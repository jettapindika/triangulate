Status: DRAFT — usulan, belum aktif
Pemilik: Devan — Infrastructure & Runtime Engineer
Rujukan: PRD §15, §17, §18 · `exta-infra-runbook` §1–§5

# Register Celah Infrastruktur — Triangulate

Setiap baris adalah temuan dengan bukti perintah, dampak, dan pemilik keputusan. **Tidak satu pun diperbaiki di sini** — perbaikan infrastruktur diusulkan, bukan dijalankan (`exta-infra-runbook` §Aturan besi).

Peringkat risiko: **Kritis** = memblokir kerja atau membocorkan akses hari ini · **Tinggi** = akan menggigit dalam 1–2 minggu · **Sedang** = perlu sebelum rilis · **Rendah** = higienis.

## Ringkasan peringkat

| Peringkat | Jumlah | Nomor |
|---|---|---|
| Kritis | 2 | C-01, C-02 |
| Tinggi | 5 | C-03, C-04, C-05, C-06, C-13 |
| Sedang | 3 | C-07, C-08, C-09 |
| Rendah | 3 | C-10, C-11, C-12 |

Yang paling mendesak bukan CI, melainkan **identitas tulis tunggal** (C-01) — selama semua agent menulis lewat satu akun GitHub ber-permission `admin`, setiap kontrol lain di daftar ini bisa dibuka kembali oleh proses yang sama.

## Kritis

### C-01 — Semua agent menulis lewat satu akun GitHub pribadi ber-permission admin

| | |
|---|---|
| Bukti | `gh api repos/jettapindika/triangulate/collaborators` → hanya `jettapindika`, `permission: admin`. Commit agent EXTA-45 `da96141` ber-author `jettapindika <jettapindika@gmail.com>`. Token lokal scope `repo` + `workflow`. |
| Dampak | Tidak ada pemisahan hak antara "agent yang menulis kode" dan "pihak yang mengatur proteksi branch, secret, dan workflow". Satu kebocoran token memberi `admin` penuh ke repo. Atribusi commit tidak bisa dipakai untuk audit — semua commit tampak dari orang yang sama. `required_pull_request_reviews` tidak bisa berfungsi sebagai pemisahan tugas karena GitHub hanya melihat satu identitas. |
| Risiko turunan | Secret Roblox apa pun yang kelak ditaruh di repo secret bisa dikeluarkan oleh siapa pun yang bisa membuka PR yang mengubah `.github/workflows/`. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO (lalu owner untuk izin) |
| Usulan | Buat machine user GitHub dengan permission `write` saja untuk agent; simpan identitas owner hanya untuk administrasi. Sampai itu ada, jangan taruh kredensial Roblox di repo secret. |

### C-02 — `main` tanpa proteksi apa pun

| | |
|---|---|
| Bukti | `gh api repos/jettapindika/triangulate/branches/main/protection` → HTTP 404 `"Branch not protected"`. `gh api repos/.../rulesets` → `[]`. `gh api "repos/.../branches?per_page=100"` → kedua belas branch `protected: false`. |
| Dampak | Push langsung ke `main` bisa dilakukan; PR bisa di-merge tanpa review; force-push dan penghapusan branch tidak dilarang. Sebelas PR yang sekarang terbuka menargetkan `main` tanpa satu pun gate. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO |
| Usulan | Pasang proteksi di `02-checklist-koneksi-repo.md` §2.1 — **setelah** pipeline CI mendarat dan check-nya terbukti muncul, supaya required check tidak memblokir semua merge. |

## Tinggi

### C-03 — Tidak ada CI yang berjalan, dan tidak ada satu pun check yang memeriksa PR

| | |
|---|---|
| Bukti | Saat potret: `gh api repos/.../actions/workflows` → `{"total_count": 0, "workflows": []}`; `gh api repos/.../actions/runners` → 0 runner; PR terbuka tanpa status check. Setelah PR #13 (EXTA-34) dibuka: workflow `CI` **terdaftar** (`total_count: 1`) dan setiap push memicu satu run — potret 2026-10-04 11:52Z mencatat tujuh run, semuanya `conclusion: skipped` dengan **keempat job `skipped`, `steps: 0`** karena repo variable `CI_ENABLED` tidak ada (`total_count: 0`). Sementara itu **empat PR (#10, #11, #14, #15) sudah di-merge ke `main` tanpa satu pun gate** — membuktikan bahwa ketiadaan gate punya konsekuensi nyata, bukan teoretis. Rincian di `03-pipeline-ci.md` §4.7. |
| Dampak | Tidak ada sinyal otomatis apa pun sebelum merge. Kesalahan format, kode mati, dan kasus JSON yang tidak valid bisa masuk `main` tanpa terdeteksi. PRD §17 menargetkan playtest minggu 7 — tanpa CI, regresi baru ketahuan saat playtest. Workflow yang terdaftar tetapi selalu `skipped` tidak mengubah apa pun: ia hanya membuat PR menampilkan empat check berwarna abu-abu alih-alih "no checks", dan check abu-abu yang tidak pernah memeriksa justru bisa disalahbaca sebagai aman. |
| Pemilik keputusan | Devan (draft) → Nathan — CTO/CIO (aktivasi) |
| Usulan | Pipeline di `03-pipeline-ci.md`, dibuat inert lewat guard `vars.CI_ENABLED == 'true'` supaya tidak jalan sebelum owner mengaktifkan. **Aktivasi (`gh variable set CI_ENABLED --body true`) adalah satu-satunya langkah yang mengubah keadaan ini**, dan itu bukan tindakan Devan. |

### C-04 — Toolchain Luau tidak terpasang; `~/.rokit/bin` berisi symlink rusak

| | |
|---|---|
| Bukti | `command -v` untuk `stylua`, `selene`, `luau-lsp`, `rojo`, `lune`, `wally`, `aftman`, `rokit` → semuanya `NOT FOUND`. `~/.rokit/bin/selene` dan `~/.rokit/bin/stylua` adalah symlink ke `/Users/mac/.rokit/bin/rokit` yang **tidak ada** (`ls` → `No such file or directory`). `~/.rokit/rokit.toml` bagian `[tools]` **kosong**. Binary sebenarnya ada di `~/.rokit/tool-storage/{johnnymorganz/stylua/2.1.0,kampfkarren/selene/0.28.0}`. |
| Dampak | Setiap agent yang butuh `stylua`/`selene` harus mengunduh binary sendiri (itu yang terjadi di sesi ini: unduhan ke `/tmp/ci-tools/`). Tidak ada pinning versi terpusat, jadi dua agent bisa memakai versi berbeda dan menghasilkan format yang berbeda. Symlink rusak membuat `stylua`/`selene` tampak "terpasang" di `PATH` tetapi gagal saat dipanggil — kegagalan yang membingungkan. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO (perubahan environment workstation) |
| Usulan | Isi `~/.rokit/rokit.toml` `[tools]` dengan versi terpin dan pasang binary rokit yang hilang; jangan biarkan symlink rusak. Sebagian sudah dijawab di tingkat repo: `rokit.toml` di root repo (PR ini) memuat pin `StyLua 2.5.2`, `selene 0.32.0`, `lune 0.10.5`, `rojo 7.7.1`, `luau-lsp 1.70.1`, sehingga versi ikut ter-versi bersama kode. Yang **belum** beres: `~/.rokit/rokit.toml` global masih kosong dan symlink `~/.rokit/bin/*` masih rusak, jadi `rokit install` di workstation masih gagal lewat shim (lihat `03-pipeline-ci.md` §4.5). |

### C-05 — `multica repo list` kosong padahal repo terpakai

| | |
|---|---|
| Bukti | `multica repo list --output json` → `[]`. Sementara `multica repo checkout https://github.com/jettapindika/triangulate` berhasil, dan `multica project resource list 0bca82b8-…` mengembalikan satu resource `github_repo` (`a94a5d66-b3cd-4b4e-a40d-3e76c8c6d8dc`). |
| Dampak | Perintah yang paling wajar dipakai untuk audit koneksi repo memberi jawaban "tidak ada repo". Setiap laporan inventaris yang hanya memakai perintah itu akan salah. `exta-infra-runbook` §2 sendiri menyatakan "`multica repo list` → 0 repository" sebagai dasar kesiapan — angka itu menyesatkan. |
| Pemilik keputusan | Devan (koreksi dokumen) · **ESKALASI →** Nathan — CTO/CIO kalau mau repo juga didaftarkan di registry workspace |
| Usulan | Perbaiki `exta-infra-runbook` §2 agar menyebut kedua jalur pendaftaran, dan cantumkan `multica project resource list <project-id>` sebagai sumber kebenaran. Pendaftaran ke registry workspace itu sendiri keputusan owner — belum jelas manfaatnya. |

### C-06 — Tidak ada peringatan kerentanan dan tidak ada secret scanning

| | |
|---|---|
| Bukti | `gh api repos/.../vulnerability-alerts` → HTTP 404 `"Vulnerability alerts are disabled."`. `gh api repos/...` → `"security_and_analysis": null`. |
| Dampak | Dependabot dan secret scanning mati. Repo ini akan menyimpan skrip CI yang menyentuh kredensial Roblox (PRD §15). Secret yang ter-commit tidak akan tertangkap oleh apa pun — dan dengan identitas `admin` tunggal (C-01), konsekuensinya langsung. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO |
| Usulan | Aktifkan vulnerability alerts + secret scanning + push protection. `ASUMSI`: ketersediaan untuk repo private bergantung plan — `gh api user --jq .plan` mengembalikan `null`, jadi harus dibaca dari Settings → Code security. |

### C-13 — `luau-lsp analyze` tidak bisa jadi gerbang: 8 galat tipe di `src/`, dan `globals` melemahkan pemeriksaan

| | |
|---|---|
| Bukti | Pada pohon EXTA-32 + EXTA-34, `luau-lsp analyze --definitions=<tag 1.70.1> --sourcemap=sourcemap.json --base-luaurc=.luaurc src` → **8 galat tipe, exit 1**. Lokasinya: `src/server/NPCController.luau:53`, `src/server/CaseLoader.luau:152`, `src/server/init.server.luau:135,189,197,224,505,522`. Rincian per baris di `03-pipeline-ci.md` §3.5. Terpisah dari itu, uji minimal membuktikan entri `globals` di `.luaurc` **dibaca** luau-lsp dan mendeklarasikan nama sebagai `any`: `Instance.new("Part")` + `local n: number = p.Name` **tertangkap** tanpa entri `Instance` di `globals`, dan **lolos** begitu entri itu ditambahkan. |
| Dampak | Dua-duanya melemahkan gerbang tipe. (a) Karena 8 galat itu ada, langkah `analyze` di CI dipasang `continue-on-error: true` — kalau tidak, `needs` berantai membuat `test` dan `validate-case` ikut ter-skip. Artinya **merge saat ini tidak diperiksa tipe sama sekali**. (b) Daftar `globals` memuat 11 nama API Roblox (`script`, `game`, `workspace`, `Instance`, `Enum`, `Vector2`, `Vector3`, `CFrame`, `Color3`, `UDim2`, `Rect`), yang membuat anggota API itu tidak lagi diperiksa terhadap definisi resmi. Pada kode hari ini keduanya tidak mengubah jumlah galat (8 dengan maupun tanpa `globals`), jadi ini utang yang belum berbunga — tetapi akan berbunga saat `src/` tumbuh. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO (`src/` milik EXTA-32; keputusan memperbaiki ada di sana) |
| Usulan | Bereskan 8 galat tipe di `src/`, lalu pangkas nama API Roblox dari `globals` di `.luaurc`, lalu lepas `continue-on-error` dan jadikan `analyze` required check. Urutannya ada di `03-pipeline-ci.md` §3.5. |

## Sedang

### C-07 — Satu bare git cache dipakai bersama 18 worktree

| | |
|---|---|
| Bukti | `git rev-parse --git-common-dir` → `.repos/22efef6c-…/github.com+jettapindika+triangulate.git`. `git worktree list` → 18 worktree aktif dari bare cache yang sama. |
| Dampak | Perintah yang mengubah state bare cache (`git gc`, `git remote prune`, `git worktree prune`) menyentuh seluruh task yang sedang berjalan — satu task bisa merusak 17 task lain. Ref remote-tracking di satu worktree bisa basi relatif terhadap worktree lain, sehingga `git branch -vv` menyesatkan (di sesi ini branch `bagas` tampak di `a7500a1` padahal remote sudah `f4c9e58` sebelum fetch). |
| Pemilik keputusan | Devan (aturan operasional) |
| Usulan | Aturan tertulis: agent tidak menjalankan perintah pemeliharaan bare cache. Untuk membaca keadaan remote, pakai `gh api` atau `git ls-remote`, bukan ref lokal. |

### C-08 — 6 dari 7 runtime terdaftar tanpa satu pun agent terikat

| | |
|---|---|
| Bukti | `multica runtime list --output json` → 7 runtime `online`. `multica agent list --output json` → `runtime_id` ke-20 agent semuanya `a82fac41-c20d-40e8-82f1-6e3b5a384796` (Oh-My-Pi). Empat runtime lain di daemon `01a0d465` (Claude `30ed3374`, Codex `35a06a66`, Hermes `c82aef94`, Pi `0a1b01de`) dan dua runtime VPS (`c2253983`, `711a58a8`) tidak melayani agent mana pun. |
| Dampak | Permukaan yang harus dipelihara (update, kredensial, port, proses) tanpa manfaat yang bisa ditunjukkan. Daemon `01a0d465` juga menanggung **seluruh** beban 20 agent dengan `active_task_count` 5–17 saat pembacaan; kapasitas tidak punya cadangan terpakai. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO |
| Usulan | Entah pindahkan sebagian agent ke runtime VPS (yang memang `online`) sebagai cadangan, atau matikan runtime yang tidak dipakai. Biarkan tidak menganggur tanpa keputusan. |

### C-09 — Tidak ada backup yang berjalan, dan hanya repo yang bisa diuji

| | |
|---|---|
| Bukti | `scripts/backup-repo.sh` dan `scripts/restore-drill.sh` ada dan sudah lolos uji end-to-end untuk repo (2026-10-04). Tidak ada jadwal otomatis: workflow `CI` yang terdaftar masih inert dan tidak memuat langkah backup, 0 cron. DataStore Roblox belum ada sehingga tidak bisa diuji sama sekali; `data/cases/` kini **sudah ada** dan ikut tercakup jalur git (`05-backup-restore.md` §2). |
| Dampak | Backup repo bergantung pada seseorang yang ingat menjalankan skrip. Aset yang paling mahal untuk hilang — state sesi + telemetri pemain (PRD §11, §12, §15) — belum punya backup dan belum bisa punya sampai ada kredensial Open Cloud. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO (kredensial Open Cloud, penjadwalan) · Michelle — CFO kalau penyimpanan berbayar |
| Usulan | Jadwalkan `backup-repo.sh` harian lewat cron lokal atau workflow terjadwal begitu CI aktif. DataStore menunggu kredensial Open Cloud. |

## Rendah

### C-10 — `delete_branch_on_merge` mati dan tiga mode merge aktif sekaligus

| | |
|---|---|
| Bukti | `gh api repos/...` → `delete_branch_on_merge: false`, `allow_merge_commit: true`, `allow_squash_merge: true`, `allow_rebase_merge: true`. |
| Dampak | Branch `agent/<slug>/<hash>` menumpuk setelah PR merge (`delete_branch_on_merge: false`; sudah 14 branch `agent/*` di remote). Tiga mode merge berarti riwayat `main` tidak konsisten antar PR. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO |
| Usulan | `delete_branch_on_merge: true`; sisakan squash saja. Perintah di `02-checklist-koneksi-repo.md` §3. |

### C-11 — Wiki aktif, dokumen proyek tidak

| | |
|---|---|
| Bukti | `gh api repos/...` → `has_wiki: true`, `has_issues: true`, `has_discussions: false`. Tidak ada halaman wiki. |
| Dampak | Wiki tidak ikut review PR dan tidak ikut backup repo — kalau dipakai, dokumen akan menyimpang dari `docs/`. `has_issues: true` padahal issue kerja ada di Multica, jadi ada dua ruang nomor issue yang bisa tertukar saat menulis `Closes #n`. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO |
| Usulan | `has_wiki: false`. `has_issues` biarkan `true` (tidak mengganggu) tetapi jangan pakai GitHub Issues. |

### C-12 — Disk workspace menumpuk tanpa kebijakan retensi

| | |
|---|---|
| Bukti | `multica daemon disk-usage --output json` → 56 task, 99.205.172 byte (≈ 94,6 MiB) total, 33.200.281 byte (≈ 31,7 MiB) di antaranya artefak. Terbesar: `task-fadb1cb8f2e5` 43,2 MiB (umur 834.637 detik ≈ 9,7 hari), `exta-33-29b1baaaf335` 38,2 MiB. Angka naik setiap task baru dibuat — potret 2026-10-04, bukan nilai tetap. |
| Dampak | Belum mendesak pada ~95 MiB, tetapi tumbuh tiap task dan tidak ada kebijakan pembersihan. Satu task `chat` berumur ~9,7 hari menyimpan 31,7 MiB artefak yang tidak dirujuk siapa pun. |
| Pemilik keputusan | **ESKALASI →** Nathan — CTO/CIO |
| Usulan | Kebijakan retensi: hapus artefak task `chat` yang lebih tua dari N hari; jalankan `multica daemon disk-usage` sebagai pemeriksaan berkala. |

## Yang TIDAK tercakup register ini

| Tidak tercakup | Sebab |
|---|---|
| Perbaikan apa pun | batas peran: diusulkan, bukan dijalankan |
| Celah keamanan pada kode game (`src/`) | bukan domain infra; milik EXTA-32 |
| Kepatuhan rating Roblox 13+ | PRD §14, milik EXTA-40/EXTA-39 |
| Biaya konkret menit Actions dan penyimpanan | butuh plan GitHub + keputusan Michelle — CFO |
| Celah pada runtime VPS (`01a0d46b`, `01a0d46c`) | tidak ada akses SSH dari workstation ini; hanya status daftar yang terbaca |
| Verifikasi bahwa check CI benar-benar muncul di PR | pipeline belum di-merge |
