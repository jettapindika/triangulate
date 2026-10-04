# Triangulate

Co-op Puzzle Mystery (working title) — game co-op asimetris 3 pemain di Roblox.

- PRD: `docs/prd-v0.2.md`
- Arsitektur teknis: `docs/arsitektur.md`
- Rencana spike minggu 0: `docs/spike-minggu-0.md`
- Issue induk: EXTA-31 — scaffold ini: EXTA-32

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

src/server/              ServerScriptService -- tidak pernah direplikasi
  init.server.luau       Titik masuk: guard, remote, sesi, handler, lobby
  CaseLoader.luau        Memuat dan memvalidasi kasus
  ClueGraph.luau         Graf ketergantungan: ketersediaan, asiklik
  DeductionEngine.luau   Resep deduksi
  AccusationService.luau Tuduhan, percobaan, rank
  RoleAssignment.luau    Penetapan role + prioritas keadilan
  Matchmaking.luau       Lobby, ready check, batas waktu
  NPCController.luau     Pengambilalihan AFK, aksi NPC
  TelemetryService.luau  Idle time, waktu ke clue pertama

src/client/              StarterPlayerScripts
  init.client.luau       Titik masuk client
  NetClient.luau         Binding remote; tiap remote punya fungsi bernama
  Hud/init.luau          Kerangka HUD
  Hud/PingWheel.luau     Ping wheel

data/cases/              Di-mount ke ServerStorage.Cases
  gallery_01.json        Kasus contoh "Lukisan yang Tertukar"
  README.md              Aturan penulisan data kasus

tests/                   Uji CLI via Lune
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
lune run tests/run.luau        # 287 assertion
selene src tests               # lint
stylua --check src tests       # format
```

Batasnya: `luau-analyze` yang berdiri sendiri tidak punya definisi API Roblox,
jadi ia hanya bisa memeriksa modul murni:

```sh
luau-analyze --mode=strict \
  src/shared/Config.luau src/shared/Roles.luau src/shared/Net.luau \
  src/shared/PingPhrases.luau src/server/RoleAssignment.luau \
  src/server/Matchmaking.luau src/server/AccusationService.luau \
  src/server/DeductionEngine.luau src/server/ClueGraph.luau \
  src/server/TelemetryService.luau src/server/NPCController.luau
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

Scaffold ini adalah minggu 0 dari PRD §17. Yang **belum** terpasang, dengan
nomor minggunya:

| Belum | Minggu (PRD §17) |
|---|---|
| Meja puzzle top-down, drag-and-snap | 1 |
| Lokasi, objek, kunci, rantai A→bukti end to end | 2 |
| Clue board Director, kombinasi, pinpoint | 3 |
| Tuduhan + batas percobaan (logikanya sudah ada, UI-nya belum) | 4 |
| Lobby lengkap, preferensi role, NPC, AFK/rejoin | 5 |
| Case 0, story case #1, ping wheel final | 6 |

Daftar lengkap utang teknis beserta risikonya ada di `docs/arsitektur.md`
bagian 9.
