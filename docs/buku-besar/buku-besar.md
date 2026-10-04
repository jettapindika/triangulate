# Buku besar pengeluaran — Triangulate

Pencatat: **Dimas — Pencatat Pengeluaran Harian** (issue EXTA-45).
Sumber aturan pos: **EXTA-3** — keputusan owner "(a) Rp 0 dulu" dan tabel alokasi final.
Disusun: 2026-10-04. **Belum ada satu baris realisasi** — lihat §6.

> Buku besar mencatat uang yang benar-benar keluar. Kalau tidak ada catatan, jawabannya
> "tidak tercatat" — bukan taksiran.

## 1. Peta pos — terkunci, dari EXTA-3

| Pos | Nama | Jumlah/bulan | Porsi |
|---|---|---|---|
| **A — Wajib** | Makan & minum 750.000 · Transport 200.000 · Data/pulsa 100.000 · ATK & print kuliah 100.000 | 1.150.000 | 57,5% |
| **B — Tumbuh** | Buku/kursus 250.000 · **Tools Exta 0** | 250.000 | 12,5% |
| **C — Opsional** | Hiburan, nongkrong, hobi | 300.000 | 15,0% |
| **D — Cadangan** | Darurat/kesehatan saja | 300.000 | 15,0% |
| | **Total** | **2.000.000** | 100% |

Pemasukan Rp 2.000.000 = budget Rp 2.000.000, sisa nol (EXTA-3). Setelah A dibayar, yang
diputuskan tiap bulan untuk B + C + D adalah **Rp 850.000**.

- **Urutan potong:** C dulu, lalu B. **D dan A tidak pernah dipotong.** Cadangan yang dipakai
  wajib diisi ulang bulan berikutnya sebelum C dapat jatah lagi.
- **Ambang keputusan Rp 200.000** (10% budget) — tidak diubah oleh buku besar ini.
- Pos D = darurat/kesehatan. **Setiap pemakaian D masuk eskalasi CFO.**

## 2. Format satu baris

Format cepat saat mencatat (notes HP, satu baris per transaksi):

```
tanggal | pos (A/B/C/D) | jumlah rupiah | keterangan satu baris
2026-10-05 | B | 25000 | cetak 20 lembar case sheet playtest
```

Contoh di atas hanya **format** — bukan pengeluaran yang tercatat. Tidak ada satu pun baris
realisasi per 2026-10-04 (§6).

Aturan: **satu baris satu transaksi**, tidak digabung, tidak dibulatkan diam-diam,
keterangan satu baris. Untuk belanja proyek, tambahkan workstream PRD di kolom §3 dan
pos yang belum pasti ditulis `?`, bukan ditebak (§5).

## 3. Kolom buku besar

| Kolom | Isi | Nilai yang sah |
|---|---|---|
| `id` | nomor baris, urut naik | `T-0001`, `T-0002`, … |
| `tanggal` | tanggal uang keluar | `YYYY-MM-DD` |
| `deskripsi` | keterangan satu baris | teks bebas |
| `jumlah_rupiah` | angka bulat tanpa titik/pemisah ribuan | bilangan ≥ 1 |
| `pos` | pos alokasi | `A` \| `B` \| `C` \| `D` \| `?` |
| `status` | realisasi atau estimasi (§4) | `realisasi` \| `estimasi` |
| `sumber` | dari mana angka itu datang | `catatan owner` \| `struk` \| `ASUMSI: <sumber>` |
| `bukti` | bukti yang bisa ditunjukkan | `struk`, `screenshot`, `transfer`, `-` |
| `pemilik` | yang mengeluarkan uang | `owner` |
| `workstream_prd` | workstream + bagian PRD (§7) | mis. `Visual §13` |

Berkas bulanan: `buku-besar-YYYY-MM.csv`. Satu baris = satu transaksi, header saja bila kosong.

### 3.1 Isi kolom `workstream_prd`

Tulis `<EXTA-xx> <nama workstream> §<bagian PRD>`, mis. `EXTA-39 Visual §13`. Workstream
berjalan di issue turunan EXTA-31:

| Workstream | Rujukan PRD |
|---|---|
| EXTA-32 Arsitektur teknis & scaffold | §15, §16, §17 |
| EXTA-33 Skema data kasus & validator | §4, §5, §10 |
| EXTA-34 CI/CD & infra | §15, §17 |
| EXTA-35 Otomasi laporan metrik | §12, §15, §17 |
| EXTA-36 Kamus metrik & telemetri | §6, §12, §15 |
| EXTA-37 Pengukuran & audit handoff | §6, §12, §17 |
| EXTA-38 Konten kasus & copy | §4, §7, §9, §10 |
| EXTA-39 Art direction & UI mobile | §13, §14, §15, §19 |
| EXTA-40 Riset benchmark & ekonomi Robux | §12–§15 |
| EXTA-41 Positioning & akuisisi | §11–§14 |
| EXTA-42 Monetisasi & unit economics | §11, §12, §13 |
| EXTA-43 Biaya build & runway | §10, §13, §17 |
| EXTA-44 Risk register & ambang belanja | §5, §8, §18 |
| EXTA-45 Buku besar pengeluaran | — |
| EXTA-46 Operating plan & playtest | §6, §8, §16, §17, §18 |
| EXTA-47 SOP produksi & playtest | §9, §10, §17 |
| EXTA-48 Log keputusan & decision request | §3, §19 |
| EXTA-49–EXTA-53 Narasi/OKR, dependensi, integrasi, kickoff MVP | — |

Baris yang tidak bisa dipetakan ke workstream mana pun ditulis `?` dan ikut butir 2 laporan
mingguan (§8) — sama seperti pos yang ambigu.

## 4. Realisasi vs estimasi vs lubang

Tiga keadaan, tidak boleh dicampur:

| Keadaan | Syarat | Cara tulis |
|---|---|---|
| **Realisasi** | Ada bukti (struk/nota/screenshot/transfer) **atau** pernyataan owner bertanggal | `status=realisasi`, `sumber=catatan owner`/`struk` |
| **Estimasi** | Angka bukan dari catatan owner — harga pasar, penawaran, hasil riset | `status=estimasi`, `sumber=ASUMSI: <sumber>` + apa yang akan memverifikasi/menggantikannya |
| **Lubang** | Periode/pos tanpa catatan sama sekali | `TIDAK TERCATAT` — bukan 0, bukan taksiran |

Aturan:

1. **Estimasi tidak pernah masuk kolom realisasi.** Laporan memisahkan keduanya di tabel berbeda.
2. **Lubang dilaporkan sebagai lubang.** `TIDAK TERCATAT` tidak sama dengan Rp 0; Rp 0 hanya
   ditulis kalau owner menyatakan tidak ada pengeluaran di pos itu.
3. **Tidak ada angka ketiga.** Setiap angka berasal dari catatan owner atau berlabel `ASUMSI`.
4. Seluruh angka per pos di EXTA-3 masih **ASUMSI harga pasar Jogja** — owner menyatakan tidak
   hafal pengeluaran aktual. Selama itu belum diganti catatan 2 minggu, alokasi = rencana,
   bukan realisasi.

## 5. Pos ambigu — ditandai, bukan ditebak

Baris yang tidak jelas posnya **tetap dicatat** dengan `pos=?`, lalu masuk eskalasi. Baris tidak
dibuang, tidak dipindahkan, tidak ditebak posnya.

**Eskalasi wajib ke Michelle — CFO** bila:

- pos D dipakai;
- satu pos lewat 100% sebelum akhir bulan;
- transaksi tunggal > Rp 200.000;
- pengeluaran tidak bisa dicocokkan ke pos mana pun (`pos=?`).

## 6. Posisi awal per 2026-10-04

| Item | Nilai | Sumber |
|---|---|---|
| Baris realisasi tercatat | **0** | belum ada catatan apa pun dari owner |
| Komitmen berjalan (langganan/tools) | **Rp 0** | EXTA-3: "belum ada" langganan; keputusan "(a) Rp 0 dulu" — VPS dan mini PC tidak dibeli |
| Pos B Tools Exta | Rp 0 alokasi | EXTA-3, tabel final |
| Pengeluaran sebelum 2026-10-04 | **TIDAK TERCATAT** | owner menyatakan "jujur ga hafal" (EXTA-3) |

Jadi tabel realisasi bulan ini masih kosong dan **tidak diisi taksiran**. Angka yang belum ada
memang belum ada.

Cara mengisinya sudah ditetapkan di EXTA-3: catat 3 angka per hari selama 14 hari
(makan+minum · transport · sisanya), lalu pindahkan ke CSV ini. Setelah itu alokasi per pos
disetel ulang memakai angka owner, bukan asumsi pasar.

## 7. Pengeluaran proyek → pos

Peta pos di §1 dibuat untuk budget bulanan pribadi owner (EXTA-3), bukan untuk belanja proyek.
Beberapa jenis belanja proyek belum punya pos berisi budget. Semua baris di bawah berstatus
**ASUMSI** — belum ada keputusan owner/CFO, jadi buku besar ini **tidak** menetapkannya.

| Jenis belanja proyek (rujukan PRD) | Pos kandidat | Status |
|---|---|---|
| Print playtest, fotokopi case sheet, ATK kasus | A — ATK & print kuliah | `ASUMSI` — apakah print proyek boleh masuk pos kuliah? |
| Pulsa/data untuk uji mobile (§12 mayoritas mobile) | A — Data/pulsa | `ASUMSI` |
| Buku/kursus Luau, Roblox, desain kasus | B — Buku/kursus | `ASUMSI` |
| Plugin/aset Roblox berbayar, VPS, domain, CI | B — **Tools Exta (Rp 0)** | **tanpa alokasi → eskalasi** |
| Aset visual & audio berbayar (§13) | B — Tools Exta? | **tanpa alokasi → eskalasi** |
| Akuisisi/store page (§11–§14) | tidak ada pos | **tanpa alokasi → eskalasi** |
| Transport & konsumsi tester saat playtest (§17 minggu 7) | tidak ada pos | **tanpa alokasi → eskalasi** |
| Cadangan untuk kejadian mendadak | D — hanya darurat/kesehatan | **pemakaian D untuk proyek = eskalasi** |

Selama pos-nya belum ditetapkan, tiap baris belanja proyek dicatat `pos=?` dan dilaporkan di
laporan mingguan §8 butir 2.

## 8. Format laporan selisih mingguan ke CFO

Pekan = Senin–Minggu. Dikirim ke Michelle — CFO setiap pekan, dan wajib memuat butir 1–5.

```
## Laporan selisih mingguan — Triangulate
Pekan: <YYYY-MM-DD> → <YYYY-MM-DD> · Disusun: <YYYY-MM-DD> · Untuk: Michelle — CFO

### 1. Realisasi vs alokasi
| Pos | Alokasi bulan | Realisasi pekan ini | Realisasi bulan-berjalan | Sisa | % terpakai MTD | Flag pekan |
|---|---|---|---|---|---|---|
| A — Wajib    | 1.150.000 | | | | | |
| B — Tumbuh   |   250.000 | | | | | |
| C — Opsional |   300.000 | | | | | |
| D — Cadangan |   300.000 | | | | | |
| Total        | 2.000.000 | | | | | |

Sisa B + C + D setelah A: 850.000.

### 2. Baris ambigu (pos=?)
| id | tanggal | jumlah | deskripsi | kenapa ambigu | keputusan yang diminta |

### 3. Lubang data
| periode | pos | status | yang dibutuhkan untuk menutup |

### 4. Pos berjalan cepat (pace)
| Pos | MTD | Pro-rata pekan ini (25%) | Selisih | Tanda |

### 5. Eskalasi ke CFO
- [ ] pos D dipakai
- [ ] satu pos > 100% sebelum akhir bulan
- [ ] transaksi tunggal > Rp 200.000
- [ ] baris tidak bisa dicocokkan ke pos

### 6. Catatan pekan
```

**Aturan butir 1.** Angka realisasi hanya dari `status=realisasi`. Bila satu pos pun tidak
tercatat pekan itu, tulis `TIDAK TERCATAT` di kolomnya — jangan 0, jangan taksiran.

**Aturan butir 3.** Lubang data selalu dilaporkan sebagai lubang. Laporan kosong bukan laporan
nol: "tidak tercatat" adalah hasil yang sah.

**Aturan butir 4.** Pro-rata bulanan = 25% per pekan (A 287.500 · B 62.500 · C 75.000 ·
D 75.000). Butir ini **informasi**, bukan ambang.

**Flag pekan** menandai pos yang terpakai >10% alokasi bulanannya di pekan berjalan. Ambangnya:
**A 115.000 · B 25.000 · C 30.000 · D 30.000**. Catatan jujur soal aturan ini: karena sebulan
kira-kira 4 pekan, pemakaian rata berjalan ±25% per pekan, jadi flag 10% menangkap *pergerakan*,
bukan laju boros. Butir 4 yang menjawab "apakah pos ini akan habis sebelum akhir bulan".
Interpretasi flag ini minta dikonfirmasi CFO; buku besar tidak mengubah ambangnya sendiri.

## 9. Yang tidak dilakukan buku besar ini

Tidak memutuskan alokasi · tidak menggeser jatah antar pos · tidak mengubah ambang Rp 200.000 ·
tidak membelanjakan · tidak menghubungi vendor · tidak menaksir pengeluaran yang tidak dicatat ·
tidak menyimpulkan owner boros atau hemat.

## 10. Sumber

- **EXTA-3** — tabel alokasi final, urutan potong, ambang Rp 200.000, keputusan "(a) Rp 0 dulu",
  pernyataan owner "belum ada" langganan dan "jujur ga hafal" pengeluaran aktual.
- **PRD v0.2** — §12 target pengguna, §13 monetisasi, §14 safety, §17 roadmap & gate,
  §18 risiko. Disalin di `docs/prd-v0.2.md`.
- Lampiran alokasi dari skill buku besar Exta (format baris, penutupan pekan, eskalasi).
