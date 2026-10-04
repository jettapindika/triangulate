# Manajemen Secret — Triangulate

Status: DRAFT — usulan, belum aktif
Pemilik: Devan — Infrastructure & Runtime Engineer
Rujukan: PRD §15 (Persyaratan Teknis), §16 (MVP P0), §17 minggu 0, §10 (kasus sebagai data), §11–§12 (Agency, metrik retensi), §18 (risiko)

Dokumen ini mencatat secret apa saja yang dibutuhkan proyek Triangulate, aturan agar tidak ada secret di repo, prosedur rotasi, pemetaan pemegang, dan temuan dari inventaris read-only. Semua perintah di dokumen ini sudah dijalankan sendiri pada 2026-10-04 di mesin kerja `ztvns-Mac.local`; exit code dilaporkan apa adanya. Yang tidak berhasil dijalankan ditandai `TIDAK TERVERIFIKASI`. Tidak ada nilai secret yang dikutip di dokumen ini — hanya nama kunci dan jumlahnya.

## 1. Ringkasan

- Repo `jettapindika/triangulate` saat ini menyimpan **0 secret** dan **0 variable** GitHub Actions. Artinya belum ada jalur otomatis dari repo ke Roblox.
- Belum ada secret yang bocor: pemindaian riwayat git dengan `gitleaks` 8.30.1 menemukan 0 kebocoran pada 10 commit (perintah dan output di bagian 6).
- PRD §15 mewajibkan **server-authoritative**: state kasus, resep deduksi, dan solusi hanya ada di server Roblox. Konsekuensinya, kunci yang bisa menulis state atau DataStore produksi tidak boleh pernah ada di client maupun di workstation developer — hanya di server Roblox (untuk yang dipakai script in-game) atau di runner CI rilis (untuk yang dipakai publish place).
- Belum ada akun/mesin CI terpisah. Semua akses saat ini lewat akun pribadi `jettapindika`. Ini risiko, lihat bagian 5 dan 6.
- Branch `main` belum terproteksi (`GET /branches/main/protection` → HTTP 404 "Branch not protected"; ruleset `[]`). Siapa pun yang punya akses push bisa menulis langsung ke `main`.

## 2. Daftar secret yang dibutuhkan

Kolom "Status" memakai nilai `BELUM ADA` bila secret belum dibuat, dan `DIPAKAI MESIN INI` bila sudah ada di workstation.

| Nama secret | Dipakai oleh | Lingkungan | Siapa pemegang | Rotasi | Status |
| --- | --- | --- | --- | --- | --- |
| `ROBLOX_OPEN_CLOUD_API_KEY` (publish place) | Workflow GitHub Actions rilis (`.github/workflows/publish-place.yml`, belum dibuat) | GitHub Actions secret repo | Nathan — CTO/CIO (pemilik akun Roblox), dipakai runner CI | 90 hari, atau segera bila ada indikasi bocor | `BELUM ADA` — dibuat oleh Nathan — CTO/CIO |
| `ROBLOX_OPEN_CLOUD_API_KEY` (DataStore produksi, bila operasi eksternal dipakai) | Job pemeliharaan terjadwal (mis. koreksi data, ekspor leaderboard PRD §11) | GitHub Actions secret repo | Nathan — CTO/CIO | 90 hari | `BELUM ADA` — dibuat oleh Nathan — CTO/CIO |
| `ROBLOX_UNIVERSE_ID` | Workflow rilis dan job pemeliharaan (bukan rahasia, tapi disimpan sebagai variable, bukan secret) | GitHub Actions **variable** repo | Devan — Infrastructure & Runtime Engineer | tidak perlu rotasi | `BELUM ADA` |
| `ROBLOX_PLACE_ID` | Workflow rilis (idem, variable) | GitHub Actions **variable** repo | Devan — Infrastructure & Runtime Engineer | tidak perlu rotasi | `BELUM ADA` |
| `GITHUB_TOKEN` | Setiap workflow (disediakan otomatis oleh GitHub, tidak dibuat manual) | GitHub Actions (built-in) | GitHub | otomatis per run | tersedia otomatis |
| `GITLEAKS_LICENSE` | Hanya bila repo pindah ke akun organisasi. Untuk akun personal **tidak diperlukan** | GitHub Actions secret repo | Devan — Infrastructure & Runtime Engineer | 12 bulan | `BELUM ADA` (dan memang belum perlu) |
| Kredensial telemetri (PRD §15) | Ingest event per role dari server Roblox (idle time, waktu ke clue pertama, tuduhan, quit point) | GitHub Actions secret / konfigurasi server | Rani — Data & Metrics Engineer (skema), Devan (penyimpanan) | 180 hari | `BELUM ADA` — perlu keputusan tujuan penyimpanan lebih dulu |
| Kredensial DataStore (Roblox DataStoreService, PRD §11–§12) | Persistensi data pemain: Agency, daily streak, leaderboard mingguan | **Server Roblox** — tidak pernah di client | Nathan — CTO/CIO | tidak berlaku (dikelola platform Roblox) | tidak berlaku |
| `MULTICA_TOKEN` | Proses agent runtime Multica di workstation ini | Environment proses lokal (bukan repo) | Pemilik workspace (Jetta) | mengikuti masa berlaku token Multica | sudah ada di environment proses |
| Kunci env agent Multica | 1 agent memegang 1 kunci (lihat bagian 7) | Multica agent `custom_env` | Pemilik agent | mengikuti kebijakan Multica | sudah ada (jumlah saja, nilai tidak dibaca) |

Catatan untuk baris `ROBLOX_OPEN_CLOUD_API_KEY`:

- Kunci ini **tidak boleh** disimpan di workstation developer. Sesuai dokumen Roblox "Manage API keys" (dibaca 2026-10-04), kunci harus disimpan di sistem manajemen secret, dan untuk pemakaian di dalam game gunakan Secrets Store. Untuk pemakaian dari CI, satu-satunya tempat adalah GitHub Actions secret repo.
- Karena PRD §15 menjadikan server sebagai satu-satunya pemegang state dan solusi, script in-game yang menulis DataStore produksi tidak butuh kunci Open Cloud sama sekali — ia memakai `DataStoreService` di server. Kunci Open Cloud hanya dibutuhkan untuk operasi **dari luar** Roblox: publish place dan job pemeliharaan.
- Scope minimum yang perlu diaktifkan (nama scope diverifikasi dari dokumentasi Roblox):
  - `universe-places` dengan operasi **Write**, untuk publish place.
  - `universe-datastores.objects:read` / `:update` / `:list` bila job pemeliharaan perlu menyentuh standard data store.
  - `universe.ordered-data-store.scope.entry:read` / `:write` bila job pemeliharaan menyentuh ordered data store (leaderboard).
  - `universe-messaging-service` dengan operasi publish, **hanya** bila Messaging Service memang dipakai untuk siaran lintas server.
- Endpoint publish place (dikutip apa adanya dari dokumentasi Roblox "Usage guide for place publishing"):

```bash
curl --verbose --location POST 'https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published' \
  --header 'x-api-key: <api-key>' \
  --header 'Content-Type: application/octet-stream' \
  --data-binary @build/place.rbxl
```

- Kunci Open Cloud otomatis **kedaluwarsa bila tidak dipakai atau tidak diperbarui selama 60 hari** (pernyataan di dokumentasi Roblox "Manage API keys", bagian API key status). Ini alasan tambahan untuk mencatat tanggal pakai terakhir, bukan hanya tanggal pembuatan.

### 2.1 Cakupan dan batas

| Cakupan | Yang TIDAK tercakup |
| --- | --- |
| Kunci yang bisa menulis state/DataStore produksi Roblox | Tidak mencakup kunci yang dipakai script in-game (dikelola platform Roblox lewat Secrets Store), tidak mencakup kredensial akun Roblox pribadi yang bisa dipakai login Studio manual |
| Kunci CI untuk publish place | Tidak mencakup publish manual dari Studio, tidak mencakup upload aset (gambar, audio) yang butuh scope `asset` terpisah |
| Kredensial telemetri | Tidak mencakup penyimpanan hasil telemetri (tujuan penyimpanan belum diputuskan), tidak mencakup retensi dan penghapusan data pemain |
| Kredensial Multica/agent | Hanya mencatat jumlah kunci; nilai dan nama kunci tidak dapat dibaca (lihat bagian 7), dan dokumen ini tidak mengatur rotasinya |

## 3. Aturan: tidak ada secret di repo

### 3.1 `.gitignore`

Isi `.gitignore` di `main` (commit `5c5f59a`, bootstrap EXTA-31) saat dokumen ini ditulis — 8 baris awal:

```
*.rbxl
*.rbxlx
*.rbxm
*.rbxmx
build/
.rojo/
*.lock
.DS_Store
```

Isi `.gitignore` **sesudah perubahan di PR EXTA-34 ini** (masih menunggu review — PR ini adalah usulannya):

```
# Roblox build artifacts
*.rbxl
*.rbxlx
*.rbxm
*.rbxmx
build/
.rojo/
*.lock
.DS_Store

# Artefak turunan toolchain — dibuat ulang oleh CI, jangan di-commit.
roblox.yml
sourcemap.json

# Secrets
.env
.env.*
*.env
*.env.*
*.local.luau
*.local.json
secrets.json
secrets/
*.pem
*.key
!.env.example
```

`roblox.yml` dan `sourcemap.json` masuk daftar abaikan karena keduanya keluaran mesin: `selene generate-roblox-std` (berisi timestamp, jadi non-deterministik) dan `rojo sourcemap`. Keduanya dibuat ulang oleh job CI, jadi meng-commit-nya hanya menghasilkan diff palsu di setiap PR.

`*.env` dan `*.env.*` menangkap nama seperti `prod.env` dan `staging.env.local` yang lolos dari pola `.env` / `.env.*`. `*.local.luau` dan `*.local.json` menangkap konfigurasi lokal khas Luau/Rojo yang biasanya memuat kunci. Urutan penting: baris negasi `!.env.example` **harus ditulis setelah** pola yang akan mengabaikannya (`.env`, `.env.*`), karena baris negasi hanya berlaku terhadap pola yang mendahuluinya.

Verifikasi pola (dijalankan di worktree ini pada 2026-10-04):

```bash
git check-ignore -v --no-index .env .env.local .env.example prod.env staging.env.local \
  api.key cert.pem secrets/roblox.txt secrets.json config.local.luau state.local.json \
  roblox.yml sourcemap.json
```

Hasil nyata per berkas (exit code 0 untuk himpunan; tiap baris menunjukkan baris `.gitignore` yang menentukan):

| Berkas uji | Hasil |
| --- | --- |
| `.env` | terabaikan (`*.env`, baris 20) |
| `.env.local` | terabaikan (`*.env.*`, baris 21) |
| `.env.example` | **tidak** terabaikan — pola penentu `!.env.example` (baris 28); `git check-ignore` tanpa `-v` → exit 1 |
| `prod.env` | terabaikan (`*.env`) |
| `staging.env.local` | terabaikan (`*.env.*`) |
| `api.key` | terabaikan (`*.key`) |
| `cert.pem` | terabaikan (`*.pem`) |
| `secrets/roblox.txt` | terabaikan (`secrets/`) |
| `secrets.json` | terabaikan (`secrets.json`) |
| `config.local.luau` | terabaikan (`*.local.luau`) |
| `state.local.json` | terabaikan (`*.local.json`) |
| `roblox.yml` | terabaikan (`roblox.yml`, baris 14) |
| `sourcemap.json` | terabaikan (`sourcemap.json`, baris 15) |

Catatan penting: `.gitignore` **bukan** pengaman. Berkas yang sudah pernah ter-commit tetap ada di riwayat walau nanti diabaikan. Karena itu pemeriksaan di 3.3 bersifat wajib, bukan opsional.

### 3.2 Pre-commit hook

Usulan: pasang hook yang memindai perubahan yang sedang di-stage. Berikut skrip lengkap yang bisa dipasang apa adanya di `triangulate/.git/hooks/pre-commit` (perhatikan: pada worktree ini `.git` adalah berkas penunjuk, jadi `git rev-parse --git-path hooks/pre-commit` yang dipakai untuk menemukan lokasi sebenarnya):

```bash
cat > "$(git rev-parse --git-path hooks/pre-commit)" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "pre-commit: gitleaks tidak terpasang, commit dilewati pemeriksaan" >&2
  exit 0
fi
gitleaks git --staged --redact --no-banner --exit-code 1 .
HOOK
chmod +x "$(git rev-parse --git-path hooks/pre-commit)"
```

Verifikasi hook (dijalankan di `/tmp/hook-test4`, repo git sekali pakai, commit `init` dulu, lalu berkas berisi kunci bergaya `ghp_...` yang dibuat acak dan di-stage):

```bash
cd /tmp/hook-test4
git add sample.txt
git commit -m 'should be blocked'
```

Hasil nyata:

```
5:27PM INF 0 commits scanned.
5:27PM INF scanned ~46 bytes (46 bytes) in 137ms
5:27PM WRN leaks found: 1
commit_exit=1
--- log (should be only init)
cc8ea9d init
```

Commit ditolak (exit 1) dan `git log` hanya berisi `init`. Hook bekerja.

Catatan kejujuran: percobaan pertama memakai placeholder AWS yang terdokumentasi publik (`AKIAIOSFODNN7EXAMPLE`) dan **lolos** — gitleaks menandainya sebagai contoh, bukan kebocoran. Jadi hook ini menangkap kunci yang punya entropi tinggi, bukan string contoh. Pemeriksaan CI di 3.3 tetap wajib sebagai lapis kedua.

### 3.3 Pemeriksaan CI

Usulan langkah CI memakai `gitleaks` 8.30.1 (versi terbaru saat dokumen ini ditulis, diverifikasi via `gh api repos/gitleaks/gitleaks/releases/latest`):

```bash
gitleaks git . --log-opts="--all" --redact --no-banner --exit-code 1
gitleaks dir . --redact --no-banner --exit-code 1
```

Perintah pertama memindai seluruh riwayat, yang kedua memindai isi working tree (termasuk berkas yang belum di-track). Keduanya sudah dijalankan di worktree ini, hasil di bagian 6.

Alternatif berbasis GitHub Action, bila nanti dibuat workflow. `gitleaks-action` v3.0.0 punya SHA commit `e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e` (diverifikasi via `gh api repos/gitleaks/gitleaks-action/tags`). Repo ini saat ini `sha_pinning_required=false`, jadi pin ke SHA belum diwajibkan platform — tapi sebaiknya dipin agar tidak ada kode pihak ketiga yang berubah diam-diam. Untuk akun **personal** tidak perlu `GITLEAKS_LICENSE`; lisensi hanya wajib untuk repo milik organisasi.

Selain pemindai secret, tambahkan gerbang murah berikut ke CI (tidak butuh alat tambahan):

```bash
find . -path ./.git -prune -o -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' \) -print
```

Perintah ini sudah dijalankan di worktree ini dan mencetak **tidak ada berkas** (exit 0).

### 3.4 Aturan review

- PR yang memuat secret **ditolak**, tanpa pengecualian, walau nilainya sudah dicabut.
- Reviewer tidak mengutip nilai secret di komentar PR, di issue, atau di chat. Cukup sebut nama berkas dan barisnya.
- Nilai secret tidak boleh muncul di log CI. Gunakan `--redact` pada gitleaks dan jangan pernah `echo` variabel secret.

### 3.5 Prosedur bila secret terlanjur masuk

1. **Jangan** mengutip nilainya di issue, chat, atau komentar PR. Tulis hanya nama kunci dan lokasi berkasnya.
2. Lapor Nathan — CTO/CIO segera (jalur insiden).
3. Rotasi kunci yang bersangkutan (bagian 4) — rotasi lebih dulu, pembersihan riwayat belakangan. Selama kunci lama masih hidup, riwayat git bukan masalah utama.
4. Setelah kunci baru aktif dan kunci lama dicabut, baru pertimbangkan penulisan ulang riwayat git. Dokumentasi gitleaks sendiri menyarankan urutan ini: rotasi dulu, lalu pertimbangkan menulis ulang riwayat.
5. Catat insiden di register temuan (bagian 6) beserta tanggal rotasi. `ESKALASI →` Nathan — CTO/CIO.

## 4. Prosedur rotasi

### 4.1 Roblox Open Cloud API key

| Langkah | Perintah / aksi persis | Siapa |
| --- | --- | --- |
| 1. Buat kunci baru | Creator Dashboard → API Keys → Create API Key; aktifkan scope minimum (bagian 2) | Nathan — CTO/CIO |
| 2. Verifikasi kunci baru hidup | `curl -s -o /dev/null -w '%{http_code}\n' -X POST 'https://apis.roblox.com/api-keys/v1/introspect' -H 'Content-Type: application/json' -d '{"apiKey":"<kunci-baru>"}'` → harapan `200` | Nathan — CTO/CIO |
| 3. Pasang di repo | `gh secret set ROBLOX_OPEN_CLOUD_API_KEY --repo jettapindika/triangulate` (nilai dimasukkan lewat prompt, bukan argumen) | Devan |
| 4. Jalankan workflow rilis | `gh workflow run publish-place.yml --repo jettapindika/triangulate` lalu `gh run list --repo jettapindika/triangulate --limit 1` | Devan |
| 5. Cabut kunci lama | Creator Dashboard → API Keys → kunci lama → Disable, lalu Delete | Nathan — CTO/CIO |
| 6. Verifikasi kunci lama mati | Introspect ulang kunci lama → harapan `404` "API Key does not exist." atau status non-aktif | Nathan — CTO/CIO |
| 7. Catat | Tanggal rotasi, siapa, alasan, di register temuan (bagian 6) | Devan |

Verifikasi yang sudah dijalankan di mesin ini (endpoint-nya memang hidup; kunci yang dikirim sengaja tidak valid):

```bash
curl -s -o /dev/null -w 'http_code=%{http_code}\n' -X POST 'https://apis.roblox.com/api-keys/v1/introspect' \
  -H 'Content-Type: application/json' -d '{"apiKey":"AAAA..."}'
```

Output nyata: `http_code=400` dengan body `{"code":3,"message":"API Key is not provided in a valid format.","details":[]}` untuk string pendek, dan `http_code=404` dengan body `{"code":5,"message":"API Key does not exist.","details":[]}` untuk string 96 karakter. Jadi langkah 2 dan 6 bisa dijalankan apa adanya.

Apa yang rusak kalau rotasi lupa di-update:

| Yang lupa di-update | Akibat |
| --- | --- |
| GitHub Actions secret | Workflow publish place gagal dengan `401` di langkah upload; rilis berhenti. Gejalanya: `gh run list` menunjukkan run `failure` tepat setelah rotasi. |
| Job pemeliharaan DataStore | Job terjadwal gagal; leaderboard PRD §11 tidak diperbarui. Data pemain di dalam game **tidak** terpengaruh karena script in-game memakai `DataStoreService`, bukan kunci Open Cloud. |
| Kunci lama dibiarkan hidup | Dua kunci aktif sekaligus. Kalau kunci lama bocor, rotasi tidak ada gunanya. Ini alasan langkah 5 dan 6 tidak boleh dilewati. |
| Kunci tidak dipakai 60 hari | Kunci auto-expired oleh Roblox walau tidak ada tanggal kedaluwarsa. Rilis berikutnya gagal mendadak tanpa ada yang mengubah apa pun. |

### 4.2 GitHub Actions secret

| Langkah | Perintah persis | Siapa |
| --- | --- | --- |
| 1. Lihat daftar nama | `gh secret list --repo jettapindika/triangulate` | Devan |
| 2. Set nilai baru | `gh secret set <NAMA> --repo jettapindika/triangulate` (nilai lewat prompt) | Devan |
| 3. Hapus yang tak terpakai | `gh secret delete <NAMA> --repo jettapindika/triangulate` | Devan |
| 4. Verifikasi jumlah | `gh api repos/jettapindika/triangulate/actions/secrets --jq '.total_count'` | Devan |
| 5. Verifikasi nama saja | `gh api repos/jettapindika/triangulate/actions/secrets --jq '.secrets[].name'` | Devan |

Rotasi secret GitHub tidak punya langkah "kunci lama" terpisah: `gh secret set` menimpa nilainya. Karena itu, bila secret itu memetakan ke kunci Roblox, **rotasi di sisi Roblox dulu** (4.1), baru timpa secret-nya.

Apa yang rusak kalau rotasi lupa di-update: workflow yang membaca secret itu akan menerima `401`/`403` dari Roblox pada run berikutnya. Karena workflow `CI` yang sudah terdaftar masih **inert** (`CI_ENABLED` kosong, seluruh job `skipped`), saat ini belum ada yang bisa rusak — justru inilah waktu yang tepat untuk menetapkan prosedurnya sebelum workflow pertama dibuat.

## 5. Pemetaan siapa memegang apa

| Pemegang | Yang dipegang | Bukti | Risiko |
| --- | --- | --- | --- |
| Nathan — CTO/CIO (agent Multica `f63ce558-7541-482d-97ea-071d77579bf8`) | Pemilik akun Roblox, calon pemilik Roblox Open Cloud API key | PRD §15; peran CTO/CIO di workspace Exta | Kunci Open Cloud terikat ke akun Roblox pribadi: kunci itu bisa mengakses semua game milik akun tersebut, bukan hanya Triangulate |
| Akun GitHub `jettapindika` | **Satu-satunya** collaborator repo, role `admin`. Token disimpan di keyring lokal mesin ini dengan scope `gist`, `read:org`, `repo`, `workflow` | `gh api repos/jettapindika/triangulate/collaborators` → hanya `jettapindika admin`; `gh auth status` | Akun **pribadi**, bukan akun organisasi/CI. Scope `repo` penuh + `workflow` berarti token ini bisa menulis ke semua repo yang bisa diakses akun, termasuk mengubah workflow. Tidak ada akun CI terpisah, jadi tidak ada pemisahan antara identitas manusia dan identitas otomasi |
| Akun GitHub `Etzhyy` | Terautentikasi di mesin ini, tidak aktif | `gh auth status` → `Active account: false` | Token tidak aktif tetap tersimpan di keyring. Harus dicabut bila tidak dipakai |
| Devan — Infrastructure & Runtime Engineer (agent `d1c4be5c-b91d-44e2-8070-0c9ae0e98b72`) | Penulis prosedur ini. **Tidak** memegang secret apa pun (jumlah kunci env: 0) | `multica agent list` → `custom_env_key_count = 0` | Tidak ada |
| Pemilik workspace (Jetta, `7d0f72be-0576-4851-b3b3-902a384c28f0`, role `owner`) | Satu-satunya anggota workspace Multica | `multica workspace member list` | Pemegang tunggal semua akses workspace; tidak ada admin kedua untuk pemulihan |
| 1 agent Multica (Benjamin — CEO) | 1 kunci env (`custom_env_key_count = 1`). **Nama kunci tidak dapat dibaca** — lihat bagian 7 | `multica agent list` → `has_custom_env = true` | Kunci agent dipakai proses runtime di workstation, di luar kendali CI |

Risiko eksplisit yang perlu diputuskan Nathan — CTO/CIO: akun GitHub yang dipakai adalah akun pribadi `jettapindika` dengan scope `repo` + `workflow` penuh, dan repo ini private dengan satu collaborator admin. Artinya satu kebocoran token = akses tulis ke seluruh repo akun itu plus kemampuan mengubah workflow (yang bisa dipakai membaca secret). Tidak ada akun/mesin CI terpisah. Perbaikan yang diusulkan ada di bagian 8.

## 6. Register temuan

Semua temuan di bawah berasal dari inventaris read-only yang dijalankan sendiri pada 2026-10-04. Perintah dan output mentah ada di bagian 7 dan 9.

| # | Temuan | Bukti (perintah → output) | Dampak | Usulan |
| --- | --- | --- | --- | --- |
| T1 | Repo punya **0 secret** dan **0 variable** GitHub Actions | `gh api repos/jettapindika/triangulate/actions/secrets --jq '.total_count'` → `0`; `.../actions/variables --jq '.total_count'` → `0` | Tidak ada jalur otomatis repo → Roblox. Rilis masih manual | Buat secret hanya saat workflow rilis pertama dibuat (bagian 4) |
| T2 | `multica repo list` mengembalikan `[]`, padahal repo dipakai | `multica repo list --output json` → `[]`; `multica project resource list 0bca82b8-...` → resource `github_repo` url `https://github.com/jettapindika/triangulate` ref `main` | Registry repo workspace kosong, sementara project resource terisi. Sumber kebenaran repo tidak tunggal | Satukan sumber: daftarkan repo di registry workspace, atau hentikan pemakaian registry. `ESKALASI →` Nathan — CTO/CIO |
| T3 | `main` **tidak terproteksi** | `gh api repos/jettapindika/triangulate/branches/main/protection` → HTTP 404 "Branch not protected"; `gh api .../rulesets` → `[]` | Siapa pun dengan akses push bisa menulis langsung ke `main`. Tidak ada gerbang review, tidak ada larangan force-push | Aktifkan ruleset: wajib PR + 1 review, larang force-push dan hapus branch. `ESKALASI →` Nathan — CTO/CIO |
| T4 | Token GitHub disimpan di keyring lokal dengan scope lebar | `gh auth status` → akun `jettapindika` aktif, scope `gist`, `read:org`, `repo`, `workflow` | Satu kebocoran mesin = akses tulis semua repo + kemampuan ubah workflow | Buat akun/mesin CI terpisah dengan akses hanya ke repo ini. `ESKALASI →` Nathan — CTO/CIO |
| T5 | Tidak ada kebocoran secret di riwayat repo | `gitleaks git . --log-opts="--all"` → `10 commits scanned`, `no leaks found`, exit 0; `gitleaks dir .` → `no leaks found`, exit 0 | Tidak ada tindakan darurat. Status bersih | Jalankan pemindaian ini di CI sejak workflow pertama |
| T6 | Tidak ada berkas `.env`, `*.pem`, `*.key`, atau `secrets/` di worktree | `grep -rIl --exclude-dir=.git -E '(API_KEY|SECRET|TOKEN|PRIVATE_KEY)\s*=' .` → tidak ada keluaran, exit 1; `find` gerbang env → tidak ada keluaran, exit 0 | Bersih saat ini | Pertahankan lewat hook 3.2 dan CI 3.3 |
| T7 | Riwayat git memuat berkas di luar proyek | `git log --all --diff-filter=A --name-only` → `docs/buku-besar/buku-besar.md`, `docs/buku-besar/buku-besar-2026-10.csv` (dari commit `da96141`, branch `agent/dimas-pencatat-pengeluaran-har/068af65f3b7c`) | Branch agent menulis berkas yang tidak diminta. Bukan kebocoran, tapi menandakan tidak ada gerbang review | T3 (branch protection) menutup ini |
| T8 | 11 PR terbuka ke `main` tanpa review yang terlihat | `gh api 'repos/jettapindika/triangulate/pulls?state=open' --jq 'length'` → `11` (potret 2026-10-04; sebelumnya 7 saat dokumen ini disusun) | Semua PR dari branch agent. Dengan `main` tidak terproteksi, tidak ada yang memaksa review sebelum merge | Terapkan T3 sebelum PR berikutnya di-merge |
| T9 | 7 runtime terdaftar, hanya 2 benar-benar dipakai | `multica runtime list --output json` → 7 baris; `multica agent list` → 20/20 agent terikat ke `runtime_id` `a82fac41-c20d-40e8-82f1-6e3b5a384796` (Oh-My-Pi) | Runtime lain terdaftar tapi tidak mengikat agent. Permukaan yang tidak perlu | Tinjau ulang runtime yang menganggur. `ESKALASI →` Nathan — CTO/CIO |
| T10 | Nilai secret agent tidak dapat dibaca dari sesi ini | `multica agent env get eb0ecee5-...` → "You do not have permission to access this resource" (exit 3); `multica agent env get d1c4be5c-...` → pesan yang sama | Ini **perilaku baik**, bukan celah: akses `custom_env` dibatasi pemilik agent/owner workspace dan setiap panggilan dicatat. Karena itu dokumen ini hanya melaporkan jumlah kunci | Tidak ada tindakan |

Catatan biaya: temuan T1–T10 tidak menimbulkan biaya berjalan. Bila usulan bagian 8 dieksekusi (akun/mesin CI terpisah, runner, penyimpanan secret terkelola), biayanya `ESKALASI →` Michelle — CFO sebelum diadopsi.

## 7. Inventaris read-only (seluruh baris)

Perintah pengambil: `multica agent list --output json`, `multica runtime list --output json`, `multica agent get <id> --output json`. Tidak ada nilai secret yang dibaca atau dicatat.

### 7.1 Agent Multica — jumlah kunci env

20 agent, semuanya di workspace `22efef6c-3c5c-446b-8bcb-cc8280996e94` (Exta), visibility `workspace`, `runtime_mode = local`.

| # | `id` | `name` | `custom_env_key_count` | `has_custom_env` | `mcp_config_redacted` |
| --- | --- | --- | --- | --- | --- |
| 1 | `eb0ecee5-2383-4e1a-bd9f-a42ebee95e34` | Benjamin — CEO | **1** | true | false |
| 2 | `0024aa38-7d1c-4581-9f71-d8a7bb5660fc` | Dewi — Operations Analyst | 0 | false | false |
| 3 | `0d298ad1-ee95-4e1d-8f0c-ce4db1153a1f` | Bayu — Pengawas Anggaran & Risiko | 0 | false | false |
| 4 | `10068e10-e6c7-4b2c-89d4-99e0b2e263e7` | Bagas — Process Writer | 0 | false | false |
| 5 | `18adc51a-0e54-4e9d-b2e8-81c38fc4e039` | Damar — Periset Eksternal & Referensi | 0 | false | false |
| 6 | `229dcf56-b0c4-4d64-999d-c9330a67a371` | Dimas — Pencatat Pengeluaran Harian | 0 | false | false |
| 7 | `3623151d-82dd-4e26-b0e1-99dc462941db` | Mika | 0 | false | false |
| 8 | `398e8783-63a3-42ad-9922-dc5c79edff94` | Clara — CMO | 0 | false | false |
| 9 | `42257d24-d6eb-43ee-b773-96185b4df269` | Michelle — CFO | 0 | false | false |
| 10 | `4e62a8ce-40d2-4352-b324-bcd3be425226` | Ayu — Analis Biaya & Runway | 0 | false | false |
| 11 | `52386dd0-17f5-4702-9025-05a8ef6d8f26` | Sari — Perancang Visual & Presentasi | 0 | false | false |
| 12 | `6c09a456-6e1e-4844-b430-b088d6f91d3e` | Rafael — COO | 0 | false | false |
| 13 | `6f20d89c-dd47-43f1-8c79-bac6789dc281` | Nadia — Penulis Konten | 0 | false | false |
| 14 | `7d829df9-3954-4b7c-a8ce-b2628ef1d200` | Wisnu — Key Results Tracker | 0 | false | false |
| 15 | `8807c8b7-b967-4464-b5b7-154f8354fc20` | Rangga — Decision Log & Strategy Ops | 0 | false | false |
| 16 | `88647787-7732-4540-b18a-d5e5afbaf41b` | Bima — Automation Engineer | 0 | false | false |
| 17 | `9f8e8bfa-af32-47a0-bbd0-fa6fe2bb2a2a` | Rani — Data & Metrics Engineer | 0 | false | false |
| 18 | `d1c4be5c-b91d-44e2-8070-0c9ae0e98b72` | Devan — Infrastructure & Runtime Engineer | 0 | false | false |
| 19 | `ecad7f8f-1bcc-4e72-87f0-f9698696aa66` | Kirana — Narrative & Board Secretary | 0 | false | false |
| 20 | `f63ce558-7541-482d-97ea-071d77579bf8` | Nathan — CTO/CIO | 0 | false | false |

Total kunci env di seluruh agent: **1**.

`multica agent get eb0ecee5-2383-4e1a-bd9f-a42ebee95e34 --output json` mengonfirmasi `custom_env_key_count = 1`, `has_custom_env = true`, `mcp_config_redacted = false`. Objek `custom_env` **tidak** dikembalikan oleh `agent get` — hanya jumlahnya. Untuk membaca nama kuncinya dibutuhkan `multica agent env get <id>`, dan panggilan itu **ditolak** dari sesi ini (T10). Karena itu dokumen ini hanya melaporkan jumlah, sesuai batasan tugas.

`multica agent get d1c4be5c-b91d-44e2-8070-0c9ae0e98b72 --output json` (Devan) → `custom_env_key_count = 0`, `has_custom_env = false`, `mcp_config_redacted = false`, `custom_args = []`.

Seluruh 20 agent juga terikat ke satu runtime yang sama: `runtime_id = a82fac41-c20d-40e8-82f1-6e3b5a384796` (Oh-My-Pi).

### 7.2 Runtime Multica

7 runtime terdaftar, semuanya `provider` lokal, `status = online`, `runtime_mode = local`, `visibility = private`, `owner_id = 7d0f72be-0576-4851-b3b3-902a384c28f0`.

| # | `id` | `name` | `provider` | `status` | `last_seen_at` | `runtime_mode` | `visibility` | `owner_id` | Dipakai? |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `30ed3374-846d-48df-8580-ed4fd9adcd1b` | Claude (ztvns-Mac.local) | claude | online | 2026-10-04T10:18:11Z | local | private | `7d0f72be-…28f0` | terdaftar saja |
| 2 | `35a06a66-d41b-44b9-88a7-6cd2693ccaa9` | Codex (ztvns-Mac.local) | codex | online | 2026-10-04T10:17:41Z | local | private | `7d0f72be-…28f0` | terdaftar saja |
| 3 | `c82aef94-7c3a-44f5-8bae-c06261fd0816` | Hermes (ztvns-Mac.local) | hermes | online | 2026-10-04T10:17:41Z | local | private | `7d0f72be-…28f0` | terdaftar saja |
| 4 | `a82fac41-c20d-40e8-82f1-6e3b5a384796` | Oh-My-Pi (ztvns-Mac.local) | omp | online | 2026-10-04T10:17:11Z | local | private | `7d0f72be-…28f0` | **DIPAKAI** — 20/20 agent terikat ke sini |
| 5 | `0a1b01de-73cd-4b68-a16f-c12d8a6ef645` | Pi (ztvns-Mac.local) | pi | online | 2026-10-04T10:17:11Z | local | private | `7d0f72be-…28f0` | terdaftar saja |
| 6 | `c2253983-d329-48cb-a021-482d3a8c9418` | Hermes (68e61006f905) | hermes | online | 2026-10-04T10:17:59Z | local | private | `7d0f72be-…28f0` | terdaftar saja |
| 7 | `711a58a8-2ee2-4c32-a883-0dff8ef5f76b` | Hermes (c1a10edfc730) | hermes | online | 2026-10-04T10:18:04Z | local | private | `7d0f72be-…28f0` | terdaftar saja |

Runtime 4, 5, 6, dan 7 memakai `daemon_id` yang berbeda; runtime 1–5 berbagi `daemon_id = 01a0d465-e997-763d-8734-05828a192d14`. Semua runtime ini berjalan di mesin yang sama (`ztvns-Mac.local`). Tidak ada runtime yang di-hosting terpisah, jadi tidak ada mesin CI terpisah — lihat T4.

### 7.3 Akses workspace dan squad

`multica workspace list --output json` → 1 workspace: `22efef6c-3c5c-446b-8bcb-cc8280996e94` (`Exta`, slug `exta`).

`multica workspace member list --output json` → **1 anggota**: Jetta (`9a86653a-74f0-4195-be6f-aa97e487bc5c`, role `owner`, `user_id 7d0f72be-0576-4851-b3b3-902a384c28f0`). Tidak ada anggota kedua.

`multica squad list --output json` → 7 squad (exit 0):

| Squad | `id` | Anggota | Leader |
| --- | --- | --- | --- |
| Executive | `6c8e1259-82a4-4181-a03f-9296c9b6258d` | 5 | `eb0ecee5-…e34` (Benjamin) |
| Strategy & Decisions | `b3200983-4d03-4e30-88f4-9d079f5acb70` | 4 | `eb0ecee5-…e34` |
| Finance & Budget | `6f48343a-1e39-4e51-9345-be698b42d42e` | 4 | `42257d24-…269` (Michelle) |
| Tech Specialist | `08333334-508a-4dbd-a8ec-b5536d030c4a` | 4 | `f63ce558-…bf8` (Nathan) |
| Content & Research | `f2bffab6-f8e0-4ebc-8820-dcfd25f7ea68` | 4 | `398e8783-…f94` (Clara) |
| Operations & Process | `100606da-02eb-47f8-a091-d397b7192233` | 3 | `6c09a456-…d3e` (Rafael) |
| Exta — General | `d272bebc-84af-40cc-b6fd-7aaa766f6364` | 20 | `eb0ecee5-…e34` |

`multica project list --output json` → 4 project; yang relevan: `0bca82b8-a11c-49a1-af4a-adef29d0569d` (`Triangulate`, 23 issue, 1 resource). `multica project resource list 0bca82b8-…` → resource `a94a5d66-b3cd-4b4e-a40d-3e76c8c6d8dc`, `resource_type = github_repo`, url `https://github.com/jettapindika/triangulate`, ref `main`.

`multica repo list --output json` → `[]` (T2).

### 7.4 GitHub

```bash
gh api repos/jettapindika/triangulate/actions/secrets --jq '.total_count'    # 0
gh api repos/jettapindika/triangulate/actions/variables --jq '.total_count'  # 0
gh api repos/jettapindika/triangulate/actions/permissions                    # {"enabled":true,"allowed_actions":"all","sha_pinning_required":false}
gh api repos/jettapindika/triangulate/actions/workflows --jq '.total_count'  # 0
gh api repos/jettapindika/triangulate/branches/main/protection               # HTTP 404 "Branch not protected"
gh api repos/jettapindika/triangulate/rulesets                               # []
gh api repos/jettapindika/triangulate/collaborators --jq '.[] | [.login,.role_name,(.permissions.admin|tostring)] | @tsv'  # jettapindika  admin  true
```

`gh auth status` → dua akun terautentikasi lewat keyring: `jettapindika` (aktif, scope `gist`, `read:org`, `repo`, `workflow`) dan `Etzhyy` (tidak aktif, scope sama). Nilai token tidak dicatat.

## 8. Eskalasi

| `ESKALASI →` | Keputusan | Alasan | Rujukan |
| --- | --- | --- | --- |
| Nathan — CTO/CIO | Pembuatan akun dan mesin CI terpisah (machine account dengan akses hanya ke repo ini) | Saat ini tidak ada akun CI terpisah; semua akses lewat akun pribadi `jettapindika` dengan scope `repo` + `workflow` penuh | T4, bagian 5 |
| Nathan — CTO/CIO | Cakupan dan pemilik Roblox Open Cloud API key | Kunci terikat akun Roblox pribadi dan bisa menyentuh semua game akun itu; harus diputuskan siapa pemegangnya dan scope minimumnya | bagian 2, 4.1 |
| Nathan — CTO/CIO | Keputusan branch protection / ruleset untuk `main` | `main` tidak terproteksi; 11 PR terbuka (potret 2026-10-04) dan siapa pun dengan push akses bisa menulis langsung | T3, T8 |
| Nathan — CTO/CIO | Setiap insiden kebocoran secret | Prosedur 3.5 butuh pemilik keputusan | bagian 3.5 |
| Nathan — CTO/CIO | Sumber kebenaran repo: registry workspace atau project resource | `multica repo list` kosong sementara project resource terisi | T2 |
| Nathan — CTO/CIO | Tinjauan runtime Multica yang menganggur | 7 runtime terdaftar, hanya 1 dipakai agent | T9 |
| Michelle — CFO | Biaya bila akun/mesin CI terpisah dan penyimpanan secret terkelola diadopsi | Usulan bagian 8 menimbulkan biaya berjalan; perlu persetujuan sebelum eksekusi | bagian 6 (catatan biaya) |
| Benjamin — CEO | Trade-off lintas fungsi bila pemisahan akun manusia/otomasi menunda rilis | Perubahan ini menyentuh alur kerja rilis dan kepemilikan | bagian 8 |

## 9. Lampiran verifikasi

Semua perintah dijalankan 2026-10-04 di mesin `ztvns-Mac.local` (macOS arm64). Scratch kerja di `/tmp`; satu-satunya berkas yang ditulis di dalam repo adalah dokumen ini.

| # | Perintah | Exit code | Ringkasan output nyata |
| --- | --- | --- | --- |
| 1 | `multica agent list --output json` | 0 | 20 agent; 1 agent dengan `custom_env_key_count > 0` |
| 2 | `multica agent get eb0ecee5-…e34 --output json` | 0 | `custom_env_key_count = 1`, `mcp_config_redacted = false` |
| 3 | `multica agent get d1c4be5c-…b72 --output json` | 0 | `custom_env_key_count = 0` |
| 4 | `multica agent env get eb0ecee5-…e34 --output json` | 3 | "You do not have permission to access this resource" |
| 5 | `multica runtime list --output json` | 0 | 7 runtime, semua `online`/`local`/`private` |
| 6 | `multica workspace list --output json` | 0 | 1 workspace: Exta |
| 7 | `multica workspace member list --output json` | 0 | 1 anggota: Jetta (owner) |
| 8 | `multica squad list --output json` | 0 | 7 squad |
| 9 | `multica project list --output json` | 0 | 4 project, termasuk Triangulate |
| 10 | `multica project resource list 0bca82b8-…` | 0 | 1 resource `github_repo` → repo triangulate |
| 11 | `multica repo list --output json` | 0 | `[]` |
| 12 | `gh api .../actions/secrets --jq '.total_count'` | 0 | `0` |
| 13 | `gh api .../actions/variables --jq '.total_count'` | 0 | `0` |
| 14 | `gh auth status` | 0 | 2 akun keyring: `jettapindika` (aktif), `Etzhyy` |
| 15 | `gh api .../branches/main/protection` | 1 | HTTP 404 "Branch not protected" |
| 16 | `gh api .../rulesets` | 0 | `[]` |
| 17 | `gh api 'repos/.../pulls?state=open' --jq 'length'` | 0 | `7` |
| 18 | `grep -rIl --exclude-dir=.git -E '(API_KEY\|SECRET\|TOKEN\|PRIVATE_KEY)\s*=' .` | 1 | tidak ada keluaran (tidak ada berkas cocok) |
| 19 | `git log --all --diff-filter=A --name-only` | 0 | 5 berkas, termasuk `docs/buku-besar/*` dari commit `da96141` |
| 20 | `gitleaks git . --log-opts="--all" --redact --no-banner --exit-code 1` | 0 | `10 commits scanned`, `no leaks found` |
| 21 | `gitleaks dir . --redact --no-banner --exit-code 1` | 0 | `no leaks found` |
| 22 | `git check-ignore -v --no-index <11 berkas>` (repo uji `/tmp/gitignore-test`) | 0 | 10 terabaikan, `.env.example` lolos |
| 23 | hook pre-commit + commit berisi kunci bergaya `ghp_…` (`/tmp/hook-test4`) | 1 | `leaks found: 1`; commit ditolak, `git log` hanya `init` |
| 24 | `curl … /api-keys/v1/introspect` dengan kunci tidak valid | 0 | `http_code=400` / `http_code=404`, endpoint hidup |
| 25 | `find . -path ./.git -prune -o -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' \) -print` | 0 | tidak ada keluaran |

`TIDAK TERVERIFIKASI`: tidak ada langkah di dokumen ini yang berstatus belum dijalankan, kecuali aksi yang memang tidak boleh dieksekusi oleh tugas ini (membuat secret, mengubah branch protection, membuat workflow, `gh secret set`). Semua perintah di bagian 4 dan 8 yang bersifat mengubah keadaan ditandai sebagai prosedur usulan, bukan hasil eksekusi.
