# Lembar hasil gate minggu 7

Diisi dari keluaran `tools/playtest-report.luau` atas ekspor sesi nyata. Definisi metrik:
[`kamus-metrik.md`](../../metrics/kamus-metrik.md). Target: [`docs/metrics.json`](../../metrics.json).
Tidak ada angka yang boleh diisi dari perkiraan; yang belum terukur ditulis `TIDAK ADA DATA`
beserta penghalangnya (§0.5).

## Status pengisian

| Butir | Status | Sumber |
| --- | --- | --- |
| Instrumen (skrip, lembar, format ekspor, alat) | siap | berkas di direktori ini |
| Validasi alat pada fixture | terukur | `tools/idle-reduce.luau`, `tools/playtest-report.luau` |
| Sesi 3 pemain nyata | **belum dijalankan** | celah C-1…C-4 di [README](README.md) |
| Gate §17 | **belum bisa dinilai** | M-03 dan M-06 keduanya `TIDAK ADA DATA` |

Kolom angka di bawah sengaja dibiarkan kosong, bukan diisi `0` atau target: baris kosong yang
tidak dijelaskan terbaca sebagai nol (§0.5).

## Tabel per sesi

Satu baris per sesi. Kolom "sumber" wajib menunjuk ekspor atau catatan sesi.

| # | Tanggal | `case_id` + varian | Perangkat | Peserta (role) | Kondisi akhir | Idle S/H/D | Selesai? | Hint | Quit < 5 mnt | Sumber |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | | | | | |
| 2 | | | | | | | | | | |
| 3 | | | | | | | | | | |

## Tabel agregat terhadap gate

| Metrik | Target (`metrics.json`) | Hasil | Sumber | Putusan |
| --- | --- | --- | --- | --- |
| M-03 sesi menamatkan kasus | > 55% | | `case_started`/`case_completed` | |
| M-06 idle Searcher | < 25% | | `idle_start`/`idle_end` | |
| M-06 idle Handler | < 25% | | `idle_start`/`idle_end` | |
| M-06 idle Director | < 25% | | `idle_start`/`idle_end` | |
| M-04 median waktu tunggu | < 60 detik | | `lobby_enter` | |
| M-05 sesi gagal start | < 10% | | `lobby_exit.reason` | |
| M-08 quit 5 menit pertama | tanpa target, dipantau | | `player_left` | |
| M-09 hint per sesi | 1-2 | | `hint_used` | |

## Aturan keputusan gate (§17)

Gate minggu 7 lulus bila **keduanya** benar:

1. `idle_ratio` < 25% untuk **setiap** role — bukan rata-rata tiga role (§2.6 mencatat bahwa
   rata-rata menyembunyikan role yang gagal).
2. Persentase sesi yang menamatkan kasus > 55%.

Sebelum keduanya punya angka bersumber, keputusan yang sah hanya **"belum bisa dinilai"**. Lulus
atau gagal tanpa angka adalah klaim yang tidak dapat diverifikasi (§7 baris terakhir).

### Aturan penyetelan N (PRD §19)

> "N naik/turun 1 jika selesai < 55% atau > 85%."

Aturan ini hanya berlaku bila M-03 punya angka. Tanpa angka, N tidak berubah — dan perubahan N
yang diklaim atas dasar data yang tidak ada adalah klaim yang tidak dapat diverifikasi.

## Keputusan

| Butir | Isi |
| --- | --- |
| Gate §17 | belum bisa dinilai |
| Alasan | M-03 dan M-06 belum punya angka; celah C-1, C-3, C-4 |
| N (`Config.KEY_DEDUCTIONS`) | tidak berubah — menunggu M-03 |
| Tindak lanjut | tutup C-1 (sink + pemancar event), C-2 (kelas input §1.1), C-3 (peserta & perangkat), lalu jalankan minimum 3 sesi |
| Pemilik | Nathan — CTO/CIO untuk C-1/C-2/C-5; COO untuk C-3/C-4 |
