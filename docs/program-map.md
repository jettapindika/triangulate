# Peta Program Triangulate — konsolidasi 22 workstream EXTA-31 dan verifikasi bukti

Pemilik dokumen: **Mika — Chief of Staff (EXTA-52)**. Disusun 2026-10-04 dari 22 komentar hasil workstream EXTA-32…EXTA-54, 17 pull request di `jettapindika/triangulate`, dan pengukuran ulang langsung terhadap repo. Rujukan: PRD v0.2 (`docs/prd-v0.2.md`) §4–§19.

Dokumen ini menjawab satu pertanyaan: **dari seluruh yang dikerjakan hari ini, mana yang benar-benar sudah ada, mana yang masih berupa klaim, dan apa yang menghambat.** Setiap baris menunjuk bukti yang bisa dibuka. Klaim "selesai" tanpa artefak yang bisa diverifikasi dicatat sebagai celah, bukan diterima.

---

## 0. Cara membaca dokumen ini

| Istilah | Arti |
|---|---|
| **Terverifikasi** | Saya menjalankan atau membuka artefaknya sendiri pada 2026-10-04; hasilnya ada di §6 |
| **Ada, belum ditinjau** | Berkas/PR ada di repo dan bisa dibuka, tetapi belum ada peninjau selain penulisnya |
| **Komentar saja** | Hasil hanya hidup sebagai komentar issue (mungkin dengan lampiran), tidak ada berkas di repo |
| **Celah** | Dijanjikan, tetapi buktinya tidak ada — daftar di §3 |

Bentuk rujukan komentar: `EXTA-<n>#<comment-id>`. Semua id itu adalah komentar akar ber-`author=agent`, terbit 2026-10-04.

Temuan yang mengubah gambaran dibanding laporan tiap workstream:

1. **Rantai implementasi minggu 2–8 sudah dibuat** (EXTA-55…EXTA-61, `in_progress`, pemilik Nathan) — klaim lama "minggu 2–8 tidak punya issue build" (EXTA-46 §2, EXTA-51 temuan 1) sudah **tidak berlaku**.
2. **Tetapi rantai itu belum menghasilkan apa pun, dan penyebabnya satu: environment.** Ketujuh issue gagal di langkah `prepare execution environment` (`execenv: local_directory "/Users/mac/Documents/Roblox" is not a git repository, but its project resource is set to execution_mode=worktree`). Ini penghambat nomor satu sekarang, dan bukan penghambat teknis produk — penghambat konfigurasi.
3. **CI sudah mendarat tetapi tetap tidak memeriksa apa pun** — repo variable `CI_ENABLED` kosong, `main` tidak dilindungi, keenam run terakhir `skipped` (§6).
4. **Data kasus dari EXTA-38 tidak lolos validator milik EXTA-33** — 29 galat, dua dari dua berkas gagal (§2.4, §6).

---

## 1. Peta program

Kolom **Status** memakai tiga nilai di §0, bukan status board. Status board per 2026-10-04: seluruh EXTA-32…EXTA-54 `done` kecuali EXTA-52 (issue ini), dan EXTA-55…EXTA-61 `in_progress`.

### 1a. Rekayasa dan infrastruktur

| Tujuan (PRD) | Workstream | Pemilik | Deliverable | Status | Bukti |
|---|---|---|---|---|---|
| §15 arsitektur server-authoritative, §17 rencana spike | EXTA-32 | Nathan | `docs/arsitektur.md`, `docs/mvp-notes.md`, `docs/spike-minggu-0.md`, scaffold `src/` + `tests/` | Ada, belum ditinjau | PR #11 (merge `01783b6`, 11:17:37Z) · EXTA-32#01a10684-2db2-7952-bcf2-68d1c3de32d5 |
| §4 Clue Graph, §5 win condition, §10 kasus sebagai data | EXTA-33 | Nathan | `schema/case.schema.json`, `docs/case-schema.md`, `tools/validate_case.luau`, `tests/case-schema.spec.luau` | **Terverifikasi** — validator dijalankan, `gallery_01.json` lulus | PR #10 (merge `59e0ff7`, 11:16:48Z) · EXTA-33#01a1067f-fa8f-7cdf-b6ba-004bb7376b26 · §6 |
| §15 CI/CD, environment, secret, backup & restore | EXTA-34 | Devan | `.github/workflows/ci.yml`, `rokit.toml`, `selene.toml`, `.luaurc`, `docs/ci/01…06` | **Sebagian** — berkasnya ada dan aktif di repo, tetapi CI mati by design (`CI_ENABLED` kosong) | PR #13 (merge `d0e8489`, 11:51:08Z) · EXTA-34#01a106bf-ddb8-7116-a35d-91845fce08ae · §6 |
| §12 metrik, §17 gate roadmap | EXTA-35 | Bima | `docs/automation-spec.md`, `docs/autopilot-prompt-laporan-metrik.md`, `docs/wakeup-instruksi-gate-roadmap.md`, `tools/metric-report.py`, `tools/roadmap-gate.sh`, `docs/metrics.json`, `docs/roadmap.json` | Ada, belum ditinjau — **dan belum ada autopilot/wakeup yang dibuat** | PR #8 (merge `600e168`, 12:04:39Z) · EXTA-35#01a1067c-9c7a-75c5-a812-0836600d0648 |
| §12 kamus metrik, §15 skema event telemetri | EXTA-36 | Rani | `docs/metrics/kamus-metrik.md`, `docs/metrics/skema-event-telemetri.md`, `docs/metrics/telemetry-events.schema.json`, `docs/metrics/fixtures/` | Ada, belum ditinjau — 13 dari 13 metrik M berstatus `BLOKIR` | PR #5 (merge `2b04fde`, 12:01:57Z) · EXTA-36#01a10671-9222-7426-8b9a-00700341993f |
| §12, §17 pengukuran & audit handoff | EXTA-37 | Dewi | Rencana pengukuran + baseline + audit H1–H13 | **Komentar saja** — tidak ada berkas repo, tidak ada PR | EXTA-37#01a10674-7714-7c91-949e-5e7d55bd5730 |
| §12, §15 telemetri di build pertama | EXTA-53 | Nathan | Meja puzzle top-down drag-and-snap, `tests/gate-minggu-0.spec.luau`, `tools/spike-s02-protokol.luau` | Ada, belum ditinjau — gate minggu 0 lulus di semua yang bisa diukur mesin; **pengukuran perangkat tidak ada** | PR #16 (merge `80b35e9`, 13:29:37Z) · **PR #17 masih OPEN** · EXTA-53#01a1071d-f820-73d8-88b0-cdefd55e4245 |
| §4, §5, §10, §17 integrasi stage 1 | EXTA-54 | Nathan | `docs/integrasi-stage-1.md` + penyatuan skema/loader ke `main` | Ada, belum ditinjau — dua PR mendarat | PR #14 (merge `d932dc0`, 11:16:59Z) · PR #15 (merge `c25d062`, 11:21:59Z) · EXTA-54#01a106a7-9758-73db-bb74-1be2b7de426f |

### 1b. Konten, desain, riset

| Tujuan (PRD) | Workstream | Pemilik | Deliverable | Status | Bukti |
|---|---|---|---|---|---|
| §4, §7, §9, §10 konten kasus + copy | EXTA-38 | Nadia | `cases/case_00.json`, `cases/kersana_01.json`, `docs/content/copy-komunikasi.md`, `tools/validate_cases.py` | **Celah** — PR #6 OPEN, berkasnya tidak ada di `main`, dan **29 galat** terhadap validator kanonik | PR #6 (OPEN) · EXTA-38#01a10673-6231-733d-9163-397554fde6c2 · §2.4, §6 |
| §13, §14, §15, §19 art direction & mockup | EXTA-39 | Sari | `docs/art/art-bible.md`, `docs/art/puzzle-style.md`, `docs/art/ui-spec.md`, `docs/art/palette.json`, `docs/art/tokens.css`, `docs/art/cosmetic-assets.md`, `docs/art/mockups/` (11 PNG — 9 mockup + 2 sampel gaya — plus HTML dan skrip verifikasi) | Ada, belum ditinjau | PR #12 (merge `9e7a806`, 12:05:21Z) · EXTA-39#01a10699-e7a4-711b-a06e-244796122f1b |
| §12–§15 riset benchmark, rating, texture, ekonomi Robux | EXTA-40 | Damar | Riset bertanggal, seluruh sumber diakses 2026-10-04 | **Komentar saja** — tidak ada berkas repo, tidak ada PR | EXTA-40#01a10679-8874-7008-b4f6-dda511f61791 |
| §11–§14 positioning, ICP, store page, akuisisi | EXTA-41 | Clara | `docs/marketing/positioning-icp-store-page-akuisisi.md` | Ada, belum ditinjau | PR #2 (merge `a4a5fb7`, 12:01:50Z) · EXTA-41#01a1066f-4fff-79a9-8a89-eebc2f30e8ee |

### 1c. Keuangan, risiko, operasi

| Tujuan (PRD) | Workstream | Pemilik | Deliverable | Status | Bukti |
|---|---|---|---|---|---|
| §12, §13 model pendapatan & unit economics | EXTA-42 | Michelle | Model per 1.000 DAU + tangga skala | **Komentar saja** — tidak ada berkas repo, tidak ada PR | EXTA-42#01a1066f-d1fb-7111-8c21-63d0de039d2f |
| §10, §13, §17 biaya build 8 minggu & runway | EXTA-43 | Ayu | Tiga skenario biaya + runway pasca rilis | **Komentar saja** — tidak ada berkas repo, tidak ada PR | EXTA-43#01a1066f-c767-7367-a61e-af791b927966 |
| §18 register risiko & ambang belanja | EXTA-44 | Bayu | `docs/risk-register-triangulate.md`, `docs/ambang-belanja-triangulate.md` | Ada, belum ditinjau | PR #3 (merge `f613746`, 12:01:54Z) · EXTA-44#01a10671-0b34-7b2a-8288-c935d4ba2b7d |
| §10, §13 buku besar pengeluaran | EXTA-45 | Dimas | `docs/buku-besar/buku-besar.md`, `docs/buku-besar/buku-besar-2026-10.csv` | Ada, belum ditinjau — **CSV masih header-only, 0 baris realisasi** | PR #1 (merge `c01163c`, 12:01:46Z) · EXTA-45#01a1066d-89e2-7dd3-92d6-d4814e781634 |
| §16–§18 operating plan, matriks kepemilikan, playtest | EXTA-46 | Rafael | `operating-plan-triangulate.md` (±29 KB, 7 bagian) | **Komentar saja** — lampiran komentar, tidak ada berkas repo, tidak ada PR | EXTA-46#01a1066f-1544-7259-bdc3-c6539d15aa8c |
| §9, §10, §17 SOP produksi & playtest | EXTA-47 | Bagas | `docs/sop/README.md`, `sop-01…sop-05`, `lampiran-a-instrumen-playtest.md` | Ada, belum ditinjau | PR #4 (merge `c36a171`, 12:03:24Z) · EXTA-47#01a10672-6d89-7ba1-ac9d-30d5fd9e589f |
| §19 log keputusan & decision request | EXTA-48 | Rangga | `docs/decision-log.md` (8 entri, DR-01…DR-03, G-01…G-18) | Ada, belum ditinjau | PR #7 (merge `d9df547`, 12:02:00Z) · EXTA-48#01a10676-d686-7788-a5bc-51e8d6666ac3 |

### 1d. Arah dan penyelarasan

| Tujuan | Workstream | Pemilik | Deliverable | Status | Bukti |
|---|---|---|---|---|---|
| Misi, 3 sasaran 90 hari, hak keputusan, kadensi | EXTA-49 | Kirana | `docs/narasi/narasi-triangulate.md` (S1–S3, horizon 5 Okt 2026–2 Jan 2027) | Ada, belum ditinjau | PR #9 (merge `573d3b7`, 12:02:03Z) · EXTA-49#01a1067c-a20c-7969-9966-f9cf72b5ffe4 |
| Peta key result 90 hari | EXTA-50 | Wisnu | Peta KR lapis Exta → keluaran workstream | **Komentar saja** — tidak ada berkas repo, tidak ada PR | EXTA-50#01a1066d-47e2-7bdc-855d-99ace8825020 |
| Peta dependensi & register tabrakan | EXTA-51 | Mika | `peta-dependensi-triangulate.md` (±29 KB, 6 bagian), register T-01…T-12 | **Komentar saja** — lampiran komentar; berkasnya tidak ada di repo maupun di checkout lokal | EXTA-51#01a1067b-4a55-7da9-bfc3-496d7724f79c |
| Konsolidasi & verifikasi bukti | **EXTA-52** | Mika | **Dokumen ini** | Deliverable | PR yang menyertakan berkas ini |

### 1e. Rantai implementasi minggu 2–8 (dibuat setelah workstream stage 1)

Ketujuhnya dibuat 10:49–10:51Z, pemilik Nathan — CTO/CIO, status `in_progress`.

| Issue | Minggu | Target (PRD §17) | Status nyata |
|---|---|---|---|
| EXTA-55 | 2 | Loader kasus dari data, lokasi, objek + kunci, rantai A→bukti end to end | Diblokir environment |
| EXTA-56 | 3 | Director UI: clue board, kombinasi, kontradiksi, pinpoint | Diblokir environment |
| EXTA-57 | 4 | Pemisahan info per role, form tuduhan, batas 3 percobaan | Diblokir environment |
| EXTA-58 | 5 | Lobby, preferensi role, NPC Searcher/Handler, AFK, rejoin | Diblokir environment |
| EXTA-59 | 6 | Case 0, story case #1 + varian, ping wheel final | Diblokir environment |
| EXTA-60 | 7 | Playtest 3 pemain nyata (mobile), tuning idle time | Diblokir environment |
| EXTA-61 | 8 | Polish, kuesioner rating, rilis | Diblokir environment |

Bukti blokir (identik di ketujuhnya): komentar `prepare execution environment` 13:45:23Z, dan di EXTA-55 dua tambahan 13:45:54Z dan 13:46:43Z dengan pesan `repository "/Users/mac/Documents/Roblox" has no commit to branch from (worktree mode needs at least one commit)`. Tidak ada satu pun yang punya komentar hasil.

---

## 2. Kontradiksi antar workstream dan putusannya

### 2.1 Definisi metrik — Rani (EXTA-36) vs Dewi (EXTA-37)

**Bertentangan pada:** siapa yang menetapkan definisi, siapa yang mengukur, dan siapa yang memutuskan lulus/tidak.

- EXTA-36 menyerahkan kamus metrik + skema event sebagai definisi kanonik.
- EXTA-37 menyerahkan rencana pengukuran yang memisahkan "pemilik angka" dari "penarik angka", dan menyatakan 0 dari 8 metrik §12 bisa dihitung hari ini.
- PRD §12 hanya menetapkan target, tidak menetapkan siapa yang memiliki definisinya.

**Putusan: Rani menetapkan definisi, Dewi memverifikasi angka, Rafael memutuskan lulus/tidak, Bima mengotomasi penariknya.** Dasar: tiga sumber independen sampai pada pembagian yang sama — EXTA-51 register T-01, EXTA-37 §1 ("satu pemilik per baris" dengan kolom bukti), dan EXTA-46 §3 (pemisahan tugas pengukuran). Ketika tiga workstream yang tidak saling membaca menetapkan pembagian identik, itu bukan kebetulan, itu pembagian yang wajar.

**Yang harus berubah:** tidak ada perubahan artefak. Yang perlu ditetapkan owner adalah satu hal yang tidak diputuskan siapa pun: **ambang `IDLE_THRESHOLD_S = 5` dan `BUCKET_MS = 1000` masih `ASUMSI`** (EXTA-36), dan ambang itu menentukan apakah gate minggu 7 "idle < 25%" lulus atau tidak.

### 2.2 Kepemilikan CI — Nathan (EXTA-32/33) vs Devan (EXTA-34)

**Bertentangan pada:** siapa yang berhak menutup pipeline. EXTA-34 menulis `.github/workflows/ci.yml` yang menganalisis `src/` milik EXTA-32.

**Ini bukan tabrakan, ini prasyarat — dan urutannya salah.** `.github/workflows/ci.yml` memuat langkah `Analisis tipe — luau-lsp` dengan `continue-on-error: true` dan komentar yang menyebut **8 galat tipe nyata** di `src/` milik EXTA-32. Artinya: kalau `CI_ENABLED` dinyalakan hari ini, CI berjalan hijau **sambil** membawa 8 galat tipe yang tidak diperiksa. Itu hijau palsu, dan lebih berbahaya daripada CI yang mati, karena orang akan mempercayainya.

**Putusan: bereskan 8 galat tipe lebih dulu, baru nyalakan CI.** Dasar: `docs/ci/03-pipeline-ci.md` §3.5 memuat kedelapan galat satu per satu (barisnya, misalnya `src/server/NPCController.luau:53,21` dan `src/server/init.server.luau:135,5`) beserta **tiga syarat melepas `continue-on-error`**: (1) kedelapan galat beres di `src/`; (2) `luau-lsp analyze … src` keluar exit 0 pada `main`; (3) daftar `globals` di `.luaurc` dipangkas dari nama API Roblox, karena mendeklarasikannya ulang sebagai global membuatnya `any` dan mematikan pemeriksaan tipe Roblox (§2.1 dokumen itu). Nathan pemilik `src/`, Devan pemilik pipeline; yang salah bukan pembagiannya, melainkan rencana menyalakan CI sebelum prasyaratnya selesai.

**Yang harus berubah:** (1) Nathan menutup 8 galat tipe di `src/`; (2) Devan memangkas `globals` di `.luaurc`; (3) `luau-lsp analyze` keluar exit 0; (4) baru lepas `continue-on-error` dan `gh variable set CI_ENABLED --body true`.

### 2.3 Cakupan MVP — scaffold Nathan (EXTA-32) vs PRD §16

**Bertentangan pada:** apakah yang sudah dibangun cocok dengan daftar MVP P0 PRD §16.

**Putusan: scaffold tidak menyimpang dari §16; yang menyimpang adalah asumsi bahwa §16 bisa selesai dalam 8 minggu.** PRD §16 P0 memuat meja puzzle, satu lokasi, clue board Director, pemisahan info per role, lobby + NPC + AFK + rejoin, ping wheel, Case 0 + satu story case, dan telemetri. Per 2026-10-04 yang **berjalan end to end** baru satu tipe puzzle (`torn_doc`; EXTA-53 §7) dan satu kasus (`gallery_01.json`). Sisa P0 seluruhnya ada di EXTA-55…EXTA-61 yang belum mulai.

**Yang harus berubah:** tidak ada pemotongan scope yang saya usulkan — memotong §16 bukan wewenang saya. Yang perlu diputuskan owner: apakah rantai minggu 2–8 tetap 7 minggu berurutan, atau diparalelkan. Dengan satu pelaksana (Nathan) dan tujuh issue berurutan, jalur kritisnya adalah **kapasitas**, bukan jadwal (§4).

### 2.4 Skema data kasus — EXTA-38 vs EXTA-33/EXTA-54

**Bertentangan pada:** bentuk data kasus. Ini kontradiksi dengan bukti terkuat di dokumen ini.

Data EXTA-38 memakai `nodes[].type = "clue"`; skema kanonik hanya mengenal `object`, `evidence`, `clue_card`, `deduction`. Data EXTA-38 tidak punya `statements`, tidak punya `briefing`, tidak punya `variants[].method`; ketiganya **wajib** di `schema/case.schema.json`.

Menjalankan validator kanonik (`tools/validate_case.luau`, milik EXTA-33, sudah di `main`) terhadap kedua berkas PR #6:

```
$ lune run tools/validate_case.luau -- cases/case_00.json cases/kersana_01.json
file: cases/case_00.json      → 10 galat
file: cases/kersana_01.json   → 19 galat
HASIL: 2 dari 2 file gagal.
```

Galat yang paling menentukan, apa adanya dari validator: `nodes[18].type: ... (ditemukan "clue")` · `nodes[19..24].supports: Node deduction wajib punya 'supports'` · `statements: 'statements' wajib ada (PRD §4)` · `briefing: 'briefing' wajib ada untuk searcher, handler, dan director` · `variants[1].method`, `variants[2].method`, `variants[1].variant_id`, `variants[2].variant_id`.

**Putusan: skema EXTA-33/EXTA-54 yang berlaku, karena (a) ia yang ada di `main`, (b) ia yang punya validator yang berjalan, dan (c) PRD §4 menyebut pernyataan saksi dan kontradiksi sebagai bagian kasus, sehingga `statements` memang wajib.** EXTA-38 menulis datanya terhadap skema yang belum mendarat dan menyerahkan validatornya sendiri (`tools/validate_cases.py`), yang tidak ada di `main` dan tidak dipakai siapa pun. Dua validator untuk satu format adalah akar masalahnya (EXTA-51 register T-09).

**Yang harus berubah:** EXTA-38 menulis ulang kedua berkas kasus terhadap `schema/case.schema.json` dan menghapus `tools/validate_cases.py`. Ini pekerjaan nyata, bukan penyesuaian kosmetik — struktur node, statements, dan briefing semuanya berubah. Selama itu belum dikerjakan, **Case 0 dan story case #1 tidak ada**, dan gate minggu 6 (EXTA-59) tidak punya bahan.

### 2.5 Gerbang deduksi Case 0 — PRD §5 vs data EXTA-38

**Bertentangan pada:** PRD §5 menetapkan N = 2 dari 3 untuk Case 0 dengan rumus ≈65% dibulatkan ke atas. Data EXTA-38 memakai N = 2 dari 3, dan EXTA-38 sendiri mengangkat ini sebagai pertanyaan. EXTA-54 mengangkat varian yang sama untuk daily case: 3 dari 5 menyimpang dari rumus 65% (65% × 5 = 3,25 → 4).

**Putusan: rumus 65% yang berlaku sebagai aturan umum; angka eksplisit PRD menang hanya di tempat PRD menyebutnya eksplisit.** Dasar: PRD §5 menulis angka N secara literal untuk tiga kasus (4 dari 6 standar, 3 dari 5 daily, 2 dari 3 Case 0) **dan** menyebut rumus 65% sebagai cara menurunkannya. Di mana keduanya berbeda (daily case), angka literal adalah keputusan penulis PRD yang sadar, bukan hasil pembulatan. EXTA-54 mengambil sikap yang sama.

**Yang harus berubah:** tidak ada. Yang perlu dicatat: rumus 65% tidak boleh dipakai untuk menurunkan N kasus baru tanpa persetujuan owner, karena ia hanya deskripsi kasar, bukan generator.

### 2.6 Gutter sheet puzzle — EXTA-39 vs EXTA-53

**Bertentangan pada:** lebar bantalan tepi sel. `docs/spike-minggu-0-hasil.md` §2 (gaya A dan B) memakai **gutter 1 px**. EXTA-53 mengukur bahwa penutupan penuh bleeding butuh **2 px untuk penurunan 2×, 4 px untuk 4×, dan 6 px untuk 4×-lalu-diperbesar**, dan menyatakan `docs/art/puzzle-style.md` menetapkan 1 px.

**Putusan: catatan EXTA-53 yang berlaku, 1 px tidak cukup — tetapi ia belum final.** Dasar: gutter 1 px memotong puncak bleeding 22–46% dan **tidak menghapusnya** (EXTA-53, angka `spike-minggu-0-hasil.md` §2 tabel gutter). Bleeding di batas sel adalah cacat yang terlihat pemain di meja puzzle, sedangkan biaya menaikkan gutter ke 2–6 px hanya kehilangan beberapa piksel tepi per sel. Pengukuran ini berasal dari resampler PIL, **bukan sampler Roblox**, jadi angkanya belum dikonfirmasi di runtime sesungguhnya — itu sebabnya putusannya "berlaku sebagai catatan, belum sebagai spesifikasi".

**Yang harus berubah:** saat art pertama ada (EXTA-59), uji gutter 4–6 px di Studio sebelum sheet diproduksi massal. Kalau ternyata 1 px sudah cukup di sampler Roblox, catatan ini ditutup dengan angka perangkat, bukan dengan argumen.

### 2.7 CI yang ada vs klaim bahwa ada merge gate

**Bertentangan pada:** apakah PR diperiksa otomatis. Sejumlah dokumen (`docs/ci/01-inventaris-repo-environment.md` §3, `docs/ci/05-backup-restore.md`) menyebut "check di PR". Kenyataannya: **`gh variable list` kosong, `main` tidak dilindungi, keenam run terakhir `skipped`.**

**Putusan: tidak ada merge gate hari ini, dan tidak pernah ada.** Dasar: pengukuran §6. `.github/workflows/ci.yml` memasang guard `if: vars.CI_ENABLED == 'true'` di tingkat job (empat job: `lint`, `analyze`, `test`, `validate-case`), dan variable itu tidak pernah diset. Ditambah `main` tidak punya branch protection, sehingga tidak ada required check yang bisa memblokir merge meski CI hidup.

**Yang harus berubah:** ini keputusan owner (§5 K-1). Selama `main` tidak dilindungi dan `CI_ENABLED` kosong, **15 PR hari ini bisa merge tanpa satu pun pemeriksaan otomatis** — dan memang begitulah yang terjadi.

### 2.8 Klaim lingkungan EXTA-53 vs kenyataan repo

**Bertentangan pada:** `docs/spike-minggu-0-hasil.md` §7 menyatakan "Pemeriksaan visual gambar tidak dapat dilakukan di lingkungan ini (tidak ada model visi, tidak ada Studio)". PR #17 menggantinya menjadi "Pemeriksaan mata di perangkat tidak dapat dilakukan di lingkungan ini". Koreksinya benar dan penting: artefak spike memang ada (`/Users/mac/Documents/Roblox/.probe/s01_out/`, 20+ PNG + `s01_hasil.json`), tetapi berada **di luar repo** dan pemeriksaannya butuh perangkat.

**Putusan: koreksi PR #17 yang berlaku.** Dasar: teks lama menyiratkan gambar tidak ada; kenyataannya gambar ada dan hanya tidak bisa diperiksa mata dari workstation. Perbedaan ini menentukan apakah gate minggu 0 lulus atau tidak.

**Yang harus berubah:** **merge PR #17** (satu berkas, +5/−5, hanya §7). Ia tertinggal karena commit `2800532` tidak ikut dalam merge PR #16 (`9edfced`). Ini pekerjaan lima detik yang menahan satu klaim salah tetap beredar di repo.

### 2.9 `selene.toml` masih memuat angka yang EXTA-34 nyatakan tidak bisa direproduksi

**Bertentangan pada:** `selene.toml:21` di `main` menyatakan `std = "roblox" -> 33 errors, exit 1`. EXTA-34 menyatakan angka "33 error" **tidak bisa direproduksi**, dan menunjukkan tabel bahwa hasilnya bergantung pada versi selene yang menghasilkan `roblox.yml` (selene 0.28.0 → 53 galat; selene 0.32.0 → 0 galat).

**Putusan: angka di `selene.toml` menyesatkan dan harus diperbaiki.** Dasar: EXTA-34 adalah yang mengukur; `selene.toml` adalah yang mengklaim. Kesimpulan operasionalnya (`std = "luau+roblox"`, `luau` di depan) tetap benar dan tidak berubah — yang salah hanya baris pembenarannya.

**Yang harus berubah:** perbaiki komentar di `selene.toml` agar menyebut ketergantungan versi, bukan angka tunggal. Ini milik EXTA-34 (Devan) dan berada di luar `docs/program-map.md`; saya catat, tidak saya sentuh.

### 2.10 `docs/ci/05-backup-restore.md` bertentangan dengan dirinya sendiri

**Bertentangan pada:** baris 11 dan 38 menyatakan `data/cases/` **sudah ada di repo** (`data/cases/gallery_01.json`, mendarat bersama PR #10) dan sudah ikut ter-restore. Baris 258 masih menyatakan "Belum ada di repo; lokasi `data/cases/` masih `ASUMSI`".

**Putusan: baris 11/38 yang berlaku, baris 258 kedaluwarsa.** Dasar: diverifikasi langsung — `git ls-tree origin/main` memuat `data/cases/gallery_01.json` dan `data/cases/README.md`; validator atas berkas itu lulus (§6). Baris 258 adalah sisa draf sebelum PR #10 mendarat.

**Yang harus berubah:** hapus/perbaiki baris 258. Milik Devan (EXTA-34).

### 2.11 `docs/ci/01-inventaris-repo-environment.md` memotret PR #13 sebagai OPEN padahal sudah merge

**Bertentangan pada:** baris 91 menyatakan branch Devan → `#13 OPEN`. Kenyataannya PR #13 merge `d0e8489` pada 11:51:08Z.

**Putusan: snapshot itu kedaluwarsa, bukan salah.** Dasar: dokumen itu memang potret pada satu waktu, dan menyebut dirinya begitu. Tidak ada tindakan wajib.

**Yang harus berubah:** tidak ada. Dicatat supaya pembaca berikutnya tidak mengutip "CI belum merge" dari baris itu.

### 2.12 EXTA-51 T-06: `par_time_s` tidak ada di skema kasus

**Bertentangan pada:** `docs/metrics/kamus-metrik.md` menuntut `par_time_s` per (`case_id`, `case_variant`) sebagai syarat rubrik rank M-13, sedangkan `schema/case.schema.json` tidak memuatnya.

**Putusan: EXTA-36 yang benar, skema yang kurang.** Dasar: diverifikasi — `par_time_s` muncul di `docs/metrics/kamus-metrik.md`, `docs/metrics/skema-event-telemetri.md`, dan `docs/metrics/telemetry-events.schema.json`, tetapi **tidak di `schema/case.schema.json`** maupun `data/cases/gallery_01.json`. Akibatnya M-13 (rank) dan D2 berstatus `BLOKIR`.

**Yang harus berubah:** tambahkan `par_time_s` per varian ke `schema/case.schema.json` + `data/cases/gallery_01.json`. Milik EXTA-33 (Nathan). Tanpa ini, PRD §5 "Rank S/A/B/C dari waktu" tidak bisa dihitung sama sekali.

### 2.13 Satu nama, dua `CaseLoader`

**Bertentangan pada:** `src/shared/case/CaseLoader.luau` (murni, dipakai CLI dan `projectForRole`) dan `src/server/CaseLoader.luau` (menyentuh `Instance`) hidup bersamaan; logika pemilihan varian ada di dua tempat (`selectVariant` vs `pickVariant`).

**Putusan: ini utang teknis, bukan kontradiksi desain — dan EXTA-54 sendiri sudah menamainya "utang nomor satu".** Dasar: EXTA-54 §"Temuan" menyatakan loader ganda harus dibereskan **sebelum minggu 2** saat loader dipanggil dari loop permainan. Minggu 2 sudah dibuka (EXTA-55) dan gagal di environment, jadi utang ini belum sempat menagih — tetapi jendelanya menutup begitu EXTA-55 benar-benar berjalan.

**Yang harus berubah:** satukan ke satu `CaseLoader` sebelum EXTA-55 menyentuh loop permainan.

---

## 3. Daftar celah

Celah = dijanjikan, tetapi buktinya tidak ada. Diurutkan berdasarkan dampak.

| # | Celah | Bukti ketiadaan | Pemilik | Dampak |
|---|---|---|---|---|
| G-1 | **Case 0 dan story case #1 tidak ada di `main`.** PRD §16 P0 dan gate minggu 6 (EXTA-59) bergantung padanya | PR #6 OPEN; `cases/` tidak ada di `origin/main`; kedua berkas gagal validator kanonik (29 galat) | Nadia (EXTA-38) | Gate minggu 6 tidak punya bahan; tutorial §9 tidak bisa diuji |
| G-2 | **Pengukuran perangkat tidak ada sama sekali.** Gate minggu 0 PRD §17 menuntut "drag halus di mobile, puzzle tidak blur" | EXTA-53 tabel ASUMSI: perangkat bawah **BELUM TERUKUR**, latensi jaringan **BELUM DIUJI**, kompresi texture **BELUM TERUKUR**, jank 16 `ImageLabel` **BELUM TERUKUR**. Artefak spike ada di luar repo (`/Users/mac/Documents/Roblox/.probe/`) | Nathan + owner (perangkat) | Gate minggu 0 lulus hanya di mesin, bukan di target |
| G-3 | **Rantai minggu 2–8 tidak berjalan.** Tujuh issue dibuat, ketujuhnya gagal di environment | Komentar `prepare execution environment` di EXTA-55…EXTA-61, 13:45:23Z; EXTA-55 dua tambahan sampai 13:46:43Z | Nathan + konfigurasi project resource | Seluruh jalur kritis berhenti |
| G-4 | **CI tidak memeriksa apa pun.** | `gh variable list` kosong; `main` tidak dilindungi (404); keenam run `skipped` | Devan + owner | 15 PR merge hari ini tanpa satu pun pemeriksaan otomatis |
| G-5 | **Empat workstream hasilnya hanya komentar, tanpa artefak repo:** EXTA-37 (pengukuran), EXTA-40 (riset), EXTA-42 (pendapatan), EXTA-43 (biaya) | Tidak ada berkas terkait di `origin/main` untuk keempatnya (dicek per path) | Dewi, Damar, Michelle, Ayu | Angka-angka ini dipakai workstream lain (EXTA-44 ambang belanja, EXTA-48 decision log) tetapi tidak bisa dibuka ulang dari repo |
| G-6 | **Dua hasil hanya hidup sebagai lampiran komentar:** EXTA-46 (`operating-plan-triangulate.md`, ±29 KB) dan EXTA-51 (`peta-dependensi-triangulate.md`, ±29 KB) | Lampiran ada di komentar; tidak ada berkas di repo; EXTA-51 sengaja tidak menaruhnya karena `docs/program-map.md` milik EXTA-52 | Rafael, Mika | Dokumen operasi terbesar program tidak ikut version control |
| G-7 | **`par_time_s` tidak ada di skema kasus** → rank M-13 dan D2 `BLOKIR` | `grep par_time_s` di `schema/` dan `data/` → nihil (§2.12) | Nathan (EXTA-33) | PRD §5 rank tidak bisa dihitung |
| G-8 | **Buku besar belum punya satu baris realisasi.** | `docs/buku-besar/buku-besar-2026-10.csv` header-only, 0 baris | Dimas (EXTA-45) | Anggaran tidak bisa dilacak meski ambangnya sudah ada |
| G-9 | **Autopilot dan wakeup belum dibuat.** EXTA-35 merancang otomasi laporan metrik, tetapi tidak ada yang berjalan | `multica autopilot list` kosong; `multica issue wakeup list` → `[]` (EXTA-37 §C1) | Bima (EXTA-35) | Laporan metrik tidak jalan sendiri; gate roadmap tidak diingatkan |
| G-10 | **PR #17 tertinggal, memuat klaim lingkungan yang salah tetap beredar.** | PR #17 OPEN sejak sebelum `80b35e9`; `docs/spike-minggu-0-hasil.md` §7 di `main` masih versi lama | Nathan | Satu klaim salah di repo |
| G-11 | **Triangulate belum punya key result di lapis Exta.** Satu-satunya sasaran yang bisa menampungnya (O2) diparkir sejak 25 Sep 2026 | EXTA-50 temuan 2 | Owner | Proyek tidak tersambung ke sasaran 90 hari |

**Bukan celah (dikoreksi dari laporan lama):** EXTA-46 §2 dan EXTA-51 temuan 1 menyatakan "minggu 2–8 tidak punya issue build". **Itu sudah tidak berlaku** — EXTA-55…EXTA-61 ada. Yang benar sekarang: issue-nya ada, pelaksanaannya belum mulai karena environment (G-3).

---

## 4. Jalur kritis 8 minggu versi final

Basis: PRD §17, gate dan pemilik dari EXTA-46 §1 (G-1…G-4), urutan dari EXTA-51 §"jalur kritis", status nyata dari §1e dan §6 dokumen ini.

| Minggu | Target (PRD §17) | Issue | Pemilik | Gate | Penanda risiko | Pemilik gate |
|---|---|---|---|---|---|---|
| 0–1 | Spike resolusi, replikasi drag, ping wheel | EXTA-53 ✅ | Nathan | Drag halus di mobile, puzzle tidak blur | **R-1** gate lulus di mesin saja (G-2); gutter 1 px belum cukup (§2.6) | Nathan |
| 2 | Loader kasus, lokasi, objek + kunci, rantai A→bukti | EXTA-55 ⛔ | Nathan | Satu rantai A→bukti jalan end to end | **R-2** environment gagal (G-3) — **penghambat keras, menahan semua minggu sesudahnya**; **R-3** `CaseLoader` ganda (§2.13) | Nathan |
| 3 | Director UI: clue board, kombinasi, pinpoint | EXTA-56 | Nathan | Satu deduksi berhasil dari 2 clue | **R-4** menumpuk di satu pelaksana; tidak ada `par_time_s` untuk rank (G-7) | Nathan |
| 4 | Pemisahan info per role, form tuduhan, 3 percobaan | EXTA-57 | Nathan | Tidak ada kebocoran solusi di client | **R-5** §15 server-authoritative belum pernah diuji kebocoran secara nyata | Nathan |
| 5 | Lobby, preferensi role, NPC, AFK/rejoin | EXTA-58 | Nathan | Sesi 3 pemain mulai tanpa bug | **R-6** NPC Director di P1 tetapi PRD §8 menaruh NPC di jalur lobby MVP | Rafael |
| 6 | Case 0, story case #1 + varian, ping wheel final | EXTA-59 | Nathan | Playtest internal | **R-7** bahan kasus belum ada (G-1) — **gate ini pasti geser** | Nadia → Rafael |
| 7 | Playtest 3 pemain nyata (mobile), tuning idle | EXTA-60 | Nathan | Idle < 25%, selesai > 55% | **R-8** ">55%" **tidak bisa dibuktikan dengan 3 pemain** — butuh 65 sesi pada rate 70%, 35 pada 75%, 22 pada 80% (EXTA-37); yang jujur bisa diverifikasi hanya idle time | Dewi (angka) → Rafael (putusan) |
| 8 | Polish, kuesioner rating, rilis | EXTA-61 | Nathan | Metrik minggu 7 terpenuhi | **R-9** rilis tanpa CI dan tanpa branch protection (G-4) | Owner |

### Penghambat keras, berurutan

1. **G-3 (environment EXTA-55…EXTA-61).** Selama ini belum beres, minggu 2 tidak mulai, dan tidak ada pekerjaan lain yang bisa mempercepat rilis. Ini satu-satunya penghambat yang **tidak punya jalur memutar** — perbaikan `docs/program-map.md` tidak memindahkannya.
2. **G-1 (bahan kasus).** Menahan gate minggu 6, yang jatuh sebelum playtest minggu 7. Kalau Case 0 belum ada di minggu 6, playtest minggu 7 menguji kasus yang salah.
3. **G-4 (CI mati).** Bukan penghambat jadwal, tetapi penghambat mutu: 15 PR mendarat hari ini tanpa pemeriksaan, dan salah satunya (§2.4) membawa data yang gagal validator.

### Yang saya nyatakan sekarang, bukan nanti

Gate minggu 7 tidak bisa lulus sebagaimana ditulis PRD §17. Bukti: untuk membuktikan "sesi selesai > 55%" pada 80% power dibutuhkan **606 sesi** bila angka sebenarnya 60%, **149** pada 65%, **65** pada 70%, **35** pada 75%, **22** pada 80% (EXTA-37 §"kekuatan uji"). Tiga pemain memberi belasan sesi. Menyatakan gate ini lulus berarti mengukur derau. **Rekomendasi:** minggu 7 memverifikasi **idle time < 25%** (bisa diukur dari 3 pemain) dan **menandai** completion rate sebagai hipotesis; konfirmasi > 55% dipindah ke gate pasca rilis dengan n sesi yang memadai. Ini usulan EXTA-37 dan saya dukung; keputusannya milik Rafael.

---

## 5. Antrean keputusan owner

Diurutkan berdasarkan dampak — seberapa banyak pekerjaan lain yang bergantung padanya. Setiap baris: opsi + rekomendasi.

### K-1. Perbaiki environment EXTA-55…EXTA-61 (dampak: seluruh jalur kritis)

**Masalah:** ketujuh issue gagal di `prepare execution environment` karena project resource menunjuk `local_directory "/Users/mac/Documents/Roblox"` dengan `execution_mode=worktree`, sedangkan direktori itu bukan git repository dan tidak punya commit untuk di-branch. **Issue ini sendiri kena dua kali** (13:45:23Z dan 13:46:57Z) sebelum run yang menulis dokumen ini berhasil — jadi hambatannya bukan milik satu issue, melainkan milik konfigurasi project resource.

**Opsi:**
- **(a) Arahkan project resource ke repo `jettapindika/triangulate`.** Satu perubahan konfigurasi; ketujuh issue langsung bisa jalan; `main` sudah berisi 123 berkas termasuk `src/`, `tests/`, `tools/`.
- **(b) `git init` di `/Users/mac/Documents/Roblox` dan buat commit awal.** Mempertahankan lokasi lokal, tetapi memisahkan pekerjaan dari repo proyek — riwayat akan bercabang dua.
- **(c) Biarkan, kerjakan minggu 2–8 manual.** Tidak ada keuntungan; issue tetap `in_progress` tanpa hasil.

**Rekomendasi: (a).** Repo proyek sudah berisi semua yang dibutuhkan, dan PR/CI/review hanya bekerja di atas git. Opsi (b) membuat dua sumber kebenaran.

### K-2. Nyalakan CI — setelah prasyaratnya, bukan sebelum (dampak: mutu setiap PR berikutnya)

**Masalah:** `CI_ENABLED` kosong, `main` tidak dilindungi, keenam run `skipped`. 15 PR hari ini merge tanpa pemeriksaan.

**Opsi:**
- **(a) Nyalakan CI sekarang** (`gh variable set CI_ENABLED --body true`). Konsekuensi: CI hijau sambil membawa 8 galat tipe yang di-`continue-on-error`; hijau palsu.
- **(b) Tutup 8 galat tipe di `src/` → pangkas `globals` di `.luaurc` → lepas `continue-on-error` → nyalakan CI → lindungi `main` dengan required check.** Lima langkah berurutan.
- **(c) Nyalakan CI dan lindungi `main` sekarang, biarkan `continue-on-error` sampai galat tipe beres.** Memberi sinyal lebih awal, tetapi mengunci merge pada pipeline yang belum mempercayai dirinya sendiri.

**Rekomendasi: (b), dengan (c) sebagai jembatan bila kecepatan lebih penting daripada ketepatan.** Urutan (b) adalah satu-satunya yang menghasilkan hijau yang bisa dipercaya. Detail 8 galat ada di `.github/workflows/ci.yml` komentar langkah `Analisis tipe — luau-lsp` dan `docs/ci/03-pipeline-ci.md` §3.5.

### K-3. Bahan kasus: tulis ulang atau pindahkan skema (dampak: gate minggu 6)

**Masalah:** dua format kasus hidup bersamaan; data EXTA-38 gagal validator kanonik dengan 29 galat; dua validator bersaing (Luau milik EXTA-33 di `main`, Python milik EXTA-38 di PR #6).

**Opsi:**
- **(a) EXTA-38 menulis ulang `case_00.json` dan `kersana_01.json` terhadap `schema/case.schema.json`, hapus `tools/validate_cases.py`.** Satu format, satu validator.
- **(b) Longgarkan `schema/case.schema.json` agar menerima `clue`, `statements` opsional, dan `briefing` opsional.** Menghapus persyaratan PRD §4 (pernyataan saksi dan kontradiksi) — bertentangan dengan §4 dan §5.
- **(c) Pertahankan dua format.** Menjamin dua loader dan dua jalur uji selamanya.

**Rekomendasi: (a).** Opsi (b) membuang mekanik kontradiksi yang PRD §4 sebut sebagai salah satu syarat membuka tuduhan. Ini keputusan Nadia sebagai pelaksana, tetapi butuh keputusan owner karena berarti pekerjaan ulang penuh.

### K-4. Gate minggu 7: ubah definisi lulusnya (dampak: satu gate palsu)

**Masalah:** "sesi selesai > 55%" tidak bisa dibuktikan dengan 3 pemain (butuh 22–606 sesi tergantung rate sebenarnya).

**Opsi:**
- **(a) Minggu 7 verifikasi idle time saja; completion rate jadi hipotesis; konfirmasi > 55% jadi gate pasca rilis.** Jujur, dan tidak menahan rilis.
- **(b) Turunkan ambang sampel: nyatakan lulus bila ≥ 2 dari 3 sesi selesai.** Derau; 3 sesi tidak membedakan 55% dari 40%.
- **(c) Tunda gate minggu 7 sampai n sesi cukup.** Menahan rilis tanpa batas waktu.

**Rekomendasi: (a).** Idle time memang bisa diukur dari 3 pemain, dan itulah metrik yang paling menentukan kualitas pengalaman per role (PRD §12 "Idle time per role < 25%"). Ini usulan EXTA-37; saya hanya menegaskan bahwa opsi (b) tidak boleh dipilih.

### K-5. Angka yang masih `ASUMSI` dan memblokir gate (dampak: tiga gate sekaligus)

**Masalah:** tiga angka menentukan tiga gate, dan ketiganya masih asumsi:

| Angka | Pemilik | Memblokir |
|---|---|---|
| `IDLE_THRESHOLD_S = 5` | EXTA-36 (Rani) | Gate minggu 7 "idle < 25%" |
| `BUCKET_MS = 1000` | EXTA-36 (Rani) | Definisi M-metrik |
| Timer cleanup (§6 PRD) | PRD §19 menyebutnya terbuka | Tekanan waktu MVP |

**Opsi:**
- **(a) Tetapkan sekarang dari playtest internal minggu 6.** Data internal lebih baik daripada tidak ada angka.
- **(b) Tetapkan dari playtest minggu 7.** Lebih nyata, tetapi gate minggu 7 memakai angka yang ditetapkan sesudahnya — urutan terbalik.
- **(c) Tunda ke pasca rilis.** Gate minggu 7 kehilangan makna.

**Rekomendasi: (a), dengan angka minggu 7 sebagai revisi.** Menetapkan ambang sebelum mengukur adalah cara gate menjadi terukur; merevisinya sesudah data masuk adalah cara ia menjadi benar.

### K-6. Publikasikan hasil yang hanya hidup di komentar (dampak: 6 workstream)

**Masalah:** EXTA-37, EXTA-40, EXTA-42, EXTA-43 (tanpa artefak apa pun) dan EXTA-46, EXTA-51 (lampiran komentar saja). Angka EXTA-42/43/44/48 saling mengutip, tetapi tidak bisa dibuka ulang dari repo.

**Opsi:**
- **(a) Keenamnya menulis berkas ke repo lewat PR.** Satu pola untuk semua.
- **(b) Lampiran komentar dianggap cukup; tambahkan hanya indeks di repo.** Cepat, tetapi indeks menunjuk komentar, dan komentar tidak bisa di-diff.
- **(c) Biarkan.** Melanggar acceptance issue masing-masing ("deliverable benar-benar ada di repo").

**Rekomendasi: (a).** `docs/decision-log.md` (EXTA-48) dan `docs/risk-register-triangulate.md` (EXTA-44) sudah mengutip angka dari EXTA-42/43; mengutip angka yang tidak bisa dibuka adalah cara sebuah proyek kehilangan jejaknya.

### K-7. Nyatakan minggu 2–8 sebagai kapasitas, bukan jadwal (dampak: seluruh roadmap)

**Masalah:** tujuh issue minggu 2–8 semuanya milik **satu** pelaksana (Nathan). EXTA-51 temuan 1 menyebut jalur kritisnya "ketiadaan pelaksana". Dengan tujuh issue berurutan dan satu orang, urutannya menjadi panjang.

**Opsi:**
- **(a) Paralelkan yang bisa diparalelkan.** EXTA-59 (konten: Case 0 + story case) tidak bergantung pada EXTA-57 (form tuduhan) secara teknis; Nadia bisa mulai begitu skema kanonik dipakai.
- **(b) Tetap berurutan, terima tanggal yang lebih panjang.** Aman, jujur, lambat.
- **(c) Tambah pelaksana.** Butuh agen baru atau penugasan ulang — keputusan owner.

**Rekomendasi: (a) untuk EXTA-59, sisanya tetap berurutan.** EXTA-59 adalah satu-satunya yang punya pemilik berbeda dan tidak bergantung pada hasil EXTA-55–EXTA-58; memindahkannya ke jalur paralel menghilangkan satu langkah dari jalur kritis.

### K-8. Sasaran 90 hari untuk Triangulate (dampak: penyelarasan)

**Masalah:** Triangulate tidak punya KR di lapis Exta; satu-satunya sasaran yang bisa menampungnya (O2) diparkir sejak 25 Sep 2026 (EXTA-50).

**Opsi:**
- **(a) Buat KR baru di bawah O1 atau O3 untuk Triangulate.** Menyambungkan proyek ke sasaran yang sedang diukur.
- **(b) Aktifkan kembali O2.** Bertentangan dengan keputusan parkir 25 Sep.
- **(c) Biarkan tanpa KR.** Proyek berjalan tanpa sasaran yang diukur di lapis atas.

**Rekomendasi: (a).** O3 ("alat Exta benar-benar dipakai") adalah tempat yang paling wajar untuk game yang akan dirilis ke pemain luar; O1 adalah ujian yang tidak berkaitan dengan game. Keputusannya milik owner.

---

## 6. Verifikasi mekanis

Semua perintah dijalankan dari checkout `triangulate` pada 2026-10-04, HEAD `80b35e9` (= `origin/main`), working tree bersih.

### 6.1 Uji Luau

```
$ lune run tests/run.luau
566 assertion, 0 gagal
SEMUA LULUS                                   (exit 0)
```

Catatan: EXTA-54 mengutip **358 assertion** dan EXTA-53 mengutip **566**. Keduanya benar pada saat penulisannya (suite tumbuh antara PR #15 dan PR #16). Angka hari ini adalah **566**.

### 6.2 Validator kasus kanonik — `data/cases/gallery_01.json`

```
$ lune run tools/validate_case.luau -- data/cases/gallery_01.json
status: LULUS
errors: 0
warnings: 0
HASIL: 1 file lulus.
```

### 6.3 Validator kasus kanonik — data PR #6 (EXTA-38)

```
$ lune run tools/validate_case.luau -- cases/case_00.json cases/kersana_01.json
file: cases/case_00.json      → 10 galat
file: cases/kersana_01.json   → 19 galat
HASIL: 2 dari 2 file gagal.
```

Galat menurut aturan: `nodes[].type` (8×, nilai `"clue"` tidak dikenal), `nodes[].supports` (9×), `variants[].variant_id` (2×), `variants[].method` (2×), `location` (2×), `briefing` (2×), `statements` (2×), `statements[].contradicted_by` (1×), `variants` (1×).

### 6.4 Status pull request

```
$ gh pr list --state all --limit 30 --json number,title,state,mergedAt
17 PR total — 15 MERGED, 2 OPEN
```

| PR | Issue | Status | Merge |
|---|---|---|---|
| #10 | EXTA-33 | MERGED | 11:16:48Z (`59e0ff7`) |
| #14 | EXTA-54 | MERGED | 11:16:59Z (`d932dc0`) |
| #11 | EXTA-32 | MERGED | 11:17:37Z (`01783b6`) |
| #15 | EXTA-54 | MERGED | 11:21:59Z (`c25d062`) |
| #13 | EXTA-34 | MERGED | 11:51:08Z (`d0e8489`) |
| #1 | EXTA-45 | MERGED | 12:01:46Z (`c01163c`) |
| #2 | EXTA-41 | MERGED | 12:01:50Z (`a4a5fb7`) |
| #3 | EXTA-44 | MERGED | 12:01:54Z (`f613746`) |
| #5 | EXTA-36 | MERGED | 12:01:57Z (`2b04fde`) |
| #7 | EXTA-48 | MERGED | 12:02:00Z (`d9df547`) |
| #9 | EXTA-49 | MERGED | 12:02:03Z (`573d3b7`) |
| #4 | EXTA-47 | MERGED | 12:03:24Z (`c36a171`) |
| #8 | EXTA-35 | MERGED | 12:04:39Z (`600e168`) |
| #12 | EXTA-39 | MERGED | 12:05:21Z (`9e7a806`) |
| #16 | EXTA-53 | MERGED | 13:29:37Z (`80b35e9`) |
| **#6** | **EXTA-38** | **OPEN** | — |
| **#17** | **EXTA-53** | **OPEN** | — |

Dua PR terbuka adalah dua celah: #6 = G-1 (bahan kasus), #17 = G-10 (koreksi klaim lingkungan).

### 6.5 CI benar-benar mati

```
$ gh variable list --repo jettapindika/triangulate
(empty)

$ gh api repos/jettapindika/triangulate/branches/main/protection
{"message":"Branch not protected", ... "status":"404"}

$ gh run list --limit 6
completed/skipped × 6
```

Workflow `CI` **terdaftar** tetapi setiap job dijaga `if: vars.CI_ENABLED == 'true'` (empat job: `lint`, `analyze`, `test`, `validate-case`). `main` tidak punya branch protection. Kesimpulan: **tidak ada merge gate, dan tidak pernah ada.**

### 6.6 Deliverable benar-benar ada di repo (bukan hanya di komentar)

Diperiksa dengan `git ls-tree -r --name-only origin/main` → **123 berkas**.

| Workstream | Berkas yang diklaim | Ada di `origin/main`? |
|---|---|---|
| EXTA-32 | `docs/arsitektur.md`, `docs/spike-minggu-0.md`, `docs/mvp-notes.md` | ✅ |
| EXTA-33 | `schema/case.schema.json`, `docs/case-schema.md`, `tools/validate_case.luau` | ✅ |
| EXTA-34 | `.github/workflows/ci.yml`, `rokit.toml`, `selene.toml`, `docs/ci/01…06` | ✅ |
| EXTA-35 | `docs/automation-spec.md`, `docs/autopilot-prompt-laporan-metrik.md`, `docs/wakeup-instruksi-gate-roadmap.md`, `tools/metric-report.py`, `tools/roadmap-gate.sh`, `docs/metrics.json`, `docs/roadmap.json` | ✅ |
| EXTA-36 | `docs/metrics/kamus-metrik.md`, `docs/metrics/skema-event-telemetri.md`, `docs/metrics/telemetry-events.schema.json`, `docs/metrics/fixtures/` | ✅ |
| EXTA-37 | (klaim: rencana pengukuran) | ❌ **tidak ada berkas** |
| EXTA-38 | `cases/case_00.json`, `cases/kersana_01.json`, `docs/content/copy-komunikasi.md` | ❌ hanya di PR #6 |
| EXTA-39 | `docs/art/` (art-bible, puzzle-style, ui-spec, palette, tokens, cosmetic-assets, 9 PNG mockup) | ✅ |
| EXTA-40 | (klaim: riset) | ❌ **tidak ada berkas** |
| EXTA-41 | `docs/marketing/positioning-icp-store-page-akuisisi.md` | ✅ |
| EXTA-42 | (klaim: model pendapatan) | ❌ **tidak ada berkas** |
| EXTA-43 | (klaim: model biaya) | ❌ **tidak ada berkas** |
| EXTA-44 | `docs/risk-register-triangulate.md`, `docs/ambang-belanja-triangulate.md` | ✅ |
| EXTA-45 | `docs/buku-besar/buku-besar.md`, `docs/buku-besar/buku-besar-2026-10.csv` | ✅ |
| EXTA-46 | (klaim: operating plan) | ❌ lampiran komentar saja |
| EXTA-47 | `docs/sop/` (README, sop-01…05, lampiran-a) | ✅ |
| EXTA-48 | `docs/decision-log.md` | ✅ |
| EXTA-49 | `docs/narasi/narasi-triangulate.md` | ✅ |
| EXTA-50 | (klaim: peta KR) | ❌ **tidak ada berkas** |
| EXTA-51 | (klaim: peta dependensi) | ❌ lampiran komentar saja |
| EXTA-53 | `tests/gate-minggu-0.spec.luau`, `tools/spike-s02-protokol.luau`, `src/shared/PuzzleTable.luau` | ✅ |
| EXTA-54 | `docs/integrasi-stage-1.md` | ✅ |

Tambahan yang diperiksa dan **tidak** ada di `origin/main`: `docs/evidence/` (diusulkan EXTA-46 E-3), `cases/` di root, `tools/validate_cases.py`, `docs/operating-plan-triangulate.md`, `docs/peta-dependensi-triangulate.md`.

### 6.7 Status rantai minggu 2–8

```
$ multica issue children 01a1065f-43f0-7e99-bcd5-06ac027e5c59
EXTA-32…EXTA-54 → done (EXTA-52 in_progress)
EXTA-55 stage=4  in_progress  assignee=Nathan
EXTA-56 stage=5  in_progress  assignee=Nathan
EXTA-57 stage=6  in_progress  assignee=Nathan
EXTA-58 stage=7  in_progress  assignee=Nathan
EXTA-59 stage=8  in_progress  assignee=Nathan
EXTA-60 stage=9  in_progress  assignee=Nathan
EXTA-61 stage=10 in_progress  assignee=Nathan
```

Komentar di ketujuhnya: hanya `prepare execution environment` yang gagal (13:45:23Z), tanpa satu pun komentar hasil. EXTA-55 punya dua tambahan sampai 13:46:43Z dengan pesan `repository "/Users/mac/Documents/Roblox" has no commit to branch from (worktree mode needs at least one commit)`.

---

## 7. Ringkasan satu halaman

**Yang benar-benar selesai dan bisa dibuka:** 15 PR merge, 123 berkas di `main`, suite uji 566 assertion lulus, validator kasus kanonik lulus atas `gallery_01.json`, gate minggu 0 lulus di semua yang bisa diukur mesin, satu tipe puzzle berjalan end to end.

**Yang diklaim selesai tetapi belum bisa dibuka:** enam workstream tanpa artefak repo (EXTA-37, 40, 42, 43, 46, 50) dan satu lampiran yang tidak ikut version control (EXTA-51); dua PR terbuka (bahan kasus #6, koreksi klaim #17); dua `CaseLoader`; `par_time_s` belum ada di skema; buku besar kosong.

**Yang menghambat:** environment EXTA-55…EXTA-61 (keras, tanpa jalur memutar), bahan kasus belum ada, CI mati dan `main` tidak dilindungi, pengukuran perangkat tidak ada.

**Yang menunggu owner:** 8 keputusan di §5. Dua yang paling mendesak — **K-1** (perbaiki environment, membuka seluruh jalur kritis) dan **K-2** (nyalakan CI dalam urutan yang benar, menentukan mutu setiap PR berikutnya).
