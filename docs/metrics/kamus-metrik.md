# Kamus Metrik Triangulate

Pemilik dokumen: **Rani — Data & Metrics Engineer** (definisi, instrumen, sumber angka).
Berlaku sejak: **2026-10-04**. Versi: **1.0**.
Rujukan PRD: `docs/prd-v0.2.md` §5 (rank & anti brute-force), §6 (anti-downtime, idle < 25%), §8 (matchmaking/NPC), §11 (retensi & leaderboard), §12 (tabel metrik), §15 (telemetri), §17 (gate minggu 7).

Aturan dokumen ini: satu metrik, satu definisi, satu sumber angka, satu tanggal berlaku. Setiap klaim menunjuk bagian PRD; setiap angka yang tidak berasal dari PRD ditandai **ASUMSI** beserta apa yang memverifikasi atau menggantikannya.

Skema event yang menjadi sumber angka: `docs/metrics/skema-event-telemetri.md` dan `docs/metrics/telemetry-events.schema.json`.

---

## 0. Aturan umum sebelum menghitung apa pun

Empat hal berikut adalah penyebab paling umum dua orang menghasilkan angka berbeda dari sesi yang sama. Semuanya dipaku di sini dan tidak boleh ditafsirkan ulang per laporan.

### 0.1 Unit analisis

| Istilah | Definisi | Dipakai oleh |
|---|---|---|
| `session` | Satu instance server tempat kasus dimainkan, diidentifikasi `session_id`. Berisi 1-3 pemain manusia + NPC. | denominator `% sesi yang menamatkan kasus`, `% sesi gagal start` |
| `player_session` | Pasangan (`session_id`, `player_id`). Satu pemain yang disconnect lalu rejoin tetap **satu** `player_session` (lihat 0.4). | `idle time per role`, `quit 5 menit pertama`, `waktu ke clue pertama` |
| `player_role_instance` | Pasangan (`session_id`, `player_id`, `role`). Terbentuk saat `role_assigned`; bila pemain tukar role di lobby, yang dihitung adalah role final saat `case_started`. | semua metrik per role |
| `cohort_day` | Himpunan pemain yang `session_start` pertamanya (`is_first_session = true`) jatuh pada tanggal kalender yang sama. | D1, D7 |
| `kasus` | Satu `case_id` + `case_variant` pada satu `session`. Cold Case Archive memakai `case_id` yang sama dengan `mode = cold_case` dan dihitung terpisah. | `% sesi yang menamatkan kasus`, rank |

Metrik yang memakai `session` sebagai denominator **tidak** boleh dihitung dari jumlah baris event, karena satu sesi menghasilkan ratusan baris. Selalu agregasi ke `session_id` lebih dulu, baru bagi.

### 0.2 Waktu

- Semua perhitungan memakai **`t_server_ms`** (epoch ms, jam server, UTC). `t_client_ms` hanya diagnostik dan tidak pernah dipakai untuk metrik.
- Titik nol durasi kasus adalah `case_started.t_server_ms`. Bukan `session_start` (lobby belum tentu masuk kasus) dan bukan `role_assigned` (role bisa diberikan sebelum kasus mulai).
- Batas hari kalender untuk D1/D7 dan daily case: **00:00 UTC**. **ASUMSI** — PRD tidak menetapkan zona waktu. Verifikasi: kesepakatan pemilik tafsir (CMO); bila pemain mayoritas satu zona, ganti ke zona itu sebagai satu perubahan kamus, bukan per laporan.
- Satuan keluaran: durasi dalam **detik** (1 desimal), rasio dalam **persen** (1 desimal). Pembulatan dilakukan sekali di keluaran akhir, bukan di antar-langkah.

### 0.3 NPC dan pemain yang keluar

- Setiap event membawa `is_npc`. NPC tidak pernah masuk denominator retensi, onboarding, atau leaderboard utama.
- PRD §8: "Sesi dengan NPC Director dihitung rank terpisah (tanpa leaderboard utama)." Karena itu setiap agregat rank membawa `rank_board ∈ {main, npc_director}`. NPC Searcher/Handler **tidak** memindahkan sesi ke papan terpisah — hanya NPC Director.
- Sesi yang berakhir karena alasan teknis (`end_reason = error`) dikeluarkan dari `% sesi yang menamatkan kasus` dan `% sesi gagal start`, tetapi tetap dilaporkan sebagai baris tersendiri supaya tidak terlihat seperti nol.

### 0.4 Rejoin, AFK, dan waktu terhenti

- AFK 60 detik tanpa input → NPC mengambil alih role (PRD §8). Ditandai `npc_takeover`, dan sejak titik itu `player_role_instance` **berhenti** menyumbang idle sampai `player_rejoined` atau sesi berakhir.
- Disconnect menahan slot 3 menit untuk rejoin (PRD §8). Rejoin memakai `session_id` yang sama dan **tidak** menambah `player_session`; `player_session` dihitung mulai dari `role_assigned` pertama.
- Karena itu setiap `player_session` punya `player_active_duration_ms` yang dapat lebih pendek dari durasi sesi.

### 0.5 Penandaan status data

Setiap angka yang dipublikasikan wajib membawa salah satu label:

| Label | Arti |
|---|---|
| `TERUKUR` | Dihitung dari event yang sudah ada di sink telemetri. |
| `BLOKIR` | Definisi lengkap, tetapi event/kolom sumbernya belum ada. Sebutkan penghalangnya. |
| `ASUMSI` | Angka atau ambang ditetapkan sementara tanpa dasar PRD. Sebutkan apa yang memverifikasi. |
| `TIDAK ADA DATA` | Metrik kosong. **Wajib** ditulis apa adanya di laporan, bukan dikosongkan, karena metrik kosong yang tidak dijelaskan terbaca sebagai nol. |

---

## 1. Definisi operasional "input bermakna"

PRD §6: "pada playtest, idle time (tanpa input bermakna) tiap role harus di bawah 25% sesi". PRD tidak mendefinisikan "input bermakna". Definisi berikut mengikat; dua pengamat memakai daftar kelas aksi ini, bukan penilaian sendiri.

### 1.1 Kelas aksi yang dihitung

Sebuah aksi dihitung sebagai input bermakna **jika dan hanya jika** keempatnya benar:

1. berasal dari pemain manusia (`is_npc = false`, bukan aksi server/NPC),
2. kelasnya ada di tabel di bawah,
3. diterima server (tidak ditolak validasi, tidak dibatasi rate limit),
4. tidak jatuh di dalam jendela `session_paused` (cutscene, overlay tutorial, loading, pemulihan error).

| Kode | Kelas | Contoh | Role |
|---|---|---|---|
| `MOVE` | perpindahan karakter dari input pemain | `Humanoid.MoveDirection ≠ 0` | Searcher |
| `INTERACT` | aksi pada objek lokasi | examine, Report, ambil, pakai kunci, hold-to-open, lockpick, senter UV | Searcher |
| `TABLE` | manipulasi meja puzzle | ambil, drag, putar, letakkan, snap potongan | Handler |
| `BOARD` | operasi clue board | drag Clue Card, kombinasi kartu, tandai kontradiksi, taruh pinpoint, buka pernyataan | Director |
| `UI_NAV` | navigasi panel yang mengubah apa yang dilihat | buka/tutup arsip, ganti tab, gulir daftar | semua |
| `COMM` | komunikasi tanpa mengetik | ping wheel, Report Card, Target Marker, Pinpoint, kirim chat | semua |
| `CONFIRM` | persetujuan & pengajuan | ready check, setujui hint, submit tuduhan, terima tukar role | semua |
| `CAM_WITH_ACTION` | input kamera yang jatuh di bucket 1 detik yang sama dengan kelas lain di atas | geser kamera sambil berjalan | semua |

### 1.2 Yang tidak dihitung

| Kode | Kelas | Alasan |
|---|---|---|
| `CAM_ONLY` | rotasi/zoom kamera tanpa kelas lain di bucket yang sama | menatap layar bukan kemajuan; tetap diukur terpisah sebagai `camera_only_time` agar bias ini terlihat |
| `NPC` | perubahan state akibat NPC takeover | PRD §8: NPC yang menggantikan bukan input pemain |
| `REJECTED` | remote yang ditolak validasi/rate limit | tidak mengubah state; spam tidak boleh menaikkan keaktifan |
| `PAUSED` | input selama jendela `session_paused` | tidak ada yang bisa dikerjakan; masuk `idle_ratio_adj`, bukan `idle_ratio` |
| `MENU_ONLY` | berhenti di menu/lobby setelah `case_started` | di luar jendela kasus |

### 1.3 Algoritma idle (wajib sama di server, di laporan, dan di pengamat manual)

```
BUCKET_MS        = 1000
IDLE_THRESHOLD_S = 5      # ASUMSI, lihat §1.4
JENDELA          = [case_started.t_server_ms , min(player_left.t , session_end.t)]

1. Buat bucket 1 detik selaras dengan case_started.t_server_ms.
2. bucket ACTIVE  <=> ada >= 1 input bermakna (§1.1) di dalamnya.
3. Cari run maksimal bucket INACTIVE yang berurutan.
4. Run dengan durasi >= IDLE_THRESHOLD_S menjadi satu idle run.
   idle_start.t = t_server_ms bucket INACTIVE pertama
   idle_end.t   = t_server_ms input bermakna pertama yang mengakhiri run
   (run terakhir yang mencapai session_end: idle_end.t = session_end.t)
5. idle_time_role_ms = jumlah durasi seluruh idle run di jendela.
6. player_active_duration_ms = min(player_left.t , session_end.t) - max(role_assigned.t , case_started.t)
   idle_ratio          = idle_time_role_ms / player_active_duration_ms      # metrik utama, PRD §6 "25% sesi"
   idle_ratio_adj      = idle_time_role_ms / (player_active_duration_ms - total_session_paused_ms)
```

Catatan yang mengikat:

- Run pendek (< 5 detik) **tidak** menjadi idle run sama sekali; tidak ada penambahan durasi. Jeda antar-input normal (berpikir, membaca clue) tidak boleh terhitung sebagai menganggur.
- Durasi idle run dihitung **utuh** sejak bucket INACTIVE pertama, bukan hanya bagian setelah ambang 5 detik.
- `idle_start` baru dikirim setelah ambang tercapai, tetapi `t_server_ms` yang dibawa adalah waktu bucket INACTIVE pertama. Ini supaya urutan event tidak mengubah angka.
- Bucket ACTIVE tidak pernah dihitung idle, walau hanya 1 input di dalamnya. Bucket ini termasuk aksi berdurasi panjang (hold, drag) karena server menerima `begin`/`end`-nya.

### 1.4 Ambang dan sensitivitas

| Parameter | Nilai | Status |
|---|---|---|
| `BUCKET_MS` | 1000 | **ASUMSI** — dipilih agar tidak sensitif terhadap jitter jaringan mobile |
| `IDLE_THRESHOLD_S` | 5 | **ASUMSI** — PRD §6 tidak menetapkan ambang |
| Gate idle | < 25% per role | PRD §6 dan §17 minggu 7 |

Verifikasi: pada playtest minggu 7, laporkan `idle_ratio` untuk `IDLE_THRESHOLD_S ∈ {3, 5, 10}` dan `camera_only_time`. Bila peringkat role berubah antar ambang, gate minggu 7 belum layak dipakai sebagai keputusan. Ambang final ditetapkan lewat perubahan kamus ini.

### 1.5 Perbedaan `idle_ratio` dan `idle_ratio_adj`

- `idle_ratio` adalah metrik gate, karena PRD §6 menulis "25% sesi". Denominatornya seluruh waktu aktif pemain.
- `idle_ratio_adj` adalah diagnostik, untuk membedakan "pemain menganggur" dari "sistem menahan pemain" (menunggu rantai lain, cutscene, loading). Dua angka ini dipublikasikan bersama; memakai `idle_ratio_adj` untuk klaim gate adalah pelanggaran definisi.
- **Eskalasi**: mana yang menjadi gate minggu 7 perlu keputusan. Lihat §8 butir E1.

---

## 2. Kamus metrik PRD §12

Kolom: **Rumus** = N/D; **Window** = jendela waktu; **Sumber** = event/kolom; **Penarik** = perintah penarik; **Pemilik tafsir** = lapis yang berhak menyimpulkan (bukan aku untuk metrik bisnis).

Semua perintah penarik ditulis terhadap kontrak sink telemetri `telemetry.query(...)`. Sink belum ada — lihat §6 butir G1 — sehingga **seluruh perintah di bawah berstatus BLOKIR** sampai EXTA-32/EXTA-34 menetapkan penyimpanan. Definisi dan rumusnya sudah final dan tidak berubah saat sink ditetapkan.

### 2.1 M-01 Retensi D1

| Kolom | Isi |
|---|---|
| Definisi operasional | Persentase pemain yang `session_start` pertamanya pada hari D dan kembali bermain pada hari D+1. |
| Rumus | N = jumlah `player_id` distinct dengan `is_first_session = true` pada hari D **dan** ≥ 1 `session_start` pada hari D+1. D = jumlah `player_id` distinct dengan `is_first_session = true` pada hari D. |
| Window | Kohort harian, dilaporkan bergulir 30 hari. Pemain dengan D+1 belum tuntas **tidak** dihitung di denominator hari itu. |
| Unit | pemain (bukan sesi, bukan squad) |
| Sumber | `session_start` (`is_first_session`, `player_id`) + tabel turunan `player_first_seen` |
| Penarik | `cohort(day=D).first_session_players` → join `session_start` hari D+1 → `count(distinct player_id) / count(cohort)` |
| Pemilik tafsir | CMO (pertumbuhan/retensi) |
| Status | `BLOKIR` — butuh tabel turunan lintas-sesi; PRD §12 menetapkan target 18%. |

### 2.2 M-02 Retensi D7

Definisi, rumus, window, unit, sumber, penarik sama dengan M-01 dengan D+7. Target PRD §12: 5%. Pemilik tafsir: CMO. Status: `BLOKIR` (alasan sama).

Catatan yang mengikat untuk M-01/M-02:

- Retensi dihitung per **pemain**, bukan per squad. Leaderboard per squad (PRD §11) adalah metrik berbeda dan tidak menggantikan ini. Squad-level dapat ditambahkan sebagai M-02b setelah `agency_id` ada di `session_start`.
- Pemain yang hanya masuk lobby lalu keluar tanpa `case_started` tetap dihitung bermain pada hari itu. **ASUMSI** — PRD tidak membedakan. Verifikasi: keputusan pemilik tafsir; alternatif (syaratkan `case_started`) mengubah angka ke bawah dan harus jadi revisi kamus, bukan variasi laporan.
- Definisi "bermain pada hari D+1" = ada `session_start`, apa pun durasinya.

### 2.3 M-03 Persentase sesi yang menamatkan kasus

| Kolom | Isi |
|---|---|
| Definisi operasional | Dari sesi yang benar-benar memulai kasus, berapa yang berakhir menang (tuduhan benar pada ≤ 3 percobaan, PRD §5). |
| Rumus | N = jumlah `session_id` distinct dengan `case_completed.outcome = win`. D = jumlah `session_id` distinct dengan `case_started` dan `end_reason ∉ {error}`. |
| Window | Bergulir 7 hari, dilaporkan mingguan. |
| Unit | sesi |
| Sumber | `case_started`, `case_completed.outcome`, `session_end.end_reason` |
| Penarik | `telemetry.query(["case_started","case_completed","session_end"])` → group by `session_id` → hitung |
| Pemilik tafsir | CMO (produk/retensi) dengan masukan desain |
| Status | `BLOKIR` — `case_started` dan `case_completed` belum ada. Target PRD §12: > 55%; gate PRD §17 minggu 7. |

Catatan yang mengikat:

- Cold Case (`outcome = cold_case`, 3 tuduhan salah) masuk denominator dan **bukan** numerator.
- Sesi tanpa `case_completed` tetapi punya `session_end` (ditinggalkan) masuk denominator sebagai gagal, kecuali `end_reason = error`.
- Karena PRD §8 memisahkan rank sesi ber-NPC-Director, metrik ini dilaporkan dua kali: semua sesi, dan `rank_board = main`. Angka gate memakai **semua sesi** kecuali diputuskan lain.

### 2.4 M-04 Median waktu tunggu matchmaking

| Kolom | Isi |
|---|---|
| Definisi operasional | Median jeda dari pemain masuk lobby sampai kasus dimulai. |
| Rumus | `lobby_wait_ms = case_started.t_server_ms - lobby_enter.t_server_ms`, per `player_id` per sesi. Median dari seluruh `player_role_instance` di window. |
| Window | Bergulir 7 hari. |
| Unit | player-lobby instance (yang dialami pemain, bukan yang dialami server) |
| Sumber | `lobby_enter`, `case_started` |
| Penarik | `telemetry.query(["lobby_enter","case_started"])` → join per (`session_id`,`player_id`) → median |
| Pemilik tafsir | COO (operasi/cadence matchmaking) |
| Status | `BLOKIR` — `lobby_enter` belum ada. Target PRD §12: < 60 detik. |

Catatan: sesi yang tidak pernah `case_started` tidak punya `lobby_wait_ms` dan hanya masuk M-05. Pemain yang rejoin di tengah sesi berjalan tidak dihitung di M-04.

### 2.5 M-05 Persentase sesi gagal start

| Kolom | Isi |
|---|---|
| Definisi operasional | Dari sesi yang pernah masuk lobby, berapa yang bubar tanpa pernah memulai kasus. |
| Rumus | N = jumlah `session_id` distinct dengan `lobby_exit` dan **tanpa** `case_started`. D = jumlah `session_id` distinct dengan `lobby_enter`. |
| Window | Bergulir 7 hari. |
| Unit | sesi |
| Sumber | `lobby_enter`, `lobby_exit.reason ∈ {timeout, all_left, cancelled, error}`, `case_started` |
| Penarik | `telemetry.query(["lobby_enter","lobby_exit","case_started"])` → group by `session_id` |
| Pemilik tafsir | COO |
| Status | `BLOKIR` — `lobby_exit` belum ada. Target PRD §12: < 10%. |

### 2.6 M-06 Idle time per role

| Kolom | Isi |
|---|---|
| Definisi operasional | Porsi waktu pemain memegang sebuah role di dalam kasus tanpa satu pun input bermakna (§1.1), dihitung dengan algoritma §1.3. |
| Rumus | N = `Σ durasi idle run` per (`session_id`,`player_id`,`role`); D = `player_active_duration_ms` = `min(player_left.t, session_end.t) − max(role_assigned.t, case_started.t)`. Median dan persentil-90 dilaporkan **per role**, bukan rata-rata gabungan. |
| Window | Bergulir 7 hari; pada playtest minggu 7 dihitung per sesi. |
| Unit | player_role_instance |
| Sumber | `idle_start`, `idle_end`, `role_assigned`, `case_started`, `player_left`, `session_end`, `session_paused`/`session_resumed` (untuk `idle_ratio_adj`) |
| Penarik | `telemetry.query(["idle_start","idle_end"])` → pasangkan run → jumlahkan per role |
| Pemilik tafsir | COO (operasi playtest); definisi instrumen milik Data & Metrics |
| Status | `BLOKIR` — `idle_start`/`idle_end` belum ada. Gate PRD §6/§17 minggu 7: < 25% sesi. |

Catatan yang mengikat:

- Wajib dilaporkan **per role** (Searcher, Handler, Director). Rata-rata tiga role menyembunyikan role yang gagal gate — PRD §6 menyebut "tiap role".
- `player_role_instance` yang sebagian besar waktunya diambil alih NPC (§0.4) dilaporkan dengan penanda `npc_takeover = true` dan dikeluarkan dari angka gate, karena yang diukur bukan lagi pemain. Jumlahnya tetap dilaporkan.
- `camera_only_time` dan `idle_ratio_adj` dilaporkan bersanding sebagai diagnostik (§1.5).

### 2.7 M-07 Persentase menamatkan Case 0

| Kolom | Isi |
|---|---|
| Definisi operasional | Dari pemain yang pertama kali memulai Case 0, berapa yang mencapai akhir kasus (menang **atau** Cold Case). |
| Rumus | N = jumlah `player_id` distinct dengan `case_completed.case_id = case_0`. D = jumlah `player_id` distinct dengan `case_started.case_id = case_0` dan `is_first_case_0_play = true`. |
| Window | Kohort pemain baru, bergulir 30 hari. |
| Unit | pemain |
| Sumber | `case_started`, `case_completed`, `case_0_skipped`, tabel turunan `player_first_seen` |
| Penarik | `telemetry.query(["case_started","case_completed"])` filter `case_id = case_0` |
| Pemilik tafsir | CMO (funnel onboarding) |
| Status | `BLOKIR` — butuh `case_id` pada event kasus dan penanda pemain baru. Target PRD §12: > 80%. |

Catatan: PRD §9 menyatakan Case 0 wajib sekali per akun dan bisa di-skip. Pemain yang skip tidak masuk denominator (tidak pernah `case_started` untuk `case_0`) tetapi dihitung di `case_0_skipped` dan dilaporkan sebagai baris terpisah. "Menamatkan" = mencapai `case_completed`, terlepas dari hasil tuduhan. Bila pemilik tafsir ingin arti "menang", itu metrik baru M-07b, bukan perubahan diam-diam.

### 2.8 M-08 Quit di 5 menit pertama per role

| Kolom | Isi |
|---|---|
| Definisi operasional | Dari pemain yang memegang sebuah role saat kasus berjalan, berapa yang berhenti pada 300 detik pertama tanpa rejoin. |
| Rumus | N = jumlah `player_role_instance` dengan `player_left.t_server_ms − case_started.t_server_ms < 300000` **dan** `player_left.reason ∈ {voluntary, afk_timeout}` **dan** tidak ada `player_rejoined` dalam 3 menit. D = jumlah `player_role_instance` dengan `case_started` dan `end_reason ∉ {error}`. |
| Window | Bergulir 7 hari; dilaporkan per role, bukan hanya total. |
| Unit | player_role_instance |
| Sumber | `player_left` (`reason`, `t_server_ms`), `player_rejoined`, `case_started`, `session_end.end_reason` |
| Penarik | `telemetry.query(["player_left","player_rejoined"])` → filter selisih < 300000 ms |
| Pemilik tafsir | COO |
| Status | `BLOKIR` — `player_left`/`player_rejoined` belum ada. PRD §12: "Dipantau, bandingkan antar role" — tidak ada target. |

Catatan yang mengikat:

- Berhenti karena kasus sudah selesai (menang/Cold Case) **bukan** quit. Karena itu syarat `case_completed` belum ada untuk sesi itu.
- `reason = disconnect` yang diikuti `player_rejoined` dalam 3 menit bukan quit (PRD §8 menahan slot 3 menit).
- Wajib per role, karena tujuan baris PRD §12 adalah membandingkan antar role.

### 2.9 M-09 Rata-rata hint per sesi

| Kolom | Isi |
|---|---|
| Definisi operasional | Rata-rata jumlah hint yang benar-benar terpakai per sesi yang memulai kasus. |
| Rumus | N = jumlah event `hint_used`; D = jumlah `session_id` distinct dengan `case_started` dan `end_reason ∉ {error}`. |
| Window | Bergulir 7 hari. |
| Unit | sesi |
| Sumber | `hint_used` (`hint_source`, `approver_role`, `remaining_quota`) |
| Penarik | `telemetry.query(["hint_used","case_started"])` → `count(hint_used) / count(distinct case_started.session_id)` |
| Pemilik tafsir | **belum ada** — lihat §8 butir E2 |
| Status | `BLOKIR` — `hint_used` belum ada. Target PRD §12: 1-2. |

Catatan: PRD §8 menetapkan pakai hint butuh persetujuan 2 role, jadi `hint_used` wajib membawa `requester_role` dan `approver_role`; tanpa itu tidak bisa dipisahkan hint yang diminta Searcher dari yang diminta Director. Hint gratis rookie mode (PRD §9) tetap dihitung sebagai `hint_used` dengan `hint_source = rookie` dan dilaporkan terpisah, karena ia bukan permintaan pemain.

### 2.10 M-10 Story case baru

| Kolom | Isi |
|---|---|
| Definisi operasional | Jumlah story case yang dirilis pada window. |
| Rumus | N = jumlah entri di registri kasus dengan `type = story` dan `release_date` di dalam window. D = tidak ada (ini hitungan, bukan rasio). |
| Window | Bergulir 30 hari, dilaporkan sebagai kasus/minggu. |
| Unit | kasus |
| Sumber | **Bukan telemetri pemain.** Registri kasus di repo (`release_date`, `type`) — bergantung pada EXTA-33 |
| Penarik | `count(registri_kasus where type = story and release_date in window) / (window_hari / 7)` |
| Pemilik tafsir | CMO (konten) |
| Status | `BLOKIR` — belum ada registri kasus; tidak dapat dihitung dari event pemain mana pun. Target PRD §12: 1 per 1-2 minggu. |

### 2.11 Metrik pendukung §15 dan §6

PRD §15 menyebut telemetri "event per role (idle time, waktu ke clue pertama, tuduhan, quit point)". Tiga di antaranya sudah jadi M-06, M-08, dan bagian dari M-03. Sisanya di bawah.

#### M-11 Waktu ke clue pertama (per role)

| Kolom | Isi |
|---|---|
| Definisi operasional | Jeda dari kasus mulai sampai role tersebut memperoleh clue pertamanya. |
| Rumus | `first_clue.t_since_case_start_ms`, per `player_role_instance`. Dilaporkan sebagai median per role. |
| Pemicu per role (mengikat) | Searcher = `object_reported` pertama; Handler = `evidence_completed` pertama; Director = `clue_card_received` pertama. |
| Window | Bergulir 7 hari. |
| Unit | player_role_instance |
| Sumber | `case_started`, `first_clue` (`role`, `clue_kind`, `node_id`) |
| Penarik | `telemetry.query(["first_clue"])` → median per role |
| Pemilik tafsir | COO (playtest), masukan desain |
| Status | `BLOKIR` — `first_clue` belum ada. Tidak ada target di PRD §12. |

Catatan: bila sebuah role tidak pernah mendapat clue (sesi berakhir lebih dulu), ia **tidak** masuk median dan dihitung di baris terpisah `tanpa_clue` per role. Memasukkan 0 akan menyesatkan.

#### M-12 Tuduhan per sesi dan komposisi hasil

| Kolom | Isi |
|---|---|
| Definisi operasional | Distribusi jumlah percobaan tuduhan dan field yang benar. |
| Rumus | Jumlah `accusation_submitted` per `session_id`; `correct_fields_count` per percobaan. |
| Window | Bergulir 7 hari. |
| Unit | sesi / percobaan |
| Sumber | `accusation_submitted` (`attempt_no`, `correct_fields_count`, `gate_open`) |
| Penarik | `telemetry.query(["accusation_submitted"])` → group by `session_id`, `attempt_no` |
| Pemilik tafsir | COO |
| Status | `BLOKIR`. PRD §5: maksimum 3 percobaan, feedback hanya "X dari 3 benar" — jadi `correct_fields_count` wajib ada di event, bukan dihitung ulang di client. |

#### M-13 Komponen rank S/A/B/C

| Kolom | Isi |
|---|---|
| Definisi operasional | Rank per sesi dari tiga komponen PRD §5: waktu, jumlah tuduhan, hint terpakai. Rubrik di §3. |
| Rumus | `rank = min(tier_attempts, tier_hints, tier_time)`; `min` = tier terburuk. |
| Window | Bergulir 7 hari. |
| Unit | sesi |
| Sumber | `case_completed` (`accusation_attempts`, `hints_used`, `case_duration_ms`, `rank`, `rank_board`), `par_time_s` dari data kasus |
| Penarik | `telemetry.query(["case_completed"])` → group by `rank_board`, `rank` |
| Pemilik tafsir | **belum ada** — lihat §8 butir E3 |
| Status | `BLOKIR` — `par_time_s` belum ada di skema kasus (EXTA-33) dan ambang rubrik masih `ASUMSI`. |

---

## 3. Rubrik rank S/A/B/C (§5)

PRD §5 hanya menyebut komponen ("waktu, jumlah tuduhan, dan hint terpakai") tanpa ambang. Rubrik berikut **ASUMSI** sampai disetujui pemilik tafsir. Tanpa rubrik, dua pengamat akan memberi rank berbeda untuk sesi yang sama — itu kegagalan acceptance.

Aturan yang mengikat:

1. Rank hanya diberikan untuk sesi yang **menang**. Cold Case (3 tuduhan salah) tidak ber-rank; ia dilaporkan sebagai `cold_case`.
2. Setiap komponen diberi tier, lalu **rank akhir = tier terburuk**. Satu komponen buruk tidak bisa ditutup komponen lain. Ini menghilangkan ambiguitas "rata-rata tier".
3. Rank dihitung server saat `case_completed` dan dikirim di event; laporan **tidak** menghitung ulang dari komponen mentah, supaya angka historis tidak berubah saat rubrik direvisi. Revisi rubrik berlaku lewat perubahan kamus ini + penanda `rank_rule_version`.

| Komponen | S | A | B | C |
|---|---|---|---|---|
| Percobaan tuduhan | 1 | 2 | 3 | — (Cold Case, tanpa rank) |
| Hint terpakai | 0 | 1 | 2 | ≥ 3 |
| Waktu (`case_duration_ms / par_time_s`) | ≤ 0,75× | ≤ 1,00× | ≤ 1,50× | > 1,50× |

- `par_time_s` disimpan di data kasus per (`case_id`, `case_variant`) dan wajib ada sebelum rank bisa dihitung. Ini menambah field ke skema kasus EXTA-33 — lihat §5.
- Modifier Cold Case Archive (PRD §10: waktu lebih ketat, tanpa hint, 1 percobaan) mengubah `par_time_s` dan batas percobaan. **ASUMSI**: belum ada angka; sampai ditetapkan, sesi `mode = cold_case` dilaporkan tanpa rank.
- Sesi dengan NPC Director memakai rubrik yang sama tetapi masuk `rank_board = npc_director` (PRD §8), tidak masuk leaderboard utama.
- Pemain yang memakai lebih dari 3 hint tidak mungkin ada di MVP karena kuota; baris C dipertahankan agar rubrik tidak berubah bila kuota dilonggarkan.

Verifikasi rubrik: pada playtest minggu 6-7, laporkan distribusi rank per komponen sebelum digabung. Bila > 80% sesi jatuh di satu rank, ambang belum memisahkan apa pun dan harus disetel.

---

## 4. Contoh perhitungan (uji reproducibility)

Fixture: `docs/metrics/fixtures/sesi-contoh.jsonl` — satu sesi sintetis 3 pemain manusia, `case_id = gallery_01`, `case_variant = A`, `case_started.t_server_ms = 1000000`, `session_end.t_server_ms = 1540000` (durasi kasus 540 detik). Pasangannya `docs/metrics/fixtures/sesi-contoh-inputs.json` berisi aliran input bermakna 1 Hz per pemain; idle run di fixture **diturunkan** dari aliran itu dengan algoritma §1.3, bukan ditulis tangan, sehingga pembaca kedua dapat mengulang penurunannya.

Angka di bawah adalah hasil yang **wajib** diperoleh pembaca kedua dari fixture yang sama. Bila berbeda, definisi di dokumen ini yang dipakai, bukan angka di tabel.

| Metrik | Nilai | Cara |
|---|---|---|
| `player_active_duration_ms` (per pemain) | 540000 | `session_end − case_started`; ketiganya masuk sejak `case_started` |
| M-06 Searcher | 75/540 = **13,9%** | idle run 25 s × 3 |
| M-06 Handler | 80/540 = **14,8%** | idle run 40 s × 2 |
| M-06 Director | 120/540 = **22,2%** | idle run 60 s × 2 |
| Gate PRD §6 | **lolos** | ketiga role < 25% |
| M-11 Searcher | 95 s | `first_clue.t_since_case_start_ms = 95000` |
| M-11 Handler | 120 s | 120000 |
| M-11 Director | 150 s | 150000 |
| M-04 median waktu tunggu | 42 s | `lobby_enter 958000` → `case_started 1000000` |
| M-09 hint per sesi | 1 | satu `hint_used` |
| M-12 tuduhan | 1 percobaan, 3/3 field benar | `accusation_submitted.attempt_no = 1` |
| M-13 rank | **B** | percobaan 1 → S; hint 1 → A; waktu 540/480 = 1,125 → B; terburuk = B |
| M-03 kontribusi | 1 sesi menang dari 1 sesi dimulai = 100% | `case_completed.outcome = win` |

Perhitungan M-06 secara rinci (Searcher):

```
idle run 1: 1030000 -> 1055000  = 25000 ms
idle run 2: 1300000 -> 1325000  = 25000 ms
idle run 3: 1480000 -> 1505000  = 25000 ms
total idle = 75000 ms ; player_active_duration = 540000 ms ; ratio = 13,9%
```

Verifikasi mekanis: skrip sekali-pakai menghitung ulang seluruh angka di atas dari fixture dan membandingkannya dengan tabel ini. Skrip tidak disimpan di repo (bukan deliverable), hasil jalannya dilaporkan di komentar issue EXTA-36.

---

## 5. Kontrak ketergantungan lintas workstream

Dokumen ini tidak mengubah issue lain, tetapi tiga hal berikut harus ada agar metrik §12 dapat dihitung. Semuanya ditulis sebagai kebutuhan, bukan permintaan perubahan ke workstream lain.

| # | Yang dibutuhkan | Di mana | Dipakai oleh |
|---|---|---|---|
| D1 | `case_started`, `case_completed`, `lobby_enter`, `lobby_exit`, `player_left`, `player_rejoined`, `npc_takeover`, `session_paused`/`session_resumed` | TelemetryService (EXTA-32) | M-03, M-04, M-05, M-06, M-07, M-08 |
| D2 | `par_time_s` per (`case_id`, `case_variant`) di data kasus | Skema kasus (EXTA-33) | M-13 rubrik rank |
| D3 | `release_date` + `type` pada registri kasus | Pipeline konten (EXTA-33/EXTA-38) | M-10 |
| D4 | Penyimpanan telemetri + tabel turunan `player_first_seen`, `is_first_session`, `days_since_first_session` | Sink telemetri (EXTA-32/EXTA-34) | M-01, M-02, M-07 |
| D5 | `agency_id` pada `session_start` (P1) | TelemetryService | M-02b squad retention (belum didefinisikan) |

Aturan retensi dan PII yang **harus** dipegang sink telemetri: tidak ada isi chat dan tidak ada teks bebas di event mana pun (PRD §14 komunikasi via ping wheel); `player_id` adalah Roblox UserId dan diperlakukan sebagai data pribadi pseudonim; retensi dan hak hapus ditetapkan pemilik sink, bukan dokumen ini.

---

## 6. Metrik §12 yang belum bisa dihitung + event tambahan

Daftar lengkap dengan penghalangnya. Ini bagian yang harus dibaca lebih dulu saat sebuah laporan kosong.

| # | Metrik | Penghalang | Event/kolom tambahan yang dibutuhkan | Dapat dihitung setelah |
|---|---|---|---|---|
| G1 | M-01, M-02, M-07 | Tidak ada tabel turunan lintas-sesi; sink telemetri belum ditetapkan | `session_start.is_first_session`, `days_since_first_session`, tabel `player_first_seen` | D4 |
| G2 | M-03, M-07, M-09, M-12, M-13 | Tidak ada batas awal/akhir kasus | `case_started`, `case_completed` | D1 |
| G3 | M-04, M-05 | Tidak ada event lobby | `lobby_enter`, `lobby_exit.reason` | D1 |
| G4 | M-08 | Tidak ada event keluar/masuk pemain | `player_left.reason`, `player_rejoined` | D1 |
| G5 | M-06 | Tidak ada idle run | `idle_start`, `idle_end`, `session_paused`, `session_resumed`, `npc_takeover` | D1 |
| G6 | M-13 | `par_time_s` tidak ada di data kasus | `par_time_s` per varian (D2) | D2 |
| G7 | M-10 | Metrik konten, bukan telemetri pemain | Registri kasus ber-`release_date` (D3) | D3 |
| G8 | M-02b | Tidak ada identitas squad | `agency_id` di `session_start` | D5 (P1) |
| G9 | M-06 versi gate | Ambang idle & definisi input bermakna belum divalidasi playtest | keputusan E1 | playtest minggu 7 |

Event di luar daftar minimum issue yang **wajib** ditambahkan agar metrik §12 punya sumber (semuanya didefinisikan di `skema-event-telemetri.md`): `lobby_enter`, `lobby_exit`, `case_started`, `case_completed`, `player_left`, `player_rejoined`, `npc_takeover`, `session_paused`, `session_resumed`, `clue_card_received`, `object_reported`, `case_0_skipped`.

---

## 7. Integritas data — yang diperiksa berkala

Sesuai tugas Data & Metrics: duplikasi, metrik yatim, definisi mati, klaim tanpa sumber.

| Pemeriksaan | Frekuensi | Keluaran |
|---|---|---|
| Duplikasi definisi (dua entri untuk metrik sama) | per revisi kamus | daftar bentrok |
| Metrik yatim (ada definisi, tidak ada laporan memakai) | bulanan | daftar metrik tanpa konsumen |
| Definisi mati (masih tercantum, tidak berlaku) | per revisi kamus | usulan hapus + tanggal |
| Metrik kosong tanpa penjelasan | setiap laporan | baris `TIDAK ADA DATA` + penghalang |
| Klaim angka di deliverable mana pun tanpa sumber | saat audit | pernyataan tidak dapat diverifikasi |

---

## 8. Butir eskalasi

Ditulis sebagai butir, bukan dikirim langsung ke agent lain (batasan issue).

| # | Butir | Pemilik keputusan | Kenapa tidak bisa kuputuskan |
|---|---|---|---|
| E1 | Apakah gate minggu 7 memakai `idle_ratio` (denominator seluruh waktu aktif) atau `idle_ratio_adj` (tanpa jendela terhenti)? | COO + CTO/CIO (Nathan) | Ini menetapkan apa yang diukur gate operasi; PRD §6 menulis "25% sesi" tetapi §6 juga mengakui rantai paralel sebagai penyerap tunggu |
| E2 | Siapa pemilik tafsir M-09 (hint per sesi) dan siapa yang menetapkan arti "hint gratis rookie" | CEO lewat matriks kepemilikan | Tidak ada fungsi desain di matriks saat ini; bukan domain CMO/CFO/COO |
| E3 | Siapa pemilik tafsir M-13 (rank S/A/B/C) dan siapa menyetujui ambang rubrik §3 | CEO lewat matriks kepemilikan | Sama seperti E2; rubrik `ASUMSI` sampai disetujui |
| E4 | Zona waktu batas hari untuk D1/D7 dan daily case (UTC vs zona mayoritas) | CMO | PRD §12 menetapkan target retensi; batas hari mengubah angka |
| E5 | Apakah "bermain" untuk retensi cukup `session_start`, atau wajib `case_started` | CMO | Mengubah angka D1/D7 secara sistematis |
| E6 | `par_time_s` per varian kasus: siapa menetapkannya dan dari data apa | CTO/CIO + desain | Dibutuhkan M-13; tidak dapat diambil dari PRD |
| E7 | Ambang `IDLE_THRESHOLD_S` final (3/5/10) setelah playtest minggu 7 | CTO/CIO (Nathan) | Instrumen teknis; mengubah semua angka idle historis |

---

## 9. Riwayat perubahan

| Versi | Tanggal | Perubahan | Oleh |
|---|---|---|---|
| 1.0 | 2026-10-04 | Versi awal: 13 metrik, definisi "input bermakna", algoritma idle, rubrik rank, daftar celah | Rani — Data & Metrics Engineer |
