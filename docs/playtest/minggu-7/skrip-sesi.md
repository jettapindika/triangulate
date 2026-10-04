# Skrip sesi dan lembar siap cetak — playtest minggu 7

Berkas ini adalah versi terisi dari [SOP-04](../../sop/sop-04-playtest.md) dan
[Lampiran A](../../sop/lampiran-a-instrumen-playtest.md) untuk gate minggu 7. Langkah, role, dan
definisi selesai **tidak** ditulis ulang di sini — yang ada hanya nilai yang sudah diisi untuk
sesi minggu 7 dan bentuk cetak lembarnya. Bila berbeda, SOP-04 yang berlaku.

## Jenis sesi

Playtest 3 pemain nyata (SOP-04, tabel pemicu): gate minggu 7, 3 pemain di luar tim, di mobile.
Minimum 3 sesi, satu varian kasus per sesi.

Peringatan yang mengikat dari SOP-04: pemain dari dalam tim membuat hasil **tidak sah untuk
gate**, dan satu pengamat hanya boleh mengamati satu role — bila pengamat kurang, sesi diulang
per role, bukan digabung.

## Prasyarat (SOP-04 langkah 2) — belum terpenuhi

SOP-04 langkah 2: "keempat event terbukti terekam pada satu sesi uji pendek **sebelum** sesi
utama". Untuk minggu 7 prasyarat ini belum lulus: server belum memancarkan satu event pun
(celah C-1 di [README paket](README.md)). Baris failure mode-nya eksplisit: *"Telemetri tidak
merekam idle time → gate minggu 7 tidak bisa dinilai; sesi terbuang | batalkan sesi sebelum
dimulai bila langkah 2 tidak lulus; jangan jalankan sesi tanpa instrumen."*

Konsekuensi operasional: selama C-1 dan C-2 terbuka, sesi yang dijalankan berstatus **latihan**
dan tidak masuk angka gate.

## Peran yang diisi

| Kode | Peran | Siapa | Catatan minggu 7 |
| --- | --- | --- | --- |
| F1 | Fasilitator | Rafael — COO (boleh didelegasikan ke Dewi) | membaca skrip pembuka, menjaga waktu, **tidak bermain** |
| F2 | Pengamat Searcher | Dewi — Operations Analyst | satu pengamat satu role |
| F3 | Pengamat Handler | Dewi — Operations Analyst | bila pengamat kurang: ulangi sesi per role |
| F4 | Pengamat Director | Dewi — Operations Analyst | — |
| F5 | Pencatat telemetri | Rani — Data & Metrics Engineer | ekspor + `tools/playtest-report.luau` |
| F6 | Pencatat teknis | Devan — Infrastructure & Runtime Engineer | perangkat, crash, lag, hash commit |
| F7 | Penerima temuan | Rafael — COO | kelas temuan |

## Skrip pembuka (dibacakan F1, kata per kata)

> "Kita akan main satu kasus. Sesi direkam dan ada pengamat yang melihat layar kalian, tapi tidak
> akan membantu — kalau kalian mentok, itu datanya. Kalian bebas berhenti kapan saja, tinggal
> bilang. Kalau ada yang terasa aneh atau bikin kesal, sebut saja saat itu, jangan ditahan sampai
> akhir."

## Urutan jalannya sesi

Ikuti SOP-04 A1-A7, B8-B13, C14-C22. Ringkas per fase:

**Persiapan (A1-A7).** Tetapkan gate minggu 7; periksa instrumen (langkah 2, lihat prasyarat di
atas); siapkan 3 perangkat, minimal 2 mobile kelas bawah; siapkan lembar observasi; nyalakan
perekam layar sebelum sesi dan catat timestampnya; catat `case_id` + varian; bekukan build dan
catat hash commit.

**Sesi (B8-B13).** Bacakan skrip pembuka; jalankan sampai kasus selesai / Cold Case / waktu habis;
tiap pengamat mencatat timestamp + kejadian; tandai momen untuk dipotong; **jangan membantu
pemain**; catat tiap momen keluar beserta alasan yang dikatakan pemain.

**Pasca sesi (C14-C22).** Tarik ekspor event ([format](ekspor-telemetri.md)); jalankan
`lune run tools/playtest-report.luau <ekspor.jsonl>`; hitung idle per role, persentase selesai,
quit point per role; wawancara 5 menit tiap pemain; susun dan klasifikasikan temuan; bandingkan
dengan kriteria gate; serahkan temuan dengan pemilik.

---

## A1. Lembar sesi (isi sebelum sesi)

| Kolom | Isi |
| --- | --- |
| Jenis sesi | playtest 3 pemain nyata |
| Gate yang diuji | minggu 7 (PRD §17) |
| Tanggal dan jam mulai | |
| `case_id` dan varian | |
| Hash commit / versi build | |
| Perangkat peserta | merek / model / OS / jenis |
| Peserta dan role | |
| Pengamat dan role yang diamati | |
| Kondisi akhir sesi | selesai / Cold Case / waktu habis / keluar |
| Anomali (termasuk intervensi F1) | |
| `telemetry_dropped_count` | |

## A2. Lembar observasi per role (satu lembar per role)

| Timestamp (mm:ss) | Kejadian yang terlihat | Diduga idle? (ya/tidak) | Ditandai untuk dipotong? |
| --- | --- | --- | --- |
| | | | |
| | | | |
| | | | |
| | | | |
| | | | |
| | | | |

Kolom "diduga idle" hanya dugaan **sebab**; angka resmi idle datang dari telemetri, bukan dari
lembar ini.

## A3. Kolom quit point

| Timestamp keluar | Role | Menit ke- (sejak sesi mulai) | Alasan yang dikatakan pemain | Masuk 5 menit pertama? |
| --- | --- | --- | --- | --- |
| | | | | |
| | | | | |
| | | | | |

Alasan diisi kalimat pemain, bukan rangkuman pengamat. Bila tidak sempat ditanya: `tidak
diketahui` — jangan diisi dugaan.

## A4. Tabel telemetri pasca sesi

Diisi dari ekspor event, **bukan** dari lembar observasi.

| Metrik | Searcher | Handler | Director | Sumber |
| --- | --- | --- | --- | --- |
| `idle_ratio` ambang 3 detik | | | | `idle_start`/`idle_end` |
| `idle_ratio` ambang 5 detik (metrik gate) | | | | `idle_start`/`idle_end` |
| `idle_ratio` ambang 10 detik | | | | `idle_start`/`idle_end` |
| Waktu ke clue pertama (detik) | | | | `first_clue` |
| Jumlah tuduhan | | | | `accusation_submitted` |
| Quit point (menit ke-) | | | | `player_left` |
| Kontradiksi ditandai (ya/tidak) | | | | `contradiction_marked` |

Baris pembanding gate ada di [`lembar-hasil.md`](lembar-hasil.md).

## A5. Template temuan

| ID | Sesi | Timestamp | Role | Kejadian | Kelas | Dugaan sebab | Usul perbaikan | Pemilik | Status | Bukti verifikasi |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T-001 | | | | | blocker/mayor/minor | | | | terbuka/tertutup | |

## A6. Wawancara pasca sesi (5 menit, per pemain)

1. Bagian mana yang paling lama terasa menunggu?
2. Ada momen di mana kamu tidak tahu harus berbuat apa? Di menit keberapa?
3. Kalau kamu berhenti main sekarang, apa alasannya?

Tiga pertanyaan terbuka; jangan diganti jadi ya/tidak. Jawaban apa adanya — tafsir masuk kolom
"dugaan sebab" A5.

## A7. Ringkasan hasil sesi (diisi F1 di akhir sesi)

| Butir | Isi |
| --- | --- |
| Idle time per role terhadap gate < 25% | lulus / tidak lulus |
| Sesi selesai terhadap gate > 55% | lulus / tidak lulus |
| Jumlah temuan blocker / mayor / minor | |
| Keputusan terhadap gate | lulus / tidak lulus / perlu sesi ulang |
| Alasan keputusan (sebut angka dan gate) | |
