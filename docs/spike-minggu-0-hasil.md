# S0.1 — Hasil: resolusi sheet dan `ImageRectOffset`/`ImageRectSize`

Status: **diukur sebagian**. Satu ambang lulus, satu terjawab sebagian, dua
tidak bisa diukur di lingkungan ini (tanpa perangkat mobile, tanpa otomasi Studio).

Roblox Studio memang terbuka di mesin ini, tetapi jalur otomasinya mati: MCP
Studio menjawab `initialize` lalu mengembalikan `tools/list` kosong dengan
`Timed out waiting for tools to become available` — ia butuh auth Assistant
interaktif di UI Studio. Jadi tidak ada cara menjalankan pengukuran di dalam
engine dari sini. Itu sebabnya angka di bawah berasal dari model gambar, bukan
dari sampler Roblox.

Skrip pengukuran: `/Users/mac/Documents/Roblox/.probe/s01_resolusi.py`
(di luar repo, tidak masuk git). Artefak:
`/Users/mac/Documents/Roblox/.probe/s01_out/`. Angka di bawah semuanya keluaran
skrip itu, bukan perkiraan. Yang diasumsikan ditandai `ASUMSI`.

## 1. Yang tidak bisa diukur di sini

Dinyatakan lebih dulu supaya tidak terbaca sebagai lulus:

| Yang diminta metode | Status |
|---|---|
| Uji di Android kelas bawah, kelas menengah, dan PC | **BELUM TERUKUR** — tidak ada perangkat; otomasi Studio mati |
| Tangkapan layar Roblox nyata sebelum/sesudah | **BELUM TERUKUR** |
| Kompresi texture Roblox yang sebenarnya | **BELUM TERUKUR** — PIL hanya meniru penurunan resolusi, bukan kompresi lossy Roblox |
| `ResampleMode = Default`/`Pixelated` yang sebenarnya | **BELUM TERUKUR** — yang diukur peniru bilinear dan nearest PIL |
| Jank render 16 `ImageLabel` | **BELUM TERUKUR** — butuh perangkat |
| Penilaian 10 penguji atas kecocokan potongan | **BELUM TERUKUR** — butuh manusia |

Konsekuensinya: ambang "waktu render" dan "pencocokan potongan" **tidak dapat
dinyatakan lulus** dari spike ini. Yang bisa disampaikan adalah perilaku
geometris di baliknya, yaitu seberapa dalam dan seberapa kuat pita tercemar di
tepi potongan pada tiap ukuran texture.

## 2. Metode

Sheet 1024×1024, grid 4×4, sel 256×256:

- **A** — flat, gutter 1 px;
- **B** — gradasi/detail halus (`GaussianBlur` radius 12 px pada skala sheet,
  sama dengan `RADIUS_BLUR = 12` di `mockups/make_style_samples.py`), gutter 1 px;
- **C** — flat, tanpa gutter.

Gutter diisi **replikasi tepi sel**, bukan warna asing: bantalan itu sendiri
berisi gambar yang sama dengan tepi potongan, jadi tidak ada warna palsu yang
ikut terukur.

Warna dibaca dari `docs/art/tokens.css` supaya sheet uji dan sheet produksi tidak
bisa berbeda sumber.

### Model render dua tahap

Roblox memuat texture pada resolusi tersimpan `n`, lalu menampilkan potongan
lewat rect `ImageRectOffset`/`ImageRectSize` pada ukuran `t`. Keduanya
dipisahkan:

1. sheet 1024 diturunkan ke resolusi texture `n` (bilinear atau nearest);
2. potongan diambil lewat rect dan ditampilkan pada ukuran `t` dengan sampling
   pada titik tengah piksel: `texel = (x0 + (i+0.5)·sisi/d)·n/1024 − 0.5`.

Rect potongan mengikuti aturan gutter: A/B memotong 254 px (gutter bukan bagian
potongan), C memotong 256 px.

### Pembanding bebas bleeding

Bleeding diukur sebagai **selisih terhadap pipeline yang identik tetapi bebas
tetangga**: seluruh sheet diisi replikasi tepi sel itu sendiri, diturunkan ke `n`,
lalu dipotong dengan rect yang sama. Selisih absolut kedua hasil adalah
kontaminasi murni dari sel tetangga. (Diperiksa: sheet yang dibangun dan sheet
yang disusun ulang dari slot-nya byte-identik, `np.array_equal` = `True` untuk
A, B, dan C — jadi pembanding memang memakai isi sel yang sama, bukan salinan
yang berbeda.)

Diperiksa juga bahwa pembanding tidak menggeser apa pun: pada texture 1:1,
wilayah sel itu sendiri di pembanding **byte-identik** dengan sheet asli
(`np.array_equal` = `True`); pada texture 512, pusat sel di pembanding dan di
sheet asli berbeda **0,0** tingkat luma. Jadi selisih yang terukur memang
terkurung di dekat tepi potongan, bukan merembet ke seluruh potongan.

Yang dilaporkan:

- `dalam_maks` — kedalaman pita tercemar dalam piksel: jarak ke tepi potongan
  terdekat dari tiap piksel yang menyimpang > `TOLERANSI`;
- `puncak_maks` — selisih luma terbesar di pita itu;
- `tercemar` — berapa dari 16 potongan yang punya pita > `TOLERANSI`.

### Konstanta `ASUMSI`

| Konstanta | Nilai | Dasar |
|---|---|---|
| `TOLERANSI` | 2,0 tingkat luma | `ASUMSI`: di bawah ini pembulatan, bukan bleeding |
| `AMBANG_TERLIHAT` | 8,0 tingkat luma | `ASUMSI`: selisih ≥ 8 terbaca mata |
| `AMBANG_FITUR` | 20,0 tingkat luma | `ASUMSI`: kedalaman minimum pola garis supaya terbaca |
| `JARAK_GARIS` | 1, 2, 3, 4, 6, 8 px | `ASUMSI`: sapuan jarak antar garis |
| `ZOOM` | 8× | hanya untuk artefak gambar |

### Satuan "skala 256"

`puzzle-style.md` memakai frasa "skala 256" untuk dua hal yang berbeda. Di sini
keduanya dilaporkan supaya bisa dicocokkan dengan pembaca mana pun:

- `lebar` = mentah × 256/`n` — konvensi **tabel** `puzzle-style.md`, yaitu gambar
  contoh 1024 px yang digambar pada 256 px lalu dinaikkan 4× dan diukur sebagai
  mentah/4 (`measure_downscale.py`, `SKALA_256 = 4`). Ini yang dipakai untuk
  membandingkan dengan A 0,5 px dan B 8,0 px.
- `lebar_sel` = mentah × 1024/`n` — konvensi kalimat "pada sel yang tampil 170 px,
  6 px di skala 256 setara 4 px di layar", yaitu 1 sel = 256 px. Selalu 4× kolom
  pertama.

## 3. Hasil

### 3.1 Bleeding (bilinear)

| Gaya | Texture | Tampil | Potongan | `dalam_maks` | `puncak_maks` | Tercemar |
|---|---|---|---|---|---|---|
| A | 1024 | 1024 | 254 px | 0 | 0,0 | 0/16 |
| A | 1024 | 512 | 127 px | 0 | 0,0 | 0/16 |
| A | 1024 | 384 | 95 px | 0 | 0,0 | 0/16 |
| A | 1024 | 256 | 64 px | 0 | 0,0 | 0/16 |
| A | 512 | 512 | 127 px | 1 | 24,2 | 16/16 |
| A | 384 | 384 | 95 px | 1 | 27,6 | 16/16 |
| A | 256 | 256 | 64 px | 1 | 35,2 | 16/16 |
| A | 256 | 512 | 127 px | 3 | 103,0 | 16/16 |
| B | 1024 | 1024 | 254 px | 0 | 0,0 | 0/16 |
| B | 512 | 512 | 127 px | 1 | 24,0 | 16/16 |
| B | 384 | 384 | 95 px | 1 | 28,0 | 16/16 |
| B | 256 | 256 | 64 px | 1 | 35,6 | 16/16 |
| B | 256 | 512 | 127 px | 3 | 107,0 | 16/16 |
| C | 1024 | 1024 | 256 px | 0 | 0,0 | 0/16 |
| C | 1024 | 512 | 128 px | 0 | 0,0 | 0/16 |
| C | 1024 | 384 | 96 px | 0 | 0,0 | 0/16 |
| C | 1024 | 256 | 64 px | 0 | 0,0 | 0/16 |
| C | 512 | 512 | 128 px | 1 | 45,0 | 16/16 |
| C | 384 | 384 | 96 px | 1 | 42,0 | 16/16 |
| C | 256 | 256 | 64 px | 1 | 45,0 | 16/16 |
| C | 256 | 512 | 128 px | 3 | 141,5 | 16/16 |

Dengan nearest (`Pixelated`): `dalam_maks` = 0 dan `puncak_maks` = 0,0 pada
**semua** baris di atas, tanpa kecuali.

Tiga hal yang terbaca:

1. **Bleeding itu artefak penurunan resolusi, bukan artefak pemotongan.** Pada
   texture 1:1 (1024 → 1024) ketiga sheet bersih sempurna. Begitu texture
   diturunkan ke 512/384/256, pita tercemar muncul di semua potongan. Ini
   menyokong kutipan staf di rencana spike: yang salah bukan rect-nya, melainkan
   sampling linier yang mencampur piksel tetangga.
2. **Gutter menurunkan kuat bleeding, tidak menghapusnya.** Pada kedalaman pita
   yang sama, `puncak_maks` C selalu lebih tinggi dari A/B: 45,0 vs 24,2 (512),
   42,0 vs 27,6 (384), 45,0 vs 35,2 (256), 141,5 vs 103,0 (256→512). Selisihnya
   22–46%. Jadi gutter 1 px bekerja, tetapi **belum cukup**: A/B masih menyisakan
   pita 1–3 px dengan puncak 24–36 tingkat luma pada penurunan yang setara
   (512, 384, 256), dan 103–107 pada 256 → 512 — semuanya di atas ambang
   terlihat 8,0.
3. **Kedalaman pita identik untuk A, B, dan C** (1 px pada penurunan setara,
   3 px pada 256 → 512). Gutter mengubah *seberapa kuat* kontaminasi, bukan
   *seberapa jauh* ia merambat. Rambatan itu ditentukan lebar kernel resampler,
   bukan lebar gutter.

### 3.2 Sapuan lebar gutter

Karena ambang pertama bertanya apakah gutter menyelesaikan, lebar gutter disapu
0–12 px dengan builder sheet yang sama (`s01_gutter_probe.py`):

| Gutter | 512→512 | 256→256 | 256→512 |
|---|---|---|---|
| 0 px | 45,0 | 45,0 | 141,5 |
| 1 px | 24,2 | 35,2 | 103,0 |
| 2 px | 0,0 | 24,2 | 35,1 |
| 3 px | 0,0 | 24,7 | 26,0 |
| 4 px | 0,0 | 0,0 | 24,7 |
| 6 px | 0,0 | 0,0 | 0,0 |
| 8 px | 0,0 | 0,0 | 0,0 |
| 12 px | 0,0 | 0,0 | 0,0 |

(angka = `puncak_maks`, bilinear, gaya A; B memberi pola yang sama)

Mekanismenya jadi jelas: gutter baru benar-benar menutup bleeding kalau
**lebih lebar dari jangkauan kernel resampler** pada resolusi tersimpan. Ambang
terukurnya: 2 px untuk penurunan 2× (1024 → 512), 4 px untuk penurunan 4×
(1024 → 256), dan 6 px untuk penurunan 4× yang lalu diperbesar 2× saat ditampilkan
(256 → 512). Gutter 1 px yang dipakai metode spike berada di bawah semua ambang
itu, sehingga hanya memotong puncak bleeding sebesar 27–46% (45,0 → 24,2 pada
512; 141,5 → 103,0 pada 256 → 512), tidak menghapusnya.

`ASUMSI`: angka ambang lebar ini bergantung pada peniru bilinear PIL. Roblox
memakai sampler-nya sendiri, jadi **lebar gutter minimum yang sebenarnya BELUM
TERUKUR**.

### 3.3 Kontras bidang

| Gaya | px | Terang | Gelap | Kontras | Simpangan baku | Gradien dalam sel |
|---|---|---|---|---|---|---|
| A | 1024 | 216,9 | 17,0 | 200,0 | 90,67 | 3,44 |
| A | 512 | 215,6 | 18,3 | 197,3 | 89,32 | 6,93 |
| A | 384 | 213,7 | 20,2 | 193,5 | 88,99 | 9,31 |
| A | 256 | 211,7 | 22,2 | 189,4 | 87,75 | 13,34 |
| B | 1024 | 210,5 | 35,0 | 175,6 | 67,39 | 2,37 |
| B | 512 | 209,2 | 36,5 | 172,7 | 67,23 | 4,73 |
| B | 384 | 207,7 | 37,8 | 169,9 | 67,26 | 6,36 |
| B | 256 | 206,0 | 39,6 | 166,3 | 67,33 | 9,40 |
| C | 1024 | 216,9 | 17,0 | 200,0 | 90,50 | 3,40 |
| C | 512 | 214,3 | 19,6 | 194,7 | 89,21 | 6,87 |
| C | 384 | 213,7 | 20,2 | 193,5 | 88,92 | 9,28 |
| C | 256 | 211,7 | 22,2 | 189,4 | 87,79 | 13,29 |

Kontras bidang turun sedikit (A −5,3%, B −5,3%) dari 1024 ke 256, bukan nol
seperti di `puzzle-style.md`. Bedanya metode: di sana kotak sampling berukuran
fraksi tetap (`KOTAK` di `measure_downscale.py`) dan tepi keras jatuh di luar
kotak; di sini cincin tepi sel ikut terukur, jadi kaburnya tepi terbaca sebagai
penurunan kontras. **Angka kontras di sini tidak sebanding langsung dengan tabel
144,9 / 144,4 di `puzzle-style.md`.**

Yang tetap sama arahnya: **A lebih kontras dari B** (200,0 vs 175,6 pada 1024;
189,4 vs 166,3 pada 256). C setara A, sesuai harapan karena isinya identik.

### 3.4 Lebar zona transisi tepi bentuk

| Gaya | px | Mentah (px texture) | `lebar` (konvensi tabel) | `lebar_sel` |
|---|---|---|---|---|
| A | 1024 | 2,0 | **0,50** | 2,00 |
| A | 512 | 3,0 | 1,50 | 6,00 |
| A | 256 | 3,0 | 3,00 | 12,00 |
| B | 1024 | 34,0 | **8,50** | 34,00 |
| B | 512 | 18,0 | 9,00 | 36,00 |
| B | 256 | 10,0 | 10,00 | 40,00 |
| C | 1024 | 2,0 | 0,50 | 2,00 |
| C | 512 | 4,0 | 2,00 | 8,00 |
| C | 256 | 4,0 | 4,00 | 16,00 |

Dengan konvensi tabel, A 1024 memberi **0,50** dan B 1024 memberi **8,50** —
cocok dengan preseden `puzzle-style.md` (A 0,5 px, B 8,0 px). Pengukuran ini
memakai rumus zona 10%–90% yang identik dengan `lebar_transisi()` di
`measure_downscale.py`. Cocoknya kedua angka ini menunjukkan bahwa kalibrasi gaya
B di skrip (radius blur 12 px) memang pada skala yang sama dengan preseden.

Perhatikan bahwa lebar transisi B **naik** relatif sedikit saat resolusi turun
(8,5 → 10,0) sedangkan A naik lebih banyak (0,5 → 3,0). Yang penting untuk
pencocokan potongan bukan laju kenaikannya, melainkan nilai akhirnya: pada
resolusi terendah yang diuji, tepi A masih 3,0 px sementara tepi B 10,0 px.

### 3.5 Pola garis 1 px setelah penurunan skala

Gaya A (nominal 220,8 tingkat luma):

| Tampil | Jarak | Bilinear | Nearest |
|---|---|---|---|
| 256 | 1–8 | 220,8 (rasio 1,00) | 220,8 (rasio 1,00) |
| 128 | 1 | 37,9 (0,17) | **0,0** |
| 128 | 2 | 58,1 (0,26) | 220,8 (1,00) |
| 128 | 3 | 82,8 (0,38) | **0,0** |
| 96 | 2 | **13,0 (0,06)** | 220,8 (1,00) |
| 64 | 2 | **15,9 (0,07)** | 220,8 (1,00) |
| 64 | 4 | **11,9 (0,05)** | 220,8 (1,00) |

Gaya B (nominal 58,7 tingkat luma pada jarak 1):

| Tampil | Jarak | Bilinear | Nearest |
|---|---|---|---|
| 256 | 1 | 58,7 (1,00) | 58,7 (1,00) |
| 256 | 6, 8 | 17,3 / 16,6 | 17,3 / 16,6 |
| 128 | 1–4 | 0,96–1,00 | 0,94–0,98 |
| 64 | 1–3 | 0,89–0,95 | 0,87–0,93 |

Dua temuan:

- **Gaya flat (A) menahan fitur jauh lebih baik pada ukuran tampil penuh.**
  Pada 256, garis A punya kedalaman 220,8 tingkat luma, sedangkan garis B hanya
  58,7–16,6 (dan pada jarak 6–8 sudah di bawah ambang baca 20,0). Komposisi B
  memang sudah lemah sebelum diturunkan.
- **Ada silang di bawah 128 px.** Garis 1 px gaya A hancur oleh penurunan skala
  (rasio 0,17 pada 128; terburuk 0,05 pada 64 px jarak 4), sedangkan garis B
  turun hanya ke rasio ~0,89. Dalam nilai absolut pun B menang
  di situ (56,7 vs 37,9 pada 128). Ini
  efek **lebar fitur**, bukan efek kualitas gaya: garis A yang 1 px menjadi
  sub-piksel saat diturunkan 2×, sementara tepi garis B sudah ~8 px (kolom
  `lebar` tabel 3.4) sehingga tidak pernah menjadi sub-piksel.
  Jadi klaim "flat lebih tahan downscale" benar untuk bidang dan tepi, tetapi
  **tidak** untuk detail bergaris setipis 1 px — di situ gaya berblur justru
  lebih lentur karena fiturnya sejak awal lebih lebar.

## 4. Putusan terhadap ambang S0.1

Ambang dikutip persis dari `docs/spike-minggu-0.md`:

| Ukuran | Lulus | Gagal | Hasil pengukuran |
|---|---|---|---|
| Garis tepi (bleeding) pada sheet C | Terlihat jelas, A/B tidak | A/B sama buruknya → gutter tidak menyelesaikan | **Sebagian** — lihat bawah |
| Pencocokan potongan | ≥ 9 dari 10 penguji mencocokkan 4 potongan berturut-turut tanpa ragu | < 7 dari 10 | **BELUM TERUKUR** |
| Perbedaan A vs B | A bertahan lebih baik (indikasi gaya flat lebih tahan kompresi) | Tidak ada perbedaan → gaya bukan variabel | **Lulus** — lihat bawah |
| Waktu render 16 potongan | Tidak ada jank yang terlihat pada perangkat kelas bawah | Jank terlihat | **BELUM TERUKUR** |

**Bleeding (sebagian).** Syarat "C terlihat jelas" terpenuhi: puncak C selalu
tertinggi (45,0 / 42,0 / 45,0 / 141,5 vs A/B 24,0–35,6 dan 103,0–107,0). Syarat
"gutter tidak menyelesaikan" **tidak** terpenuhi: A/B jelas lebih baik dari C
selisih 22–46%, jadi gutter berpengaruh. Tetapi syarat "A/B tidak [terlihat]"
juga tidak terpenuhi: A/B masih menyisakan pita dengan puncak 24–36 tingkat luma,
di atas ambang terlihat 8,0. Kesimpulan: **gutter 1 px memperbaiki, belum
menghilangkan.** Sapuan lebar menunjukkan penyebabnya — gutter harus lebih lebar
dari jangkauan kernel resampler — 4 px untuk penurunan 4×, dan 6 px bila
potongan itu lalu diperbesar saat ditampilkan. Perlu dikonfirmasi di perangkat
nyata.

**A vs B (lulus).** Ada perbedaan besar dan konsisten, jadi "tidak ada perbedaan"
tidak berlaku. A bertahan lebih baik pada dua ukuran yang menentukan pencocokan
potongan: lebar zona transisi tepi (0,50–3,00 px vs 8,50–10,00 px) dan kontras
bidang (200,0 vs 175,6 pada 1024). Catatan kejujuran: untuk detail bergaris
setipis 1 px, B justru lebih lentur di bawah 128 px (bagian 3.5). Keunggulan A
bukan "semua fitur lebih tahan", melainkan "tepi dan bidang lebih tegas" — dan
itu tepat yang dibutuhkan potongan puzzle untuk dicocokkan.

## 5. Perbandingan dengan `docs/art/puzzle-style.md`

| Klaim `puzzle-style.md` | Angka di sana | Angka di sini | Putusan |
|---|---|---|---|
| Lebar zona transisi A | 0,5 px | 0,50 px | **Sejalan** |
| Lebar zona transisi B | 8,0 px | 8,50 px | **Sejalan** |
| Kontras bidang A vs B tidak membedakan gaya | 144,9 vs 144,4 | 200,0 vs 175,6 | **Tidak sebanding** — beda metode sampling (kotak fraksi tetap vs cincin tepi sel); arahnya sama, A lebih kontras |
| Flat lebih tahan downscale | dipilih | ya, untuk tepi dan bidang; tidak untuk garis 1 px | **Sejalan dengan kualifikasi** |
| Fitur 2 px melemah (0,80), 3 px utuh (0,98), ambang produksi 6 px | 2/3/6 px | A 256 terbaca sampai 1 px; di bawah 128 px garis 1 px hilang | **Sejalan** — preseden mengukur fitur persegi pada 128 px, di sini garis 1 px pada beberapa ukuran tampil; bentuk dan ukuran berbeda, jadi angkanya tidak sebanding langsung |
| Satu sheet per bukti, grid maks 6×6 | keputusan | grid 4×4 diuji; 6×6 belum | **Belum diuji** |

Tidak ada klaim `puzzle-style.md` yang tersanggah. Yang perlu dijaga: dua
perbedaan metode pengukuran di atas (kontras memakai kotak sampling berbeda;
fitur memakai bentuk berbeda) membuat angkanya tidak boleh dibandingkan
langsung lintas dokumen — hanya arah dan urutannya yang sebanding.

## 6. Yang perlu diukur berikutnya

1. **Uji perangkat nyata** untuk ambang jank dan tangkapan layar sebelum/sesudah
   (butuh otomasi Studio + Android kelas bawah + iPhone/Android menengah + PC).
2. **Uji 10 penguji** untuk ambang kecocokan potongan.
3. **Lebar gutter minimum** di sampler Roblox sebenarnya — model di sini
   menyarankan sekitar 6 px untuk penurunan 4×, tetapi itu keluaran bilinear PIL.
4. **Biaya `Pixelated`.** Model menunjukkan nearest menghapus bleeding sepenuhnya,
   tetapi model itu tidak menangkap aliasing/shimmering yang diperingatkan staf.
   Apakah biaya itu lebih ringan dari bleeding, belum terukur.
5. **Grid 6×6** (sel 170 px), sesuai batas yang dipilih `puzzle-style.md`.

## 7. Artefak

Di `/Users/mac/Documents/Roblox/.probe/s01_out/` (di luar repo, tidak masuk git):

- `sheet_{A,B,C}_1024.png` — tiga sheet uji;
- `sheet_{gaya}_{512,384,256}_bilinear.png`, `sheet_{gaya}_256_nearest.png` —
  texture pada tiap resolusi;
- `banding_{gaya}_{512ke512,256ke256,256ke512}_{bilinear,nearest}.png` — pita di
  sekitar batas sel: potongan asli, pembanding bebas bleeding, dan selisihnya
  diperbesar 8× (18 berkas);
- `uji_fitur_{A,B}_256.png` — kanvas pola garis;
- `s01_hasil.json` — seluruh angka mentah.

Skrip: `/Users/mac/Documents/Roblox/.probe/s01_resolusi.py` (pengukuran utama),
`/Users/mac/Documents/Roblox/.probe/s01_gutter_probe.py` (sapuan lebar gutter).

Pemeriksaan visual gambar tidak dapat dilakukan di lingkungan ini (tidak ada
model visi, tidak ada Studio). Sebagai gantinya, panel selisih tiap berkas
`banding_*` diukur numerik. Berkas itu hanya memuat 20 baris teratas pita batas
sel (0,0)|(1,0), jadi puncaknya tidak selalu sama dengan `puncak_maks` tabel 1
yang menyapu seluruh potongan. Yang terukur di panel selisih, 256 → 512 bilinear:
**141,5 (C)** vs **26,0 (A)** dan **27,0 (B)**. Urutannya tetap C paling parah,
sesuai tabel 1. (Pada PNG, penguatan 8× membuat panel C jenuh di 255 — artinya
selisih aslinya ≥ 32, bukan berarti hanya 32.) Pita yang tampak lebar (24 kolom
tampil ≈ 12 px di tiap sisi
batas) masuk akal: pada 256 → 512 setiap texel texture melayani 2 px tampil,
sehingga jangkauan kernel resampler memang beberapa piksel. Untuk A dan B, baris
0–20 kebetulan bukan baris terparah, jadi angka panel lebih rendah dari
`puncak_maks` tabel 1 (103,0 dan 107,0) — keduanya konsisten, bukan bertentangan.
