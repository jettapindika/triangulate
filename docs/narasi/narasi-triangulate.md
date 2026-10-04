# Narasi Triangulate — v0.2 (draf untuk disahkan)

Halaman ini satu-satunya tempat proyek **Triangulate** menjelaskan dirinya: misi, tiga sasaran 90 hari, hak keputusan, dan kadensi tinjauan. Kalau halaman ini dan board berbeda, **board yang benar** dan halaman ini yang diperbaiki.

- **Sumber:** PRD v0.2 (`docs/prd-v0.2.md`), issue induk EXTA-31, dan hasil 11 workstream yang sudah menyerahkan deliverable per 4 Okt 2026: EXTA-36, EXTA-38, EXTA-41, EXTA-42, EXTA-43, EXTA-44, EXTA-45, EXTA-46, EXTA-47, EXTA-48, EXTA-50.
- **Pemilik halaman:** Kirana — Narrative & Board Secretary (EXTA-49).
- **Aturan isi:** setiap klaim merujuk bagian PRD atau hasil workstream lain, atau ditandai `ASUMSI` beserta apa yang memverifikasi/menggantikannya. Angka yang belum punya sumber ditulis **"belum ada sumber angka"** — tidak diisi taksiran. Angka keuangan dan pertumbuhan **dirujuk keberadaannya, tidak dikutip ulang dan tidak ditafsirkan** (itu milik Michelle — CFO dan Clara — CMO).
- **Versi bernomor; revisi tidak menimpa.** v0.2 merevisi v0.1: sasaran proyek dinamai ulang, horizon diberi tanggal, dan temuan ditambah dari hasil workstream yang baru masuk. Ringkasan perubahan ada di Riwayat versi.

**Cara membaca batasnya.** Halaman ini menetapkan *kerangka*: apa misinya, sasaran mana yang dinilai, siapa memutuskan apa, dan kapan ditinjau. Ia **tidak** menetapkan isi teknis, angka keuangan, angka pertumbuhan, atau mekanik review eksekusi mingguan — keempatnya ada di dokumen pemiliknya masing-masing dan dirujuk, bukan disalin.

---

## 1. Misi (satu baris)

> **Triangulate: game misteri co-op asimetris 3 pemain di Roblox — Searcher, Handler, dan Director memegang informasi berbeda, menyusun bukti, lalu menuduh pelaku, motif, dan cara dengan benar; sesi 15-30 menit, komunikasi tanpa mengetik.**

- Sumber: PRD §1 (co-op asimetris 3 pemain, komunikasi adalah gameplay utamanya, sesi 15-30 menit), PRD §3 (win condition: Director menuduh pelaku/motif/cara, dikonfirmasi 1 role lain), PRD §7 (komunikasi mobile-first), PRD §2 (empat pilar desain).
- Nama **Triangulate** dan arah visual "kaya detective": jawaban pemilik di thread EXTA-31, 4 Okt 2026, verbatim: *"namanya Triangulate dan arah visualnya kaya detective gitu / sisanya tentukan sendiri"*.

`ASUMSI` — Misi Triangulate belum pernah dinyatakan pemilik sebagai satu kalimat. Baris di atas adalah rumusan dari PRD, bukan kutipan pemilik. **Verifikasi/pengganti:** pengesahan pemilik, diusulkan lewat Benjamin — CEO. Sesuai pembagian peran, pemegang halaman ini tidak mengubah misi.

### 1.1 Hubungan dengan misi Exta

Misi Exta (kata pemilik, di EXTA-2) berlaku di atas halaman ini:

> *Exta adalah Management System milik Jetta. Penggunanya Jetta. Yang dikerjakan: mengelola project, tugas, kelas, dan daily brainstorming app.*
>
> **Menang dalam 90 hari:** naik nilai. (Lomba tidak ada untuk sekarang.)

`ASUMSI` — Misi Triangulate dianggap tidak boleh menyimpang dari misi Exta. **Verifikasi:** keputusan pemilik/CEO bila keduanya berbenturan.

**Catatan yang harus dibaca bersama:** Triangulate adalah proyek game, sementara ukuran menang Exta yang tersisa adalah "naik nilai". EXTA-50 mencatat bahwa proyek ini **belum punya sasaran Exta yang menampungnya** — O1 Exta adalah ujian, O3 adalah alat Exta yang dipakai, dan O2 (lomba) diparkir sejak 25 Sep 2026, sedangkan Triangulate dimulai 4 Okt 2026. Itu **lubang, bukan kesalahan workstream mana pun**; lihat §6 F4 dan §7 butir 1.

---

## 2. Tiga sasaran 90 hari

### 2.1 Penamaan: S1–S3, bukan O1–O3

Sasaran di halaman ini dinamai **S1, S2, S3** (Sasaran), bukan O1–O3.

Alasannya: EXTA-2 sudah memakai **O1/O2/O3 untuk sasaran Exta**, dan keduanya berbeda lingkup (Exta: ujian, lomba, alat Exta). Dua daftar berlabel sama di satu workspace adalah sumber salah rujuk. EXTA-50 sudah menuliskan keduanya sebagai "lapis A" dan "lapis B"; halaman ini memakai lapis B dengan nama yang tidak bertabrakan.

### 2.2 Horizon

| | |
|---|---|
| **Mulai** | Senin **5 Okt 2026** — `ASUMSI` dari EXTA-46 A8 (usulan kalender anchor). Belum disahkan pemilik; lihat §6 F3 dan §7 butir 1 |
| **Selesai** | **2 Jan 2027** (hari ke-90 dari anchor) |
| **Build** | minggu 0–8 (5 Okt – 6 Des 2026), rilis di gate minggu 8 (PRD §17) |
| **Pasca rilis** | minggu 9–12 (7 Des 2026 – 2 Jan 2027); minggu 12 terpotong di hari ke-90 |

`ASUMSI` — PRD §17 hanya memuat minggu 0–8. Panjang pasca rilis diambil 4 minggu supaya total tepat 90 hari; PRD tidak menetapkan panjangnya. **Verifikasi/pengganti:** EXTA-46 (operating plan) sudah menetapkan gate minggu 0–8 tanpa memperpanjang horizon — kalau anchor 5 Okt bergeser, seluruh tanggal di §2.3–§2.5 bergeser bersamanya.

`ASUMSI` — pembagian minggu per sasaran (0–4 / 5–8 / 9–12) adalah cara membaca roadmap §17, bukan keputusan baru. **Verifikasi:** EXTA-46 §1.2 sudah menetapkan isi dan pemilik tiap gate minggu 0–8.

### 2.3 S1 — Fondasi yang bisa diperiksa (minggu 0–4, 5 Okt – 8 Nov 2026)

| KR | Ambang | Sumber | Pemilik | Bukti yang diperiksa |
|---|---|---|---|---|
| S1-KR1 — Gate minggu 0–4 lulus | Minggu 0: drag P95 ≤ 100 ms dan ≥ 30 fps di Android kelas bawah; teks puzzle terbaca tanpa blur · minggu 1: 1 puzzle dokumen sobek selesai di perangkat mobile nyata · minggu 2: satu rantai objek→key→bukti jalan end to end dari data saja · minggu 3: 1 deduksi lahir dari 2 Clue Card, resep diperiksa di server · minggu 4: data client per role tidak memuat culprit/motive/solution | PRD §17 (target); **ambang terukur dari EXTA-46 §1.2 (`ASUMSI` A1, A2)** | Rafael — COO (pemutus gate); Nathan — CTO/CIO (pelaksana + verifikasi teknis) | Artefak bukti per gate + register gate |
| S1-KR2 — Kasus sebagai data | Loader kasus, objek + kunci, validator Clue Graph lulus pada kasus contoh | PRD §4, §10, §17 minggu 2 | Nathan — CTO/CIO (EXTA-33) | Skema + keluaran validator |
| S1-KR3 — Repo dan pipeline bisa dipakai | CI Luau, environment, secret, backup & uji restore | PRD §15, §17 | Devan — Infrastructure & Runtime Engineer (EXTA-34) | Hasil uji restore |

`ASUMSI` — ambang S1-KR1 berasal dari EXTA-46 dan **belum disahkan pemilik** (EXTA-46 E-2). Sampai disahkan, gate minggu 0–4 tetap bisa dijalankan, tetapi angkanya belum final.

### 2.4 S2 — Sesi 3 pemain yang layak dimainkan (minggu 5–8, 9 Nov – 6 Des 2026)

| KR | Ambang | Sumber | Pemilik | Bukti yang diperiksa |
|---|---|---|---|---|
| S2-KR1 — Sesi 3 pemain mulai tanpa bug | 2 preferensi role dihormati, timer lobby 45 dtk (opsi tunggu 90 dtk), ready check 10 dtk, AFK 60 dtk → NPC takeover, disconnect → slot ditahan 3 menit untuk rejoin; tidak ada P0 blocker | PRD §8, §17 minggu 5; EXTA-46 §1.2 | Rafael — COO (pemutus); Nathan (pelaksana) | Log sesi 3 pemain + tabel kepatuhan aturan lobby |
| S2-KR2 — Pengalaman role terukur | **Idle time tiap role < 25% sesi** dan **sesi menamatkan kasus > 55%**, dari ≥ 12 sesi / ≥ 36 player-session / ≥ 6 pemain berbeda; selisih dua sumber idle ≤ 5 poin persentase | PRD §6, §12, §17 minggu 7; **ambang sampel dari EXTA-46 A3, A4** | Rafael — COO (pemutus gate); Dewi — Operations Analyst (angka, EXTA-37); Rani — Data & Metrics Engineer (definisi, EXTA-36) | Ekspor telemetri per role + tabel rekonsiliasi |
| S2-KR3 — Onboarding dan kasus pertama siap | Case 0 tuntas **≤ 7 menit** (EXTA-46 A6, `ASUMSI`) — lihat catatan di bawah; story case #1 dengan 2 varian yang benar-benar berbeda cabang; ping wheel final | PRD §9, §10, §16, §17 minggu 6; EXTA-46 A6 | Nadia — Penulis Konten (EXTA-38); SOP: Bagas — Process Writer (EXTA-47) | Playtest internal minggu 6 + form observasi |

**Catatan pada S2-KR1 (F15).** "AFK 60 dtk → NPC mengambil alih" (PRD §8) berlaku untuk role apa pun, tetapi PRD §16 MVP hanya menyediakan NPC Searcher dan Handler dan menaruh NPC Director di P1. Artinya **perilaku saat Director AFK atau disconnect di MVP tidak terdefinisi**: tidak ada pengambil alih yang tersedia. Ini menyentuh implementasi (EXTA-32) dan risiko state drift (EXTA-44). Halaman ini tidak memilih jawabannya — itu keputusan lingkup MVP milik owner.

**Catatan pada S2-KR3 (F14).** PRD §9 menyebut Case 0 "±5 menit", EXTA-46 A6 menyebut "≤ 7 menit". Halaman ini memakai ≤ 7 menit karena itu ambang gate yang terukur, tetapi **angka mana yang berlaku belum diputuskan**, dan metrik onboarding PRD §12 ("% menamatkan Case 0 > 80%") bergantung padanya.

### 2.5 S3 — Rilis dan konten berjalan (minggu 9–12, 7 Des 2026 – 2 Jan 2027)

| KR | Ambang | Sumber | Pemilik | Bukti yang diperiksa |
|---|---|---|---|---|
| S3-KR1 — Rilis | Metrik minggu 7 terpenuhi pada gate minggu 8, tanpa pengecualian; kuesioner maturity Roblox terkirim | PRD §17 minggu 8, §14; EXTA-46 §1.2 | **Owner** (keputusan rilis); Rafael (verifikasi metrik); Nathan (build) | Snapshot metrik minggu 7 + checklist rilis |
| S3-KR2 — Konten berjalan | Story case baru **1 per 1-2 minggu** | PRD §10, §12 | **belum ada pemilik irama rilis** — SOP produksi ada di EXTA-47, pemiliknya belum ditetapkan (§6 F5, §7 butir 5) | Log rilis kasus |
| S3-KR3 — Retensi bergerak | Retensi **D1 18% / D7 5%** (target PRD) | PRD §12 | **belum ada pemilik angka** (§6 F5) | Laporan metrik mingguan |
| S3-KR4 — Matchmaking sehat | Median waktu tunggu **< 60 dtk**; sesi gagal start **< 10%** | PRD §12 | Rafael — COO (gate sesi mulai) | Laporan metrik |

### 2.6 Angka dan keputusan yang belum punya sumber — tidak diisi di halaman ini

| Angka / keputusan | Status | Di mana menunggu |
|---|---|---|
| Durasi timer *cleanup* | PRD §6 menyebut mekanismenya tanpa durasi; PRD §19 menundanya. EXTA-46 E-9 mengusulkan nilai awal (`ASUMSI` 8 menit per rantai) | **DR-02** (EXTA-48), status `terkirim`; keputusan owner |
| Nilai N Deduksi Kunci final | PRD §5 menetapkan N; PRD §19 menunda validasi ke playtest minggu 7 (naik/turun 1). PRD §5 sendiri tidak konsisten (§6 F1) | **DR-03** (EXTA-48); validasi angkanya dari playtest minggu 7 (EXTA-37) |
| Ambang "quit di 5 menit pertama" | PRD §12 hanya menulis "Dipantau" — tanpa angka dan tanpa pemilik | EXTA-50 B6; EXTA-48 G-09 (keputusan tanpa pemilik) |
| Rumus rank S/A/B/C | PRD §5 menyebut komponen (waktu, jumlah tuduhan, hint), bukan rumusnya. Skema kasus PRD §10 juga belum punya `par_time_s` yang dibutuhkan rank berbasis waktu | EXTA-50 B9; EXTA-48 G-10 dan G-18; EXTA-36 menyediakan komponennya |
| Target DAU | Tidak ada di PRD §12 — hanya retensi D1/D7 | EXTA-42; ini angka pertumbuhan/keuangan, bukan milik halaman ini |
| Durasi Case 0 | Dua angka berbeda: PRD §9 "±5 menit" vs EXTA-46 A6 "≤ 7 menit" (`ASUMSI`) | Pengesahan owner atas ambang gate; EXTA-48 mencatatnya sebagai tabrakan (§6 F14) |
| Perilaku Director AFK di MVP | PRD §8 menjanjikan NPC takeover untuk role apa pun; PRD §16 menaruh NPC Director di P1 | Keputusan lingkup MVP — **Owner** (§6 F15) |
| Ambang gate minggu 0–8 | EXTA-46 A1–A8 masih `ASUMSI`; dipakai halaman ini sebagai ambang KR | EXTA-48 G-13 (tanpa pemilik); persetujuan owner |
| Ukuran sampel playtest | EXTA-46 A4 (`ASUMSI`: ≥ 12 sesi / ≥ 36 player-session / ≥ 6 pemain) | EXTA-48 G-14 (tanpa pemilik) |
| Kewenangan mengubah N dan timer | PRD §19 menyerahkan ke playtest, tanpa menyebut siapa yang berwenang mengubah | EXTA-48 G-12 (tanpa pemilik) |
| Pemilik angka retensi D1/D7 | Target ada di PRD §12, pemiliknya belum tercatat | §6 F5 |

**Angka yang sudah ada hasilnya, dan mengapa tidak dikutip di sini:** model pendapatan dan unit economics (EXTA-42), model biaya build + runway (EXTA-43), register risiko + ambang belanja (EXTA-44), buku besar (EXTA-45), positioning/ICP (EXTA-41), kamus metrik (EXTA-36). Semuanya **dirujuk keberadaannya saja**. Mengutip ulang atau menurunkan angka darinya adalah pekerjaan CFO/CMO, bukan pekerjaan halaman narasi.

---

## 3. Hak keputusan

Kolom "Pemilik" merujuk agent/workstream yang benar-benar ada di board.

| Keputusan | Pemilik | Dasar |
|---|---|---|
| Misi dan sasaran 90 hari proyek | **Pemilik (Jetta)**; diusulkan lewat Benjamin — CEO | Misi bukan milik pemegang halaman narasi |
| Nama game dan arah visual | **Pemilik (Jetta)** — sudah diputuskan: "Triangulate", arah detective | Jawaban pemilik di thread EXTA-31, 4 Okt 2026 |
| Perubahan keputusan terkunci PRD §3 (tema, win condition, kamera, mode 2 pemain, rotasi role) | **Pemilik + CEO (dua pihak)** | PRD §3 berlabel "Keputusan Terkunci" |
| **Perubahan lingkup MVP** | **Owner** | EXTA-46 §2.1; PRD §16 |
| **Rilis minggu 8** | **Owner** | EXTA-46 §2.1; PRD §17 |
| **Promosi issue dari backlog** | **Owner** | EXTA-46 §2.1 (menambah kerja) |
| **Gate minggu 0–5 lulus/gagal** | **Rafael — COO**; verifikasi teknis Nathan sebagai bukti | EXTA-46 §2.1 |
| **Gate minggu 6–7 lulus/gagal** | **Rafael — COO**; angka diverifikasi Dewi | EXTA-46 §2.1 |
| **Definisi metrik & "input bermakna"** | **Rani** (EXTA-36); diaudit Dewi (EXTA-37) | EXTA-46 §2.1, C-7; EXTA-36 |
| Baseline vs target dan audit handoff | Dewi (EXTA-37) | EXTA-37 |
| Otomasi laporan metrik dan pengingat gate | Bima (EXTA-35) — aktivasi otomasi/akses baru perlu owner | EXTA-46 §2.2 |
| Arsitektur, skema data kasus, pemisahan info per role | Nathan — CTO/CIO (EXTA-32, EXTA-33) | PRD §15, §16 |
| CI/CD, environment, secret, backup & restore | Devan (EXTA-34) | PRD §15 |
| Operating plan, matriks kepemilikan, proses playtest, review eksekusi mingguan | Rafael — COO (EXTA-46) | EXTA-46 |
| SOP produksi kasus dan SOP playtest | Bagas (EXTA-47) | PRD §9, §10 |
| Strategi dan prioritas lintas fungsi | Benjamin — CEO | EXTA-31 |
| Triase, slot WIP, peta dependensi antar workstream | Mika (EXTA-51) | EXTA-51 |
| Angka keuangan: model pendapatan, unit economics, harga case pack | Michelle — CFO (EXTA-42) | PRD §13 |
| Angka biaya dan runway | Ayu (EXTA-43); buku besar: Dimas (EXTA-45) | PRD §17, §13 |
| Ambang belanja dan penerapannya | Bayu (EXTA-44) — penegak; keputusannya di CFO | EXTA-44 |
| Angka pertumbuhan: positioning, ICP, akuisisi | Clara — CMO (EXTA-41) | PRD §12, §11 |
| Risk register | Bayu (EXTA-44) | PRD §18 |
| Konten kasus (Case 0, story case) dan copy komunikasi | Nadia (EXTA-38); copy disetujui Clara | EXTA-46 §2.2 |
| Art direction cozy noir dan mockup UI mobile | Sari (EXTA-39); arah visual disetujui owner | EXTA-46 §2.2; PRD §19 |
| Riset eksternal: benchmark, rating, texture, Robux | Damar (EXTA-40) | EXTA-46 §2.2 |
| Log keputusan PRD dan antrean decision request §19 | Rangga (EXTA-48) | PRD §3, §19 |
| Narasi, versi halaman ini, dan konsistensi istilah di board | Kirana (EXTA-49) | EXTA-49 |
| Peta key result 90 hari | Wisnu (EXTA-50) | EXTA-50 |

**Rujukan silang:** EXTA-48 (log keputusan) memakai §3 halaman ini sebagai **sumber kolom "pemilik"** untuk 8 entri log keputusan PRD §3, karena PRD §3 tidak mencantumkan pemilik per keputusan. Kalau salah satu baris di §3 tidak cocok dengan kenyataan, itu yang perlu diperbaiki lebih dulu — dokumen lain merujuknya.

### 3.1 Yang butuh persetujuan dua pihak

1. **Perubahan misi atau sasaran proyek** — pemilik + CEO.
2. **Perubahan keputusan terkunci PRD §3** — pemilik + fungsi yang terdampak. `ASUMSI` — PRD menyebut §3 "keputusan terkunci" tanpa prosedur pembatalannya; **verifikasi:** EXTA-48 mencatat "apa yang membatalkan" tiap keputusan §3.
3. **Merge ke `main` dan perubahan repo/setting workspace** — persetujuan pemilik. Aturan yang berlaku di EXTA-31: agent hanya mengusulkan lewat PR, tidak merge ke `main`.
4. **Belanja di atas ambang** — penegaknya Bayu (EXTA-44); keputusannya di Michelle — CFO. Ambangnya tidak dikutip di halaman ini (angka keuangan).
5. **Di dalam game (bukan tata kelola board):** hanya dua aksi yang butuh persetujuan 2 role — **tuduhan akhir** dan **pakai hint** (PRD §8). Ini aturan desain, bukan aturan board.

---

## 4. Kadensi tinjauan dan arti "on track"

### 4.1 Pembagian kadensi — halaman ini vs EXTA-46

Halaman ini memegang **kerangka kadensi organisasi** dan **definisi "on track"**. EXTA-46 §4 memegang **review eksekusi/gate mingguan** (agenda 30 menit, input wajib, output wajib, aturan anti-rubber-stamp). Keduanya **tidak diduplikasi di sini** — halaman ini menyebut kadensinya, EXTA-46 menjalankannya.

EXTA-46 C-6 mencatat potensi kadensi dobel ini dan menyerahkannya ke review mingguan pertama; pembagian di atas adalah jawaban halaman ini atas temuan itu.

### 4.2 Kadensi

| Kadensi | Yang ditinjau | Pemilik | Sumber |
|---|---|---|---|
| Harian | Catatan pengeluaran proyek per pos | Dimas (EXTA-45) | EXTA-44, EXTA-45 |
| Mingguan — **eksekusi/gate** | Gate minggu berjalan, bottleneck, metrik, perubahan lingkup, aksi & eskalasi | Rafael — COO | **EXTA-46 §4** (mekaniknya di sana, bukan di sini) |
| Mingguan (Senin) — **board** | Setiap issue `in_progress`, langkah berikutnya, penghambatnya; promosi dan satu keputusan prioritas bila dua hal bersaing | Benjamin — CEO (pemutus); Mika — Chief of Staff (pengelola alur, EXTA-7) | EXTA-2 (kadensi board), EXTA-7 |
| Dua mingguan | Status sasaran Exta, satu baris per sasaran: on track / berisiko / di luar jalur | Benjamin — CEO | EXTA-2 |
| Per playtest (minggu 6 internal, minggu 7 pemain nyata) | Idle time per role, sesi tamat, quit 5 menit pertama, hint per sesi | Dewi (EXTA-37), angka dari Rani (EXTA-36) | PRD §6, §12, §17 |
| Bulanan | Anggaran vs realisasi dan risiko; kemajuan sasaran 90 hari terhadap KR | Bayu (EXTA-44); peta KR: Wisnu (EXTA-50) | EXTA-44, EXTA-50 |
| Per keputusan owner | Entri log keputusan (tanggal, keputusan, alasan, yang membatalkan) | Rangga (EXTA-48) | EXTA-2, PRD §3, §19 |
| Checkpoint 30/60/90 hari | Status tiap sasaran: on track / berisiko / di luar jalur | Benjamin — CEO | EXTA-2 (checkpoint Exta: 25 Okt / 24 Nov / 24 Des 2026) |

### 4.3 Definisi "on track"

- **S1** — gate minggu berjalan **lulus dengan artefak bukti yang bisa diperiksa**, dan tidak ada gate tertinggal lebih dari satu minggu. Gate yang lulus tanpa artefak dicatat **gagal** (EXTA-46 G-1, §4.3).
- **S2** — playtest minggu 7 menunjukkan **idle < 25%** dan **selesai > 55%** (PRD §17). Bila selesai < 55% atau > 85%, aturan PRD §19 berlaku: N Deduksi Kunci naik/turun 1 setelah validasi.
- **S3** — story case rilis tiap 1-2 minggu; metrik menuju D1 18% / D7 5%; median waktu tunggu < 60 dtk; sesi gagal start < 10% (PRD §10, §12).
- **Berlaku untuk semua sasaran** — KR yang **belum punya pemilik angka** atau **belum punya instrumen** tidak bisa dinyatakan on track; tidak ada yang bisa membuktikan angkanya benar. Daftar KR seperti itu ada di §2.6 dan §6 F5, F12.

`ASUMSI` — ambang "tidak ada gate tertinggal lebih dari satu minggu" dan bentuk checkpoint 30/60/90 mengikuti kadensi Exta di EXTA-2, bukan keputusan baru. **Verifikasi:** EXTA-46 §4 saat review mingguan pertama berjalan.

---

## 5. Versi satu paragraf

> Triangulate adalah game misteri co-op asimetris untuk 3 pemain di Roblox. Tiga peran memegang informasi berbeda: **Searcher** menjelajah lokasi dan melaporkan objek, **Handler** merekonstruksi bukti di meja puzzle top-down, dan **Director** menggabungkan Clue Card di clue board sampai lahir deduksi, lalu menuduh pelaku, motif, dan cara. Menyelesaikan puzzle saja tidak cukup — kemenangan datang dari deduksi yang benar dan dikonfirmasi satu role lain. Sesi 15-30 menit, komunikasi utama tanpa mengetik lewat ping wheel, Report Card, dan Target Marker, mayoritas pemain mobile. Tema cozy noir non-gore, target rating 13+. Rencananya: build 8 minggu dengan gate per minggu, playtest 3 pemain nyata di mobile pada minggu 7, rilis pada minggu 8, lalu story case baru tiap 1-2 minggu.

- Sumber: PRD §1, §2, §3, §4, §7, §10, §12, §14, §15, §17.
- `ASUMSI` — paragraf ini ditulis untuk anggota tim baru atau pihak luar yang meminta ringkasan. Board **tidak** memuat rencana investor, pendapatan, atau pelanggan (PRD §13 tanpa pay-to-win). **Verifikasi/pengganti:** versi positioning dan store page ada di Clara (EXTA-41); versi pendapatan ada di Michelle (EXTA-42).

---

## 6. Temuan konsistensi (narasi vs board)

Diperiksa: PRD v0.2, deskripsi 22 issue turunan EXTA-31, deskripsi project, `README.md`, EXTA-2, dan hasil 11 workstream yang sudah masuk (EXTA-36, 38, 41–48, 50).

| # | Tingkat | Temuan | Sisi A | Sisi B |
|---|---|---|---|---|
| F1 | **Tinggi** | Rumus N tidak konsisten dengan angkanya sendiri | PRD §5: "N = ... 3 dari 5 untuk daily case ... Rumusnya kira-kira 65% dari total, dibulatkan ke atas" | PRD §5 angka: 3/5 = **60%**, sedangkan 65% × 5 dibulatkan ke atas = **4**. Untuk kasus standar (4/6 = 66,7%) dan Case 0 (2/3 = 66,7%) rumusnya cocok. Daily case satu-satunya yang tidak |
| F2 | **Tinggi** | Nama game sudah diputuskan pemilik, tapi dokumen masih "working title" | Jawaban pemilik di thread EXTA-31, 4 Okt 2026: "namanya **Triangulate** dan arah visualnya kaya detective gitu" | Judul PRD masih "Co-op Puzzle Mystery (Working Title) — v0.2"; `README.md` sudah memakai `# Triangulate` sebagai judul tetapi barisnya masih "Co-op Puzzle Mystery (working title)"; PRD §19 masih mencantumkan "Nama game dan arah visual" sebagai pertanyaan terbuka. Jadi namanya sudah dipakai setengah jalan — belum ada yang menyatakan "working title" itu dicabut |
| F3 | **Tinggi** | Pemilik mendelegasikan sisa §19, dan empat workstream sudah mengajukan rekomendasi — belum ada keputusan, dan belum ada kewenangan yang tercatat | Jawaban pemilik: "sisanya tentukan sendiri" | EXTA-48 sudah menyerahkan antrean **DR-01…DR-03** (nama+visual, durasi timer cleanup, validasi N) dengan status `terkirim`, plus **G-01…G-18** untuk keputusan yang menggantung di luar §19. EXTA-46 E-8/E-9, EXTA-50 butir 5–6, EXTA-44 F6, dan EXTA-41 kebutuhan #2–#3 mengajukan hal yang sama dari arah berbeda. Yang belum ada: siapa berwenang menutup, dan di mana jawabannya dicatat |
| F4 | **Tinggi** | Ukuran "menang dalam 90 hari" untuk Triangulate belum ada, dan proyek ini belum punya sasaran Exta yang menampungnya | EXTA-2 menetapkan ukuran menang Exta: **naik nilai**; lomba diparkir 25 Sep 2026 | PRD tidak menyebut lomba, tenggat eksternal, atau ukuran menang proyek ini. EXTA-50: O1 Exta = ujian, O3 = alat Exta, O2 = parkir — "proyek game tidak masuk ketiganya". Triangulate mulai 4 Okt, sesudah O2 diparkir |
| F5 | **Tinggi** | Tiga metrik PRD §12 tidak punya pemilik angka, satu di antaranya juga tanpa ambang | PRD §12 menetapkan target retensi D1/D7 18%/5%, "quit di 5 menit pertama dipantau", dan "story case baru 1 per 1-2 minggu" | EXTA-50 B6 (quit — tanpa ambang **dan** tanpa pemilik), B8 (irama rilis — SOP ada di EXTA-47, pemilik irama tidak ditetapkan), B1 (retensi — definisi ada di Rani, pemilik angka tidak ada). EXTA-36 mendefinisikan M-01, M-02, M-08 tetapi "pemilik tafsir"-nya belum ditetapkan |
| F6 | Sedang | Pilar desain absolut vs ambang metrik | PRD §2 pilar 1: "Tidak ada yang menganggur" | PRD §6: idle time tiap role harus **di bawah 25% sesi** — artinya sampai 25% menganggur masih lulus |
| F7 | Sedang | Metrik onboarding berpotensi tidak bisa diukur | PRD §12: "% menamatkan Case 0 > 80%" | PRD §9: Case 0 "wajib sekali per akun, **bisa di-skip**". Penyebut metrik belum didefinisikan; EXTA-36 mendefinisikan M-07 tetapi belum memutuskan apakah `case_0_skipped` masuk penyebut |
| F8 | Rendah | Jenis bukti "foto" menggantung | PRD §3: potongan puzzle = "dokumen sobek, **foto**, timeline, cipher" (4 jenis) | PRD §4 MVP: 3 tipe (dokumen sobek, timeline, cipher); P1: spot-the-difference, rangkaian kabel, kunci kombinasi. "Foto" tidak ada di daftar MVP maupun P1 |
| F9 | Rendah | Rujukan bagian di changelog salah | PRD §0 baris 10: perbaikan "8 minggu + minggu 0 untuk spike teknis" dirujuk ke **§16** | Isi "8 minggu + minggu 0" ada di **§17** (Roadmap); §16 adalah Scope |
| F10 | Rendah | Judul roadmap vs isinya | PRD §17 berjudul "Roadmap (8 Minggu)" | Tabelnya berisi minggu **0-8** (9 baris). Changelog §0 baris 10 sendiri menulis "8 minggu **+ minggu 0**" |
| F11 | **Tinggi** | Minggu 2–8 tidak punya issue pelaksana, jadi KR S1 dan S2 tidak punya penanggung di board | Halaman ini menetapkan KR untuk minggu 0–8 (§2.3, §2.4) | Satu-satunya issue yang menyentuh implementasi adalah EXTA-53 (status `backlog`, cakupan minggu 0–1). EXTA-46 B-01/C-1 mencatat celah yang sama: "gate minggu 2–8 tidak punya pelaksana; Nathan memikul seluruh build sendirian". EXTA-32/33/34 menghasilkan arsitektur, skema, dan CI — bukan fitur |
| F12 | Sedang | Seluruh metrik PRD §12 berstatus belum bisa dihitung | PRD §12 dan §17 memakai angka-angka itu sebagai target dan gate (mis. gate minggu 7) | EXTA-36: 13 metrik (M-01…M-13) **seluruhnya berstatus `BLOKIR`** — "sink telemetri belum ada, jadi belum ada satu angka pun yang bisa dihitung hari ini". Artinya tidak ada KR di §2 yang bisa menghasilkan angka sekarang |
| F13 | Sedang | N Deduksi Kunci Case 0 lebih kecil dari jumlah field tuduhan | PRD §5: N = 2 dari 3 untuk Case 0 | PRD §5: form tuduhan meminta tiga field (Pelaku, Motif, Cara). EXTA-38 menutup Pelaku dan Cara lewat dua Deduksi Kunci dan menjadikan deduksi Motif bonus rank; kalau keputusannya harus lain (mis. form dua field untuk Case 0), itu perubahan aturan yang butuh persetujuan |
| F14 | Sedang | Dua angka berbeda untuk durasi Case 0, dan KR S2-KR3 di halaman ini memakai salah satunya | PRD §9: "Case 0 (±5 menit)". Halaman ini §2.4 memakai **≤ 7 menit** | EXTA-46 A6: "Case 0 ≤ 7 menit" (`ASUMSI`, belum disahkan). Metrik onboarding PRD §12 ("% menamatkan Case 0 > 80%") bergantung pada angka mana yang dipakai — ambang lebih longgar membuat lebih banyak sesi terhitung tuntas. EXTA-48 mencatatnya sebagai tabrakan §9 vs A6 |
| F15 | Sedang | Perilaku saat Director AFK/disconnect tidak terdefinisi untuk MVP | PRD §8: AFK 60 dtk → NPC mengambil alih role itu (berlaku untuk role apa pun), dan NPC mengisi slot yang kosong | PRD §16 MVP hanya mencantumkan "NPC Searcher dan Handler"; NPC Director masuk **P1**. Jadi MVP tidak punya NPC Director untuk mengambil alih saat Director AFK, padahal §8 menjanjikannya. Menyentuh EXTA-32 (implementasi) dan EXTA-44 (risiko state drift) |

Catatan istilah: pencarian varian istilah di seluruh deskripsi issue dan hasil workstream tidak menemukan pergeseran makna — yang ada hanya perbedaan huruf besar/kecil (`clue card` di EXTA-38 vs `Clue Card` di PRD) dan `Deduction` di EXTA-32 yang sah sebagai nama modul kode. **Tidak dilaporkan sebagai temuan.** Penamaan S1–S3 di §2.1 adalah perbaikan yang dilakukan halaman ini, bukan temuan.

---

## 7. Butir eskalasi

Ditulis sebagai butir; tidak dikirim ke agent lain langsung dan tidak memakai mention.

1. **Ke Benjamin — CEO (arah dan sasaran).**
   - **F4** — Triangulate belum punya sasaran Exta yang menampungnya, dan ukuran menang 90 hari belum ada. EXTA-50 mengusulkan dua pilihan: hubungkan ke O2 saat pemilik menamai satu lomba, atau tetapkan sasaran baru bertenggat. Selama belum diputuskan, sasaran di §2 halaman ini hanya bisa dinilai dari gate internal PRD §17.
   - **F2** — pemilik sudah memutuskan nama "Triangulate" dan arah detective; PRD, §19, dan `README.md` masih "working title". Perlu penetapan siapa yang merevisi dokumen dan kapan.
   - **F3** — pemilik mendelegasikan sisa §19; perlu penetapan siapa yang menutupnya dan di mana jawabannya dicatat. EXTA-48 sudah menyerahkan antrean **DR-01…DR-03** dan daftar **10 keputusan tanpa pemilik (G-03, G-04, G-05, G-09, G-10, G-12, G-13, G-14, G-17, G-18)** — untuk G-13/G-14/G-17 usulannya sudah ada (EXTA-46 A1–A8, EXTA-36 E-7), yang dibutuhkan persetujuan. EXTA-48 juga memperingatkan hal yang paling berisiko hilang: pertanyaan §19 diajukan **empat arah sekaligus** hari ini (EXTA-44 F6, EXTA-46 E-8/E-9, EXTA-50 butir 5–6, EXTA-41 kebutuhan #2–#3) — kalau dijawab di tempat berbeda, tidak ada jawaban yang tercatat sebagai keputusan.
   - **F14/F15** — dua hal yang hanya bisa ditutup di tingkat ini: durasi Case 0 (dua angka berbeda) dan perilaku saat Director AFK di MVP (PRD §8 menjanjikan, §16 menaruhnya di P1). Keduanya keputusan lingkup, bukan temuan dokumen.
   - **Misi §1 masih draf** dan butuh pengesahan pemilik. Kalimat misi Exta di §1.1 adalah kata pemilik dan tidak perlu disahkan lagi.
2. **Ke Rangga — Decision Log (EXTA-48).** F1, F8, F9, F10, F13, **F14, F15** adalah temuan dokumen yang perlu masuk log/antrean §19 — bukan untuk saya putuskan. Sebagian sudah tercatat di sana: F1 sebagai tabrakan §5, F14 sebagai tabrakan §9 vs A6, dan F3 sebagai empat permintaan §19 yang berpotensi diajukan dua kali. **F15 belum ada di daftar tabrakan EXTA-48** dan menurut saya yang paling perlu ditambahkan: ia menyentuh perilaku sesi MVP, bukan hanya angka. Antrean **DR-01…DR-03** dan daftar **G-01…G-18** sudah terkirim. Satu hal yang saya dukung dari EXTA-48: DR-01–DR-03 dipakai sebagai tempat tunggal jawaban §19 dicatat, supaya jawaban yang tersebar di beberapa issue tidak hilang.
3. **Ke Rafael — COO (operasi).** F11 — minggu 2–8 tanpa issue pelaksana, sehingga KR S1 dan S2 tidak punya penanggung. EXTA-46 sudah mengangkatnya sebagai B-01/E-1 dengan rekomendasi "promosikan per minggu"; halaman ini menambahkan satu konsekuensi yang belum tertulis di sana: **KR tanpa penanggung tidak bisa dinyatakan on track** (§4.3).
4. **Ke Michelle — CFO (angka keuangan).** Halaman ini tidak memakai satu pun angka keuangan. Yang perlu diketahui CFO: EXTA-44 F1 (biaya yang diminta PRD belum punya pos anggaran) dan EXTA-43 (produksi konten pasca rilis di luar plafon bulanan) menyentuh langsung KR S3-KR2 — irama rilis 1–2 minggu yang **belum punya pemilik** (F5). Angkanya tidak saya kutip atau turunkan.
5. **Ke Clara — CMO (angka pertumbuhan).** F5 — retensi D1/D7 belum punya pemilik angka; EXTA-50 B8 (irama rilis konten) juga belum. EXTA-36 E4 (zona waktu batas hari D1/D7) dan E5 (definisi "bermain" untuk retensi) menunggu CMO, dan keduanya menentukan apakah angka retensi bisa dibandingkan dengan target PRD §12.
6. **Ke Mika (lintas fungsi).** F1, F3, F6, F7, F13, F15 menyentuh lebih dari satu workstream (EXTA-32, EXTA-33, EXTA-37, EXTA-38, EXTA-46); F11 dan F12 menyentuh hampir semua workstream teknis. EXTA-46 C-1…C-8 sudah mendaftar delapan celah kepemilikan — halaman ini tidak menduplikasinya, hanya menunjuk bahwa F11 dan F12 belum ada di daftar itu.

---

**Riwayat versi**

| Versi | Tanggal | Perubahan | Status |
|---|---|---|---|
| v0.1 | 2026-10-04 | Versi pertama: misi draf, tiga sasaran 90 hari, hak keputusan, kadensi + definisi on track, versi satu paragraf, 10 temuan konsistensi, 5 butir eskalasi | Draf |
| v0.2 | 2026-10-04 | Sasaran proyek dinamai ulang **S1–S3** supaya tidak bertabrakan dengan O1–O3 Exta di EXTA-2 (§2.1) · horizon diberi tanggal nyata 5 Okt 2026 – 2 Jan 2027 (§2.2) · KR disambungkan ke ambang terukur EXTA-46 (A1–A6) dan ke pemilik gate per §2.1 · hak keputusan diselaraskan dengan EXTA-46 §2.1/§2.2 dan EXTA-44 (§3) · kadensi dipisah tegas dari review eksekusi mingguan EXTA-46, termasuk jawaban atas temuan C-6 (§4.1), dan diselaraskan dengan kadensi Exta di EXTA-2 (checkpoint 25 Okt / 24 Nov / 24 Des) · lima temuan baru: F11 (minggu 2–8 tanpa issue pelaksana), F12 (13 metrik berstatus `BLOKIR`), F13 (N Case 0 vs jumlah field tuduhan), F14 (durasi Case 0: §9 ±5 menit vs A6 ≤ 7 menit), F15 (Director AFK di MVP tidak terdefinisi, §8 vs §16); F4 diperkuat dengan temuan EXTA-50; F5 diperluas ke B6/B8; F3 diperbarui setelah EXTA-48 menyerahkan DR-01…DR-03 dan daftar 10 keputusan tanpa pemilik · angka keuangan dan pertumbuhan dinyatakan dirujuk, bukan dikutip (§2.6) · eskalasi disegarkan ke enam tujuan | Draf — menunggu pengesahan pemilik untuk §1 dan review CEO |
