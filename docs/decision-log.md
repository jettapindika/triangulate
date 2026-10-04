# Log keputusan Triangulate dan antrean decision request

Pemilik dokumen: **Rangga — Decision Log & Strategy Ops**. Draf 2026-10-04. Sumber: `docs/prd-v0.2.md` (PRD v0.2 "Co-op Puzzle Mystery") sebagai sumber tunggal keputusan; hasil workstream EXTA-36, EXTA-41, EXTA-42, EXTA-43, EXTA-44, EXTA-46, dan EXTA-50 dibaca pada 2026-10-04 hanya untuk mengisi kolom "sudah dilaporkan" dan mendeteksi tabrakan. Isi hasil workstream lain **bukan** keputusan dan tidak diubah di sini.

**Revisi 1 (2026-10-04).** Kolom "Sudah dilaporkan workstream lain" diisi dari hasil workstream yang terbit hari yang sama: EXTA-36 (kamus metrik, `in_review`), EXTA-41 (positioning & store page, `in_review`), EXTA-42 (model pendapatan, `in_review`), EXTA-43 (model biaya build, `in_review`), EXTA-44 (register risiko & ambang belanja, `in_review`), EXTA-46 (operating plan, `in_review`), EXTA-50 (peta KR, `in_review`). Kolom itu menandai temuan yang **sudah** dilaporkan pemiliknya masing-masing — supaya pertanyaan yang sama tidak diajukan dua kali ke owner.

Dokumen ini **tidak memutuskan apa pun**. Isinya tiga bagian: (1) log keputusan untuk §3 Keputusan Terkunci, (2) antrean decision request untuk §19 Pertanyaan Terbuka, (3) daftar keputusan yang masih menggantung di PRD tetapi belum masuk §19. Semua klaim merujuk bagian PRD; yang tidak bisa dirujuk ditandai `ASUMSI` beserta apa yang menggantikannya.

## 1. Log keputusan — PRD v0.2 §3 "Keputusan Terkunci"

Format entri mengikuti lima kolom wajib (Tanggal, Keputusan, Pemilik, Alasan, Pemicu pembatalan). Kolom **Rujukan** ditambahkan untuk ketertelusuran; kolom itu bukan bagian format wajib.

**Catatan tanggal.** PRD v0.2 tidak mencantumkan tanggal per keputusan, dan changelog v0.1→v0.2 hanya menyebut nomor bagian. Tanggal `2026-10-04` di bawah adalah tanggal PRD v0.2 masuk repo (`5c5f59a`, "EXTA-31: bootstrap repo dengan PRD v0.2 dan struktur awal") dan tanggal issue EXTA-48 dibuat — **`ASUMSI`**, bukan tanggal keputusan diambil. Yang menggantikannya: riwayat revisi PRD v0.1→v0.2 (belum ada di repo) atau tanggal persetujuan tema oleh owner di kanal keputusan.

**Catatan pemilik.** PRD §3 tidak menyebut pemilik per keputusan. Kolom Pemilik di bawah diisi `Jetta — owner proyek` untuk seluruh delapan entri — **`ASUMSI`**: yang berhak membatalkan keputusan terkunci PRD adalah pemilik PRD. Yang menggantikannya: **EXTA-49** (Kirana — Narrative & Board Secretary), butir "hak keputusan: apa yang diputuskan owner, apa yang diputuskan tiap fungsi, dan apa yang butuh persetujuan dua pihak" — sampai itu terbit, kepemilikan di bawah adalah asumsi, bukan temuan. Pemilik pelaksana teknis dicatat di kolom Rujukan, dan pelaksana bukan yang berhak membatalkan.

| Tanggal | Keputusan | Pemilik | Alasan | Pemicu pembatalan | Rujukan |
|---|---|---|---|---|---|
| 2026-10-04 `ASUMSI` | Pakai tema cozy noir non-gore — pencurian, pemalsuan, sabotase, orang hilang — dan tunda supernatural ke case pack P2. | Jetta — owner proyek `ASUMSI` | §3 menandainya "(disetujui)"; §14 menuntut konten non-gore dan target rating 13+; §18 memasang "Rating konten: tema non-gore, isi kuesioner sejak awal" sebagai mitigasi. Supernatural ditahan karena §16 menaruh "supernatural pack" di P2. | Kuesioner maturity Roblox memaksa rating di atas 13+ untuk tema yang dipakai, atau owner memindahkan case pack supernatural dari P2 ke P0/P1. | §3, §14, §16, §18 |
| 2026-10-04 `ASUMSI` | Batasi potongan puzzle MVP pada bukti bermakna: dokumen sobek, foto, timeline, cipher. | Jetta — owner proyek `ASUMSI` | Pilar §2 "Puzzle adalah bukti" — tiap bagian yang terbuka harus mengubah apa yang diketahui tim, jadi jigsaw polos ditolak. §4 menetapkan tiga tipe untuk MVP dan menaruh spot-the-difference, rangkaian kabel, kunci kombinasi di P1. | Playtest minggu 7 (§17) menunjukkan penyelesaian di bawah 55% (§12) sehingga butuh tipe puzzle yang lebih mudah, atau EXTA-32/EXTA-33 melaporkan satu tipe tidak layak di perangkat mobile kelas bawah (§15). | §2, §4, §16, §17 |
| 2026-10-04 `ASUMSI` | Menangkan sesi hanya lewat tuduhan Director atas pelaku, motif, dan cara yang benar. | Jetta — owner proyek `ASUMSI` | Pilar §2 "Deduksi menentukan kemenangan — menyelesaikan puzzle saja tidak cukup"; §5 mengunci bentuknya: "Director mengisi form tuduhan (Pelaku, Motif, Cara) dan 1 role lain mengonfirmasi", dengan 3 percobaan dan feedback "X dari 3 benar". | Data playtest menunjukkan tim bisa menang dengan menebak tiga field sekaligus tanpa menyelesaikan N Deduksi Kunci (§5), atau mode 2 pemain/solo (§8) membuat komposisi field tuduhan berubah. | §2, §4, §5 |
| 2026-10-04 `ASUMSI` | Wajibkan konfirmasi satu role lain sebelum tuduhan akhir sah. | Jetta — owner proyek `ASUMSI` | §8 membatasi aksi yang butuh persetujuan dua role hanya pada "tuduhan akhir dan pakai hint", supaya tidak ada friksi voting; §18 memasang "Satu pemain mendominasi" sebagai risiko yang harus dimitigasi. | Konfirmasi terbukti jadi friksi pada playtest (sesi gagal atau tertunda karena satu pemain tidak hadir saat konfirmasi), atau NPC Director terpandu masuk P0 dan menggantikan peran konfirmasi manusia. | §3, §5, §8, §18 |
| 2026-10-04 `ASUMSI` | Minta pemain memilih 2 preferensi role berurutan sebelum matchmaking. | Jetta — owner proyek `ASUMSI` | §8 alur lobby langkah 1 memakai preferensi untuk menetapkan role; §3 menetapkan rotasi publik "preferensi dihormati + prioritas keadilan", jadi pemaksaan role ditolak demi mengisi lobby. | Median waktu tunggu melewati 60 detik atau sesi gagal start melewati 10% (§12) karena preferensi tidak pernah terpenuhi, atau EXTA-49 menetapkan hak keputusan role ke pihak lain. | §3, §8, §12 |
| 2026-10-04 `ASUMSI` | Isi role Handler dengan NPC "Archivist" saat sesi hanya punya dua pemain manusia (Searcher + Director). | Jetta — owner proyek `ASUMSI` | §8 menilai kesulitan AI Handler "Rendah" dan Director "Tinggi, jadi prioritaskan manusia", sehingga Handler yang pertama di-NPC-kan; §18 menahan lingkup dengan "2 NPC dulu, Director NPC ke P1". | Playtest duo menunjukkan Archivist otomatis membuat kasus terlalu mudah (penyelesaian di atas 85%, ambang revisi §19) atau menjadi bottleneck karena kecepatannya terlalu lambat. | §3, §8, §16, §18 |
| 2026-10-04 `ASUMSI` | Hormati preferensi role di publik dengan prioritas keadilan; di private server/seri kasus pakai rotasi otomatis Searcher → Handler → Director. | Jetta — owner proyek `ASUMSI` | §10 memberi private server rotasi otomatis dengan imbalan badge "All-Rounder" dan bonus Agency XP, sementara publik tidak dipaksa karena risiko "Lobby sepi" (§18) lebih mahal daripada manfaat rotasi. | Data menunjukkan rotasi otomatis menurunkan retensi D1/D7 di bawah target §12, atau default toggle host (§10) ditetapkan menyala dan mengubah perilaku pemain baru. | §3, §8, §10, §12, §18 |
| 2026-10-04 `ASUMSI` | Pakai kamera Handler top-down Scriptable, Searcher first/third person, dan Director UI 2D. | Jetta — owner proyek `ASUMSI` | §15 mengunci implementasinya: "kamera Scriptable top-down, raycast ke bidang meja, posisi potongan diatur server dan direplikasi (interpolasi di client agar halus di mobile)"; §7 menuntut kontrol touch-first untuk mayoritas pemain mobile. | Spike minggu 0 (§17) gagal: drag tidak halus di mobile atau `ImageRectOffset`/`ImageRectSize` tidak menyelesaikan blur pada perangkat kelas bawah, sehingga meja Handler harus diganti pendekatan lain. | §3, §7, §15, §17 |

## 2. Antrean decision request — PRD v0.2 §19 "Pertanyaan Terbuka"

Bentuk tiap permintaan mengikuti skill decision log: **pilihan → opsi → rekomendasi → apa yang dibutuhkan untuk jalan**. Status awal semuanya `terkirim` pada 2026-10-04; status berubah jadi `tidak dijawab >7 hari` pada 2026-10-11 bila belum ada jawaban. Yang menjawab adalah owner; rekomendasi di bawah adalah usulan bentuk, bukan keputusan.

### DR-01 — Nama game dan arah visual (§19 baris 1)

**Pilihan.** Tetapkan (a) arah visual yang mengikat untuk produksi, dan (b) nama game final yang dipakai di store page dan aset.

**Opsi.**
- **A — Nama deskriptif + arah visual seperti yang PRD sendiri sebut:** low-poly noir hangat dengan lampu meja sebagai identitas Handler. Selaras §14 (non-gore, 13+) dan §15 (ilustrasi flat tahan downscale). Biaya: nama deskriptif sulit dibedakan di pencarian Roblox.
- **B — Nama unik/brandable (satu kata) + arah visual yang sama.** Menguntungkan store page dan akuisisi (EXTA-41). Biaya: butuh clearance bentrok nama di Roblox sebelum dipakai.
- **C — Pecah dua keputusan: kunci arah visual dulu, nama menyusul bertenggat.** Kelebihan: EXTA-39 (art bible) bisa jalan tanpa menunggu nama. Biaya: EXTA-41 (store page) dan EXTA-38 (copy komunikasi) memakai placeholder sampai nama ditetapkan.

**Rekomendasi (usulan, bukan keputusan).** Ambil **C**: arah visual dikunci lebih dulu karena produsennya (EXTA-39, Sari — Perancang Visual) sudah berjalan dan tidak bergantung pada nama; nama ditetapkan sebagai keputusan terpisah dengan syarat clearance bentrok. Alasan menolak A/B sebagai bentuk tunggal: menggabungkan dua keputusan dengan kecepatan berbeda membuat keduanya tertahan oleh yang lebih lambat.

**Sudah dilaporkan workstream lain.** Pertanyaan ini bukan hanya milik antrean ini: EXTA-46 (Rafael — COO) menaikkannya sebagai **E-8** dan menyatakan Sari (EXTA-39) serta Clara (EXTA-41) memblokir sampai diputuskan; EXTA-41 (Clara — CMO) menaruh "Nama game final" sebagai kebutuhan #2 dan "ketersediaan aset visual" sebagai kebutuhan #3, dan menyatakan arahan visual di dokumennya masih konsep tanpa keluaran EXTA-39. Artinya satu keputusan ini menahan tiga workstream — jangan dijawab terpisah di tiga tempat.

**Dampak bila tidak dijawab.** EXTA-39 bisa lanjut tapi tidak mengikat; EXTA-41 tidak bisa finalkan store page; EXTA-38 menulis copy dengan placeholder; aset kosmetik §13 tidak punya bahasa visual tetap.

**Apa yang dibutuhkan untuk lanjut.** (a) owner menandai arah visual mana yang mengikat; (b) untuk nama — daftar bentrok nama Roblox (bahan bisa datang dari riset benchmark EXTA-40, Damar — Periset Eksternal) lalu keputusan owner; (c) bila C diambil, tenggat nama ditetapkan sebelum gate minggu 6 (§17, "Case 0, story case #1 + varian, ping wheel final"), karena store page masuk pekerjaan rilis minggu 8.

### DR-02 — Durasi timer cleanup (§19 baris 2, merujuk §6)

**Pilihan.** Tetapkan durasi timer cleanup per rantai bukti dan aturan percepatannya saat tuduhan salah.

**Opsi.**
- **A — Satu nilai tunggal untuk semua rantai.** Sederhana untuk MVP, mudah dijelaskan ke pemain. Biaya: rantai awal dan rantai akhir terasa sama, padahal §4 menaruh tiga rantai paralel dengan panjang berbeda.
- **B — Nilai per rantai** (rantai awal lebih longgar, rantai akhir lebih ketat). Memberi kurva tekanan. Biaya: menambah parameter yang harus dituning dan diuji, di luar daftar MVP §16.
- **C — Tetapkan nilai awal sebagai placeholder yang boleh diubah, dan kunci angkanya dari data playtest minggu 7.** Selaras dengan §19 yang justru menaruh validasi di playtest minggu 7.

**Rekomendasi (usulan, bukan keputusan).** Ambil **C**. Menetapkan durasi final sebelum data berarti mengarang angka, dan §19 sendiri menyatakan angka ini divalidasi di playtest minggu 7. Nilai placeholder awal tetap harus datang dari owner/COO, bukan ditaksir di dokumen ini.

**Sudah dilaporkan workstream lain.** Tiga artefak menyentuh pertanyaan yang sama: EXTA-44 (Bayu — Pengawas Anggaran & Risiko) mencatat **F6** "N Deduksi Kunci 4 dari 6 + durasi timer cleanup belum divalidasi (§19)" dengan pemilik Rafael; EXTA-46 (Rafael — COO) menaruhnya sebagai **E-9** dan sudah memakai nilai sementara "timer cleanup 8 menit per rantai" sebagai asumsi yang menunggu konfirmasi; EXTA-36 (Rani — Data & Metrics) menyebut `IDLE_THRESHOLD_S` final (3/5/10) ditetapkan setelah playtest minggu 7 sebagai **E7**. Nilai 8 menit itu **bukan** keputusan — ia asumsi kerja yang dipakai EXTA-46 supaya dokumennya bisa ditulis.

**Dampak bila tidak dijawab.** §6 ("pelaku menghapus satu bukti di lokasi jika tidak diambil dalam waktu tertentu") tidak bisa diimplementasikan; penalti §5 ("memajukan timer cleanup") tidak punya besaran; telemetri §15 tidak punya event timer untuk diukur; target §12 "idle time per role < 25% sesi" tidak bisa diuji sebagai tekanan waktu.

**Apa yang dibutuhkan untuk lanjut.** (a) nilai placeholder awal + siapa yang berwenang mengubahnya; (b) instrumen playtest minggu 7 yang mencatat waktu pengambilan tiap bukti (proses playtest ada di EXTA-46, Rafael — COO; SOP playtest di EXTA-47, Bagas — Process Writer; definisi event di EXTA-36, Rani — Data & Metrics); (c) kriteria lulus gate §17 minggu 7: "Idle < 25%, selesai > 55%".

### DR-03 — Validasi N (jumlah Deduksi Kunci) (§19 baris 2, merujuk §5)

**Pilihan.** Tetapkan N final per jenis kasus dan aturan naik/turun 1.

**Opsi.**
- **A — Kunci rumus yang sudah tertulis:** N = sekitar 65% dari total deduksi, dibulatkan ke atas → 4 dari 6 (kasus standar), 3 dari 5 (daily), 2 dari 3 (Case 0).
- **B — Pakai aturan revisi §19:** turunkan N satu bila penyelesaian < 55%, naikkan satu bila > 85%, dievaluasi setelah playtest minggu 7.
- **C — Tentukan N per kasus di dalam data kasus** (bukan rumus global), divalidasi oleh validator §10.

**Rekomendasi (usulan, bukan keputusan).** Ambil **A sebagai nilai rilis awal + B sebagai aturan revisi bertanggal**, karena keduanya sudah tertulis di PRD dan hanya butuh pengesahan; C menambah pekerjaan validator di luar MVP §16, jadi bukan jalur MVP.

**Catatan ketidakcocokan angka di §5 (temuan, bukan keputusan).** §5 menulis "Rumusnya kira-kira 65% dari total, dibulatkan ke atas", tetapi angka yang disebut di kalimat yang sama tidak konsisten dengan rumus itu: 65% dari 6 = 3,9 → dibulatkan ke atas 4 (cocok), 65% dari 3 = 1,95 → 2 (cocok), tetapi 65% dari 5 = 3,25 → dibulatkan ke atas **4**, sedangkan §5 menulis daily case = **3 dari 5**. Jadi salah satu dari dua hal ini yang berlaku: angka per jenis kasus, atau rumus 65%. Owner perlu menunjuk mana yang menang sebelum `DeductionEngine` (EXTA-32) dan validator (EXTA-33) mengunci ambang.

**Sudah dilaporkan workstream lain.** Sama seperti DR-02: EXTA-44 **F6**, EXTA-46 **E-9**, dan EXTA-50 (Wisnu — KR Tracker) butir 5–6 semuanya menunjuk pertanyaan §19 ini sebagai penghambat. EXTA-42 (Michelle — CFO) menambahkan sudut yang berbeda: model pendapatannya tidak bisa mengunci harga tanpa target DAU (§12 hanya menetapkan retensi, bukan DAU) — lihat G-15.

**Dampak bila tidak dijawab.** Gerbang tuduhan §5 ("Form hanya terbuka jika N Deduksi Kunci selesai dan minimal 1 Kontradiksi ditandai") tidak bisa diimplementasikan; rank S/A/B/C §5 tidak bisa dihitung; target §12 "> 55% sesi menamatkan kasus" tidak bisa dinilai karena N menentukan berapa yang wajib dikerjakan.

**Apa yang dibutuhkan untuk lanjut.** (a) pengesahan owner atas N rilis awal dan atas mana yang menang saat angka dan rumus berbeda; (b) penunjukan pihak yang berwenang menaikkan/menurunkan N dan tanggal evaluasinya (usulan: angka disiapkan Rani — Data & Metrics lewat EXTA-36, keputusan gate dipegang Rafael — COO lewat EXTA-46); (c) hasil playtest minggu 7 sebagai pemicu revisi.

## 3. Keputusan yang menggantung di PRD tetapi belum masuk §19

Daftar ini menjawab butir ketiga brief. Kolom "Sudah dilaporkan workstream lain" menandai temuan yang sudah muncul di hasil workstream paralel — supaya tidak dihitung dua kali, bukan untuk mengklaimnya.

| # | Keputusan yang menggantung | Bagian PRD | Pemilik yang terlihat dari workstream | Sudah dilaporkan workstream lain |
|---|---|---|---|---|
| G-01 | Harga case pack (nominal, per pack, dan isi pack) | §13 "Case pack: host-owns", §16 P2 "Case pack berbayar" | Michelle — CFO (EXTA-42, model pendapatan dan unit economics case pack serta kosmetik) | **Ya** — EXTA-42 menyatakan pendapatan MVP tidak boleh bergantung pada case pack dan tidak mengunci harga tanpa target DAU; itu keputusan owner. EXTA-43 (Ayu) menambahkan bahwa biaya konten berulang §10 tidak punya penutup pendapatan sampai P2 |
| G-02 | Harga kosmetik per role (Searcher, Handler, Director, Agency HQ) | §13 daftar kosmetik | Michelle — CFO (EXTA-42) | **Ya** — EXTA-42 merekomendasikan jalur **pass in-experience** (bagi hasil 70%, terkonfirmasi verbatim) dan menolak asumsi default avatar item Marketplace (30%); harga tetap usulan, bukan penetapan |
| G-03 | Kuota hint gratis per kasus dan aturan "progres" yang menambahnya | §13 "hanya dari kuota gratis per kasus dan progres", §12 target "1–2 hint per sesi" | **Belum ada pemilik** | **Ya, sebagian** — EXTA-50 (Wisnu) menandai B7 "rata-rata hint per sesi" tanpa instrumen; EXTA-36 (Rani) sudah membuat M-09 beserta event `hint_used`, tetapi **pemilik tafsir M-09 masih kosong** (kebutuhan E2 EXTA-36, naik ke CEO lewat matriks kepemilikan) |
| G-04 | Nilai default toggle rotasi role di private server (menyala atau mati) | §10 "Bisa dimatikan lewat toggle host" | **Belum ada pemilik** | Belum |
| G-05 | Kapan target D1/D7 ditinjau ulang dan ke angka berapa ("naikkan setelah ada Agency & daily") — Agency dan daily baru ada di P1 | §12, §16 P1 | **Belum ada pemilik**; angka metrik ada di Rani — Data & Metrics (EXTA-36) | **Ya, sebagian** — EXTA-50 menandai baseline D1/D7 tidak ada; EXTA-36 membuat M-01/M-02 tetapi menandai keduanya `BLOKIR` karena butuh tabel turunan lintas-sesi, dan menyerahkan zona waktu batas hari D1/D7 (kini `ASUMSI` 00:00 UTC) serta definisi "bermain" ke CMO (E4/E5 EXTA-36); EXTA-41 (Clara) menyarankan jangan memakai RFY organik sebagai asumsi pertumbuhan MVP selama Agency dan daily belum ada |
| G-06 | Jadwal, kriteria, dan pengamat playtest eksternal minggu 7 (3 pemain nyata, mobile) | §17 minggu 7, §6 aturan idle < 25% | Rafael — COO (EXTA-46 proses playtest); Bagas — Process Writer (EXTA-47 SOP playtest) | **Ya** — EXTA-46 mengirim §3 playtest minggu 6 dan 7 lengkap: cara kumpulkan bukti idle, pemisahan tugas (Rani mendefinisikan, Dewi memverifikasi, Rafael memutuskan lulus/gagal, Bima mengotomasi), toleransi rekonsiliasi ≤ 5 poin persentase, dan ukuran sampel `ASUMSI` A4 (≥ 12 sesi / ≥ 36 player-session / ≥ 6 pemain). B-04: pemain eksternal belum direkrut, tenggat minggu 5 |
| G-07 | Siapa yang menandatangani tiap gate roadmap minggu 0–8 | §17 kolom Gate | Rafael — COO (EXTA-46 matriks kepemilikan); verifikasi teknis Nathan — CTO/CIO (EXTA-32/33) | **Ya** — EXTA-46 §2 mengirim matriks 22 workstream (Pemilik / Menyetujui / Diinformasikan / Gate) plus **8 celah kepemilikan**, dan §1 memasang ambang terukur `ASUMSI` A1–A8 untuk gate minggu 0–8; EXTA-50 menandai pemilik verifikasi gate minggu 7 belum ditetapkan; EXTA-37 (Dewi) memegang audit handoff |
| G-08 | Perilaku AFK/disconnect untuk role Director di MVP | §8 "AFK 60 detik → NPC mengambil alih role itu" dan "Disconnect → NPC mengisi sementara", bertabrakan dengan §16 yang menaruh NPC Director di P1 | Nathan — CTO/CIO (EXTA-32 matchmaking/AFK); Rafael — COO (EXTA-46) | **Ya, sebagian** — EXTA-44 (Bayu) mencatat risiko "state drift saat AFK takeover/rejoin" di bagian C register risiko; EXTA-36 menetapkan `rank_board ∈ {main, npc_director}` untuk memisahkan sesi ber-NPC-Director dan event `npc_takeover`/`session_paused`, tetapi **perilaku produk saat Director AFK di MVP tetap tidak terdefinisi** |
| G-09 | Ambang angka untuk metrik "Quit di 5 menit pertama per role" | §12 ("Dipantau, bandingkan antar role") | **Belum ada pemilik**; instrumen ada di Rani (EXTA-36) | **Ya** — EXTA-50 menandai B6 tanpa ambang dan tanpa pemilik; EXTA-36 membuat M-08 beserta rumusnya, jadi yang tersisa hanya ambangnya |
| G-10 | Rumus rank S/A/B/C dari waktu, jumlah tuduhan, dan hint terpakai | §5 ("Rank: S/A/B/C dari waktu, jumlah tuduhan, dan hint terpakai") | **Belum ada pemilik**; komponen telemetri di Rani (EXTA-36) | **Ya** — EXTA-50 menandai B9 "komponen ada, rumus tidak ada"; EXTA-36 kini mengirim **rubrik rank S/A/B/C** (M-13, "terburuk dari 3 komponen") tetapi menandai persetujuan ambang rubrik dan pemilik tafsir M-13 sebagai kebutuhan **E3** ke CEO |
| G-11 | Tanggal pasti pengisian kuesioner maturity Roblox ("sejak prototype") | §14, §18 baris "Rating konten" | Damar — Periset Eksternal (EXTA-40 riset maturity rating) | **Ya, sebagian** — EXTA-46 menaruh B-06 "kuesioner maturity Roblox belum ada pemilik eksekusi" (tenggat minggu 4) dan mengusulkan Damar menyiapkan, owner mengirim; EXTA-41 menambahkan bahwa deskriptor Fear kemungkinan terpicu dan itu menentukan eligibility Roblox Kids/Select, serta bahwa judul/deskripsi yang menyebut *social hangout* menggeser klasifikasi maturity. Tanggal eksekusi masih kosong |
| G-12 | Siapa yang berwenang mengubah N dan durasi timer cleanup setelah rilis (konsekuensi DR-02 dan DR-03) | §19 "naik/turun 1 jika selesai < 55% atau > 85%" | **Belum ada pemilik** | **Ya, sebagian** — EXTA-46 memisahkan peran (Rafael memutuskan lulus/gagal gate) tetapi kewenangan mengubah angka N/timer itu sendiri tidak disebut; EXTA-44 F6 menaruh pemiliknya di Rafael |
| G-13 | Ambang terukur untuk tiap gate minggu 0–8 (PRD §17 hanya memberi gate kualitatif: "drag halus", "tidak blur") | §17 kolom Gate | Rafael — COO (EXTA-46) | **Ya** — EXTA-46 §1 mengusulkan A1–A8 dan meminta konfirmasi di **minggu 0**, bukan minggu 6: "menetapkan ambang setelah tahu hasil spike bukan gate". Belum ada persetujuan owner (E-2) |
| G-14 | Ukuran sampel playtest minggu 7 (berapa sesi/pemain yang cukup untuk menyatakan gate lulus) | §17 minggu 7, §12 | Rafael — COO (EXTA-46) | **Ya** — EXTA-46 mengusulkan A4 (≥ 12 sesi / ≥ 36 player-session / ≥ 6 pemain) dengan alasan di bawah itu "selesai > 55%" tidak bisa dibedakan dari kebetulan. Belum ada persetujuan owner |
| G-15 | Target DAU dan anggaran akuisisi — §12 hanya menetapkan retensi (D1 18% / D7 5%), sehingga model pendapatan tidak punya penyebut | §12, §13 | Michelle — CFO (EXTA-42); Clara — CMO (EXTA-41, persetujuan belanja ads) | **Ya** — EXTA-42 menyatakan "tidak ada angka yang bisa dikunci tanpa target DAU" dan menyajikan model **per 1.000 DAU**; EXTA-41 meminta persetujuan belanja ads dan konfirmasi angka dari Ads Manager |
| G-16 | Pos anggaran penanggung biaya yang dituntut PRD (aset, audio, tooling, playtest) — sub-pos "Tools Exta" = Rp 0 sementara anggaran EXTA-3 sudah terbagi habis (sisa nol) | §13, §15, §17 | Michelle — CFO (EXTA-42/EXTA-44 F1) | **Ya** — EXTA-44 **F1** menyebutnya sebagai dua temuan paling perlu perhatian, bersama **F8** (biaya konten berulang §10 tanpa penutup pendapatan); EXTA-43 (Ayu) mengukur biaya build 8 minggu dalam tiga skenario (Rp 22.328 hemat / Rp 1.274.830 base / Rp 8.792.169 mahal) terhadap anggaran Rp 2 juta per bulan |
| G-17 | Privasi telemetri untuk pemain 13+ (data apa yang boleh disimpan, berapa lama, bagaimana consent) | §14, §15 (telemetri sejak build pertama) | **Belum ada pemilik** | **Ya** — EXTA-46 mengusulkan **E-7**: agregat tanpa identitas; EXTA-36 menetapkan tidak ada isi chat/teks bebas di event mana pun (§14) dan memakai `t_server_ms` sebagai satu-satunya jam metrik |
| G-18 | Siapa menetapkan `par_time_s` per (`case_id`, `case_variant`) — dibutuhkan rank M-13, tidak ada di skema data kasus §10 | §10 skema kasus, §5 rank | **Belum ada pemilik** | **Ya** — EXTA-36 kebutuhan **E6** (CTO/CIO + desain) dan **D2**; EXTA-46 menyerahkan ke pemilik data kasus |

## 4. Alarm wajib menurut aturan pencatatan

### 4.1 Keputusan tanpa pemilik

Sepuluh keputusan mengikat implementasi tetapi tidak punya nama yang berhak memutuskan:

| # | Keputusan | Status pemilik |
|---|---|---|
| G-03 | Kuota hint gratis dan aturan "progres" | Belum ada; tafsir M-09 kosong (E2 EXTA-36) |
| G-04 | Nilai default toggle rotasi role di private server | Belum ada |
| G-05 | Kebijakan revisi D1/D7 | Belum ada; E4/E5 EXTA-36 ke CMO |
| G-09 | Ambang quit 5 menit pertama | Belum ada |
| G-10 | Ambang rubrik rank S/A/B/C | Rumus sudah ada (EXTA-36), persetujuan ambang belum (E3) |
| G-12 | Kewenangan mengubah N dan timer cleanup | Belum ada |
| G-13 | Ambang terukur gate minggu 0–8 | Usul A1–A8 dari EXTA-46, belum disetujui |
| G-14 | Ukuran sampel playtest minggu 7 | Usul A4 dari EXTA-46, belum disetujui |
| G-17 | Privasi telemetri pemain 13+ | Belum ada; usul E-7 EXTA-46 |
| G-18 | Penetap `par_time_s` per varian kasus | Belum ada; E6 EXTA-36 |

Sesuai aturan pencatatan, ini dinaikkan ke **Benjamin — CEO** untuk penunjukan pemilik, bukan diselesaikan sendiri. Catatan penting: G-13/G-14/G-17 sudah **punya usulan konkret** dari EXTA-46 dan EXTA-36, jadi yang dibutuhkan dari owner adalah persetujuan atau penolakan, bukan penyusunan dari nol.

### 4.2 Entri yang saling bertabrakan

1. **§8 vs §16 (AFK/disconnect Director).** §8 menyatakan NPC mengambil alih role apa pun yang AFK atau disconnect, tanpa pengecualian role; §16 menaruh "NPC Director terpandu" di P1, sementara daftar MVP hanya menyebut "NPC Searcher dan Handler" plus "AFK takeover". Untuk MVP, perilaku saat Director AFK tidak terdefinisi — apakah sesi dijeda, apakah form tuduhan terkunci, apakah slot langsung dibuka. Ini tabrakan lingkup, bukan sekadar angka hilang, dan menyentuh EXTA-32 (implementasi matchmaking/AFK) serta EXTA-46 (proses playtest). EXTA-44 menambahkan risiko "state drift saat AFK takeover/rejoin", jadi tabrakan ini punya konsekuensi teknis, bukan hanya definisi.
2. **§5 angka vs rumus N.** Dijelaskan di DR-03: "3 dari 5" untuk daily case tidak konsisten dengan "65% dari total, dibulatkan ke atas" (yang menghasilkan 4). Dua entri log yang tidak bisa berlaku bersamaan — dilaporkan, tidak dipilih.
3. **§9 "±5 menit" vs durasi Case 0 yang dipakai workstream.** PRD §9 menetapkan Case 0 ±5 menit; EXTA-46 memasang `ASUMSI` A6 "Case 0 ≤ 7 menit" supaya dokumennya bisa ditulis. Dua angka untuk hal yang sama, dan salah satunya mengikat onboarding (target §12 "% menamatkan Case 0 > 80%"). Perlu satu angka resmi sebelum Case 0 dibangun (EXTA-51).
4. **§10 skema kasus tidak memuat `par_time_s`, padahal §5 menuntut rank berbasis waktu.** Rank S/A/B/C dihitung dari waktu, tetapi skema data kasus §10 tidak punya field waktu acuan, sehingga "waktu" tidak punya pembanding. Ini bukan dua entri yang bertentangan langsung, melainkan satu keputusan yang hilang dari skema — dilaporkan sebagai G-18.

### 4.3 Permintaan yang berpotensi diminta dua kali

- **§19 dipakai bersama tiga workstream.** Kedua butir §19 (timer cleanup + validasi N, dan nama game + arah visual) muncul sebagai permintaan di **tiga** artefak berbeda pada hari yang sama: EXTA-44 **F6** (pemilik Rafael), EXTA-46 **E-9** dan **E-8**, dan EXTA-50 butir 5–6; EXTA-41 menambahkan "nama game final" sebagai kebutuhan #2. Risikonya nyata: owner menerima pertanyaan yang sama dari empat arah dan menjawab di tempat berbeda, lalu tidak ada satu pun jawaban yang tercatat sebagai keputusan. **Usulan: antrean DR-01–DR-03 di dokumen ini dipakai sebagai tempat jawaban dicatat**, dan artefak lain merujuk ke sini, bukan menanyakan ulang.
- **G-01/G-02 (harga case pack dan kosmetik)** sudah punya pemilik dan sudah dijawab sebagian di EXTA-42. Bila owner menjawab harga di luar EXTA-42, jawabannya harus dicatat di sini agar tidak ditanyakan ulang. Komentar Benjamin di EXTA-31 sendiri sudah memperkirakan permintaan ini muncul dari EXTA-42 — jadi antrean ini hanya menandai tempatnya, bukan mengajukan ulang.
- **G-07 (kepemilikan gate) dan G-13/G-14 (ambang & sampel gate)** disentuh empat workstream sekaligus: EXTA-46 (matriks kepemilikan + A1–A8 + A4, Rafael), EXTA-37 (rencana pengukuran dan audit handoff, Dewi), EXTA-36 (pemilik tafsir metrik, Rani), dan EXTA-50 (peta KR, Wisnu). Empat artefak untuk satu kepemilikan berisiko menghasilkan empat jawaban berbeda. Perlu satu penunjuk: pemilik gate ditetapkan sekali, sisanya merujuk.
- **G-15 (target DAU)** adalah penyebut bagi dua model yang sudah terbit: EXTA-42 (pendapatan per 1.000 DAU) dan EXTA-43 (biaya build tiga skenario). Tanpa satu angka DAU, kedua model tidak bisa dipertemukan menjadi keputusan anggaran.

## 5. Batas pengerjaan

- Tidak ada keputusan yang diambil di dokumen ini. Kolom "rekomendasi" adalah usulan bentuk permintaan, dan "Rekomendasi" pada DR-01–DR-03 tidak mengikat siapa pun.
- Tidak ada status, prioritas, atau assignee issue lain yang diubah; tidak ada sub-issue baru.
- Tidak ada angka yang dihitung selain pembagian aritmetika pada §5 yang dipakai untuk menunjukkan ketidakcocokan; tidak ada tanggal yang dikarang — tanggal yang tidak diketahui ditandai `ASUMSI`.
- Draf dokumen ini diusulkan lewat PR; tidak ada yang di-merge ke `main` tanpa persetujuan owner.
