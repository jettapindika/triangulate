# Triangulate

Triangulate — game misteri co-op asimetris 3 pemain di Roblox, arah visual
detective noir. Nama dan arah visual dikunci owner (EXTA-31); rujukan keputusan
ada di `docs/decision-log.md`.

- PRD: `docs/prd-v0.2.md`
- Spesifikasi otomasi (usulan, belum diaktifkan): `docs/automation-spec.md`
- SOP produksi & playtest (draf, belum terbit): `docs/sop/README.md`
- Arsitektur teknis: `docs/arsitektur.md`
- Skema data kasus: `docs/case-schema.md`
- Rencana spike minggu 0: `docs/spike-minggu-0.md`
- Catatan integrasi stage 1: `docs/integrasi-stage-1.md`
- Issue induk: EXTA-31 — scaffold ini: EXTA-32 — skema kasus: EXTA-33

## Isi repo

```
default.project.json     Rojo: memetakan src/ dan data/ ke pohon DataModel
.luaurc                  Luau: languageMode strict + daftar global Roblox
selene.toml stylua.toml  Lint dan format
rokit.toml               Pin versi toolchain

src/shared/              Direplikasi ke client -- TIDAK BOLEH berisi rahasia
  Config.luau            Angka dari PRD (§5, §8, §12)
  Roles.luau             Tiga role, rotasi, prioritas keadilan
  Net.luau               Kontrak remote + proyeksi whitelist per role
  PingPhrases.luau       Frasa ping wheel per role
  PuzzleTable.luau       Geometri puzzle (grid, potongan, toleransi)
  LocationMap.luau       Titik masuk lokasi + anchor objek + bearing
  case/                  Skema dan validasi data kasus (murni, dual-target)
    CaseGraph.luau       Ketergantungan, keterjangkauan, unlocks
    CaseValidator.luau   Validator skema + graf (asiklik, tanpa rantai buntu)
    CaseLoader.luau      Pilih varian dari seed, proyeksi per role
    Compat.luau          Jembatan require antara Lune dan Roblox

src/server/              ServerScriptService -- tidak pernah direplikasi
  init.server.luau       Titik masuk: guard, remote, sesi, handler, lobby
  CaseLoader.luau        Memuat kasus dari ServerStorage + seam validator
  ClueGraph.luau         Graf ketergantungan: ketersediaan, asiklik
  DeductionEngine.luau   Resep deduksi
  AccusationService.luau Tuduhan, percobaan, rank
  RoleAssignment.luau    Penetapan role + prioritas keadilan
  Matchmaking.luau       Lobby, ready check, batas waktu
  NPCController.luau     Pengambilalihan AFK, aksi NPC
  TelemetryService.luau  Idle time, waktu ke clue pertama
  PuzzleTableService.luau Meja puzzle: entri, penempatan, progres
  DirectorBoardService.luau Pernyataan saksi, kontradiksi, pinpoint, N

src/client/              StarterPlayerScripts
  init.client.luau       Titik masuk client
  NetClient.luau         Binding remote; tiap remote punya fungsi bernama
  Hud/init.luau          Kerangka HUD
  Hud/PingWheel.luau     Ping wheel
  Table/init.luau        Meja puzzle top-down (kamera scriptable)
  Board/init.luau        Clue board 2D: kartu, pernyataan, pinpoint, pratinjau

schema/case.schema.json  Skema JSON data kasus (dokumentasi + alat luar)
data/cases/              Di-mount ke ServerStorage.Cases
  gallery_01.json        Kasus contoh "Lukisan yang Tertukar"
  case_00.json           Case 0: tutorial singkat
  kersana_01.json        Kasus kedua: bengkel Kersana
  README.md              Aturan penulisan data kasus

tools/                   Alat CLI
  validate_case.luau     Validator kasus; exit 1 bila ada yang gagal

tests/                   Uji CLI via Lune (satu pintu: tests/run.luau)
  run.luau               Runner
  harness.luau           Harness assertion
  *.spec.luau            Spec per modul
  fixtures/              Kasus cacat yang disengaja (cycle, dead_end, gate)
```

## Prasyarat

Toolchain dipin di `rokit.toml`: Rojo 7.7.1, StyLua 2.5.2, Selene 0.32.0,
Lune 0.10.5, dan Luau 0.741. Pasang dengan `rokit install`, atau pakai binary
yang sudah ada di `$HOME/.local/roboxtools/`.

## Menjalankan uji

Seluruh aturan permainan (deduksi, tuduhan, rank, matchmaking, penetapan role,
graf clue, telemetri, proyeksi Net) adalah modul murni yang **tidak menyentuh
global Roblox**, sehingga bisa diuji dari CLI tanpa Studio:

```sh
lune run tests/run.luau        # 947 assertion, 19 berkas spec
selene src tests tools         # lint
stylua --check src tests tools # format
```

Perintahnya sama persis dengan yang dijalankan CI (`.github/workflows/ci.yml`),
supaya hasil lokal dan hasil pipeline tidak pernah berbeda aturan. Rincian
keluaran terakhir ada di `docs/rilis.md` bagian 1.

Batasnya: `luau-analyze` yang berdiri sendiri tidak punya definisi API Roblox,
jadi ia hanya bisa memeriksa modul murni:

```sh
luau-analyze --mode=strict \
  src/shared/Config.luau src/shared/Roles.luau src/shared/Net.luau \
  src/shared/PingPhrases.luau src/shared/PuzzleTable.luau src/shared/LocationMap.luau \
  src/server/RoleAssignment.luau src/server/Matchmaking.luau \
  src/server/AccusationService.luau src/server/DeductionEngine.luau \
  src/server/ClueGraph.luau src/server/TelemetryService.luau \
  src/server/NPCController.luau src/server/PuzzleTableService.luau \
  src/server/DirectorBoardService.luau \
  src/shared/case/CaseGraph.luau src/shared/case/CaseValidator.luau \
  src/shared/case/CaseLoader.luau
```

Pemeriksaan tipe untuk berkas yang menyentuh API Roblox butuh `luau-lsp` dengan
`sourcemap.json` dari `rojo sourcemap`. Itu bagian dari EXTA-34.

## Membangun place

```sh
rojo build -o build.rbxlx
```

Hasil build tidak masuk repo (`build.rbxlx` dan `sourcemap.json` ada di
`.gitignore`). Untuk bekerja di Studio:

```sh
rojo serve
```

## Yang belum ada

Scaffold ini berjalan sampai minggu 3 dari PRD §17. Yang **belum** terpasang,
dengan nomor minggunya:

| Belum | Minggu (PRD §17) |
|---|---|
| Pemisahan info per role end to end, tuduhan + batas percobaan di UI | 4 |
| Lobby lengkap, preferensi role, NPC, AFK/rejoin | 5 |
| Case 0, story case #1, ping wheel final | 6 |

Utang yang sudah diketahui dari minggu 3, dengan alasan masing-masing:

| Utang | Kenapa belum |
|---|---|
| Map panel menggambar chip pinpoint berlabel, bukan marker di dunia | Data kasus belum punya koordinat dunia untuk objek (itu scope minggu 2) |
| Marka pinpoint belum sampai ke Searcher sebagai objek di lokasi | `Pinpoint` sudah dikirim ke Searcher dan Director; penempatan marker di dunia menyusul bersama lokasi |

Daftar lengkap utang teknis beserta risikonya ada di `docs/arsitektur.md`
bagian 9.

## Dokumen rilis

- Ceklis rilis dan status MVP P0: `docs/rilis.md`
- Draf kuesioner maturity Roblox (belum dikirim): `docs/kuesioner-maturity-roblox.md`
