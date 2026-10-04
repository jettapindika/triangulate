# PRD: Co-op Puzzle Mystery (Working Title) — v0.2

Dokumen base pekerjaan proyek **Triangulate** (issue induk EXTA-31). Platform: Roblox (PC, mobile, console). Status: Draft revisi. Semua bagian bernomor di bawah dirujuk oleh issue turunan.

**Platform:** Roblox (PC, mobile, console) | **Versi:** 0.2 | **Status:** Draft revisi

> Revisi dari v0.1. Semua loophole hasil evaluasi sudah dijawab dengan keputusan konkret. Tema cozy noir sudah disetujui. Aturan rotasi role dan jumlah Deduksi Kunci sudah ditetapkan (bagian 3, 5, 8).

### 0. Changelog v0.1 → v0.2

| #   | Masalah di v0.1                                 | Solusi di v0.2                                           | Bagian |
| --- | ----------------------------------------------- | -------------------------------------------------------- | ------ |
| 1   | Hubungan puzzle ↔ misteri ↔ win condition kabur | Clue Graph + win = tuduhan benar, puzzle = membuka bukti | 4, 5   |
| 2   | Jigsaw polos membosankan                        | Puzzle jadi rekonstruksi bukti (3 tipe di MVP)           | 4      |
| 3   | Text chat sulit di mobile                       | Ping wheel kontekstual + Report Card otomatis            | 7      |
| 4   | Downtime tidak seimbang                         | Rantai bukti paralel + tugas aktif per role              | 6      |
| 5   | Brute-force jawaban                             | 3 percobaan, feedback terbatas, gerbang deduksi          | 5      |
| 6   | Replayability nol & spoiler                     | Varian solusi per seed, rotasi role, mode ulang          | 10     |
| 7   | Matchmaking rapuh                               | Ready check, AFK takeover, rejoin, aturan NPC            | 8      |
| 8   | Tidak ada onboarding                            | Case 0 (tutorial 5 menit) + role card                    | 9      |
| 9   | Metrik & monetisasi lemah                       | Metrik baru, host-owns, kosmetik lintas role             | 12, 13 |
| 10  | Roadmap 5 minggu tidak realistis                | 8 minggu + minggu 0 untuk spike teknis                   | 16     |
| 11  | Tema & rating belum diputuskan                  | Cozy noir non-gore, target 13+                           | 3, 14  |

### 1. Ringkasan

Game co-op asimetris untuk 3 pemain. Searcher menjelajah lokasi, Handler merekonstruksi bukti di meja top-down, Director menggabungkan bukti dan menuduh pelaku. Tiap role memegang informasi berbeda, jadi komunikasi adalah gameplay utamanya. Sesi 15-30 menit.

### 2. Pilar Desain

1. **Tidak ada yang menganggur.** Setiap role selalu punya sesuatu yang bisa dikerjakan.
2. **Komunikasi tanpa mengetik.** Cukup sentuh, tidak harus ketik.
3. **Puzzle adalah bukti.** Setiap bagian yang terbuka mengubah apa yang diketahui tim.
4. **Deduksi menentukan kemenangan.** Menyelesaikan puzzle saja tidak cukup.

### 3. Keputusan Terkunci

| Topik            | Keputusan                                                                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Tema (disetujui) | Cozy noir: pencurian, pemalsuan, sabotase, orang hilang. Tanpa gore, tanpa pembunuhan eksplisit. Supernatural ditunda sebagai case pack P2 |
| Potongan puzzle  | Bukti bermakna: dokumen sobek, foto, timeline, cipher                                                                                      |
| Win condition    | Director menuduh pelaku, motif, dan cara dengan benar                                                                                      |
| Kerja sama       | Tuduhan akhir butuh konfirmasi dari 1 role lain                                                                                            |
| Pilih role       | Pemain memilih **2 preferensi role** (urutan prioritas) sebelum matchmaking                                                                |
| Mode 2 pemain    | Searcher + Director manusia, Handler diisi NPC "Archivist" (lihat bagian 8)                                                                |
| Rotasi role      | Publik: preferensi dihormati + prioritas keadilan. Private/seri kasus: rotasi otomatis (lihat bagian 8)                                    |
| Kamera           | Handler top-down, Searcher first/third person, Director UI 2D                                                                              |

### 4. Mekanik Inti: Clue Graph

Semua kasus adalah graf ketergantungan (tanpa siklus) dari empat jenis node:

| Node          | Dipegang                            | Fungsi                                      |
| ------------- | ----------------------------------- | ------------------------------------------- |
| **Objek**     | Searcher menemukan di lokasi        | Memberi *kunci* (kode, potongan, tanda)     |
| **Bukti**     | Handler merekonstruksi di meja      | Hasil puzzle, berisi informasi              |
| **Clue Card** | Director di clue board              | Fakta yang dikirim dari bukti atau laporan  |
| **Deduksi**   | Director menggabungkan 2+ Clue Card | Membuka target baru, pinpoint, atau tuduhan |

#### Alur satu rantai

1. Handler membaca arsip dan menandai **target**, misal "cari benda dengan simbol bintang".
2. Searcher menemukan objek, memeriksanya, dan menekan **Report**. Objek masuk ke clue board Director sebagai *Laporan* dan memberi *kunci* ke Handler.
3. Kunci membuka potongan bukti di meja. Handler menyelesaikan puzzle bukti.
4. Bukti yang selesai terkirim ke Director sebagai **Clue Card**.
5. Director menggabungkan Clue Card (drag kartu ke kartu), server memeriksa resep, dan lahir **Deduksi**.
6. Deduksi menaruh pinpoint baru di map dan membuka target baru. Ulangi.

#### Tipe puzzle bukti (MVP: 3)

| Tipe          | Contoh                                         | Skill   |
| ------------- | ---------------------------------------------- | ------- |
| Dokumen sobek | Susun surat yang robek, kalimatnya berisi nama | Spasial |
| Timeline      | Urutkan foto/log berdasarkan petunjuk waktu    | Logika  |
| Cipher        | Pecahkan kode memakai kunci dari Searcher      | Pola    |

P1: spot-the-difference, rangkaian kabel, kunci kombinasi.

#### Pernyataan saksi dan kontradiksi

Tiap kasus punya 2-3 pernyataan saksi/tersangka, minimal satu berbohong. Director menandai **Kontradiksi** antara pernyataan dan bukti, dan itu salah satu syarat membuka tuduhan. Ini yang bikin komunikasi dan cross-check terasa bermakna.

#### Contoh mini kasus: "Lukisan yang Tertukar"

| Rantai    | Searcher                             | Handler               | Director                                                                                        |
| --------- | ------------------------------------ | --------------------- | ----------------------------------------------------------------------------------------------- |
| A: Jadwal | Temukan sobekan jadwal di ruang staf | Susun jadwal sobek    | Clue: satpam off duty jam 21.00                                                                 |
| B: Akses  | Temukan kartu akses di loker         | Cipher pada log akses | Clue: kartu kurator dipakai jam 21.10                                                           |
| C: Motif  | Foto di studio kolektor              | Urut timeline foto    | Clue: kolektor tahu lukisan palsu                                                               |
| Deduksi   |                                      |                       | A + B → kurator punya akses saat satpam tidak jaga. Kontradiksi dengan alibi kurator. C → motif |

### 5. Win Condition & Anti Brute-force

- **Menang:** Director mengisi form tuduhan (Pelaku, Motif, Cara) dan 1 role lain mengonfirmasi.
- **Gerbang:** Form hanya terbuka jika **N Deduksi Kunci** selesai dan minimal 1 Kontradiksi ditandai. N = 4 dari 6 untuk kasus standar (3 rantai x 2 deduksi), 3 dari 5 untuk daily case, 2 dari 3 untuk Case 0. Rumusnya kira-kira 65% dari total, dibulatkan ke atas. Tiap rantai menopang satu field tuduhan (Pelaku / Motif / Cara), dan deduksi sisanya menjadi bonus rank, jadi tim bisa menang tanpa mengerjakan semuanya.
- **Batas percobaan:** 3 tuduhan per kasus.
- **Feedback salah:** hanya "X dari 3 benar", tidak menyebutkan field mana.
- **Penalti:** tiap tuduhan salah menurunkan rank kasus dan memajukan timer *cleanup* (lihat bagian 6).
- **Gagal:** setelah 3 salah, kasus jadi "Cold Case". Tim melihat rekap parsial dan bisa mencoba lagi pada varian lain (bagian 10).
- **Rank:** S/A/B/C dari waktu, jumlah tuduhan, dan hint terpakai.

### 6. Anti-downtime: Tugas Aktif per Role

**Prinsip:** tiap kasus punya 3 rantai bukti yang berjalan paralel. Selalu ada rantai yang bisa dikerjakan walau yang lain menunggu.

| Role     | Saat menunggu, bisa melakukan                                                                                                       |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Searcher | Eksplorasi bebas dengan objek *ambient* (bukti tambahan opsional), mini-aksi (senter UV, buka laci dengan hold, lockpick sederhana) |
| Handler  | Cross-reference arsip (mini-task mencocokkan nama/tanggal untuk hint target), kerjakan puzzle rantai lain                           |
| Director | Baca pernyataan saksi, cari kontradiksi, susun hipotesis di clue board, taruh pinpoint spekulatif                                   |

**Tekanan waktu (ringan, MVP):** satu rantai punya timer *cleanup*, yaitu pelaku menghapus satu bukti di lokasi jika tidak diambil dalam waktu tertentu. Timer dipercepat tiap tuduhan salah. **P1:** patroli NPC yang harus dihindari Searcher.

**Aturan desain:** pada playtest, idle time (tanpa input bermakna) tiap role harus di bawah 25% sesi.

### 7. Komunikasi Mobile-first

#### Ping Wheel kontekstual

Roda dengan 6-8 frasa yang berubah sesuai role dan situasi.

| Role     | Contoh frasa                                                         |
| -------- | -------------------------------------------------------------------- |
| Searcher | "Nemu sesuatu!", "Terkunci, butuh kode", "Ada bahaya", "Sudah dicek" |
| Handler  | "Cari benda bertanda ini", "Bukti terbuka", "Butuh kunci lain"       |
| Director | "Ke pinpoint ini", "Periksa ulang", "Aku butuh waktu"                |
| Semua    | "Setuju", "Ragu", "Tolong ulangi"                                    |

#### Alat lain

- **Report Card:** Searcher menekan Report, foto objek + tag lokasi otomatis terkirim. Tidak perlu mengetik.
- **Target Marker:** Handler menaruh ikon target yang muncul di HUD Searcher dan arah kompas.
- **Pinpoint:** Director menaruh marker yang terlihat di dunia Searcher.
- **Text chat:** tetap ada sebagai opsional, dengan filter Roblox. Voice tidak diwajibkan.
- **Table Preview:** Director melihat thumbnail meja Handler (read-only) supaya tahu progres tanpa bertanya.

### 8. Matchmaking, NPC, dan Disconnect

#### Alur lobby

1. Pemain memilih 2 preferensi role. Server menetapkan role berdasarkan prioritas dan ketersediaan.
   - **Prioritas keadilan:** pemain yang memegang role yang sama 3 sesi berturut-turut mendapat prioritas ke preferensi keduanya. Pemain baru tidak otomatis jadi Director di sesi pertama.
2. Timer lobby 45 detik. Jika belum 3 manusia, role kosong diisi NPC. Pemain bisa memilih tunggu sampai 90 detik.
3. **Ready check** 10 detik sebelum mulai. Pemain yang tidak ready diganti.
4. Pemain boleh tukar role di lobby (saling setuju).

#### Disconnect & AFK

- AFK 60 detik tanpa input → NPC mengambil alih role itu, state tetap utuh.
- Disconnect → slot ditahan 3 menit untuk rejoin, NPC mengisi sementara.
- Setelah 3 menit slot dibuka untuk pemain pengganti (join-in-progress) atau tetap NPC.

#### Prioritas NPC

| Role     | Perilaku NPC                                                              | Kesulitan buat AI                 |
| -------- | ------------------------------------------------------------------------- | --------------------------------- |
| Searcher | Berjalan ke objek yang ditandai ping/pinpoint dan melapor                 | Rendah                            |
| Handler  | Merakit potongan otomatis dengan kecepatan lambat setelah kunci diberikan | Rendah                            |
| Director | Mode terpandu: menyarankan kombinasi Clue Card dengan hint terbatas       | Tinggi, jadi prioritaskan manusia |

Sesi dengan NPC Director dihitung rank terpisah (tanpa leaderboard utama).

#### Mode 2 pemain

Searcher + Director manusia, Handler = NPC Archivist. Archivist merakit bukti secara otomatis dan lambat, dan puzzle manual bisa diambil alih Director jika mau lebih cepat. Pemain solo memainkan Director dengan dua NPC.

#### Dominasi

Hanya dua aksi yang butuh persetujuan 2 role: **tuduhan akhir** dan **pakai hint**. Selainnya bebas, supaya tidak ada friksi voting.

### 9. Onboarding

- **Case 0 (±5 menit):** kasus pendek dengan NPC mentor. Tiap role mendapat satu objective sederhana dan overlay kontekstual. Wajib sekali per akun, bisa di-skip untuk pemain yang sudah main.
- **Role Card:** layar singkat saat mulai, berisi "Kamu tahu apa / Tidak tahu apa / Tugas pertamamu".
- **Rookie mode:** 3 sesi pertama memakai kasus dengan clue lebih sedikit dan hint gratis.
- **Rotasi saran:** pemain baru didorong mencoba role berbeda tiap kasus (badge "All-Rounder").

### 10. Konten & Replayability

- **Story case:** ditulis manual, rilis 1 per 1-2 minggu.
- **Varian solusi:** tiap story case ditulis dengan **2-3 cabang solusi** (pelaku/motif berbeda) yang berbagi aset lokasi dan puzzle. Seed server memilih cabang saat sesi dibuat. Spoiler dari video/wiki jadi tidak berlaku penuh.
- **Daily case:** diacak dari template (pelaku, motif, penempatan clue, gambar puzzle) dengan seed harian dan validator.
- **Validator:** memastikan minimal satu jalur solusi, tanpa dependensi melingkar, dan tidak ada rantai yang buntu.
- **Rotasi role:** publik tidak dipaksa (preferensi dihormati, ada prioritas keadilan di bagian 8). Di private server/seri kasus, kasus pertama bebas pilih, lalu rotasi otomatis Searcher → Handler → Director → Searcher. Bisa dimatikan lewat toggle host. Rotasi memberi badge "All-Rounder" dan bonus Agency XP.
- **Cold Case Archive:** kasus lama bisa dimainkan ulang dengan varian baru dan modifier (waktu lebih ketat, tanpa hint, 1 percobaan tuduhan).
- Semua kasus berupa data (puzzle, clue, graf, briefing per role, solusi). Menambah kasus tidak menyentuh kode.

#### Skema data kasus (ringkas)

```json
{
  "case_id": "gallery_01",
  "variants": [{"culprit": "curator", "motive": "debt"}, {"culprit": "guard", "motive": "revenge"}],
  "location": "gallery",
  "nodes": [
    {"id": "obj_schedule", "type": "object", "gives_key": "key_a"},
    {"id": "ev_schedule", "type": "evidence", "puzzle": "torn_doc", "needs": ["key_a"], "yields": "clue_guard_off"},
    {"id": "ded_access", "type": "deduction", "needs": ["clue_guard_off", "clue_card_log"], "unlocks": ["pin_office"]}
  ],
  "statements": [{"who": "curator", "lie": true, "contradicted_by": "clue_card_log"}]
}
```

### 11. Social & Retention

- **Detective Agency:** squad (atau pemain) punya agency yang naik level, dengan HQ yang bisa didekor dan arsip kasus yang sudah dipecahkan. HQ juga jadi lobby.
- **Case Recap:** layar akhir berisi kontribusi tiap role ("Searcher menemukan 7 bukti, Director benar di percobaan ke-1"), bisa di-screenshot.
- **Daily streak + leaderboard mingguan** per squad dan per individu.
- **Event komunitas (P1):** kasus mingguan di mana tiap sesi menyumbang satu fragmen clue global.
- **Spectator slot (P1):** teman menunggu bisa menonton clue board dan ping.
- **Ghost replay (P2):** pemain solo bisa melihat rekap run squad lain.

### 12. Target Pengguna & Metrik

**Utama:** teman bermain 3 orang (13+), suka misteri/puzzle, sesi 15-30 menit. **Sekunder:** solo/duo dengan NPC. Mayoritas mobile.

| Kategori        | Metrik                                   | Target awal                                       |
| --------------- | ---------------------------------------- | ------------------------------------------------- |
| Retensi         | D1 / D7                                  | 18% / 5% (naikkan setelah ada Agency & daily)     |
| Penyelesaian    | % sesi yang menamatkan kasus             | > 55%                                             |
| Matchmaking     | Median waktu tunggu / % sesi gagal start | < 60 dtk / < 10%                                  |
| Pengalaman role | Idle time per role                       | < 25% sesi                                        |
| Onboarding      | % menamatkan Case 0                      | > 80%                                             |
| Drop-off        | Quit di 5 menit pertama per role         | Dipantau, bandingkan antar role                   |
| Hint            | Rata-rata hint per sesi                  | 1-2                                               |
| Konten          | Story case baru                          | 1 per 1-2 minggu                                  |

### 13. Monetisasi

- **Tanpa pay-to-win.** Solusi dan hint tidak bisa dibeli.
- **Case pack: host-owns.** Satu pemain yang punya, semua anggota sesi bisa main.
- **Kosmetik untuk semua role:**
  - Searcher: avatar, senter, gaya ping (terlihat semua).
  - Handler: meja, set potongan puzzle (terlihat di Table Preview milik Director).
  - Director: skin clue board dan pin (terlihat di Case Recap).
  - Semua: dekor Agency HQ.
- **Hint:** hanya dari kuota gratis per kasus dan progres, bukan Robux.

### 14. Safety & Rating

- Konten non-gore, tema kejahatan non-kekerasan, target rating 13+. Isi kuesioner maturity Roblox sejak prototype.
- Komunikasi utama via ping wheel sehingga paparan chat toksik berkurang.
- Gunakan filter chat Roblox, mute/report mudah diakses, dan tidak ada voice wajib.
- Private server untuk bermain bersama teman.

### 15. Persyaratan Teknis

- Server menyimpan state kasus dan solusi. Client hanya menerima data sesuai role. Pemeriksaan resep deduksi dan tuduhan hanya di server.
- `MaxPlayers = 3`, reserved server untuk sesi teman, `TeleportService` untuk sesi dari lobby/HQ.
- Handler: kamera Scriptable top-down, raycast ke bidang meja, posisi potongan diatur server dan direplikasi (interpolasi di client agar halus di mobile).
- **Gambar puzzle:** jangan asumsi satu gambar raksasa. Platform bisa menurunkan resolusi texture besar, jadi:
  - **Spike minggu 0:** uji `ImageRectOffset`/`ImageRectSize` pada gambar besar di perangkat mobile kelas bawah.
  - Fallback: satu sheet per bukti (resolusi sedang), grid terbatas (misal maks 6x6), atau gaya ilustrasi flat yang tahan downscale.
- Kontrol touch-first, target sentuh besar, UI responsif.
- Telemetri: event per role (idle time, waktu ke clue pertama, tuduhan, quit point) sejak build pertama.

### 16. Scope

#### MVP (P0)

- Meja puzzle top-down dengan drag-and-snap + 3 tipe puzzle bukti.
- 1 lokasi dengan objek yang bisa diperiksa + mini-aksi.
- Director: clue board, kombinasi Clue Card, kontradiksi, map + pinpoint, form tuduhan (3 percobaan).
- Pemisahan info per role (server-authoritative).
- Lobby: 2 preferensi role, ready check, NPC Searcher dan Handler, AFK takeover, rejoin.
- Ping wheel + Report Card + Target Marker (text chat opsional).
- Case 0 (tutorial) + 1 story case dengan 2 varian.
- Telemetri dasar.

#### Pasca-MVP (P1)

- Daily case + validator, leaderboard, rank per role, streak.
- Agency HQ + kosmetik, private server/invite.
- NPC Director terpandu, patroli NPC, spectator slot, event komunitas.

#### Nanti (P2)

- Case pack berbayar, supernatural pack, ghost replay, case editor pemain (butuh moderasi).

### 17. Roadmap (8 Minggu)

| Minggu | Target                                                                        | Gate                                    |
| ------ | ----------------------------------------------------------------------------- | --------------------------------------- |
| 0      | Spike teknis: resolusi gambar, replikasi drag di mobile, ping wheel prototipe | Drag halus di mobile, puzzle tidak blur |
| 1      | Meja puzzle top-down, drag-and-snap                                           | Bisa selesai 1 puzzle di mobile         |
| 2      | Loader kasus dari data, lokasi, objek + kunci                                 | Satu rantai A→bukti jalan end to end    |
| 3      | Director UI: clue board, kombinasi, pinpoint                                  | Satu deduksi berhasil dari 2 clue       |
| 4      | Pemisahan info per role, tuduhan + batas percobaan                            | Tidak ada kebocoran solusi di client    |
| 5      | Lobby, preferensi role, NPC, AFK/rejoin                                       | Sesi 3 pemain mulai tanpa bug           |
| 6      | Case 0, story case #1 + varian, ping wheel final                              | Playtest internal                       |
| 7      | Playtest 3 pemain nyata (mobile), tuning idle time                            | Idle < 25%, selesai > 55%               |
| 8      | Polish, rating questionnaire, rilis                                           | Metrik minggu 7 terpenuhi               |

Pasca rilis: story case tiap 1-2 minggu, lalu daily, Agency, leaderboard, kosmetik.

### 18. Risiko & Mitigasi

| Risiko                       | Mitigasi                                                        |
| ---------------------------- | --------------------------------------------------------------- |
| Lobby sepi                   | NPC pengisi, private server, invite, spectator                  |
| Satu pemain mendominasi      | Hanya tuduhan & hint yang butuh persetujuan; rantai paralel     |
| Konten cepat habis           | Varian solusi, daily, Cold Case, data-driven                    |
| Spoiler                      | Cabang solusi per seed, rotasi daily                            |
| Exploit/bocor                | Solusi & resep hanya di server                                  |
| Komunikasi buruk tanpa voice | Ping wheel, Report Card, Table Preview                          |
| Director NPC lemah           | Mode terpandu, rank terpisah, prioritas manusia                 |
| Puzzle blur di mobile        | Spike minggu 0, fallback sheet kecil                            |
| Scope MVP terlalu besar      | 1 lokasi, 3 tipe puzzle, 2 NPC dulu, Director NPC ke P1         |
| Rating konten                | Tema non-gore, isi kuesioner sejak awal                         |

### 19. Pertanyaan Terbuka

- Nama game dan arah visual (opsi: low-poly noir hangat dengan lampu meja sebagai identitas Handler).
- Durasi timer cleanup yang pas, dan validasi N dari playtest minggu 7 (naik/turun 1 jika selesai < 55% atau > 85%).
