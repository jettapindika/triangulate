Status: DRAFT — usulan, belum aktif
Pemilik: Devan — Infrastructure & Runtime Engineer
Rujukan: PRD §15 (Persyaratan Teknis), §16 (MVP P0), §17 (Roadmap minggu 0), §10 (kasus sebagai data), §18 (Risiko)
Prasyarat: tidak satu pun perintah aktivasi di dokumen ini dijalankan. Workflow ditulis **inert** — semua job di-skip sampai owner menyalakan `CI_ENABLED`.

# Pipeline CI — Triangulate

Dokumen ini merancang pipeline GitHub Actions untuk repo `jettapindika/triangulate`, beserta berkas konfigurasi yang menyertainya. Seluruh perintah di dokumen ini sudah dijalankan sendiri pada 2026-10-04 di mesin kerja `ztvns-Mac.local`; exit code dilaporkan apa adanya. Yang tidak berhasil dijalankan ditandai `TIDAK TERVERIFIKASI`.

Ringkas keadaan hari ini: repo punya **0 required status check**, dan `main` **tidak terproteksi** (`gh api repos/jettapindika/triangulate/branches/main/protection` → HTTP 404 `"Branch not protected"`). Sebelum branch PR ini di-push, `gh api repos/jettapindika/triangulate/actions/workflows` juga mengembalikan `total_count: 0`; setelah push, workflow **terdaftar** dan satu run terpicu dengan seluruh job `skipped` (§4.7). Jadi dokumen ini mengusulkan sesuatu yang belum berjalan, bukan mendokumentasikan yang sudah jalan.

## 1. Status dan artinya

| Pertanyaan | Jawaban |
|---|---|
| Apakah pipeline ini sudah berjalan? | **Belum.** Berkas workflow ada di repo, tetapi setiap job berguard `if: vars.CI_ENABLED == 'true'` dan repository variable `CI_ENABLED` **belum ada** (`gh api repos/.../actions/variables` → `{"total_count": 0}`). |
| Apa yang terjadi kalau PR dibuka sekarang? | **Sudah teramati**, bukan lagi dugaan. Pada PR #13, GitHub mendaftarkan workflow dan memicu satu run `event: pull_request` yang selesai `conclusion: skipped`; keempat job `lint`, `analyze`, `test`, `validate-case` masing-masing `skipped` dengan **`steps: 0`**. Tidak ada check yang gagal, dan tidak ada menit yang terpakai. Rinciannya di §4.7. |
| Apakah PR jadi terblokir? | **Tidak**, dan itu disengaja. Required status check belum dipasang (§5), jadi `skipped` tidak menghalangi merge. Ini mencegah pipeline baru memblokir PR-PR yang sudah terbuka saat workflow ini mendarat. |
| Kapan ia mulai bekerja? | Setelah owner menjalankan satu perintah aktivasi di §5.1. |
| Apakah ini "sudah ada CI"? | **Belum.** Yang ada adalah **usulan yang inert**. Sampai `CI_ENABLED` diset dan PR-nya di-merge, repo tetap tanpa CI. |

## 2. Berkas yang ditambahkan

| Path | Isi | Pemilik |
|---|---|---|
| `.github/workflows/ci.yml` | Definisi 4 job: `lint`, `analyze`, `test`, `validate-case` | Devan (dokumen ini) |
| `stylua.toml` | Konfigurasi formatter StyLua | Devan |
| `selene.toml` | Konfigurasi linter selene | Devan |
| `.luaurc` | Mode bahasa Luau `strict` + alias `shared`/`server`/`client` | Devan |
| `rokit.toml` | Pin versi toolchain untuk workstation | Devan |

Berkas `stylua.toml`, `selene.toml`, `.luaurc`, dan `rokit.toml` sengaja diletakkan di root repo supaya CI dan editor lokal memakai aturan yang sama — bukan dua set aturan yang menyimpang.

`ASUMSI`: layout `src/shared`, `src/server`, `src/client` dan berkas `default.project.json` (Rojo) berasal dari scaffold EXTA-32 (Nathan — CTO/CIO). Dokumen ini merujuknya, tidak memilikinya. Bila EXTA-32 memilih layout lain, alias di `.luaurc` dan job `analyze` perlu disesuaikan.

### 2.1 Isi keputusan konfigurasi

**`stylua.toml`** — `syntax = "All"`, `column_width = 100`, `line_endings = "Unix"`, `indent_type = "Tabs"`, `indent_width = 4`, `quote_style = "AutoPreferDouble"`, `call_parentheses = "Always"`, `collapse_simple_statement = "Never"`. Tab dipilih karena itu konvensi de-facto komunitas Luau/Roblox dan toolchain lain (Rojo, luau-lsp) tidak peduli.

Nilai-nilai ini **disamakan dengan `stylua.toml` di branch EXTA-32** (scaffold `src/`, PR #11), karena EXTA-32 yang memiliki kode dan kodenya sudah terformat untuk lebar 100. Uji 2026-10-04 pada pohon EXTA-32: `stylua --config-path stylua.toml --check src tests` → **exit 0** dengan `column_width = 100`; dengan `column_width = 120` → **exit 1** (StyLua ingin menggabungkan baris yang muat dalam 120 kolom). Draf awal dokumen ini memakai 120 dan itu **salah** untuk repo ini.

**`selene.toml`** — `std = "luau+roblox"`, `exclude = ["build/**", ".rojo/**"]`, plus `[lints]` dengan `shadowing = "allow"`, `multiple_statements = "deny"`, `unused_variable = "warn"`. `exclude` dan `multiple_statements = "deny"` diadopsi dari `selene.toml` EXTA-32; kode EXTA-32 lolos dengan keduanya.

Pemilihan `luau+roblox` **bukan** pilihan gaya, melainkan hasil pengujian: repo akan memuat dua gaya `require` sekaligus. `src/` memakai gaya Roblox (`require(ReplicatedStorage.Shared.Types)`), sedangkan `tests/` yang dijalankan lune memakai gaya path relatif (`require("../src/shared/clue_graph")`). Hasil uji:

| std | `src/` gaya Roblox | `tests/` gaya Lune |
|---|---|---|
| `roblox` | lolos | `error[incorrect_standard_library_use]` |
| `roblox+luau` | lolos | `error[incorrect_standard_library_use]` |
| `luau` | `error[undefined_variable]: game is not defined` | lolos |
| **`luau+roblox`** | **lolos** | **lolos** |

Urutannya penting: `luau` harus di depan. `roblox+luau` menghasilkan error yang sama dengan `roblox` pada `require` gaya Lune.

Catatan lint tambahan, semuanya diuji ulang 2026-10-04 dengan selene **0.28.0 dan 0.32.0** (perilakunya identik di kedua versi):

- **`[rules]` adalah alias sah untuk `[lints]`.** Selene mendeserialisasi `lints` dengan `#[serde(alias = "rules")]` (`selene-lib/src/lib.rs`), jadi `[rules] shadowing = "deny"` dan `[lints] shadowing = "deny"` sama-sama menaikkan `shadowing` dari `warning` menjadi `error`. Draf awal dokumen ini menyatakan selene "mengabaikan `[rules]`" — **itu salah** dan sudah dikoreksi. Yang benar: memakai **keduanya sekaligus** gagal sebagai `Config file not in correct format: TOML parse error` (dua kunci menulis field `lints` yang sama). Repo memakai `[lints]` saja.
- **Kunci tingkat atas tidak dikenal ditolak.** `deny_unknown_fields` aktif: `bogus_key = 1` dan `[nonsense] x = 1` sama-sama → `Config file not in correct format: TOML parse error` (EXIT=1). Jadi typo pada nama seksi tidak lewat diam-diam.
- **Nama lint tidak divalidasi.** `[lints] not_a_real_lint = "allow"` diterima tanpa keluhan (EXIT=0 saat tidak ada temuan lain). Typo pada **nama lint** memang lewat diam-diam — itu risiko yang tersisa, dan satu-satunya penangkalnya adalah review.
- **`[config]` bukan tempat severity.** Nilai severity hanya sah di `[lints]` (alias `[rules]`). `[config] unused_variable = "warn"` ditolak dengan `ERROR: [unused_variable] Configuration was incorrectly formatted: invalid type: string "warn", expected struct UnusedVariableConfig` (EXIT=1) — `[config]` hanya menerima struct khusus lint, mis. `empty_if = { comments_count = true }`.
- **Peringatan ikut menggagalkan selene.** Selene keluar **EXIT=1** saat ada `warning`, bukan hanya saat ada `error`. Karena CI tidak memakai `--allow-warnings`, `unused_variable = "warn"` berarti temuan itu **memblokir** merge. Itu memang disengaja, tetapi penting diketahui: "warn" di `selene.toml` tidak berarti "tidak menghalangi".

Catatan untuk penulis uji: `assert(x)` dengan satu argumen memicu `error[incorrect_standard_library_use]: standard library function 'assert' requires 2 parameters, 1 passed` di bawah ketiga varian std (termasuk `luau` polos). Runner uji sebaiknya memakai pola counter + `error(string.format(...))`, bukan `assert` satu argumen.

**`.luaurc`** — `languageMode: strict`, `aliases` (`shared` → `src/shared`, `server` → `src/server`, `client` → `src/client`), `lint: { "*": true }`, plus 18 entri `globals`. Alias dan `languageMode` berasal dari draf EXTA-34; `lint` dan `globals` diadopsi dari `.luaurc` EXTA-32 supaya tidak ada setelan yang hilang saat kedua PR digabung.

Konsekuensi `strict` yang harus disadari: `strict` menandai `Unknown require` pada setiap `require` yang tidak bisa diresolusi luau-lsp. Karena itu job `analyze` **wajib** menjalankan `rojo sourcemap` lebih dulu (§3.3); tanpa sourcemap, luau-lsp gagal dengan `TypeError: Unknown require`.

Tentang `globals` — **diuji, dan hasilnya berlawanan dengan dugaan awal.** Entri `globals` **memang dibaca** `luau-lsp analyze`, bukan hanya linter Luau. Cara kerjanya penting:

- Entri `globals` hanya **mendeklarasikan nama**, tanpa tipe apa pun — nama itu menjadi `any`.
- Karena itu, menaruh nama API Roblox (`Instance`, `game`, `workspace`, `Enum`, `Vector3`, …) di `globals` **melemahkan** analisis: nama tersebut tidak lagi diperiksa terhadap definisi.
- Repro minimal (2026-10-04): `local p = Instance.new("Part"); local n: number = p.Name` → dengan `--definitions` dan **tanpa** entri `Instance` di `globals` → `TypeError: Expected this to be 'number', but got 'string'` (benar, tertangkap). Dengan `Instance` ditambahkan ke `globals` → **0 galat** (kesalahan tipe lolos).
- Definisi dari `--definitions` tetap **wajib**: tanpanya, luau-lsp mencetak `WARNING: --platform is set to 'roblox' but no definitions files are provided`.

Pada pohon EXTA-32 + EXTA-34 hari ini, daftar `globals` itu **tidak mengubah jumlah galat**: dengan `globals` maupun tanpa, `luau-lsp analyze` melaporkan 8 galat yang sama (galatnya soal union tipe lokal, bukan anggota API Roblox). Daftar ini dipertahankan karena berasal dari EXTA-32 dan menghapusnya tidak memberi manfaat terukur sekarang; tetapi ia perlu **dipangkas** saat galat tipe di `src/` dibereskan (§3.5), supaya pemeriksaan tipe Roblox kembali tajam.

**`rokit.toml`** — format entri wajib `owner/repo@versi`. Bentuk tanpa pemisah `@` (mis. `StyLua = "2.5.2"`) ditolak dengan `WARN ... missing '@' separator`. Tag ditulis apa adanya: StyLua dan lune memakai awalan `v`, selene dan luau-lsp tidak. Isinya disamakan dengan EXTA-32, ditambah satu tool `luau-lsp` yang dibutuhkan job `analyze`.

## 3. Toolchain dan langkah CI

### 3.1 Versi terpin

Tidak ada `latest` di mana pun. Setiap versi dipin angka persis, arsipnya diverifikasi SHA-256 sebelum diekstrak, dan hash-nya ditulis di `env:` workflow.

| Tool | Versi | Aset Linux x86_64 | SHA-256 |
|---|---|---|---|
| StyLua | `v2.5.2` | `stylua-linux-x86_64.zip` | `bcb0d855e91f102f28a370e850f8566b3b44b79e6274d806ea5246837c0fd5ab` |
| selene | `0.32.0` | `selene-0.32.0-linux.zip` | `d3773393578580074386e69337d35b7acddfbaa9fc38964c07fa3e28436ade9b` |
| luau-lsp | `1.70.1` | `luau-lsp-linux-x86_64.zip` | `1a2ea1ae4f98f8946cefd970a4b54853e11ab4775e6932faa7f60cf920346567` |
| lune | `v0.10.5` | `lune-0.10.5-linux-x86_64.zip` | `1fb5dee6a1afa1d300092805c6e660fe06144d29dd68c45cf6956f040667f791` |
| rojo | `v7.7.1` | `rojo-7.7.1-linux-x86_64.zip` | `00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4` |
| Definisi Luau | tag `1.70.1` | `globalTypes.d.luau` | `2857efa8245485f8c25c19c018ee1ef9b46afab4efd2ea70fc3257cd3faf7080` |

**Versi ini disamakan dengan `rokit.toml` di branch EXTA-32** (StyLua 2.5.2, selene 0.32.0, lune 0.10.5). Alasannya: dua PR yang mendarat dengan versi tool berbeda akan memformat dan melint dengan aturan berbeda, dan yang kalah adalah PR yang mendarat belakangan. Uji 2026-10-04 pada pohon gabungan EXTA-32 + EXTA-34: kode EXTA-32 lolos dengan ketiga versi baru ini (`stylua --check .` exit 0, `selene .` 0 errors / 0 warnings, `lune run tests/run.luau` 287 assertion lulus). Draf awal dokumen ini memakai 2.1.0 / 0.28.0 / 0.10.4 dan itu menghasilkan konflik dengan PR #11.

Alasan tiap tool dipakai:

- **StyLua** — formatter; satu-satunya cara mencegah diff format yang tidak perlu di PR.
- **selene** — linter statis; menangkap variabel tak terdefinisi dan kesalahan pemakaian standard library tanpa menjalankan kode.
- **luau-lsp** — analisis tipe; satu-satunya alat yang bisa memverifikasi `--!strict` di `src/` (PRD §15 menuntut server-authoritative; tipe yang salah di server berbiaya mahal).
- **rojo** — menghasilkan `sourcemap.json` yang dibutuhkan luau-lsp untuk meresolusi `require` gaya Roblox.
- **lune** — runtime Luau di luar Roblox; menjalankan runner uji dan validator kasus tanpa Roblox Studio.

Setiap arsip berisi **satu binary di root** bernama persis `stylua` / `selene` / `luau-lsp` / `lune` / `rojo` — terverifikasi dengan `unzip -Z1`. Karena itu `unzip -o -q <zip> -d bin` lalu `chmod +x bin/<nama>` sudah cukup, tanpa perlu memindahkan berkas.

`ASUMSI`: runner `ubuntu-latest` adalah x86_64. Bila GitHub kelak menyediakan `ubuntu-24.04-arm`, nama aset perlu diganti ke varian `aarch64`/`arm64`. Yang memverifikasi: kegagalan `file`/eksekusi di run pertama.

### 3.2 Urutan langkah dan alasan gagal cepat

Rantai `needs` sengaja berurutan, bukan paralel:

```
lint ──needs──> analyze ──needs──> test ──needs──> validate-case
```

Alasannya biaya: `lint` selesai dalam hitungan detik dan tidak butuh jaringan selain unduhan tool. `analyze` butuh unduhan definisi 851 KB dan lebih lambat. `test` menjalankan kode. `validate-case` bergantung pada validator milik EXTA-33. Kalau keempatnya paralel, PR dengan satu spasi salah format tetap menagih menit keempat job. Dengan rantai, kegagalan termurah membatalkan sisanya lebih awal.

`concurrency` dengan `cancel-in-progress: true` membatalkan run lama saat branch yang sama di-push lagi.

**Job `lint`** (7 langkah):

| # | Langkah | Perintah |
|---|---|---|
| 1 | Checkout | `actions/checkout@11d5960a326750d5838078e36cf38b85af677262` (v4.4.0), `persist-credentials: false` |
| 2 | Cache | `actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830` (v4.3.0), key berisi tag StyLua + selene |
| 3 | Pasang | unduh 2 zip, `sha256sum -c checksums.txt`, `unzip`, `chmod +x` |
| 4 | PATH | `echo "$RUNNER_TEMP/luau-tools/bin" >> "$GITHUB_PATH"` |
| 5 | Format | `stylua --config-path stylua.toml --check .` |
| 6 | Std Roblox | `selene generate-roblox-std` |
| 7 | Lint | `selene --config selene.toml .` |

Langkah 6 **tidak boleh dihapus**. Tanpa `roblox.yml` lokal, selene mengunduh API dump Roblox dari `https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json`. Terverifikasi dengan jaringan diblokir (`sandbox-exec`): `selene generate-roblox-std` → **EXIT=1**, pesan `ERROR: Couldn't create Roblox standard library: ... Dns Failed`, dan **tidak ada berkas yang ditulis**. Menjalankannya eksplisit membuat kegagalan muncul di langkah yang jelas, bukan sebagai error lint yang membingungkan.

`roblox.yml` **tidak boleh di-commit**: baris pertamanya `# This file was @generated by generate-roblox-std at <timestamp>` dan baris `last_updated: <epoch>` berubah tiap generate, sehingga commit akan menghasilkan diff palsu di setiap run. `roblox.yml` dan `sourcemap.json` **sudah masuk `.gitignore`** di PR ini (`docs/ci/04-manajemen-secret.md` §3.1).

**Job `analyze`** — tambahan pentingnya:

```
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze \
  --definitions="$RUNNER_TEMP/luau-tools/defs/globalTypes.d.luau" \
  --sourcemap=sourcemap.json \
  --base-luaurc=.luaurc \
  src
```

Definisi Luau diunduh dari **tag `1.70.1`**, bukan `main`. Tag `main` menghasilkan hash berbeda (`4f70cbcf82cc84708207c37b3ccc671fdabd0de547391fe0c7f445c8f191e68b`) sehingga setiap perubahan hulu akan memecah CI tanpa perubahan repo. `globalTypes.RobloxScriptSecurity.d.luau` pada tag yang sama **identik byte-for-byte** dengan `globalTypes.d.luau` (keduanya 851435 byte, SHA-256 sama), jadi hanya satu berkas yang perlu diunduh.

Langkah `luau-lsp analyze` memakai `continue-on-error: true` **untuk sementara**. Alasannya di §3.5: `src/` milik EXTA-32 masih menyisakan galat tipe nyata di bawah `languageMode: strict`, dan PR ini bukan pemilik berkas itu.

**Job `test`** — `lune run tests/run.luau`. Berkas ini belum ada; langkahnya dijaga `hashFiles('tests/run.luau') != ''`.

**Job `validate-case`** — `lune run tools/validate-case.luau`. Berkas ini milik **EXTA-33** (Nathan — CTO/CIO), PR #10. Job ini hanya menyiapkan jalur masuknya; tidak ada validator yang ditulis di sini.

### 3.3 Guard `hashFiles` dan `vars`

Aturan yang tidak boleh dilanggar: **`hashFiles` tidak tersedia di `jobs.<job_id>.if`.** Context yang diizinkan di sana hanya `github`, `needs`, `vars`, `inputs`, plus fungsi `always`/`cancelled`/`success`/`failure`. Karena itu pembagiannya:

| Guard | Tingkat | Alasan |
|---|---|---|
| `vars.CI_ENABLED == 'true'` | job | Menjaga seluruh pipeline tetap inert sebelum aktivasi |
| `hashFiles('src/**/*.luau') != ''` | step | `hashFiles` tidak boleh di `jobs.<job_id>.if` |
| `hashFiles('tools/validate-case.luau') != ''` | step | idem |
| `hashFiles('tests/run.luau') != ''` | step | idem |
| `hashFiles('default.project.json') != ''` | step | idem |

Konsekuensinya: sebelum `src/` ada, job `analyze` tetap **hijau** dan menulis `::notice::` ke log. Ini disengaja — pipeline yang merah karena repo belum punya kode akan melatih orang mengabaikan warna merah.

### 3.4 Kekurangan yang ditemukan saat pengujian

| Temuan | Bukti | Dampak pada desain |
|---|---|---|
| `runner` tidak boleh dipakai di `env:` tingkat workflow | `actionlint` 1.7.7 → `.github/workflows/ci.yml:57:18: context "runner" is not allowed here. available contexts are "github", "inputs", "secrets", "vars"` (EXIT=1) | `TOOLS_DIR` dihapus dari `env:`; setiap langkah memakai `$RUNNER_TEMP` langsung |
| `hashFiles` tidak ada di `jobs.<job_id>.if` | dokumentasi konteks GitHub Actions | Semua guard keberadaan berkas dipindah ke tingkat step |
| selene tanpa `roblox.yml` dan tanpa jaringan | `env HOME=/tmp/h3 sandbox-exec -p '(deny network*)' selene --config selene.toml g.luau` → ``std = "luau+roblox", but some libraries could not be found: `luau` `` (EXIT=1) | Langkah `generate-roblox-std` wajib, dan urutannya sebelum lint |
| Pesan error selene menyesatkan | Pesan di atas menunjuk `luau` padahal yang hilang adalah `roblox` | Dicatat di dokumen ini supaya tidak menyesatkan saat CI merah |
| `@lune/test` tidak tersedia di lune 0.10.5 | `require("@lune/test")` → `error requiring module "@lune/test": @lune is not a valid alias` (EXIT=1) | Runner uji ditulis tangan (`tests/run.luau`), bukan memakai pustaka uji |
| `process` bukan global di lune 0.10.5 | `print(type(process))` → `nil`; wajib `require("@lune/process")` | Runner uji tidak boleh memakai `process` telanjang |
| `assert(x)` satu argumen dilarang selene | `error[incorrect_standard_library_use]: standard library function 'assert' requires 2 parameters, 1 passed` | Runner uji memakai counter + `error(...)` |
| Shim `~/.rokit/bin/*` rusak di mesin ini | `~/.rokit/bin/selene` dan `stylua` adalah symlink ke `/Users/mac/.rokit/bin/rokit` yang **tidak ada** (`ls` → `No such file or directory`). Setelah `rokit install` pada HOME terisolasi, shim `.rokit/bin/*` masih gagal dipanggil: `ERROR Resource temporarily unavailable (os error 35)` | `rokit.toml` tetap ditulis sebagai pin versi (formatnya terverifikasi, lihat §4.5), tetapi **pemakaian hariannya di mesin ini TIDAK TERVERIFIKASI**. Ini bagian dari `06-register-celah.md` C-04, **ESKALASI →** Nathan — CTO/CIO |

`TIDAK TERVERIFIKASI`: bahwa CI benar-benar hijau di `ubuntu-latest`. Mesin ini macOS arm64; binary Linux x86_64 terverifikasi sebagai ELF 64-bit x86-64 (`file`) tetapi **tidak bisa dieksekusi** di sini (`cannot execute binary file`, exit 126). Yang memverifikasi: run pertama setelah `CI_ENABLED` diset.

### 3.5 Galat tipe `luau-lsp` pada `src/` (milik EXTA-32) — kenapa `analyze` sementara non-blocking

Pada pohon gabungan EXTA-32 + EXTA-34, `luau-lsp analyze` menemukan **8 galat tipe nyata** di `src/`. Semuanya sudah ada di `src/` milik **EXTA-32** (Nathan — CTO/CIO, PR #11) dan **tidak** disebabkan konfigurasi PR ini.

Diukur 2026-10-04, `luau-lsp 1.70.1`, definisi tag `1.70.1`, `rojo sourcemap` lebih dulu:

| # | Lokasi | Pesan |
|---|---|---|
| 1 | `src/server/NPCController.luau:53,21` | `TypeError: Expected this to be 'string', but got 'T'` — tipe generik `T` dipakai sebagai indeks `{ [T]: boolean }` |
| 2 | `src/server/CaseLoader.luau:152,15` | `TypeError: Unknown require: unsupported path` |
| 3 | `src/server/init.server.luau:125,5` | `TypeError: Types RemoteEvent and nil cannot be compared with == because they do not have the same metatable` |
| 4 | `src/server/init.server.luau:179,22` | `Expected this to be exactly 'PlayerRef', but got '{| id: any, isNew: boolean, preferences: {"Director" \| "Handler" \| "Searcher"}, recentRoles: {string} \|}'` |
| 5 | `src/server/init.server.luau:187,47` | `Expected this to be exactly '{string}', but got '{"Director" \| "Handler" \| "Searcher"}'` |
| 6 | `src/server/init.server.luau:214,48` | idem baris 5 |
| 7 | `src/server/init.server.luau:495,26` | `Expected this to be exactly …` — `LobbyPlayer` vs `PlayerRef` |
| 8 | `src/server/init.server.luau:512,26` | idem baris 7 |

Yang **bukan** penyebab, sudah diuji dan dikesampingkan:

- **`--base-luaurc`.** Menjalankan analyze dengan `.luaurc` gabungan, dengan `.luaurc` milik EXTA-32, dengan `.luaurc` minimal (`{"languageMode": "strict"}` saja), dan **tanpa** `--base-luaurc` sama sekali → keempatnya menghasilkan **8 galat yang sama**. Untuk kedelapan galat ini, setelan `.luaurc` tidak mengubah hasil — galatnya soal union tipe lokal, bukan anggota API Roblox. (Perhatikan: ini **tidak** berarti `globals` diabaikan; ia dibaca, dan justru melemahkan pemeriksaan tipe Roblox — lihat §2.1.)
- **`--platform roblox`.** Menambahkannya tidak mengubah apa pun (tetap 8, EXIT=1).
- **`--no-strict-dm-types`.** Tidak mengubah hasil.
- **Definisi yang hilang.** Kegagalan ~40 `TypeError` yang sempat terlihat adalah artefak: berkas `globalTypes.d.luau` tidak ada, dan luau-lsp mencetak `[ERROR] Failed to read definitions file … Extended types will not be provided` lalu melanjutkan tanpa tipe Roblox. Setelah definisi tag `1.70.1` diunduh (851435 byte, SHA-256 `2857efa8…`), angkanya turun ke 8 galat nyata di atas. **Jangan salah membaca 40 sebagai kondisi repo.**

**Kenapa `continue-on-error: true` dipasang sementara.** Dua alasan, keduanya operasional:

1. `src/` adalah milik EXTA-32. PR ini tidak boleh memblokir merge-nya sendiri karena galat yang bukan miliknya, dan memperbaiki berkas milik workstream lain akan menabrak kepemilikan berkas yang disepakati di EXTA-31.
2. `test` dan `validate-case` **bergantung** pada `analyze` lewat `needs`. Kalau `analyze` merah, kedua job itu ter-skip seluruhnya. Satu galat tipe di `src/` akan mematikan lint-format, uji, dan validasi kasus sekaligus — itu kerugian yang jauh lebih besar daripada manfaatnya.

Karena itu langkah `analyze` memakai `id: analyze` + `continue-on-error: true`, dan langkah berikutnya menulis `::warning title=luau-lsp analyze::…` saat `steps.analyze.outcome == 'failure'`. Galat tetap **terlihat** sebagai anotasi di PR; ia hanya tidak mewarnai job merah.

**Syarat melepas `continue-on-error`:**

1. Kedelapan galat di tabel di atas beres di `src/` (EXTA-32 atau penerusnya).
2. `luau-lsp analyze … src` keluar **exit 0** pada pohon gabungan.
3. Daftar `globals` di `.luaurc` dipangkas dari nama API Roblox (`Instance`, `game`, `workspace`, `Enum`, `Vector3`, …) — nama-nama itu sudah datang bertipe dari `--definitions`, dan mendeklarasikannya ulang sebagai global membuatnya `any` sehingga pemeriksaan tipe Roblox mati (§2.1).
4. Setelah itu, hapus `continue-on-error: true`, hapus langkah `Laporkan galat tipe`, dan tambahkan `analyze` ke required check `main` (urutan aktivasi gate: CI dulu, proteksi branch kemudian — lihat `02-checklist-koneksi-repo.md`).

Sampai keempatnya terpenuhi, `analyze` adalah sinyal, bukan gerbang.

## 4. Hasil pengujian

Seluruh pengujian dijalankan pada layout tiruan realistis di `/tmp/ci-repo/` (`src/shared`, `src/server`, `src/client`, `tests/`, `tools/`, `default.project.json`, `.luaurc`) dengan konfigurasi **persis** dari repo.

### 4.1 Jalur hijau

| # | Perintah | Exit | Output |
|---|---|---|---|
| 1 | `stylua --config-path stylua.toml --check .` | **0** | (tanpa keluaran) |
| 2 | `selene generate-roblox-std` | **0** | `Generating Roblox standard library...` → `roblox.yml` 601707 byte (selene 0.28.0; dengan 0.32.0 menjadi 760203 byte) |
| 3 | `selene --config selene.toml .` | **0** | `0 errors / 0 warnings / 0 parse errors` |
| 4 | `rojo sourcemap default.project.json --output sourcemap.json` | **0** | `Created sourcemap at sourcemap.json` |
| 5 | `luau-lsp analyze --definitions=... --sourcemap=sourcemap.json --base-luaurc=.luaurc src` | **0** | `Loading Luau configuration from /private/tmp/ci-repo/.luaurc` |
| 6 | `lune run tests/run.luau` | **0** | `PASS 2` |
| 7 | `lune run tools/validate-case.luau` | **0** | `validasi kasus: OK` |

Pada repo nyata (root `triangulate`, hanya berisi dokumentasi): `stylua --config-path stylua.toml --check .` → **EXIT=0**; `selene --config selene.toml .` → `0 errors / 0 warnings / 0 parse errors`, **EXIT=0**.

Tabel di atas adalah pengukuran awal pada layout tiruan `/tmp/ci-repo/`, memakai toolchain **2.1.0 / 0.28.0 / 0.10.4** dan `stylua.toml` draf (`column_width = 120`). Keduanya sudah diganti (§2.1, §3.1); §4.6 memuat pengukuran ulang dengan toolchain dan konfigurasi final. Satu angka yang berubah karena versi selene: `roblox.yml` dari 0.28.0 adalah 601707 byte, dari **0.32.0 adalah 760203 byte**. Ukuran itu tidak pernah di-commit (`roblox.yml` ada di `.gitignore`), jadi yang penting hanya berkasnya ada dan lint lolos.

### 4.2 Jalur merah — exit code kegagalan

| Perintah | Kondisi | Exit | Pesan |
|---|---|---|---|
| `stylua --config-path stylua.toml --check src` | berkas berantakan (`local   x=1`) | **1** | `Diff in src/bad.luau:` |
| `selene --config selene.toml src` | global tak terdefinisi | **1** | `1 errors / 0 warnings / 0 parse errors` |
| `luau-lsp analyze ... src` | `local n: number = "string"` | **1** | `src/bad3.luau(2,1): TypeError: Expected this to be 'number', but got 'string'` |
| `lune run tests/run.luau` | `error(...)` dipanggil | **1** | jejak tumpukan ke `tests/run`, Line 3 |
| `stylua --check src` | direktori `src` tidak ada | **2** | `error: no file or directory found matching 'src'` |
| `luau-lsp analyze src` | direktori kosong | **1** | `error: no files provided` |
| `selene --config selene.toml .` | tanpa `roblox.yml`, tanpa cache, tanpa jaringan | **1** | ``std = "luau+roblox", but some libraries could not be found: `luau` `` |
| `selene generate-roblox-std` | tanpa jaringan | **1** | `ERROR: Couldn't create Roblox standard library: ... Dns Failed` (tidak menulis berkas) |

Catatan penting untuk pembaca kegagalan CI: **`stylua` memakai exit 2 untuk "path tidak ditemukan"**, berbeda dari exit 1 untuk "format salah". Ini alasan job `lint` tidak memakai `hashFiles` di level step untuk stylua — `stylua --check .` pada root selalu aman karena root pasti ada.

### 4.3 Validasi berkas workflow

| Pemeriksaan | Perintah | Exit | Hasil |
|---|---|---|---|
| YAML dapat di-parse | `ruby -ryaml -e 'YAML.safe_load_file(".github/workflows/ci.yml", aliases: true)'` | **0** | `PARSE OK`; job: `lint, analyze, test, validate-case` |
| Guard tiap job | pembacaan YAML | **0** | keempat job `if: vars.CI_ENABLED == 'true'`; `needs`: `analyze→lint`, `test→analyze`, `validate-case→test` |
| Lint workflow | `actionlint -color .github/workflows/ci.yml` (1.7.7) | **0** | (tanpa keluaran) |
| Sintaks blok `run` | `bash -n` atas 20 blok `run` hasil ekstraksi YAML | **0** | semua lolos |
| `continue-on-error` + `id` pada langkah `analyze` | `actionlint -color .github/workflows/ci.yml` | **0** | kombinasi `id` + `continue-on-error` + `if` pada langkah yang sama diterima tanpa keluhan |

`actionlint` awalnya **EXIT=1** dan menemukan `context "runner" is not allowed here` pada `env:`. Setelah `TOOLS_DIR` dihapus dari `env:`, `actionlint` → **EXIT=0**. Ini bukti bahwa workflow divalidasi, bukan hanya ditulis.

### 4.4 Verifikasi aset dan checksum

Semua URL di `env:` workflow diuji apa adanya dengan substitusi tag yang sama seperti yang akan dilakukan shell di runner, 2026-10-04. Hasil: **keenamnya HTTP 200** dengan ukuran yang sesuai, dan **kelima arsip + berkas definisi cocok dengan `*_SHA256` di `env:`** (`shasum -a 256 -c` → **enam** baris `: OK`, `EXIT=0`).

| Aset | HTTP | Ukuran | SHA-256 cocok dengan `env:` |
|---|---|---|---|
| `stylua-linux-x86_64.zip` (`v2.5.2`) | 200 | 3303824 B | ya |
| `selene-0.32.0-linux.zip` | 200 | 3610315 B | ya |
| `luau-lsp-linux-x86_64.zip` (`1.70.1`) | 200 | 4475341 B | ya |
| `lune-0.10.5-linux-x86_64.zip` | 200 | 5373877 B | ya |
| `rojo-7.7.1-linux-x86_64.zip` | 200 | 5832480 B | ya |
| `globalTypes.d.luau` (tag `1.70.1`) | 200 | 851435 B | ya |

| Perintah | Exit | Output |
|---|---|---|
| `shasum -a 256 -c checksums.txt` | **0** | enam baris `: OK` |
| `sha256sum -c checksums.txt` | **0** | enam baris `: OK` |

`sha256sum` di mesin ini adalah versi 0.8.0 (`/sbin/sha256sum`) dan menerima format `<hash><dua spasi><nama>` yang sama dengan GNU coreutils, termasuk mode biner satu spasi. Format dua spasi yang ditulis workflow karena itu aman untuk runner Ubuntu.

### 4.5 Verifikasi `rokit.toml`

`rokit` binary (v1.0.0) diunduh ke `/tmp/rokit-bin/` dan `rokit.toml` diuji pada HOME terisolasi `/tmp/rokit-home/` supaya tidak menyentuh `~/.rokit` milik mesin ini.

| Perintah | Exit | Hasil |
|---|---|---|
| `/tmp/rokit-bin/rokit --version` | **0** | `rokit 1.0.0` |
| `HOME=/tmp/rokit-home3 rokit list` | **0** | menemukan kelima tool dengan versi persis: `StyLua → JohnnyMorganz/StyLua @ 2.5.2`, `luau-lsp → JohnnyMorganz/luau-lsp @ 1.70.1`, `lune → lune-org/lune @ 0.10.5`, `rojo → rojo-rbx/rojo @ 7.7.1`, `selene → Kampfkarren/selene @ 0.32.0` |
| `HOME=/tmp/rokit-home GITHUB_TOKEN=... rokit install` | **0** | mengunduh kelima tool ke `tool-storage/` dengan direktori versi yang benar: `johnnymorganz/stylua/2.5.2`, `kampfkarren/selene/0.32.0`, `johnnymorganz/luau-lsp/1.70.1`, `lune-org/lune/0.10.5`, `rojo-rbx/rojo/7.7.1` |

Versi di tabel `rokit install` diukur sebelum penyelarasan dengan EXTA-32 (2.1.0/0.28.0/0.10.4); pemasangan ulang tidak diulang untuk versi baru karena hanya nomor direktori yang berbeda. `rokit list` **diukur ulang** dengan `rokit.toml` final dan mengembalikan kelima versi baru tanpa keluhan, jadi formatnya tetap sahih.

Dua catatan tambahan dari pengujian yang sama:

- `rokit install` **tanpa** `--no-trust-check` berhenti dengan `ERROR The following tool has not been marked as trusted: JohnnyMorganz/luau-lsp` dan **EXIT=1**. Ini perilaku rokit 1.0.0 yang normal: setiap tool harus dipercaya dulu lewat `rokit add <owner/repo>` (atau `rokit trust`). Karena itu, siapa pun yang menjalankan `rokit install` di workstation harus menyetujui kelima tool satu per satu pada pemasangan pertama.
- `rokit` mencetak `no oauth token found for github.com` sebelum memasang. Pemasangan tetap berhasil karena kelima repo rilis bersifat publik; token baru dibutuhkan bila kuota API GitHub terlampaui.

Yang **TIDAK TERVERIFIKASI**: eksekusi lewat shim. Setelah install, `.rokit/bin/stylua` adalah Mach-O arm64 yang benar (`file` → `Mach-O 64-bit executable arm64`), tetapi **kelima** shim gagal dipanggil dengan pesan identik:

```
stylua     ERROR Resource temporarily unavailable (os error 35)
selene     ERROR Resource temporarily unavailable (os error 35)
luau-lsp   ERROR Resource temporarily unavailable (os error 35)
lune       ERROR Resource temporarily unavailable (os error 35)
rojo       ERROR Resource temporarily unavailable (os error 35)
```

Kegagalan ini milik lingkungan mesin ini (sandbox proses), bukan kesalahan format `rokit.toml` — `rokit list` membaca kelima entri tanpa keluhan. Pekerjaan di sesi ini karena itu memakai binary di `/tmp/ci-tools/`, dan CI tidak memakai `rokit` sama sekali (ia mengunduh aset rilis langsung dengan checksum). Ini bagian dari `06-register-celah.md` C-04, **ESKALASI →** Nathan — CTO/CIO.

### 4.6 Uji end-to-end pada pohon gabungan EXTA-32 + EXTA-34

Tujuan uji ini: membuktikan bahwa **konfigurasi final PR ini tidak merusak kode EXTA-32**, dan bahwa rantai CI lolos pada pohon yang sebenarnya akan ada setelah kedua PR mendarat. Pohon uji = `git archive` dari branch EXTA-32 (`agent/nathan-cto-cio/62ee7feb5e5a`), lalu keempat berkas config PR ini + `.gitignore` + `.github/workflows/ci.yml` di-overlay. Toolchain: StyLua 2.5.2, selene 0.32.0, lune 0.10.5, rojo 7.7.1, luau-lsp 1.70.1.

Seluruh tabel ini **diukur ulang 2026-10-04 setelah konfigurasi dibekukan** (pohon segar dari `git archive`, lima berkas di-overlay dari isi final PR ini). Langkah 1–5 memakai perintah persis seperti di `.github/workflows/ci.yml`; langkah 6 memakai baris `luau-lsp analyze` yang sama tanpa tambahan flag.

| # | Perintah | Exit | Output |
|---|---|---|---|
| 1 | `stylua --config-path stylua.toml --check .` | **0** | (tanpa keluaran) |
| 2 | `selene generate-roblox-std` | **0** | `roblox.yml` 760203 byte |
| 3 | `selene --config selene.toml .` | **0** | `0 errors / 0 warnings / 0 parse errors` |
| 4 | `rojo sourcemap default.project.json --output sourcemap.json` | **0** | `Created sourcemap at sourcemap.json` |
| 5 | `lune run tests/run.luau` | **0** | `287 assertion, 0 gagal` / `SEMUA LULUS` |
| 6 | `luau-lsp analyze … src` | **1** | 8 galat tipe di `src/` — lihat §3.5 |

Langkah 1–5 hijau, jadi keputusan penyelarasan versi (§3.1) dan penggabungan `.luaurc` (§2.1) **tidak** merusak apa pun. Langkah 6 merah karena galat bawaan EXTA-32; itulah dasar `continue-on-error: true` di §3.5.

Kontrol negatif untuk langkah 1: `stylua --check .` dengan `column_width = 120` pada pohon yang sama → **exit 1**. Jadi `column_width = 100` bukan selera, melainkan nilai yang membuat kode EXTA-32 lolos.

### 4.7 Guard inert teramati pada PR nyata (bukan lagi asumsi)

Sebelumnya status "pipeline belum berjalan" hanya bisa dinyatakan dari `actions/workflows` → `total_count: 0`. Setelah branch PR ini di-push, GitHub **mendaftarkan workflow** dan **memicu satu run** — jadi guard-nya sekarang teramati bekerja, bukan disimpulkan.

Potret 2026-10-04 11:14 UTC, PR #13:

| Perintah | Hasil |
|---|---|
| `gh api repos/jettapindika/triangulate/actions/workflows` | `total_count: 1` — `CI`, path `.github/workflows/ci.yml`, `state: active` |
| `gh api .../actions/runs` | `total_count: 1` — `name: CI`, `event: pull_request`, `status: completed`, `conclusion: skipped` |
| `gh api .../actions/runs/37198053872/jobs` | empat job (`lint`, `analyze`, `test`, `validate-case`), **semuanya `conclusion: skipped`, `steps: 0`** |
| `gh pr checks 13` | `analyze skipping`, `lint skipping`, `test skipping`, `validate-case skipping` |

`steps: 0` pada keempat job adalah buktinya: tidak satu pun langkah dijalankan, jadi **tidak ada menit Actions yang ditagih** dan tidak ada unduhan tool. Penyebabnya `vars.CI_ENABLED` yang kosong (repo variables `total_count: 0`) — persis yang dimaksud guard di §3.3.

Dua konsekuensi yang perlu dicatat:

1. **Angka `actions/workflows` bergerak.** Nilainya `1` selama branch PR ini ada, dan akan kembali `0` bila branch dihapus tanpa merge. Karena itu `01-inventaris-repo-environment.md` mencatat `total_count: 0` sebagai potret **sebelum** push, dan itu tidak salah — hanya beda waktu.
2. **Workflow terdaftar bukan berarti CI aktif.** Yang aktif adalah *pendaftaran* workflow; eksekusinya masih nol. "CI jalan" baru benar setelah `CI_ENABLED` diset dan ada job dengan `conclusion: success`.

## 5. Gate sebelum merge

### 5.1 Aktivasi dan deaktivasi

```bash
# Aktifkan — owner / Nathan — CTO/CIO. Belum dijalankan.
gh variable set CI_ENABLED --body true --repo jettapindika/triangulate

# Matikan kembali tanpa menghapus workflow
gh variable delete CI_ENABLED --repo jettapindika/triangulate

# Verifikasi keadaan
gh api repos/jettapindika/triangulate/actions/variables
```

`gh api repos/.../actions/variables` saat ini mengembalikan `{"total_count": 0, "variables": []}` — jadi `CI_ENABLED` memang belum ada, dan pipeline memang belum berjalan.

**ESKALASI →** Nathan — CTO/CIO (aktivasi dan biaya menit).

### 5.2 Required status check

Setelah `CI_ENABLED` diset dan satu PR sudah memperlihatkan check `lint`, `analyze`, `test` muncul, barulah proteksi `main` dipasang. Urutan ini penting: memasang required check **sebelum** check-nya pernah muncul akan memblokir semua merge karena check yang tidak pernah dilaporkan dianggap "pending".

Perintah di bawah **tidak dijalankan** oleh Devan. Ini usulan; pemegang keputusan Nathan — CTO/CIO, eksekutor pemegang token owner. Isinya selaras dengan `02-checklist-koneksi-repo.md` §2.1.

```bash
gh api --method PUT repos/jettapindika/triangulate/branches/main/protection \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["lint", "analyze", "test"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true,
  "required_linear_history": true
}
JSON
```

`validate-case` sengaja **tidak** dimasukkan ke `contexts` karena job itu bergantung pada berkas milik EXTA-33 yang belum ada. Memasukkan check yang belum pernah hijau akan memblokir semua merge. Tambahkan setelah validator mendarat.

Catatan penting soal `analyze`: selama `continue-on-error: true` masih terpasang (§3.5), job `analyze` **selalu** selesai dengan status sukses — galat tipe muncul sebagai anotasi `::warning::`, bukan sebagai kegagalan job. Jadi mencantumkannya di `contexts` sekarang tidak berbahaya (tidak akan pernah memblokir), tetapi juga **belum memberi gerbang tipe apa pun**. `analyze` baru benar-benar bergerbang setelah syarat di §3.5 dipenuhi. Kalau owner ingin `contexts` mencerminkan gerbang yang nyata hari ini, isi saja `["lint", "test"]`.

#### Job `skipped` dan required check — satu jebakan yang harus dihindari

Guard `vars.CI_ENABLED` ada di tingkat **job**, dan itu pilihan yang disengaja. Bedanya menentukan:

| Bentuk skip | Check yang dilaporkan | Akibat di required status check |
|---|---|---|
| Job di-skip oleh `if:` di tingkat job (dipakai di sini) | job dilaporkan `skipped` | **Dianggap sukses** — tidak memblokir merge |
| Seluruh workflow tidak terpicu oleh filter `paths:`/`branches:` | **tidak ada check yang dilaporkan** | **Menunggu selamanya** — PR tidak bisa merge tanpa jalan keluar |

Sumber: dokumentasi GitHub untuk troubleshooting required status checks. `TIDAK TERVERIFIKASI` di repo ini karena memasang proteksi bukan tindakan Devan — yang bisa diukur di sini hanya sisi Actions-nya, dan itu sudah diukur (§4.7: keempat job `skipped`, `steps: 0`).

Konsekuensi yang mengikat siapa pun yang menyunting `ci.yml` nanti:

- **Jangan pernah menambahkan `on.pull_request.paths` atau `paths-ignore` ke workflow ini** selama `lint`/`analyze`/`test` menjadi required check. Filter tingkat workflow mengubah skip dari "dilaporkan" menjadi "tidak dilaporkan", dan itu memblokir semua merge tanpa pesan yang menjelaskan. Penyaringan berdasarkan keberadaan berkas sudah ditangani di tingkat step (§3.3) justru untuk alasan ini.
- Efek samping yang menguntungkan: menonaktifkan kembali `CI_ENABLED` (mis. saat repo sedang dibekukan) **tidak** mengunci PR — job menjadi `skipped` dan tetap dianggap sukses.

`ASUMSI`: `required_approving_review_count: 1` hanya berguna bila ada peninjau kedua. Hari ini hanya `jettapindika` yang punya akses (`gh api repos/.../collaborators` → satu collaborator, `admin`), dan commit agent semuanya ber-author akun yang sama. Dengan satu identitas, GitHub tidak bisa membedakan penulis dari peninjau — lihat `06-register-celah.md` C-01. Yang memverifikasi: penambahan collaborator/machine user.

### 5.3 Yang membuat PR tidak bisa merge

| Kondisi | Check yang merah | Siapa yang memperbaiki |
|---|---|---|
| Format tidak sesuai `stylua.toml` | `lint` | penulis PR |
| Variabel tak terdefinisi / salah pakai std | `lint` | penulis PR |
| Tipe tidak konsisten di bawah `--!strict` | `analyze` | penulis PR |
| Runner uji `tests/run.luau` gagal | `test` | penulis PR |
| Berkas kasus tidak sesuai skema | `validate-case` | penulis kasus (EXTA-33) |

## 6. Lampiran — bukti mentah

Blok-blok di bawah adalah keluaran **apa adanya** dari pengukuran **pertama** (2026-10-04, layout tiruan `/tmp/ci-repo/`, toolchain 2.1.0 / 0.28.0 / 0.10.4, `stylua.toml` draf). Angka versi dan ukuran di sini **bukan** konfigurasi final — nilai final ada di §3.1 (versi terpin), §4.4 (aset rilis) dan §4.6 (pengukuran ulang pada pohon gabungan). Lampiran ini dipertahankan karena ia bukti bahwa jalur merah benar-benar dipicu, bukan dikarang.

```
$ cd /tmp/ci-repo && stylua --config-path stylua.toml --check .
EXIT=0

$ selene generate-roblox-std
Generating Roblox standard library...
EXIT=0
$ ls -la roblox.yml
-rw-r--r--  1 mac  wheel  601707  roblox.yml
$ head -3 roblox.yml
# This file was @generated by generate-roblox-std at 2026-10-04 17:45:06.808711 +07:00
base: luau
name: roblox

$ selene --config selene.toml .
Results:
0 errors
0 warnings
0 parse errors
EXIT=0

$ rojo sourcemap default.project.json --output sourcemap.json
Created sourcemap at sourcemap.json
EXIT=0

$ luau-lsp analyze --definitions=.../g-1.70.1.luau --sourcemap=sourcemap.json --base-luaurc=.luaurc src
[WARN] client does not allow didChangeWatchedFiles registration - automatic updating on sourcemap changes disabled
[INFO] Loading Luau configuration from /private/tmp/ci-repo/.luaurc
EXIT=0

$ lune run tests/run.luau
PASS 2
EXIT=0

$ lune run tools/validate-case.luau
validasi kasus: OK
EXIT=0
```

```
$ shasum -a 256 -c checksums.txt
66a8e8d68003848d23bd7dfca95e3d0e7b96bd19658879b1f8b39d992f3be331  stylua-linux-x86_64.zip: OK
5d8706751968486d46d120316b108154693052f75af60efb3dbf4d4cf9e4d902  selene-0.28.0-linux.zip: OK
1a2ea1ae4f98f8946cefd970a4b54853e11ab4775e6932faa7f60cf920346567  luau-lsp-linux-x86_64.zip: OK
ffba0bd404ae078c9543ef5ac12479938a741aab255768a11a08517ae963b288  lune-0.10.4-linux-x86_64.zip: OK
00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4  rojo-7.7.1-linux-x86_64.zip: OK
EXIT=0
```

```
$ actionlint -color .github/workflows/ci.yml
EXIT=0
```

```
$ sandbox-exec -p '(version 1)(allow default)(deny network*)' selene generate-roblox-std
Generating Roblox standard library...
ERROR: Couldn't create Roblox standard library:
   0: error when getting API dump
   1: https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json: Dns Failed: resolve dns name 'raw.githubusercontent.com:443': failed to lookup address information: nodename nor servname provided, or not known
EXIT=1
$ ls roblox.yml
ls: cannot access 'roblox.yml': No such file or directory
```

## 7. Biaya

**ESKALASI →** Michelle — CFO (biaya menit Actions pada repo private) dan **ESKALASI →** Nathan — CTO/CIO (keputusan aktifkan).

Repo `jettapindika/triangulate` **private**, jadi menit Actions dihitung terhadap kuota akun. Yang bisa dinyatakan tanpa mengarang angka:

- Selama `CI_ENABLED` belum diset, **0 menit** terpakai — job `skipped` tidak ditagih.
- Job `lint` adalah yang paling murah dan paling sering berguna; ia juga yang paling awal gagal.
- `concurrency.cancel-in-progress: true` membatalkan run lama pada branch yang sama, sehingga push beruntun tidak menumpuk.
- `timeout-minutes` dipasang di setiap job (`lint` 10, `analyze` 15, `test` 10, `validate-case` 10) sebagai batas atas bila ada langkah yang menggantung.
- Cache toolchain ber-key versi tool, sehingga unduhan 3–6 MB per tool hanya terjadi sekali per versi per OS.

`TIDAK TERVERIFIKASI`: angka menit per run. Tidak ada run yang pernah terjadi (`gh api repos/.../actions/workflows` → `{"total_count": 0}`), jadi angka apa pun di sini akan karangan. Yang memverifikasi: halaman Billing → Actions setelah run pertama.

## 8. Yang TIDAK dicakup pipeline ini

| Tidak tercakup | Sebab |
|---|---|
| Verifikasi perilaku runtime Roblox | Tidak ada Roblox Studio di runner; `game`, `DataStoreService`, dan `TeleportService` tidak ada di luar Roblox |
| Server-authoritative sebagai sifat yang teruji (PRD §15) | CI hanya memeriksa tipe dan lint. Bahwa state kasus/solusi benar-benar tidak terekspos ke client adalah sifat arsitektur, bukan sesuatu yang bisa dibuktikan linter. Yang memverifikasi: review PR EXTA-32/EXTA-33 dan uji manual di Studio |
| Perilaku mobile kelas bawah (PRD §15, §18 "puzzle blur di mobile") | Butuh perangkat nyata; ini spike minggu 0 (PRD §17), bukan CI. Tidak ada emulator Roblox di runner |
| Resolusi tekstur dan `ImageRectOffset`/`ImageRectSize` | idem — butuh Studio dan perangkat |
| Telemetri per role (PRD §15, §11–§12) | Skema dan pengiriman event belum ada; tidak ada yang bisa diuji |
| Deploy / publish place ke Roblox | Tidak ada workflow rilis dan tidak ada `ROBLOX_OPEN_CLOUD_API_KEY` (`04-manajemen-secret.md` §2). Pipeline ini hanya memeriksa, tidak merilis |
| Backup dan restore | Milik `05-backup-restore.md` dan `scripts/backup-repo.sh`, bukan pipeline ini. CI ini tidak menjadwalkan apa pun |
| Manajemen secret | Milik `04-manajemen-secret.md`. Workflow ini hanya memakai `GITHUB_TOKEN` bawaan dengan `permissions: contents: read` |
| Validator skema kasus | Milik EXTA-33 (Nathan — CTO/CIO), PR #10, calon lokasi `tools/validate-case.luau`. Job `validate-case` hanya menyediakan jalur masuknya |
| Layout `src/` dan `default.project.json` | Milik EXTA-32 (Nathan — CTO/CIO). Dokumen ini mengasumsikan layoutnya dan merujuknya |
| Perbaikan celah apa pun | Batas peran: diusulkan, bukan dijalankan. Lihat `06-register-celah.md` |
| Angka menit dan biaya konkret | Butuh plan GitHub; lihat §7 |
