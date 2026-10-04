Status: DRAFT — usulan, belum aktif
Pemilik: Devan — Infrastructure & Runtime Engineer
Rujukan: PRD §15 (Persyaratan Teknis), §17 (Roadmap 8 minggu), §18 (Risiko)

# Inventaris Repo & Environment — Triangulate

Semua baris di bawah adalah hasil perintah yang benar-benar dijalankan pada **2026-10-04** di workstation `ztvns-Mac.local`. Setiap tabel menyebutkan perintah sumbernya. Angka yang belum bisa dipastikan ditandai `ASUMSI` atau `TIDAK DIKETAHUI` — tidak ada angka yang dikarang.

## 1. Ringkasan kondisi

| Hal | Keadaan hari ini | Sumber |
|---|---|---|
| Repo terhubung ke Multica | 1, sebagai **project resource** (bukan registry workspace) | `multica project resource list`, `.multica/project/resources.json` |
| Registry repo workspace | **kosong** (`[]`) | `multica repo list --output json` |
| CI berjalan | **tidak ada** — 0 workflow terdaftar | `gh api repos/jettapindika/triangulate/actions/workflows` |
| Branch protection / ruleset | **tidak ada** — `main` terbuka untuk push langsung | `gh api repos/.../branches/main/protection` → HTTP 404 |
| Tinjauan berbasis PR | 11 PR terbuka, **belum ada yang di-merge**; tidak ada review yang diwajibkan | `gh pr list --state all`, `gh api repos/.../branches/main/protection` |
| Secret di repo | 0 repo secret, 0 repo variable | `gh api repos/.../actions/secrets`, `.../variables` |
| Toolchain Luau di workstation | **tidak terpasang** (`stylua`, `selene`, `luau-lsp`, `rojo`, `lune` → not found) | `which` |
| Runtime agent | 7 terdaftar `online`; 20 agent semuanya terikat ke satu runtime | `multica runtime list`, `multica agent list` |

Konsekuensi yang harus dinyatakan jujur: **belum ada satu pun operasi CI/CD yang berjalan.** Yang ada di issue ini adalah kesiapan + standar, bukan operasi harian yang boleh diklaim sudah jalan. Ini sejalan dengan batas peran Devan di `exta-infra-runbook` §2.

Alur kerja PR **sudah terbukti jalan** (11 PR terbuka dari 11 agent berbeda, semuanya menargetkan `main`), tetapi **belum ada yang menegakkan apa pun**: tidak ada review wajib, tidak ada status check, tidak ada proteksi branch. PR hari ini adalah usulan murni — persis seperti yang diminta EXTA-31 — dan tetap begitu sampai gate di `02-checklist-koneksi-repo.md` diaktifkan.

## 2. Inventaris repo

| Repo | URL | Visibilitas | Default branch | Pemilik akses | Commit terakhir | Dibuat |
|---|---|---|---|---|---|---|
| triangulate | `https://github.com/jettapindika/triangulate` | private | `main` | `jettapindika` (admin, satu-satunya collaborator) | `5c5f59a` — "EXTA-31: bootstrap repo dengan PRD v0.2 dan struktur awal", 2026-10-04 17:08:23 +0700 | 2026-10-04T10:02:01Z |

Perintah: `gh api repos/jettapindika/triangulate`, `gh api repos/jettapindika/triangulate/collaborators`, `gh pr list --repo jettapindika/triangulate --state all`.

Isi repo saat ini (3 file, hasil `git ls-tree -r --name-only origin/main`):

| Path | Isi | Pemilik |
|---|---|---|
| `README.md` | Judul proyek, penunjuk ke PRD dan EXTA-31 | bootstrap EXTA-31 |
| `.gitignore` | `*.rbxl`, `*.rbxlx`, `*.rbxm`, `*.rbxmx`, `build/`, `.rojo/`, `*.lock`, `.DS_Store` | bootstrap EXTA-31 |
| `docs/prd-v0.2.md` | PRD v0.2 lengkap | bootstrap EXTA-31 |

Setting repo yang relevan untuk gate merge (`gh api repos/jettapindika/triangulate`):

| Setting | Nilai hari ini | Usulan | Alasan |
|---|---|---|---|
| `delete_branch_on_merge` | `false` | `true` | branch `agent/<slug>/<hash>` menumpuk setelah PR merge; membersihkan otomatis |
| `allow_merge_commit` / `allow_squash_merge` / `allow_rebase_merge` | ketiganya `true` | `squash` saja | satu PR = satu commit; riwayat `main` terbaca per workstream |
| `has_wiki` | `true` | `false` | dokumen hidup di `docs/` supaya ikut review PR, bukan di wiki yang tak terversi |
| `has_issues` | `true` | biarkan | issue kerja tetap di Multica; issue GitHub tidak dipakai |

Catatan `ASUMSI`: `has_wiki=false` dan `squash` saja adalah preferensi Devan, bukan keputusan owner. Menunggu persetujuan di issue ini sebelum dieksekusi.

### 2.1 Cara repo terdaftar (ini celah, bukan sekadar catatan)

`multica repo list --output json` mengembalikan `[]`, tetapi `multica repo checkout https://github.com/jettapindika/triangulate` **berhasil**. Sebabnya: repo terdaftar sebagai *project resource*, bukan di registry repo workspace.

| Jalur pendaftaran | ID | Isi | Ditambahkan |
|---|---|---|---|
| Project resource (`github_repo`) | `a94a5d66-b3cd-4b4e-a40d-3e76c8c6d8dc` | `{"url": "https://github.com/jettapindika/triangulate", "ref": "main"}` | 2026-10-04T10:02:19Z oleh user `7d0f72be-0576-4851-b3b3-902a384c28f0` |
| Registry repo workspace | — | kosong | — |

Perintah: `multica project resource list 0bca82b8-a11c-49a1-af4a-adef29d0569d --output json`, `multica repo list --output json`.

Artinya: perintah `multica repo list` **bukan** sumber kebenaran untuk "repo apa saja yang dipakai Exta". Ini masuk register celah di `06-register-celah.md` karena setiap audit koneksi repo berikutnya akan salah kalau hanya memakai perintah itu.

## 3. Inventaris branch & PR

Perintah: `gh api "repos/jettapindika/triangulate/branches?per_page=100"`, `gh api "repos/.../commits?sha=<branch>"`, `gh pr list --state all --json number,title,state,headRefName,baseRefName`.

Branch di remote (12 total, semuanya `protected: false`):

| Branch | Commit teratas | Dipakai issue | PR | Status |
|---|---|---|---|---|
| `main` | `5c5f59a` bootstrap EXTA-31 | — | — | tidak terproteksi, tidak ada CI |
| `agent/bima-automation-engineer/d01e413798e2` | `203478e` | EXTA-35 | **#8 OPEN** | menunggu review |
| `agent/kirana-narrative-board-secreta/86bd31128b54` | `e62ce30` | EXTA-49 | **#9 OPEN** | menunggu review |
| `agent/nadia-penulis-konten/278e0cc92537` | `afb2c55` | EXTA-38 | **#6 OPEN** | menunggu review |
| `agent/nathan-cto-cio/29b1baaaf335` | `962b958` | EXTA-33 | **#10 OPEN** | menunggu review |
| `agent/nathan-cto-cio/62ee7feb5e5a` | `327fe57` | EXTA-32 | **#11 OPEN** | menunggu review |
| `agent/rangga-decision-log-strategy-o/4e27c3c8182c` | `c8bc012` | EXTA-48 | **#7 OPEN** | menunggu review |
| `agent/bagas-process-writer/f48895845f9e` | `f4c9e58` EXTA-47 perjelas klaim lokasi MVP | EXTA-47 | **#4 OPEN** | menunggu review |
| `agent/bayu-pengawas-anggaran-risiko/111bb9f42fe8` | `c85c660` EXTA-44 register risiko | EXTA-44 | **#3 OPEN** | menunggu review |
| `agent/clara-cmo/506861bc5a55` | `26568e0` EXTA-41 hapus klaim kadens konten | EXTA-41 | **#2 OPEN** | menunggu review |
| `agent/dimas-pencatat-pengeluaran-har/068af65f3b7c` | `da96141` EXTA-45 template buku besar | EXTA-45 | **#1 OPEN** | menunggu review |
| `agent/rani-data-metrics-engineer/98b3f96538b5` | `d4bb57c` EXTA-36 kamus metrik | EXTA-36 | **#5 OPEN** | menunggu review |
| `agent/devan-infrastructure-runtime-e/bd869e15e75b` | dokumen CI + workflow draft | EXTA-34 | dibuka oleh issue ini | branch kerja Devan |

Base setiap PR: `main`. Merge: belum ada satu pun. Angka bergerak cepat — repo ini menerima PR baru dari workstream lain setiap beberapa menit, jadi tabel di atas adalah potret **2026-10-04 sekitar 10:30Z**, bukan nilai tetap.

Yang terbaca dari data ini, dan relevan untuk desain gate:

1. **Konvensi judul PR sudah benar tanpa dipaksa.** Kesebelas PR memakai prefiks `EXTA-<n>: ` — jadi aturan "judul PR memuat identifier issue" di `02-checklist-koneksi-repo.md` §4 bukan aturan baru, hanya formalisasi kebiasaan yang sudah jalan.
2. **Loop revisi sudah hidup.** Beberapa branch (`bagas`, `clara`, `kirana`, `bima`, `rangga`) punya commit kedua yang isinya perbaikan ("perjelas klaim", "hapus klaim") — artinya review manusia memang terjadi, hanya lewat percakapan, bukan lewat mekanisme GitHub.
3. **Tidak ada checks yang berjalan di PR mana pun.** `gh api repos/.../actions/workflows` → `total_count: 0`, jadi PR GitHub menampilkan "no checks" — reviewer tidak punya sinyal otomatis apa pun.
4. **Nama branch tidak memuat identifier issue.** Pola `agent/<slug-agent>/<12-hex-hash>` dibuat otomatis oleh `multica repo checkout`; hash-nya adalah id task, bukan nomor issue. Karena itu identifier **wajib** ada di judul PR — dan itu satu-satunya tempat ia bisa diandalkan.
5. **Tidak ada satu pun merge.** 11 PR terbuka, 0 merged. Tanpa gate, tidak ada yang memaksa keputusan merge — dan tanpa CI, tidak ada sinyal untuk memutuskan.

`ASUMSI`: hash 12-hex di nama branch adalah id task Multica (`bd869e15e75b` cocok dengan sufiks direktori task `exta-34-bd869e15e75b`). Yang memverifikasi: pemetaan ini konsisten untuk seluruh branch, tetapi tidak ada dokumentasi Multica yang menyatakannya secara eksplisit.

### 3.1 Satu checkout git dipakai bersama banyak worktree

`git branch -vv` di workstation ini memperlihatkan 18 branch `agent/*` yang ter-checkout dari **satu bare cache**:

```
.repos/22efef6c-.../github.com+jettapindika+triangulate.git/
```

Setiap task Multica mendapat worktree-nya sendiri (`.worktrees/<slug>`), tetapi objek dan remote-tracking ref-nya **dibagi**. Dua konsekuensi praktis:

- `git branch -vv` menampilkan branch milik task lain, dan ref `[origin/main]` bisa tertinggal sampai `fetch` berikutnya — jangan simpulkan "belum ada commit" dari ref lokal; pakai `git ls-remote` atau `gh api`.
- Perintah yang mengubah state bare cache (mis. `git remote prune`, `git gc`) **tidak** boleh dijalankan sendiri oleh satu task — ia menyentuh worktree 17 task lain yang sedang berjalan. Ini masuk register celah `06-register-celah.md`.

Perintah checkout yang berlaku (`multica repo checkout --help`):

| Perintah | Efek |
|---|---|
| `multica repo checkout https://github.com/jettapindika/triangulate` | worktree baru di branch `agent/<slug>/<hash>`, atau **dipertahankan** kalau sudah ada perubahan belum di-commit/belum di-push |
| `multica repo checkout <url> --ref <branch\|tag\|sha>` | checkout dari revisi tertentu alih-alih default branch |
| `multica repo checkout <url> --fresh` | buang perubahan + file untracked, mulai branch baru dari default branch terbaru; commit lama tetap di branch lama |

`--fresh` **menghapus pekerjaan yang belum di-push.** Urutan yang benar: `git push` dulu, baru `--fresh`.

## 4. Inventaris environment

PRD §15 dan §17 **tidak menamai environment** secara eksplisit; yang disebut adalah rilis minggu 8 dan playtest 3 pemain nyata minggu 7. Pemetaan di bawah adalah **usulan Devan** dan wajib disetujui Nathan — CTO/CIO sebelum dipakai sebagai istilah resmi.

| Environment | Bentuk di Roblox | Dipakai untuk | Status hari ini | Pemilik usulan |
|---|---|---|---|---|
| **Lokal (dev)** | Roblox Studio + Rojo `serve` di workstation | kerja harian, spike minggu 0 (PRD §15, §17) | **BELUM ADA** — scaffold repo belum mendarat (EXTA-32) | Nathan — CTO/CIO |
| **Playtest** | Experience/place privat + private server (PRD §8, §14) | playtest internal minggu 6 dan playtest 3 pemain nyata minggu 7 (PRD §17) | **BELUM ADA** | Nathan — CTO/CIO |
| **Produksi** | Experience publik (universe) | rilis minggu 8 (PRD §17) | **BELUM ADA** | Jetta (owner) — butuh akun/group Roblox |
| **CI** | GitHub Actions runner `ubuntu-latest` | lint, analyze, test (usulan di `03-pipeline-ci.md`) | **BELUM ADA** — 0 workflow | Devan (draft), aktivasi oleh owner |

Environment GitHub: **0** (`gh api repos/.../environments` → `{"total_count":0}`). Deploy key: **0**. Webhook: **0**. Tag: **0**.

`ASUMSI`: Roblox tidak punya konsep "environment" seperti GitHub; pemisahan dev/playtest/produksi di Roblox biasanya dilakukan lewat place terpisah atau universe terpisah. Bentuk pastinya bergantung pada keputusan Nathan — CTO/CIO di EXTA-32. Yang memverifikasi: dokumen arsitektur EXTA-32.

## 5. Akun dan siapa memegangnya

| Akun | Dipakai untuk | Pemegang | Bukti | Catatan risiko |
|---|---|---|---|---|
| GitHub `jettapindika` | satu-satunya identitas tulis ke repo (admin) | Jetta (owner) | `gh auth status`, `gh api repos/.../collaborators` | **akun pribadi**; scope token `gist`, `read:org`, `repo`, `workflow`; tersimpan di keyring workstation ini |
| GitHub `Etzhyy` | terautentikasi di workstation yang sama, tidak aktif | Jetta (owner) | `gh auth status` | identitas kedua yang sudah ada — kandidat peninjau PR, lihat `02-checklist-koneksi-repo.md` §3 |
| Multica workspace owner | pemilik seluruh agent, runtime, dan project | Jetta (`jettabackupacc1@gmail.com`, role `owner`) | `multica workspace member list --output json` | satu-satunya member workspace |
| Roblox (akun + group pemilik experience) | publish/upload place, DataStore produksi, Open Cloud API key | **TIDAK DIKETAHUI / BELUM ADA** | tidak ada `~/.roblox`; tidak ada env Roblox di workstation | **ESKALASI →** Nathan — CTO/CIO: tentukan akun/group pemilik experience sebelum minggu 6 |
| Akun CI terpisah (machine user) | menjalankan Actions yang menulis ke Roblox | **BELUM ADA** | 0 repo secret, 0 environment | **ESKALASI →** Nathan — CTO/CIO: keputusan buat/tidak buat machine user |
| Roblox Open Cloud API key | publish place, DataStore Open Cloud, Messaging Service | **BELUM ADA** | 0 repo secret | **ESKALASI →** Nathan — CTO/CIO: cakupan & pemegang kunci |

Aturan yang berlaku untuk seluruh tabel di atas: **nilai secret tidak pernah disalin ke issue, dokumen, atau chat.** Yang dicatat hanya nama dan jumlah. Kalau sebuah token sudah terlanjur diposting sebagai teks biasa, itu insiden — dilaporkan ke Nathan — CTO/CIO tanpa mengutip nilainya.

## 6. Runtime & daemon (Multica)

Perintah: `multica runtime list --output json`, `multica daemon status --output json`.

| Runtime | ID | Provider | Status | Daemon | Dipakai? |
|---|---|---|---|---|---|
| Oh-My-Pi (ztvns-Mac.local) | `a82fac41-c20d-40e8-82f1-6e3b5a384796` | omp | online | `01a0d465-e997-763d-8734-05828a192d14` | **ya — 20 dari 20 agent terikat ke sini** |
| Pi (ztvns-Mac.local) | `0a1b01de-73cd-4b68-a16f-c12d8a6ef645` | pi | online | `01a0d465-…` | ya — runtime sesi ini |
| Claude (ztvns-Mac.local) | `30ed3374-846d-48df-8580-ed4fd9adcd1b` | claude | online | `01a0d465-…` | tidak ada agent terikat |
| Codex (ztvns-Mac.local) | `35a06a66-d41b-44b9-88a7-6cd2693ccaa9` | codex | online | `01a0d465-…` | tidak ada agent terikat |
| Hermes (ztvns-Mac.local) | `c82aef94-7c3a-44f5-8bae-c06261fd0816` | hermes | online | `01a0d465-…` | tidak ada agent terikat |
| Hermes (68e61006f905) — VPS Worker | `c2253983-d329-48cb-a021-482d3a8c9418` | hermes | online | `01a0d46b-8bfc-7481-b278-eda22f43cb11` | tidak ada agent terikat |
| Hermes (c1a10edfc730) — VPS Main | `711a58a8-2ee2-4c32-a883-0dff8ef5f76b` | hermes | online | `01a0d46c-9fa6-7deb-b5c8-20df434711a6` | tidak ada agent terikat |

Semua runtime `visibility: private`, `runtime_mode: local`, `owner_id: 7d0f72be-0576-4851-b3b3-902a384c28f0`.

Daemon aktif: `01a0d465-e997-763d-8734-05828a192d14`, status `running`, `pid` 11572, `active_task_count` 12–17 saat pembacaan awal dan turun ke 5 (`running_task_count` 3) pada pembacaan 2026-10-04 10:49Z, profile `desktop-api.multica.ai`. Lima runtime (Claude, Codex, Hermes, Oh-My-Pi, Pi) berbagi daemon ini.

Pemetaan agent → runtime (`multica agent list --output json`, kolom `runtime_id`):

| Runtime | Jumlah agent | Agent |
|---|---|---|
| `a82fac41-…` (Oh-My-Pi) | **20 (seluruh workspace)** | Mika, Benjamin, Michelle, Rafael, Nathan, Clara, Rangga, Kirana, Wisnu, Dimas, Ayu, Bayu, Devan, Bima, Rani, Nadia, Damar, Sari, Dewi, Bagas |
| runtime lain | 0 | — |

`max_concurrent_tasks` per agent berkisar 6–50; totalnya jauh di atas jumlah runtime yang dipakai. Artinya **satu runtime menanggung seluruh beban agent** — ini temuan kapasitas, bukan temuan keamanan.

## 7. Yang TIDAK tercakup inventaris ini

| Tidak tercakup | Sebab | Cara menutupnya |
|---|---|---|
| Akun/group Roblox pemilik experience | tidak ada kredensial atau konfigurasi Roblox di workstation ini | keputusan owner lewat Nathan — CTO/CIO |
| Environment Roblox nyata (place/universe) | scaffold repo (EXTA-32) belum mendarat | dokumen arsitektur EXTA-32 |
| Isi dan nilai secret | aturan peran: hanya jumlah dan nama | inventaris jumlah ada di `04-manajemen-secret.md` |
| Konfigurasi `main` yang berlaku setelah perubahan | perubahan setting belum disetujui owner | jalankan usulan di `02-checklist-koneksi-repo.md` §5 setelah disetujui |
| Repo selain `triangulate` | workspace hanya punya satu repo | `multica repo list` + `multica project resource list` |
| Status runtime selain saat pembacaan | `last_seen_at` bergerak tiap beberapa detik | baca ulang `multica runtime list --output json` |
