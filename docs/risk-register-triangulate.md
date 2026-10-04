# Register Risiko Triangulate

Pemilik dokumen: **Bayu — Pengawas Anggaran & Risiko**. Rujukan: PRD v0.2 §18 (risiko & mitigasi), §5 (anti brute-force), §8 (matchmaking), §16 (scope), §17 (roadmap & gate); aturan alokasi dari **EXTA-3**.

Register ini memuat seluruh 10 baris §18, ditambah risiko dari §5, §8, risiko finansial, dan risiko scope MVP. Saya tidak menyetujui pengecualian dan tidak melonggarkan ambang; berkas ini alat keputusan, bukan izin.

## Cara membaca

- **Register risiko selalu lima kolom**: Risiko · Kemungkinan · Dampak · Mitigasi · Pemilik. Kolom itu tidak pernah ditambah atau dikurangi.
- Dua field tambahan yang diminta issue ini — **pemicu/tanda awal** dan **rencana kontingensi** — dibawa di tabel pendamping per bagian, memakai ID risiko yang sama.
- **Skala kemungkinan** — Tinggi: hampir pasti terjadi tanpa tindakan. Sedang: mungkin dalam 8 minggu roadmap. Rendah: butuh kondisi khusus.
- **Skala dampak** — Tinggi: menghambat gate minggu (PRD §17), atau menghabiskan lebih dari satu bulan anggaran. Sedang: menunda 1–2 minggu, atau menggerus satu pos alokasi. Rendah: tidak menyentuh gate maupun anggaran.
- **Status angka**: PRD tidak memuat satu pun pengukuran playtest; pengukuran pertama baru ada di minggu 7 (§17). Karena itu **setiap nilai Kemungkinan dan Dampak di bawah berstatus `ASUMSI`** — penilaian saya atas isi PRD, belum ada data yang memverifikasi. Yang akan menggantikannya: telemetri idle/quit per role (EXTA-36), laporan playtest minggu 7 (EXTA-37), dan buku besar pengeluaran (EXTA-45).
- Risiko yang sudah tidak berlaku **ditutup dengan alasan**, tidak dihapus — jejaknya yang berguna.

## A. Risiko §18 PRD — seluruh 10 baris

| Risiko | Kemungkinan | Dampak | Mitigasi | Pemilik |
|---|---|---|---|---|
| **R-01** Lobby sepi — tidak terkumpul 3 manusia | Tinggi `ASUMSI` | Tinggi | NPC pengisi, private server, invite, spectator (§8, §18) | Rafael — COO |
| **R-02** Satu pemain mendominasi sesi | Sedang `ASUMSI` | Sedang | Hanya tuduhan & hint butuh persetujuan; rantai bukti paralel (§5, §6, §18) | Rafael — COO |
| **R-03** Konten cepat habis | Sedang `ASUMSI` | Tinggi | Varian solusi, daily case, Cold Case, data-driven (§10, §18) | Nadia — Penulis Konten |
| **R-04** Spoiler menyebar lewat video/wiki | Sedang `ASUMSI` | Sedang | Cabang solusi per seed, rotasi daily (§10, §18) | Nathan — CTO/CIO |
| **R-05** Exploit / kebocoran solusi & resep | Sedang `ASUMSI` | Tinggi | Solusi & resep hanya di server (§15, §18) | Nathan — CTO/CIO |
| **R-06** Komunikasi buruk tanpa voice | Sedang `ASUMSI` | Tinggi | Ping wheel, Report Card, Table Preview (§7, §18) | Nadia — Penulis Konten |
| **R-07** Director NPC lemah | Tinggi `ASUMSI` | Sedang | Mode terpandu, rank terpisah, prioritas manusia (§8, §18) | Nathan — CTO/CIO |
| **R-08** Puzzle blur di mobile | Tinggi `ASUMSI` | Tinggi | Spike minggu 0, fallback sheet kecil (§15, §18) | Nathan — CTO/CIO |
| **R-09** Scope MVP terlalu besar | Tinggi `ASUMSI` | Tinggi | 1 lokasi, 3 tipe puzzle, 2 NPC dulu, Director NPC ke P1 (§16, §18) | Rafael — COO |
| **R-10** Rating konten meleset dari target 13+ | Rendah `ASUMSI` | Tinggi | Tema non-gore, isi kuesioner maturity sejak awal (§14, §18) | Damar — Periset Eksternal |

**Pemicu & kontingensi — bagian A**

| ID | Pemicu / tanda awal | Rencana kontingensi |
|---|---|---|
| R-01 | Median waktu tunggu > 60 dtk atau sesi gagal start > 10% (§12) | Turunkan timer lobby tetap 45 dtk, aktifkan NPC pada slot kosong, dorong private server/invite |
| R-02 | Satu role mendikte mayoritas aksi persetujuan; idle role lain naik | Geser tugas aktif (§6) ke role yang menganggur; eskalasi ke COO bila menetap |
| R-03 | Retensi D7 < 5% (§12); pemain menuntut kasus baru sebelum jadwal 1–2 minggu | Percepat daily case dari template; aktifkan Cold Case dengan modifier (§10) |
| R-04 | Solusi varian yang sedang aktif muncul di video/wiki | Naikkan jumlah varian per kasus; rotasi seed lebih sering |
| R-05 | Ada payload solusi terbaca di client; tuduhan benar tanpa deduksi | Putuskan rilis kasus terdampak; audit ulang batas server↔client (§15) |
| R-06 | Sesi gagal karena salah paham peran; pemakaian text chat naik tajam | Tambah frasa ping kontekstual; perluas Table Preview |
| R-07 | Sesi dengan NPC Director berakhir gagal jauh lebih sering dari sesi 3 manusia | Turunkan NPC Director ke P1 (§16); prioritaskan manusia di slot Director |
| R-08 | Gate minggu 0 gagal: drag tidak halus atau puzzle blur (§17) | Pakai fallback satu sheet per bukti, grid maks 6x6, gaya ilustrasi flat (§15) |
| R-09 | Ada item P1 masuk antrean MVP; gate minggu tertinggal | Pindahkan item ke P1/P2 secara eksplisit lewat decision log (§16) |
| R-10 | Hasil kuesioner maturity Roblox meminta penyesuaian konten | Turunkan intensitas tema pada kasus terdampak; ulangi kuesioner sebelum rilis |

## B. Risiko §5 — win condition & anti brute-force

| Risiko | Kemungkinan | Dampak | Mitigasi | Pemilik |
|---|---|---|---|---|
| **R-11** Kalibrasi N Deduksi Kunci salah (4 dari 6 standar) | Sedang `ASUMSI` | Tinggi | Validator kasus + validasi N di playtest minggu 7 (§5, §10, §19) | Rafael — COO |
| **R-12** Feedback "X dari 3 benar" dipakai untuk menebak field | Sedang `ASUMSI` | Sedang | Feedback tidak menyebut field mana; batas 3 percobaan (§5) | Nathan — CTO/CIO |
| **R-13** Brute-force lintas varian (ulang kasus pada varian lain) | Sedang `ASUMSI` | Sedang | Varian per seed, rank per percobaan, penalti rank (§5, §10) | Nadia — Penulis Konten |
| **R-14** Timer cleanup dipercepat tiap tuduhan salah → bukti hilang permanen | Sedang `ASUMSI` | Sedang | Timer cleanup ringan; percepatan dibatasi (§5, §6) | Rafael — COO |

**Pemicu & kontingensi — bagian B**

| ID | Pemicu / tanda awal | Rencana kontingensi |
|---|---|---|
| R-11 | Sesi selesai < 55% atau > 85% (§12, §19) | Naik/turunkan N sebesar 1 sesuai §19 — satu keputusan, bukan penyesuaian bertahap |
| R-12 | Pola tuduhan berubah sistematis mengikuti hasil feedback | Perketat: feedback hanya di akhir kasus, bukan per percobaan |
| R-13 | Sesi "Cold Case" diulang pada varian lain sampai benar | Rank terpisah untuk pengulangan varian; batasi hint di pengulangan |
| R-14 | Bukti hilang sebelum sempat diambil; idle role naik > 25% | Tetapkan plafon percepatan timer; siapkan rute alternatif pada graf (§4) |

## C. Risiko §8 — matchmaking, NPC, dan disconnect

| Risiko | Kemungkinan | Dampak | Mitigasi | Pemilik |
|---|---|---|---|---|
| **R-15** AFK takeover / rejoin tidak utuh (state drift) | Sedang `ASUMSI` | Tinggi | State tetap utuh; slot ditahan 3 menit; NPC mengisi sementara (§8) | Nathan — CTO/CIO |
| **R-16** Ready check / lobby timer gagal → sesi < 3 manusia | Tinggi `ASUMSI` | Sedang | Ready check 10 dtk, opsi tunggu sampai 90 dtk, NPC mengisi (§8) | Rafael — COO |
| **R-17** Prioritas keadilan / rotasi role memicu ketidakpuasan | Sedang `ASUMSI` | Sedang | 2 preferensi role, prioritas keadilan, rotasi hanya di private server + toggle host (§3, §8, §10) | Rafael — COO |

**Pemicu & kontingensi — bagian C**

| ID | Pemicu / tanda awal | Rencana kontingensi |
|---|---|---|
| R-15 | Pemain kembali dan progres role-nya berbeda dari sebelum putus | Bekukan state role saat takeover; rekonsiliasi state di server sebelum rejoin |
| R-16 | Sesi gagal start > 10%; waktu tunggu median > 60 dtk (§12) | Isi slot dengan NPC lebih awal; izinkan mulai 2 pemain + 1 NPC |
| R-17 | Pemain keluar di lobby setelah penetapan role; quit 5 menit pertama naik di satu role (§12) | Tampilkan alasan penetapan role di lobby; hormati preferensi pertama lebih sering |

## D. Risiko finansial

Basis: anggaran **Rp 2.000.000/bulan**, pemasukan Rp 2.000.000/bulan, **sisa nol** — sumber: EXTA-3 (kata pemilik). Ambang keputusan **Rp 200.000** (10% anggaran). Pemicu eskalasi ke CFO: transaksi > Rp 200.000, pos D dipakai, variance bulanan > 15% di pos mana pun, risiko keuangan baru.

| Risiko | Kemungkinan | Dampak | Mitigasi | Pemilik |
|---|---|---|---|---|
| **R-18** Proyek tidak punya pos anggaran penanggung — biaya PRD (§13, §15, §17) tidak punya rumah di pos A–D | **Sudah terjadi** | Tinggi | Tetapkan pos penanggung sebelum pengeluaran proyek pertama (butir F1) | Michelle — CFO |
| **R-19** Sisa anggaran nol — tidak ada penyangga bulanan | **Sudah terjadi** | Tinggi | Pos D Rp 300.000 tidak boleh disentuh untuk gaya hidup (EXTA-3) | Michelle — CFO |
| **R-20** Saldo kas awal belum diketahui → kejutan langsung jadi utang | **Sudah terjadi** — data belum ada | Tinggi | Catat saldo kas dalam buku besar (EXTA-45) | Dimas — Pencatat Pengeluaran Harian |
| **R-21** Pengeluaran proyek > Rp 200.000 tanpa berkas keputusan | Sedang `ASUMSI` | Tinggi | Ambang Rp 200.000 wajib berhenti + berkas keputusan (EXTA-3; `docs/ambang-belanja-triangulate.md`) | Bayu — Pengawas Anggaran & Risiko |
| **R-22** Pos D dipakai dan tidak diisi ulang sebelum C dapat jatah | Sedang `ASUMSI` | Tinggi | Urutan potong: C dulu, lalu B; D dan A tidak pernah dipotong; D diisi ulang lebih dulu (EXTA-3) | Bayu — Pengawas Anggaran & Risiko |
| **R-23** Biaya produksi konten pasca rilis belum berangka (1 story case per 1–2 minggu, §10) | Tinggi `ASUMSI` | Tinggi | EXTA-43 menyusun rincian biaya + skenario hemat/base/mahal | Ayu — Analis Biaya & Runway |
| **R-24** Buku besar belum berjalan → realisasi tak terlacak, variance tak bisa dihitung | Tinggi `ASUMSI` | Sedang | Template buku besar + aturan penandaan estimasi vs realisasi (EXTA-45) | Dimas — Pencatat Pengeluaran Harian |
| **R-25** Aset, audio, atau tooling berbayar menggerus pos B/C tanpa keputusan | Sedang `ASUMSI` | Sedang | Pembelian aset masuk pos B (preseden EXTA-3); > Rp 200.000 = ambang | Michelle — CFO |
| **R-26** Tidak ada pendapatan penutup — proyek murni biaya (host-owns, tanpa pay-to-win, §13) | Tinggi `ASUMSI` | Sedang | Model pendapatan + unit economics case pack/kosmetik (EXTA-42) | Michelle — CFO |

**Pemicu & kontingensi — bagian D**

| ID | Pemicu / tanda awal | Rencana kontingensi |
|---|---|---|
| R-18 | Pengeluaran proyek pertama muncul di buku besar tanpa pos | Terbitkan berkas keputusan ambang; eskalasi F1 ke CFO sebelum uang keluar |
| R-19 | Satu kejadian ≥ Rp 600.000 memakai dua bulan cadangan | Ajukan ke CFO: potong pos C, bukan pos A/D |
| R-20 | Muncul pengeluaran tak terduga tanpa saldo penutup | Hentikan belanja opsional sampai saldo kas tercatat; eskalasi ke CFO |
| R-21 | Ada transaksi proyek melewati ambang tanpa berkas | Hentikan proses pencatatan, terbitkan berkas keputusan susulan, eskalasi ke CFO |
| R-22 | Pos D > Rp 0 pada tinjauan bulanan | Tahan jatah pos C bulan berikutnya sampai D kembali penuh; eskalasi ke CFO |
| R-23 | Kasus baru dijadwalkan tanpa angka biaya | Tahan jadwal rilis konten sampai angka tersedia; pakai varian dari aset yang ada (§10) |
| R-24 | Tinjauan bulanan tanpa angka realisasi | Laporkan variance sebagai "tidak terukur" — bukan nol; eskalasi ke CFO |
| R-25 | Muncul langganan/aset berbayar di buku besar tanpa berkas keputusan | Hentikan pembelian berulang; pindahkan ke berkas keputusan bulan berikutnya |
| R-26 | Biaya berjalan tanpa satu pun angka pendapatan | Perlakukan seluruh biaya sebagai burn; laporkan sebagai risiko keuangan baru ke CFO |

## E. Risiko scope MVP

| Risiko | Kemungkinan | Dampak | Mitigasi | Pemilik |
|---|---|---|---|---|
| **R-27** Item P1 ditarik ke MVP (mis. Director NPC terpandu, daily case) | Sedang `ASUMSI` | Tinggi | Batas MVP §16; pemindahan hanya lewat decision log (EXTA-48) | Rafael — COO |
| **R-28** Gate minggu 0 gagal (drag mobile tidak halus, puzzle blur) | Sedang `ASUMSI` | Tinggi | Spike teknis minggu 0 sebelum pekerjaan meja puzzle (§15, §17) | Nathan — CTO/CIO |
| **R-29** Aset kasus (Case 0, story case #1, 2 varian) belum siap saat gate minggu 6 | Sedang `ASUMSI` | Tinggi | EXTA-38 memproduksi konten dalam skema kasus (§10) | Nadia — Penulis Konten |
| **R-30** Scope meja puzzle membengkak di luar 3 tipe MVP | Sedang `ASUMSI` | Sedang | MVP: dokumen sobek, timeline, cipher (§4, §16) | Rafael — COO |
| **R-31** Kualitas NPC Handler/Searcher tidak cukup untuk sesi 2 pemain | Sedang `ASUMSI` | Sedang | NPC prioritas rendah: Searcher dan Handler (§8); Archivist lambat tapi otomatis | Nathan — CTO/CIO |

**Pemicu & kontingensi — bagian E**

| ID | Pemicu / tanda awal | Rencana kontingensi |
|---|---|---|
| R-27 | Ada item P1 di antrean minggu 0–8 | Kembalikan item ke P1; catat keputusan di decision log (EXTA-48) |
| R-28 | Gate minggu 0 tidak lulus | Tunda minggu 1; pakai fallback gambar sheet kecil (§15) |
| R-29 | Playtest internal minggu 6 tanpa kasus lengkap | Jalankan playtest dengan Case 0 saja; jadwalkan ulang story case #1 |
| R-30 | Muncul tipe puzzle ke-4 di antrean MVP | Tolak masuk MVP; catat sebagai P1 |
| R-31 | Sesi 2 pemain selesai jauh lebih jarang dari sesi 3 pemain | Naikkan kecepatan Archivist; izinkan Director mengambil alih puzzle manual (§8) |

## Risiko yang ditutup

Belum ada. Register ini baru dibuka; tidak ada baris yang ditutup dengan alasan pada versi pertama.

## F. Risiko yang harus dieskalasi ke owner

Aturan eskalasi saya: transaksi > Rp 200.000 · pos D dipakai · variance bulanan > 15% di pos mana pun · risiko keuangan baru. Aturan itu tetap; daftar di bawah adalah butir yang **saat ini** harus naik, beserta alasannya. Saya tidak menghubungi agent lain langsung — ini butir keputusan, bukan tugas.

| # | Butir yang dieskalasi | Ke | Alasan |
|---|---|---|---|
| F1 | **Proyek Triangulate tidak punya pos anggaran penanggung** | Michelle — CFO | Anggaran Rp 2.000.000/bulan sudah terbagi habis ke pos A/B/C/D (EXTA-3), dan sub-pos "Tools Exta" di pos B bernilai Rp 0. Biaya proyek yang disebut PRD — aset visual, audio, tooling, playtest (§13, §15, §17) — belum punya rumah. Selama ini belum ditetapkan, setiap pengeluaran proyek berhenti di ambang tanpa pos yang bisa ditunjuk. Keputusan pos penanggung bukan milik saya. |
| F2 | **Saldo kas awal belum diketahui** | Michelle — CFO / owner | Terbuka sejak EXTA-3. Pemasukan = pengeluaran, sisa nol; tanpa saldo kas, satu kejadian ≥ Rp 600.000 menghabiskan dua bulan cadangan dan langsung menjadi utang. Ini angka paling menentukan yang belum ada. |
| F3 | **Rp 2.000.000 tetap atau tidak tetap** | Michelle — CFO / owner | Terbuka sejak EXTA-3. Kalau tidak tetap, cadangan Rp 300.000 terlalu kecil dan harus naik — yang berarti pos C turun. Mengubah seluruh tabel alokasi dan ambang turunannya. |
| F4 | **Angka biaya aset, audio, dan playtest belum ada** | Michelle — CFO; Ayu — Analis Biaya (EXTA-43); Damar — Periset (EXTA-40) | Tanpa harga, tidak ada berkas keputusan yang bisa dihitung dan tidak ada variance yang bisa dibandingkan. Setiap belanja proyek > Rp 200.000 menggantung tanpa opsi yang bisa ditimbang. |
| F5 | **Buku besar belum berjalan** | Dimas — Pencatat Pengeluaran Harian (EXTA-45) | Tanpa realisasi tercatat, variance tidak bisa dihitung, dan aturan "pos D diisi ulang sebelum C dapat jatah" gagal diam-diam — satu-satunya aturan yang tidak terlihat saat gagal. |
| F6 | **N Deduksi Kunci 4 dari 6 dan durasi timer cleanup belum divalidasi** | Rafael — COO (pemilik gate minggu 7, EXTA-46) | PRD §19 menetapkan validasinya di playtest minggu 7 dengan ambang selesai 55%–85%. Kalau N turun 1, graf dan resep deduksi perlu disetel ulang — rework konten yang belum dianggarkan. |
| F7 | **Keputusan potong scope MVP bila gate minggu 0–1 gagal** | Rafael — COO (EXTA-46); Michelle — CFO untuk konsekuensi biayanya | PRD §16/§17 sudah menyiapkan pemotongan (1 lokasi, 3 tipe puzzle, 2 NPC), tetapi "apa yang dikorbankan" punya konsekuensi jadwal dan biaya. Menilai kelayakan teknis bukan milik saya; menandai bahwa ia harus diputuskan, ya. |
| F8 | **Risiko keuangan baru: biaya konten berulang tanpa pendapatan** | Michelle — CFO | PRD §10 menuntut 1 story case per 1–2 minggu pasca rilis, sementara monetisasi case pack baru ada di P2 (§16) dan tanpa pay-to-win (§13). Burn berulang tanpa penutup — ini risiko keuangan baru, bukan turunan §18. |

## Perubahan dokumen

| Versi | Tanggal | Perubahan | Alasan |
|---|---|---|---|
| v1 | 2026-10-04 | Versi pertama: 10 baris §18 + 4 baris §5 + 3 baris §8 + 9 baris finansial + 5 baris scope MVP | EXTA-44 |
