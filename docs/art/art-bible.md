# Art bible Triangulate

Arah visual untuk game co-op misteri 3 pemain, target rating 13+, mayoritas dimainkan di mobile.

Dokumen ini menetapkan bentuk, bukan isi. Semua kalimat yang muncul di UI, nama kasus, dan angka
metrik dimiliki oleh workstream lain (lihat bagian 9).

## 0. Design Read

**UI game co-op misteri untuk pemain 13+ di mobile, bahasa visual cozy noir berkas cahaya lampu
meja, dial ENERGY 2 / RHYTHM 2 / MOTION 1.**

Dial rendah disengaja. Sesi berjalan 15 sampai 30 menit dan pemain membaca teks bukti dalam waktu
lama, jadi layar tidak boleh bergetar, berkedip, atau menuntut perhatian terus-menerus. Energi
rendah juga menjaga jarak dari bahasa visual gacha dan battle pass yang mendorong pembelian.

Sumber arah: PRD v0.2 §3 (tema cozy noir disetujui: pencurian, pemalsuan, sabotase, orang hilang,
tanpa gore) dan §19 ("low-poly noir hangat dengan lampu meja sebagai identitas Handler").

## 1. Motif identitas: kolam cahaya lampu meja

Satu motif yang muncul di seluruh permukaan: **kolam cahaya** dari lampu meja, berupa gradien
radial hangat dengan tepi jatuh yang tegas.

Tiga pemakaian, satu bentuk:

| Tempat | Bentuk | Arti |
|---|---|---|
| Meja Handler | Gradien radial di tengah bidang meja | Wilayah kerja yang terang, sisanya gelap |
| Cincin fokus | Cincin 3 point warna `lamp-300` | Elemen yang sedang aktif atau dipilih |
| Senter Searcher | Kerucut cahaya dari titik pandang | Arah pandang, sekaligus batas pandang |

Alasan: PRD §19 menyebut lampu meja sebagai identitas visual Handler. Dengan memakai bentuk yang
sama untuk fokus dan senter, pemain belajar satu bahasa visual saja, bukan tiga. Handler bekerja di
bawah lampu, Searcher membawa cahaya sendiri, dan Director melihat bukti yang sudah diterangi.

## 2. Palet

Sumber angka: `docs/art/palette.json`, hasil skrip verifikasi. Semua nilai di bawah sudah diuji dan
lulus, tidak ada yang dipilih dengan mata saja.

### Base gelap

Base adalah cokelat-hitam hangat, seperti kayu tua di bawah lampu, bukan hitam murni dan bukan biru
dingin.

| Token | Nilai | Pakai |
|---|---|---|
| `noir-950` | `#0B0908` | Void terluar, latar dokumen di luar meja |
| `noir-900` | `#14100E` | Latar terdalam |
| `noir-800` | `#1D1815` | Latar panel standar |
| `noir-700` | `#282019` | Panel terangkat, kartu |
| `noir-600` | `#35291F` | Permukaan hover |
| `noir-500` | `#46372A` | Dekoratif saja |
| `noir-400` | `#5E4B3A` | Dekoratif saja |

Alasan base hangat: PRD §19 meminta noir **hangat**. Hitam murni akan terbaca dingin dan
bertabrakan dengan lampu meja sebagai identitas.

`noir-500` dan `noir-400` **gagal** ambang 3:1 untuk garis dan ikon bermakna, jadi keduanya
diturunkan perannya menjadi dekoratif saja. Penggantinya `line` dan `icon-mute`.

### Garis, kertas, cahaya

| Token | Nilai | Pakai |
|---|---|---|
| `line` | `#7A7168` | Garis pemisah, tepi kontrol |
| `icon-mute` | `#7D7166` | Ikon informatif |
| `paper-100` | `#F4EDE1` | Teks utama |
| `paper-200` | `#E2D8C6` | Teks sekunder, permukaan kartu clue |
| `paper-300` | `#C3B7A2` | Teks tersier |
| `paper-400` | `#9A9080` | Label, metadata |
| `paper-contra` | `#F3D9D4` | Permukaan kartu kontradiksi, satu-satunya kartu berwarna |
| `lamp-100` | `#FFE0B0` | Kilau, huruf rank |
| `lamp-300` | `#F0B457` | Aksen utama, cincin fokus, tombol primer |
| `lamp-500` | `#E09A2E` | Lampu meja Handler |

### Tinta di atas kertas

Kartu clue, dokumen, dan bukti dicetak di atas permukaan kertas terang, jadi teksnya butuh tinta
gelap, bukan warna kertas terang di atas latar gelap. Dua tingkat tinta saja: satu untuk teks
utama, satu untuk label sekunder.

| Token | Nilai | Pakai |
|---|---|---|
| `ink-900` | `#2A2118` | Teks isi di atas kertas |
| `ink-700` | `#4A3A28` | Tinta mesin tik, huruf bukti cetak |
| `ink-alert` | `#8E2F26` | Teks peringatan di atas kertas, versi gelap dari `alert` |

Tingkat ketiga (`ink-500`, `#7A5B2E`) pernah ada dan **dihapus**. Di atas `paper-200` nilainya
hanya 4.42:1, di bawah ambang 4.5:1. Kekurangannya ditutup dengan menghapus token itu, bukan
dengan menurunkan ambang. Sekarang hierarki tinta dibuat lewat dua tingkat plus `ink-alert`, dan
ketiganya lulus di keempat permukaan kertas.

### Material dunia

| Token | Nilai | Material |
|---|---|---|
| `wood-900` | `#2A1D13` | Kayu paling gelap, ujung gradien meja |
| `wood-700` | `#4A3524` | Kayu gelap, badan meja |
| `wood-500` | `#6E5136` | Kayu sedang, permukaan meja |
| `wood-300` | `#96714B` | Tepi kayu yang terkena cahaya |
| `brass-500` | `#C9A227` | Kuningan, logam kecil |

### Aksen role

| Token | Nilai | Role | Rasio di `noir-800` |
|---|---|---|---|
| `role-searcher` | `#5FA8D3` | Searcher | 6.73:1 |
| `role-handler` | `#E09A2E` | Handler | 7.40:1 |
| `role-director` | `#B96A9E` | Director | 4.71:1 |
| `role-director-text` | `#BE7AA6` | Director, varian teks di `noir-700` | 4.98:1 |
| `role-npc` | `#8A93A0` | NPC pengisi | 5.66:1 |

Warna role adalah satu-satunya tempat di mana warna dipakai untuk **identitas**, bukan status. Tiap
role punya warnanya sendiri supaya pemain tahu siapa yang berbicara dari warna chip, tanpa membaca
nama.

### Status

| Token | Nilai | Pakai |
|---|---|---|
| `ok` | `#63B37A` | Berhasil, siap, bukti terkumpul |
| `alert` | `#E36459` | Gagal, kontradiksi, timer cleanup |

Status selalu dipasangkan dengan ikon atau teks. Warna saja tidak pernah menjadi satu-satunya
pembawa arti.

### Kenapa tokennya banyak tapi warnanya sedikit

Daftar di atas terlihat panjang, jadi perlu dinyatakan batasnya. Warna inti proyek ini ada **dua**:
cahaya lampu (`lamp-*`) dan kertas (`paper-*`). Aksesori tunggalnya `alert`. Sisanya adalah
**neutral** dari satu keluarga hangat yang sama, yaitu tujuh langkah gelap (`noir-*`), empat langkah
kayu (`wood-*`), dan satu kuningan (`brass-500`).

Cara memeriksanya: setiap token punya langkah di antaranya. Kalau ada dua token yang nilainya
berdekatan sampai tidak bisa dibedakan, salah satunya tidak dibutuhkan. Yang bertahan adalah langkah
yang punya pekerjaan sendiri, dan pekerjaan itu tertulis di kolom Pakai.

Warna role (`role-*`) adalah satu-satunya pengecualian, dan itu disengaja: warna role adalah
**identitas**, bukan status. Lima nilai itu tidak dipakai di tempat lain, hanya untuk menandai siapa
yang berbicara.

### Kenapa tema gelap, bukan pilihan

Tema gelap di sini bukan default gaya. Sumbernya PRD §3 dan §19: cozy noir, dengan lampu meja
sebagai identitas visual Handler. Lampu meja hanya punya arti kalau ruangannya gelap. Karena itu
mockup tidak punya tombol ganti tema: mode terang bukan fitur yang belum dikerjakan, melainkan mode
yang tidak diminta. Kalau pemilik produk memutuskan sebaliknya, itu keputusan identitas dan bukan
keputusan tata letak, jadi masuk butir eskalasi.

### Ikon

Mockup ini tidak memakai set ikon pihak ketiga sama sekali. Ada dua lapis, dan keduanya perlu
dibedakan supaya tidak ada klaim berlebih:

**Bentuk bermakna digambar sebagai CSS**, bukan karakter: titik status (`.dot`), kerucut senter
(`.ray`), reticle Searcher (`.reticle`), kepala pin peta (`.pin-head`). Semuanya lingkaran dan
kerucut sederhana yang tahan downscale, dan bentuknya sama dengan motif kolam cahaya di bagian 1.

**Ikon tombol memakai karakter Unicode sebagai placeholder yang jujur**: kunci, kaca pembesar,
kamera, bendera, tanda seru, tanda centang, panah putar, dan matahari UV. Ini bukan ikon final.
Alasannya sederhana: menggambar ikon final sekarang berarti memutuskan bahasa ikon sebelum
workstream teknis menetapkan pipeline sprite, dan placeholder yang jujur lebih baik daripada
mengklaim set ikon yang belum ada. Ikon final digambar mengikuti bentuk di dokumen ini.

Batas lisensi ada di `cosmetic-assets.md` bagian sumber daya: tidak ada logo, merek dagang, atau
karya pihak lain yang dipakai.

## 3. Bukti verifikasi palet

Semua dijalankan dengan `python3 palette_final.py` dari `docs/art/`. Hasil terakhir: **tidak ada
satu pun pasangan yang gagal.**

| Kelompok | Jumlah pasangan | Ambang | Hasil |
|---|---|---|---|
| A. Teks | 65 | WCAG 2.1 AA, 4.5:1 | Semua lulus |
| B. Komponen UI dan grafis | 18 | WCAG 2.1 SC 1.4.11, 3:1 | Semua lulus |
| C. Pemisahan aksen role | 12 | CIE76 di 4 mode penglihatan, 25.0 | Semua lulus |

Titik terketat dari kelompok C adalah pemisahan `role-handler` dan `role-director` pada penglihatan
tritanopia: **dE76 29.7**, di atas ambang 25.0. Angka ini yang menentukan warna Director.

### Kenapa Director plum, bukan merah

Pilihan pertama untuk Director adalah crimson `#C9564E`. Warna itu **gagal** simulasi buta warna:
pada deuteranopia, jaraknya ke `role-handler` hanya dE76 12.5, sehingga chip Director dan Handler
tampak sama bagi sekitar 6 persen pemain pria. Masalah ini ditutup dengan mengganti token, bukan
dengan menurunkan ambang.

Plum `#B96A9E` memberi jarak terburuk dE76 29.7 dan tetap lulus 4.71:1 di `noir-800`. Dari sisi
tema, plum terbaca sebagai tinta buku besar, tetap hangat dan noir, bukan pink neon.

### Kenapa `alert` dinaikkan

`alert` semula `#E36459` dengan margin 4.51:1 di `noir-700`, hanya 0.01 di atas ambang. Nilai itu
terlalu dekat untuk dipertahankan. Token dinaikkan sehingga marginnya 4.76:1.

### Kenapa border pin memakai `noir-900`, bukan `ink-alert`

Pin peta dan penanda pinpoint digambar sebagai lingkaran `alert` dengan garis tepi. Pilihan pertama
untuk garis itu adalah `ink-alert` `#8E2F26`, tetapi terhadap `alert` `#E36459` rasionya hanya
2.41:1, di bawah ambang 3:1 untuk komponen. `noir-900` memberi 5.61:1 terhadap `alert`, jadi garis
tepi itu tetap terbaca sebagai batas pin, bukan menyatu dengan isinya.

### Ringkasan simulasi buta warna

Nilai aksen setelah simulasi, untuk rujukan cepat:

| Mode | Searcher | Handler | Director |
|---|---|---|---|
| Normal | `#5FA8D3` | `#E09A2E` | `#B96A9E` |
| Deuteranopia | `#817BC7` | `#C9CE60` | `#A1A691` |
| Protanopia | `#8586CA` | `#C6C559` | `#9D9C94` |
| Tritanopia | `#64C2C0` | `#DD6E72` | `#B68B88` |

## 4. Pencahayaan

Satu sumber cahaya utama: **lampu meja**. Tidak ada cahaya langit, tidak ada rim light dingin.

| Aspek | Aturan | Alasan |
|---|---|---|
| Sumber | Satu, dari atas dan sedikit depan | Dua sumber membuat bayangan ganda dan sulit dibaca di layar kecil |
| Warna cahaya | `lamp-300` sampai `lamp-100` | Hangat adalah inti cozy noir, bukan pilihan gaya |
| Warna bayangan | `noir-900` sampai `noir-700`, tidak pernah hitam murni | Hitam murni mematikan detail material di perangkat dengan kontras rendah |
| Jatuh cahaya | Gradien radial, tepi tegas | Tepi tegas membuat batas wilayah kerja terbaca, tepi halus membuatnya kabur |
| Rasio terang dan gelap | Area terang sekitar 35 persen layar | Lebih dari itu bukan noir, kurang dari itu pemain tidak bisa membaca |

Searcher membawa cahaya sendiri berupa kerucut senter. Ini membuat lokasi tetap gelap sementara
pemain tetap bisa bekerja, dan memberi alasan naratif kenapa hanya sebagian ruangan terlihat.

Untuk layar Director yang berupa UI 2D, kolam cahaya dipakai tipis saja sebagai penanda fokus.
Director butuh membaca teks, jadi latarnya lebih rata daripada layar Searcher.

## 5. Bentuk

| Aspek | Aturan | Alasan |
|---|---|---|
| Gaya geometri | Low-poly, bidang rata, tepi keras | Sesuai §19, dan tahan downscale texture |
| Radius | `3px` kecil, `6px` sedang, `10px` besar | Hierarki lewat radius, bukan lewat ukuran seragam |
| Bentuk kontrol | Chamfer kecil, bukan pill | Pill terbaca ramah dan modern, chamfer terbaca seperti peralatan |
| Ketebalan tepi | 1 point garis, 2 point untuk batas wilayah | Di bawah 1 point hilang di layar padat |
| Sudut potongan puzzle | Tidak pernah membulat | Potongan harus terbaca sebagai potongan, bukan tombol |

Radius tidak dipakai seragam. Tombol sekunder lebih tajam dari tombol utama supaya hierarki aksi
terbaca dari bentuk, bukan hanya dari warna.

## 6. Material

Empat material saja. Menambah material kelima berarti menambah bahasa yang harus dipelajari pemain.

| Material | Tampilan | Dipakai di |
|---|---|---|
| Kayu | Gelap, serat halus, tanpa kilap | Meja, lantai, bingkai |
| Kuningan | Kecil, hangat, sedikit kilap | Tarikan laci, pin, ornamen |
| Kertas | Rata, tepi tidak rata, warna `paper-100` sampai `paper-300` | Bukti, kartu clue, dokumen |
| Kain | Rata, gelap, tanpa motif | Permukaan meja, sandaran |

Serat kayu digambar sebagai garis tipis berulang, bukan tekstur bergambar. Alasannya sama dengan
alasan gaya ilustrasi flat di `puzzle-style.md`: tekstur bergambar kehilangan detail saat resolusi
turun, sedangkan garis rata bertahan.

## 7. Tipografi

| Peran | Font | Ukuran minimum | Alasan |
|---|---|---|---|
| UI umum | Nunito | 12 point | Bentuk huruf terbuka, angka jelas, tersedia resmi di Roblox |
| Arsip dan judul | Merriweather | 18 point | Serif terbaca sebagai dokumen resmi, bukan dekorasi |
| Bukti cetak | Special Elite | 13 point | Mesin tik tua, cocok untuk dokumen yang dijadikan bukti |
| Log dan cipher | Roboto Mono | 12 point | Lebar huruf seragam, penting untuk kode dan angka sejajar |

Batas bawah 12 point untuk teks UI bukan pilihan estetis. Di bawah itu, pemain di layar ponsel
kecil harus menempelkan muka ke layar, dan itu bertabrakan dengan sesi 15 sampai 30 menit.

### Catatan teknis font di Roblox

`Enum.Font` adalah API lama. Untuk pekerjaan baru, pakai datatype `Font` dengan `FontFace`:

```lua
Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
```

Family asset yang sudah tersedia resmi dan dipakai proyek ini:

| Font | Family asset | Nilai `Enum.Font` lama |
|---|---|---|
| Nunito | `rbxasset://fonts/families/Nunito.json` | 35 |
| Merriweather | `rbxasset://fonts/families/Merriweather.json` | 33 |
| Special Elite | `rbxasset://fonts/families/SpecialElite.json` | 43 |
| Roboto Mono | `rbxasset://fonts/families/RobotoMono.json` | 41 |

Nilai `Enum.Font` dicantumkan hanya untuk kode lama. Kalau `Enum.Font` dan tabel ini berbeda,
yang benar adalah tabel ini, karena diambil dari halaman `Enum.Font` di dokumentasi resmi.

## 8. Aturan konten non-gore, layak 13+

PRD §14 menetapkan tema kejahatan non-kekerasan, target rating 13+, dan kuesioner maturity Roblox
diisi sejak prototype. Aturan berikut adalah turunan konkretnya untuk pekerjaan visual.

### Yang tidak boleh digambar

| Dilarang | Alasan | Gantinya |
|---|---|---|
| Darah, luka, atau jejak tubuh | Gore, langsung melanggar §14 | Jejak dokumen, barang berpindah, ruangan berantakan |
| Senjata tajam yang menonjol | Membaca sebagai kekerasan | Alat kerja biasa: gunting kertas, pemotong kaca, linggis kecil |
| Tubuh, mayat, atau siluet orang | Tema orang hilang dibawa lewat barang, bukan tubuh | Barang pribadi yang tertinggal |
| Ekspresi wajah ketakutan atau kesakitan | Menambah beban emosional yang tidak diminta tema | Wajah netral, atau tidak ada wajah sama sekali |
| Warna merah pekat dalam bidang besar | Terbaca sebagai gore meski maksudnya bukan | `alert` hanya untuk aksen kecil, di bawah 5 persen layar |
| Adegan kekerasan dalam bentuk apa pun | §14 | Konsekuensi ditunjukkan lewat benda dan catatan |

### Kekerasan diganti dengan apa

Prinsipnya: **perbuatan tidak pernah ditampilkan, hanya jejaknya.** Kejahatan di Triangulate selalu
berupa pencurian, pemalsuan, sabotase, atau orang hilang. Ketiganya punya jejak benda yang jauh
lebih menarik untuk digambar daripada kekerasan.

Contohnya:

- Bukan "lukisan dirusak dengan pisau", tapi "lukisan tergantung miring, tali penggantinya baru".
- Bukan "satpam diserang", tapi "kursi jaga kosong, kopi masih hangat, jadwal shift disobek".
- Bukan "orang hilang diculik", tapi "koper terbuka, tiket kereta tidak dipakai, pintu belakang
  tidak terkunci".

### Pemeriksaan sebelum aset dipakai

1. Kalau ada keraguan, bandingkan dengan daftar larangan di atas.
2. Kalau masih ragu, jangan pakai, dan ajukan sebagai pertanyaan ke pemilik isi.
3. Kuesioner maturity Roblox diisi sejak prototype, bukan menjelang rilis.

## 9. Batas dokumen ini

Dokumen ini menetapkan **bentuk**: warna, cahaya, bentuk, material, tipografi, dan batas konten.
Dokumen ini tidak menetapkan:

| Hal | Pemiliknya |
|---|---|
| Kalimat di UI, nama kasus, isi pernyataan saksi | Workstream konten kasus dan copy |
| Nama game dan keputusan akhir arah visual | Butir terbuka PRD §19, menyentuh identitas Exta |
| Thumbnail dan halaman store | Workstream positioning |
| Angka metrik dan target | Pemilik metrik |
| Batas texture dan rating perangkat nyata | Workstream verifikasi teknis |

## 10. Berkas terkait

| Berkas | Isi |
|---|---|
| `tokens.css` | Token warna dan ukuran, sumber tunggal untuk komponen |
| `palette.json` | Nilai token plus hasil verifikasi, dibaca skrip |
| `palette_final.py` | Skrip verifikasi WCAG dan simulasi buta warna |
| `ui-spec.md` | Target sentuh, aturan responsif, state tiap layar |
| `puzzle-style.md` | Gaya ilustrasi puzzle dan perilaku downscale |
| `cosmetic-assets.md` | Panduan aset kosmetik per role |
| `mockups/index.html` | Enam layar mockup plus lembar spesifikasi |
| `mockups/*.png` | Hasil render tiap layar |
| `mockups/render.sh` | Skrip render ulang PNG dari HTML |
| `mockups/verify_mockup.py` | Skrip pemeriksa mockup, keluar dengan kode 1 kalau ada yang gagal |
