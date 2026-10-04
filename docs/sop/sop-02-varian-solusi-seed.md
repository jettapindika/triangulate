# SOP-02: Varian solusi per seed

- Versi: draf v0.1 (belum terbit)
- Penyusun draf: Bagas — Process Writer (EXTA-47)
- Pemilik proses: Nadia — Penulis Konten
- Rujukan PRD: §5, §10, §15, §18
- Dipanggil oleh: SOP-01 langkah 6-11

## Pemicu

1. Kasus baru masuk tahap penulisan data (SOP-01 langkah 6).
2. Kasus lama ditambah varian baru untuk Cold Case Archive (SOP-03 langkah 4).
3. Ditemukan kebocoran solusi: pemain atau video memuat pelaku yang benar sebelum sesi dimulai (§18, §10).

## Peran

| Kode | Peran | Pemilik |
| --- | --- | --- |
| V1 | Penulis varian | Nadia — Penulis Konten |
| V2 | Validator | Nathan — CTO/CIO |
| V3 | Pemilik pemilihan seed dan pemisahan data | Nathan — CTO/CIO (kontrak data: EXTA-32) |
| V4 | Verifikator kebocoran | Rani — Data & Metrics Engineer |

## Langkah

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 1 | Tetapkan jumlah varian: 2 atau 3 | V1 | pitch (SOP-01 langkah 4) | daftar varian dengan `culprit` dan `motive` | setiap varian punya pasangan pelaku+motif yang berbeda dari varian lain |
| 2 | Tetapkan aset bersama: satu lokasi, satu set puzzle, satu set gambar | V1 + V3 | berkas kasus | daftar aset bersama | tidak ada aset visual atau geometri baru per varian; hanya teks dan nilai yang berbeda (§10) |
| 3 | Untuk setiap varian, pastikan graf punya jalur solusi penuh dari objek pertama sampai tuduhan | V1 | node dan relasi | graf per varian | validator §10 menyatakan jalur solusi penuh ada di varian itu |
| 4 | Untuk setiap varian, pastikan setiap field tuduhan (Pelaku, Motif, Cara) ditopang tepat satu rantai | V1 | graf per varian | peta rantai → field | setiap dari 3 field punya satu rantai penopang; tidak ada field yang bergantung pada rantai yang sama dengan field lain |
| 5 | Untuk setiap varian, pastikan minimal satu kontradiksi dapat ditandai | V1 | `statements` | daftar kontradiksi per varian | setiap varian punya ≥ 1 pernyataan bohong dengan `contradicted_by` yang dapat dicapai pemain |
| 6 | Untuk setiap varian, pastikan N Deduksi Kunci dapat dicapai | V1 + V2 | `key_deductions` | daftar deduksi kunci per varian | jumlah deduksi kunci yang dapat dicapai ≥ N tipe kasus (§5) |
| 7 | Tulis daftar diff antar varian | V1 | berkas kasus semua varian | tabel diff | tabel menyebut setiap node yang berbeda isinya antar varian, dan menyatakan node mana yang identik |
| 8 | Jalankan validator untuk setiap varian, satu per satu | V2 | berkas kasus | laporan validator per varian | setiap varian hijau; tidak ada varian yang lolos hanya karena varian lain hijau |
| 9 | Uji pemilihan seed pada rentang seed uji | V2 + V3 | fungsi pemilihan seed | tabel seed → varian terpilih | tidak ada seed yang menghasilkan varian tanpa jalur solusi; tidak ada seed yang menghasilkan varian yang tidak ada |
| 10 | Periksa distribusi varian pada rentang seed uji | V2 | tabel seed → varian | catatan distribusi | setiap varian terpilih pada rentang uji; tidak ada varian yang selalu terpilih atau tidak pernah terpilih |
| 11 | Verifikasi pemisahan data: client tidak menerima pelaku/motif sebelum terungkap | V4 | kontrak data server↔client (EXTA-32), §15 | hasil verifikasi | data yang diterima client tidak memuat `culprit`/`motive` varian terpilih di luar momen yang diizinkan |
| 12 | Catat varian terpilih pada sesi di telemetri | V4 | kamus event (EXTA-36) | event sesi | setiap sesi mencatat varian mana yang dipakai; tanpa ini playtest tidak bisa membandingkan varian |

## Aturan pemilihan seed

1. Seed ditetapkan server saat sesi dibuat, bukan di client (§10).
2. Varian terpilih tidak dikirim ke client sebelum momen yang ditentukan desain (§15).
3. Seed disimpan pada rekaman sesi agar run dapat direproduksi saat investigasi bug.
4. Pemilihan varian tidak boleh bergantung pada role yang dipegang pemain — kalau bergantung, varian bisa ditebak dari komposisi lobby.

## Definisi selesai

SOP ini selesai untuk satu kasus bila:

1. Ada 2 atau 3 varian dengan pasangan pelaku+motif berbeda.
2. Tabel diff antar varian ada dan tidak menyebut aset baru di luar teks.
3. Laporan validator hijau untuk **setiap** varian, bukan rata-rata.
4. Tabel seed → varian ada, tanpa seed yang menghasilkan varian cacat, dan setiap varian terwakili.
5. Hasil verifikasi pemisahan data ada dan menyatakan tidak ada kebocoran.
6. Setiap sesi mencatat varian yang dipakai.

## Failure modes

| Kalau ini gagal | Gejalanya | Yang dilakukan |
| --- | --- | --- |
| Varian kedua butuh aset lokasi baru | biaya produksi per kasus naik, ritme §10 jebol | batalkan varian itu atau ubah agar berbagi aset; jangan tambah aset baru di tengah produksi |
| Varian tanpa kontradiksi | syarat pembuka tuduhan tidak terpenuhi di varian itu (§5) | tambah satu pernyataan bohong dengan `contradicted_by` yang dapat dicapai |
| Satu rantai menopang dua field tuduhan | satu bukti hilang membuat dua field tidak bisa dijawab; tim mentok | pisahkan rantai atau ubah pemetaan rantai → field |
| Validator hanya dijalankan pada varian pertama | varian lain bisa buntu tanpa terdeteksi | jalankan langkah 8 untuk setiap varian; catat varian mana yang diuji di laporan |
| Seed menentukan varian di client | pemain dapat membaca varian dari client; spoiler (§18) | pindahkan pemilihan ke server; ulangi langkah 11 |
| Varian selalu sama pada rentang seed uji | spoiler tetap berlaku meski ada varian (§10) | perbaiki fungsi pemilihan seed; ulangi langkah 9-10 |
| Client menerima `culprit` lebih awal | exploit/bocor (§18) | hentikan rilis kasus; perbaiki kontrak data per role; ulangi langkah 11 |
| Varian tidak tercatat di telemetri | playtest tidak bisa membandingkan varian; temuan tidak dapat diperbaiki | tambahkan pencatatan varian sebelum playtest (langkah 12) |

## Pemilik

Nadia — Penulis Konten. Langkah validasi dan pemisahan data dijalankan Nathan — CTO/CIO sebagai pemilik skema dan kontrak data.
