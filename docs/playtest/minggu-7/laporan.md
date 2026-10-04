# Laporan playtest minggu 7

Status tiap angka diberi label `kamus-metrik.md` §0.5: `TERUKUR`, `BLOKIR`, `ASUMSI`,
`TIDAK ADA DATA`. Angka tanpa salah satu label itu tidak boleh dipakai.

## Ringkasan

Gate minggu 7 (PRD §17) **belum bisa dinilai** — `BLOKIR`. Belum ada satu pun sesi 3 pemain nyata
dijalankan, dan server belum memancarkan event telemetri apa pun, jadi kedua syarat gate (idle <
25% per role, selesai > 55%) tidak punya angka.

Yang selesai: instrumen playtest siap pakai, dan satu divergensi definisi idle yang terbukti bisa
membalik putusan gate sudah diperbaiki di kode dengan angka before/after.

| Butir | Status |
| --- | --- |
| Instrumen (skrip, lembar, format ekspor, dua alat pembaca) | siap — `TERUKUR` |
| Alat menghitung ulang `idle_ratio` menurut §1.3 | `TERUKUR` — mereproduksi seluruh angka §4 kamus-metrik |
| Alat membaca ekspor event → tabel gate | `TERUKUR` — atas fixture 42 event |
| Perbaikan definisi idle (lama vs §1.3) | `TERUKUR` — masuk kode, tes hijau |
| Sesi 3 pemain nyata | `BLOKIR` — celah C-1, C-3, C-4 |
| Gate §17 | belum bisa dinilai — `BLOKIR` |
| Penyetelan N (PRD §19) | tidak diubah — `TIDAK ADA DATA` untuk M-03 |

## 1. Yang terukur: validasi instrumen

Instrumen harus dibuktikan bisa menghitung **sebelum** dipakai pada sesi manusia — kalau tidak,
sesinya terbuang (failure mode SOP-04). Yang dipakai sebagai pembanding adalah
[`kamus-metrik.md` §4](../../metrics/kamus-metrik.md), yang memuat angka contoh untuk fixture
`docs/metrics/fixtures/sesi-contoh-inputs.json`.

`lune run tools/idle-reduce.luau`:

| Role | `idle_time_role_ms` | Jumlah idle run | `idle_ratio` | §4 | Putusan |
| --- | --- | --- | --- | --- | --- |
| Searcher | 75 000 | 3 | 13,9% | 13,9% | LULUS |
| Handler | 80 000 | 2 | 14,8% | 14,8% | LULUS |
| Director | 120 000 | 2 | 22,2% | 22,2% | LULUS |

Sepuluh baris pembanding §4 semuanya cocok; skrip mencetak `SELURUH ANGKA §4 COCOK`. §1.4 juga
terpenuhi pada fixture: peringkat role **stabil** di ambang 3/5/10 detik (Searcher < Handler <
Director), jadi gate belum goyah oleh pilihan ambang.

`lune run tools/playtest-report.luau` atas `docs/metrics/fixtures/sesi-contoh.jsonl` (42 event):

| Metrik | Hasil | Target | Putusan |
| --- | --- | --- | --- |
| M-03 sesi menamatkan kasus | 1 menang / 1 sesi = 100,0% | > 55% | LULUS |
| M-06 Searcher | 75 000 / 540 000 = 13,9% | < 25% | LULUS |
| M-06 Handler | 80 000 / 540 000 = 14,8% | < 25% | LULUS |
| M-06 Director | 120 000 / 540 000 = 22,2% | < 25% | LULUS |
| M-04 median waktu tunggu | 42,0 detik | < 60 detik | LULUS |
| M-08 quit 5 menit pertama | 0,0% ketiga role | dipantau | — |
| M-09 hint per sesi | 1,00 | band 1-2 | LULUS |

**Angka di atas adalah angka fixture, bukan angka playtest.** Fixture dibuat tangan untuk menguji
alat; ia tidak membuktikan apa pun tentang pengalaman pemain sungguhan. Yang dibuktikan: alat
menghitung definisi §1.3 dengan benar dan mencetak `TIDAK ADA DATA` + butir penghalang §6 — bukan
`0` — ketika sumbernya kosong.

## 2. Yang terukur: divergensi definisi idle, sebelum dan sesudah

`TelemetryService` sebelum pekerjaan ini memakai definisi idle yang **berbeda** dari
`kamus-metrik.md` §1.3 pada tiga hal sekaligus:

| Aspek | Kode lama | §1.3 (mengikat) |
| --- | --- | --- |
| Satuan | detik (`os.clock()`) | ms (`t_server_ms`) |
| Algoritma | union jendela keaktifan `[t, t+5]` | bucket 1 detik, run INACTIVE berurutan |
| Titik nol penyebut | `session.startedAt` (mulai sesi) | `max(role_assigned, case_started)` |

Kode lama dijalankan apa adanya atas fixture yang sama:

| Role | Lama, penyebut start sesi | Lama, penyebut `case_started` | §1.3 (sekarang) |
| --- | --- | --- | --- |
| Searcher | 20,3673% | 11,6667% | **13,9%** |
| Handler | 21,8698% | 13,3333% | **14,8%** |
| Director | **28,5476%** | 20,7407% | **22,2%** |

Baris Director yang penting: dengan penyebut yang benar-benar dipakai `init.server.luau` saat itu
(`startedAt` = mulai sesi), Director **gagal** gate < 25%; definisi §1.3 memberi 22,2% dan lulus.
Satu bug definisi membalik putusan gate untuk satu dari tiga role.

Perbaikan yang masuk kode:

- `src/server/TelemetryService.luau` ditulis ulang ms-native mengikuti §1.3, dengan `idleRuns`,
  `idleRatio`, `idleRatioByThreshold`, dan `idleEvents`. `idleRatio` mengembalikan `nil` — bukan
  `0` — bila tidak bisa dihitung; nol diam-diam akan terbaca sebagai "lulus".
- `src/server/init.server.luau` memakai dua cap waktu: `telemetryMs()` (ms) untuk telemetri,
  `os.clock()` (detik) untuk rank dan durasi. Sebelumnya `startedAt` tidak terikat dan
  `caseStartedAt` tidak terpakai — sesi bisa gagal jalan.
- `tests/telemetry.spec.luau` ditulis ulang, 62 assertion. Assertion lama yang mem-pin definisi
  union-jendela **dihapus**, bukan di-pin ulang ke angka baru.

Verifikasi: `lune run tests/run.luau` → **610 assertion, 0 gagal**; `selene src tests tools` → 0
error, 0 warning; `stylua --check src tests tools` → bersih.

## 3. Yang tidak bisa diukur

`BLOKIR`. Tiap butir punya bukti dan pemilik.

| ID | Celah | Bukti | Dampak |
| --- | --- | --- | --- |
| C-1 | Server belum memancarkan satu event pun | hanya `TelemetryService.record` yang ada, tanpa sink; tidak ada `AnalyticsService`/`DataStoreService` di `src/` | M-03/M-04/M-06/M-08/M-09 semua `TIDAK ADA DATA` (§6 G2-G5) |
| C-2 | Kelas input bermakna §1.1 tidak ada sebagai kolom | `grep -rln "CAM_WITH_ACTION\|UI_NAV"` hanya menemukan `docs/metrics/kamus-metrik.md` | penyaring §1.1 belum bisa dijalankan atas lalu lintas sungguhan |
| C-3 | Tidak ada perangkat mobile dan tidak ada pemain luar tim di lingkungan ini | SOP-04 langkah 3 mensyaratkan minimal 2 mobile kelas bawah | sesi 3 pemain nyata tidak bisa dijalankan |
| C-4 | Roblox Studio tidak bisa diotomasi | `docs/mvp-notes.md` §2.3 baris `MCP Studio`: "JALUR MATI — `tools/list` kosong" | tiap sesi butuh manusia |
| C-5 | Timer *cleanup* (PRD §6) belum ada implementasinya | `grep` hanya menemukan komentar di `src/server/init.server.luau`, `src/shared/Net.luau`, `src/shared/Config.luau`, `docs/prd-v0.2.md` | durasi cleanup (§19) tidak punya angka awal |
| C-6 | `par_time_s` tidak ada di `data/cases/gallery_01.json` | §3 kamus membutuhkannya per (`case_id`, `case_variant`) | M-13 rank tidak bisa dihitung (§6 G6) |

C-1 memblokir yang lain: tanpa pemancar event, sesi manusia pun akan menghasilkan `TIDAK ADA
DATA`. SOP-04 langkah 2 mengaturnya eksplisit — *"jangan jalankan sesi tanpa instrumen"*. Karena
itu sesi yang dijalankan sementara C-1 terbuka berstatus **latihan**, bukan data gate.

## 4. Evaluasi gate PRD §17

Gate: `idle_ratio` < 25% untuk **setiap** role, **dan** persentase sesi menamatkan kasus > 55%.

| Syarat | Angka playtest | Putusan |
| --- | --- | --- |
| idle < 25% per role | `TIDAK ADA DATA` (C-1, C-3) | belum bisa dinilai |
| selesai > 55% | `TIDAK ADA DATA` (C-1, C-3) | belum bisa dinilai |
| **Gate keseluruhan** | — | **belum bisa dinilai** |

Tidak diklaim lulus dan tidak diklaim gagal. Lulus/gagal tanpa angka adalah klaim yang tidak dapat
diverifikasi (`kamus-metrik.md` §7).

### Penyetelan N (PRD §19)

> "N naik/turun 1 jika selesai < 55% atau > 85%."

M-03 belum punya angka, jadi aturan ini **tidak dijalankan**.
`Config.KEY_DEDUCTIONS` tetap `{standard = 4, daily = 3, tutorial = 2}`. Mengubahnya sekarang
berarti menyetel keseimbangan permainan berdasarkan nol sesi.

## 5. Tuning

### 5.1 Sudah diterapkan — punya angka before/after

| Perubahan | Sebelum | Sesudah | Sumber angka |
| --- | --- | --- | --- |
| Definisi `idle_ratio` mengikuti §1.3 | Director 28,5476% (penyebut start sesi) → **gagal** gate 25% | Director 22,2% → lulus | `tools/idle-reduce.luau`, kode lama dijalankan atas fixture yang sama |
| Satuan telemetri | detik (`os.clock()`), tak cocok dengan `t_server_ms` §0.2 | ms lewat `telemetryMs()` | `tests/telemetry.spec.luau` 62 assertion |
| Titik nol penyebut idle | `session.startedAt` | `max(role_assigned, case_started)` | §1.3 langkah 6 |
| `idleRatio` saat tak terhitung | `0` (terbaca "lulus") | `nil` | §0.5 |
| Assertion yang mem-pin definisi lama | 5 assertion gagal setelah satuan diperbaiki | dihapus, diganti 62 assertion §1.3 | `lune run tests/run.luau` |
| Ambang gate di `tools/playtest-report.luau` | angka `0.55` dan `25` disalin ke kode | dibaca dari `docs/metrics.json` seperti `tools/metric-report.py`; berkas hilang → berhenti, bukan memakai cadangan | `lune run tools/playtest-report.luau` |

Ini satu-satunya perubahan tuning yang punya dasar angka. Sisanya menunggu sesi.

### 5.2 Kandidat — menunggu data, **belum diubah**

Nilai di bawah adalah angka sekarang di kode; kolom "arah" adalah yang akan diuji, bukan keputusan.

| Kandidat | Nilai sekarang | Sumber | Arah yang akan diuji | Data yang dibutuhkan |
| --- | --- | --- | --- | --- |
| Timer *cleanup* (PRD §6) | **tidak ada implementasi** | C-5 | pasang lalu setel durasinya | sesi + implementasi |
| `Config.KEY_DEDUCTIONS` | `{standard=4, daily=3, tutorial=2}` | `src/shared/Config.luau:37` | ±1 menurut §19 | M-03 > 55% dan < 85% |
| `Config.TABLE_WIDTH`/`TABLE_HEIGHT` | 16×16 stud | `src/shared/Config.luau:63` (komentar `ASUMSI`) | ukuran sel agar potongan nyaman di jari | uji jari di ponsel |
| `Table.GRAB_RADIUS` | 1,2 sel | `src/client/Table/init.luau:74` | turun bila salah-ambil, naik bila gagal ambil | rekaman layar sesi |
| `PuzzleTable.SNAP_TOLERANCE` | 0,5 sel | `src/shared/PuzzleTable.luau:60` | — | tingkat koreksi server saat drop nyata |
| `PuzzleTable.INTERPOLATION_RATE` | 12 pangsa/detik | `src/shared/PuzzleTable.luau:73` | — | pengukuran jank di perangkat |
| Frasa ping per role | Searcher 4+3, Handler 3+3, Director 3+3 (maks 8) | `src/shared/PingPhrases.luau` | tambah frasa yang terbukti sering dibutuhkan | wawancara A6 + pola ping sesi |

Ketujuh baris itu sengaja **tidak** diubah. Menyetelnya tanpa data playtest berarti mengganti satu
tebakan dengan tebakan lain.

### 5.3 Divergensi yang dilaporkan, belum diubah

`AccusationService.rank` memakai ambang scaffold (`percobaan ≤ 1` dan `hint = 0` → S, dst.),
sementara `kamus-metrik.md` §3 mendefinisikan rubrik tier-per-komponen dengan rank = tier
terburuk. Keduanya memberi hasil berbeda pada sesi yang sama. Yang dipakai kode hari ini adalah
scaffold, dan komentarnya sudah menyebut dirinya bukan angka PRD. Belum diubah karena rubrik §3
sendiri berlabel `ASUMSI` dan bergantung pada `par_time_s` yang belum ada (C-6).

## 6. Risiko yang terbukti

1. **Definisi metrik bisa menyimpang dari kamus tanpa ketahuan.** Divergensi idle hidup di kode
   selama beberapa minggu dan hanya muncul karena fixture §4 dipakai sebagai pembanding. Mitigasi
   yang sudah jalan: `tools/idle-reduce.luau` membandingkan kode dengan §4 setiap kali dijalankan.
   Belum ada yang menjaga metrik lain dengan cara yang sama.
2. **Kode bisa membalik putusan gate.** Director gagal di definisi lama, lulus di §1.3. Mitigasi:
   definisi idle kini satu tempat (`TelemetryService`) dan diuji 62 assertion.
3. **Gate minggu 7 tidak bisa dinilai pada tanggal gate.** C-1 sampai C-4 belum tertutup; tanpa
   pemancar event, sesi manusia pun menghasilkan `TIDAK ADA DATA`. Urutan perbaikan yang benar:
   tutup C-1 dan C-2 lebih dulu, baru jadwalkan sesi.
4. **`par_time_s` belum ada di data kasus** (C-6), sehingga M-13 rank — salah satu metrik
   keberhasilan playtest — tidak punya sumber meski sesinya jalan.

## 7. Langkah berikutnya

1. Tutup C-1: sink telemetri + pemancar untuk `case_started`, `case_completed`, `lobby_enter`,
   `lobby_exit`, `player_left`, `role_assigned`, `first_clue`, `hint_used`, `idle_start`,
   `idle_end`, `accusation_submitted`, `contradiction_marked`.
2. Tutup C-2: bawa kelas input §1.1 ke event input, atau sediakan tabel pemetaan aksi→kelas.
3. Jalankan sesi uji pendek untuk membuktikan keempat event §15 terekam (SOP-04 langkah 2).
4. Setelah itu baru jadwalkan minimum 3 sesi 3 pemain nyata di mobile (C-3), dan isi
   [`lembar-hasil.md`](lembar-hasil.md).
