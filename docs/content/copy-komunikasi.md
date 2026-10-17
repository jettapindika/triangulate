# Copy Komunikasi Triangulate

Draf v1. Rujukan: PRD v0.2 bagian 7 (komunikasi mobile-first) dan bagian 9 (onboarding).
Aturan: tanpa mengetik, sentuh saja. Semua frasa di bawah masuk ke Ping Wheel kontekstual, jadi roda menampilkan maksimal delapan pilihan sesuai role dan situasi.

## 1. Ping Wheel

Roda menampilkan 6 sampai 8 frasa. Empat frasa pertama selalu sama untuk role itu; sisanya berubah mengikuti situasi (menunggu kunci, bukti terbuka, gerbang tuduhan terbuka).

### Searcher (8)

| # | Frasa | Muncul saat |
|---|---|---|
| 1 | Nemu sesuatu! | setelah objek diperiksa |
| 2 | Terkunci, butuh kode | objek butuh kunci |
| 3 | Ada bahaya | patroli NPC mendekat (P1) |
| 4 | Sudah dicek | objek sudah dilaporkan |
| 5 | Butuh pinpoint | belum ada marker arah |
| 6 | Aku di gudang | berpindah area |
| 7 | Benda ini aneh | objek lolos pemeriksaan cepat |
| 8 | Aku kembali ke meja | menuju ruang depan |

### Handler (8)

| # | Frasa | Muncul saat |
|---|---|---|
| 1 | Cari benda bertanda ini | menaruh Target Marker |
| 2 | Bukti terbuka | puzzle selesai |
| 3 | Butuh kunci lain | menunggu kunci berikutnya |
| 4 | Clue terkirim | Clue Card sampai ke Director |
| 5 | Potongan kurang | ada slot puzzle kosong |
| 6 | Aku kerjakan rantai lain | pindah rantai |
| 7 | Kunci ini salah | kunci tidak cocok |
| 8 | Meja penuh, bantu pilih | lebih dari tiga bukti terbuka |

### Director (8)

| # | Frasa | Muncul saat |
|---|---|---|
| 1 | Ke pinpoint ini | menaruh pinpoint |
| 2 | Periksa ulang | minta objek dicek lagi |
| 3 | Aku butuh waktu | membaca pernyataan saksi |
| 4 | Gabungan ini masuk akal | deduksi lahir |
| 5 | Ada kontradiksi | menandai kontradiksi |
| 6 | Gerbang belum terbuka | Deduksi Kunci belum cukup |
| 7 | Coba kombinasi lain | resep deduksi gagal |
| 8 | Aku siap menuduh | form tuduhan terbuka |

### Semua role (3, selalu di slot bawah)

| # | Frasa |
|---|---|
| 1 | Setuju |
| 2 | Ragu |
| 3 | Tolong ulangi |

## 2. Role Card

Muncul sekali saat sesi dimulai, di atas HUD selama sepuluh detik pertama, bisa dibuka lagi lewat tombol role.

### Searcher

- Kamu tahu: lokasi, benda yang bisa diperiksa, dan apa yang kamu lihat dengan mata sendiri.
- Kamu tidak tahu: isi bukti di meja Handler dan papan Director.
- Tugas pertamamu: periksa benda pertama yang ditandai, lalu tekan Report.

### Handler

- Kamu tahu: kunci dari Searcher, dan bentuk potongan bukti sebelum dirangkai.
- Kamu tidak tahu: pernyataan saksi dan kombinasi Clue Card milik Director.
- Tugas pertamamu: rakit satu bukti begitu kunci pertama masuk.

### Director

- Kamu tahu: semua Clue Card, pernyataan saksi, dan peta.
- Kamu tidak tahu: lokasi benda sebelum Searcher melaporkannya.
- Tugas pertamamu: baca pernyataan saksi, lalu gabungkan Clue Card pertama yang datang.

## 3. Case Recap

Layar akhir, bisa di-screenshot. Angka diisi dari telemetri sesi, bukan ditulis tangan.

Judul: Kasus Ditutup

- Nama kasus dan varian yang terpakai.
- Rank kasus: S / A / B / C.
- Baris kontribusi per role:
  - Searcher: memeriksa {jumlah_objek} benda, mengirim {jumlah_laporan} laporan, {jumlah_benda_terlewat} benda terlewat.
  - Handler: merakit {jumlah_bukti} bukti, {jumlah_puzzle_gagal} percobaan gagal, {jumlah_hint} hint terpakai.
  - Director: menyusun {jumlah_deduksi} deduksi, menandai {jumlah_kontradiksi} kontradiksi.
- Hasil tuduhan: benar pada percobaan ke-{percobaan} dari {batas_percobaan}.
- Waktu sesi: {durasi}.
- Baris penutup: Tim menemukan pelaku, motif, dan cara. Arsip kasus bertambah satu.

Kalau gagal (Cold Case):

- Judul: Kasus Dingin
- Isi: Tim berhenti di {jumlah_deduksi} deduksi. Rekap parsial di bawah ini bisa dibaca, dan kasus yang sama bisa dimainkan lagi dengan varian berbeda.

## 4. Onboarding Rookie Mode

Berlaku untuk tiga sesi pertama akun. Clue lebih sedikit, hint gratis, dan setiap role dapat satu overlay tambahan.

### Banner pembuka

Selamat datang, Detektif Baru. Tiga sesi pertama ini lebih ringan: hint gratis dan clue lebih sedikit. Setelah itu, kasusnya kembali penuh.

### Overlay tambahan per role

- Searcher: Lingkaran kuning menandai benda yang bisa diperiksa. Sentuh, tahan sebentar, lalu tekan Report.
- Handler: Potongan yang benar akan menempel sendiri kalau didekatkan. Kamu tidak perlu tepat sampai milimeter.
- Director: Tarik satu kartu ke kartu lain untuk mencoba gabungan. Kalau resepnya salah, kartunya kembali sendiri.

### Pesan hint gratis

Hint ini gratis. Tiga sesi pertama tidak menghitung hint ke rank.

### Penutup rookie mode

Rookie mode selesai. Kasus berikutnya penuh: clue lebih banyak, hint dihitung, dan rank berlaku.

## 5. Teks Tambahan

### Report Card

Laporan terkirim ke clue board Director. Objek ini tidak perlu diperiksa lagi.

### Ready check

Sesi mulai dalam sepuluh detik. Sentuh tombol siap, atau slotmu diisi NPC.

### AFK takeover

Kamu tidak bergerak selama satu menit. NPC mengambil alih role-mu. State tetap utuh dan kamu bisa kembali kapan saja.

### Disconnect

Slotmu ditahan tiga menit. NPC mengisi sementara. Setelah tiga menit, slot dibuka untuk pengganti.

### Rotasi role

Kasus ini kamu memegang role berbeda dari sesi sebelumnya. Kamu bisa mematikan rotasi di pengaturan host.
