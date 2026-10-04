# SOP-01: Produksi story case — ide sampai rilis

- Versi: draf v0.1 (belum terbit)
- Penyusun draf: Bagas — Process Writer (EXTA-47)
- Pemilik proses: Rafael — COO
- Rujukan PRD: §3, §4, §5, §10, §12, §14, §15, §17
- Kadensi: 1 story case per 1-2 minggu (§10, §17)

## Pemicu

Salah satu dari ini terjadi:

1. Kasus terakhir sudah tayang ≥ 1 minggu dan tidak ada kasus berikutnya dalam produksi (§10: rilis 1 per 1-2 minggu).
2. Operating plan EXTA-46 menetapkan tanggal rilis kasus berikutnya.
3. Gate minggu 6 (§17) membutuhkan "Case 0, story case #1 + varian".
4. Kasus yang sudah tayang dinyatakan cacat oleh temuan playtest (SOP-04) dan butuh versi perbaikan.

## Peran

| Kode | Peran | Pemilik | Kewenangan |
| --- | --- | --- | --- |
| P1 | Penulis kasus | Nadia — Penulis Konten | menulis pitch, data kasus, teks puzzle, pernyataan saksi |
| P2 | Pemilik skema dan validator | Nathan — CTO/CIO | menjalankan validator, memutuskan lulus/ tidak lulus teknis |
| P3 | Aset visual puzzle | Sari — Perancang Visual & Presentasi | sheet gambar per bukti, mockup clue board |
| P4 | Instrumen dan telemetri | Rani — Data & Metrics Engineer | memastikan event §15 terekam untuk kasus baru |
| P5 | Fasilitator playtest | Rafael — COO (dapat didelegasikan ke Dewi — Operations Analyst) | menjalankan SOP-04 |
| P6 | Penerbit dan pemutus gate | Rafael — COO | membuka slot kasus, memutuskan rilis |
| P7 | Persetujuan isi konten | Clara — CMO | menyetujui isi sebelum tayang |

`ASUMSI`: P7 diambil dari batasan tertulis di EXTA-38 ("draf saja — tidak menerbitkan tanpa persetujuan Clara"). Yang menggantikan bila salah: keputusan owner di EXTA-46.

## Langkah

Satu langkah satu tindakan. Nomor `H+n` adalah hari kerja setelah slot dibuka; `ASUMSI` — kalender 10 hari kerja per kasus; yang menggantikan: tanggal pada operating plan EXTA-46.

### Tahap 0 — Buka slot

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 1 | Buka slot kasus di papan: `case_id`, lokasi, tanggal rilis target, pemilik kasus | P6 | kasus terakhir tayang, kalender rilis | entri slot kasus | `case_id` unik dan tanggal target terisi; pemilik kasus satu nama |
| 2 | Salin template kasus dari skema EXTA-33 ke berkas kasus baru | P2 | JSON Schema kasus (EXTA-33) | berkas kasus kosong yang lolos parser | berkas ter-parse tanpa error |
| 3 | Pastikan event telemetri §15 untuk kasus baru sudah terpetakan (idle time, waktu ke clue pertama, tuduhan, quit point) | P4 | kamus event (EXTA-36) | daftar event yang dipakai kasus ini | setiap dari 4 event §15 punya nama kanonik atau ditandai menunggu EXTA-36 |

### Tahap 1 — Ide (H+0 sampai H+1)

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 4 | Tulis pitch 1 halaman | P1 | §3 tema, §4 struktur rantai | pitch 1 halaman | lihat checklist pitch di bawah — semua butir terisi |
| 5 | Review pitch dan putuskan lanjut atau tulis ulang | P1 + P6 | pitch | keputusan lanjut/ulang tercatat | keputusan tertulis; bila ulang, kembalikan ke langkah 4 |

Checklist pitch (semua wajib terisi; rujukan §4, §5, §10):

- [ ] lokasi (satu lokasi; §16 MVP: 1 lokasi per kasus)
- [ ] 3 rantai bukti yang berjalan paralel (§6)
- [ ] setiap rantai menopang tepat satu field tuduhan: Pelaku, Motif, Cara (§5)
- [ ] 2-3 varian solusi dengan pelaku/motif berbeda, berbagi lokasi dan aset puzzle (§10)
- [ ] minimal satu pernyataan saksi/tersangka yang berbohong, dengan bukti yang mengontradiksinya (§4)
- [ ] tipe puzzle tiap bukti termasuk 3 tipe MVP: dokumen sobek, timeline, cipher (§4)
- [ ] tema termasuk daftar §3 (pencurian, pemalsuan, sabotase, orang hilang); tanpa gore, tanpa pembunuhan eksplisit

### Tahap 2 — Data kasus (H+2 sampai H+4)

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 6 | Tulis node graf untuk seluruh rantai: `object`, `evidence`, `clue_card`, `deduction` | P1 | pitch, skema EXTA-33 | berkas kasus berisi node | setiap node bertipe salah satu dari empat tipe §4 dan punya `id` unik |
| 7 | Isi relasi antar node: `gives_key`, `needs`, `yields`, `unlocks` | P1 | node | graf terhubung | setiap `evidence` punya `needs` yang dapat dipenuhi dari node yang ada |
| 8 | Tulis briefing per role dan teks puzzle tiap tipe | P1 | §4 alur rantai, §7 komunikasi | teks briefing dan teks puzzle | setiap role punya briefing; setiap puzzle punya teks hasil yang berisi informasi (bukan hiasan) |
| 9 | Tulis pernyataan saksi/tersangka dengan penanda bohong dan `contradicted_by` | P1 | §4 kontradiksi | blok `statements` | 2-3 pernyataan; ≥ 1 bertanda bohong; setiap yang bohong punya `contradicted_by` yang menunjuk node yang ada |
| 10 | Tulis solusi untuk setiap varian: pelaku, motif, cara | P1 | varian dari pitch | blok `solution` per varian | setiap field tuduhan (Pelaku/Motif/Cara) punya nilai di setiap varian |
| 11 | Tandai Deduksi Kunci per kasus | P1 + P2 | §5 | daftar `key_deductions` | jumlahnya = N sesuai tipe kasus: 4 dari 6 (standar), 3 dari 5 (daily), 2 dari 3 (Case 0) |
| 12 | Siapkan aset visual tiap bukti | P3 | teks puzzle | satu sheet gambar per bukti | resolusi sedang, grid ≤ 6x6, mengikuti fallback §15 (bukan satu gambar raksasa) |

### Tahap 3 — Validasi (H+5)

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 13 | Jalankan validator §10 pada setiap varian | P2 | berkas kasus | laporan validator per varian | laporan menyatakan per varian: tanpa siklus, minimal satu jalur solusi penuh, tidak ada rantai buntu |
| 14 | Periksa gerbang deduksi dan kontradiksi (§5) | P2 | berkas kasus, `key_deductions` | hasil periksa | N Deduksi Kunci ada dan dapat dicapai; ≥ 1 kontradiksi dapat ditandai di setiap varian |
| 15 | Periksa pemisahan informasi per role (§15) | P2 | kontrak data server↔client (EXTA-32) | hasil periksa | solusi, resep deduksi, dan varian terpilih tidak ada di data yang diterima client sebelum waktunya |
| 16 | Perbaiki temuan validator dan ulangi langkah 13 | P1 | laporan validator | berkas kasus revisi | validator hijau untuk semua varian |

Gate tahap 3: langkah 13-16 selesai untuk **setiap** varian, bukan hanya varian default.

### Tahap 4 — Playtest (H+6 sampai H+9)

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 17 | Jalankan playtest internal | P5 | build + kasus, SOP-04 | laporan playtest | SOP-04 definisi selesai terpenuhi |
| 18 | Triase temuan playtest menjadi perbaikan | P5 + P1 + P2 | laporan playtest | daftar temuan berkelas (blocker/mayor/minor) dengan pemilik | setiap temuan punya kelas, pemilik, dan bukti timestamp |
| 19 | Perbaiki semua temuan kelas blocker | pemilik temuan | daftar temuan | berkas kasus/build revisi | tidak ada temuan blocker berstatus terbuka |
| 20 | Jalankan playtest verifikasi | P5 | build revisi | laporan verifikasi | setiap temuan blocker dinyatakan tertutup dengan bukti dari sesi verifikasi |

### Tahap 5 — Rilis (H+10)

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 21 | Ajukan persetujuan isi konten | P1 | berkas kasus + laporan playtest | persetujuan tertulis | persetujuan P7 tercatat di issue kasus |
| 22 | Tutup gate rilis | P6 | semua output tahap 0-4 | keputusan rilis/tidak | lihat daftar gate rilis di bawah — semua butir terpenuhi |
| 23 | Publikasikan kasus ke rotasi | P6 | keputusan rilis | kasus tayang | kasus dapat dimainkan pemain; tidak ada perubahan kode yang menyertai rilis (§10: menambah kasus tidak menyentuh kode) |
| 24 | Catat tanggal tayang dan mulai pantau metrik kasus | P4 | telemetri | entri tanggal tayang | tanggal tayang tercatat; metrik §12 kasus ini terbaca |

Daftar gate rilis (semua wajib):

- [ ] validator §10 hijau untuk setiap varian
- [ ] N Deduksi Kunci sesuai tipe kasus, dan ≥ 1 kontradiksi dapat ditandai (§5)
- [ ] playtest lulus kriteria lulus dari EXTA-46
- [ ] tidak ada temuan blocker terbuka
- [ ] isi konten disetujui P7
- [ ] tema dan rating sesuai §14 (non-gore, target 13+)
- [ ] event telemetri §15 kasus ini terekam

## Definisi selesai

SOP ini selesai untuk satu kasus bila seluruh ini benar:

1. Ada satu entri kasus dengan `case_id`, tanggal tayang, dan pemilik kasus.
2. Berkas kasus ada di repo, ter-parse, dan lolos validator untuk setiap varian (bukti: laporan validator per varian).
3. Ada laporan playtest dengan angka idle time per role dan persentase sesi selesai (bukti: laporan SOP-04).
4. Ada daftar temuan dengan kelas dan pemilik, dan tidak ada blocker terbuka (bukti: daftar temuan).
5. Ada persetujuan tertulis P7 (bukti: komentar persetujuan di issue kasus).
6. Kasus tayang dan tanggal tayangnya tercatat.

## Failure modes

| Kalau ini gagal | Gejalanya | Yang dilakukan |
| --- | --- | --- |
| Slot kasus dibuka tanpa tanggal target | tidak ada yang tahu kapan harus selesai; kasus mengambang | P6 mengisi tanggal target sebelum langkah 2 dimulai; langkah 4 tidak boleh jalan tanpa tanggal |
| Pitch hanya punya 1 varian | §10 tidak terpenuhi; spoiler berlaku penuh | kembalikan ke langkah 4; varian kedua ditulis sebelum data kasus ditulis |
| Validator merah pada salah satu varian | ada rantai buntu atau siklus di varian itu | perbaiki graf varian itu; kasus tidak boleh rilis dengan varian yang tidak lolos — kurangi jumlah varian bila varian itu tidak bisa diperbaiki |
| Deduksi Kunci kurang dari N | form tuduhan tidak terbuka; tim tidak bisa menang | tambah deduksi kunci atau turunkan N sesuai tipe kasus (§5); perubahan N naik ke owner (butir 4 README) |
| Solusi terbaca di client | exploit/bocor (§18) | hentikan rilis; pindahkan data ke server sesuai §15; ulangi langkah 15 |
| Playtest tidak menemukan masalah apa pun | kemungkinan instrumennya yang gagal, bukan kasusnya yang bersih | periksa apakah event telemetri benar-benar terekam (langkah 3); ulangi sesi dengan pengamat per role |
| Aset puzzle butuh satu gambar raksasa | texture turun resolusi di mobile (§15, §18) | pakai fallback §15: sheet per bukti, grid ≤ 6x6, atau ilustrasi flat |
| Kasus melewati 2 minggu | ritme §10 tidak tercapai | naikkan sebagai bottleneck lewat prosedur EXTA-46; jangan menambah orang di tengah kasus tanpa keputusan P6 |
| Kasus sudah tayang lalu ditemukan jalur buntu | pemain mentok permanen | cabut kasus dari rotasi, perbaiki, tayangkan ulang sebagai revisi; catat di daftar temuan |

## Pemilik

Rafael — COO. Pemilik per tahap seperti pada tabel Peran; satu tahap tetap satu pemilik.
