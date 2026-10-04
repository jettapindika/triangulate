Status: DRAFT — usulan, belum aktif
Pemilik: Devan — Infrastructure & Runtime Engineer
Rujukan: PRD §15 (Persyaratan Teknis), §17 (Roadmap 8 minggu), §18 (Risiko), §10 (Konten & Replayability), §11 (Social & Retention), §12 (Target Pengguna & Metrik)

# Backup & Restore — Triangulate

Semua angka di dokumen ini berasal dari perintah yang benar-benar dijalankan pada **2026-10-04** di workstation ini. Perintah yang belum pernah dijalankan ditandai `TIDAK TERVERIFIKASI`. Yang tidak bisa diuji sama sekali ditandai `BELUM ADA — tidak bisa diuji`. Keputusan yang bukan milik Devan ditandai `ESKALASI →`.

## 1. Ringkasan

Satu-satunya aset yang **bisa** dicadangkan dan di-restore hari ini adalah repo git `jettapindika/triangulate`. Tiga aset lain yang PRD butuhkan — data kasus JSON (PRD §10), state sesi + telemetri Roblox DataStore (PRD §15, §11), dan konfigurasi secret — belum ada atau belum bisa diakses dari workstation ini, sehingga **belum ada satu pun yang bisa diuji restore-nya**. Itu dinyatakan apa adanya, bukan ditutupi prosedur teoretis.

Hasil uji restore nyata 2026-10-04:

| Kriteria lulus | Manifest (sebelum backup) | Hasil restore | Status |
| --- | --- | --- | --- |
| SHA commit `main` | `5c5f59a7720f5d642871e124640e555485c95fc5` | `5c5f59a7720f5d642871e124640e555485c95fc5` | **identik** |
| Jumlah file `main` | 3 | 3 | **identik** |
| `git bundle verify` | — | exit 0 | **sukses** |
| SHA-256 bundle | `b03eedbcb692ee5b9668514d2d1ceaa325a9eee718d068e3faba03777362a6de` | cocok | **identik** |

Kesimpulan: **LULUS**. Dua skrip disertakan dan sudah dijalankan end-to-end:

| Skrip | Fungsi | Bukti 2026-10-04 |
| --- | --- | --- |
| `scripts/backup-repo.sh` | mirror + bundle + verify + manifest + rotasi | exit 0, `LULUS` |
| `scripts/restore-drill.sh` | restore ke direktori sementara + bandingkan dengan manifest | exit 0, cetak `LULUS` |

## 2. Matriks backup

Kolom `Yang TIDAK tercakup` wajib terisi untuk setiap baris. Daftar cakupan tanpa batas adalah janji kosong.

| Apa yang dicadangkan | Sumber | Jadwal usulan | Terakhir diuji | Kriteria lulus | Yang TIDAK tercakup |
| --- | --- | --- | --- | --- | --- |
| Repo git `jettapindika/triangulate` (semua ref) | `https://github.com/jettapindika/triangulate` (otoritatif) dan checkout worktree (cadangan) | Tiap push ke `main`; drill restore bulanan | **2026-10-04 — LULUS** | SHA `main` identik + jumlah file identik + `git bundle verify` exit 0 + SHA-256 bundle cocok manifest | Isu & PR GitHub, GitHub Actions log, branch protection/ruleset, wiki, release, LFS object, secret nilai, `.git` hook, konfigurasi repo, commit yang belum di-push |
| Data kasus JSON (PRD §10: puzzle, clue, graf, briefing, solusi) | Belum ada di repo. `ASUMSI` lokasi usulan: `data/cases/*.json` — **belum diverifikasi, belum ada** | Tiap merge kasus baru; ikut backup repo | **BELUM ADA — tidak bisa diuji** | Setiap file lolos validator (calon lokasi `tools/validate-case.luau`, milik EXTA-33) + hash manifest cocok | Aset biner lokasi (`.rbxl`, `.rbxm` — di-ignore `.gitignore`), seed varian, terjemahan, riwayat seed daily case |
| Roblox DataStore: state sesi/kasus + telemetri (PRD §15, §11, §12) | Roblox Open Cloud DataStore API — **belum dikonfigurasi, tanpa kredensial** | Harian setelah MVP punya data pemain | **BELUM ADA — tidak bisa diuji** | Snapshot per universe/store bisa dibaca ulang + jumlah entry cocok | `MemoryStoreService` (volatil), OrderedDataStore leaderboard, state sesi live (in-flight), data yang dihapus sebelum snapshot, PII di luar cakupan Roblox |
| Konfigurasi secret (jumlah & **nama** kunci, BUKAN nilai — PRD §15 server-authoritative) | `gh api repos/jettapindika/triangulate/actions/secrets` dan `.../variables` | Tiap perubahan kunci; dicek di drill bulanan | **SEBAGIAN** — jumlah terverifikasi (0 repo secret, 0 repo variable); belum ada nilai untuk diuji | Jumlah & daftar nama kunci cocok dengan catatan inventaris | **Nilai secret tidak pernah dicadangkan** (dilarang); environment secret, Dependabot secret, secret runtime Multica, kredensial Roblox Open Cloud, riwayat rotasi |
| Dokumen/PRD + issue Multica | `docs/prd-v0.2.md` (ikut repo) dan issue Multica via `multica issue list --output json` | Ikut tiap backup repo; ekspor issue bulanan | **2026-10-04** — PRD ikut restore (bagian dari 3 file); ekspor issue **berhasil** (52 issue, exit 0, dibaca ulang dengan `jq`) | PRD ada di hasil restore + hash cocok; ekspor issue bisa dibaca ulang + jumlah issue cocok catatan | Komentar & riwayat aktivitas issue, lampiran/artifact eksternal, agent/automation config, wiki, thread percakapan, state runtime Multica, issue yang dihapus permanen sebelum ekspor |

Untuk baris (3) dan (4) — apa yang dibutuhkan supaya bisa diuji:

- **DataStore (3):** kredensial **Roblox Open Cloud** dengan scope baca DataStore, universe ID game, dan keputusan owner soal store mana yang wajib di-backup. Selama itu belum ada, tidak ada perintah yang bisa dijalankan. `ESKALASI →` Nathan — CTO/CIO untuk penyediaan kredensial.
- **Secret (4):** nilai secret memang **tidak boleh** dicadangkan, jadi yang bisa diuji hanya enumerasi nama/jumlah kunci. Saat ini terverifikasi 0 repo secret dan 0 repo variable, jadi belum ada yang bisa diuji. Uji restore penuh untuk secret tidak berlaku; yang berlaku adalah uji **rotasi** (PRD §15), dan itu `BELUM ADA — tidak bisa diuji` sampai ada kunci pertama.

## 3. Prosedur uji restore

### 3.1 Langkah

```bash
# 1. buat backup
REPO_PATH=/path/ke/triangulate \
BACKUP_DIR=/tmp/triangulate-backup \
KEEP_LAST=7 \
bash scripts/backup-repo.sh

# 2. uji restore dari backup terbaru
BACKUP_DIR=/tmp/triangulate-backup \
RESTORE_ROOT=/tmp/triangulate-restore-drill \
bash scripts/restore-drill.sh
```

Atau langsung dari remote tanpa checkout lokal:

```bash
MIRROR_URL=https://github.com/jettapindika/triangulate \
BACKUP_DIR=/tmp/triangulate-backup \
KEEP_LAST=7 \
bash scripts/backup-repo.sh
```

### 3.2 Format manifest

`manifest.env` ditulis di tiap direktori backup. Contoh nyata dari run 2026-10-04T10:28:19Z (nilai apa adanya, tanpa perubahan):

```
BACKUP_TS=20261004T102819Z
SOURCE=/Users/mac/multica_workspaces_desktop-api.multica.ai/exta-cc8280996e94/exta-34-bd869e15e75b/workdir/triangulate
MAIN_REF=refs/heads/main
MAIN_SHA=5c5f59a7720f5d642871e124640e555485c95fc5
MAIN_FILES=3
BUNDLE_BYTES=108390
BUNDLE_SHA256=b03eedbcb692ee5b9668514d2d1ceaa325a9eee718d068e3faba03777362a6de
BUNDLE_PATH=/tmp/triangulate-backup-final/20261004T102819Z/triangulate.bundle
MIRROR_REFS=28
GIT_VERSION=git version 2.50.1 (Apple Git-155)
```

`restore-drill.sh` membaca manifest dengan `awk`, **bukan** `source`. Alasannya nyata: nilai `GIT_VERSION` memuat tanda kurung (`(Apple Git-155)`), dan `source`-ing manifest gagal — `bash -c 'source manifest.env'` mencetak `syntax error near unexpected token '('` dengan exit 1 (teramati pada bash 3.2.57). `BUNDLE_SHA256` adalah satu-satunya penanda integritas byte bundle; lihat §3.7.

### 3.3 Kriteria lulus (eksplisit)

Uji dinyatakan **LULUS** hanya jika keempatnya terpenuhi. Skrip mencetak `LULUS`/`GAGAL` dan **exit non-zero saat gagal**.

1. SHA-256 file bundle cocok dengan `BUNDLE_SHA256` di manifest.
2. `git bundle verify` exit 0.
3. SHA commit `main` hasil restore **identik** dengan `MAIN_SHA` di manifest.
4. Jumlah file (`git ls-tree -r --name-only main | wc -l`) hasil restore **identik** dengan `MAIN_FILES` di manifest.

### 3.4 Hasil uji yang dijalankan — 2026-10-04

Kondisi sumber sebelum backup:

```bash
git -C <repo> rev-parse origin/main
# 5c5f59a7720f5d642871e124640e555485c95fc5
git -C <repo> ls-tree -r --name-only origin/main
# .gitignore
# README.md
# docs/prd-v0.2.md
```

| Langkah | Perintah | Hasil | Durasi terukur |
| --- | --- | --- | --- |
| Backup penuh | `bash scripts/backup-repo.sh` | exit 0, `LULUS — main=5c5f59a... file=3` | 0.31–0.39 s (`time -p` real, seluruh run 2026-10-04) |
| Drill restore | `bash scripts/restore-drill.sh` | exit 0, `LULUS` | 0.32–0.33 s (`time -p` real) |
| Drill via `MIRROR_URL` GitHub | `MIRROR_URL=... bash scripts/backup-repo.sh` lalu drill | exit 0, `LULUS` | backup 2.43 s (termasuk mirror dari GitHub); drill 0.32 s |
| Mirror dari GitHub | `git clone --mirror https://github.com/jettapindika/triangulate` | exit 0, SHA `main` identik | 1638 / 1550 / 1557 ms |
| Bundle create | `git -C <mirror> bundle create <bundle> --all` | exit 0 | 151 / 141 / 141 ms |
| Bundle verify | `git -C <mirror> bundle verify <bundle>` | exit 0, `is okay` | 87 / 100 / 96 ms |
| Restore clone | `git clone <bundle> <dir>` | exit 0, `fatal` tidak ada | 135 / 165 / 111 ms |

Ketiga run di atas diukur dengan pencatat milidetik di sekeliling perintah, bukan `time -p`. Angka ini hanya berlaku untuk repo 3 file hari ini.

Ukuran artefak **bervariasi antar run** karena repo sedang aktif diubah agen lain secara paralel; jumlah ref bergerak. Nilai nyata yang masih tersimpan dan terverifikasi pada 2026-10-04: bundle `61966` B (22 ref), `82317` B (25 ref), `84445` B (14 ref), `101383` B (19 ref), `108390` B (28 ref), `109179` B (28 ref); mirror `176`–`492` KB. Ini normal, bukan indikasi kerusakan — karena itu **jangan pakai ukuran bundle sebagai kriteria integritas**; pakai SHA-256 di manifest.

### 3.5 RTO dan RPO

| Metrik | Nilai terukur | Dasar |
| --- | --- | --- |
| **RTO** (waktu pulih jalur git) | **0.31–0.39 s backup + 0.32–0.33 s drill**, jadi di bawah 1 s untuk repo 3 file | `time -p` pada run 2026-10-04 |
| **RPO** jalur git | **0 commit** | Setiap commit ada di remote GitHub; mirror menyalin semua ref |
| Waktu `git clone --mirror` dari GitHub | 1.55–1.64 s (3 run); backup `MIRROR_URL` penuh 2.43 s | Diukur 2026-10-04 |

Angka ini akan naik seiring pertumbuhan repo (aset, kasus, riwayat commit) dan **tidak boleh dipakai sebagai janji SLA**. Ukur ulang sebelum rilis minggu 8 (PRD §17).

### 3.6 Uji jalur gagal (bukti skrip benar-benar mendeteksi)

| Skenario | Perlakuan | Keluaran | Exit |
| --- | --- | --- | --- |
| SHA manifest diubah | `MAIN_SHA` diganti `000...0` | `GAGAL: SHA main berbeda` | **1** |
| Bundle ditambah sampah | `printf 'CORRUPT' >> bundle` | `GAGAL: sha256 bundle berbeda (...)` | **1** |
| Bundle dipotong separuh | `truncate -s $((size/2)) bundle` | `GAGAL: sha256 bundle berbeda (...)` | **1** |
| Manifest tidak ada | `MANIFEST=/tmp/tidak-ada.env` | `GAGAL: manifest tidak ada: ...` | **1** |
| Rotasi | 5 backup berturut-turut, `KEEP_LAST=3` | 3 direktori tersisa | 0 |

### 3.7 Temuan: `git bundle verify` tidak mendeteksi korupsi byte

Ini ditemukan saat uji jalur gagal dan penting untuk insiden:

| Perlakuan pada bundle | `git bundle verify` | `git clone` dari bundle | SHA-256 |
| --- | --- | --- | --- |
| Append `CORRUPT` di akhir | **exit 0** (`is okay`) | exit 128, `fatal: pack has junk at the end` | berbeda |
| Potong separuh file | **exit 0** (`is okay`) | exit 128, `fatal: early EOF` | berbeda |

Artinya: **`git bundle verify` saja tidak cukup sebagai gerbang integritas.** Karena itu kriteria lulus menaruh SHA-256 di urutan pertama, dan drill tidak berhenti di `verify`.

### 3.8 Temuan: mirror dari worktree agen tidak punya `refs/heads/main`

`git clone --mirror <worktree>` menyalin apa adanya: worktree agen berada di branch `agent/...`, sehingga mirror hanya punya `refs/remotes/origin/main` dan **tidak** punya `refs/heads/main`. Akibatnya `git -C <mirror> rev-parse main` gagal dengan `fatal: ambiguous argument 'main'`. Skrip menangani ini dengan `git update-ref refs/heads/main refs/remotes/origin/main` sebelum membuat bundle. Untuk backup produksi, `MIRROR_URL` lebih tepat karena ref yang tersimpan adalah ref remote yang sebenarnya.

### 3.9 Ekspor issue Multica (diuji 2026-10-04)

Ekspor issue untuk backup dijalankan dan **berhasil**:

```bash
multica issue list --output json --limit 100 --offset 0 > /tmp/multica-issues-p1.json
jq -r '(.issues|length), .has_more' /tmp/multica-issues-p1.json
# 52
# false
```

Hasil: exit 0, 52 issue, `has_more=false` (seluruh issue workspace tercakup dalam satu halaman `--limit 100`). Percobaan `--offset 100` mengembalikan 0 issue, konsisten. Ekspor dengan `--fields id,identifier` juga exit 0 dan deterministik (dua kali jalan menghasilkan SHA-256 identik). Issue EXTA-34 terkonfirmasi ada di hasil ekspor. Ini membuktikan ekspor **bisa dibaca ulang**; yang belum diuji adalah penjadwalan otomatis dan penyimpanan hasil ekspor di luar workstation.

### 3.10 Batas alat

| Alat | Status | Bukti |
| --- | --- | --- |
| `bash -n scripts/backup-repo.sh` | exit 0 | dijalankan 2026-10-04 |
| `bash -n scripts/restore-drill.sh` | exit 0 | dijalankan 2026-10-04 |
| `shellcheck scripts/backup-repo.sh` | exit 0 (tanpa temuan) | shellcheck 0.11.0, dijalankan 2026-10-04 |
| `shellcheck scripts/restore-drill.sh` | exit 0 (tanpa temuan) | shellcheck 0.11.0, dijalankan 2026-10-04 |

`shellcheck` awalnya **tidak terpasang** di workstation (`command -v shellcheck` kosong). Alat ini lalu dipasang selama sesi (`brew install shellcheck` → 0.11.0) dan kedua skrip dijalankan ulang. Temuan pertama pada `restore-drill.sh` adalah `SC2012` (pemakaian `ls` untuk memilih manifest terbaru); baris itu diganti menjadi `printf` + `sort`, dan setelah itu `shellcheck` bersih (exit 0) untuk kedua skrip.

## 4. Jadwal usulan

| Kapan | Apa | Perintah | Pemilik |
| --- | --- | --- | --- |
| Tiap push ke `main` | Backup repo (hook atau CI) | `MIRROR_URL=... bash scripts/backup-repo.sh` | Devan |
| Harian 03:00 WIB | Backup repo + rotasi `KEEP_LAST=7` | sama | Devan |
| Bulanan | Drill restore penuh, hasil dicatat di issue | `bash scripts/restore-drill.sh` | Devan |
| Sebelum rilis minggu 8 (PRD §17) | Drill restore **wajib** lulus sebelum rilis | `bash scripts/restore-drill.sh` | Devan |
| Tiap merge kasus baru | Backup data kasus (setelah `data/cases/` ada) | `TIDAK TERVERIFIKASI` | Devan |
| Harian | Snapshot DataStore (setelah kredensial ada) | `TIDAK TERVERIFIKASI` | Devan |

Frekuensi, retensi, dan lokasi penyimpanan adalah usulan, bukan keputusan — lihat §6.

## 5. Runbook insiden

### 5.1 Repo/commit hilang atau force-push ke `main`

Risiko nyata, bukan hipotetis: **branch `main` tidak terproteksi** (`GET /repos/jettapindika/triangulate/branches/main/protection` → HTTP 404 "Branch not protected"; rulesets `[]`). Tidak ada yang menghalangi `git push --force` ke `main` hari ini.

- **Gejala:** `git log origin/main` tidak lagi memuat commit yang sebelumnya ada; SHA `main` di GitHub berbeda dari manifest backup terakhir.
- **Langkah mitigasi:**
  ```bash
  cat /tmp/triangulate-backup/<ts>/manifest.env
  git clone /tmp/triangulate-backup/<ts>/triangulate.bundle /tmp/triangulate-recover
  git -C /tmp/triangulate-recover log --oneline -5
  git -C /tmp/triangulate-recover push origin main
  ```
  Langkah `push` **hanya setelah disetujui** — jangan dijalankan sendiri.
- **Mengeksekusi:** Devan (pemulihan teknis); langkah push butuh persetujuan.
- **Melapor:** Nathan — CTO/CIO (insiden). `ESKALASI →` Nathan untuk mengaktifkan branch protection sebagai pencegahan.

### 5.2 Secret bocor

- **Gejala:** token/kunci muncul di commit, log, issue, atau pesan; aktivitas tak dikenal pada akun GitHub/agent; alert dari secret scanning.
- **Langkah mitigasi:**
  ```bash
  gh api repos/jettapindika/triangulate/actions/secrets --jq '.secrets[].name'
  gh api repos/jettapindika/triangulate/actions/variables --jq '.variables[].name'
  ```
  Rotasi di sisi penyedia (GitHub/Roblox) lalu set ulang lewat jalur aman. **Nilai secret tidak pernah dikutip di issue, dokumen, atau log** — kalau sudah terlanjur terposting sebagai teks biasa, itu insiden; laporkan, jangan salin nilainya.
- **Mengeksekusi:** Nathan — CTO/CIO (pemegang akses).
- **Melapor:** Nathan — CTO/CIO; Rafael — COO bila berdampak proses.

### 5.3 Data kasus korup atau hilang

- **Gejala:** validator gagal pada file kasus; `data/cases/*.json` tidak parse; jumlah kasus berkurang dari catatan; rantai solusi buntu.
- **Langkah mitigasi:**
  ```bash
  git clone /tmp/triangulate-backup/<ts>/triangulate.bundle /tmp/triangulate-recover
  git -C /tmp/triangulate-recover show main:data/cases/<nama>.json > /tmp/recovered.json
  ```
  Jalankan validator sebelum commit. `TIDAK TERVERIFIKASI` — `data/cases/` dan validator belum ada.
- **Mengeksekusi:** Devan (pemulihan file); validasi kasus oleh pemilik skema EXTA-33.
- **Melapor:** Nathan — CTO/CIO (pemilik skema + validator EXTA-33).

### 5.4 DataStore Roblox terhapus atau rusak

- **Gejala:** pemain kehilangan progress/streak; leaderboard mingguan kosong; telemetri berhenti masuk; error Open Cloud saat membaca store.
- **Langkah mitigasi:** `BELUM ADA — tidak bisa diuji`. Belum ada kredensial Roblox Open Cloud, jadi belum ada satu pun perintah yang bisa dijalankan. Rencana setelah kredensial ada: ekspor snapshot store ke penyimpanan terpisah, lalu pulihkan dari snapshot terakhir.
- **Mengeksekusi:** Devan (setelah kredensial ada).
- **Melapor:** `ESKALASI →` Nathan — CTO/CIO (kredensial & akses); Michelle — CFO bila menyangkut biaya penyimpanan.

## 6. Eskalasi

- `ESKALASI →` **Michelle — CFO:** biaya penyimpanan backup. Berapa lama retensi (7 hari, 30 hari, 1 tahun?), apakah backup disimpan di penyimpanan berbayar, dan berapa volume wajar setelah repo tumbuh (aset gambar puzzle, PRD §15). Biaya belum bisa dihitung karena volume final belum diketahui.
- `ESKALASI →` **Nathan — CTO/CIO:** retensi, lokasi backup, dan siapa punya akses. Termasuk keputusan apakah backup disimpan di luar GitHub (mis. object storage) atau cukup mirror GitHub, dan apakah branch protection untuk `main` akan diaktifkan (lihat §5.1 — risiko nyata yang masih terbuka).
- `ESKALASI →` **Nathan — CTO/CIO:** penyediaan kredensial Roblox Open Cloud supaya backup DataStore (§2 baris 3, §5.4) bisa diuji. Tanpa ini, baris DataStore tetap `BELUM ADA — tidak bisa diuji`.

## 7. Yang tidak bisa diuji hari ini

| Aset | Alasan | Yang dibutuhkan |
| --- | --- | --- |
| Data kasus JSON | Belum ada di repo; lokasi `data/cases/` masih `ASUMSI` | Skema + validator EXTA-33 (Nathan) |
| DataStore Roblox | Tanpa kredensial Open Cloud | Kredensial + universe ID + keputusan owner |
| Konfigurasi secret | 0 repo secret, 0 repo variable — tidak ada yang bisa diuji | Kunci pertama dibuat |
| Penjadwalan ekspor Multica | Ekspor manual terbukti jalan (52 issue, §3.9); penjadwalan + penyimpanan hasil belum ada | Cron/CI + lokasi penyimpanan |
