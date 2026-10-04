# Catatan MVP — minggu 0-1

Rujukan: PRD v0.2 §15, §16, §17. Dokumen ini mencatat apa yang benar-benar
jalan setelah minggu 0-1, apa yang belum, dan risiko teknis yang terbukti dari
spike — bukan daftar rencana.

Yang bisa dijalankan ulang ada di repo: `lune run tests/run.luau` (566 assertion),
`lune run tests/leak-sweep.spec.luau`, dan `lune run tools/spike-s02-protokol.luau`.
Angka di bawah berasal dari ketiganya plus `docs/spike-minggu-0-hasil.md`.

## 1. Apa yang sudah jalan

| Bagian PRD | Yang ada sekarang | Bukti |
|---|---|---|
| §15 meja top-down | Kamera `Scriptable` top-down, raycast jari ke bidang meja (`Table.mount`) | `src/client/Table/init.luau`; matematika sinar-bidang diuji di `tests/puzzle-table.spec.luau` |
| §15 posisi potongan diatur server | Server pemegang `PuzzleTable.State`; client hanya menerima `{id, region, x, y, placed}` | `PuzzleTable.clientPayload` membuang `target` dan `correct` |
| §15 interpolasi di client | `PuzzleTable.interpolate` dipanggil tiap `RenderStepped` | `src/client/Table/init.luau:310` |
| §4 drag-and-snap | Ambil potongan, gerakkan mengikuti jari, lepas → snap ke sel terdekat | `grab`/`drag`/`release` di `src/client/Table/init.luau` |
| §4 satu tipe puzzle end to end | `torn_doc` dari `obj_schedule` → `ev_schedule` → `clue_guard_off` | `tests/gate-minggu-0.spec.luau` suite 3, memakai `data/cases/gallery_01.json` |
| §15 server-authoritative | Resep deduksi, penilaian tuduhan, dan penyelesaian meja semuanya di server | `src/server/init.server.luau`; `tests/leak-sweep.spec.luau` 25 pasangan view×role, 0 temuan |
| §4 Clue Card dari bukti | Meja selesai → `yields` → `ClueCard` ke Director, Handler, Searcher dengan proyeksi per role | `handlePlacePiece`, `src/server/init.server.luau:547` |
| §16 data-driven | Tipe puzzle dibaca dari `data/cases/gallery_01.json`; menambah kasus tidak menyentuh kode | `PuzzleTableService.build` |
| §15 telemetri | Event `input` per penempatan potongan | `TelemetryService.record` di `handlePlacePiece` |

Tiga tipe puzzle sudah punya grid-nya (`torn_doc` 4×4, `timeline` 4×2, `cipher`
3×3), tetapi hanya `torn_doc` yang diuji end to end. Dua sisanya menunggu
pemetaan region sheet saat art pertama ada.

## 2. Apa yang belum

### 2.1 Bukan scope minggu 0-1 (sesuai PRD §17)

- **Lobby, preferensi role, NPC, AFK/rejoin** — minggu 5. `Matchmaking`,
  `RoleAssignment`, dan `NPCController` sudah ada dan diuji, tetapi
  pemanggilnya belum: timer 45/90 detik belum dijadwalkan, ready check belum
  punya UI, `preferences` masih `Roles.ALL` (tanpa preferensi). Daftar lengkap
  ada sebagai komentar di `src/server/init.server.luau` bagian 7.
- **NPC Director terpandu** — P1 (PRD §16).
- **Case 0 dan story case** — minggu 6.
- **Kontradiksi di clue board** — minggu 3-4.

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
| MCP Studio | **JALUR MATI** — `tools/list` kosong, butuh auth Assistant interaktif di UI Studio | Aksi manusia |

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

## 5. Langkah berikutnya, terurut

1. **Uji gutter 4–6 px di perangkat** saat art pertama ada (§3.1). Ini yang
   paling murah dan paling berisiko kalau ditunda — kalau 1 px memang kurang,
   seluruh pipeline sheet berubah.
2. **Uji S0.2 dengan latensi buatan** 100 ms dan 300 ms + packet loss, di
   perangkat. Angka pesan sudah lulus; yang belum diuji adalah perilaku saat
   pesan datang terlambat.
3. **Lanjut minggu 2** (PRD §17): loader kasus dari data dan satu rantai
   A→bukti end to end di lokasi — sekarang baru meja dan rantai `torn_doc`
   yang jalan.
4. **Minggu 5**: isi pemanggil lobby/ready check/NPC yang sudah bernama di
   `src/server/init.server.luau` bagian 7.
