# Catatan MVP — minggu 0-1

Rujukan: PRD v0.2 §15, §16, §17. Dokumen ini mencatat apa yang benar-benar
jalan setelah minggu 0-1, apa yang belum, dan risiko teknis yang terbukti dari
spike — bukan daftar rencana.

Yang bisa dijalankan ulang ada di repo: `lune run tests/run.luau` (967 assertion,
19 berkas spec), `lune run tests/leak-sweep.spec.luau`, dan
`lune run tools/spike-s02-protokol.luau`. Angka di bawah berasal dari ketiganya
plus `docs/spike-minggu-0-hasil.md`.

Angka 967 adalah hasil terakhir, setelah pekerjaan minggu 6 di `main` ditambah
EXTA-57 (minggu 4). Naik dari 566 karena tiga berkas spec baru (`location-map`,
`case-content`, `puzzle-types`) dan perluasan `leak-sweep`, `ping`, serta
`telemetry`; EXTA-57 menambahkan `tests/accusation-gate.spec.luau`.

## 1. Apa yang sudah jalan

| Bagian PRD | Yang ada sekarang | Bukti |
|---|---|---|
| §15 meja top-down | Kamera `Scriptable` top-down, raycast jari ke bidang meja (`Table.mount`) | `src/client/Table/init.luau`; matematika sinar-bidang diuji di `tests/puzzle-table.spec.luau` |
| §15 posisi potongan diatur server | Server pemegang `PuzzleTable.State`; client hanya menerima `{id, region, x, y, placed}` | `PuzzleTable.clientPayload` membuang `target` dan `correct` |
| §15 interpolasi di client | `PuzzleTable.interpolate` dipanggil tiap `RenderStepped` | `src/client/Table/init.luau:310` |
| §4 drag-and-snap | Ambil potongan, gerakkan mengikuti jari, lepas → snap ke sel terdekat | `grab`/`drag`/`release` di `src/client/Table/init.luau` |
| §4 tiga tipe puzzle end to end | `torn_doc` 16 potongan, `timeline` 8, `cipher` 9 — ketiganya dirakit sampai `solved` lewat jalur server | `tests/puzzle-types.spec.luau`; `tests/gate-minggu-0.spec.luau` suite 3 untuk rantai `torn_doc` di `gallery_01.json` |
| §15 server-authoritative | Resep deduksi, penilaian tuduhan, dan penyelesaian meja semuanya di server | `src/server/init.server.luau`; `tests/leak-sweep.spec.luau` 30 pasangan view×role, 0 temuan |
| §4 Clue Card dari bukti | Meja selesai → `yields` → `ClueCard` ke Director, Handler, Searcher dengan proyeksi per role | `handlePlacePiece`, `src/server/init.server.luau:547` |
| §16 data-driven | Tipe puzzle dibaca dari `data/cases/gallery_01.json`; menambah kasus tidak menyentuh kode | `PuzzleTableService.build` |
| §15 telemetri | Event `input` per penempatan potongan, plus `input` untuk ping dan `deduction` untuk deduksi; `variant` ikut tercatat per sesi | `TelemetryService.record` di `handlePlacePiece`, `handlePing`, `handleDeduce`; `TelemetryService.summary().variant` |
| §9 Case 0 | `data/cases/case_00.json` — 9 node, 3 rantai, ketiga tipe puzzle, `key_deductions` 2 | `lune run tools/validate_case.luau -- data/cases/case_00.json` → LULUS; `tests/puzzle-types.spec.luau` (tiga tipe end to end); `tests/location-map.spec.luau` (`origins` deduksi) |
| §10 story case + varian | `data/cases/kersana_01.json` — 22 node, 10 deduksi, 2 varian (`v_rani`, `v_bowo`) | validator LULUS; `tests/case-content.spec.luau` suite seed & pernyataan |
| §10 pemilihan varian dari seed | `selectVariant` deterministik; 128 seed uji menjangkau kedua varian | `tests/case-content.spec.luau` suite "seed memilih varian" |
| §4 pernyataan terpisah per varian | Director hanya menerima pernyataan yang berlaku di varian sesi ini | `CaseLoader.projectForRole`; `tests/case-content.spec.luau` suite "pernyataan terpisah per varian" |
| §7 ping wheel final | Frasa per role + universal; label direlay server, bukan disalin client | `src/shared/PingPhrases.luau`; `tests/ping.spec.luau` |
| §7 Report Card tanpa mengetik | Searcher menekan Report → server memperkaya label + lokasi dari data kasus | `handleReport`; `NetClient.report(bound, objectId)` |
| §7 Target Marker di HUD Searcher | Handler menandai target → `SetTarget` → `TargetMarker` + bearing kompas | `handleSetTarget`; `src/shared/LocationMap.luau` |
| §5 gerbang deduksi & anti brute-force | Ambang N per tipe kasus; pinpoint deduksi diturunkan dari rantai, bukan ditulis di data | `CaseGraph.primaryOrigin`; `handleDeduce` |

Ketiga tipe puzzle punya grid sendiri (`torn_doc` 4×4, `timeline` 4×2, `cipher`
3×3) dan ketiganya kini dirakit **end to end** sampai `solved` di
`tests/puzzle-types.spec.luau` — lewat `PuzzleTableService.place`, bukan lewat
`PuzzleTable.place` langsung, sehingga jalur otoritatif server yang diuji.

Dua hal yang perlu dicatat dari suite itu:

- **`PuzzleTableService.build` tidak menyaring berdasarkan `needs`/kunci.** Ia
  membuat meja untuk **setiap** node `evidence` yang aktif di varian, sejak
  sesi dimulai — `needs` belum diperiksa di situ. Jadi urutan pembukaan bukti
  oleh kunci masih bergantung pada alur kunci, bukan pada keberadaan meja.
- Kontrol "drop di luar toleransi ditolak" memakai titik **sudut sel**
  (ternormalisasi `1/cols, 1/rows`), bukan sudut meja `(0,0)`.
  `clampNormalized` sengaja menjepit jari yang keluar meja ke pusat sel tepi,
  jadi `(0,0)` mendarat tepat di pusat sel `(0,0)` dan memang diterima. Menguji
  `(0,0)` akan mengunci kebalikan dari kontrak modul.

Grid masih memakai `Table.SHEET = "rbxassetid://0"`: yang terbukti adalah
geometri dan aturan snap, bukan tampilan gambar. Pemetaan region sheet ke
potongan asli menunggu art pertama, seperti sebelumnya.

**`case_00` jadi kasus default sesi.** `startSession()` memilih `caseIds[1]`
dari daftar yang diurutkan, dan `case_00` mengurut paling awal secara
alfabetis. Konsekuensinya untuk playtest: begitu berkasnya ada, sesi tanpa
pemilihan kasus akan selalu membuka Case 0 — bukan `gallery_01`. Untuk menguji
`kersana_01`, kasusnya harus dipilih eksplisit.

**Ping dicatat sebagai telemetri `input`.** PRD §7 menyebut komunikasi "cukup
sentuh, tidak harus ketik", jadi ping adalah input bermakna untuk pengukuran
idle time PRD §12 (`< 25%`). Tanpa itu, pemain yang sedang berkomunikasi lewat
ping wheel akan terhitung menganggur.

## 2. Apa yang belum

### 2.1 Bukan scope minggu 0-1 (sesuai PRD §17)

- **Lobby, preferensi role, NPC, AFK/rejoin** — minggu 5. `Matchmaking`,
  `RoleAssignment`, dan `NPCController` sudah ada dan diuji, tetapi
  pemanggilnya belum: timer 45/90 detik belum dijadwalkan, ready check belum
  punya UI, `preferences` masih `Roles.ALL` (tanpa preferensi). Daftar lengkap
  ada sebagai komentar di `src/server/init.server.luau` bagian 7.
- **NPC Director terpandu** — P1 (PRD §16).
- **UI clue board Director** — minggu 3 (EXTA-56). Mesinnya sudah ada
  (`DeductionEngine.combine`, `handleDeduce`, node `ded_*` di data kasus), yang
  belum adalah layar untuk menyusun Clue Card dan menandai Kontradiksi.
  Mekanisme penandaan kontradiksi di server dan proyeksinya sudah selesai
  (EXTA-57); HUD belum memanggil `NetClient.markContradiction`.

Catatan: baris *"Case 0 dan story case — minggu 6"* sudah tidak berlaku; dua
berkas kasusnya ada dan lolos validator (§1). Yang **belum** ada dari minggu 6
adalah runtime SOP-05 (mentor NPC, tawaran Case 0, flag selesai, rookie mode) —
lihat §2.4.

### 2.2 Jalan, tapi belum lengkap

- **Aset gambar.** `Table.SHEET` masih `"rbxassetid://0"`. Selama placeholder,
  tiap potongan diberi latar warna dan nomor region supaya drag-and-snap bisa
  diverifikasi tanpa art. Mengunggah texture butuh akun Creator — di luar
  lingkungan kerja ini. Ganti satu konstanta itu saat sheet pertama selesai;
  tidak ada bagian lain yang perlu berubah.
- **Kamera untuk Searcher.** `Table.mount` menyetel `CameraType = Scriptable`.
  Karena server hanya mengirim `puzzle_state` ke Handler dan Director, Searcher
  tidak pernah memicu pemasangan meja — jadi kameranya tidak tersentuh. Kalau
  kelak Searcher ikut membangun meja, ini akan merusak kamera first/third
  person (PRD §3) dan harus dipisah lebih dulu.

### 2.3 `ASUMSI` yang belum diverifikasi

| `ASUMSI` | Nilai | Yang akan mengonfirmasi |
|---|---|---|
| Ukuran meja | `Config.TABLE_WIDTH`/`TABLE_HEIGHT` = 16×16 stud | Playtest minggu 7 |
| Radius genggam | `Table.GRAB_RADIUS` = 1,2 sel | Playtest minggu 7; uji jari nyata di ponsel |
| Laju interpolasi | `PuzzleTable.INTERPOLATION_RATE` = 12 pangsa/detik | Pengukuran jank di perangkat |
| Perangkat mobile kelas bawah | **BELUM TERUKUR** | Uji di Android kelas bawah (tidak ada perangkat di lingkungan ini) |
| Latensi jaringan nyata | **BELUM DIUJI** | Uji 100 ms dan 300 ms + packet loss, sesuai metode S0.2 |
| Kompresi texture Roblox | **BELUM TERUKUR** | Unggah sheet nyata, lihat hasil di perangkat |
| Koordinat `LocationMap` | **PLACEHOLDER** — `ENTRIES` dan `ANCHORS` memakai koordinat bidang ternormalisasi karangan (`gallery` `{0.5,0.05}`, `agency_hq` `{0.5,0.08}`, `kersana_workshop` `{0.1,0.5}`) | Ganti dengan denah lokasi nyata saat level blockout ada; `tests/location-map.spec.luau` sengaja menguji **semantik** bearing, bukan sudut absolut, supaya angka placeholder bisa diganti tanpa mengubah spec |
| Foto objek untuk Report Card | `report_card.image` = `"rbxassetid://0"` — belum ada aset foto objek | Unggah foto objek per node, lalu isi field `image` dari data kasus; sampai itu, `label` yang membuat kartu terbaca |
| MCP Studio | **JALUR MATI** — `tools/list` kosong, butuh auth Assistant interaktif di UI Studio | Aksi manusia |

### 2.4 SOP-05 (onboarding Case 0): data ada, runtime belum

`docs/sop/sop-05-onboarding-case-0.md` menugaskan langkah A6 kepada Nathan
dengan DoD *"NPC mentor aktif selama Case 0 dan tidak mengungkap solusi"*.
Status jujurnya: **kasus Case 0-nya ada dan lolos validator, runtime
onboarding-nya belum.** Tidak ada satu pun baris di `src/` yang membaca mentor
lines, menawarkan Case 0, menyimpan flag selesai, atau mengaktifkan rookie mode.
Jadi SOP-05 **tidak** boleh diklaim terpenuhi.

| Langkah SOP-05 | Status |
|---|---|
| A6 NPC mentor aktif selama Case 0 | **BELUM** — teksnya disimpan di bawah, belum ada pemanggil |
| B8 tawarkan Case 0 | **BELUM** — `startSession()` memilih `caseIds[1]`, tidak ada tawaran |
| B11 flag selesai sekali per akun | **BELUM** — tidak ada penyimpanan per pemain |
| B12 tombol skip | **BELUM** |
| B13 rookie mode 3 sesi | **BELUM** |

Teks mentor (enam pemicu) yang ditulis untuk A6, disimpan di sini karena tidak
ada berkas lain yang memuatnya. Formatnya `{pemicu, teks}`; `case_start`,
`first_report`, `first_key`, `gate_open`, `wrong_accusation`, `win`:

- `case_start` — "Selamat datang di ruang arsip. Aku Bu Lastri. Pena perakku hilang, dan kalian yang mencari. Aku akan memandu sampai tuduhan pertama."
- `first_report` — "Bagus. Laporanmu langsung sampai ke clue board Director. Tidak perlu mengetik apa pun."
- `first_key` — "Kunci ini membuka satu potongan bukti di meja Handler. Kunci selalu datang dari benda di lokasi."
- `gate_open` — "Dua Deduksi Kunci selesai. Form tuduhan terbuka: pelaku, motif, dan cara. Motif bisa kalian simpulkan dari Clue Card; deduksi motif hanya menambah bonus rank. Minta satu role lain mengonfirmasi sebelum menuduh."
- `wrong_accusation` — "Belum tepat. Aku hanya bisa bilang berapa field yang benar, bukan yang mana. Baca ulang Clue Card kalian."
- `win` — "Selesai. Pena itu memang tertukar, bukan dicuri. Sekarang kalian sudah tahu cara kerja satu rantai."

Lima langkah SOP-05 itu di luar scope MVP P0 PRD §16 (`Case 0 (tutorial)` ada di
daftar, tetapi mentor NPC tidak disebut sebagai komponen terpisah) — jadi ini
celah antara SOP dan PRD yang perlu diputuskan pemilik, bukan sesuatu yang bisa
diselesaikan sepihak di sini.

## 3. Risiko teknis yang terbukti dari spike

Tiga hal di bawah bukan dugaan; masing-masing punya angka.

### 3.1 Bleeding tepi potongan tidak dihapus gutter 1 px

`docs/spike-minggu-0-hasil.md` §3.1–3.2. Pada sheet 1024×1024 grid 4×4,
penurunan texture ke 512/384/256 menyisakan pita tercemar 1–3 px di **semua 16
potongan**, dengan puncak 24–36 tingkat luma untuk gaya ber-gutter (A/B) dan
42–45 tanpa gutter (C). Ambang terlihat 8,0 — jadi pita itu terlihat.

Gutter 1 px yang dipakai metode spike memotong puncak 22–46%, belum
menghilangkannya. Sapuan lebar menunjukkan gutter baru menutup penuh kalau
**lebih lebar dari jangkauan kernel resampler**: 2 px untuk penurunan 2×, 4 px
untuk 4×, 6 px untuk 4× yang lalu diperbesar 2× saat ditampilkan.

Konsekuensi untuk produksi: `docs/art/puzzle-style.md` menetapkan gutter 1 px
lewat pilihan "satu sheet per bukti, grid maks 6×6". Angka di atas menunjukkan
1 px kurang, dan itu **belum dikonfirmasi di sampler Roblox** — model ini
memakai peniru bilinear PIL. Tindakan: uji gutter 4–6 px di perangkat saat art
pertama ada, sebelum mengunci pipeline sheet.

Catatan: dengan `ResampleMode = Pixelated` (nearest), bleeding **nol di semua
konfigurasi** pada model ini. Itu sudah dipakai di `buildLabel`
(`src/client/Table/init.luau`). Tetapi model itu tidak menangkap aliasing —
biaya sebenarnya belum terukur, jadi ini mitigasi yang belum diverifikasi,
bukan solusi.

### 3.2 Drag per frame menabrak ambang; jalur "satu pesan saat dilepas" lulus

`tools/spike-s02-protokol.luau`, ambang `docs/spike-minggu-0.md` S0.2
("< 20 pesan/detik saat drag aktif"):

| Jalur | Pesan/detik | Putusan |
|---|---|---|
| A: satu pesan per frame @60 fps | 60,00 | GAGAL |
| A: @30 fps (perangkat kelas bawah) | 30,00 | GAGAL |
| B: satu pesan per potongan | 1,00 | LULUS |
| B: 16 potongan dalam 1 detik | 16,00 | LULUS |

Yang dipakai game adalah jalur B: `release` di `src/client/Table/init.luau`
mengirim tepat satu pesan per pelepasan jari, dan **tidak** mengirim apa pun
saat drop pasti ditolak (dideteksi lokal lewat `resolveDrop`). Karena itu
jumlah pesan tidak tumbuh mengikuti framerate.

### 3.3 Prediksi client dan keputusan server sepakat — 0 koreksi dari 48 drop

Diukur pada tiga pola drop × 16 potongan, membandingkan jalur client
(`clampNormalized` → `normalizedToPoint` → `resolveDrop`) dengan jalur server
(`applyDrop`):

| Pola drop | Koreksi | Ambang | Putusan |
|---|---|---|---|
| Tepat di pusat sel tujuan | 0/16 | ≤ 1 | LULUS |
| Meleset 0,4 sel (masih dalam `SNAP_TOLERANCE` 0,5) | 0/16 | ≤ 1 | LULUS |
| Ke sel lain yang masih sah | 0/16 | ≤ 1 | LULUS |

Kontrol non-vacuous: drop ke sel lain tetap **diterima** (potongan menempel,
sesuai aturan snap) tetapi **tidak** dihitung benar — jadi `accepted` bukan
`correct`, dan angka nol di atas bukan efek "server menerima apa saja". Drop
NaN ditolak server.

Kedua jalur memakai `clampNormalized` yang sama, dan itu yang membuat
kesepakatannya bukan kebetulan: penjepitan punya satu definisi. Diuji lintas-sisi
di `tests/puzzle-table.spec.luau` suite `clampNormalized` (5 probe, 0
ketidakcocokan).

Yang **belum** terukur: apakah drag terasa halus di ponsel. Itu butuh perangkat.
Yang terbukti di sini adalah properti protokolnya — jumlah pesan dan
kesepakatan prediksi — bukan pengalaman jari.

## 4. Utang warisan yang tidak diperparah

`src/shared/case/CaseLoader.luau` (murni, `selectVariant`) dan
`src/server/CaseLoader.luau` (menyentuh `Instance`, `pickVariant`) masih
koeksis — dua loader dengan kontrak berbeda (EXTA-54). Pekerjaan ini tidak
menambah salinan ketiga: sisi server yang disentuh, dan `pickVariant` hanya
dipecah agar varian bisa dipilih dari `roll` yang bisa diuji.

## 5. Cacat yang ketahuan dan diperbaiki di minggu 6

Tiga cacat nyata, semuanya ditemukan oleh spec baru — bukan oleh review manual.

### 5.1 Ejaan role di `projectForRole` — pernyataan per varian tidak pernah terkirim

`CaseLoader.ROLE_PROJECTION` berkunci huruf kecil (`searcher`/`handler`/`director`,
mengikuti `CaseGraph.ROLES` dan `$defs.briefing` di skema). Tetapi
`src/server/init.server.luau` memanggilnya dengan nama role tampilan
(`Roles.DIRECTOR` = `"Director"`). Lookup tanpa normalisasi itu meleset dan
mengembalikan `nil` — dan pemanggilnya membungkus hasilnya dalam guard
`type(...) == "table"`, jadi `nil`-nya ditelan tanpa suara.

Akibatnya bukan sekadar satu spec merah: **pernyataan saksi per varian tidak
pernah sampai ke Director**, padahal itu salah satu acceptance criteria minggu
ini ("pernyataan terpisah per varian"). Kasus yang punya pernyataan berbeda di
tiap cabang solusi akan tampak benar dari data, tetapi Director selalu melihat
daftar kosong.

Perbaikannya satu tempat: `canonicalRole` menormalkan ejaan di dalam modul, dan
dipakai untuk kedua lookup — `ROLE_PROJECTION` **dan** `case.briefing`, karena
keduanya berbeda kunci (`briefing` huruf kecil, `briefings` nama tampilan).
`payload.role` tetap membawa ejaan pemanggil; hanya lookup yang dikanonikkan.
Regresinya dikunci di `tests/case-content.spec.luau` suite "ejaan role di
proyeksi".

### 5.2 `key_deductions` bocor di proyeksi role

Proyeksi yang sama juga mengirim `key_deductions`, yang ada di
`Net.SECRET_FIELDS` — *deduksi mana yang kunci* adalah informasi solusi. Tidak
satu pun view `briefing` di `Net.CLIENT_VIEWS` memuatnya, jadi
`Net.findSecrets` menandai setiap proyeksi role. Ambang gerbang dikirim
terpisah sebagai `key_deductions_required` pada view `session_state`, hanya ke
Director (yang memang butuh **jumlah**, bukan **yang mana**). Field itu
dihapus dari payload proyeksi.

### 5.3 Gerbang validator tidak mencakup berkas kasus baru

`tests/case-schema.spec.luau` memvalidasi `gallery_01.json` plus tiga fixture
rusak, tetapi **tidak** menyentuh `case_00.json` maupun `kersana_01.json`. Jadi
sebelum ini kedua kasus minggu 6 hanya dijaga oleh perintah CLI manual: rusak
satu berkas, suite tetap hijau. Dua baris ditambahkan ke tabel `expectations`
supaya keduanya ikut digerbang (869 assertion saat itu; 967 setelah EXTA-57).

Celah yang sama masih ada di tempat lain: `tools/validate_case.luau` menerima
daftar berkas dari argumen, jadi kasus baru **tidak** otomatis ikut kecuali
namanya ditambahkan. Tidak ada penemuan berkas otomatis atas `data/cases/`.

## 6. Langkah berikutnya, terurut

1. **Putuskan runtime SOP-05** (§2.4). Kasus Case 0-nya sudah ada dan lolos
   validator; yang hilang adalah mentor NPC, tawaran, flag selesai, dan rookie
   mode. Ini butuh keputusan pemilik karena SOP-05 menugaskannya tetapi PRD §16
   tidak menyebut mentor NPC sebagai komponen MVP.
2. **Uji gutter 4–6 px di perangkat** saat art pertama ada (§3.1). Ini yang
   paling murah dan paling berisiko kalau ditunda — kalau 1 px memang kurang,
   seluruh pipeline sheet berubah.
3. **Uji S0.2 dengan latensi buatan** 100 ms dan 300 ms + packet loss, di
   perangkat. Angka pesan sudah lulus; yang belum diuji adalah perilaku saat
   pesan datang terlambat.
4. **Ganti koordinat `LocationMap`** dengan denah lokasi nyata (§2.3). Spec-nya
   sudah menguji semantik bearing, jadi penggantian angka tidak menyentuh uji.
5. **Minggu 7**: playtest 3 pemain nyata di mobile, tuning idle time terhadap
   ambang PRD §12 (`< 25%`). Ini juga yang memvalidasi `key_deductions` N=4
   untuk kasus standar (PRD §19).
6. **Minggu 5**: isi pemanggil lobby/ready check/NPC yang sudah bernama di
   `src/server/init.server.luau` bagian 7.
