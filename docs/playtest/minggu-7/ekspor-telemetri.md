# Ekspor telemetri mentah — format dan cara menariknya

Format ekspor yang dibaca `tools/playtest-report.luau` dan `tools/idle-reduce.luau`. Bentuknya
diturunkan langsung dari [`docs/metrics/skema-event-telemetri.md`](../../metrics/skema-event-telemetri.md) —
**tidak ada** nama event, properti, atau enum baru yang diperkenalkan di sini. Kalau berkas ini
dan skema berbeda, skema yang menang.

## Bentuk berkas

Dua bentuk, dua pemakai:

### 1. Ekspor event mentah — JSONL, satu event per baris

Dibaca `tools/playtest-report.luau`. Contoh yang sudah ada:
[`docs/metrics/fixtures/sesi-contoh.jsonl`](../../metrics/fixtures/sesi-contoh.jsonl).

```
{"event_id":"01J...","event_name":"case_started","event_version":1,"t_server_ms":1000000,"session_id":"sess_...","server_id":"job_...","player_id":"server","role":"none","is_npc":false,"build_version":"0.1.0+abc123","case_id":"gallery_01","case_variant":"A","seed":1,"mode":"public","npc_director":false,"player_count_human":3,"par_time_s":480}
```

Aturan yang diwarisi dari skema dan **tidak boleh dilanggar** di ekspor:

- Amplop §2 wajib ada di setiap baris: `event_id`, `event_name`, `event_version`, `t_server_ms`,
  `session_id`, `server_id`, `player_id`, `role`, `is_npc`, `build_version`.
- `t_server_ms` adalah satu-satunya waktu untuk metrik (§1.2). `t_client_ms` boleh ada, tidak
  dipakai.
- Urutan baris tidak dijamin (§1.3) — agregasi memakai `t_server_ms`.
- Event terminal (`session_end`, `case_completed`, `accusation_submitted`, `player_left`,
  `lobby_exit`) di-flush segera (§1.4), jadi tidak boleh tertinggal di buffer.
- Bila ada event yang dibuang karena buffer, jumlahnya dilaporkan sebagai
  `telemetry_dropped_count` per sesi (§1.5). Tanpa itu, metrik kosong tidak bisa dibedakan dari
  metrik nol — dan laporan akan terbaca seolah datanya nol.
- Tidak ada isi chat, teks bebas, atau gambar (§1.7, PRD §14).

### 2. Ringkasan aliran input — JSON

Dibaca `tools/idle-reduce.luau`. Contoh: `docs/metrics/fixtures/sesi-contoh-inputs.json`.

```
{ "case_started_t_server_ms": 1000000,
  "session_end_t_server_ms": 1540000,
  "players": { "p1": { "role": "searcher", "t_server_ms": [1000000, 1001000, ...] } } }
```

`t_server_ms` di sini adalah cap waktu input yang **sudah** tersaring menurut §1.1. Bentuk ini
dipakai untuk menguji algoritma §1.3 dan sensitivitas ambang §1.4 secara terpisah dari pipeline
event, dan itulah satu-satunya cara menjalankannya hari ini — celah C-2 di
[README paket](README.md) mencatat bahwa kelas aksi §1.1 belum ada sebagai kolom di skema.

## Cara menarik ekspor

1. Jalankan sesi sampai `session_end` untuk setiap pemain.
2. Tarik seluruh event dengan `session_id` itu dari sink. **Jangan** menyaring per role:
   `case_started` dan `lobby_enter` ber-`role = none`.
3. Simpan JSONL mentah. Jangan dibulatkan, jangan diagregasi, jangan diganti nama event — alat
   yang mengagregasi, dan nama kanonik yang dipakai.
4. Catat `telemetry_dropped_count` dan jumlah baris ke lembar A1.

## Yang dicetak alat bila data tidak ada

`tools/playtest-report.luau` mencetak `TIDAK ADA DATA` beserta butir penghalangnya (§6 kamus
metrik) untuk metrik yang sumbernya belum ada di ekspor — **bukan** `0`. Peta cepat:

| Metrik | Event yang dibutuhkan | Kalau kosong |
| --- | --- | --- |
| M-03 sesi menamatkan kasus | `case_started`, `case_completed` | butir §6 **G2** |
| M-04 median waktu tunggu | `lobby_enter`, `case_started` | butir §6 **G3** |
| M-06 idle per role | `idle_start`, `idle_end`, `role_assigned`, `session_end`, `player_left` | butir §6 **G5** |
| M-08 quit 5 menit pertama | `player_left`, `player_rejoined` | butir §6 **G4** |
| M-09 hint per sesi | `hint_used`, `case_started` | butir §6 **G2** |
| M-13 rank | `par_time_s` per varian | butir §6 **G6** |

## Jangan dicampur dengan kosakata usulan

`tools/metric-report.py` (EXTA-37) memakai kosakata event **usulan** sendiri — docstring-nya
menyebutnya "KONTRAK EVENT — USULAN, bukan keputusan otomasi ini" — dengan nama seperti
`lobby_wait` dan `case_released`. Nama kanonik ada di `skema-event-telemetri.md`. Jangan
menjalankan kedua alat atas berkas yang sama dan menyajikan hasilnya sebagai satu laporan tanpa
menyebut kosakata mana yang dipakai.
