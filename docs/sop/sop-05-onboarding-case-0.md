# SOP-05: Onboarding Case 0

- Versi: draf v0.1 (belum terbit)
- Penyusun draf: Bagas — Process Writer (EXTA-47)
- Pemilik proses: Nadia — Penulis Konten
- Rujukan PRD: §3, §5, §8, §9, §11, §12, §15, §17
- Bergantung pada: SOP-01 (produksi), SOP-04 (playtest)

## Pemicu

1. Akun membuka game untuk pertama kali dan belum menamatkan Case 0 (§9).
2. Akun menekan tombol skip pada tawaran Case 0.
3. Gate minggu 6 (§17) membutuhkan Case 0 siap untuk playtest internal.
4. Persentase menamatkan Case 0 turun di bawah target > 80% (§12).

## Peran

| Kode | Peran | Pemilik |
| --- | --- | --- |
| O1 | Pemilik isi dan teks Case 0 | Nadia — Penulis Konten |
| O2 | Pemilik status onboarding per akun | Nathan — CTO/CIO |
| O3 | Pemilik pengukuran | Rani — Data & Metrics Engineer |
| O4 | Fasilitator playtest onboarding | Rafael — COO |

## Langkah

### A. Menyiapkan Case 0

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 1 | Tulis Case 0 sebagai kasus biasa dengan skema yang sama (§10) | O1 | skema EXTA-33, SOP-01 | berkas kasus Case 0 | berkas lolos validator sama seperti kasus lain; tidak ada jalur kode khusus untuk Case 0 |
| 2 | Batasi Case 0 ke 3 rantai dan N = 2 dari 3 Deduksi Kunci | O1 | §5, §9 | `key_deductions` Case 0 | jumlah deduksi kunci = 2 dan dapat dicapai dalam ±5 menit |
| 3 | Beri tiap role tepat satu objective sederhana | O1 | §9 | objective per role | setiap dari Searcher, Handler, Director punya satu objective; tidak ada role dengan dua objective |
| 4 | Tulis overlay kontekstual per langkah | O1 | §4 alur rantai | teks overlay | setiap langkah alur §4 yang dijalankan pemain baru punya overlay yang menjelaskan tindakannya |
| 5 | Tulis role card tiap role: "Kamu tahu apa / Tidak tahu apa / Tugas pertamamu" | O1 | §9 | 3 role card | ketiga bagian terisi untuk ketiga role |
| 6 | Tetapkan NPC mentor | O2 | §9 | konfigurasi NPC mentor | NPC mentor aktif selama Case 0 dan tidak mengungkap solusi |
| 7 | Pastikan pemain baru tidak ditempatkan sebagai Director di sesi pertama | O2 | §8 prioritas keadilan | aturan penempatan | akun tanpa riwayat sesi tidak menerima role Director pada sesi pertamanya |

### B. Menjalankan Case 0

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 8 | Tawarkan Case 0 saat akun masuk lobby pertama kali | O2 | status akun | tawaran Case 0 | akun yang belum menamatkan Case 0 menerima tawaran; akun yang sudah menamatkan tidak menerimanya lagi |
| 9 | Tampilkan role card sebelum sesi dimulai | O2 | role card | layar role card | pemain melihat role card sebelum kontrol aktif |
| 10 | Jalankan Case 0 dengan NPC mentor dan overlay kontekstual | O2 | berkas kasus | sesi Case 0 | sesi dapat diselesaikan dalam ±5 menit |
| 11 | Tandai status menamatkan Case 0 pada akun | O2 | state sesi | flag akun | flag tersimpan; akun itu tidak ditawari Case 0 lagi |
| 12 | Sediakan tombol skip | O2 | — | tombol skip | tombol tersedia di layar tawaran; menekannya tidak menghapus akses Case 0 di kemudian hari |
| 13 | Terapkan rookie mode pada 3 sesi pertama akun | O2 | §9 | konfigurasi sesi | akun dengan riwayat < 3 sesi memakai kasus dengan clue lebih sedikit dan hint gratis |

### C. Mengukur dan memperbaiki

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 14 | Catat event onboarding: tawaran tampil, mulai, selesai, skip | O3 | kamus event (EXTA-36) | event onboarding | keempat momen tercatat dengan timestamp |
| 15 | Hitung persentase akun baru yang menamatkan Case 0 | O3 | event onboarding | angka % menamatkan Case 0 | angka dihitung terhadap akun yang **ditawari** Case 0, bukan terhadap seluruh akun baru |
| 16 | Bandingkan dengan target > 80% (§12) | O3 | angka langkah 15 | status terhadap target | status tertulis: di atas atau di bawah target |
| 17 | Bila di bawah target, cari tahu momen pemain berhenti | O3 + O4 | event onboarding, SOP-04 | daftar temuan onboarding | setiap temuan punya timestamp dan pemilik perbaikan |
| 18 | Uji ulang perbaikan lewat playtest onboarding | O4 | SOP-04 | laporan playtest | angka % menamatkan Case 0 diukur ulang setelah perbaikan |

## Definisi selesai

1. Case 0 ada sebagai berkas kasus dengan skema yang sama dan lolos validator.
2. Tiga role card lengkap, dan setiap role punya satu objective.
3. Akun yang belum menamatkan Case 0 ditawari Case 0, dan akun yang sudah menamatkan tidak ditawari lagi.
4. Tombol skip tersedia dan tidak menghapus akses Case 0.
5. Empat event onboarding tercatat dan angka % menamatkan Case 0 dapat dihitung.
6. Ada keputusan tertulis terhadap target > 80% (§12), beserta temuan bila di bawah target.

## Failure modes

| Kalau ini gagal | Gejala | Yang dilakukan |
| --- | --- | --- |
| Case 0 butuh jalur kode khusus | menambah kasus lain jadi lebih mahal; §10 "semua kasus berupa data" rusak | ubah Case 0 jadi konfigurasi kasus; ulangi langkah 1 |
| Pemain baru langsung jadi Director | sesi pertama memakai role tersulit (§8), quit point tinggi | perbaiki aturan penempatan; ulangi langkah 7 |
| Tombol skip menghapus akses Case 0 | pemain yang skip tidak pernah bisa mencoba tutorialnya | pisahkan "skip tawaran" dari "tandai selesai"; ulangi langkah 12 |
| Case 0 ditawarkan lagi setelah ditamatkan | pemain berpengalaman terjebak tutorial berulang | periksa flag akun; ulangi langkah 11 |
| Overlay kontekstual membocorkan solusi | tutorial menghapus bagian deduksi yang justru jadi inti permainan (§2 pilar 4) | perbaiki teks overlay agar menjelaskan tindakan, bukan jawaban |
| NPC mentor menyelesaikan puzzle untuk pemain | pemain tidak belajar apa pun; metrik > 80% jadi palsu | perbaiki perilaku NPC mentor; uji ulang lewat playtest |
| Persentase dihitung terhadap seluruh akun baru | angka terlihat rendah padahal pemain yang ditawari menamatkan | hitung terhadap akun yang ditawari (langkah 15) |
| Angka di bawah 80% tapi tidak ada tindak lanjut | target §12 tidak pernah tercapai | jalankan langkah 17-18; catat sebagai temuan dengan pemilik |
| Konten Case 0 ikut berubah saat story case baru dirilis | pemain lama mendapat tutorial yang berbeda dari yang diuji | **butuh keputusan owner** — lihat butir 5 README; sampai diputuskan, bekukan isi Case 0 dan catat setiap perubahan sebagai revisi terpisah |

## Pemilik

Nadia — Penulis Konten. Langkah status akun dan pengukuran dijalankan Nathan — CTO/CIO dan Rani — Data & Metrics Engineer.
