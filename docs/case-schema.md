# Kontrak Data Kasus & Loader

Rujukan: PRD v0.2 §4, §5, §10, §15. Dokumen ini menjelaskan bentuk data satu kasus, aturan
yang ditegakkan validator, dan cara server memuatnya tanpa membocorkan solusi ke client.

## Berkas

| Berkas | Peran |
|---|---|
| `schema/case.schema.json` | Spesifikasi bentuk (JSON Schema draft 2020-12). Untuk editor dan tooling. |
| `src/shared/case/CaseGraph.luau` | Operasi graf: dependensi, deteksi siklus, ketercapaian. |
| `src/shared/case/CaseValidator.luau` | **Otoritas eksekutabel.** Menegakkan aturan lintas-field yang tidak bisa diungkapkan JSON Schema. |
| `src/shared/case/CaseLoader.luau` | Memuat kasus, memilih varian dari seed, memproyeksikan payload per role. |
| `tools/validate_case.luau` | Harness CLI untuk penulis kasus. |
| `tests/run.luau` | Runner tunggal seluruh suite. |
| `tests/case-schema.spec.luau` | Uji regresi validator, loader, dan proyeksi per role. |
| `tests/leak-sweep.spec.luau` | Uji kebocoran seluruh pasangan view x role pada payload nyata. |
| `tests/fixtures/*.json` | Kasus rusak yang sengaja disimpan sebagai bukti perilaku validator. |

JSON Schema memvalidasi **bentuk**; validator Luau memvalidasi **arti**. Keduanya dipakai:
editor memberi umpan balik cepat dari skema, server menolak kasus cacat lewat validator.

## Bentuk satu kasus

```jsonc
{
  "case_id": "gallery_01",
  "title": "Lukisan yang Tertukar",
  "case_type": "standard",        // standard | daily | case0  -> N = 4 | 3 | 2
  "key_deductions": 4,            // N pembuka form tuduhan (PRD §5)
  "location": "gallery",
  "suspects": ["curator", "guard", "collector"],   // kandidat Pelaku untuk form tuduhan (PRD §5)
  "motives": ["debt", "revenge", "greed"],         // kandidat Motif
  "methods": ["access_card", "alarm_off", "forged_log"],  // kandidat Cara; harus memuat setiap variants[].method
  "variants": [
    { "variant_id": "v_curator", "culprit": "curator", "motive": "debt", "method": "access_card" }
  ],
  "briefing": { "searcher": "...", "handler": "...", "director": "..." },
  "briefings": {
    "Searcher": { "case_id": "gallery_01", "location": "gallery", "objective": "...",
                  "knowns": ["..."], "unknowns": ["..."], "target": "obj_schedule" },
    "Handler":  { "case_id": "gallery_01", "location": "gallery", "objective": "...",
                  "knowns": ["..."], "unknowns": ["..."] },
    "Director": { "case_id": "gallery_01", "location": "gallery", "objective": "...",
                  "knowns": ["..."], "unknowns": ["..."],
                  "statements": [{ "who": "collector", "text": "..." }] }
  },
  "nodes": [
    { "id": "obj_schedule", "type": "object",    "gives_key": "key_a" },
    { "id": "ev_schedule",  "type": "evidence",  "puzzle": "torn_doc", "needs": ["key_a"], "yields": "clue_schedule" },
    { "id": "clue_schedule","type": "clue_card", "source": "ev_schedule" },
    { "id": "ded_access",   "type": "deduction", "needs": ["clue_schedule", "clue_access"],
      "supports": ["culprit"], "unlocks": ["obj_ledger"] }
  ],
  "statements": [
    { "who": "curator", "text": "...", "lie": true, "contradicted_by": "clue_access", "variants": ["v_curator"] }
  ],
  "solution": {
    "v_curator": { "culprit": "curator", "motive": "debt", "method": "access_card",
                   "required_deductions": ["ded_c_culprit_1", "ded_c_method_1", "ded_c_motive_1", "ded_c_motive_2"] }
  }
}
```

### Empat tipe node (PRD §4)

| `type` | Field wajib | Arti |
|---|---|---|
| `object` | `gives_key` | Searcher menemukan objek di lokasi; memberi *kunci* ke Handler. |
| `evidence` | `puzzle`, `yields` (opsional `needs`) | Handler merakit bukti memakai kunci; menghasilkan Clue Card. |
| `clue_card` | `source` | Fakta di clue board Director. `source` = id bukti penghasilnya. |
| `deduction` | `needs` (≥2), `supports` | Director menggabungkan Clue Card; menopang field tuduhan. |

`puzzle` ∈ `torn_doc`, `timeline`, `cipher` (tipe MVP).

### Field opsional yang menentukan perilaku

- **`briefings` vs `briefing`** — dua field berbeda, keduanya wajib. `briefing` (huruf kecil) adalah
  teks prosa per role yang divalidasi `CaseValidator`; `briefings` (huruf besar) adalah Role Card
  terstruktur (PRD §9) yang diproyeksikan `Net.forRole` view `briefing`. Kunci `briefings` memakai
  huruf besar (`Searcher`/`Handler`/`Director`) supaya cocok dengan allowlist per role di
  `Net.CLIENT_VIEWS.briefing`. Karena `Net.project` menyalin nilai apa adanya, `briefings` **wajib
  sudah bersih**: `briefings.Director.statements` hanya boleh memuat `who` dan `text`, bukan
  `lie`/`contradicted_by`.
- **`suspects`/`motives`/`methods`** — ruang pilihan form tuduhan (PRD §5). Ini kandidat, bukan
  jawaban: solusinya tetap hanya di `solution` di sisi server. `methods` harus memuat setiap nilai
  `variants[].method`, kalau tidak Director tidak bisa menulis jawaban yang benar.
- **`node.variants`** — node hanya aktif di varian tersebut. Tanpa field ini, node aktif di semua
  varian. Inilah cara cabang solusi berbagi sebagian aset tapi tidak seluruhnya.
- **`node.unlocks`** — node yang terbuka setelah deduksi selesai. Diperlakukan sebagai **tepi
  dependensi nyata** (PRD §4: deduksi "membuka target baru"), bukan metadata. Tanpa tepi ini,
  target hasil deduksi akan salah dilaporkan sebagai rantai buntu.
- **`node.supports`** — daftar field tuduhan (`culprit`/`motive`/`method`) yang ditopang deduksi.
  Berupa daftar karena satu deduksi bisa menopang lebih dari satu field.
- **`statement.variants`** — pernyataan hanya berlaku di varian tersebut. Pelaku berbeda tiap
  cabang, jadi pernyataan pembohong pun berbeda per cabang.

## Aturan yang ditegakkan validator

Validator mengembalikan `Report { ok, errors, warnings }`. Tiap temuan punya `code` stabil dan
`path` menunjuk lokasi di JSON. Pemeriksaan graf **dilewati** bila masih ada kerusakan struktural,
supaya pesan turunannya tidak menyesatkan.

| Kode | Arti |
|---|---|
| `graph.cycle` | Dependensi melingkar (PRD §10: "tanpa dependensi melingkar"). |
| `graph.key_unobtainable` | Bukti meminta kunci yang tidak disediakan objek aktif mana pun. |
| `graph.dead_end` | Node aktif tidak bisa dicapai dari objek mana pun (PRD §10: "tidak ada rantai yang buntu"). |
| `graph.field_unsupported` | Ada field tuduhan tanpa satu pun deduksi aktif yang menopangnya (PRD §5). |
| `statements.no_liar` | Tidak ada pernyataan bohong yang berlaku di varian ini; Kontradiksi tak bisa ditandai (PRD §4). |
| `solution.*` | Jalur solusi hilang, deduksinya tidak dikenal/tidak aktif/tidak tercapai, atau tidak menutup ketiga field tuduhan. |
| `gate.key_deductions_exceeds` | `key_deductions` melebihi jumlah deduksi yang benar-benar bisa dicapai. |
| `gate.key_deductions_count` | `key_deductions` tidak sama dengan panjang `required_deductions`. |
| `gate.key_deductions_type_mismatch` | `key_deductions` tidak sesuai `case_type` (standard 4 / daily 3 / case0 2). |

Ketercapaian memakai semantik **AND**: sebuah node baru dianggap tercapai bila seluruh
dependensinya tercapai. Akibatnya node di dalam siklus tidak pernah tercapai — satu mekanisme
yang sekaligus menangkap siklus dan rantai buntu.

Sebuah rantai buntu selalu punya akar: kunci yang tidak tersedia atau siklus. Validator melaporkan
**akar masalah dan setiap node yang terdampar**, jadi penulis kasus melihat sebab dan akibatnya.
Itulah mengapa fixture `cycle.json` memunculkan `graph.cycle` sekaligus `graph.dead_end`.

## Kontrak loader (PRD §10, §15)

```lua
local CaseLoader = require("src/shared/case/CaseLoader")

local result = CaseLoader.load(caseData, seed)
-- result.ok == false -> kasus cacat; result.report berisi pesan validator. Server TIDAK menjalankan kasus ini.
-- result.ok == true  -> result.session dipakai server saja.
```

1. **Validasi lebih dulu.** `load` memanggil `CaseValidator.validate`. Kasus cacat tidak pernah
   dijalankan — `session` bernilai `nil`.
2. **Pemilihan varian dari seed.** `selectVariant` memetakan seed ke indeks varian lewat hash
   FNV-1a 32-bit dengan penyelesaian akhir (avalanche). Deterministik dan stabil lintas platform,
   jadi semua pemain dalam satu sesi mendapat cabang yang sama tanpa saling memberi tahu.
   Aritmetika 32-bit dikerjakan eksplisit karena `number` Luau adalah float 64-bit: perkalian FNV
   mentah mencapai 2^56 dan bit rendahnya hilang.
3. **Session adalah data server.** `session.solution` dan `session.variant` memuat pelaku, motif,
   cara, dan jalur solusi. Blok ini tidak pernah dikirim ke client.

### Pemisahan informasi per role

`projectForRole(case, variantId, role)` memakai **allowlist**, bukan denylist: hanya field yang
terdaftar untuk role itu yang ikut. Field baru yang ditambahkan ke skema tidak pernah bocor ke
client secara tidak sengaja.

| Role | Menerima |
|---|---|
| `searcher` | Node `object`: `id`, `label`, `gives_key`. Tanpa pernyataan. |
| `handler` | Node `evidence`: `id`, `label`, `puzzle`, `needs`. Tanpa pernyataan. |
| `director` | Node `clue_card` dan `deduction`: `id`, `label`. Plus `statements` (`who`, `text`) **hanya yang berlaku di varian sesi ini**. |

Yang **tidak pernah** ikut ke payload mana pun (`CaseLoader.SERVER_ONLY_FIELDS`):

```
solution  culprit  motive  method  lie  contradicted_by  required_deductions
```

Director menerima teks pernyataan untuk dibaca, tapi tidak menerima `lie` maupun
`contradicted_by` — mencari kontradiksi tetap pekerjaannya. Resep deduksi (`needs`) juga tidak
dikirim: server yang memeriksa kombinasi Clue Card (PRD §15).

## Menjalankan

```bash
lune run tools/validate_case.luau -- data/cases/gallery_01.json
lune run tools/validate_case.luau -- tests/fixtures/cycle.json tests/fixtures/dead_end.json tests/fixtures/key_deductions_too_high.json
lune run tests/run.luau
```

`validate_case.luau` keluar dengan kode 1 bila ada kasus yang gagal, sehingga bisa dipakai di CI
sebelum kasus baru dirilis.
