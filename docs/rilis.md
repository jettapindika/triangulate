# Ceklis rilis Triangulate

Pemilik: **Nathan — CTO/CIO** · Issue: EXTA-61 · Induk: EXTA-31 · Tanggal: 2026-10-04
Rujukan PRD: `docs/prd-v0.2.md` §14, §16, §17, §18, §19

Dokumen ini menjawab satu pertanyaan: **boleh tidak rilis sekarang?** Jawabannya
**tidak**, dan alasannya bukan opini — tiap butir di bawah punya status dan bukti.

Konvensi: klaim hasil eksekusi ditulis apa adanya (perintah + keluaran); klaim
yang belum diukur ditandai `ASSUMPTION` beserta apa yang memverifikasinya.
Tidak ada butir yang dibiarkan kosong.

---

## 0. Ringkasan keputusan

| Pertanyaan | Jawaban | Dasar |
|---|---|---|
| Build kandidat lulus gerbang lokal? | **Ya** — 4 dari 4 | Bagian 1 |
| Ceklis MVP P0 PRD §16 lengkap? | **Tidak** — 2 butir `tidak`, 6 butir `sebagian`, 0 butir `jalan` penuh dari 8 | Bagian 2 |
| Gate minggu 8 PRD §17 ("metrik minggu 7 terpenuhi")? | **Tidak terpenuhi** | Bagian 3 |
| Boleh rilis sekarang? | **Tidak** | Bagian 2 + 3 |
| Ada aksi yang hanya bisa dilakukan manusia? | **Ya** — 8 butir | Bagian 7 |

Ringkasnya: **mesinnya lulus uji, tapi produknya belum lengkap.** Yang ada di
`main` (commit `80b35e9`) adalah minggu 0–1 PRD §17: meja puzzle +
drag-and-snap + pemisahan info per role. Minggu 2–7 belum menghasilkan apa pun
di `main`; pekerjaannya baru mulai berjalan setelah environment diperbaiki
2026-10-04 14:05Z, dan penyebabnya dicatat di bagian 8 — bukan karena
pekerjaannya dianggap tidak perlu.

---

## 1. Gerbang lokal pada build kandidat

Commit: `80b35e9a7f2a6a3765dbe55236ef22c4200b1854`
("Merge pull request #16 from jettapindika/exta53-meja-puzzle-drag-snap").

Toolchain: lune 0.10.5, stylua 2.5.2, selene 0.32.0, Rojo 7.7.1 (sama dengan
pin `rokit.toml` dan `env.*` di `.github/workflows/ci.yml`).

| # | Perintah | Hasil | Exit |
|---|---|---|---|
| 1 | `lune run tests/run.luau` | **566 assertion, 0 gagal** — 15 berkas spec | 0 |
| 2 | `stylua --config-path stylua.toml --check .` | bersih, tanpa keluaran | 0 |
| 3 | `selene --config selene.toml .` | **0 errors / 0 warnings / 0 parse errors** | 0 |
| 4 | `rojo build -o build-candidate.rbxlx` | `Built project to build-candidate.rbxlx` — 200.771 byte | 0 |
| 5 | `lune run tools/validate_case.luau -- data/cases/gallery_01.json` | `HASIL: 1 file lulus` — 0 errors, 0 warnings | 0 |

Empat gerbang pertama adalah empat gerbang yang diminta issue ini; #5 adalah
pemeriksaan tambahan atas data kasus. Di luar itu, `luau-analyze --mode=strict`
dijalankan atas 13 modul murni (exit 0, tanpa diagnostik) — bukan gerbang
rilis, tetapi bagian dari verifikasi yang sama.

Keluaran verbatim kelima perintah ada di lampiran komentar hasil EXTA-61.

**Yang gerbang ini TIDAK buktikan.** `rojo build` membuktikan struktur dan
parsing, bukan perilaku. Tidak ada runtime Roblox di lingkungan ini: tidak ada
Studio yang bisa diotomasi, tidak ada perangkat mobile, tidak ada akun Creator.
Tidak ada satu baris pun `init.server.luau` yang pernah dieksekusi. Yang diuji
adalah modul murni — geometri meja, resep deduksi, tuduhan, rank, matchmaking,
penetapan role, proyeksi `Net`, telemetri. Itu sebabnya modul-modul itu
dipisahkan dari glue.

Batas ini bukan kelemahan dokumen ini; ia yang membuat angka "566 lulus" tidak
boleh dibaca sebagai "game-nya jalan".

---

## 2. Ceklis MVP P0 — PRD §16 "MVP (P0)"

Delapan butir, satu per satu. Status: **jalan** / **sebagian** / **tidak**.

### 2.1 Meja puzzle top-down dengan drag-and-snap + 3 tipe puzzle bukti — `SEBAGIAN`

| Aspek | Status | Bukti |
|---|---|---|
| Meja top-down, kamera Scriptable | jalan | `src/client/Table/init.luau` (`Table.mount`, `Table.PLANE_Y`, `Table.CAMERA_HEIGHT`); geometri murni diuji di `tests/puzzle-table.spec.luau` |
| Drag-and-snap | jalan | Protokol "satu pesan saat dilepas" lulus ambang S0.2 (< 20 pesan/detik): jalur A 60 pesan/detik GAGAL, jalur B 1 pesan/detik LULUS — `docs/mvp-notes.md` §3.2 |
| Prediksi client = keputusan server | jalan | 0 koreksi dari 48 drop (3 pola × 16 potongan), ambang ≤ 1 — `docs/mvp-notes.md` §3.3; `tests/puzzle-table.spec.luau` |
| 3 tipe puzzle terdaftar | jalan | `src/shared/PuzzleTable.luau:492-496` — `torn_doc` 4×4, `timeline` 4×2, `cipher` 3×3 |
| `torn_doc` end to end | jalan | `tests/gate-minggu-0.spec.luau` suite "rantai torn_doc: obj_schedule → ev_schedule → clue_guard_off" |
| `timeline` dan `cipher` end to end | **tidak** | Grid ada, tapi belum ada uji rantai untuk keduanya. Komentar di `src/shared/PuzzleTable.luau:489-490` menyatakan hal yang sama |
| Gambar puzzle nyata | **tidak** | `src/client/Table/init.luau:51` — `Table.SHEET = "rbxassetid://0"`. Potongan digambar sebagai kotak berwarna + nomor region |

**Alasan.** Satu tipe puzzle terverifikasi end to end; dua sisanya hanya punya
geometri. Sheet gambar butuh akun Creator untuk mengunggah texture — di luar
lingkungan ini.

### 2.2 1 lokasi dengan objek yang bisa diperiksa + mini-aksi — `TIDAK`

`grep -rni "miniaction|mini_action|lockpick|senter|flashlight|uv_" src/ data/`
→ **nol hasil**. Tidak ada implementasi lokasi, tidak ada objek yang bisa
diperiksa di dunia, tidak ada mini-aksi (senter UV, laci hold, lockpick).

Data kasus (`data/cases/gallery_01.json`) sudah punya 33 node termasuk node
`object` dengan `gives_key`, dan grafnya lolos validator. Tapi sisi Searcher —
tempat objek itu benar-benar ditemukan — belum ada.

**Alasan.** PRD §17 menempatkan ini di minggu 2 ("Loader kasus dari data,
lokasi, objek + kunci"). Minggu 2 belum menghasilkan apa pun di `main`; status
dan penyebabnya di bagian 8.

### 2.3 Director: clue board, kombinasi Clue Card, kontradiksi, map + pinpoint, form tuduhan (3 percobaan) — `TIDAK`

| Bagian | Status | Bukti |
|---|---|---|
| Logika kombinasi Clue Card | jalan | `src/server/DeductionEngine.luau`; `tests/deduction.spec.luau`; handler `handleDeduce` di `src/server/init.server.luau:392` |
| Logika tuduhan + batas 3 percobaan | jalan | `src/server/AccusationService.luau`; `tests/accusation.spec.luau`; handler `handleAccuse` `:428`, `handleConfirm` `:470` |
| Clue board (UI) | **tidak** | `grep -rni "clueboard|clue_board|ClueBoard" src/` → nol hasil |
| Kontradiksi (UI penanda) | **tidak** | Tidak ada elemen UI; hanya data `lie`/`contradicted_by` di data kasus |
| Map + pinpoint (UI) | **tidak** | Remote `Pinpoint` dideklarasikan (`src/shared/Net.luau:39-56`) tetapi tidak ada handler client |
| Form tuduhan (UI) | **tidak** | Feedback tuduhan tampil sebagai satu baris teks di HUD (`src/client/Hud/init.luau`, label `Accusation`), bukan form Pelaku/Motif/Cara |

**Alasan.** PRD §17 minggu 3 ("Director UI: clue board, kombinasi, pinpoint")
dan minggu 4 ("tuduhan + batas percobaan"). Keduanya belum menghasilkan apa pun
di `main`; statusnya di bagian 8.

Konsekuensinya nyata: **Director tidak punya satu pun layar.** Seluruh logika
kemenangan ada dan teruji, tetapi tidak ada cara menyentuhnya dari dalam game.

### 2.4 Pemisahan info per role (server-authoritative) — `SEBAGIAN`

| Aspek | Status | Bukti |
|---|---|---|
| Proyeksi whitelist per view × role | jalan | `src/shared/Net.luau:90` `CLIENT_VIEWS`, `Net.project` `:198` |
| Sweep kebocoran | jalan | `tests/leak-sweep.spec.luau` — **25 pasangan view × role, 0 temuan** |
| Guard boot | jalan | `src/server/init.server.luau` §1, verifikasi `Net.REMOTE_NAMES` |
| Remote server→client yang benar-benar terpakai | **sebagian** | Server menembak 9 remote; client hanya memasang handler untuk 5: `SessionState`, `AccusationResult`, `ConfirmAccusation`, `PuzzleState`, `PiecePlaced` (`src/client/init.client.luau:63,85,102,108,129`) |
| `ClueCard`, `TargetMarker`, `Pinpoint`, `ReportCard`, `DeductionResult` | **tidak** | Dideklarasikan di `Net.REMOTE_NAMES`, **tidak ada handler client**. Data sampai lalu dibuang |

**Alasan.** Pemisahan datanya benar dan terbukti tidak bocor — itu bagian
sulitnya, dan itu selesai. Yang belum ada adalah sisi penerimanya. Efeknya
persis kebalikan dari kebocoran: bukan client tahu terlalu banyak, melainkan
client tidak menampilkan apa yang sudah berhak ia terima. Handler client adalah
pekerjaan UI Director/Handler yang jatuh di minggu 2–4.

### 2.5 Lobby: 2 preferensi role, ready check, NPC Searcher dan Handler, AFK takeover, rejoin — `TIDAK`

| Bagian | Status | Bukti |
|---|---|---|
| Modul logika | jalan | `Matchmaking.luau`, `RoleAssignment.luau`, `NPCController.luau` — diuji di `tests/matchmaking.spec.luau`, `tests/role-assignment.spec.luau`, `tests/npc.spec.luau` |
| Pemanggilnya | **tidak** | `src/server/init.server.luau` §7 (`:643-720`) |

Empat hal yang hilang, semuanya bernama di komentar §7:

- **Preferensi role**: `preferences = Roles.ALL` di dua tempat (`:671`, `:688`) — artinya "tanpa preferensi". Pemain tidak bisa memilih 2 preferensi.
- **Ready check**: `Matchmaking.readyFailures`/`canStart` sudah diuji, tetapi tidak ada UI yang menyetel `ready`. Sesi dimulai saat 3 pemain hadir (`:678`).
- **Timer 45/90 detik**: `Matchmaking.secondsLeft` sudah ada, tetapi penjadwalnya hanya loop `task.wait(1)` (`:698-711`), bukan timer yang menggerakkan fase.
- **AFK takeover dan rejoin**: tidak ada deteksi input, tidak ada penahanan slot 3 menit.

**Alasan.** PRD §17 minggu 5 ("Lobby, preferensi role, NPC, AFK/rejoin").
Tidak pernah dieksekusi. Ini utang teknis #3 di `docs/arsitektur.md` §9.

### 2.6 Ping wheel + Report Card + Target Marker (text chat opsional) — `SEBAGIAN`

| Bagian | Status | Bukti |
|---|---|---|
| Ping wheel (UI) | jalan | `src/client/Hud/PingWheel.luau` — `RADIUS = 150`, `BUTTON_SIZE = 92`; dibuka dari tombol `PingButton` 96×96 (`src/client/Hud/init.luau:140-149`) |
| Frasa per role + validasi | jalan | `src/shared/PingPhrases.luau`; `tests/ping.spec.luau` — 6–8 frasa per role, 3 frasa universal, frasa role lain ditolak |
| Ping sampai ke server | **tidak** | **Tidak ada handler `Ping.OnServerEvent`** di `src/server/init.server.luau`. Yang ter-connect hanya 5 (`:633-637`): `SubmitDeduction`, `PlacePiece`, `Accuse`, `ConfirmAccusation`, `Report` |
| Report Card | **tidak** | `handleReport` (`:503`) menembak `ReportCard` ke semua role, tetapi **tidak ada handler client** — data laporan dibuang |
| Target Marker | **tidak** | Remote dideklarasikan, tidak ada pengirim maupun penerima |
| Text chat | tidak dikerjakan | PRD §7 menyebutnya opsional |

**Alasan.** Roda ping-nya sendiri selesai dan sudah punya aturan frasa yang
diuji, tetapi **saklarnya belum tersambung**: pemain bisa membuka roda, memilih
frasa, dan tidak terjadi apa-apa. Ini temuan yang harus diperbaiki sebelum
playtest apa pun — komunikasi adalah gameplay utamanya (PRD §2 pilar 2), dan
satu-satunya kanal komunikasi yang dirancang belum mengirim apa pun.

### 2.7 Case 0 (tutorial) + 1 story case dengan 2 varian — `SEBAGIAN`

| Bagian | Status | Bukti |
|---|---|---|
| Story case dengan 2 varian | jalan | `data/cases/gallery_01.json` — 33 node, varian `v_curator` (curator/debt) dan `v_guard` (guard/revenge), `key_deductions: 4`, 4 pernyataan, briefing untuk 3 role. Lolos `tools/validate_case.luau` |
| Tiga tipe puzzle dipakai | jalan | Node bukti memakai `torn_doc`, `timeline`, `cipher` |
| Case 0 (tutorial) | **tidak** | Tidak ada kasus tutorial. `Config.KEY_DEDUCTIONS.tutorial = 2` hanya angkanya |
| Konten Case 0 dan copy | **belum masuk main** | Draf ada di **PR #6** (`agent/nadia-penulis-konten/278e0cc92537`), masih terbuka, belum di-merge |

**Alasan.** PRD §17 minggu 6 ("Case 0, story case #1 + varian, ping wheel
final"). Tidak pernah dieksekusi. Draf kontennya ada, tetapi draf di PR yang
belum di-merge bukan konten yang dirilis.

### 2.8 Telemetri dasar — `SEBAGIAN`

| Aspek | Status | Bukti |
|---|---|---|
| Modul + skema | jalan | `src/server/TelemetryService.luau`; `docs/metrics/skema-event-telemetri.md`; `docs/metrics/telemetry-events.schema.json`; `tests/telemetry.spec.luau` |
| Perekaman event | jalan | `src/server/init.server.luau:446` (tuduhan), `:518` (clue), `:578` (input) |
| Pengiriman/ekspor event | **tidak** | Tidak ada jalur keluar. Utang teknis #5 di `docs/arsitektur.md` §9: "Telemetri dihitung tapi tidak dikirim" |

**Alasan.** Event-nya dihitung di memori server dan tidak pernah meninggalkan
sesi. PRD §12 tidak bisa diukur dari build ini — dan itu tepat sasaran untuk
gate minggu 7, yang juga tidak pernah dijalankan.

### 2.9 Rekap status

| # | Butir P0 (PRD §16) | Status |
|---|---|---|
| 1 | Meja puzzle top-down + drag-and-snap + 3 tipe puzzle | `SEBAGIAN` |
| 2 | 1 lokasi + objek + mini-aksi | `TIDAK` |
| 3 | Director: clue board, kombinasi, kontradiksi, map + pinpoint, form tuduhan | `TIDAK` |
| 4 | Pemisahan info per role (server-authoritative) | `SEBAGIAN` |
| 5 | Lobby: preferensi role, ready check, NPC, AFK takeover, rejoin | `TIDAK` |
| 6 | Ping wheel + Report Card + Target Marker | `SEBAGIAN` |
| 7 | Case 0 + 1 story case dengan 2 varian | `SEBAGIAN` |
| 8 | Telemetri dasar | `SEBAGIAN` |

**2 `tidak`, 6 `sebagian`, 0 `jalan` penuh.** Tidak ada butir yang kosong.

---

## 3. Polish dan gate minggu 7

PRD §17 minggu 7: "Playtest 3 pemain nyata (mobile), tuning idle time" dengan
gate **"Idle < 25%, selesai > 55%"**. Minggu 8: gate **"metrik minggu 7
terpenuhi"**.

| Yang dituntut | Status | Bukti |
|---|---|---|
| Playtest 3 pemain nyata di mobile | **tidak dijalankan** | Tidak ada build yang dipublikasikan, tidak ada penguji, tidak ada data |
| Idle time per role < 25% | **tidak terukur** | Butuh sesi nyata; `Config.MAX_IDLE_FRACTION = 0.25` masih konstanta yang belum pernah dibandingkan dengan pengukuran |
| Penyelesaian kasus > 55% | **tidak terukur** | Butuh sesi nyata |
| Bug hasil playtest minggu 7 | **tidak ada daftarnya** | Tidak ada playtest → tidak ada bug |
| Validasi N Deduksi Kunci dari playtest | **tidak** | DR-03 masih terbuka (`docs/decision-log.md`); §5 sendiri tidak konsisten: 65% dari 5 = 4, tetapi §5 menulis daily "3 dari 5" |
| Durasi timer cleanup | **tidak** | DR-02 masih terbuka; §6 belum bisa diimplementasikan tanpa angka |

**Konsekuensi yang harus dinyatakan terang:** gate minggu 8 **tidak terpenuhi**,
dan yang lebih mendasar, **tidak ada satu pun data playtest** di repo ini. Setiap
angka tuning yang ada sekarang adalah `ASSUMPTION` yang menunggu playtest:

| Konstanta | Lokasi | Status |
|---|---|---|
| `Config.TABLE_WIDTH/HEIGHT = 16×16` | `src/shared/Config.luau` | `ASSUMPTION` — "playtest minggu 7 yang menentukan angkanya" |
| `Table.GRAB_RADIUS = 1.2` | `src/client/Table/init.luau:74` | `ASSUMPTION` — menunggu playtest |
| `PuzzleTable.INTERPOLATION_RATE = 12` | `src/shared/PuzzleTable.luau:73` | `ASSUMPTION` — "titik tengah", belum diukur di perangkat |
| Ambang target sentuh 48/56 | `docs/art/ui-spec.md` §2 | `ASSUMPTION` — dari panduan aksesibilitas industri (44 px min, 48 optimal), bukan angka resmi Roblox |

### 3.1 Kontrol touch-first, target sentuh, UI responsif

**Yang sudah terverifikasi (mockup, bukan runtime):** `python3
docs/art/mockups/verify_mockup.py` mengukur 29 elemen lewat
`getBoundingClientRect()` — **tidak ada yang di bawah 44 point, terkecil 48**;
**0 overflow horizontal** pada 320/360/390/430/768/1400 point; 65 pasangan
kontras teks dan 18 pasangan kontras komponen lulus. Rinciannya di
`docs/art/ui-spec.md` §7.

**Yang belum terverifikasi, dan butuh perangkat nyata** — dinyatakan sendiri
oleh `docs/art/ui-spec.md` §7:

- sentuhan sebenarnya pada layar ponsel;
- perilaku safe area pada perangkat berponi;
- performa render pada perangkat kelas bawah;
- pembacaan layar oleh pembaca layar.

**Celah antara spesifikasi dan kode.** Aturan responsif di `docs/art/ui-spec.md`
§3 (breakpoint 320/390/430, safe area dari `GuiService`) **belum diterapkan di
`src/client`**:

| Temuan | Lokasi | Akibat |
|---|---|---|
| Tidak ada `UISizeConstraint` mana pun | `src/client/Hud/init.luau`, `src/client/Hud/PingWheel.luau` | Pengaman `MinSize = 48` dari ui-spec §2 tidak terpasang |
| Tidak ada penanganan `ViewportSize`/breakpoint | seluruh `src/client` | Layout sama di 320 dan 1400 point; aturan "jumlah elemen yang tampil berkurang, bukan ukurannya" belum ada |
| `IgnoreGuiInset = true` | `src/client/Hud/init.luau:122` | HUD boleh masuk area top bar Roblox; ui-spec §1 justru meminta safe area dari `GuiService` |
| Posisi offset tetap | `src/client/Hud/init.luau` — status `UDim2.fromOffset(16,16)` 280×96, RoleCard 440×300 | Panel bisa melebihi lebar 320 point |
| Ukuran potongan punya lantai 8 px | `src/client/Table/init.luau:300` — `math.max(8, …)` | Pada viewport kecil, potongan bisa jauh di bawah minimum 48 point |
| `ScreenInsets` tidak disetel | `src/client/Table/init.luau`, `src/client/Hud/init.luau` | Notch dan home indicator bisa menutup kontrol |

**Yang benar dan layak dicatat:** `PingWheel.BUTTON_SIZE = 92` dan `PingButton`
96×96 sudah jauh di atas minimum 48 — kontrol komunikasi utama memang target
sentuh besar.

**Kesimpulan polish:** mockup-nya lulus, kodenya belum menerapkan aturannya.
Polish bukan pekerjaan satu-dua bug; ia pekerjaan menerapkan §3 ui-spec di
`src/client`. Dan tanpa perangkat, tidak ada satu pun dari ini yang bisa
dinyatakan selesai.

### 3.2 Pemisahan info per role diverifikasi ulang pada build kandidat

**Ya, dijalankan.** `tests/leak-sweep.spec.luau` termasuk dalam `tests/run.luau`
yang lulus pada commit `80b35e9`: **25 pasangan view × role, 0 temuan**, plus
kontrol detektor yang membuktikan uji ini tidak vacuous (data mentah dan
`session` harus menghasilkan temuan, dan payload yang sengaja dirusak harus
tertangkap). Sumber: keluaran gerbang #1 di bagian 1.

---

## 4. Kesiapan rilis

### 4.1 Nama dan arah visual (PRD §19)

**Keputusan pemilik:** nama **Triangulate**, arah visual **detective noir**.

Sumber: jawaban owner di thread EXTA-31 — "namanya **Triangulate** dan arah
visualnya kaya detective gitu" (komentar `01a1066a-1069-708f-aa64-f1e4ba6b3df3`),
dikunci Chief of Staff di `01a10673-bbc6-71e6-85d4-47e3970cd3e0`: nama
**Triangulate** tanpa subtitle, arah visual **Detective noir**.

**Temuan konsistensi.** Nama itu dipakai setengah jalan. Placeholder masih ada di:

| Berkas | Baris | Isi | Status |
|---|---|---|---|
| `docs/prd-v0.2.md` | 1 | `# PRD: Co-op Puzzle Mystery (Working Title) — v0.2` | **masih ada** |
| `docs/narasi/narasi-triangulate.md` | 204, 229 | rujukan ke judul placeholder | **masih ada** |
| `README.md` | 3 | `Co-op Puzzle Mystery (working title) — game co-op asimetris 3 pemain di Roblox.` | **diperbaiki di PR ini** |

`docs/narasi/narasi-triangulate.md` F2 sudah melaporkan temuan yang sama.
`docs/decision-log.md` masih menaruh DR-01 (nama + arah visual) sebagai
pertanyaan terbuka — entri itu **stale** terhadap keputusan owner di atas.

`README.md` diperbaiki di PR ini (satu baris, milik repo ini) dan sekarang
menyebut **Triangulate** + **detective noir**. Judul `docs/prd-v0.2.md` dan
`docs/narasi/narasi-triangulate.md` **tidak** diubah di sini: keduanya dokumen
milik workstream lain, dan mengganti judul PRD bisa memutus rujukan issue lain.
Yang benar adalah workstream pemiliknya yang merevisi — dicatat sebagai aksi
(bagian 7), bukan diam-diam dikerjakan.

**Nama repo dan project Rojo sudah konsisten:** `default.project.json` →
`"name": "Triangulate"`, repo `jettapindika/triangulate`.

### 4.2 Deskripsi store page (dari EXTA-41)

Dipakai apa adanya dari `docs/marketing/positioning-icp-store-page-akuisisi.md`:

- **Judul:** `Triangulate: Co-op Mystery` (§3.1)
- **Deskripsi:** §3.2, lima paragraf, ±950 karakter
- **Genre/Subgenre:** `Puzzle → Escape Room` (§3.3)

**Peringatan yang mengikat dan harus dipatuhi saat store page diisi manusia:**
jangan menulis "hangout", "roleplay", "vibes", "chill with friends", "private
room", atau "cafe/bar" di store page mana pun. Kata-kata itu memicu klasifikasi
*social hangout*, dan social hangout tanpa private space hanya untuk 16+ —
artinya audiens 13–15 yang jadi target utama (PRD §12) terpotong. Sumber:
`https://create.roblox.com/docs/production/promotion/content-maturity`.

**`ASSUMPTION` yang belum diverifikasi:** batas karakter deskripsi. Draf ±950
karakter; angka batas resmi belum diverifikasi. Yang memverifikasi: field
deskripsi di Creator Dashboard saat publish.

**Konsistensi MVP:** deskripsi menyebut "2 pemain dengan NPC Archivist" dan
"solo sebagai Director". Keduanya bergantung pada NPC Searcher/Handler dan
NPC Director — yang belum ada (butir 2.5) dan NPC Director baru P1 (§16). Copy
store page-nya sudah benar; yang belum ada adalah produknya.

### 4.3 `MaxPlayers = 3` (PRD §15)

**Status: belum disetel. Ini aksi manusia.**

`Players.MaxPlayers` **tidak bisa diubah dari script** — dokumentasi resminya:
"This property can only be set through a specific place's settings on the
Creator Dashboard."
(`https://create.roblox.com/docs/reference/engine/classes/Players`)

Yang ada di kode adalah verifikasi, bukan penegakan: `src/server/init.server.luau`
§3 hanya `warn` bila `Players.MaxPlayers ~= Config.MAX_PLAYERS`. Artinya place
dengan `MaxPlayers ≠ 3` tetap bisa jalan dan hanya menghasilkan peringatan di
output server.

Tindakan: **Configure → Places → Access → Maximum Visitor Count = 3**, di
Creator Dashboard, pada place yang dipublikasikan. Belum bisa dikerjakan dari
sini: tidak ada akun Creator di lingkungan ini.

---

## 5. Apa yang dirilis, apa yang ditahan, apa yang jadi P1

### 5.1 Yang SIAP secara teknis (bukan berarti cukup untuk rilis)

| Aset | Bukti |
|---|---|
| Build Rojo bersih (200.771 byte) | Gerbang #4 |
| 566 assertion, 0 gagal | Gerbang #1 |
| Lint dan format bersih | Gerbang #2, #3 |
| Data kasus `gallery_01` lolos validator (2 varian, 33 node) | Gerbang #5 |
| Pemisahan info per role tanpa kebocoran (25 pasangan) | `tests/leak-sweep.spec.luau` |
| Meja puzzle + drag-and-snap terverifikasi protokolnya | `docs/mvp-notes.md` §3.2, §3.3 |
| Arsitektur dan skema kasus terdokumentasi | `docs/arsitektur.md`, `docs/case-schema.md` |

### 5.2 Yang DITAHAN — tidak boleh ikut rilis

| Ditahan | Alasan |
|---|---|
| Publikasi place | Ceklis P0 belum lengkap: Director tanpa layar (2.3), lokasi Searcher tidak ada (2.2), lobby tidak ada (2.5), ping tidak tersambung (2.6) |
| Store page | Butuh `MaxPlayers = 3` disetel dulu, dan nama/arah visual di dokumen PRD belum dirapikan |
| Kuesioner maturity | Draf siap (bagian 6), pengiriman aksi manusia |
| Case 0 dan konten naratif | PR #6 belum di-merge; Case 0 belum ada di `main` |
| Aktifkan CI | `vars.CI_ENABLED` belum disetel; butuh keputusan owner (dan biaya menit Actions = eskalasi CFO) |
| Rate limiting remote | Utang teknis #1 `docs/arsitektur.md` §9 — prasyarat rilis, belum ada |

### 5.3 Yang jadi pekerjaan P1 (PRD §16 "Pasca-MVP")

- Daily case + validator, leaderboard, rank per role, streak.
- Agency HQ + kosmetik, private server/invite.
- NPC Director terpandu, patroli NPC, spectator slot, event komunitas.

P1 bukan alasan menahan rilis. Yang menahan rilis adalah **P0 yang belum
selesai** — dan per hari ini tidak ada satu pun butir P0 yang berstatus `jalan`
penuh, karena minggu 2–7 belum menghasilkan apa pun di `main` (bagian 8).

### 5.4 Utang teknis yang harus lunas sebelum rilis

Dari `docs/arsitektur.md` §9, dengan status per hari ini:

| # | Utang | Kapan | Status |
|---|---|---|---|
| 1 | Tidak ada rate limiting remote | Sebelum rilis | **Belum** |
| 2 | `Players.MaxPlayers` hanya diverifikasi, tidak dipaksa | Sebelum playtest | **Belum** — aksi manusia (4.3) |
| 3 | Lobby minggu 5 belum ada | Minggu 5 | **Belum** |
| 4 | `luau-lsp` + `sourcemap.json` belum di CI | EXTA-34 | **Belum** — CI nonaktif |
| 5 | Telemetri dihitung tapi tidak dikirim | EXTA-34 | **Belum** |
| 6 | Belum ada `RemoteFunction` untuk permintaan balasan | Kalau perlu | Tidak dibutuhkan (keputusan sadar: hindari `InvokeClient`) |

---

## 6. Kuesioner maturity Roblox (PRD §14, §18)

Draf jawaban per pertanyaan ada di **`docs/kuesioner-maturity-roblox.md`**.
Ringkasnya:

- **Label yang dituju: `Mild`.** Itu membuka Roblox Kids (5–8), Roblox Select (9–15), dan 16+ — cukup untuk target 13+ PRD §14. `Moderate` masih memenuhi 13+ (lewat Select) tetapi menutup Kids. `Restricted` (18+ terverifikasi) tidak memenuhi target. Perlu dicatat: Roblox tidak memakai label "13+" sama sekali.
- **Deskriptor yang berisiko terpicu:** **Fear** (adegan mencekam, musik tegang, suspense) dan — kalau Agency HQ masuk MVP — **Free-form user creation** serta **Social hangout**. Keduanya adalah pembatas 16+.
- **Pengiriman belum dilakukan.** Ini aksi manusia: Creator Dashboard → Configure → Questionnaire → Start → … → Questionnaire Preview → Submit. Label terbit segera setelah Submit.
- **Konsekuensi tidak mengisi:** "If an experience does not have accurate or all content maturity information, Roblox restricts the playability of the experience on the platform for all players."

Temuan pendukung: **G-11/B-06** di `docs/decision-log.md` — kuesioner maturity
belum punya pemilik eksekusi dan belum punya tanggal. EXTA-46 mengusulkan Damar
menyiapkan, owner mengirim.

---

## 7. Aksi manusia yang belum dilakukan

Daftar ini ada supaya tidak ada yang tersirat selesai padahal belum. **Tidak
satu pun** dari butir di bawah bisa dikerjakan dari lingkungan ini.

| # | Aksi | Siapa | Kenapa tidak bisa dari sini |
|---|---|---|---|
| 1 | Set `MaxPlayers = 3`: Creator Dashboard → Configure → Places → Access → Maximum Visitor Count | Owner | Butuh akun Creator; `Players.MaxPlayers` tidak bisa disetel dari script |
| 2 | Kirim kuesioner maturity Roblox | Owner (bahan dari Damar) | Butuh Creator Dashboard; label terbit saat Submit |
| 3 | Publikasikan place ke Roblox | Owner | Butuh akun Creator dan keputusan rilis |
| 4 | Isi judul, deskripsi, genre store page (copy dari EXTA-41 §3.1–3.3) | Owner/CMO | Butuh Creator Dashboard |
| 5 | Rekrut 3 penguji minggu 7 dan jalankan playtest di mobile | COO (EXTA-46/EXTA-47) | Butuh manusia dan perangkat |
| 6 | Aktifkan CI: `gh variable set CI_ENABLED --body true --repo jettapindika/triangulate` | Owner | Butuh keputusan owner; biaya menit Actions = eskalasi CFO |
| 7 | Jawab DR-01/DR-02/DR-03 (nama di dokumen PRD, durasi timer cleanup, validasi N) | Owner | Keputusan produk, bukan teknis |
| 8 | Set `start_date` di `docs/roadmap.json` | Owner | Skrip pengingat gate berhenti eksplisit selama null; jangan ditebak |

Tambahan yang perlu keputusan owner (bukan aksi, tapi menghambat):

- **Judul dokumen PRD masih placeholder.** `docs/prd-v0.2.md:1` dan `docs/narasi/narasi-triangulate.md:204,229` masih menulis "Co-op Puzzle Mystery (Working Title)", padahal owner sudah menetapkan **Triangulate**. `README.md` sudah diperbaiki di PR ini. Revisi judul PRD sebaiknya lewat workstream pemiliknya (bukan disunting diam-diam dari sini), supaya rujukan antar-issue tidak putus. Sumber: bagian 4.1.
- **§8 vs §16 bertabrakan**: §8 menyatakan role apa pun yang AFK diambil alih NPC, tetapi §16 menempatkan NPC Director di P1. Perilaku AFK Director di MVP belum terdefinisi. Di kode, `Roles.NPC_FILLABLE` sudah mengecualikan Director dan perbedaannya dilaporkan lewat `warn` (`src/server/init.server.luau:266`), bukan didiamkan — jadi tidak ada keputusan yang diambil diam-diam.
- **G-18**: skema data kasus tidak punya `par_time_s`, padahal rank S/A/B/C §5 butuh pembanding waktu. Sudah dikonfirmasi: `grep -rn "par_time" schema/ src/ data/` → nol hasil.

---

## 8. Mengapa minggu 2–7 belum menghasilkan apa pun di `main`

Ini dicatat supaya tidak terbaca sebagai kelalaian. Ada dua lapis: penyebab, lalu
statusnya per hari ini.

### 8.1 Penyebab: environment gagal disiapkan

Sub-issue EXTA-55 sampai EXTA-60 (minggu 2–7) tidak pernah menghasilkan
commit apa pun. Penyebabnya lingkungan, bukan kode:

- Runtime menargetkan `local_directory /Users/mac/Documents/Roblox` dengan
  `execution_mode = worktree`.
- Direktori itu **bukan git repository ber-commit** —
  `git rev-list --count HEAD` gagal dengan
  `fatal: ambiguous argument 'HEAD': unknown revision`. Isinya hanya berkas
  tak terlacak (`.DS_Store`, `Triangulate.rbxlx`, `.probe/`, `Plugins/`, dll).
- Worktree mode menuntut minimal satu commit untuk bercabang dari; tanpa itu
  persiapan environment gagal sebelum agen mana pun mulai bekerja.

Pesan kegagalan yang tercatat di thread EXTA-31 pada 2026-10-04, dalam dua
varian yang muncul berurutan (yang kedua muncul setelah ada yang menjalankan
`git init` di folder itu — gate-nya cuma bergeser satu langkah):

```
execenv: local_directory "/Users/mac/Documents/Roblox" is not a git repository,
but its project resource is set to execution_mode=worktree; initialise a
repository there or switch the resource back to in_place
```
```
execenv: repository "/Users/mac/Documents/Roblox" has no commit to branch from
(worktree mode needs at least one commit; make an initial commit or switch the
resource back to in_place)
```

Jumlah pesan kegagalan yang teramati di thread EXTA-31: **14**, terdiri dari
**8 pemberitahuan sistem** `Delegated task ... ended in a final failure
(environment_prepare_failed)` (`01a10729-81f9`…`01a10729-82df`, semuanya
2026-10-04T13:45:23Z) dan **6 laporan agen** `prepare execution environment:
execenv: ...` (`01a10729-83ca` 13:45:23Z, `01a10729-8693` 13:45:24Z,
`01a10729-89b1` 13:45:25Z, `01a1072a-873d` 13:46:30Z, `01a1072a-a2e4` 13:46:37Z,
`01a1072b-3c04` 13:47:16Z). Sebarannya menurut bunyi pesan: **11 dengan varian
pertama** ("is not a git repository, but its project resource is set to
execution_mode=worktree") dan **3 dengan varian kedua** ("has no commit to
branch from"). Owner menulis "fix the error couldnt prepare the execution
environment" (`01a1072b-38aa-7124-9a0f-4d8a633722df`, 13:47:15Z).

**Yang perlu diketahui:** resource project yang terdaftar hanyalah satu —
`a94a5d66-b3cd-4b4e-a40d-3e76c8c6d8dc`, `github_repo`,
`https://github.com/jettapindika/triangulate` @ `main`. Path
`/Users/mac/Documents/Roblox` **bukan** resource project; ia target
`execution_mode` runtime. Pekerjaan minggu 8 ini bisa selesai justru karena
checkout-nya lewat `multica repo checkout`, bukan lewat path itu.

### 8.2 Status per hari ini: environment sudah diperbaiki, minggu 2–7 sedang berjalan

**Blocker environment-nya sudah tidak aktif.** Owner menulis "fix the error
couldnt prepare the execution environment" (`01a1072b-38aa-7124-9a0f-4d8a633722df`,
2026-10-04T13:47:15Z); perbaikannya dilaporkan di komentar
`01a1073b-fa0f-7260-882e-9a60ab32861c` (2026-10-04T14:05:33Z). Bukti yang bisa
saya verifikasi sendiri dari sini: `multica issue children` pada 2026-10-04
menunjukkan **EXTA-55, EXTA-56, EXTA-57, EXTA-58, EXTA-59, EXTA-60 berstatus
`in_progress`** — bukan `todo` lagi. Tidak ada lagi pesan `execenv` setelah
`01a1072b-3c04` (13:47:16Z).

**Yang belum berubah, dan itu yang membuat ceklis ini tetap berlaku:**
`origin/main` masih di `80b35e9`, dan tidak ada branch maupun pull request dari
EXTA-55…EXTA-60. Jadi seluruh ceklis di bagian 2 menggambarkan `main` hari ini —
bukan gambaran akhir, karena minggu 2–7 baru mulai berjalan.

**Perbaikan permanen (keputusan owner, tidak dikerjakan dari sini):**

1. Kalau `/Users/mac/Documents/Roblox` memang harus tetap jadi target runtime:
   jadikan git repo ber-commit lebih dulu, baru pasang `execution_mode = worktree`.
2. Kalau tidak, andalkan `github_repo` + workdir per-issue seperti sekarang.

Setting repo dan resource **tidak** diubah di sini — itu di luar batas
kewenangan dan butuh persetujuan owner.

---

## 9. Langkah berikutnya, terurut

Urutan ini menaruh yang termurah dan paling memblokir lebih dulu.

1. **Tuntaskan minggu 2–6** (EXTA-55…EXTA-60) — sudah `in_progress` sejak environment diperbaiki (bagian 8.2). Urutan internalnya: lokasi + objek + mini-aksi, Director UI, lobby, Case 0.
2. **Sambungkan `Ping.OnServerEvent`** di `src/server/init.server.luau`. Paling murah, dan tanpa ini tidak ada satu pun kanal komunikasi yang bekerja — padahal komunikasi adalah gameplay utamanya.
3. **Pasang handler client untuk `ReportCard`**, `ClueCard`, `Pinpoint`, `TargetMarker`, `DeductionResult` — datanya sudah dikirim dan sudah diproyeksikan dengan benar; yang hilang hanya sisi penerimanya.
4. **Jalankan playtest minggu 7** (EXTA-60) dan ukur idle time serta tingkat penyelesaian.
5. **Terapkan §3 ui-spec di `src/client`**: breakpoint, `UISizeConstraint`, safe area.
6. **Rate limiting remote** (utang #1) sebelum rilis.
7. **Aksi manusia** (bagian 7), terutama `MaxPlayers` dan kuesioner.

---

## 10. Sumber

- `docs/prd-v0.2.md` §14, §16, §17, §18, §19
- `docs/arsitektur.md` §8, §9
- `docs/mvp-notes.md` §3
- `docs/spike-minggu-0.md`, `docs/spike-minggu-0-hasil.md`
- `docs/art/ui-spec.md` §1–§3, §7
- `docs/case-schema.md`
- `docs/decision-log.md` (DR-01/02/03, G-11, G-18)
- `docs/marketing/positioning-icp-store-page-akuisisi.md` §1, §3.1–§3.3
- `docs/metrics/skema-event-telemetri.md`
- Keluaran gerbang: `lune run tests/run.luau`, `stylua --check`, `selene`, `rojo build`, `tools/validate_case.luau` pada commit `80b35e9`
- Dokumentasi Roblox (diakses 2026-10-04):
  - `https://create.roblox.com/docs/reference/engine/classes/Players` — `MaxPlayers` hanya bisa disetel lewat Creator Dashboard
  - `https://create.roblox.com/docs/production/promotion/content-maturity` — label maturity dan aturan klasifikasi
  - `https://create.roblox.com/docs/scripting/security/access-control` — apa pun yang direplikasi ke client bisa di-ekstrak
