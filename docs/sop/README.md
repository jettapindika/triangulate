# SOP Triangulate — indeks

Status: **draf v0.1, belum terbit.** Draf disusun di EXTA-47 (Bagas — Process Writer). Penerbitan ada di Rafael — COO.

Rujukan PRD: `docs/prd-v0.2.md` (§4, §5, §6, §9, §10, §11, §12, §14, §15, §17, §19).

Aturan penulisan yang dipakai di semua SOP di folder ini:

- satu langkah = satu tindakan;
- definisi selesai harus bisa diperiksa, bukan "sudah rapi";
- failure modes wajib;
- satu SOP satu pemilik;
- setiap klaim menunjuk bagian PRD, atau ditandai `ASUMSI` beserta apa yang memverifikasi atau menggantikannya.

## Daftar SOP

| SOP | Nama | Pemicu utama | Pemilik proses |
| --- | --- | --- | --- |
| [SOP-01](sop-01-produksi-kasus.md) | Produksi story case: ide → rilis | slot rilis kosong / tanggal rilis dari operating plan | Rafael — COO |
| [SOP-02](sop-02-varian-solusi-seed.md) | Varian solusi per seed | kasus masuk tahap penulisan data (SOP-01 langkah 5) | Nadia — Penulis Konten |
| [SOP-03](sop-03-cold-case-archive.md) | Cold Case Archive dan modifier | kasus berakhir "Cold Case" (§5) atau pemain membuka arsip (§10) | Rafael — COO |
| [SOP-04](sop-04-playtest.md) | Playtest internal dan 3 pemain nyata | gate minggu 6 dan minggu 7 (§17); setiap kasus baru sebelum rilis | Rafael — COO |
| [SOP-05](sop-05-onboarding-case-0.md) | Onboarding Case 0 | akun baru pertama kali masuk lobby (§9) | Nadia — Penulis Konten |
| [Lampiran A](lampiran-a-instrumen-playtest.md) | Instrumen playtest: lembar observasi dan template temuan | dipakai SOP-04 | Rani — Data & Metrics Engineer |

## Batas antar-dokumen (jangan diduplikasi)

| Dokumen | Pemilik | Isi | Hubungan dengan folder ini |
| --- | --- | --- | --- |
| EXTA-46 Operating plan 8 minggu | Rafael — COO | milestone, gate per minggu, matriks kepemilikan per workstream, kriteria lulus playtest | SOP-04 memakai kriteria lulus dari EXTA-46; SOP di sini adalah lapisan prosedur yang bisa dijalankan, bukan pengganti matriks kepemilikan |
| EXTA-33 Skema data kasus, loader, validator | Nathan — CTO/CIO | JSON Schema lengkap + aturan validasi | SOP-01 langkah 6 dan SOP-02 langkah 5 memanggil validator itu; SOP di sini tidak mendefinisikan ulang field skema |
| EXTA-36 Kamus metrik dan skema event telemetri | Rani — Data & Metrics Engineer | nama event kanonik, definisi metrik | Lampiran A memakai empat event §15; nama event final menunggu EXTA-36 |
| EXTA-37 Rencana pengukuran dan audit handoff | Dewi — Operations Analyst | siapa mengukur apa, baseline vs target | SOP-04 menghasilkan data mentah; interpretasi target ada di EXTA-37 |
| EXTA-38 Konten kasus dan copy komunikasi | Nadia — Penulis Konten | isi kasus Case 0 dan story case #1 | SOP-01 dan SOP-02 adalah prosesnya; EXTA-38 adalah isi yang melewati proses itu |

## Tanggung jawab di folder ini yang belum punya pemilik

Daftar ini sengaja dipisah supaya lubangnya terlihat; matriks kepemilikan program ada di EXTA-46 (Rafael).

| Tanggung jawab | Kenapa belum ada pemilik | Usulan pemilik |
| --- | --- | --- |
| Pemutus akhir gate rilis konten (bukan gate teknis) | PRD §10 tidak menyebut siapa yang menyetujui rilis kasus; EXTA-38 menyebut persetujuan Clara untuk draf kontennya | Clara — CMO, atau Rafael — COO bila diputuskan sebagai gate proses |
| Pemilik angka "idle time" (ambang detik dan cara menghitungnya) | §6 dan §12 menetapkan target < 25% tetapi tidak mendefinisikan idle | Rani — Data & Metrics Engineer (EXTA-36) |
| Pemilik durasi timer *cleanup* | §19 menyatakan durasi ini masih pertanyaan terbuka | Nadia (nilai) + Nathan (implementasi), divalidasi playtest minggu 7 |
| Pemilik jadwal rilis kasus pasca rilis game | §17 hanya menyebut "pasca rilis: story case tiap 1-2 minggu" tanpa pemilik kalender | Rafael — COO |
| Pemilik perawatan arsip kasus lama (versi kasus yang sudah dirilis) | §10 menyebut Cold Case Archive, tidak menyebut siapa yang merawat versi | Nadia — Penulis Konten |

## Butir yang naik ke owner (keputusan yang bukan milik Process Writer)

1. **Ambang idle time.** SOP-04 dan Lampiran A memakai ambang `ASUMSI` 5 detik tanpa input bermakna. Yang menggantikan: definisi resmi di EXTA-36.
2. **Kalender rilis kasus.** SOP-01 memakai `ASUMSI` 10 hari kerja per kasus. Yang menggantikan: tanggal di operating plan EXTA-46.
3. **Rank untuk run Cold Case bermodifier.** PRD §5 memisahkan rank hanya untuk sesi dengan NPC Director; §10 tidak menyatakan hal yang sama untuk Cold Case. Butuh keputusan: apakah run Cold Case bermodifier masuk leaderboard utama.
4. **Validasi N.** §5 menetapkan N = 4/6, 3/5, 2/3 dan §19 menyatakan N naik/turun 1 bila penyelesaian < 55% atau > 85%. Pemilik keputusan penyesuaian N belum ada.
5. **Konten Case 0 setelah rilis.** §9 menyatakan Case 0 wajib sekali per akun dan bisa di-skip; tidak dinyatakan apakah kasus ini ikut berubah saat story case berikutnya dirilis. SOP-05 langkah 8 menandai ini sebagai keputusan.
6. **Batas SOP-04 dan proses playtest EXTA-46.** EXTA-46 juga memuat "proses playtest: internal (minggu 6) dan 3 pemain nyata di mobile (minggu 7)". Draf di sini menulis prosedur yang bisa dijalankan dan memakai kriteria lulus EXTA-46 sebagai input, tetapi dua dokumen yang sama-sama mendefinisikan playtest adalah tabrakan kepemilikan. Butuh keputusan: satu dokumen jadi acuan, yang lain menunjuk ke sana.
7. **Tanggung jawab tanpa pemilik** pada tabel di atas.
