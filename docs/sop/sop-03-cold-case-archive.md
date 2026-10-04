# SOP-03: Cold Case Archive dan modifier

- Versi: draf v0.1 (belum terbit)
- Penyusun draf: Bagas — Process Writer (EXTA-47)
- Pemilik proses: Rafael — COO
- Rujukan PRD: §5, §10, §11, §12
- Bergantung pada: SOP-02 (varian solusi per seed), SOP-04 (playtest)

## Pemicu

1. Sebuah sesi gagal: Director salah 3 kali, kasus menjadi "Cold Case" (§5).
2. Pemain membuka Cold Case Archive dan memilih kasus lama untuk dimainkan ulang (§10).
3. Kasus lama sudah berumur dan perlu varian baru agar tidak spoiler (§10).

## Istilah

| Istilah | Arti di SOP ini |
| --- | --- |
| Cold Case | status akhir sesi setelah 3 tuduhan salah; pemain melihat rekap parsial (§5) |
| Modifier | pengubah aturan yang diaktifkan pada run arsip: waktu lebih ketat, tanpa hint, 1 percobaan tuduhan (§10) |
| Varian arsip | cabang solusi yang dipakai run arsip; boleh varian yang sudah ada atau varian baru (SOP-02) |

## Peran

| Kode | Peran | Pemilik |
| --- | --- | --- |
| C1 | Pemilik arsip dan isi kasus | Nadia — Penulis Konten |
| C2 | Pemilik aturan modifier di server | Nathan — CTO/CIO |
| C3 | Pemilik rekap dan rank | Rani — Data & Metrics Engineer |
| C4 | Pemutus gate tayang arsip | Rafael — COO |

## Langkah

### A. Menutup sesi yang gagal menjadi Cold Case

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 1 | Setelah tuduhan salah ke-3, kunci form tuduhan | C2 | state sesi | state sesi "Cold Case" | tidak ada tuduhan ke-4 yang bisa dikirim |
| 2 | Tampilkan rekap parsial: bukti yang ditemukan, deduksi yang selesai, kontradiksi yang ditandai | C2 + C3 | state sesi | layar rekap parsial | rekap menyebut apa yang **belum** terungkap tanpa menyebut jawabannya |
| 3 | Tawarkan varian lain untuk percobaan berikutnya (§5) | C1 + C2 | daftar varian kasus | tombol "coba varian lain" | varian yang ditawarkan berbeda dari varian yang baru gagal |
| 4 | Catat status Cold Case di telemetri | C3 | kamus event (EXTA-36) | event sesi | event memuat: kasus, varian, jumlah tuduhan salah, timestamp |
| 5 | Masukkan kasus ke Cold Case Archive | C1 | daftar kasus tayang | entri arsip | entri memuat `case_id`, varian yang tersedia, dan tanggal masuk arsip |

### B. Menjalankan run arsip dengan modifier

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 6 | Pilih modifier sebelum sesi dimulai, di lobby | C2 | daftar modifier §10 | konfigurasi sesi | modifier terpilih terlihat pemain sebelum mereka menekan siap |
| 7 | Terapkan modifier sebagai konfigurasi data, bukan jalur kode terpisah | C2 | konfigurasi sesi | sesi berjalan dengan modifier | kasus yang sama dapat dijalankan dengan dan tanpa modifier tanpa berkas kasus berbeda |
| 8 | Terapkan "waktu lebih ketat" pada timer *cleanup* (§6) | C2 | durasi dasar timer | durasi timer sesi arsip | durasi sesi arsip lebih pendek dari durasi dasar; angkanya satu nilai yang tercatat di konfigurasi |
| 9 | Terapkan "tanpa hint" | C2 | kuota hint (§13) | sesi tanpa hint | tombol hint tidak tersedia selama sesi |
| 10 | Terapkan "1 percobaan tuduhan" | C2 | batas 3 percobaan (§5) | sesi dengan 1 percobaan | setelah tuduhan pertama salah, sesi langsung berakhir Cold Case |
| 11 | Pastikan gerbang deduksi dan kontradiksi tetap berlaku saat modifier aktif | C2 | §5 | hasil periksa | N Deduksi Kunci dan ≥ 1 kontradiksi tetap menjadi syarat pembuka form tuduhan |
| 12 | Catat modifier aktif di telemetri sesi | C3 | kamus event (EXTA-36) | event sesi | setiap sesi mencatat modifier mana yang aktif |

### C. Merawat arsip

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 13 | Tambah varian baru untuk kasus arsip bila varian lama sudah beredar luas | C1 | SOP-02 | berkas kasus revisi | SOP-02 definisi selesai terpenuhi untuk varian baru |
| 14 | Uji varian arsip baru lewat playtest ringkas | C4 + fasilitator SOP-04 | varian baru | laporan playtest ringkas | tidak ada temuan blocker terbuka |
| 15 | Tayangkan varian arsip baru | C4 | laporan playtest | varian tayang di arsip | varian dapat dipilih pemain dan tercatat di telemetri |
| 16 | Periksa berhenti: kasus arsip yang tidak pernah dimainkan selama satu siklus konten | C1 | telemetri arsip | keputusan pertahankan/cabut | ada keputusan tertulis per kasus arsip yang tidak dimainkan |

## Definisi selesai

1. Sesi gagal berubah menjadi Cold Case tanpa kemungkinan tuduhan tambahan, dan rekap parsial tampil tanpa membocorkan jawaban.
2. Kasus masuk arsip dengan entri yang memuat varian tersedia.
3. Setiap dari tiga modifier §10 dapat dinyalakan dan dimatikan sebagai konfigurasi, dan setiap sesi mencatat modifier yang aktif.
4. Gerbang deduksi dan kontradiksi tetap berlaku saat modifier aktif.
5. Ada keputusan tertulis untuk setiap kasus arsip yang tidak dimainkan dalam satu siklus konten.

## Failure modes

| Kalau ini gagal | Gejala | Yang dilakukan |
| --- | --- | --- |
| Rekap parsial menyebut jawaban | sesi gagal jadi tidak ada artinya; pemain lanjut dengan jawaban gratis | hentikan tayang; perbaiki isi rekap; uji ulang sebelum tayang |
| Modifier diimplementasikan sebagai jalur kode terpisah | setiap kasus arsip butuh berkas kedua; §10 "semua kasus berupa data" rusak | ubah menjadi konfigurasi; ulangi langkah 7 |
| "Tanpa hint" tapi kuota hint tetap terpakai | pemain kehilangan kuota untuk hint yang tidak diberikan | periksa pencatatan kuota; pastikan hint tidak dikurangi saat modifier aktif |
| "1 percobaan" tapi form tuduhan tetap terbuka | aturan arsip tidak berlaku; rank tidak bermakna | perbaiki gerbang form; ulangi langkah 10 |
| Modifier tidak tercatat di telemetri | tidak bisa membandingkan sesi arsip dengan sesi biasa; temuan playtest tidak dapat diperbaiki | tambahkan pencatatan modifier (langkah 12) |
| Varian arsip sama dengan varian yang baru gagal | pemain mengulang jawaban yang sama; tidak ada nilai ulang | pilih varian berbeda; bila hanya satu varian tersedia, tulis varian baru lewat SOP-02 |
| Kasus arsip menumpuk tanpa dimainkan | arsip jadi beban perawatan tanpa manfaat | jalankan langkah 16 dan putuskan pertahankan atau cabut |
| Rank run arsip bermodifier bercampur dengan rank utama | leaderboard tidak bermakna | **butuh keputusan owner** — lihat butir 3 README; sampai diputuskan, pisahkan pencatatannya dan jangan tampilkan di leaderboard utama |

## Pemilik

Rafael — COO.
