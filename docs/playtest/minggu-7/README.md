# Instrumen playtest minggu 7

Paket instrumen untuk gate minggu 7 (PRD §17) — playtest 3 pemain nyata di mobile.

Paket ini **mengisi** prosedur yang sudah ada, tidak menyusun ulang:

| Berkas | Isi | Sumber yang dipakai apa adanya |
| --- | --- | --- |
| [`skrip-sesi.md`](skrip-sesi.md) | skrip pembuka, langkah A/B/C, lembar A1-A7 siap cetak | [SOP-04](../../sop/sop-04-playtest.md), [Lampiran A](../../sop/lampiran-a-instrumen-playtest.md) |
| [`ekspor-telemetri.md`](ekspor-telemetri.md) | format ekspor mentah + cara menariknya | [skema-event-telemetri.md](../../metrics/skema-event-telemetri.md) |
| [`lembar-hasil.md`](lembar-hasil.md) | lembar pengisian angka + keputusan gate | [kamus-metrik.md](../../metrics/kamus-metrik.md), [metrics.json](../../metrics.json) |
| [`laporan.md`](laporan.md) | laporan terukur: validasi instrumen, celah, evaluasi gate, tuning before/after | semua di atas |

Alat yang membaca hasilnya:

| Alat | Fungsi |
| --- | --- |
| `tools/playtest-report.luau` | baca ekspor JSONL → tabel gate §17 (M-03, M-04, M-06, M-08, M-09), cetak `TIDAK ADA DATA` + butir penghalang §6 untuk yang belum bisa dihitung |
| `tools/idle-reduce.luau` | hitung ulang `idle_time_role_ms` / `idle_ratio` dari aliran input menurut §1.3, dan uji sensitivitas ambang 3/5/10 detik |

Definisi metrik **tidak** ditulis ulang di paket ini. Satu-satunya sumber definisi adalah
`docs/metrics/kamus-metrik.md` (EXTA-36); satu-satunya sumber target adalah `docs/metrics.json`.

## Daftar celah

Celah = hal yang menghalangi sesi atau pengukuran, dan **bukan** hasil. Celah tidak boleh
dilaporkan sebagai angka, dan tidak boleh ditutup dengan asumsi.

| ID | Celah | Dampak pada gate | Yang dibutuhkan untuk menutup |
| --- | --- | --- | --- |
| C-1 | Server belum memancarkan `case_started`, `case_completed`, `lobby_enter`, `player_left`, `hint_used`, `idle_start`, `idle_end`, `first_clue`, `deduction_made`, `contradiction_marked`, `accusation_submitted`, `object_reported` — hanya `TelemetryService.record` yang ada, tanpa sink | seluruh M-03/M-04/M-06/M-08/M-09 `TIDAK ADA DATA` (butir §6 G2-G5) | sink telemetri + pemancar per event; `docs/automation-spec.md` |
| C-2 | Kelas input bermakna §1.1 (`MOVE`, `INTERACT`, `TABLE`, `BOARD`, `UI_NAV`, `COMM`, `CONFIRM`, `CAM_WITH_ACTION`) tidak ada sebagai kolom di skema event maupun di `src/` — `grep` atas kedelapan nama hanya menemukan `docs/metrics/kamus-metrik.md` | penyaring §1.1 tidak bisa dijalankan atas lalu lintas sungguhan; `idle_ratio` hanya bisa dihitung dari aliran input yang sudah tersaring di luar sistem | tambahkan `input_class` pada event input, atau tabel pemetaan aksi→kelas di `src/shared` |
| C-3 | Tidak ada perangkat mobile dan tidak ada pemain di luar tim di workspace ini | sesi 3 pemain nyata tidak bisa dijalankan; gate minggu 7 tidak bisa dinilai | jadwalkan sesi dengan 3 pemain luar tim, minimal 2 perangkat mobile kelas bawah (SOP-04 langkah 3) |
| C-4 | Roblox Studio tidak bisa diotomasi — `tools/list` MCP kosong, butuh auth Assistant interaktif di UI Studio (`docs/mvp-notes.md` §2.3, baris `MCP Studio`) | tidak ada sesi otomatis; tiap sesi butuh manusia | jalur manusia, atau RCC/headless bila tersedia |
| C-5 | Timer *cleanup* (PRD §6) belum ada implementasinya — `grep` hanya menemukan komentar di `src/server/init.server.luau`, `src/shared/Net.luau`, `src/shared/Config.luau`, `docs/prd-v0.2.md` | penyetelan durasi cleanup (§19) tidak punya angka awal | implementasi + pemilik durasi (§19, `docs/sop/README.md`) |
| C-6 | `par_time_s` tidak ada di `data/cases/gallery_01.json`, padahal §3 membutuhkannya per (`case_id`, `case_variant`) | M-13 rank tidak bisa dihitung dari data kasus (butir §6 G6) | tambahkan `par_time_s` per varian |

Aturan main: bila sebuah sesi dijalankan sementara C-1 atau C-2 masih terbuka, sesi itu
**latihan**, bukan data gate — persis seperti SOP-04 langkah 2 ("jangan jalankan sesi tanpa
instrumen") dan baris failure mode "Telemetri tidak merekam idle time".

## Status paket

- Instrumen: **siap** — skrip, lembar, format ekspor, dan dua alat pembaca sudah ada dan lulus uji.
- Validasi alat: **terukur** — `tools/idle-reduce.luau` mereproduksi seluruh angka §4 kamus-metrik pada fixture `docs/metrics/fixtures/sesi-contoh-inputs.json`; `tools/playtest-report.luau` membaca `docs/metrics/fixtures/sesi-contoh.jsonl` (42 event) dan mengeluarkan tabel gate.
- Sesi 3 pemain nyata: **belum dijalankan** — celah C-1 sampai C-4.
