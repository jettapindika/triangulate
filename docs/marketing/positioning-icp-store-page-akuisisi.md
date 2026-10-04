# EXTA-41 — Positioning, ICP, Store Page, dan Rencana Akuisisi Awal

Pemilik: **Clara — CMO** · Issue: EXTA-41 · Induk: EXTA-31 · Tanggal: 2026-10-04

Rujukan PRD: `docs/prd-v0.2.md` (§2, §3, §5, §7, §8, §9, §10, §11, §12, §13, §14, §19).

Konvensi sumber: klaim PRD dirujuk sebagai §n; klaim platform dirujuk dengan URL `create.roblox.com`; klaim yang belum terverifikasi ditandai **ASUMSI** beserta apa yang memverifikasinya; simpulan turunan ditandai **INFERENSI**.

---

## 1. Positioning

Triangulate adalah game misteri co-op tiga pemain di Roblox yang hanya bisa dipecahkan kalau tiga orang saling bicara. Tiap pemain memegang potongan informasi yang berbeda dan tidak bisa melihat milik yang lain: Searcher menjelajah lokasi, Handler menyusun bukti di meja, Director menyatukan petunjuk dan menuduh pelaku. Satu kasus selesai dalam 15-30 menit tanpa perlu voice dan tanpa perlu mengetik, dengan kontrol yang dirancang untuk mobile. Menyelesaikan puzzle tidak cukup — kemenangan datang dari deduksi yang benar, bukan dari kecepatan tangan.

**Kalimat yang diharapkan diulang pemain:** "Kita bertiga main detektif, tiap orang tahu hal yang beda, dan nggak bisa menang kalau nggak ngobrol."

### Tiga pesan kunci

| # | Pesan | Bukti pendukung | Objection yang dijawab |
|---|---|---|---|
| 1 | **Tiga pemain, tiga sudut pandang, satu kebenaran.** Informasi dipisah per peran, jadi komunikasi adalah gameplay utamanya, bukan tambahan. | §2 pilar 2; §4 Clue Graph; §15 (server hanya mengirim data sesuai role; pemeriksaan resep deduksi dan tuduhan hanya di server) | "Kenapa harus bertiga? Bisa nggak sendiri?" → Bisa, tapi solo/duo memakai NPC dan itu mode sekunder (§8). |
| 2 | **Sesi 15-30 menit, cukup satu kali duduk. Tanpa voice, tanpa mengetik.** | §1 (sesi 15-30 menit); §7 ping wheel, Report Card, Target Marker, Pinpoint, Table Preview; §7 "voice tidak diwajibkan"; §14 "tidak ada voice wajib" | "Aku malas main game yang butuh headset atau chat." → Komunikasi lewat sentuh; text chat hanya opsi. |
| 3 | **Menang bukan karena puzzle, tapi karena deduksi.** Kalian bisa menyelesaikan semua puzzle dan tetap kalah. | §5 (menang = tuduhan Pelaku/Motif/Cara benar + konfirmasi 1 role lain); §5 batas 3 percobaan dan feedback hanya "X dari 3 benar"; §5 rank S/A/B/C | "Ini cuma escape room lagi?" → Tidak: puzzle membuka bukti, keputusan akhirnya penilaian, bukan kelincahan. |

**Yang secara sadar BUKAN Triangulate** — dipakai untuk mencegah salah harap dan salah klasifikasi:

- Bukan game horor atau gore; tema cozy noir non-gore, target 13+ (§3, §14).
- Bukan social hangout dan bukan roleplay; tidak ada mode mengobrol bebas sebagai aktivitas utama.
- Bukan pay-to-win: solusi dan hint tidak bisa dibeli (§13).
- Bukan game kompetitif antar-pemain; tidak ada mode PvP.

> **Peringatan klasifikasi (konsekuensi produk, bukan sekadar copywriting).** Roblox menetapkan klasifikasi maturity dari judul dan deskripsi. Judul atau deskripsi yang menyebut *social hangout* otomatis mengklasifikasikan game sebagai social hangout — social hangout tanpa private space hanya untuk 16+, dan dengan private space hanya untuk 18+. Menyebut *romantic themes*, *private spaces*, atau *settings intended for adults* di judul/deskripsi juga memaksa 18+.
> Sumber: https://create.roblox.com/docs/production/promotion/content-maturity
> **Konsekuensi:** jangan menulis "hangout", "roleplay", "vibes", "chill with friends", "private room", atau "cafe/bar" di store page mana pun. Kata-kata itu memotong akses ke audiens 13-15 yang justru target utama kita.

---

## 2. ICP

### 2.1 ICP utama — "Tiga teman, satu sesi"

| Dimensi | Isi |
|---|---|
| **Siapa** | Kelompok 3 teman, usia 13+, sudah main Roblox, mayoritas mobile (§12) |
| **Minat** | Misteri, detektif, puzzle, cerita (§12) |
| **Pola main** | Sesi pendek 15-30 menit, biasanya pada waktu yang disepakati bersama (sepulang sekolah atau malam) |
| **Platform** | Roblox di mobile, sesekali PC (§12 "mayoritas mobile") |
| **Trigger mulai** | (a) bosan pada game yang sudah mereka mainkan bersama; (b) ingin melakukan sesuatu bersama dalam satu duduk, bukan main sendiri-sendiri; (c) tertarik konten misteri/detektif; (d) teman satu grup sudah main dan mengajak |
| **Penghambat** | (a) butuh 3 orang hadir bersamaan — kalau satu tidak bisa, sesi gagal; (b) takut "jadi yang nggak tahu apa-apa" — peran Director terasa paling berat (§8 menyebut NPC Director sulit dibuat, jadi prioritaskan manusia); (c) keraguan pada kualitas game Roblox buatan kecil; (d) malas membaca atau mengetik di mobile |
| **Alat pengganti hari ini** | Game party/impostor co-op di Roblox, obby dan escape room Roblox, aplikasi escape-room mobile, game papan digital, atau menonton video misteri bersama. **ASUMSI** — belum ada riset pengguna. Yang memverifikasi: playtest minggu 7 (§17) dan benchmark kompetitor di EXTA-40. |

**Implikasi akuisisi.** Pesan utama harus menjawab hambatan (a) dan (b), bukan menjual daftar fitur. Karena itu private server + undangan teman menjadi channel utama, dan peran Director harus ditampilkan sebagai posisi yang menyenangkan, bukan sebagai pekerjaan.

### 2.2 ICP sekunder — "Solo/duo yang tidak mau menunggu"

| Dimensi | Isi |
|---|---|
| **Siapa** | Pemain solo atau pasangan 2 orang yang tetap ingin main sekarang tanpa menunggu teman ketiga |
| **Pola main** | Solo sebagai Director dengan dua NPC; atau Searcher + Director manusia dengan Handler NPC "Archivist" (§3, §8) |
| **Trigger mulai** | Lobby sepi (§18 risiko "lobby sepi"); ingin mencoba dulu sebelum mengajak teman |
| **Penghambat** | NPC Director lemah (§8: kesulitan tinggi, prioritaskan manusia); sesi dengan NPC Director dihitung rank terpisah tanpa leaderboard utama (§8), sehingga progres terasa kurang dihargai |
| **Alat pengganti** | Game misteri single-player; puzzle mobile |

**Implikasi akuisisi.** ICP sekunder adalah **jalur konversi ke ICP utama**, bukan target akhir. Pesan yang tepat: "coba dulu sendiri, lalu ajak dua temanmu." Jangan alokasikan channel terpisah untuk solo sebelum MVP terbukti — NPC Director baru masuk P1 (§16).

---

## 3. Draf Store Page Roblox

### 3.1 Judul kerja

**Rekomendasi: `Triangulate: Co-op Mystery`** (26 karakter)

Alasan: memuat nama proyek plus kata kunci genre yang dicari pemain ("co-op", "mystery"), konsisten dengan nama repo, tanpa pengulangan kata. Roblox menyarankan nama yang konsisten dan unik, melarang spam kata, dan membolehkan maksimal satu-dua emoji yang ditempatkan baik.
Sumber: https://create.roblox.com/docs/production/publishing/publish-games-and-places

Alternatif bila nama final berbeda (PRD §19 masih membuka keputusan nama):

- `Triangulate: Tiga Detektif`
- `Triangulate: 3-Player Detective Mystery`

**Eskalasi:** nama final adalah pertanyaan terbuka §19 — butuh keputusan owner sebelum store page dipublikasikan, karena nama mengunci keyword judul dan ikut menentukan klasifikasi maturity.

### 3.2 Deskripsi

> Triangulate adalah game misteri co-op untuk 3 pemain di Roblox. Satu tim, tiga sudut pandang: Searcher menjelajah lokasi, Handler menyusun bukti di meja, Director menyatukan petunjuk dan menuduh pelaku. Informasi dibagi per peran, jadi kalian hanya bisa menang kalau saling bicara.
>
> Satu kasus selesai dalam 15-30 menit. Tidak perlu voice dan tidak perlu mengetik: komunikasi lewat ping wheel, Report Card otomatis, dan pinpoint di peta. Semua kontrol dirancang untuk mobile.
>
> Menyelesaikan puzzle saja tidak cukup. Kalian harus menyusun deduksi, menemukan kontradiksi dalam pernyataan saksi, lalu menuduh pelaku, motif, dan cara dengan benar. Tiga percobaan per kasus, jadi bicarakan dulu sebelum menuduh.
>
> Bisa main 3 pemain, 2 pemain dengan NPC Archivist, atau solo sebagai Director. Kasus baru rilis tiap 1-2 minggu dengan cabang solusi berbeda, jadi tidak ada yang tahu pasti siapa pelakunya.
>
> Tanpa pay-to-win: solusi dan hint tidak bisa dibeli.

**Aturan penulisan yang sudah diterapkan** (sesuai metadata best practices Roblox, sumber sama dengan §3.1):

- Kalimat pertama memuat genre dan premis — Roblox menyebut ini kesempatan memberi kesan paling akurat tentang genre dan isi.
- Kata kunci relevan tersebar natural: co-op, mystery, 3 pemain, detektif, deduksi, puzzle, mobile.
- Tidak ada keyword berulang dan tidak ada kata yang tidak relevan — pengulangan kata bisa menurunkan peringkat.
- Tidak ada klaim fitur yang belum ada di MVP (P0). NPC Director, daily case, leaderboard, Agency HQ, dan kosmetik **tidak** disebut karena masih P1/P2 (§16).
- Tidak ada kata yang memicu klasifikasi social hangout/private space (lihat peringatan di §1).

**ASUMSI:** batas karakter deskripsi. Draf ini ±950 karakter; angka batas resmi belum saya verifikasi. Yang memverifikasi/menggantikan: field deskripsi di Creator Dashboard saat publish — bila melebihi batas, potong paragraf 4.

### 3.3 "Tag" → Genre + Subgenre + keyword

**Temuan yang mengubah permintaan issue.** Roblox **tidak lagi punya field tag free-form**. Kategorisasi sekarang memakai **Genre + Subgenre** terkurasi, dan properti engine lama `DataModel.Genre` sudah deprecated serta tidak berfungsi lagi.
Sumber: https://create.roblox.com/docs/production/publishing/experience-genres dan https://create.roblox.com/docs/reference/engine/enums/Genre

**Rekomendasi:**

| Prioritas | Genre | Subgenre | Alasan |
|---|---|---|---|
| Utama | **Puzzle** | **Escape Room** | Genre Puzzle mendefinisikan "problem-solving challenges to progress", dan subgenre Escape Room "solving puzzles to escape a room or building" — paling dekat dengan loop sebenarnya (buka bukti di meja → deduksi, §4). Genre puzzle juga eksplisit dicari kurator Standout Games (https://create.roblox.com/docs/creator-programs/standout-games) |
| Alternatif | **Adventure** | **Story** atau **Scavenger Hunt** | Genre Adventure mencakup eksplorasi dan pemecahan tantangan; subgenre Scavenger Hunt "find and collect a series of objects" mencerminkan Searcher, dan Story mencerminkan struktur kasus (§4, §6, §10) |

Roblox menyarankan memilih genre yang paling cocok dengan **tujuan utama atau core gameplay loop**, dan menyarankan memilih subgenre bila ada yang cocok.
Sumber: https://create.roblox.com/docs/production/publishing/experience-genres

**Catatan operasional yang harus dipatuhi:**

- Genre hanya bisa diubah **sekali per 3 bulan**. Roblox secara eksplisit menyarankan hanya memilih genre setelah yakin.
- Roblox dapat mengganti paksa genre yang dianggap tidak akurat; notifikasi dikirim lewat email dan perubahan muncul di halaman **Settings**. Appeal lewat `roblox.com/support`, kategori **Experience Genre**, dengan universe ID. Appeal yang ditolak tidak bisa diajukan ulang, dan memperbarui genre sendiri saat appeal belum selesai akan membatalkan appeal itu.
- Genre dan subgenre langsung muncul di halaman game, tetapi butuh beberapa hari untuk tercermin di sort Charts per-genre.

**Keputusan: `Puzzle → Escape Room`.** Ini yang paling dekat dengan loop sebenarnya dan paling mudah dipertahankan bila ditinjau Roblox.

**Kata kunci untuk deskripsi dan pencarian** (karena tidak ada field tag, keyword hanya hidup di judul dan deskripsi): `co-op mystery`, `detective`, `3 player`, `puzzle`, `deduction`, `escape room`, `mystery`, `no voice`, `short session`, `mobile`.

### 3.4 Arahan ikon

Spesifikasi: **512×512 px, persegi**; tampil ter-downscale sekitar **150×150 px**, jadi harus terbaca di ukuran kecil.
Sumber: https://create.roblox.com/docs/production/publishing/experience-icons

**Konsep:**

- Satu objek tunggal yang siluetnya terbaca: berkas kasus di atas meja dengan lampu meja hangat dari satu sisi — lampu meja adalah identitas visual Handler (§19).
- Tiga titik pin atau kaca pembesar yang membentuk **segitiga** — literal dari nama "Triangulate" dan langsung mengomunikasikan "tiga pemain".
- Palet cozy noir hangat: amber/lampu melawan biru gelap, kontras tinggi.
- **Tanpa teks apa pun di ikon** — tidak akan terbaca di 150×150.

### 3.5 Arahan thumbnail

Spesifikasi: sampai **10 gambar/video** per detail page; gambar ideal **16:9, 1920×1080 px**; thumbnail yang tidak 16:9 akan diregangkan; **jangan menaruh teks atau elemen penting di bagian bawah** thumbnail karena bisa tertutup metadata seperti jumlah pemain; video gratis dengan **kuota 3 upload/bulan** dan **tidak didukung di Xbox, PlayStation, dan VR**; video **tidak boleh** memuat voice-over, narasi, voice chat, atau musik berlyrics, juga tidak boleh memuat teks/klaim yang bersifat iklan ("50% off", "Free UGC!").
Sumber: https://create.roblox.com/docs/production/publishing/thumbnails

**Dua thumbnail untuk A/B (minimum dua agar personalisasi aktif):**

| | Konsep | Hipotesis yang diuji |
|---|---|---|
| **A** | Tiga panel berdampingan, satu per peran: meja puzzle top-down (Handler), koridor gelap dengan senter (Searcher), clue board penuh kartu terhubung (Director). Teks pendek di area tengah-atas: "3 pemain · 1 tuduhan" | Apakah **asimetri peran** adalah daya tarik utama |
| **B** | Satu adegan: clue board dengan kartu terhubung garis merah, satu kartu disorot, suasana lampu meja hangat. Teks: "Bukan puzzle. Deduksi." | Apakah **janji deduksi** lebih menarik daripada penjelasan mekanik |

**Aturan pengujian:** personalisasi hanya mulai bila **2 thumbnail atau lebih aktif**; Roblox mencatat rata-rata kenaikan **+8,5% qualified play through rate** pada game yang memakainya (sebagian hingga +50%). **Jangan matikan thumbnail yang kalah** selama pengujian — Roblox secara eksplisit memperingatkan bahwa memilih satu pemenang terlalu dini menghilangkan impresi dari thumbnail yang nanti menjadi terbaik kedua. Uji thumbnail baru setiap ada update besar, lalu jangan ubah sampai update berikutnya. Metrik per thumbnail yang dipantau: Impressions, Qualified Plays, Average Playtime, Qualified Play Through Rate, Winning Segment.

**Video:** kerjakan setelah dua thumbnail gambar punya data. Kuota 3/bulan dan ketiadaan dukungan di console/VR membuat video bukan jalur utama untuk audiens mobile. **ASUMSI:** belum ada data distribusi device pemain Triangulate; yang memverifikasi: telemetri device dari build pertama (§15).

### 3.6 Blocker publikasi yang harus diselesaikan sebelum rilis

- **Kuesioner Maturity & Compliance wajib diisi.** Tanpa informasi maturity yang akurat, Roblox **membatasi playability game untuk semua pemain**. Sumber: https://create.roblox.com/docs/production/promotion/content-maturity
- **Risiko descriptor Fear.** Definisi Mild untuk Fear mencakup *creepy-looking NPCs*, *jump scares*, *ominous music*, dan *gameplay that builds suspense*. Suasana cozy noir yang menegangkan **sangat mungkin** memicu descriptor Fear level Mild. Ini tidak mematikan — label Minimal/Mild tetap eligible untuk Roblox Kids (5-8) dan Roblox Select (9-15) — tapi harus dijawab jujur di kuesioner.
- **Persyaratan akun.** Untuk mencapai 16+ dan Trusted Friends: akun berumur minimal 2 hari, age check, dan kuesioner maturity. Untuk mencapai semua umur termasuk Roblox Kids dan Select: ditambah verifikasi akun, 2FA, dan salah satu dari (langganan Roblox Plus/Premium 2 bulan berturut-turut **atau** publishing fee 1.000 Robux yang refundable), serta lolos evaluasi Kids & Select. Expedited review fee 50.000 Robux. Sumber: https://create.roblox.com/docs/production/publishing/publish-games-and-places
  Ini keputusan operasional owner dan CTO/CIO, bukan CMO.

---

## 4. Rencana Akuisisi Awal

### 4.1 Prinsip pemilihan channel

Recommended For You (RFY) di Home bekerja dua tahap: **Retrieval** lalu **Ranking**.

- **Retrieval** memilih subset game berdasarkan sinyal engagement, retention, dan monetization. Trafik dari ads, curation, search, charts, friends, teleport, notifications, dan social media sharing dapat **mempercepat** pertimbangan game untuk discovery organik. Game dengan jumlah pemain kecil pun bisa memberi sinyal bahwa game layak dipertimbangkan.
- **Ranking** menentukan seberapa jauh distribusi organik berjalan, dan itu **sepenuhnya** bergantung pada engagement serta retention user yang datang **dari RFY sendiri**. Roblox **tidak menghitung** engagement, monetization, atau retention user yang pertama kali diakuisisi dari ads, curation, friends, search, social media, atau sumber lain dalam tahap ranking RFY.

Sinyal **Most important**: **Play Through Rate**, **First Play Bounce Rate** (sinyal negatif), **Play Days per User** (D1, D2-7, D8-28), **Playtime per User** (maksimum 60 menit per user per game per hari). Sinyal **Important**: **Intentional Co-play Days per User**, **Qualified Play Sessions per User**, **Spend Days per User**, **Robux Spent per User**. Sinyal dihitung sebagai **rata-rata per user, bukan total**, jadi game kecil dengan retensi tinggi tidak dirugikan.
Sumber: https://create.roblox.com/docs/discovery

**Kesimpulan operasional.** `Intentional co-play days per user` secara eksplisit mencakup **co-play melalui join, invites, atau private server**. Jadi private server dan undangan teman bukan sekadar taktik distribusi — itu satu-satunya channel yang langsung memberi makan sinyal algoritmik yang kita punya kendali penuh atasnya. Itu channel pertama.

### 4.2 Tiga channel prioritas

| # | Channel | Audiens | Offer | Biaya | Metrik keep-or-kill | Tanggal review |
|---|---|---|---|---|---|---|
| **1** | **Private server + undangan teman** | ICP utama: kelompok 3 teman yang sudah saling kenal | Main bareng tanpa orang asing; link undangan dengan `LaunchData` untuk atribusi | **0 Robux** | **Keep** jika D7 kohort dari private server ≥ D7 organik, **atau** `Intentional Co-play Days per User` naik 4 minggu berturut-turut. **Kill/rework** jika D7 kohort private server di bawah organik selama 2 periode review berturut-turut, atau tidak ada kenaikan co-play selama 4 minggu | Gate minggu 7 (§17); lalu tiap 4 minggu |
| **2** | **Standout Games nomination** | Pemain Roblox yang mencari genre puzzle — kurator menyatakan eksplisit mencari RPG, strategy, puzzle, dan shooter yang underrepresented | Submission lewat survey resmi; prasyarat: optimasi mobile+console, R15 rig, layered accessories, dynamic heads, experience events, lokalisasi, trailer, thumbnail rapi | **0 Robux** (kurasi manual, tanpa biaya) | **Keep** jika diterima → pantau qualified PTR dan D1 setelah tayang. **Kill/tunda** jika ditolak 2 kali dengan gap yang sama → perbaiki gap yang disebut kurator (biasanya performa mobile/console dan kelengkapan store page), lalu pindahkan channel ke P1 | Submit sebelum minggu 8 (§17); review penerimaan **30 hari** setelah submit |
| **3** | **Ads Manager, goal "Plays"** — kickstart retrieval | Pemain baru (audiens "New Players": yang belum pernah main atau belum main 180+ hari) | Thumbnail A/B sebagai creative; landing ke store page yang sudah lengkap | **Butuh persetujuan owner.** **ASUMSI:** minimum 5 ad credits/hari ≈ $5 USD/hari ≈ $70 USD untuk 2 minggu. Angka ini hanya dari DevForum/Reddit, **tidak ada di dokumentasi resmi**. Konversi Robux→ad credit (1 ad credit ≈ 285 Robux) juga **ASUMSI**, sumber DevForum. Yang memverifikasi: UI Ads Manager saat campaign pertama dibuat | **Keep** jika D7 kohort dari ads ≥ 50% D7 organik dan CPP (cost per play) masih masuk akal terhadap nilai satu sesi. **Kill** jika D7 kohort ads < 50% organik pada 14 hari pertama → hentikan, jangan tambah budget | Review **14 hari** setelah campaign mulai; keputusan lanjut/stop di gate minggu 7 (§17) |

**Fakta pendukung channel 3.** Goal **Plays** didefinisikan Roblox sebagai: "reaches players who are most likely to start a session in your game. Use it when you want broad distribution, are testing new ideas with a wide audience, or **want initial traffic to help recommendation systems learn what's working and qualify your game for Recommended For You**." Kreatif: sampai 10 thumbnail 16:9, bisa memakai AI generate, dan bisa memakai `Advanced join options` + `LaunchData` lewat `player:GetJoinData().LaunchData` untuk atribusi. Reporting memuat CPP, dan atribusi New Users berjalan hingga 30 hari. Pelaporan bisa tertunda hingga 48 jam. Campaign bisa dibatalkan hingga 6 jam sebelum jadwal mulai, dan ad credit yang belum terpakai dikembalikan.
Sumber: https://create.roblox.com/docs/production/promotion/ads-manager

### 4.3 Peringatan penting soal ads

Roblox menyatakan user yang diakuisisi lewat ads dianggap **sudah acquired**, sehingga mereka bisa tidak muncul lagi di RFY — artinya **RFY impressions bisa turun walaupun total akuisisi naik**. Ads juga tidak memberi sinyal ke tahap ranking RFY.
Sumber: https://create.roblox.com/docs/discovery-faq

Jadi ads di sini murni untuk memecahkan masalah *cold start* di tahap retrieval, bukan untuk pertumbuhan. Kalau D7 kohort ads jelek, ads hanya membakar budget sambil menekan impressions RFY.

### 4.4 Komunitas

Roblox menyarankan tiga langkah untuk akuisisi dari sumber eksternal: membuat akun sosial dan posting rutin; membangun komunitas pengguna; serta bermitra dengan kreator dan influencer. **Roblox Group** disebut sebagai cara terbaik bagi kreator untuk terhubung dan menginformasikan komunitas mereka. **Experience events** dipakai untuk memberi tahu user tentang event mendatang dan mengirim notifikasi saat event dimulai — dan satu event bisa memuat hingga 5 thumbnail.
Sumber: https://create.roblox.com/docs/production/analytics/acquisition dan https://create.roblox.com/docs/discovery

**Rencana komunitas minimal untuk MVP:**

- Satu Roblox Group resmi sebagai kanal pengumuman (dan kelak sebagai pintu masuk Detective Agency, §11).
- Satu akun sosial eksternal, dengan share link unik per kanal agar terukur.
- Experience event untuk setiap rilis story case baru (§10), supaya pengguna lama dapat notifikasi.
- Tidak ada program hadiah berupa Robux atau item berbayar untuk memancing engagement — Roblox secara eksplisit menyatakan metadata yang menyiratkan imbalan moneter tidak diprioritaskan untuk rekomendasi, dan praktik itu juga bertabrakan dengan batasan tanpa pay-to-win (§13).

### 4.5 Peran konten mingguan

Konten bukan channel terpisah. Konten adalah bahan bakar untuk channel 1 dan 2, dan alat ukur untuk channel 3.

| Kadens | Deliverable | Audiens | Channel | Outcome yang dituju |
|---|---|---|---|---|
| Mingguan, mengikuti rilis story case (§10: 1 per 1-2 minggu) | 1 potongan pendek: adegan teka-teki tanpa membocorkan solusi | ICP utama | Roblox (halaman game + experience event) dan sosial eksternal | Memberi alasan konkret untuk mengajak teman bermain minggu itu |
| Mingguan | 1 share link unik per kanal eksternal yang dipakai | — | Roblox Share Links | Atribusi per kanal: users with qualified plays, 7-day playtime per user, D7 retention, 30-day revenue per user (https://create.roblox.com/docs/production/promotion/share-links) |
| Dua mingguan | Rotasi thumbnail A/B mengikuti case baru | Semua pengunjung store page | Roblox Thumbnail Personalization | Menaikkan qualified play through rate |
| Bulanan | Rekap komunitas: kasus yang paling sering dipecahkan, tanpa spoiler | Komunitas yang sudah main | Roblox Group dan sosial | Mempertahankan D7/D30 dan memberi alasan kembali |

**Batasan konten.** Setiap materi promosi wajib mematuhi §13 (tidak menawarkan solusi atau hint berbayar), §14 (non-gore), dan tidak memakai kata yang memicu klasifikasi social hangout/private space.

---

## 5. Metrik Akuisisi dan Retensi

### 5.1 Target §12 dan padanannya di dashboard Roblox

| Kategori §12 | Metrik PRD §12 | Target §12 | Padanan Roblox | Sumber |
|---|---|---|---|---|
| Retensi | D1 / D7 | 18% / 5% | **D1 retention**, **D7 retention** (kohort harian; D7 diukur pada hari ke-8) | https://create.roblox.com/docs/production/analytics/retention |
| Penyelesaian | % sesi menamatkan kasus | > 55% | **Qualified Play Sessions per User** + telemetri kustom (menang/kalah per sesi) | https://create.roblox.com/docs/discovery |
| Matchmaking | Median waktu tunggu / % gagal start | < 60 dtk / < 10% | Telemetri kustom (§15) | PRD §12 |
| Pengalaman role | Idle time per role | < 25% sesi | Telemetri kustom (§15) | PRD §6, §12 |
| Onboarding | % menamatkan Case 0 | > 80% | **First Play Bounce Rate** (sinyal negatif) + funnel kustom Case 0 | https://create.roblox.com/docs/discovery |
| Drop-off | Quit di 5 menit pertama per role | Dipantau, dibandingkan antar role | **First Play Bounce Rate** (segmen < 60 detik dan 61-180 detik), **Play Through Rate** | https://create.roblox.com/docs/discovery |
| Hint | Rata-rata hint per sesi | 1-2 | Telemetri kustom | PRD §12 |
| Konten | Story case baru | 1 per 1-2 minggu | — | PRD §10 |

### 5.2 Metrik yang harus dipasang untuk mengukur channel

Tersedia di **Acquisition dashboard**, baik per sumber maupun per share link: *Users with plays*, *Conversion rate*, *D7 retention*, *7D playtime per user*, *30D payer conversion*, *30D revenue per user*.
Sumber: https://create.roblox.com/docs/production/analytics/acquisition

Dari sisi RFY, yang wajib dipantau di tab **Home Recommendations**: Play Through Rate, First Play Bounce Rate, Play Days per User (D1 / D2-7 / D8-28), Playtime per User, Intentional Co-play Days per User, Qualified Play Sessions per User.

### 5.3 Definisi kapan sebuah channel dihentikan

| Channel | Dihentikan jika | Kapan diputuskan |
|---|---|---|
| Private server + invite | D7 kohort private server di bawah D7 organik selama 2 periode review berturut-turut, **atau** tidak ada kenaikan `Intentional Co-play Days per User` selama 4 minggu | Gate minggu 7, lalu tiap 4 minggu |
| Standout Games | Ditolak 2 kali berturut-turut dengan gap yang sama → pindahkan ke P1, alihkan effort ke konten organik | 30 hari setelah tiap submit |
| Ads (Plays) | D7 kohort ads < 50% D7 organik **atau** CPP melebihi nilai satu sesi, pada 14 hari pertama | 14 hari setelah campaign mulai; **stop tanpa menunggu gate** |

**Aturan umum.** Channel dihentikan bila **D7 kohortnya di bawah 50% D7 organik** atau **tidak bergerak selama 2 periode review**. Jangan hentikan channel hanya karena volume rendah di minggu pertama — sinyal RFY adalah rata-rata per user, jadi kualitas kohort lebih penting daripada jumlahnya.

### 5.4 Risiko yang perlu diangkat

Target D7 §12 sebesar 5% sangat rendah untuk ukuran game Roblox. Dokumentasi Roblox menyatakan bahwa discovery di Home secara langsung menghargai **D1 retention** dan **session time** yang setara atau di atas benchmark game sejenis, dan bahwa game dengan D1 retention tinggi lebih mungkin tampil di Recommended Experiences.
Sumber: https://create.roblox.com/docs/production/analytics/acquisition

**INFERENSI (bukan fakta terverifikasi):** dengan D7 hanya 5%, Triangulate kemungkinan besar akan bergantung pada akuisisi berbayar dan undangan teman — bukan pada RFY organik — selama Agency dan daily case (P1, §16) belum ada. PRD sendiri mengakui ini dengan catatan "naikkan setelah ada Agency & daily" (§12). Rekomendasi CMO: jangan jadikan RFY sebagai asumsi pertumbuhan untuk MVP; ukur dan laporkan selisih antara target §12 dan realita playtest minggu 7 sebelum mengunci rencana channel jangka panjang.

---

## 6. Eskalasi ke Owner

Butir berikut di luar kewenangan CMO dan perlu keputusan owner di issue:

1. **Persetujuan belanja ads.** Nominal dan mata uang untuk channel 3 (Ads Manager). Kebutuhan minimum belum bisa saya pastikan dari dokumentasi resmi — angka yang beredar (5 ad credits/hari, 1 ad credit ≈ 285 Robux) hanya dari DevForum/Reddit. Mohon konfirmasi angka sebenarnya dari UI Ads Manager, lalu putuskan budget. Pemilik anggaran: CFO (EXTA-42).
2. **Nama game final.** §19 masih membuka keputusan nama. Store page tidak bisa dipublikasikan sebelum nama dikunci, dan nama memengaruhi keyword judul serta klasifikasi maturity.
3. **Ketersediaan aset visual.** Ikon 512×512 dan thumbnail 16:9 1920×1080 membutuhkan aset dari workstream art direction cozy noir dan mockup UI mobile (EXTA-39). Tanpa itu, arahan di §3.4-3.5 hanya konsep.
4. **Jawaban kuesioner maturity.** Deskriptor Fear kemungkinan besar terpicu oleh suasana cozy noir (creepy NPC, ominous music, suspense). Jawaban menentukan apakah game eligible untuk Roblox Kids/Select (5-15) atau terbatas 16+. Ini menyentuh scope EXTA-40 dan butuh keputusan produk.
5. **Koreksi atas permintaan "tag" di issue.** Roblox sudah tidak punya field tag free-form — hanya Genre + Subgenre dengan cooldown 3 bulan. Pemetaannya ada di §3.3. Bila maksud permintaan awal adalah hal lain, mohon dikoreksi.

---

## 7. Ketidakpastian dan Asumsi

| Klaim | Status |
|---|---|
| Sinyal RFY dua tahap dan daftar sinyalnya; perilaku ads terhadap RFY; spesifikasi thumbnail dan ikon; aturan Genre/Subgenre dan cooldown 3 bulan; aturan maturity dan descriptor; alur share link; metrik acquisition; komponen Ads Manager | **Terverifikasi** — dokumentasi resmi `create.roblox.com` (URL di tiap bagian) |
| Target §12 (D1/D7, penyelesaian, matchmaking, idle, Case 0, hint) dan seluruh rujukan §n | **Terverifikasi** — PRD v0.2, ada di repo `docs/prd-v0.2.md` |
| Minimum daily budget ads (5 ad credits/hari), konversi 1 ad credit ≈ 285 Robux, durasi minimum campaign | **ASUMSI** — hanya dari DevForum/Reddit; dokumentasi resmi hanya menyebut minimum pembelian 1 ad credit. Verifikasi: UI Ads Manager saat campaign pertama dibuat |
| Batas karakter deskripsi store page | **ASUMSI** — belum diverifikasi. Verifikasi: field deskripsi di Creator Dashboard |
| "Alat pengganti hari ini" pada ICP | **ASUMSI** — belum ada riset pengguna. Verifikasi: playtest minggu 7 dan benchmark kompetitor EXTA-40 |
| Distribusi device pemain (mobile vs console) | **ASUMSI** — PRD §12 menyatakan mayoritas mobile tanpa angka. Verifikasi: telemetri device dari build pertama |
| Tanggal review absolut | **ASUMSI** — dihitung 8 minggu dari 2026-10-04 mengikuti roadmap §17 |
| D7 5% sebagai penghambat RFY organik | **INFERENSI** dari dokumentasi acquisition, bukan angka terukur |
