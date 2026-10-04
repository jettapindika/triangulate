Status: DRAFT — usulan, belum aktif
Pemilik: Devan — Infrastructure & Runtime Engineer
Rujukan: PRD §15 (Persyaratan Teknis), §17 (Roadmap), §18 (Risiko) · `exta-infra-runbook` §2
Prasyarat: tidak satu pun perintah di dokumen ini dijalankan sampai owner menyetujui. Ini daftar usulan, bukan catatan operasi.

# Checklist Koneksi Repo — Triangulate

Dokumen ini menjawab lima pertanyaan wajib dari `exta-infra-runbook` §2 sebelum repo dianggap "terhubung": remote & branch, siapa punya akses tulis, apa yang wajib hijau sebelum merge, apa yang berubah pada run agent begitu repo terhubung, dan siapa peninjau PR pertama.

Repo sudah ter-checkout dan 11 PR sudah terbuka (0 merged), jadi sebagian pertanyaan sudah terjawab oleh keadaan. Bagian yang **belum** terjawab adalah gate-nya — dan itu isi utama dokumen ini.

## 0. Ringkasan jawaban

| Pertanyaan runbook §2 | Jawaban hari ini | Status |
|---|---|---|
| Remote dan branch mana | `https://github.com/jettapindika/triangulate`, branch `main` | terjawab |
| Siapa punya akses tulis | `jettapindika` (admin, satu-satunya collaborator) | terjawab, **risiko**: akun pribadi tunggal |
| Apa yang wajib hijau sebelum merge | **belum ada apa pun** — 0 required check, 0 proteksi | **usulan di §2–§3** |
| Apa yang berubah pada run agent begitu repo terhubung | sudah terhubung; yang berubah begitu **CI aktif**: menit Actions, akses token, dan kegagalan yang memblokir PR | **usulan di §5** |
| Siapa peninjau PR pertama | `jettapindika` hari ini; kandidat kedua `Etzhyy` | **usulan di §4** |

## 1. Remote, branch, dan akses tulis

| Hal | Nilai | Sumber |
|---|---|---|
| Remote | `https://github.com/jettapindika/triangulate` | `git remote -v` |
| Default branch | `main` | `gh api repos/jettapindika/triangulate --jq .default_branch` |
| Branch kerja agent | `agent/<slug-agent>/<12-hex-task-id>` | `git branch -vv` |
| Collaborator | `jettapindika` — permission `admin` | `gh api repos/.../collaborators` |
| Deploy key | 0 | `gh api repos/.../keys` |
| Webhook | 0 | `gh api repos/.../hooks` |

Cara agent mendapat akses tulis: **tidak lewat collaborator per-agent.** Token GitHub lokal (`jettapindika`, scope `repo` + `workflow`) yang dipakai proses push, sehingga setiap commit agent di GitHub tercatat atas nama `jettapindika`. Bukti: commit `da96141` di branch EXTA-45 punya author `jettapindika <jettapindika@gmail.com>`.

Dua akibat yang harus disadari sebelum gate diaktifkan:

1. **"Siapa menulis apa" tidak bisa diaudit dari GitHub.** Atribusi hanya ada di commit trailer `Co-authored-by: multica-agent <github@multica.ai>` yang sudah jadi kebiasaan (terlihat di `da96141`). Itu konvensi, bukan kontrol.
2. **Tidak ada pemisahan hak.** Semua agent memakai satu identitas ber-permission `admin` — termasuk hak mengubah proteksi branch, secret, dan workflow. Gate apa pun yang dipasang bisa dibuka kembali oleh proses yang sama.

`ESKALASI →` Nathan — CTO/CIO: putuskan apakah agent menulis lewat akun pribadi owner (kondisi hari ini) atau lewat machine user terpisah dengan permission `write` saja. Ini prasyarat sebelum proteksi branch punya arti.

## 2. Yang wajib hijau sebelum merge (usulan gate)

Hari ini tidak ada apa pun: `gh api repos/.../branches/main/protection` → HTTP 404 `"Branch not protected"`, dan `gh api repos/.../rulesets` → `[]`. Artinya push langsung ke `main` bisa dilakukan siapa pun yang memegang token, dan PR bisa di-merge tanpa satu pun review.

Usulan isi gate, dengan alasan yang diikat ke PRD:

| Aturan | Nilai usulan | Alasan |
|---|---|---|
| Wajib pull request sebelum merge | ya | PRD §10: kasus berupa data; satu perubahan data/skema harus terlihat sebagai satu diff yang bisa ditinjau |
| Jumlah review wajib | 1, `dismiss_stale_reviews: true` | PRD §18: exploit/bocor dicegah lewat pemeriksaan; review basi setelah commit baru harus gugur otomatis |
| Required status check | `lint`, `analyze`, `test` (nama job di `03-pipeline-ci.md`) | PRD §15 + §17: kode Luau tidak boleh masuk `main` tanpa lolos format, analisis statis, dan validasi kasus |
| Larang force-push | ya | riwayat `main` adalah dasar audit; force-push menghapus jejak |
| Larang hapus branch | ya | idem |
| Wajib review dari code owner | **tidak dulu** | belum ada file `CODEOWNERS`; menyalakannya tanpa pemilik file akan memblokir semua PR |
| Wajib review dari luar penulis | **tidak bisa dipaksakan** | semua agent memakai satu identitas GitHub — GitHub tidak melihat "agent berbeda", jadi aturan ini tidak akan pernah terpenuhi secara teknis |

Poin terakhir penting dan sering terlewat: **`required_pull_request_reviews` tidak akan berfungsi sebagai pemisahan tugas selama identitas tunggal dipakai.** GitHub hanya bisa menuntut "reviewer ≠ penulis" kalau penulis punya identitas berbeda. Selama belum ada machine user per agent, review wajib hanya berarti "ada satu approval dari identitas mana pun" — dan identitas itu bisa jadi identitas penulisnya sendiri. Ini alasan kedua mengapa `ESKALASI` di §1 jadi prasyarat.

### 2.1 Perintah usulan — proteksi `main`

Perintah berikut **tidak dijalankan** oleh Devan. Pemegang keputusan: Nathan — CTO/CIO, dieksekusi oleh pemegang token owner.

```bash
# Proteksi main: wajib PR, 1 review, stale review dibuang, required check, larang force-push & hapus
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

Catatan yang mengikat perintah di atas:

- `strict: true` berarti branch PR harus sudah memuat `main` terbaru sebelum merge. Untuk repo dengan beberapa agent menulis paralel, ini yang mencegah dua PR saling menimpa.
- `contexts` harus memakai **nama job** yang persis sama dengan yang didefinisikan di `.github/workflows/ci.yml` (lihat `03-pipeline-ci.md`). Mengganti nama job tanpa memperbarui daftar ini akan membuat gate menunggu check yang tidak pernah datang — dan **PR tidak akan bisa di-merge selamanya.**
- `enforce_admins: true` ikut mengikat owner. Kalau owner ingin bisa menembus gate saat darurat, set `false` — itu keputusan, bukan detail teknis, dan harus dicatat.
- `required_linear_history: true` melarang merge commit. Konsisten dengan usulan squash-only di `01-inventaris-repo-environment.md` §2.

### 2.2 Urutan aktivasi yang benar

Gate dan pipeline saling mengunci: required check yang tidak pernah ada akan memblokir semua merge. Karena itu urutannya:

1. PR pipeline CI di-merge lebih dulu (`03-pipeline-ci.md`), sehingga check `lint`/`analyze`/`test` benar-benar muncul di PR.
2. Verifikasi check muncul minimal sekali di sebuah PR — **bukan diasumsikan**.
3. Baru pasang proteksi branch di §2.1.
4. Kalau CI harus dimatikan sementara, matikan proteksinya lebih dulu; jangan matikan workflow-nya saja.

Langkah 1 dan 2 belum bisa dikerjakan hari ini karena pipeline masih usulan di PR terpisah.

## 3. Setting repo pendukung (usulan)

| Setting | Nilai hari ini | Usulan | Perintah |
|---|---|---|---|
| `delete_branch_on_merge` | `false` | `true` | `gh api --method PATCH repos/jettapindika/triangulate -f delete_branch_on_merge=true` |
| `allow_merge_commit` | `true` | `false` | `gh api --method PATCH repos/jettapindika/triangulate -f allow_merge_commit=false` |
| `allow_rebase_merge` | `true` | `false` | `gh api --method PATCH repos/jettapindika/triangulate -f allow_rebase_merge=false` |
| `allow_squash_merge` | `true` | `true` (biarkan) | — |
| `has_wiki` | `true` | `false` | `gh api --method PATCH repos/jettapindika/triangulate -f has_wiki=false` |
| `sha_pinning_required` | `false` | `true` | `gh api --method PUT repos/jettapindika/triangulate/actions/permissions -f sha_pinning_required=true` |
| `default_workflow_permissions` | `read` | biarkan `read` | sudah benar: `GITHUB_TOKEN` read-only secara default |
| `can_approve_pull_request_reviews` | `false` | biarkan `false` | sudah benar: workflow tidak boleh menyetujui PR-nya sendiri |
| `allowed_actions` | `all` | `selected` + hanya action resmi GitHub | `gh api --method PUT repos/.../actions/permissions -f allowed_actions=selected` |
| Vulnerability alerts | **disabled** | `true` | `gh api --method PUT repos/jettapindika/triangulate/vulnerability-alerts` |
| `security_and_analysis` | `null` (semua fitur keamanan mati) | aktifkan secret scanning + push protection bila plan mendukung | `gh api --method PATCH repos/... -f 'security_and_analysis[secret_scanning][status]=enabled'` |

Dua baris terakhir adalah temuan keamanan, bukan preferensi gaya: hari ini **tidak ada peringatan kerentanan dan tidak ada secret scanning** di repo. Karena repo akan menyimpan skrip CI yang menyentuh kunci Roblox Open Cloud, secret yang ter-commit tidak akan tertangkap oleh apa pun.

`ASUMSI`: ketersediaan secret scanning dan push protection untuk repo **private** bergantung pada plan akun GitHub. `gh api user --jq .plan` mengembalikan `null` pada token ini, jadi plan tidak bisa dibaca dari sini. Yang memverifikasi: Nathan — CTO/CIO membuka Settings → Code security repo dan melaporkan fitur mana yang tersedia.

## 4. Peninjau PR dan konvensi

| Hal | Usulan |
|---|---|
| Peninjau PR pertama | Jetta (owner) — hari ini satu-satunya identitas ber-akses. Kandidat kedua yang sudah terautentikasi di workstation: akun GitHub `Etzhyy` |
| Peninjau untuk perubahan infra | Devan — Infrastructure & Runtime Engineer (`.github/`, `docs/ci/`, `scripts/`) |
| Peninjau untuk perubahan kode game | Nathan — CTO/CIO (`src/`) |
| Peninjau untuk perubahan data kasus | Nadia — Penulis Konten (`data/cases/`) |
| Aturan kepemilikan file | sudah disepakati di EXTA-31: satu penulis per direktori. Belum ada `CODEOWNERS` yang menegakkannya secara otomatis |

`ESKALASI →` Nathan — CTO/CIO: tambahkan `Etzhyy` sebagai collaborator dengan permission `write` supaya review wajib di §2 bisa benar-benar berisi dua identitas berbeda. Tanpa itu, `required_approving_review_count: 1` hanya formalitas.

### 4.1 Konvensi judul PR

Pola yang sudah jalan tanpa dipaksa (kesebelas PR terbuka memakainya):

```
EXTA-<nomor>: <ringkasan imperatif, satu baris>
```

Contoh nyata dari repo (potret 2026-10-04):

| PR | Judul |
|---|---|
| #1 | `EXTA-45: template buku besar pengeluaran Triangulate (pos A/B/C/D)` |
| #2 | `EXTA-41: positioning, ICP, store page, dan rencana akuisisi awal` |
| #3 | `EXTA-44: register risiko Triangulate dan penerapan ambang belanja` |
| #4 | `EXTA-47: draf SOP produksi kasus, varian seed, Cold Case, playtest, dan onboarding Case 0` |
| #5 | `EXTA-36: kamus metrik dan skema event telemetri (PRD §12, §15)` |
| #10 | `EXTA-33: Skema data kasus, validator, dan kontrak loader` |
| #11 | `EXTA-32: Arsitektur teknis, scaffold repo Roblox, dan rencana spike minggu 0` |

Identifier issue **wajib** ada di judul karena nama branch memuat hash task, bukan nomor issue (`01-inventaris-repo-environment.md` §3 poin 4). Tanpa itu, satu-satunya cara memetakan PR → issue adalah membaca isi komentar Multica.

Aturan tambahan yang diusulkan:

- Satu PR = satu issue. PR yang menutup dua workstream sulit ditinjau dan sulit di-revert.
- Isi badan PR menyebut **PRD §** yang jadi dasar, seperti judul PR #5.
- Judul memakai Bahasa Indonesia, sesuai bahasa workspace.
- Jangan pakai `Closes #<n>` untuk issue Multica — nomor issue GitHub dan Multica tidak berbagi ruang nomor, dan repo tidak memakai GitHub Issues.

## 5. Apa yang berubah pada run agent begitu repo terhubung

Repo **sudah** terhubung sebagai project resource sejak 2026-10-04T10:02:19Z. Yang belum terjadi adalah CI. Perubahan yang menyusul saat CI diaktifkan:

| Dampak | Sifat | Perlu keputusan dari |
|---|---|---|
| Menit GitHub Actions terpakai setiap push dan setiap PR | **biaya** — repo private dihitung menit | Michelle — CFO |
| Setiap PR yang gagal check menjadi tidak bisa di-merge | **proses** — agent harus memperbaiki sebelum lanjut | Rafael — COO |
| Job CI mengunduh toolchain Luau (4 arsip Linux = 16.630.040 byte ≈ 15,9 MiB per job tanpa cache) | **waktu & bandwidth** | Devan — Infrastructure & Runtime Engineer |
| Cache Actions menyimpan artefak toolchain | **penyimpanan** — kuota cache terbatas | Michelle — CFO |
| `GITHUB_TOKEN` tersedia di dalam job | **akses** — hari ini read-only, dan itu harus dipertahankan | Nathan — CTO/CIO |
| Kalau kelak CI memanggil Roblox Open Cloud API, kunci tersedia di job | **akses + risiko** — kunci di CI berarti kunci bisa dipakai siapa pun yang bisa mengubah workflow | Nathan — CTO/CIO |

Poin terakhir adalah keputusan desain, bukan detail: selama agent memakai satu identitas `admin`, siapa pun yang bisa membuka PR juga bisa mengubah `.github/workflows/ci.yml` dan mengeluarkan secret dari job. Cara menutupnya ada dua — dan keduanya keputusan owner:

1. **Jangan pernah simpan kunci Roblox di repo secret.** Simpan hanya di environment dengan required reviewer, sehingga job yang butuh kunci harus disetujui manusia.
2. **Pisahkan identitas penulis workflow** dari identitas yang bisa membaca secret (machine user terpisah).

`ASUMSI`: apakah CI perlu menyentuh Roblox sama sekali belum diputuskan. Kalau tidak ada publish otomatis di minggu 0–8 (PRD §17 tidak menyebut publish otomatis), maka **tidak ada secret Roblox yang perlu masuk CI sama sekali** — dan itu opsi paling aman. Yang memverifikasi: keputusan Nathan — CTO/CIO di EXTA-32.

## 6. Checklist siap-jalan

Tanda `[ ]` berarti belum. Tidak ada satu pun yang boleh dicentang Devan sendiri.

- [ ] Machine user GitHub (atau keputusan sadar untuk tetap memakai akun pribadi owner) — **ESKALASI → Nathan**
- [ ] `Etzhyy` (atau identitas kedua) jadi collaborator `write` — **ESKALASI → Nathan**
- [ ] PR pipeline CI di-merge dan check `lint`/`analyze`/`test` terbukti muncul di PR
- [ ] Proteksi `main` dipasang sesuai §2.1
- [ ] Setting repo di §3 diterapkan
- [ ] Vulnerability alerts + secret scanning aktif
- [ ] Konvensi judul PR `EXTA-<n>: …` disosialisasikan ke seluruh workstream
- [ ] Kuota menit Actions dan biaya disetujui — **ESKALASI → Michelle**
- [ ] Keputusan: apakah CI menyentuh Roblox Open Cloud sama sekali — **ESKALASI → Nathan**

## 7. Yang TIDAK tercakup

| Tidak tercakup | Sebab | Cara menutupnya |
|---|---|---|
| Eksekusi perintah di §2.1 dan §3 | batas peran: perubahan repo/akses diusulkan, bukan dijalankan | Nathan — CTO/CIO mengeksekusi dengan token owner |
| Verifikasi bahwa check `lint`/`analyze`/`test` benar-benar muncul | pipeline belum di-merge | jalankan setelah PR `03-pipeline-ci.md` mendarat |
| Apakah plan GitHub mendukung secret scanning di repo private | `gh api user --jq .plan` → `null` | Nathan — CTO/CIO membaca Settings → Code security |
| Isi `CODEOWNERS` | kepemilikan file baru disepakati lewat percakapan EXTA-31 | Devan menulis usulan `CODEOWNERS` setelah struktur `src/` mendarat (EXTA-32) |
| Review wajib sebagai pemisahan tugas | mustahil selama identitas GitHub tunggal | machine user, keputusan Nathan — CTO/CIO |
| Environment Roblox (place/universe) | scaffold EXTA-32 belum mendarat | dokumen arsitektur EXTA-32 |
| Branch protection untuk branch selain `main` | branch agent berumur pendek, proteksi tidak memberi manfaat | tidak perlu |
