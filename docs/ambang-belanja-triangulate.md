# Ambang Belanja, Urutan Potong, dan Format Tinjauan Bulanan — Triangulate

Pemilik dokumen: **Bayu — Pengawas Anggaran & Risiko**. Basis aturan: **EXTA-3** (aturan alokasi, ambang, urutan potong) dan PRD v0.2 §16 (scope), §17 (roadmap), §13 (monetisasi).

Saya menjaga aturan, bukan memberi izin. Dokumen ini tidak menambah ritme tinjauan baru — tinjauan menempel pada kadensi operasi yang dipegang COO (EXTA-46).

## 1. Anggaran proyek = anggaran yang sama

Proyek Triangulate **tidak punya pos anggaran sendiri**. Sumber dana proyek adalah anggaran bulanan yang sudah ditetapkan di EXTA-3:

| Pos | Alokasi bulanan | Sumber | Sifat |
|---|---|---|---|
| **A — Wajib** | Rp 1.150.000 | EXTA-3 | tidak pernah dipotong |
| **B — Tumbuh** | Rp 250.000 | EXTA-3 | dipotong setelah C habis |
| **C — Opsional** | Rp 300.000 | EXTA-3 | **dipotong pertama** |
| **D — Cadangan** | Rp 300.000 | EXTA-3 | tidak pernah dipotong; dipakai = wajib diisi ulang |
| **Total** | **Rp 2.000.000** | EXTA-3 | pemasukan Rp 2.000.000 → sisa nol |

Pemetaan pengeluaran proyek ke pos `ASUMSI` — EXTA-3 menetapkan pos untuk kebutuhan pribadi, bukan untuk proyek game, jadi pemetaan ini usulan saya dan berlaku sampai CFO menetapkan lain:

| Jenis pengeluaran proyek | Pos | Alasan |
|---|---|---|
| Tooling berlangganan, aset visual/audio berbayar, biaya playtest, pendaftaran/transport terkait proyek | **B** | Preseden EXTA-3: "biaya lomba masuk pos B, bukan C"; pos B adalah pos tumbuh |
| Hiburan, nongkrong, hobi, langganan non-esensial | **C** | EXTA-3 |
| Darurat/kesehatan | **D** | EXTA-3 |
| Makan, transport harian, data, ATK kuliah | **A** | EXTA-3 — bukan pengeluaran proyek |

**Konsekuensi yang harus dicatat sekarang:** PRD §17 menuntut 8 minggu kerja, plus aset visual (§13 kosmetik, §15 gambar puzzle) dan playtest (§17 minggu 7), tetapi **tidak ada satu baris pun di PRD yang menyebut anggaran**. Ruang belanja proyek yang tersedia hanya **pos B Rp 250.000/bulan** — dan pos itu sudah memuat buku/kursus. Angka biaya aktual belum ada; EXTA-43 (model biaya build 8 minggu) dan EXTA-40 (harga texture/economy Robux) yang mengisinya. Sampai angka itu ada, setiap belanja proyek di atas Rp 200.000 otomatis berhenti di ambang.

## 2. Ambang keputusan — Rp 200.000

Rp 200.000 adalah **10% dari anggaran bulanan** (10% × Rp 2.000.000 = Rp 200.000, EXTA-3). Ambang ini tidak dilonggarkan dan tidak ada pengecualian.

| Besar transaksi | Tindakan |
|---|---|
| ≤ Rp 50.000, pos A/B | jalan saja |
| Rp 50.000 – Rp 200.000, posnya ada sisa | jalan, catat di buku besar |
| **> Rp 200.000** | **berhenti** — terbitkan berkas keputusan (§4) dan naikkan ke CFO |
| Pos C sudah Rp 300.000 bulan itu | berhenti, tidak ada tambahan |
| Pos D dipakai | isi ulang dulu bulan depan, **sebelum C dapat jatah lagi** |

**Urutan potong: C dulu, lalu B. D dan A tidak pernah dipotong.**

Urutan pengecekan yang saya jalankan pada setiap pengeluaran yang dilaporkan:

1. Nominal > Rp 200.000? → berhenti, terbitkan berkas keputusan.
2. Pos C sudah Rp 300.000 bulan ini? → berhenti, tidak ada tambahan.
3. Apakah bulan lalu pos D terpakai? → tahan jatah C sampai D kembali penuh.
4. Posnya punya sisa? → jalan, catat.
5. Ragu pos mana → tanya Dimas (buku besar, EXTA-45), jangan menebak.

**Contoh perhitungan** (angka transaksi di bawah adalah contoh, bukan harga yang sudah diketahui):

> Usulan: beli satu paket aset visual Rp 350.000 dari pos B.
>
> 1. Rp 350.000 > ambang Rp 200.000 → **wajib keputusan**, tidak boleh langsung dibayar.
> 2. Pos B bulan ini: Rp 250.000, sudah terpakai Rp 100.000 (buku) → sisa Rp 150.000. Kurang Rp 200.000.
> 3. Opsi yang tersedia: (a) potong pos C — Rp 300.000 jadi Rp 100.000, hiburan hampir nol bulan ini; (b) tunda ke bulan depan dan kumpulkan dari sisa B dua bulan; (c) tolak dan pakai aset gratis/placeholder sampai angka EXTA-43 ada.
> 4. Yang **tidak boleh**: ambil dari pos A, atau ambil dari pos D tanpa mengisi ulang.

## 3. Format tinjauan bulanan

Tiga bagian, ketiganya wajib. Tinjauan tanpa keputusan adalah laporan, bukan tinjauan.

### Bagian 1 — Realisasi vs alokasi per pos

| Pos | Alokasi | Realisasi | Sisa |
|---|---|---|---|
| A — Wajib | 1.150.000 | ? | ? |
| B — Tumbuh | 250.000 | ? | ? |
| C — Opsional | 300.000 | ? | ? |
| D — Cadangan | 300.000 | ? | ? |
| **Total** | **2.000.000** | ? | ? |

Angka realisasi hanya boleh diisi dari buku besar (EXTA-45). Kalau buku besar belum jalan, tulis **"tidak terukur"** — bukan nol. Nol yang salah lebih berbahaya daripada selisih yang jujur.

### Bagian 2 — Variance per pos

| Pos | Selisih (Rp) | Selisih (%) | Arah | Pemicu eskalasi (>15%) |
|---|---|---|---|---|
| A | ? | ? | lebih/kurang | > Rp 172.500 |
| B | ? | ? | lebih/kurang | > Rp 37.500 |
| C | ? | ? | lebih/kurang | > Rp 45.000 |
| D | ? | ? | lebih/kurang | > Rp 45.000 |

Kolom pemicu adalah 15% dari alokasi tiap pos. **Variance > 15% di pos mana pun = eskalasi ke CFO.** Aturan penggeseran dari EXTA-3 tetap berlaku: **selisih di pos A dibayar oleh pos C**; kalau C sudah nol dan A masih lebih, tabelnya yang harus disetel ulang — bukan tanda kegagalan.

### Bagian 3 — Satu keputusan yang dipaksa variance itu

Format baris keputusan — tiga bagian, tanpa kecuali:

1. **Dari tingkat mana** — pos mana yang membengkak, berapa, dan karena apa.
2. **Apa yang dikorbankan** — apa yang hilang kalau keputusan ini diambil.
3. **Opsi yang tersedia** — minimal dua, dengan konsekuensi masing-masing.

Kalau variance tidak memaksa keputusan apa pun, **tulis itu juga** ("tidak ada keputusan yang dipaksa bulan ini"). Bagian yang boleh dikosongkan adalah isinya, bukan keberadaannya.

### Pemeriksaan wajib setiap bulan

- Pos D terpakai bulan lalu → sudah diisi ulang? Kalau belum, pos C tidak dapat jatah.
- Ada transaksi > Rp 200.000 tanpa berkas keputusan? Kalau ada, terbitkan berkas susulan dan eskalasi.
- Buku besar mencatat estimasi sebagai estimasi, bukan sebagai realisasi?

### Kadensi

Tinjauan mengikuti kadensi operasi yang dipegang COO (EXTA-46). Kalau kadensinya mingguan, pemeriksaan ambang ikut mingguan dan ringkasan realisasi vs alokasi disusun bulanan — **saya tidak membuat ritme kedua.**

## 4. Berkas keputusan ambang

Diterbitkan setiap ada transaksi > Rp 200.000, sebelum uang keluar. Satu berkas per transaksi.

```
## Berkas Keputusan Ambang — <tanggal>

Transaksi: <deskripsi> · Nominal: Rp <jumlah> · Pos: <A/B/C/D> · Pemohon: <nama>

1. Dari tingkat mana
   Pos <X> terpakai Rp <n> dari Rp <alokasi>. Sisa pos: Rp <sisa>.
   Pemicu: <nominal melewati ambang / pos C sudah penuh / pos D terpakai>.

2. Apa yang dikorbankan
   <Item yang tidak jadi dibelanjakan / pos yang dipotong / jadwal yang mundur>.

3. Opsi yang tersedia
   a. <opsi> — konsekuensi: <...>
   b. <opsi> — konsekuensi: <...>
   c. Tolak — konsekuensi: <...>

Pemeriksaan aturan:
- [ ] Nominal > Rp 200.000 → berhenti (terpenuhi)
- [ ] Pos C belum Rp 300.000 bulan ini
- [ ] Pos D tidak dipakai, atau sudah diisi ulang
- [ ] Bukan pos A, bukan pos D yang dipotong

Keputusan: <diisi CFO> · Tanggal: <...>
```

**Saya tidak mengisi baris Keputusan.** Saya menyiapkan berkas supaya CFO bisa memutuskan cepat; keputusan dan pengecualian bukan milik saya.

## 5. Pemicu eskalasi

Aturan eskalasi saya, tidak berubah:

| Pemicu | Ke |
|---|---|
| Transaksi > Rp 200.000 | Michelle — CFO |
| Pos D dipakai | Michelle — CFO |
| Variance bulanan > 15% di pos mana pun | Michelle — CFO |
| Risiko keuangan baru | Michelle — CFO |
| Kadensi tinjauan | Rafael — COO |
| Pemicu teknis | Nathan — CTO/CIO |
| Lintas fungsi | Mika — Chief of Staff |

Daftar risiko yang saat ini harus naik, beserta alasannya, ada di `docs/risk-register-triangulate.md` bagian F.

## Perubahan dokumen

| Versi | Tanggal | Perubahan | Alasan |
|---|---|---|---|
| v1 | 2026-10-04 | Versi pertama: ambang, urutan potong, format tinjauan, berkas keputusan, daftar eskalasi | EXTA-44 |
