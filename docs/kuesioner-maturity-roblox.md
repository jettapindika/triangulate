# Draf kuesioner maturity Roblox — Triangulate

Pemilik: **Nathan — CTO/CIO** · Issue: EXTA-61 · Induk: EXTA-31 · Tanggal: 2026-10-04
Rujukan PRD: `docs/prd-v0.2.md` §3, §11, §14, §16 · Riset EXTA-40

> **Status: DRAF. BELUM DIKIRIM.** Kuesioner ini hanya bisa diisi dan dikirim
> manusia lewat Creator Dashboard. Dokumen ini menyiapkan jawabannya dan
> menandai butir yang butuh keputusan manusia lebih dulu. Tidak ada klaim
> bahwa pengiriman sudah terjadi.

---

## 1. Kenapa ini menghambat rilis, bukan urusan setelah rilis

Kutipan langsung dari dokumentasi Roblox:

> "If an experience does not have accurate or all content maturity information,
> Roblox restricts the playability of the experience on the platform for all
> players."
> — `https://create.roblox.com/docs/production/promotion/content-maturity`

Artinya experience yang sudah dipublikasikan tanpa kuesioner maturity **tidak
bisa dimainkan siapa pun**. Ini bukan pekerjaan polish; ini prasyarat publish.

Alur pengisian: Creator Dashboard → **Configure** → **Questionnaire** → **Start**
→ jawab tiap halaman → **Save and Continue** → **Questionnaire Preview** →
**Submit**. Label langsung terbit ke halaman experience saat Submit.

Kewajiban memperbarui:

> "If you publish an update that changes any of the answers from the
> questionnaire, you **must** update your answers and resubmit the questionnaire
> to remain compliant."

Konsekuensi untuk dokumen ini: jawaban di bawah sah untuk **scope MVP P0**.
Begitu fitur P1 yang menyentuh deskriptor berat masuk — Agency HQ, dekorasi,
NPC Director — kuesioner wajib dikirim ulang.

## 2. Label dan siapa yang bisa memainkan

Empat label: **Minimal / Mild / Moderate / Restricted**.

| Label | Arti (verbatim dari dokumentasi) |
|---|---|
| Minimal | Tidak ada konten yang tercantum di deskriptor mana pun |
| Mild | "May contain repeated mild violence, heavy unrealistic blood, mild fear-based content, and/or mild crude humor." |
| Moderate | "May contain moderate violence, light realistic blood, moderate fear-based content, moderate crude humor, and/or unplayable gambling content." |
| Restricted | "only accessible to age-verified Roblox users 18 and older" |

Pemetaan ke audiens — `https://create.roblox.com/docs/production/publishing/kids-and-select`:

- **Minimal atau Mild** → Roblox Kids (5–8) **dan** Roblox Select (9–15) **dan** Roblox 16+.
- **Moderate** → Roblox Select (9–15) **dan** Roblox 16+.
- **Restricted** → hanya 18+ terverifikasi usia.

Catatan penting: **Roblox tidak memakai label "13+"**. Target 13+ di PRD §14
harus diterjemahkan: label yang menjangkau 13–15 adalah **Mild atau Moderate**
(melalui Roblox Select). Keduanya memenuhi target §14; Restricted tidak.

**Rekomendasi label untuk MVP P0: `Mild`.** Alasan per kategori ada di bagian 3.

## 3. Draf jawaban per kategori

Kategori kuesioner yang relevan, beserta draf jawaban dan dasarnya di PRD.
Yang ditandai **ASUMSI** berarti jawabannya bergantung pada bentuk akhir konten
yang belum ada — dan itu justru alasan bagian 4 ada.

| Kategori | Draf | Dasar | Keyakinan |
|---|---|---|---|
| **Violence** | Tidak ada | PRD §3: cozy noir tanpa gore, tanpa pembunuhan eksplisit. Tema: pencurian, pemalsuan, sabotase, orang hilang. §14: "Konten non-gore, tema kejahatan non-kekerasan". Tidak ada combat, tidak ada senjata, tidak ada kematian pemain | Tinggi |
| **Blood** | Tidak ada | PRD §3 dan §14 mengecualikan gore secara eksplisit. Tidak ada satu pun mekanik yang menampilkan darah | Tinggi |
| **Fear** | **Mild** — *butuh konfirmasi* | Tema cozy noir: suasana tegang, ruangan gelap, tapi tanpa jumpscare, tanpa pengejaran (patroli NPC ada di P1), tanpa kekerasan | **Sedang — lihat 4.1** |
| **Crude humor** | Tidak ada | Tidak ada humor kasar di desain maupun data kasus | Tinggi |
| **Unplayable gambling** | Tidak ada | Tidak ada undian, tidak ada taruhan, tidak ada loot box | Tinggi |
| **Strong language** | Tidak ada | PRD §7: komunikasi lewat ping wheel dengan frasa tetap yang divalidasi server (`src/shared/PingPhrases.luau`); text chat opsional memakai filter Roblox; voice tidak diwajibkan | Tinggi |
| **Romantic themes** | Tidak ada | Tidak ada tema romantis di PRD maupun di data kasus | Tinggi |
| **Alcohol** | Tidak ada | Tidak ada konsumsi alkohol, tidak ada bar/klub di lokasi kasus | Tinggi |
| **Social hangout** | **Tidak** — *butuh konfirmasi* | PRD §16 menempatkan Agency HQ (satu-satunya permukaan yang berpotensi jadi ruang sosial) di **P1**, bukan MVP. Sesi MVP diarahkan ke satu kasus dengan timer | **Sedang — lihat 4.2** |
| **Free-form user creation** | **Tidak** — *butuh konfirmasi* | Tidak ada editor, tidak ada pembuatan konten oleh pemain. Kasus adalah data yang ditulis tim (`data/cases/*.json`). Dekorasi HQ ada di P1 | **Sedang — lihat 4.2** |
| **Sensitive issues** | Tidak ada | Tema kejahatan properti (pencurian, pemalsuan, sabotase, orang hilang), bukan kekerasan, pelecehan, atau diskriminasi | Sedang-tinggi |
| **Paid random items** | Tidak ada | PRD §13: "Tanpa pay-to-win. Solusi dan hint tidak bisa dibeli." Hint hanya dari kuota gratis per kasus. Tidak ada paid random item | Tinggi |
| **Paid item trading** | Tidak ada | Tidak ada sistem trading antar pemain | Tinggi |
| **Media** | Tidak ada | Tidak ada video atau musik pihak ketiga yang dilisensikan; aset audio/visual berasal dari platform | Sedang |
| **AI interaction** | Tidak ada | "NPC Archivist" (PRD §8) adalah NPC berbasis aturan di dalam engine, bukan model AI generatif | Tinggi |

**Konsekuensi dua kategori kritis.** Dokumentasi menyatakan tegas:

> "Roblox restricts free-form user creation and social hangouts to players over 16."

Jadi bila **Social hangout** atau **Free-form user creation** dijawab **Ya**,
experience ini pindah ke **16+** — dan audiens 13–15, target utama PRD §12,
hilang. Untuk MVP P0 jawabannya **Tidak**, karena Agency HQ ada di P1 (§16).
Begitu HQ dan kosmetik dekoratif masuk, jawaban itu berubah dan kuesioner
**wajib** dikirim ulang.

## 4. Butir yang harus dikonfirmasi manusia sebelum dikirim

Ini daftar yang membuat dokumen ini draf, bukan jawaban final. Tidak satu pun
bisa diselesaikan dari lingkungan ini.

### 4.1 Deskriptor "Fear" — butuh keputusan desain

Draf menjawab **Mild** dengan dasar: suasana tegang tanpa jumpscare, tanpa
pengejaran, tanpa kekerasan. Yang belum bisa dipastikan tanpa melihat build
akhir:

- Seberapa gelap pencahayaan lokasi? Apakah ada ruang yang gelap total?
- Apakah ada audio sting atau musik yang dirancang mengejutkan?
- Apakah ada satu pun momen yang dimaksudkan membuat pemain terkejut?

`docs/art/ui-spec.md` dan `docs/prd-v0.2.md` tidak menyebut jumpscare, tetapi
keduanya juga tidak melarangnya secara eksplisit. **Risiko:** menjawab Mild
untuk konten yang sebenarnya Moderate berarti label tidak akurat, dan itu
melanggar kewajiban di bagian 1. **Keputusan:** owner/desainer, setelah build
lokasi ada (minggu 2, EXTA-55 — belum dieksekusi).

### 4.2 Agency HQ, kosmetik, dan dua deskriptor 16+

Agency HQ (PRD §11: squad punya agency berlevel dengan HQ yang bisa didekor)
menyentuh dua deskriptor sekaligus: **Social hangout** dan **Free-form user
creation**. PRD §16 menempatkannya di P1, jadi draf MVP menjawab Tidak.

Yang harus diputuskan manusia:

- Apakah kosmetik **Handler** (set potongan puzzle, terlihat di Table Preview
  milik Director) dan kosmetik **Director** (skin clue board) tetap "pilih dari
  katalog", atau pemain bisa menata sendiri?
- Apakah dekorasi HQ di P1 memungkinkan pemain menempatkan objek yang terlihat
  pemain lain? Kalau ya, itu free-form user creation.
- Apakah HQ berfungsi sebagai ruang kumpul bebas, atau tetap lobby yang
  diarahkan ke satu kasus? Kalau bebas, itu social hangout.

Selama jawabannya "katalog, bukan penataan bebas" dan "lobby terarah, bukan
ruang kumpul", jawaban **Tidak** aman untuk kedua deskriptor.

### 4.3 Bahasa store page — aturan yang mengikat

Peringatan yang sudah tercatat di `docs/marketing/positioning-icp-store-page-akuisisi.md`
dan berlaku juga di sini: **jangan pernah** menulis "hangout", "roleplay",
"vibes", "chill with friends", "private room", atau "cafe/bar" di store page,
judul, deskripsi, atau materi promosi mana pun. Kata-kata itu memicu
klasifikasi *social hangout*, dan social hangout tanpa private space hanya
untuk 16+ — memotong audiens 13–15.

### 4.4 Siapa yang mengirim

`docs/decision-log.md` mencatat **G-11/B-06**: kuesioner maturity belum punya
pemilik eksekusi dan belum punya tanggal. EXTA-46 mengusulkan **Damar**
menyiapkan dan **owner** mengirim. Sampai itu ditetapkan, draf ini menunggu.

## 5. Yang belum diklaim

- Kuesioner **belum diisi**, **belum dikirim**, dan **belum ada label terbit**.
- Angka batas karakter deskripsi store page (±950 karakter) belum diverifikasi — `ASUMSI`; yang memverifikasi adalah field deskripsi di Creator Dashboard.
- Syarat pengiriman lain (akun Creator terverifikasi, 2FA, biaya publikasi atau langganan aktif) belum diperiksa — semuanya di luar lingkungan ini.
- Jalur evaluasi Roblox Kids/Select menuntut **250 unique plays dari highly engaged players dalam 60 hari**, dan jalur cepatnya **50.000 Robux (refundable)**. Butir terakhir adalah belanja → eskalasi ke CFO, bukan keputusan CTO/CIO.
- Kategori di atas disalin dari dokumentasi dan riset EXTA-40. **Urutan dan susunan halaman di UI Creator Dashboard bisa berbeda**; yang dipakai adalah label kategori resminya, bukan tata letaknya.

## 6. Sumber

- `https://create.roblox.com/docs/production/promotion/content-maturity` — label, definisi, alur pengisian, kewajiban kirim ulang, pembatasan 16+ untuk social hangout dan free-form user creation. Diakses 2026-10-04.
- `https://create.roblox.com/docs/production/publishing/kids-and-select` — pemetaan label ke Roblox Kids / Select / 16+, syarat 250 unique plays, biaya expedited review 50.000 Robux. Diakses 2026-10-04.
- `https://create.roblox.com/docs/production/publishing/publish-games-and-places` — alur publikasi place. Diakses 2026-10-04.
- Riset EXTA-40 (komentar hasil, issue `01a10665-4980-7cfc-90e5-df8b689e9eb2`) — kutipan verbatim definisi label dan daftar kategori kuesioner.
- `docs/prd-v0.2.md` §3, §7, §8, §11, §12, §13, §14, §16.
- `docs/marketing/positioning-icp-store-page-akuisisi.md` — peringatan kosakata store page.
- `docs/decision-log.md` — G-11/B-06 (pemilik dan tanggal kuesioner belum ditetapkan).
