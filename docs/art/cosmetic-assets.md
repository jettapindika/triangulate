# Panduan aset kosmetik

Spesifikasi produksi untuk kosmetik per role dan dekorasi Agency HQ.

Sumber kewajiban: PRD v0.2 §13. Aturan yang mengikat dari bagian itu: tidak ada pay-to-win, solusi
dan hint tidak bisa dibeli, case pack host-owns, dan kosmetik terlihat oleh pemain lain sesuai
slotnya.

## 1. Aturan yang berlaku untuk semua kosmetik

| Aturan | Isi |
|---|---|
| Tidak mengubah gameplay | Kosmetik tidak boleh mengubah ukuran area sentuh, warna penanda status, atau posisi kontrol |
| Terlihat oleh orang lain | Kosmetik yang tidak terlihat siapa pun tidak layak dijual. Kolom "terlihat oleh" wajib diisi |
| Tidak menyamarkan role | Warna role tetap dipakai di chip dan HUD. Kosmetik tidak boleh memakai warna role milik role lain |
| Lolos aturan konten | Semua kosmetik melewati aturan non-gore di `art-bible.md` bagian 8 |
| Warna dari token | Kosmetik boleh memakai palet yang lebih luas dari token UI, tapi tidak boleh memakai warna role orang lain |

Aturan "tidak menyamarkan role" penting. Kalau kosmetik Searcher boleh berwarna oranye Handler,
pemain kehilangan satu-satunya cara cepat mengenali siapa yang bicara. Warna role adalah kanal
informasi, bukan dekorasi.

## 2. Slot per role

### Searcher

| Slot | Bentuk | Terlihat oleh | Format | Ukuran | Catatan |
|---|---|---|---|---|---|
| Avatar | Pakaian dan aksesori karakter | Semua pemain, sepanjang sesi | Sesuai sistem avatar Roblox | Bawaan platform | Tidak perlu aset sendiri |
| Senter | Badan dan warna berkas cahaya | Semua pemain | `.png` | 256x256 | Warna berkas tidak boleh menyerupai `alert` atau `ok` |
| Gaya ping | Bentuk dan warna gelombang ping | Semua pemain | `.png` | 256x256, 4 bingkai | Animasi 4 bingkai, bukan video |

Slot senter adalah satu-satunya kosmetik yang menyentuh pencahayaan. Karena itu warnanya dibatasi:
tidak boleh merah (`alert`) atau hijau (`ok`), supaya tidak terbaca sebagai penanda status.

### Handler

| Slot | Bentuk | Terlihat oleh | Format | Ukuran | Catatan |
|---|---|---|---|---|---|
| Meja | Permukaan dan tepi meja | Handler, plus Director lewat Table Preview | `.png` | 1024x1024 | Satu texture, bukan model 3D |
| Set potongan puzzle | Tekstur punggung potongan | Handler, plus Director lewat Table Preview | `.png` | 512x512 | Maksimum grid 6x6 |

Table Preview adalah alasan Handler punya penonton kedua (PRD §7). Kosmetik meja bukan hanya untuk
pemain yang memakainya, jadi kualitasnya harus cukup pada thumbnail kecil, bukan hanya pada layar
penuh.

Set potongan hanya mengubah punggung potongan, bukan gambar buktinya. Gambar bukti adalah isi
kasus, bukan kosmetik.

### Director

| Slot | Bentuk | Terlihat oleh | Format | Ukuran | Catatan |
|---|---|---|---|---|---|
| Skin clue board | Latar dan bingkai papan | Director, plus semua pemain di Case Recap | `.png` | 1024x1024 | Kontras teks di atasnya wajib tetap 4.5:1 |
| Pin | Bentuk kepala pin dan pinpoint | Director, plus Searcher di dunia | `.png` | 128x128 | Pin pinpoint terlihat Searcher, jadi harus jelas di dunia gelap |

Dua slot Director punya pembatas yang keras:

1. Skin clue board **tidak boleh** menurunkan kontras teks di atasnya di bawah 4.5:1. Setiap skin
   baru wajib diuji ulang dengan `palette_final.py`.
2. Pin pinpoint terlihat Searcher di dunia yang gelap. Bentuknya harus tetap terbaca pada latar
   `noir-900` sampai `noir-700`.

### Semua role: dekor Agency HQ

| Slot | Bentuk | Terlihat oleh | Format | Ukuran | Catatan |
|---|---|---|---|---|---|
| Dekor HQ | Perabot dan ornamen ruang | Semua anggota agency | `.png` | 512x512 per item | HQ juga berfungsi sebagai lobby (PRD §11) |

Karena HQ adalah lobby, dekor harus tetap menyisakan ruang untuk pemain berdiri dan melihat pilihan
role. Dekor yang memenuhi ruang akan merusak fungsi lobby.

## 3. Batas teknis

| Aspek | Aturan | Alasan |
|---|---|---|
| Ukuran maksimum | 1024x1024 | Batas unggah texture umum 4096x4096, tapi tidak ada slot kosmetik yang butuh sebesar itu |
| Format | `.png` | Butuh transparansi |
| Gaya | Flat, sesuai `puzzle-style.md` | Kosmetik tampil kecil di perangkat mobile, gradien halus akan hilang |
| Detail minimum | 8 px pada ukuran tampil terkecil | Di bawah itu hilang saat texture diturunkan |
| Warna | Bebas, kecuali warna role lain | Warna role adalah kanal informasi |

## 4. Lisensi aset pihak ketiga

**Proyek ini tidak memakai aset pihak ketiga.**

Semua aset kosmetik harus dibuat sendiri atau dibeli dengan lisensi yang jelas. Aturan yang berlaku:

| Sumber | Boleh dipakai | Syarat |
|---|---|---|
| Dibuat sendiri | Ya | Tidak ada syarat tambahan |
| Dibeli dengan lisensi komersial | Ya | Nama lisensi dan tautan bukti dicatat di tabel bagian 5 |
| Aset gratis berlisensi bebas | Ya | Nama lisensi dicatat, termasuk kewajiban atribusi |
| Foto atau karya orang lain tanpa lisensi | **Tidak** | Dilarang, tanpa pengecualian |
| Logo atau merek dagang pihak lain | **Tidak** | Dilarang |

Alasan aturan ini tegas: game ini dijual dalam bentuk case pack (PRD §13), jadi aset di dalamnya
adalah barang dagangan. Aset tanpa lisensi membuat seluruh produk tidak bisa dijual.

Setiap kosmetik yang memakai aset pihak ketiga **wajib** dicatat di tabel berikut sebelum dipakai.
Tabel kosong di bawah ini adalah keadaan yang benar saat dokumen ini ditulis.

## 5. Catatan lisensi

| Nama aset | Slot | Sumber | Lisensi | Bukti | Tanggal |
|---|---|---|---|---|---|
| (kosong) | | | | | |

Aturan pengisian: satu baris per aset. Kolom "Bukti" diisi tautan ke halaman lisensi atau berkas
bukti pembelian, bukan nama toko saja.

## 6. Yang belum diputuskan

| Hal | Menunggu |
|---|---|
| Harga dan pengelompokan kosmetik | Keputusan monetisasi, bukan lingkup art |
| Jumlah item per slot pada rilis pertama | Keputusan scope |
| Apakah kosmetik bisa dilihat di luar sesi | Keputusan produk |
| Apakah dekor HQ punya batas jumlah | Keputusan teknis, bergantung performa |

## 7. Yang bukan lingkup dokumen ini

| Hal | Pemiliknya |
|---|---|
| Harga, bundel, dan penempatan di toko | Keputusan monetisasi |
| Thumbnail dan halaman store | Workstream positioning |
| Sistem avatar Roblox | Bawaan platform |
| Aset kasus seperti gambar bukti | Workstream konten kasus |
