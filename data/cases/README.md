# Data kasus

PRD §10: "Semua kasus berupa data (puzzle, clue, graf, briefing per role, solusi).
Menambah kasus tidak menyentuh kode."

Direktori ini adalah satu-satunya tempat data kasus hidup. Di-mount Rojo ke
`ServerStorage.Cases` (lihat `default.project.json`), yang **tidak pernah
direplikasi ke client** — lihat `docs/arsitektur.md` bagian "Mekanisme tidak
bocor".

## Satu kasus = satu berkas

`<case_id>.json`. Nama berkas harus sama dengan `case_id` di dalamnya, karena
`CaseLoader.load` mencari anak `ServerStorage.Cases` berdasarkan nama.
`CaseLoader.availableCaseIds` mengurutkan hasilnya, jadi pemilihan kasus
deterministik.

## Aturan wajib: JSON `null` berubah menjadi `nil` di Luau

Ini bukan preferensi gaya, ini perilaku terukur Rojo 7.7.1. Berkas `.json` di
bawah `$path` dibangun menjadi **ModuleScript berisi literal tabel Luau**, dan
Rojo menuliskan `null` sebagai `nil`:

- pada key tabel, `nil` **menghapus key itu**;
- pada array, `nil` **memotong panjang array** sampai elemen terakhir yang
  bukan-nil.

Artinya `{"unlocks": null}` dan `{"unlocks": []}` tidak sama: yang pertama
menghasilkan tabel tanpa key `unlocks`, yang kedua menghasilkan tabel kosong
yang masih bisa diiterasi. Dan `{"needs": ["a", null, "b"]}` menjadi array
berisi **satu** elemen, bukan tiga.

**Karena itu: jangan pakai `null`.** Pakai nilai sentinel yang tipenya benar:

| Maksud | Tulis | Jangan tulis |
|---|---|---|
| Tidak ada | `""` | `null` |
| Tidak ada (boolean) | `false` | `null` |
| Tidak ada (daftar) | `[]` | `null` |
| Tidak ada (angka) | `0` | `null` |

Verifikasi: `grep -c null data/cases/*.json` harus `0` untuk setiap berkas.

## Kunci jenis node: `type`, bukan `kind`

PRD §10 menulis node dengan kunci `"type"`. Di Luau, `type` **sah** sebagai nama
field (`node.type` parse dengan benar; yang tidak boleh adalah memakai `type`
sebagai nama variabel karena menutupi global `type`).

`CaseLoader.shapeProblems` membaca `node.kind` lebih dulu lalu jatuh ke
`node.type`, jadi kedua bentuk termuat. **Pakai `type`** supaya berkas kasus
sama persis dengan PRD §10. Empat jenis yang dikenal: `object`, `evidence`,
`clue`, `deduction`.

## Yang diperiksa saat start

`CaseLoader.shapeProblems` adalah pemeriksaan bentuk minimum, bukan validator
skema. Yang ditangkapnya:

- `case_id` ada dan berupa string;
- `nodes` ada, berupa tabel, dan tidak kosong;
- setiap node punya `id` yang tidak kosong, dan tidak ada `id` duplikat;
- setiap node punya jenis yang dikenal;
- setiap entri `needs` menunjuk node yang benar-benar ada.

Kasus yang gagal salah satu di atas **menghentikan start** (`error`), bukan
menghasilkan sesi setengah jalan.

Skema lengkap dan validator graf (asiklik, tidak ada rantai buntu) adalah
deliverable **EXTA-33**. Seam-nya sudah ada:

```lua
CaseLoader.setValidator(function(case)
    -- kembalikan (ok: boolean, daftarMasalah: {string})
end)
```

`setValidator` mengembalikan validator sebelumnya supaya uji bisa memulihkannya.

## Graf: ketergantungan tanpa siklus

PRD §4: "Semua kasus adalah graf ketergantungan (tanpa siklus)." Node `evidence`
dan `deduction` punya `needs`; `unlocks` menunjuk apa yang terbuka setelahnya.
Alur satu rantai (PRD §4):

```
object --gives_key--> evidence --yields--> clue --needs--> deduction --unlocks--> pinpoint
```

`ClueGraph` (`src/server/ClueGraph.luau`) yang membaca graf ini di runtime;
`gallery_01.json` adalah contoh kerja yang mengikuti bentuk itu.
