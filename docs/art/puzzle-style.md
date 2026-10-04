# Gaya ilustrasi puzzle dan perilaku downscale

Aturan produksi gambar bukti untuk meja Handler, plus rekomendasi teknis untuk `ImageRectOffset`
dan `ImageRectSize`.

Sumber kewajiban: PRD v0.2 §15. Bagian itu menyatakan jangan mengasumsikan satu gambar raksasa,
karena platform dapat menurunkan resolusi texture besar. Fallback yang disebut PRD: satu sheet per
bukti pada resolusi sedang, grid terbatas maksimum 6x6, atau gaya ilustrasi flat yang tahan
downscale.

## 1. Keputusan

**Satu sheet per bukti. Grid maksimum 6x6. Ilustrasi flat.**

Ketiganya dipakai bersamaan, bukan sebagai pilihan yang saling menggantikan:

| Keputusan | Isi |
|---|---|
| Satu sheet per bukti | Semua potongan satu bukti ada dalam satu texture, bukan satu unggahan per potongan |
| Grid maksimum 6x6 | 36 sel per sheet, dan tidak lebih |
| Ilustrasi flat | Bidang warna rata, siluet tebal, tanpa gradien halus dan tanpa detail kecil |

## 2. Kenapa flat, dibuktikan bukan diklaim

Klaim "flat lebih tahan downscale" diuji, bukan diterima begitu saja. Dua gambar 1024x1024 dibuat
`mockups/make_style_samples.py` dengan **komposisi, warna, dan posisi yang sama persis**. Yang
berbeda hanya cara tepinya digambar: gaya A bertepi keras, gaya B bertepi lembut selebar 8 px.
Karena variabel lain identik, selisih hasil ukur hanya bisa berasal dari gaya tepi.

Pengukuran dijalankan `mockups/measure_downscale.py`, bisa diulang kapan saja.

### Yang tidak terbukti: kontras bidang tidak rusak oleh downscale

Dugaan awal adalah warna gaya B akan "menyatu" saat resolusi turun. Itu **tidak terjadi**.

| Gaya | Ukuran | Terang | Gelap | Kontras | Detail |
|---|---|---|---|---|---|
| A, flat | 1024 | 178,5 | 33,6 | 144,9 | 40,4 |
| A, flat | 512 | 178,5 | 33,6 | 144,9 | 40,4 |
| A, flat | 256 | 178,4 | 33,6 | 144,8 | 40,4 |
| A, flat | 128 | 178,5 | 33,6 | 144,9 | 40,4 |
| B, lembut | 1024 | 178,0 | 33,6 | 144,4 | 39,4 |
| B, lembut | 512 | 178,0 | 33,6 | 144,4 | 39,5 |
| B, lembut | 256 | 178,0 | 33,6 | 144,5 | 39,4 |
| B, lembut | 128 | 177,9 | 33,6 | 144,3 | 39,5 |

Dari 1024 ke 128 px, kontras bidang berubah **0,0%** pada kedua gaya. Downscale bersifat spasial,
bukan tonal: yang hilang adalah batas antar bidang, bukan warna bidangnya. Kontras bidang juga
**tidak membedakan** kedua gaya (144,9 versus 144,4). Jadi angka ini bukan dasar pemilihan gaya.

### Yang benar-benar membedakan: lebar zona transisi tepi

| Gaya | Lebar zona transisi tepi, skala 256 | Putusan |
|---|---|---|
| A, flat | 0,5 px | tepi keras |
| B, lembut | 8,0 px | tepi landai |

Tepi gaya B butuh 8 px untuk berpindah dari warna dinding ke warna pintu, sedangkan gaya A selesai
dalam 0,5 px. Pada gaya B, pintu selebar 34 px kehilangan hampir seperempat lebarnya menjadi zona
kabur, dan tidak ada garis batas yang bisa dipertahankan resampler. Inilah alasan gaya flat dipilih.

### Fitur terkecil yang bertahan

| Sisi fitur, skala 256 | Kedalaman setelah turun ke 128 px | Putusan |
|---|---|---|
| 2 | 0,80 | tidak utuh |
| 3 | 0,98 | utuh |
| 4 | 1,05 | utuh |
| 6 | 1,07 | utuh |
| 8 | 1,06 | utuh |
| 16 | 1,06 | utuh |

Fitur 3 px pada skala 256 masih utuh setelah gambar turun ke 128 px; yang 2 px melemah ke 0,80.
Angka di atas 1,00 muncul karena LANCZOS sedikit menajamkan tepi, bukan galat. Titik lemahnya di
2 px, dan **ambang produksi dipasang di 6 px**, yaitu 2x lipat titik lemah, untuk menutup kompresi
texture dan resampler perangkat yang bukan LANCZOS. Pada sel yang tampil 170 px, 6 px di skala 256
setara 4 px di layar.

Ini penting karena engine Roblox memuat texture mulai dari versi kualitas rendah lalu menaikkannya
sesuai kemampuan perangkat. Gambar harus terbaca pada versi terendah.

**Catatan kejujuran:** yang diuji adalah dua gambar contoh, bukan seluruh katalog bukti. Angka di
atas membuktikan mekanismenya, bukan menjamin setiap gambar masa depan. Karena itu aturannya
dibuat sebagai batas produksi di bagian 5, supaya gaya tetap flat apa pun isi gambarnya. Satu
metrik lagi sempat dicoba, yaitu selisih luma antar bidang, dan dibuang karena selalu bernilai
rasio 1,00 di semua ukuran.

Berkas bukti: `mockups/08-puzzle-style.png`, sumber `mockups/style-flat-1024.png` dan
`mockups/style-grad-1024.png`.

## 3. Grid maksimum 6x6

| Ukuran sheet | Sel 6x6 | Sel 8x8 | Putusan |
|---|---|---|---|
| 1024 | 170 | 128 | 6x6 aman |
| 512 | 85 | 64 | 8x8 terlalu kecil |
| 256 | 42 | 32 | tidak layak untuk grid |

Alasan batas 6x6: pada sheet 1024 px, sel 6x6 berukuran 170 px. Sel 8x8 turun ke 128 px, dan pada
sheet 512 px turun lagi ke 64 px. Di bawah sekitar 64 px, goresan tinta dan lipatan kertas hilang
saat texture diturunkan perangkat.

Angka 64 px adalah **ASUMSI** dari praktik umum UI, bukan angka resmi Roblox. Yang memverifikasi
pada perangkat nyata adalah workstream batas texture dan rating.

## 4. Batas resmi platform

Diambil dari halaman texture specifications di dokumentasi resmi Roblox.

| Jenis texture | Batas resmi | Implikasi |
|---|---|---|
| Texture umum, termasuk gambar UI dan decal | 4096x4096 | Sheet bukti 1024 aman, tidak perlu dipecah karena batas unggah |
| PBR dan UV texture map | 1024x1024 | Hanya relevan bila potongan puzzle jadi material 3D, bukan gambar UI |
| Rekomendasi ukuran per ukuran objek | 256 untuk objek 5x5 stud | Potongan yang tampil kecil di meja cukup 256 |

**Koreksi penting:** ada anggapan bahwa kanvas unggah dibatasi 1024x1024. Untuk texture umum itu
tidak benar, batasnya 4096x4096. Angka 1024x1024 berlaku untuk PBR dan UV texture map, jenis yang
berbeda. Jangan pakai angka 1024 sebagai alasan memecah sheet bukti.

Engine memuat texture mulai dari versi kualitas rendah dan menaikkannya sesuai resource perangkat.
Format yang didukung: `.png`, `.jpg`, `.tga`, `.bmp`. Proyek ini memakai `.png` karena butuh
latar transparan pada potongan.

## 5. Batas produksi untuk pembuat gambar

Aturan yang harus dipatuhi setiap gambar bukti:

1. **Bidang warna rata.** Tidak ada gradien halus, tidak ada glow lembut, tidak ada bayangan
   bertingkat. Kalau butuh kesan bercahaya, pakai satu bidang warna terang dengan tepi tegas.
2. **Tidak ada detail lebih kecil dari 6 px pada skala 256.** Ini 2x lipat titik lemah terukur
   (2 px), dengan margin untuk kompresi texture dan resampler perangkat yang bukan LANCZOS. Pada
   sel yang tampil 170 px, 6 px setara 4 px di layar.
3. **Kontras antar bidang minimal 40 tingkat** pada skala 0 sampai 255. Terukur stabil di semua
   ukuran, jadi dipakai sebagai batas bawah. Ini batas keterbacaan warna, bukan penangkal
   downscale; yang menahan downscale adalah tepi keras di poin 5.
4. **Siluet tebal.** Garis luar minimal 3 px pada ukuran tampil final.
5. **Tepi keras, zona transisi maksimum 2 px pada skala 256.** Ini poin yang paling menentukan:
   tepi gaya B yang landai 8 px kehilangan batas bentuknya saat texture turun, sedangkan tepi
   0,5 px tidak.
6. **Warna dari `tokens.css`.** Tidak ada warna baru di luar token, supaya bukti terlihat satu
   sistem.

## 6. Perilaku ImageRectOffset dan ImageRectSize

Ini perilaku resmi, bukan tafsiran. Keduanya bertipe `Vector2` dan dipakai bersama untuk menampilkan
sebagian gambar.

| Properti | Perilaku resmi | Aturan pakai di Triangulate |
|---|---|---|
| `ImageRectOffset` | Offset piksel dari sudut kiri atas gambar | Dihitung server dari indeks sel, dikirim ke client sebagai satu angka |
| `ImageRectSize` | Ukuran piksel area yang ditampilkan | Selalu diisi eksplisit, kecuali sengaja menampilkan seluruh sheet |
| Keduanya | Bila salah satu dimensi bernilai 0, seluruh gambar ditampilkan | Nilai 0 hanya dipakai sengaja untuk menampilkan sheet penuh |

Perilaku "salah satu dimensi 0 berarti seluruh gambar" adalah jebakan yang perlu diingat: lupa
mengisi `ImageRectSize` bukan menghasilkan potongan kosong, melainkan menampilkan seluruh sheet.
Bug seperti ini terlihat sebagai gambar penuh di dalam slot potongan.

Dokumentasi resmi menyebut sprite sheet sebagai pemakaian yang disarankan, karena menggabungkan
banyak gambar kecil ke satu texture membuat aset lebih cepat dimuat. Ini alasan kedua untuk
keputusan satu sheet per bukti, di samping alasan downscale.

### ResampleMode

`ResampleMode` bertipe `Enum.ResamplerMode` dan menentukan cara gambar diskalakan.

| Nilai | Pakai di |
|---|---|
| `Pixelated` | Potongan bergaya cetak dan dokumen, supaya tepi tetap tajam saat diperbesar |
| `Default` | Foto bukti yang butuh terlihat halus |

### Posisi potongan ditentukan server

PRD §15 menetapkan posisi potongan diatur server dan direplikasi, dengan interpolasi di client agar
halus di mobile. Konsekuensi untuk gaya ilustrasi: gambar potongan harus bisa digambar pada posisi
mana pun tanpa bergantung pada pencahayaan di client. Karena itu tidak ada bayangan yang di-bake ke
dalam gambar potongan. Bayangan digambar oleh engine sebagai efek di atas potongan.

## 7. Langkah produksi satu bukti

1. Tentukan jumlah potongan. Maksimum 36, dan selalu kuadrat agar grid rapi.
2. Susun sheet pada 1024x1024 dengan grid 6x6. Sel berukuran 170 px.
3. Periksa setiap sel pada ukuran tampil terkecil yang direncanakan, bukan pada ukuran penuh.
4. Turunkan sheet ke 512 dan 256, lalu periksa lagi. Detail yang hilang pada 256 harus diperbesar
   atau dihilangkan, bukan dibiarkan.
5. Catat indeks sel dan offsetnya di data kasus. Lihat skema kasus di PRD §10.
6. Simpan sebagai `.png` dengan latar transparan.

## 8. Yang belum diputuskan

| Hal | Menunggu |
|---|---|
| Ukuran sheet final per tipe puzzle | Hasil verifikasi perangkat, workstream batas texture |
| Ambang px detail minimum di bawah 6 px | Sama, karena bergantung pada perangkat terendah yang disasar |
| Berapa tipe puzzle boleh berbagi satu sheet | Keputusan teknis saat implementasi |

Semua angka di bagian 2 dan 3 berasal dari pengukuran yang bisa diulang: `python3
mockups/make_style_samples.py` lalu `python3 mockups/measure_downscale.py`. Halaman
`mockups/puzzle-style.html` menampilkan angka yang sama beserta gambarnya, dan dirender jadi
`mockups/08-puzzle-style.png` oleh `mockups/render.sh`. Tata letak halaman itu diperiksa
`python3 mockups/verify_mockup.py`, yang juga memastikan kesepuluh gambarnya termuat pada enam
lebar point.
