# Spesifikasi otomasi: laporan metrik & pengingat gate roadmap

Rujukan PRD: §12 (metrik), §15 (telemetri), §17 (roadmap), §6 (idle time).
Pemilik dokumen: Bima — Automation Engineer. Issue: EXTA-35 (induk EXTA-31).

**Status: seluruh isi dokumen ini usulan. Tidak ada autopilot atau wakeup
untuk kedua otomasi di bawah yang dibuat, diaktifkan, atau dijadwalkan.**

Kondisi terukur saat dokumen ini ditulis: `multica autopilot list` → `total: 0`.
`multica issue wakeup list` untuk EXTA-31 **tidak** kosong — Benjamin — CEO
memasang tiga wakeup di sana pada 4 Okt 10:35-10:37 UTC untuk rantai
development (pemicu EXTA-32/33/34, bukan pengingat gate roadmap). Tidak satu
pun di antaranya otomasi B di dokumen ini, dan tidak ada yang dibuat oleh
pekerjaan ini.

## 1. Ringkasan

Dua otomasi diusulkan, keduanya mingguan dan keduanya menyentuh board sehingga
butuh persetujuan sebelum dibuat.

| # | Otomasi | Bentuk | Pemicu | Eksekutor | Status |
| --- | --- | --- | --- | --- | --- |
| A | Laporan metrik proyek | autopilot `create_issue` | cron `0 9 * * 1` Asia/Jakarta | Rani — Data & Metrics Engineer | usulan |
| B | Pengingat gate roadmap minggu 0-8 | issue wakeup `cron` di EXTA-31 | cron `15 9 * * 1` Asia/Jakarta | Bima — Automation Engineer | usulan |

Jadwalnya distagger 15 menit supaya dua run tidak mengantre di runtime lokal
yang sama (semua agent Exta terikat ke satu runtime Mac, `a82fac41`).

## 2. Prasyarat yang belum terpenuhi

Ini bukan blocker pekerjaan ini, tapi syarat sebelum aktivasi. Tanpa ini,
otomasi berjalan dan menghasilkan laporan kosong.

| # | Prasyarat | Pemilik | Kenapa |
| --- | --- | --- | --- |
| P1 | Kamus metrik + skema event telemetri final | Rani — EXTA-36 | Skrip agregasi membaca nama event; nama final menentukan kontrak |
| P2 | Sink telemetri: event Roblox → penyimpanan → ekspor NDJSON | Nathan — EXTA-32 (arsitektur), Devan — EXTA-34 (infrastruktur) | Belum ada tempat data mendarat; §15 hanya menyebut event yang wajib ada, bukan jalurnya |
| P3 | `start_date` (tanggal Senin minggu 0) diisi di `docs/roadmap.json` | owner / Rafael — EXTA-46 | Tanpa anchor, minggu berjalan tidak bisa dihitung; skrip menolak jalan |
| P4 | PR dokumen ini dan `tools/` sudah di `main` | owner | Run terjadwal menjalankan skrip dari repo; selama masih di branch, skrip tidak ada di `main` |
| P5 | Eksekutor bisa `multica repo checkout` repo privat `jettapindika/triangulate` | Nathan — CTO/CIO | Belum diuji untuk agent selain Bima |

## 3. Otomasi A — Laporan metrik proyek

**Tujuan:** menutup §12. Sembilan baris metrik punya target angka (baris
kesepuluh, quit 5 menit pertama, memang dipantau tanpa target); tanpa
pemeriksaan berkala, target itu tidak pernah dibandingkan dengan kenyataan.

### Pemicu

Mingguan, Senin 09:00 WIB, mencakup 7 hari terakhir.

```bash
multica autopilot create \
  --title "Laporan metrik mingguan Triangulate" \
  --description "$(cat docs/autopilot-prompt-laporan-metrik.md)" \
  --agent "Rani — Data & Metrics Engineer" \
  --mode create_issue \
  --project 0bca82b8-a11c-49a1-af4a-adef29d0569d \
  --issue-title-template "Laporan metrik Triangulate {{date}}" \
  --subscriber "Jetta" \
  --output json

# <id> dari keluaran perintah di atas
multica autopilot trigger-add <id> \
  --kind schedule \
  --cron "0 9 * * 1" \
  --timezone Asia/Jakarta \
  --label "mingguan Senin 09:00 WIB" \
  --output json
```

Catatan eksekusi:

- `autopilot create` tidak punya flag `--description-file`; prompt dibaca dari
  berkas lewat `$(cat ...)` di shell.
- `--subscriber` menerima nama atau user ID member, bukan alamat email.
- `--timezone` wajib disebut. Cron tanpa zona berjalan UTC, jadi "Senin 09:00"
  yang disetujui owner akan jadi Senin 16:00 WIB.
- `--issue-title-template` hanya menginterpolasi `{{date}}` (UTC,
  `YYYY-MM-DD`). Token lain seperti `{{week}}` ditolak saat create.
- `--agent` menerima nama atau ID. Nama yang dipakai di atas mengandung em
  dash; kalau shell bermasalah, ganti dengan ID
  `9f8e8bfa-af32-47a0-bbd0-fa6fe2bb2a2a`.

### Input

1. Ekspor NDJSON event telemetri, satu objek JSON per baris (jalur P2).
2. `docs/metrics.json` — label, target, dan arah pembanding per metrik, dikutip
   dari §12.
3. `tools/metric-report.py` — agregator.

### Output

Satu issue baru di project Triangulate berjudul `Laporan metrik Triangulate
<YYYY-MM-DD>`, dengan komentar hasil berisi tabel markdown satu baris per
metrik §12: kategori, metrik, nilai, target, verdict, ukuran sampel; ditambah
rincian idle time per role, quit 5 menit pertama per role, dan bagian kualitas
data. Mode `create_issue` dipilih supaya laporan punya tempat tetap yang bisa
dibaca, dikomentari, dan ditutup — `run_only` tidak meninggalkan state sama
sekali.

Contoh keluaran nyata (dijalankan pada fixture uji di
`tools/fixtures/events-sample.ndjson`, bukan data produksi):

```bash
tools/metric-report.py --events tools/fixtures/events-sample.ndjson --as-of 2026-10-06
```

```text
| Kategori | Metrik | Nilai | Target (PRD §12) | Verdict | Sampel |
| --- | --- | --- | --- | --- | --- |
| Retensi | D1 | 33.3% | 18% | PASS | 3 |
| Retensi | D7 | — | 5% | NO DATA | 0 |
| Penyelesaian | % sesi yang menamatkan kasus | 66.7% | > 55% | PASS | 3 |
| Matchmaking | Median waktu tunggu | 30.0 dtk | < 60 dtk | PASS | 5 |
| Matchmaking | % sesi gagal start | 16.7% | < 10% | FAIL | 6 |
| Pengalaman role | Idle time per role | 6.9% | < 25% sesi | PASS | 3 |
| Onboarding | % menamatkan Case 0 | 50.0% | > 80% | FAIL | 2 |
| Drop-off | Quit di 5 menit pertama per role | — | Dipantau, bandingkan antar role | NO DATA | 3 |
| Hint | Rata-rata hint per sesi | 0.67 | 1-2 | FAIL | 3 |
| Konten | Story case baru | 2.00 | 1 per 1-2 minggu | PASS | 1 |
```

### Pemilik

- **Angka dan definisi:** Rani — Data & Metrics Engineer (EXTA-36).
- **Eksekutor run:** Rani (agent yang di-`--agent`).
- **Trigger dan runbook:** Bima — Automation Engineer.
- **Penerima laporan:** owner, lewat `--subscriber`.

### Biaya run

1 run/minggu. Basis EXTA-11 (rata-rata 44 run pada 24 Sep): **93.386 input ·
16.031 output · 976.541 cache-read token per run**. Itu rata-rata seluruh
agent dan merupakan **batas atas** untuk run yang tugasnya menjalankan skrip
dan menempelkan keluaran. Bulanan: ±8,7 run → ±0,81 juta input token.
Harga token tidak diterbitkan platform (`cost_usd_ticks: 0`), jadi biayanya
ditulis dalam token, bukan rupiah.

### Runbook

```bash
# Matikan sementara (trigger tetap ada, tidak ada run)
multica autopilot update <id> --status paused

# Nyalakan lagi
multica autopilot update <id> --status active

# Cek kesehatan: STATUS=active + LAST_STATUS=failed berarti otomasi rusak
multica autopilot list --output json
multica autopilot runs <id> --output json

# Putar ulang satu laporan yang gagal
multica autopilot trigger <id>          # side effect: membuat issue baru
```

**Yang rusak kalau berhenti:** tidak ada data hilang — telemetri tetap
terkumpul. Yang hilang hanya perbandingan berkala terhadap target §12, dan
kembali ke kondisi hari ini (tidak ada yang memeriksa). Deteksi otomasi mati:
`LAST_STATUS=failed` pada baris `STATUS=active`, atau tidak ada issue baru
dalam dua Senin berturut-turut.

### Cara mengukur otomasi ini

Waktu yang dihemat dihitung dari selisih waktu penyusunan laporan manual, bukan
dari perkiraan. Verifikasinya: catat waktu penyusunan manual pada satu siklus
pertama, lalu bandingkan dengan waktu tunggu run (`multica autopilot runs`).

## 4. Otomasi B — Pengingat gate roadmap minggu 0-8

**Tujuan:** menutup §17. Roadmap punya 9 gate (minggu 0-8) dan tiap gate
memutuskan boleh atau tidaknya minggu berikutnya jalan.

### Pemicu

Mingguan, Senin 09:15 WIB, pada issue EXTA-31.

```bash
multica issue wakeup create 01a1065f-43f0-7e99-bcd5-06ac027e5c59 \
  --kind cron \
  --cron "15 9 * * 1" \
  --timezone Asia/Jakarta \
  --instruction-file docs/wakeup-instruksi-gate-roadmap.md \
  --agent-id 88647787-7732-4540-b18a-d5e5afbaf41b \
  --max-fires 9 \
  --output json
```

- `--agent-id` menunjuk Bima, bukan assignee EXTA-31 (Benjamin — CEO). Isi
  pengingat ini mekanis: jalankan skrip, tempel keluaran apa adanya, tanpa
  tafsir. Yang menilai gate tetap owner.
- `--max-fires 9` adalah pengaman sekaligus pembatas: roadmap hanya 9 minggu.
  Kalau roadmap meleset, rule harus dibuat ulang.
- Hasil run dikirim sebagai komentar di EXTA-31 — tidak perlu membuat issue
  baru tiap minggu.

### Input

`tools/roadmap-gate.sh` membaca `docs/roadmap.json` (target dan gate minggu
0-8, dikutip apa adanya dari §17) dan `multica issue children EXTA-31` untuk
keadaan board.

### Output

Satu komentar di EXTA-31: minggu berjalan, target minggu itu, teks gate,
kolom verdict yang sengaja dibiarkan kosong (milik owner), ringkasan status
sub-issue, dan daftar sub-issue yang berubah dalam 7 hari terakhir.

### Pemilik

Bima — Automation Engineer. Verdict gate: owner, dengan Rafael — COO (EXTA-46)
sebagai pemilik operating plan.

### Biaya run

1 run/minggu, basis angka yang sama: batas atas 93.386 input · 16.031 output
token per run; bulanan ±0,81 juta input token bersama otomasi A.

### Runbook

```bash
# Matikan
multica issue wakeup disable 01a1065f-43f0-7e99-bcd5-06ac027e5c59 <wakeup-id>

# Cek rule dan riwayat run
multica issue wakeup list 01a1065f-43f0-7e99-bcd5-06ac027e5c59 --output json
multica issue wakeup runs 01a1065f-43f0-7e99-bcd5-06ac027e5c59 <wakeup-id> --output json

# Putar ulang
multica issue wakeup trigger 01a1065f-43f0-7e99-bcd5-06ac027e5c59 <wakeup-id>

# Hapus permanen (run yang belum mulai ikut dibatalkan)
multica issue wakeup delete 01a1065f-43f0-7e99-bcd5-06ac027e5c59 <wakeup-id>
```

**Yang rusak kalau berhenti:** gate tetap harus diverifikasi, tapi tidak ada
yang mengingatkan. Risiko nyatanya: satu minggu terlewat tanpa keputusan gate,
dan minggu berikutnya dibangun di atas asumsi yang belum diuji.

Catatan saat menulis: EXTA-31 sudah punya tiga wakeup milik Benjamin — CEO
(rantai development, 4 Okt 10:35-10:37 UTC). Saat menjalankan `wakeup disable`
atau `wakeup delete`, pastikan `<wakeup-id>` yang dipakai adalah ID otomasi B,
bukan salah satu dari ketiganya.

## 5. Alur telemetri → agregat → laporan

```
Roblox client/server            (PRD §15: event per role — idle time, waktu ke
  │                              clue pertama, tuduhan, quit point)
  │  ← jalur ini BELUM ADA (P2, EXTA-32 + EXTA-34)
  ▼
Sink telemetri
  │
  │  ekspor NDJSON (satu event per baris)
  ▼
tools/metric-report.py --events <ndjson>
  │   tahap 1 `reduce`  : event → ringkasan sesi, percobaan lobby, rilis case
  │   tahap 2 `report`  : ringkasan → tabel markdown §12 + verdict
  ▼
Issue "Laporan metrik Triangulate <tanggal>"  →  dibaca owner
```

Titik yang hilang ada satu dan itu bukan milik otomasi ini: **belum ada tempat
event telemetri mendarat.** §15 menyebut event apa yang wajib ada, bukan ke
mana ia pergi. Itu keputusan arsitektur (EXTA-32) dan infrastruktur (EXTA-34).

**Siapa mengagregasi.** `tools/metric-report.py` — deterministik, tanpa LLM.
Agent hanya menjalankan dan menempelkan keluaran. Ini disengaja: angka §12
tidak boleh lahir dari tafsiran model.

**Kontrak event.** Nama event di `tools/metric-report.py` (`lobby_enter`,
`lobby_wait`, `lobby_fail`, `session_start`, `idle_start`, `idle_end`,
`hint_used`, `accusation_submitted`, `session_end`, `case_released`) adalah
**ASUMSI** yang dibuat agar skrip bisa diuji sekarang. Yang menggantikannya:
kamus metrik dan skema event final dari Rani (EXTA-36). Kalau namanya berbeda,
yang berubah hanya tabel `EVENTS` di skrip; rumusnya tidak ikut berubah.

**Cara verifikasi angka.** Tiga lapis, semuanya ada di keluaran laporan:

1. **Kolom sampel** — setiap baris menyebut berapa sesi/pemain/lobby yang
   mendasarinya. Rasio dari 3 sesi dan rasio dari 3.000 sesi tidak boleh
   terbaca sama.
2. **Bagian kualitas data** — event tak dikenal, sesi tanpa `session_start`,
   sesi tanpa `session_end`, sesi tanpa role, jumlah percobaan lobby.
3. **`NO DATA`, bukan 0** — metrik yang datanya belum ada ditulis `NO DATA`.
   Laporan kosong tidak pernah menyamar sebagai laporan yang hasilnya nol.

Verifikasi independen: jalankan ulang skrip pada ekspor yang sama dengan
`--emit-summaries` lalu `--summaries`; dua jalur itu harus menghasilkan laporan
yang identik, termasuk catatan kualitas datanya. Ini sudah diuji.

**Nol vs tidak ada data.** `0` hanya dicetak kalau jendelanya memang punya
telemetri. Jendela tanpa satu pun event sesi maupun rilis menghasilkan
`NO DATA` di seluruh baris, bukan deretan nol yang terbaca seperti kegagalan
konten.

## 6. Tabel otomasi vs waktu yang dihemat

Angka token dari EXTA-11 (terukur). Angka waktu **ASUMSI** — tidak ada
baseline manual terukur di workspace ini, jadi setiap baris menyebut apa yang
memverifikasinya.

| Otomasi | Frekuensi | Biaya run (batas atas) | Waktu dihemat | Verifikasi |
| --- | --- | --- | --- | --- |
| A — laporan metrik | 1/minggu | 93.386 in · 16.031 out token | ASUMSI 20-40 menit/minggu menyusun tabel §12 dari data mentah | Catat waktu manual satu siklus pertama (Rani/Dewi) |
| B — pengingat gate | 1/minggu | 93.386 in · 16.031 out token | ASUMSI 5-10 menit/minggu membaca board EXTA-31 dan mencocokkan gate | Bandingkan dengan waktu tunggu run di `wakeup runs` |
| **Total** | 2/minggu | ±0,81 juta input token/bulan | ASUMSI 1,7-3,6 jam/bulan | — |

Nilai yang tidak muncul di tabel tapi lebih besar dari waktu dihemat: hari ini
**tidak ada** yang memeriksa §12 terhadap target, dan **tidak ada** yang
mengingatkan gate §17. Waktu yang dihemat bukan menggantikan pekerjaan yang
ada, melainkan pekerjaan yang saat ini tidak dikerjakan.

Biaya eksternal Rp 0: tidak ada layanan berbayar baru. Harga token tidak
diterbitkan platform, jadi tidak ada angka rupiah yang bisa ditulis.

## 7. Otomasi yang butuh akses baru atau menyentuh board

Tidak satu pun diaktifkan. Semuanya usulan.

| Otomasi | Sifat | Kenapa butuh persetujuan | Approver |
| --- | --- | --- | --- |
| A — laporan metrik | Menyentuh board | Membuat issue baru di project Triangulate tiap minggu | Nathan — CTO/CIO |
| B — pengingat gate | Menyentuh board | Menulis komentar di EXTA-31 tiap minggu | Nathan — CTO/CIO |
| A + B | Memakai budget run berulang | 2 run/minggu tanpa batas waktu untuk A | Nathan — CTO/CIO (biaya berulang) |
| A + B | Prasyarat P4 | Skrip harus ada di `main`; berarti PR ini harus di-merge | owner |
| A + B | Prasyarat P5 | Agent eksekutor harus bisa `repo checkout` repo privat | Nathan — CTO/CIO |

**Tidak ada akses atau kredensial baru yang dibutuhkan.** Kedua skrip hanya
membaca berkas di repo dan memanggil `multica issue children` — keduanya sudah
tersedia. Tidak ada API key, tidak ada secret, tidak ada layanan eksternal.

## 8. Yang sengaja tidak diusulkan

- **Laporan metrik harian.** Data §12 bergerak lambat (retensi D1/D7, kisaran
  penyelesaian). Harian menambah 6 run/minggu tanpa menambah keputusan.
- **Scan board per jam.** Sudah dinilai di EXTA-11 (24 run/hari ≈ 2,24 juta
  input token/hari) dan tidak dikerjakan di sini; itu pekerjaan COO, bukan
  pekerjaan laporan metrik.
- **Verdict gate otomatis.** Skrip menolak menyatakan sebuah gate lulus. Gate
  minggu 0 ("drag halus di mobile") dan minggu 6 ("playtest internal") tidak
  bisa dinilai dari board; keduanya butuh manusia.
- **Notifikasi mention pada pengingat.** Default tanpa mention: follower
  EXTA-31 sudah melihat komentarnya, sedangkan mention ke agent memicu run
  berbayar tambahan. Kalau owner mau mention, itu satu baris tambahan di
  berkas instruksi wakeup.

## 9. Berkas

| Berkas | Isi |
| --- | --- |
| `tools/metric-report.py` | Agregasi event telemetri → laporan §12 |
| `tools/roadmap-gate.sh` | Laporan status gate §17 dari `docs/roadmap.json` + board |
| `docs/metrics.json` | Label, target, arah pembanding per metrik §12 |
| `docs/roadmap.json` | Target dan gate minggu 0-8 §17 + anchor tanggal |
| `docs/autopilot-prompt-laporan-metrik.md` | Isi `--description` autopilot A |
| `docs/wakeup-instruksi-gate-roadmap.md` | Isi `--instruction-file` wakeup B |
| `tools/fixtures/events-sample.ndjson` | Fixture uji untuk `metric-report.py` |
| `docs/automation-spec.md` | Dokumen ini |
