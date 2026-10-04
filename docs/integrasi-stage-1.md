# Integrasi Stage 1 — EXTA-54

Rujukan: PRD v0.2 §4, §5, §9, §10, §15, §17. Dokumen ini mencatat bagaimana dua
pekerjaan stage 1 disatukan ke `main`, keputusan yang diambil saat konflik, dan
apa yang masih terbuka.

Dua pekerjaan yang disatukan:

| PR | Issue | Isi | Head commit |
|---|---|---|---|
| #10 | EXTA-33 | Skema kasus, validator graf, loader data kasus | `962b958` |
| #11 | EXTA-32 | Arsitektur, scaffold Rojo, kontrak data, modul gameplay | `327fe57` |

Keduanya bercabang dari `main` (`5c5f59a`) dan sama-sama menyentuh enam berkas
yang sama (`.gitignore`, `.luaurc`, `README.md`, `data/cases/gallery_01.json`,
`docs/prd-v0.2.md`, `tests/run.luau`); tiga di antaranya dengan isi yang berbeda
(`.luaurc`, `data/cases/gallery_01.json`, `tests/run.luau`). Jadi integrasinya
bukan penggabungan dua himpunan berkas yang lepas, melainkan penyatuan dua
definisi atas berkas yang sama.

## 1. Urutan dan metode

Branch integrasi `exta54-integrasi` dibuat dari head PR #10 (`962b958`), lalu
head PR #11 (`327fe57`) di-*cherry-pick* di atasnya.

Alasannya: PR #11 bercabang dari `main`, bukan dari PR #10, jadi `git merge`
akan menghasilkan konflik yang sama dan tidak ada yang lebih mudah dibaca.
Cherry-pick menghasilkan riwayat linier — `main` → PR #10 → integrasi PR #11 —
dan satu commit integrasi yang bisa di-PR-kan sebagai satu unit.

Urutan pendaratan ke `main`:

| # | Aksi | Hasil di `main` |
|---|---|---|
| 1 | PR #10 di-*merge* lewat GitHub | merge commit `59e0ff7` |
| 2 | PR #14 (`exta54-integrasi`, judul memuat EXTA-54) di-*merge* lewat GitHub | merge commit `d932dc0` |
| 3 | PR #11 direkam sebagai leluhur lewat merge commit `01783b6` (strategi `ours`) | pohon tidak berubah |

Langkah 3 perlu dijelaskan. Setelah langkah 2, seluruh isi PR #11 sudah ada di
`main` — hasil cherry-pick di langkah 2 adalah superset-nya. Menggabungkan PR
#11 sebagai merge biasa karena itu akan membenturkan sepuluh berkas dan
meminta penyelesaian yang mengembalikan pohon ke keadaan yang sudah ada:
pekerjaan yang sama, dikerjakan dua kali. Merge commit `01783b6` memakai
strategi `ours` untuk merekam `327fe57` sebagai parent kedua tanpa menyentuh
pohon, dan itu dibuktikan: `git diff d932dc0 01783b6` kosong. Setelah itu
GitHub menandai PR #11 `MERGED`.

Cherry-pick PR #11 menyentuh 40 berkas: 37 masuk bersih, 3 bentrok (`add/add`).
Ketiganya diselesaikan sadar, bukan dengan `--skip`:

| Berkas | Sumber konflik | Penyelesaian |
|---|---|---|
| `.luaurc` | Dua definisi setelan Luau | **Versi PR #11** — superset: `languageMode: "strict"` + blok `lint` + 18 global Roblox |
| `data/cases/gallery_01.json` | Dua bentuk data kasus | **Basis PR #10** (kanonik, lolos validator) **+ field yang dikonsumsi scaffold PR #11** |
| `tests/run.luau` | Dua runner uji | **Kerangka PR #11** (harness bersama) + 6 blok uji EXTA-33 dipindah ke spec baru |

Tidak ada berkas dari salah satu PR yang hilang. Dibuktikan dengan
`git diff --name-status 962b958 01783b6 --diff-filter=D` dan
`git diff --name-status 327fe57 01783b6 --diff-filter=D` — keduanya kosong.

## 2. `gallery_01.json`: satu kasus, dua konsumen

PR #10 dan PR #11 sama-sama memakai `gallery_01.json`, tetapi membaca field yang
berbeda. Hasil integrasi memakai **data kanonik PR #10 sebagai basis** — itulah
yang lolos `CaseValidator` — lalu menambahkan yang dibaca `init.server.luau`:

| Field tambahan | Isi | Dikonsumsi oleh |
|---|---|---|
| `suspects` | `["curator", "guard", "collector"]` | `Net.forRole("accusation_options", …)` — ruang pilihan Pelaku |
| `motives` | `["debt", "revenge", "greed"]` | idem, Motif |
| `methods` | `["access_card", "alarm_off", "forged_log"]` | idem, Cara |
| `briefings` | Role Card terstruktur per role (kunci Kapital) | `Net.forRole("briefing", …)` — PRD §9 |

Keputusan yang perlu dicatat:

- **`methods` memakai nilai kanonik PR #10** (`access_card`, `alarm_off`) plus
  satu nilai PR #11 (`forged_log`), bukan himpunan PR #11
  (`swapped_painting`/`forged_log`/`stolen_access_card`). Alasannya
  `variants[].method` dan `solution[*].method` yang kanonik memakai
  `access_card`/`alarm_off`; kalau `methods` memakai himpunan PR #11, Director
  tidak akan pernah bisa menulis jawaban yang benar.
- **`briefings` adalah field baru, terpisah dari `briefing`.** `briefing` (huruf
  kecil) adalah teks prosa yang divalidasi `CaseValidator`; `briefings` (huruf
  besar) adalah Role Card terstruktur. Keduanya koeksis, dan keduanya
  didokumentasikan di `docs/case-schema.md`.
- **`briefings.Director.statements` sengaja bersih**: hanya `who` dan `text`.
  `Net.project` menyalin nilai apa adanya, jadi menaruh `case.statements` akar
  (yang memuat `lie` dan `contradicted_by`) di sana akan membocorkan solusi.
  Mode kegagalan itu diuji eksplisit — lihat bagian 5.
- **Tidak ada `null`** di berkas ini (`null` menjadi `nil` saat Rojo menulis
  literal tabel Luau; aturannya didokumentasikan di `data/cases/README.md`).
  Diverifikasi: `grep -c null data/cases/*.json` → `0`.

## 3. `clue` → `clue_card`: cutover, bukan alias

Scaffold PR #11 memakai jenis node `clue`; PRD §4 menamainya **Clue Card**, dan
skema kanonik PR #10 sudah menetapkan `clue_card`. Ini drift, dan alias akan
membiarkan dua nama hidup berdampingan selamanya. Karena itu dilakukan cutover
penuh di dalam commit integrasi:

| Berkas | Yang diubah |
|---|---|
| `src/server/ClueGraph.luau` | `NodeType` + himpunan `VALID_TYPES` |
| `src/server/CaseLoader.luau` | himpunan `VALID_KINDS` |
| `tests/clue-graph.spec.luau` | 8 literal |
| `tests/case-loader.spec.luau` | 7 literal |
| `data/cases/gallery_01.json` | 7 node |
| `data/cases/README.md` | daftar jenis node |

Tidak ada `clue` sebagai jenis node yang tersisa di repo. Sisa kata "clue" yang
ada adalah istilah lain yang memang benar: `TelemetryService.EventKind` punya
`"clue"` sebagai jenis event telemetri ("waktu ke clue pertama"), bukan jenis
node.

## 4. Satu runner uji

PR #10 punya `tests/run.luau` sendiri (runner mandiri, `--!nonstrict`,
`process.exit(0/1)`); PR #11 punya harness bersama (`tests/harness.luau`) dengan
10 berkas spec. Dua runner berarti dua tempat yang bisa lupa dijalankan, dan
runner PR #10 tidak tahu apa-apa soal spec PR #11.

Hasil integrasi: **satu pintu**, `lune run tests/run.luau`, memuat 12 spec —
10 milik PR #11, `case-schema.spec.luau` (EXTA-33 yang dipindah), dan
`leak-sweep.spec.luau` (uji kebocoran lintas lapisan, lihat bagian 5).
Enam blok uji EXTA-33 dipindah ke `tests/case-schema.spec.luau` dalam bentuk
`Harness`:

1. validator atas `gallery_01.json` dan tiga fixture cacat, dicek lewat kode
   stabil (`graph.cycle`, `graph.dead_end`, `gate.key_deductions_exceeds`);
2. determinisme `selectVariant` (seed sama → varian sama; 64 seed menjangkau
   lebih dari satu varian);
3. `load` menolak kasus bersiklus dan menerima kasus valid;
4. proyeksi per role bebas `SERVER_ONLY_FIELDS`;
5. pernyataan hanya berlaku di varian sesi ini;
6. `unlocks` diperlakukan sebagai tepi dependensi nyata, bukan metadata.

`tests/fixtures/*.json` tetap dipakai — fixture itu justru satu-satunya bukti
bahwa validator menolak kasus cacat.

### Seam EXTA-32 ↔ EXTA-33 akhirnya tersambung

PR #11 mendeklarasikan kontrak `CaseLoader.setValidator(fn)` dengan `fn(case) ->
(ok, daftarMasalah)`, dan menyisakan pengisinya untuk EXTA-33. PR #10 menyediakan
`CaseValidator.validate`, tetapi tidak menyediakan `fn` berbentuk kontrak itu —
jadi selama kedua PR terpisah, tidak ada satu pun fungsi di repo yang memenuhi
kontrak seam tersebut.

Integrasi ini menutupnya: `CaseValidator.asLoaderValidator` adalah adapter yang
memenuhi kontrak itu, dan `src/server/init.server.luau` memasangnya saat start.
Efeknya, kasus yang gagal skema atau graf **menghentikan start**, bukan
menghasilkan sesi setengah jalan — dan jalur validasi yang dipakai server adalah
jalur yang sama persis dengan yang diuji dari CLI, karena adapter itu murni.

## 5. Bukti: tidak ada field solusi di payload role mana pun

Field rahasia yang diperiksa (`Net.SECRET_FIELDS`):
`solution`, `variants`, `culprit`, `motive`, `method`, `key_deductions`, `lie`,
`contradicted_by`, `draft`.

`tests/leak-sweep.spec.luau` menyapu **seluruh** pasangan view × role (9 view ×
3 role = 25 target; `puzzle_state` dan `piece_placed` hanya untuk Handler dan
Director karena meja milik Handler — PRD §4, §8) dengan payload yang dirakit
dari data kasus gabungan, bentuknya sama seperti yang dirakit
`init.server.luau`. Beberapa payload sengaja disuntik `solution` dan `culprit`
supaya terbukti proyeksinya benar-benar menyaring. Uji ini berjalan di dalam
suite tunggal, jadi perintah yang sama yang membuktikan runner hijau juga
membuktikan tidak ada kebocoran.

Tabel di bawah adalah keadaan setelah **EXTA-57** (minggu 4) memperluas
`session_state` dengan field gerbang, cleanup, dan rekap Cold Case. Kolom
`hit` tetap 0 untuk seluruh baris.

| view | role | hit | field terkirim |
|---|---|---|---|
| `briefing` | Searcher | 0 | `case_id`, `knowns`, `location`, `objective`, `target`, `unknowns` |
| `briefing` | Handler | 0 | `case_id`, `knowns`, `location`, `objective`, `target`, `unknowns` |
| `briefing` | Director | 0 | `case_id`, `knowns`, `location`, `objective`, `statements`, `unknowns` |
| `clue_card` | Searcher | 0 | `id`, `summary`, `title` |
| `clue_card` | Handler | 0 | `id`, `summary`, `title` |
| `clue_card` | Director | 0 | `id`, `source`, `summary`, `title` |
| `deduction` | Searcher | 0 | `id`, `pinpoint`, `unlocks` |
| `deduction` | Handler | 0 | `id`, `pinpoint`, `unlocks` |
| `deduction` | Director | 0 | `clue_ids`, `id`, `pinpoint`, `unlocks` |
| `session_state` | Searcher | 0 | `case_id`, `chains`, `cleanup_seconds_left`, `cold_case_recap`, `phase`, `role`, `seconds_left` |
| `session_state` | Handler | 0 | `case_id`, `chains`, `cleanup_seconds_left`, `cold_case_recap`, `phase`, `role`, `seconds_left` |
| `session_state` | Director | 0 | `case_id`, `chains`, `cleanup_seconds_left`, `cold_case_recap`, `contradictions_marked`, `contradictions_required`, `deductions_done`, `gate_open`, `key_deductions_done`, `key_deductions_required`, `phase`, `role`, `seconds_left` |
| `puzzle_state` | Handler | 0 | `cols`, `pieces`, `puzzle_id`, `rows` |
| `puzzle_state` | Director | 0 | `cols`, `pieces`, `puzzle_id`, `rows` |
| `piece_placed` | Handler | 0 | `accepted`, `piece_id`, `placed`, `x`, `y` |
| `piece_placed` | Director | 0 | `accepted`, `piece_id`, `placed`, `x`, `y` |
| `report_card` | Searcher | 0 | `id`, `image`, `location`, `object_id` |
| `report_card` | Handler | 0 | `gives_key`, `id`, `image`, `location`, `object_id` |
| `report_card` | Director | 0 | `id`, `image`, `location`, `object_id` |
| `accusation_result` | Searcher | 0 | `attempts_left`, `correct_count` |
| `accusation_result` | Handler | 0 | `attempts_left`, `correct_count` |
| `accusation_result` | Director | 0 | `attempts_left`, `correct_count`, `pending_confirmation`, `rank`, `resolved`, `won` |
| `accusation_options` | Searcher | 0 | `methods`, `motives`, `suspects` |
| `accusation_options` | Handler | 0 | `methods`, `motives`, `suspects` |
| `accusation_options` | Director | 0 | `methods`, `motives`, `suspects` |

**Total hit: 0 dari 25 target.**

Detektornya dibuktikan tidak vacuous — kalau tidak, "0 hit" tidak berarti apa-apa:

| Kontrol | Hasil |
|---|---|
| `Net.findSecrets` atas data kasus mentah | **38 temuan** |
| `Net.findSecrets` atas `session` | **8 temuan** |
| `briefings.Director.statements` sengaja diisi `case.statements` akar, lalu dilewatkan view `briefing` | **8 temuan** (`lie`, `contradicted_by`, `variants` per pernyataan) |
| `Net.validateViews()` | `true`, 0 masalah |

Baris ketiga adalah yang penting: ia membuktikan mode kegagalan yang paling
mungkin pada field baru ini memang tertangkap, bukan lewat begitu saja.

## 6. Perintah verifikasi dan hasilnya

Semua dijalankan dari akar repo. Pertama di atas commit integrasi, lalu
**diulang di `main`** setelah PR #10, #14, dan #11 mendarat (`01783b6`) dengan
hasil identik — angka di bawah adalah angka di `main`.

```sh
lune run tests/run.luau     # EXIT=0
selene src tests tools      # EXIT=0
stylua --check src tests tools   # EXIT=0
rojo build -o build.rbxlx   # EXIT=0
lune run tools/validate_case.luau -- data/cases/gallery_01.json
```

Keluaran `lune run tests/run.luau` (ekor):

```
== CaseLoader: pemilihan varian

== CaseLoader: seam validator EXTA-33

== NPCController: pengambilalihan dan rejoin

== NPCController: role yang diisi NPC

== NPCController: aksi berikutnya

== NPCController: rank terpisah

664 assertion, 0 gagal
SEMUA LULUS
```

Keluaran `selene src tests tools`:

```
Results:
0 errors
0 warnings
0 parse errors
```

Keluaran `rojo build -o build.rbxlx`:

```
Building project 'Triangulate'
Built project to build.rbxlx
```

Pohon hasil build diperiksa isinya, bukan cuma status keluarnya:
`ReplicatedStorage.Shared` berisi ModuleScript termasuk `case/` bersarang,
`ServerScriptService.Server` adalah `Script` dengan ModuleScript anak,
`ServerStorage.Cases` berisi `gallery_01`, dan `StarterPlayerScripts.Client`
adalah `LocalScript` dengan `Hud`, `Table`, dan `NetClient`.

Validator atas kasus gabungan: `status: LULUS`, `errors: 0`, `warnings: 0`.

Seluruh perintah di atas dijalankan ulang setelah EXTA-57 mendarat, dengan
`664 assertion, 0 gagal` dan `EXIT=0` untuk seluruh baris. Pemeriksaan tipe
(dijalankan ulang: 17 modul murni, 0 diagnostik):

```sh
luau-analyze --mode=strict \
  src/shared/Config.luau src/shared/Roles.luau src/shared/Net.luau \
  src/shared/PingPhrases.luau src/shared/PuzzleTable.luau \
  src/shared/case/CaseGraph.luau src/shared/case/CaseValidator.luau \
  src/server/RoleAssignment.luau src/server/Matchmaking.luau \
  src/server/AccusationService.luau src/server/AccusationGate.luau \
  src/server/DeductionEngine.luau src/server/ClueGraph.luau \
  src/server/TelemetryService.luau src/server/NPCController.luau \
  src/server/PuzzleTableService.luau
# EXIT=0, 0 diagnostik
```

Daftar itu sama dengan yang ada di `README.md`. `src/shared/case/Compat.luau`
ditandai `--!nocheck` sehingga tidak dihitung — ia "lulus" karena pemeriksaannya
dimatikan, bukan karena tipenya benar. `src/shared/case/CaseLoader.luau`
(`--!nonstrict`) juga tidak dihitung meski keluarannya bersih, karena
`--mode=strict` pada berkas nonstrict tidak menaikkan ketatnya pemeriksaan.

### Catatan `stylua`

Commit integrasi ikut merapikan berkas PR #10 dengan `stylua.toml` milik PR #11
(`column_width = 100`). Sebelum ini `stylua --check` gagal pada
`src/shared/case/{Compat,CaseLoader,CaseValidator}.luau` — bukan karena isinya,
tetapi karena berkas-berkas itu ditulis sebelum konfigurasi format repo ada.
Dibuktikan dengan `git diff -w` bahwa perubahan pada `Compat.luau` dan
`CaseLoader.luau` hilang seluruhnya saat spasi diabaikan (satu tanda kurung dan
satu literal tabel yang dibungkus ulang). Pada `CaseValidator.luau` perubahan
tersebut bercampur dengan `asLoaderValidator` yang memang baru — lihat bagian 4.
Perubahan format murni tanpa perubahan perilaku; `tests/run.luau` dan validator
menghasilkan keluaran yang sama sebelum dan sesudah.

## 7. Utang yang masih terbuka

| # | Utang | Risiko | Kapan |
|---|---|---|---|
| 1 | **Dua `CaseLoader` koeksis** | `src/shared/case/CaseLoader.luau` (murni, dipakai CLI + `projectForRole`) dan `src/server/CaseLoader.luau` (menyentuh `Instance`, dipakai server) punya nama sama dan tanggung jawab yang tumpang tindih. Pembaca baru bisa salah `require`, dan logika pemilihan varian hidup di dua tempat (`selectVariant` vs `pickVariant`). | Sebelum minggu 2, saat loader dipanggil dari loop permainan |
| 2 | `luau-lsp` + `sourcemap.json` belum ada | `init.server.luau`, `init.client.luau`, `NetClient`, `Hud/*` tidak bisa diperiksa tipe oleh `luau-analyze` mandiri (tidak punya definisi API Roblox). 14 modul murni sudah bersih di bawah `--mode=strict` (13 di `README.md` + `src/shared/case/CaseLoader.luau`). | EXTA-34 |
| 3 | Tidak ada rate limiting remote | Client bisa spam `Report`/`SubmitDeduction` | Sebelum rilis |
| 4 | Belum ada CI | Tidak ada yang menjalankan suite ini otomatis. `tools/validate_case.luau` sudah `exit 1` saat gagal, jadi ia siap jadi gate. | EXTA-34 |
| 5 | Telemetri dihitung tapi tidak dikirim | PRD §12 tidak bisa diukur | EXTA-34 |
| 6 | `SetValidator` sekarang dipasang, tetapi hanya `CaseValidator` | Skema JSON di `schema/case.schema.json` tidak ditegakkan saat runtime (validator Luau yang menegakkan). Dua sumber aturan bisa menyimpang. | Kalau schema dipakai alat luar |

### Butir eskalasi EXTA-33 yang belum diputuskan

Tidak ada yang diubah diam-diam saat integrasi; semuanya masih menunggu
keputusan owner:

1. **`ASSUMPTION`** — varian punya field `method`. PRD §5 menuntut tiga field
   tuduhan (Pelaku/Motif/Cara), sedangkan EXTA-33 hanya menyebut
   culprit/motive. Data dan skema memakai tiga field.
2. **`ASSUMPTION`** — `node.supports` dan `statement.variants` adalah desain
   EXTA-33, bukan dari PRD.
3. **N daily 3/5 menyimpang dari rumus 65% PRD §5.** 65% dari 5 dibulatkan ke
   atas = 4, bukan 3. EXTA-33 memakai angka eksplisit PRD ("3 dari 5") sebagai
   otoritatif, sehingga `case_type = "daily"` → `key_deductions = 3`. Belum ada
   keputusan mana yang berlaku.
4. **Tabrakan kepemilikan `default.project.json`** antara EXTA-33 dan EXTA-32 —
   sekarang sudah tidak relevan karena berkasnya tunggal, tetapi kepemilikannya
   belum ditetapkan.
5. Repo belum punya CI; `tools/validate_case.luau` sudah siap jadi gate dan
   menunggu persetujuan owner.
