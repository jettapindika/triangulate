# Spesifikasi UI mobile

Aturan tata letak, ukuran target sentuh, dan state wajib untuk enam layar Triangulate.

Lampiran visual: `mockups/07-ui-spec.png`. Mockup lengkap: `mockups/01-handler-table.png` sampai
`06-case-recap.png`, atau gabungan di `mockups/09-all-screens.png`.

## 1. Satuan

**Semua angka di dokumen ini adalah point offset Roblox, bukan piksel fisik perangkat.**

Ini bukan detail sepele. `Camera.ViewportSize` mengembalikan safe area dalam UI offset units, dan
satuannya bukan piksel. Perangkat dengan kepadatan layar berbeda punya jumlah point yang berbeda
untuk lebar fisik yang sama. Akibatnya:

| Kalau salah | Akibatnya |
|---|---|
| Menganggap point sama dengan piksel | Kontrol terlihat benar di satu ponsel dan terlalu kecil di ponsel lain |
| Memakai posisi piksel tetap | Layout rusak saat lebar point berbeda |

Karena itu layout memakai skala `UDim2`, bukan posisi piksel tetap.

`Camera.ViewportSize` juga sudah mengecualikan top bar Roblox, notch, dan home indicator. Untuk
mendapat dimensi layar mentah, `ScreenGui` perlu `ScreenInsets` bernilai `Enum.ScreenInsets.None`.

## 2. Target sentuh

| Elemen | Minimum | Catatan |
|---|---|---|
| Aksi utama: Report, Tuduh, Siap | 56 | Tinggi penuh, melebar |
| Aksi sekunder: senter UV, Ping, Peta | 48 | Ikon disertai label teks |
| Potongan puzzle | 48 | Area sentuh lebih besar dari gambar potongan |
| Kartu clue | 48 | Seluruh kartu bisa diseret, bukan hanya judulnya |
| Slot ping wheel | 62 | Lebar 96, jarak antar slot 8 |
| Baris daftar role di lobby | 62 | Tinggi baris, bukan tinggi teks |

### Yang bukan target sentuh

Chip role dan chip status di mockup (`<span class="chip">`) adalah **label, bukan kontrol**. Ukurannya
92 sampai 138 kali 26 sampai 27 point, di bawah minimum, dan itu memang disengaja: tidak ada satu pun
yang bisa ditekan. Chip menyatakan siapa pemegang informasi pada baris itu, dan itu dibaca, bukan
disentuh. Yang perlu target sentuh adalah baris yang memuatnya, dan baris itu 62 point.

Aturan yang membedakan keduanya: kalau sebuah elemen punya handler sentuh, ukurannya wajib 44 point
atau lebih. Kalau tidak, ukurannya mengikuti tipografi. Menuliskan batas ini penting supaya tidak ada
yang memperbesar chip menjadi tombol yang tidak melakukan apa pun.

Aturan tambahan:

- Jarak antar target minimal **8 point**, supaya salah tekan tidak terjadi saat pemain berjalan.
- Ukuran **36 point** atau kurang tidak boleh dipakai untuk aksi apa pun.
- `UISizeConstraint` dengan `MinSize = Vector2.new(48, 48)` dipakai sebagai pengaman pada kontrol
  yang ukurannya mengikuti isi.

### Status angka ini

Angka 48 dan 56 adalah **ASUMSI**, bukan angka resmi Roblox. Nilainya berasal dari panduan
aksesibilitas industri: minimum 44 px, optimal 48 px, jarak antar target minimal 8 px. Angka 44 px
dikenal dari panduan antarmuka Apple dan WCAG 2.1 SC 2.5.5 Target Size.

Yang memverifikasi pada perangkat nyata adalah workstream batas texture dan rating. Kalau hasil
verifikasi menurunkan atau menaikkan angka ini, `tokens.css` yang diubah, bukan dokumen ini saja.

## 3. Breakpoint

| Lebar | Perangkat | Yang berubah |
|---|---|---|
| 320 point | Ponsel kecil, kelas bawah | Grid clue board 2 kolom, label tombol bisa disembunyikan, ikon tetap |
| 390 point | Ponsel standar | Acuan mockup. Grid clue board 3 kolom |
| 430 point | Ponsel besar | Grid clue board 4 kolom, panel samping melebar |
| 16:9 lanskap | Semua | Panel kanan pindah ke samping, tinggi konten dikurangi |

Aturan yang berlaku di semua breakpoint:

1. Tidak boleh ada overflow horizontal pada lebar 320 point.
2. Teks panjang turun baris, tidak dipotong dan tidak memakai elipsis pada teks yang bermakna.
3. Target sentuh tidak pernah mengecil di bawah minimum, walau ruang sempit. Kalau tidak cukup,
   yang dikurangi adalah jumlah elemen yang tampil sekaligus, bukan ukurannya.
4. Safe area diambil dari `GuiService` supaya notch dan home indicator tidak menutup kontrol.

## 4. State wajib tiap layar

Setiap layar berdata harus punya kelima state ini. Mockup menampilkan state terisi, karena state
terisi adalah yang paling padat dan paling menentukan tata letak.

| State | Isi | Catatan |
|---|---|---|
| Kosong | Belum ada clue, meja belum terisi, belum ada pemain | Menjelaskan langkah berikutnya, bukan hanya kosong |
| Memuat | Memuat kasus, sinkronisasi state dari server | Ada indikator, tidak ada layar putih |
| Galat | Koneksi putus, kasus gagal dimuat, pemain keluar | Ada jalan keluar, bukan hanya pesan |
| Fokus | Cincin lampu 3 point | Kontras di atas 3:1 di semua latar |
| Nonaktif | Kontrol terkunci | Menampilkan syaratnya, bukan tombol mati tanpa penjelasan |

Aturan nonaktif layak diperhatikan. Form tuduhan terkunci karena gerbang deduksi belum terpenuhi
(PRD §5) harus menampilkan berapa deduksi kunci yang sudah selesai, bukan tombol abu-abu tanpa
keterangan. Tombol mati tanpa alasan membuat pemain mengira game rusak.

## 5. Per layar

### Layar 1: Meja puzzle Handler

| Aspek | Nilai |
|---|---|
| Kamera | Scriptable top-down, raycast ke bidang meja (PRD §15) |
| Ukuran potongan | Area sentuh 48, gambar lebih kecil dari area sentuh |
| Wilayah kerja | Kolam cahaya di tengah, sekitar 35 persen layar |
| Kontrol bawah | Aksi sekunder 48, aksi utama 56 |
| State kritis | Meja kosong sebelum kunci diberikan, potongan terkunci menampilkan asal kuncinya |

Posisi potongan diatur server dan direplikasi, dengan interpolasi di client agar halus di mobile
(PRD §15). Mockup menggambar posisi akhir, bukan animasi.

### Layar 2: Clue board Director

| Aspek | Nilai |
|---|---|
| Grid clue board | 2 kolom pada 320, 3 pada 390, 4 pada 430 |
| Kartu clue | Area sentuh 48, seluruh kartu bisa diseret |
| Penanda kontradiksi | `alert` plus ikon plus label, tidak pernah warna saja |
| Gerbang tuduhan | Menampilkan hitungan deduksi kunci, misal "3 dari 4" (PRD §5) |
| State kritis | Belum ada clue, kombinasi salah, form tuduhan terkunci |

Feedback kombinasi salah hanya menyebut jumlah field yang benar, tidak menyebut field mana (PRD §5).
Tampilan tidak boleh membocorkan lebih dari itu.

### Layar 3: Ping wheel

| Aspek | Nilai |
|---|---|
| Slot | 6 sampai 8, sesuai PRD §7 |
| Ukuran slot | 62, lebar 96, jarak 8 |
| Isi | Frasa berubah sesuai role dan situasi |
| Akses alternatif | Teks chat opsional tetap ada (PRD §7) |
| State kritis | Slot yang tidak relevan dinonaktifkan, tidak disembunyikan |

Frasa di mockup dikutip dari contoh PRD §7 sebagai placeholder. Teks final dimiliki workstream
konten kasus dan copy.

### Layar 4: HUD Searcher

| Aspek | Nilai |
|---|---|
| Target marker | Ikon di HUD plus arah kompas (PRD §7) |
| Pinpoint | Marker dari Director terlihat di dunia |
| Report Card | Satu aksi utama 56, foto objek plus tag lokasi otomatis |
| Senter | Kontrol sekunder 48, dengan state hidup dan mati |
| State kritis | Objek terkunci, objek sudah dicek, tidak ada marker aktif |

### Layar 5: Lobby dan role card

| Aspek | Nilai |
|---|---|
| Pilihan role | Dua preferensi berurutan (PRD §3, §8) |
| Baris role | Tinggi 62, seluruh baris bisa disentuh |
| Timer lobby | 45 detik, bisa diperpanjang sampai 90 (PRD §8) |
| Ready check | 10 detik sebelum mulai (PRD §8) |
| Role card | "Kamu tahu apa / Tidak tahu apa / Tugas pertamamu" (PRD §9) |
| State kritis | Menunggu pemain, NPC mengisi slot, pemain tidak ready |

### Layar 6: Case Recap

| Aspek | Nilai |
|---|---|
| Isi | Kontribusi tiap role (PRD §11) |
| Rank | S/A/B/C dari waktu, jumlah tuduhan, hint terpakai (PRD §5) |
| Tombol | Bagikan, main lagi, kembali. Satu aksi utama 56 |
| State kritis | Kasus gagal jadi Cold Case, ada rank terendah |

Layar ini dirancang untuk bisa di-screenshot (PRD §11), jadi semua informasi penting harus masuk
dalam satu layar tanpa perlu menggulir.

## 6. Aksesibilitas

| Aturan | Nilai | Bukti |
|---|---|---|
| Kontras teks | Minimal 4.5:1 | 65 pasangan diuji, semua lulus |
| Kontras komponen dan grafis | Minimal 3:1 | 18 pasangan diuji, semua lulus |
| Pemisahan warna role | CIE76 minimal 25 di 4 mode penglihatan | 12 pasangan diuji, semua lulus |
| Fokus keyboard | Cincin lampu 3 point, kontras 8.67:1 di `noir-700` | Terpasang di mockup |
| Warna sebagai satu-satunya penanda | Dilarang | Setiap chip role disertai ikon dan label |

Angka lengkap ada di `palette.json` dan bisa dijalankan ulang dengan `python3 palette_final.py`.

## 7. Cara memverifikasi mockup

Mockup adalah HTML statis, jadi tidak ada perilaku yang bisa diklik. Verifikasi dilakukan lewat
inspeksi, bukan lewat interaksi, dan itu perlu dinyatakan supaya tidak terkesan diklaim.

Yang sudah diverifikasi:

| Yang diperiksa | Cara | Hasil |
|---|---|---|
| Tidak ada overflow horizontal | `scrollWidth` dibandingkan `clientWidth` di DOM | 0 pada 320, 360, 390, 430, 768, dan 1400 point, untuk kedua halaman |
| Teks tidak keluar container | Tiap elemen dibandingkan `scrollWidth` dengan `clientWidth` | Tidak ada yang terpotong di keenam lebar |
| Enam layar dan satu lembar spesifikasi ada | Dihitung di DOM | 6 layar dan 1 lembar, sesuai rancangan |
| Target sentuh | Setiap `button` diukur `getBoundingClientRect()` | 10 tombol, tidak ada yang di bawah 44 point |
| Chip bukan kontrol | Setiap `.chip` dicari induk `button` atau `a` | 14 chip, 0 di dalam kontrol, semuanya `<span>` |
| Font benar-benar terpakai | Lebar teks diukur di canvas dengan keluarga token, lalu dibandingkan dengan dua fallback | Keempatnya berbeda dari fallback: Nunito 271.68, Merriweather 273.87, Special Elite 297.66, Roboto Mono 316.85, lawan serif 235.78 dan mono 317.88 |
| Halaman gaya puzzle | Lebar dokumen, gambar rusak, dan jumlah sel | 10 gambar, 0 gagal dimuat, 102 sel tabel, 0 overflow di keenam lebar |

Seluruh baris di atas dihasilkan `python3 verify_mockup.py`, yang menjalankan Chrome headless dan
membaca hasilnya dari DOM. Skrip keluar dengan kode 1 kalau ada satu saja yang gagal, jadi hasilnya
bisa diperiksa ulang tanpa menebak.

```bash
cd docs/art/mockups
python3 verify_mockup.py
```

Uji font memakai perbandingan lebar teks, bukan `document.fonts.check()`. `check()` menanyakan apakah
satu berat tertentu tersedia, dan jawabannya `false` untuk berat yang memang tidak dimuat halaman.
Yang perlu dibuktikan bukan itu, melainkan apakah keluarga yang diminta benar-benar dipakai. Kalau
lebarnya berbeda dari kedua fallback, fontnya terpakai. Keempat keluarga lolos.

Nama keluarga font pernah tidak cocok dengan yang dimuat Google Fonts: `SpecialElite` dan `RobotoMono`
adalah nama di Roblox, sedangkan Google Fonts memuat `Special Elite` dan `Roboto Mono`. Selama tidak
cocok, dua keluarga itu jatuh ke fallback tanpa terlihat rusak. Sekarang `tokens.css` memakai nama
Google Fonts.

### Kenapa tombol mockup tidak berperilaku

Sepuluh tombol di mockup menggambar bentuk, ukuran, dan posisi kontrol, bukan menjalankan aksi. Itu
dinyatakan di dua tempat supaya tidak terbaca sebagai kelalaian: satu paragraf di dalam lembar
spesifikasi mockup, dan satu penanda `TODO(mockup)` di dalam sumber setiap layar yang punya tombol.
Setiap penanda menyebut perilaku apa yang diminta dan di bagian mana tabelnya.

Alasannya: mockup HTML ini adalah lampiran tata letak, bukan prototipe. Perilaku nyata tiap tombol
bergantung pada state server yang belum ada di luar Roblox, jadi perilaku itu masuk lingkup
implementasi, bukan lingkup lampiran. Yang bisa dan sudah diperiksa di sini adalah hal yang memang
milik lampiran: ukuran, kontras, posisi, dan tidak ada overflow.

Yang belum diverifikasi, dan butuh perangkat nyata:

- Sentuhan sebenarnya pada layar ponsel.
- Perilaku safe area pada perangkat berponi.
- Performa render pada perangkat kelas bawah.
- Pembacaan layar oleh pembaca layar.

Semua ini masuk lingkup verifikasi perangkat workstream teknis.

## 8. Cara render ulang

```bash
cd docs/art/mockups
./render.sh
```

Skrip butuh Chrome atau Chromium headless. Kalau lokasinya berbeda dari default, set `CHROME`:

```bash
CHROME=/path/ke/chrome ./render.sh
```

Skrip menghasilkan 9 PNG: enam layar pada 780x1688, satu lembar spesifikasi, satu halaman gaya
puzzle, dan satu gabungan.
