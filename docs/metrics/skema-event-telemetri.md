# Skema Event Telemetri Triangulate

Pemilik: **Rani — Data & Metrics Engineer**. Berlaku sejak: **2026-10-04**. Versi skema: **1**.
Rujukan PRD: §5 (tuduhan & rank), §6 (idle), §8 (lobby/NPC/AFK/rejoin), §9 (Case 0), §15 (telemetri per role), §16 (telemetri dasar = P0).
Kamus metrik yang memakai event ini: `docs/metrics/kamus-metrik.md`.
Skema mesin: `docs/metrics/telemetry-events.schema.json`.

---

## 1. Aturan pengiriman

1. **Server-authoritative.** Semua event diterbitkan server (PRD §15: state kasus, solusi, resep deduksi, dan pemeriksaan tuduhan hanya di server). Client hanya mengirim *intent* (remote), server memvalidasi, lalu menerbitkan event. Tidak ada event yang dikirim langsung oleh client. Konsekuensi: `t_server_ms` selalu ada dan tidak bisa dipalsukan, dan event yang ditolak tidak pernah muncul.
2. **`t_client_ms` hanya diagnostik.** Client boleh melampirkan waktu monotoniknya pada intent; server menyalinnya ke event sebagai `t_client_ms`. Tidak ada metrik yang boleh memakainya.
3. **Urutan tidak dijamin.** Perhitungan memakai `t_server_ms`, bukan urutan kedatangan. Sink tidak boleh mengandalkan urutan.
4. **Batch & flush.** Event dikirim per batch setiap 5 detik atau 50 event, mana lebih dulu. Event terminal (`session_end`, `case_completed`, `accusation_submitted`, `player_left`, `lobby_exit`) di-flush segera.
5. **Dedup.** `event_id` unik (ULID) dan menjadi kunci idempoten di sink. Buffer lokal maksimum 5 menit; event yang lebih tua dibuang, dan jumlah yang dibuang dilaporkan sebagai `telemetry_dropped_count` per sesi supaya metrik kosong bisa dibedakan dari metrik nol.
6. **Satu kali, bukan berulang.** Event yang bersifat "pertama kali" (`first_clue`) dijaga flag-nya di server dan hanya dikirim sekali per `player_role_instance` per sesi.
7. **Tanpa isi bebas.** Tidak ada isi chat, tidak ada teks bebas, tidak ada audio, tidak ada screenshot di event mana pun (PRD §14). Ping wheel dikirim sebagai `ping_id` (enum), Report Card mengirim `node_id`, bukan gambar.

---

## 2. Amplop umum (semua event)

| Properti | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `event_id` | string (ULID) | ya | kunci idempoten |
| `event_name` | string (enum) | ya | lihat §3 |
| `event_version` | int | ya | `1` untuk versi ini |
| `t_server_ms` | int | ya | epoch ms, jam server, UTC — **satu-satunya** waktu untuk metrik |
| `t_client_ms` | int \| null | tidak | monotonik sejak client boot; diagnostik |
| `session_id` | string | ya | instance server |
| `server_id` | string | ya | Roblox JobId |
| `player_id` | string | ya | Roblox UserId; `npc:<role>` untuk NPC; `server` untuk event lingkup server |
| `role` | enum `searcher`\|`handler`\|`director`\|`none` | ya | `none` sebelum `role_assigned` dan untuk event lingkup server |
| `is_npc` | bool | ya | PRD §8 |
| `build_version` | string | ya | mis. `0.1.0+abc123` |

Field lingkup kasus (`case_id`, `case_variant`, `seed`, `mode`, `npc_director`) wajib ada pada `case_started` dan pada setiap event yang terjadi setelah kasus dimulai; event lobby membiarkannya `null`. Join antar-event memakai `session_id` + `player_id`, yang selalu ada.

---

## 3. Event

Kolom **Pengirim** selalu server (§1.1); yang dicatat adalah modul yang menerbitkan. **Pemicu** = kapan dikirim.

### 3.1 Lobby & sesi

#### `session_start`
- Pemicu: pemain masuk ke instance server, setelah profil pemain dimuat. Sekali per `player_session`.
- Properti wajib: `platform` (`mobile`|`desktop`|`console`), `is_first_session` (bool), `days_since_first_session` (int \| null), `agency_id` (string \| null, P1), `region` (string \| null).
- Dipakai oleh: M-01, M-02, M-07, segmentasi mobile (PRD §12).

#### `lobby_enter`
- Pemicu: pemain masuk ke lobby/matchmaking.
- Properti wajib: `mode_preference` (`public`|`private`|`solo`|`duo`), `party_size` (int), `waited_from_ms` (int).
- Dipakai oleh: M-04, M-05.

#### `lobby_exit`
- Pemicu: lobby berakhir — kasus dimulai atau lobby bubar. Sekali per `session_id`.
- Properti wajib: `reason` (`started`|`timeout`|`all_left`|`cancelled`|`error`), `waited_ms` (int), `human_count` (int), `npc_count` (int).
- Dipakai oleh: M-04, M-05.

#### `role_assigned`
- Pemicu: role final ditetapkan untuk pemain (setelah preferensi & prioritas keadilan, PRD §8), dan lagi bila pemain tukar role di lobby.
- Properti wajib: `role`, `assignment_reason` (`preference_1`|`preference_2`|`fairness`|`npc_fill`|`swap`|`rejoin`|`fill`), `preference_1` (enum), `preference_2` (enum), `lobby_wait_ms` (int \| null).
- Dipakai oleh: M-06, M-11, M-12 (semua metrik per role).

#### `case_started`
- Pemicu: state kasus dimulai (semua role terisi, ready check lolos). Sekali per `session_id`. **Titik nol semua durasi.**
- Properti wajib: `case_id`, `case_variant`, `seed`, `mode` (`public`|`private`|`solo`|`duo`|`daily`|`cold_case`|`tutorial`), `npc_director` (bool), `player_count_human` (int), `par_time_s` (int \| null — sampai D2 terpasang).
- Dipakai oleh: M-03, M-04, M-06, M-07, M-08, M-09, M-11, M-12, M-13.

#### `case_completed`
- Pemicu: kasus berakhir — menang, atau Cold Case setelah 3 tuduhan salah (PRD §5). Sekali per `session_id`.
- Properti wajib: `outcome` (`win`|`cold_case`), `accusation_attempts` (int), `hints_used` (int), `case_duration_ms` (int), `rank` (`S`|`A`|`B`|`C`\| null), `rank_rule_version` (int), `rank_board` (`main`|`npc_director`), `key_deductions_done` (int), `contradictions_marked` (int).
- Dipakai oleh: M-03, M-07, M-09, M-13.

#### `case_0_skipped`
- Pemicu: pemain menekan skip pada Case 0 (PRD §9).
- Properti wajib: `is_first_play` (bool).
- Dipakai oleh: M-07 (baris terpisah).

#### `session_paused` / `session_resumed`
- Pemicu: mulai/selesai jendela saat pemain tidak bisa beraksi karena sistem.
- Properti wajib: `pause_reason` (`cutscene`|`tutorial_overlay`|`loading`|`error_recovery`), `scope` (`session`|`role`).
- Dipakai oleh: `idle_ratio_adj` (diagnostik M-06).

#### `player_left`
- Pemicu: pemain keluar dari sesi — sengaja, disconnect, atau kena AFK timeout.
- Properti wajib: `reason` (`voluntary`|`disconnect`|`afk_timeout`|`kicked`), `t_since_case_start_ms` (int \| null), `case_completed` (bool), `rejoin_window_ms` (int \| null — 300000 saat `disconnect`, PRD §8).
- Dipakai oleh: M-08.

#### `player_rejoined`
- Pemicu: pemain kembali ke slot yang ditahan (PRD §8, jendela 3 menit).
- Properti wajib: `t_since_case_start_ms`, `away_duration_ms` (int), `replaced_npc` (bool).
- Dipakai oleh: M-08.

#### `npc_takeover`
- Pemicu: NPC mengambil alih role — AFK 60 detik atau mengisi slot disconnect (PRD §8).
- Properti wajib: `role`, `trigger` (`afk_60s`|`disconnect`), `takeover_player_id`.
- Dipakai oleh: M-06 (pengecualian gate), M-08.

#### `session_end`
- Pemicu: sesi berakhir bagi pemain. Sekali per `player_session`. Event terminal.
- Properti wajib: `end_reason` (`completed`|`left`|`disconnect`|`afk_timeout`|`server_shutdown`|`error`), `session_duration_ms` (int), `case_started` (bool), `case_completed` (bool).
- Dipakai oleh: seluruh metrik berbasis sesi (denominator & pengecualian `error`).

### 3.2 Rantai bukti

#### `object_reported`
- Pemicu: Searcher memeriksa objek dan menekan Report (PRD §4 langkah 2). Sekaligus memicu `first_clue` untuk Searcher.
- Properti wajib: `node_id`, `object_kind`, `is_ambient` (bool — objek ambient §6, bukan objek rantai), `gave_key` (bool), `t_since_case_start_ms`.
- Dipakai oleh: M-11, M-12 (konteks), dan hitungan kontribusi di Case Recap (PRD §11).

#### `clue_card_received`
- Pemicu: Clue Card masuk ke clue board Director. Memicu `first_clue` untuk Director.
- Properti wajib: `node_id`, `source` (`evidence`|`report`), `t_since_case_start_ms`.
- Dipakai oleh: M-11.

#### `first_clue`
- Pemicu: role memperoleh clue pertamanya. Sekali per `player_role_instance` per sesi.
- Properti wajib: `role`, `clue_kind` (`object`|`evidence`|`clue_card`), `node_id`, `t_since_case_start_ms`.
- Pemicu per role (mengikat, sama dengan kamus §2.11): Searcher = `object_reported` pertama; Handler = `evidence_completed` pertama; Director = `clue_card_received` pertama.
- Dipakai oleh: M-11.

#### `evidence_completed`
- Pemicu: Handler menyelesaikan satu puzzle bukti (PRD §4 langkah 3). Memicu `first_clue` untuk Handler bila yang pertama.
- Properti wajib: `node_id`, `puzzle_type` (`torn_doc`|`timeline`|`cipher`), `duration_ms` (int), `attempt_count` (int), `was_npc` (bool), `assisted_by` (enum \| null — Director mengambil alih puzzle di mode 2 pemain, PRD §8), `t_since_case_start_ms` (int — wajib agar pemicu `first_clue` Handler dapat diverifikasi dari event itu sendiri, bukan dari urutan kedatangan).
- Dipakai oleh: M-11, Case Recap.

#### `deduction_made`
- Pemicu: Director menggabungkan Clue Card dan server menyatakan resepnya sah (PRD §4 langkah 5).
- Properti wajib: `deduction_id`, `input_node_ids` (array string, ≥ 2), `is_key_deduction` (bool — masuk gerbang N, PRD §5), `hint_assisted` (bool), `t_since_case_start_ms`.
- Dipakai oleh: M-03 (gerbang), M-12, M-13.

#### `contradiction_marked`
- Pemicu: Director menandai kontradiksi antara pernyataan dan bukti (PRD §4).
- Properti wajib: `statement_id`, `contradicted_by_node_id`, `is_correct` (bool — server tahu kebenarannya, PRD §15), `t_since_case_start_ms`.
- Dipakai oleh: M-03 (syarat gerbang), Case Recap.

### 3.3 Keputusan

#### `accusation_submitted`
- Pemicu: Director mengirim form tuduhan. Maksimum 3 per sesi (PRD §5). Event terminal, flush segera.
- Properti wajib: `attempt_no` (1-3), `culprit_correct` (bool), `motive_correct` (bool), `method_correct` (bool), `correct_fields_count` (0-3), `confirm_role` (enum — role yang mengonfirmasi, PRD §3), `gate_open` (bool), `key_deductions_done` (int), `hints_used_at_submit` (int), `t_since_case_start_ms`.
- Catatan: `correct_fields_count` dihitung **server**, karena client hanya boleh menerima "X dari 3 benar" tanpa menyebut field mana (PRD §5). `culprit_correct`/`motive_correct`/`method_correct` tidak boleh direplikasi ke client sebelum kasus berakhir.
- Dipakai oleh: M-12, M-13.

#### `hint_used`
- Pemicu: hint benar-benar terpakai setelah persetujuan 2 role (PRD §8).
- Properti wajib: `requester_role` (enum), `approver_role` (enum), `hint_id`, `hint_scope` (`target`|`deduction`|`statement`), `hint_source` (`free_quota`|`rookie`|`progress`), `remaining_quota` (int), `t_since_case_start_ms`.
- Catatan: hint gratis rookie mode (PRD §9) tetap `hint_used` dengan `hint_source = rookie`; dilaporkan terpisah dari permintaan pemain.
- Dipakai oleh: M-09, M-13.

### 3.4 Idle (instrumen M-06)

#### `idle_start`
- Pemicu: run bucket INACTIVE mencapai `IDLE_THRESHOLD_S`. Dikirim **setelah** ambang tercapai, tetapi `t_server_ms` yang dibawa adalah waktu bucket INACTIVE pertama — sehingga urutan pengiriman tidak mengubah angka.
- Properti wajib: `role`, `idle_threshold_ms` (int), `t_since_case_start_ms` (dihitung dari waktu run mulai, bukan waktu kirim).
- Dipakai oleh: M-06.

#### `idle_end`
- Pemicu: run idle berakhir — input bermakna, NPC takeover, pemain keluar, atau sesi berakhir.
- Properti wajib: `role`, `idle_duration_ms` (int), `ended_by` (`input`|`npc_takeover`|`player_left`|`session_end`|`paused`), `t_since_case_start_ms`.
- Dipakai oleh: M-06.

Definisi "input bermakna", ambang, dan algoritma bucket ada di `kamus-metrik.md` §1 dan mengikat; skema ini hanya mengangkut hasilnya.

---

## 4. Matriks event × role

`S` = Searcher, `H` = Handler, `D` = Director, `Srv` = lingkup server/lobby.

| Event | S | H | D | Srv | P0/P1 |
|---|---|---|---|---|---|
| `session_start` | • | • | • | • | P0 |
| `lobby_enter` | • | • | • | • | P0 |
| `lobby_exit` | | | | • | P0 |
| `role_assigned` | • | • | • | | P0 |
| `case_started` | | | | • | P0 |
| `object_reported` | • | | | | P0 |
| `clue_card_received` | | | • | | P0 |
| `first_clue` | • | • | • | | P0 |
| `evidence_completed` | | • | | | P0 |
| `deduction_made` | | | • | | P0 |
| `contradiction_marked` | | | • | | P0 |
| `accusation_submitted` | | | • | | P0 |
| `hint_used` | • | • | • | | P0 |
| `idle_start` / `idle_end` | • | • | • | | P0 |
| `case_completed` | | | | • | P0 |
| `session_end` | • | • | • | • | P0 |
| `case_0_skipped` | • | • | • | | P0 |
| `player_left` | • | • | • | | P0 |
| `player_rejoined` | • | • | • | | P0 |
| `npc_takeover` | • | • | • | | P0 |
| `session_paused` / `session_resumed` | • | • | • | • | P1 |
| `deduction_made.hint_assisted` | | | • | | P1 |
| `case_completed.rank*` | | | | • | P1 (leaderboard & rank per role, PRD §16) |

Catatan P0/P1: PRD §16 menaruh "telemetri dasar" di MVP. Set yang ditandai P0 adalah minimum agar metrik §12 punya sumber; `rank` dan `session_paused` menyusul karena rank per role dan leaderboard ada di P1 (PRD §16), dan `idle_ratio_adj` hanya diagnostik.

---

## 5. Aturan integritas

| Aturan | Alasan |
|---|---|
| Setiap event punya `session_id` + `player_id` + `t_server_ms` | join & agregasi; tanpa salah satunya metrik tidak reproducible |
| `is_npc` di setiap event | PRD §8; tanpa ini NPC mengkontaminasi idle, completion, dan retensi |
| `case_id`/`case_variant` sejak `case_started` | memisahkan Case 0, story, daily, cold case (PRD §9, §10) |
| `npc_director` di `case_started` | memisahkan papan rank (PRD §8) |
| Tidak ada isi bebas / chat / gambar | PRD §14 |
| `event_version` di setiap event | skema berubah tanpa memecah data lama |
| `rank_rule_version` di `case_completed` | rank historis tidak berubah saat rubrik direvisi |

Perubahan skema: penambahan properti opsional = versi minor, tidak mengubah `event_version`. Perubahan arti properti, penghapusan, atau perubahan enum = kenaikan `event_version` + revisi dokumen ini + catatan di kamus metrik (karena dapat mengubah angka historis).
