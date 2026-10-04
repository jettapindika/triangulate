# SOP-04: Playtest

- Versi: draf v0.1 (belum terbit)
- Penyusun draf: Bagas — Process Writer (EXTA-47)
- Pemilik proses: Rafael — COO (fasilitator dapat didelegasikan ke Dewi — Operations Analyst)
- Rujukan PRD: §6, §8, §12, §15, §17
- Melengkapi: EXTA-46 (kriteria lulus per gate), EXTA-37 (rencana pengukuran dan target)
- Lampiran: [Lampiran A — instrumen playtest](lampiran-a-instrumen-playtest.md)

## Pemicu

| Jenis sesi | Pemicu | Peserta |
| --- | --- | --- |
| Playtest internal | gate minggu 6 (§17) atau kasus baru selesai divalidasi (SOP-01 langkah 17) | tim, 3 orang, satu per role |
| Playtest verifikasi | ada temuan kelas blocker yang diklaim sudah diperbaiki (SOP-01 langkah 20) | tim, 3 orang, dengan kondisi reproduksi temuan |
| Playtest 3 pemain nyata | gate minggu 7 (§17) | 3 pemain di luar tim, di mobile |

## Peran

| Kode | Peran | Tugas di sesi | Pemilik |
| --- | --- | --- | --- |
| F1 | Fasilitator | menyiapkan sesi, memegang skrip, menjaga waktu, tidak bermain | Rafael — COO |
| F2 | Pengamat Searcher | mencatat perilaku Searcher, tidak menyentuh kontrol | Dewi — Operations Analyst |
| F3 | Pengamat Handler | mencatat perilaku Handler | Dewi — Operations Analyst |
| F4 | Pengamat Director | mencatat perilaku Director | Dewi — Operations Analyst |
| F5 | Pencatat telemetri | menarik event §15 setelah sesi, menyusun tabel | Rani — Data & Metrics Engineer |
| F6 | Pencatat teknis | mencatat crash, lag, dan perangkat | Devan — Infrastructure & Runtime Engineer |
| F7 | Penerima temuan | menampung daftar temuan dan menetapkan kelas | Rafael — COO |

Satu pengamat memegang satu role. Bila hanya ada satu pengamat, pengamat itu mengamati satu role per sesi dan sesi diulang untuk role lain — bukan mengamati tiga role sekaligus, karena idle time per role adalah gate (§17).

## Langkah

### A. Persiapan (sebelum sesi)

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 1 | Tetapkan jenis sesi dan gate yang diuji | F1 | kalender gate EXTA-46 | lembar sesi | jenis sesi dan gate tertulis di lembar sesi |
| 2 | Pastikan build memuat event telemetri §15: idle time, waktu ke clue pertama, tuduhan, quit point | F5 | kamus event (EXTA-36) | hasil periksa | keempat event terbukti terekam pada satu sesi uji pendek sebelum sesi utama |
| 3 | Siapkan 3 perangkat, minimal 2 di antaranya mobile kelas bawah | F6 | daftar perangkat | daftar perangkat sesi | setiap perangkat tercatat merek/model/OS, dan minimal 2 adalah mobile |
| 4 | Siapkan lembar observasi per role (Lampiran A) | F2-F4 | Lampiran A | 3 lembar observasi | setiap lembar punya kolom timestamp, kejadian, dan role |
| 5 | Siapkan perekam layar untuk sesi | F6 | perangkat | rekaman sesi | rekaman berjalan sebelum sesi dimulai; timestamp rekaman dicatat |
| 6 | Siapkan varian yang akan diuji dan catat `case_id` + varian | F1 | berkas kasus (SOP-02) | lembar sesi | `case_id` dan varian tertulis; kalau varian tidak tercatat, hasil sesi tidak bisa dibandingkan |
| 7 | Bekukan build: catat commit atau versi build | F6 | repo | hash commit di lembar sesi | hash commit tertulis; temuan tanpa hash tidak dapat direproduksi |

### B. Sesi

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 8 | Bacakan skrip pembuka (di bawah) | F1 | skrip pembuka | pemain memahami perannya | F1 sudah membacakan seluruh skrip pembuka sebelum pemain menyentuh kontrol |
| 9 | Jalankan sesi sampai kasus selesai, gagal, atau waktu habis | semua | build | sesi berjalan | sesi berakhir pada salah satu dari tiga kondisi itu, dan kondisinya dicatat |
| 10 | Setiap pengamat mencatat kejadian dengan timestamp dan role | F2-F4 | lembar observasi | lembar terisi | setiap baris punya timestamp; tidak ada catatan tanpa timestamp |
| 11 | Tandai momen mencurigakan untuk dipotong dari rekaman | F2-F4 | lembar observasi | daftar timestamp | setiap tanda menunjuk timestamp di rekaman |
| 12 | Jangan membantu pemain selama sesi | F1 | — | sesi tanpa intervensi | tidak ada intervensi tercatat; bila terpaksa, dicatat sebagai anomali di lembar sesi |
| 13 | Catat momen keluar dan alasan bila pemain berhenti | F2-F4 | lembar observasi | baris quit point | setiap kejadian keluar punya timestamp dan alasan yang dikatakan pemain |

### C. Pasca sesi

| # | Langkah | Peran | Input | Output | Definisi selesai |
| --- | --- | --- | --- | --- | --- |
| 14 | Tarik event telemetri sesi | F5 | event §15 | tabel event mentah | tabel memuat 4 event §15 dengan timestamp untuk tiap role |
| 15 | Hitung idle time per role | F5 | tabel event | angka idle time per role | ada satu angka idle time untuk Searcher, Handler, dan Director masing-masing |
| 16 | Hitung persentase sesi selesai | F5 | tabel event | angka sesi selesai | ada angka pembilang (sesi selesai) dan penyebut (sesi dijalankan) |
| 17 | Hitung quit point per role | F5 | tabel event | tabel quit point | setiap kejadian keluar terpetakan ke role dan menit keberapa |
| 18 | Wawancara singkat 5 menit dengan tiap pemain | F1 | daftar pertanyaan (Lampiran A) | catatan wawancara | setiap pemain menjawab ketiga pertanyaan Lampiran A; jawaban dicatat apa adanya |
| 19 | Susun daftar temuan | F7 | lembar observasi, tabel telemetri, catatan wawancara | daftar temuan | setiap temuan punya: timestamp, role, kejadian, kelas, usul perbaikan, pemilik |
| 20 | Tetapkan kelas setiap temuan: blocker / mayor / minor | F7 | daftar temuan | daftar temuan berkelas | tidak ada temuan tanpa kelas |
| 21 | Bandingkan hasil dengan kriteria lulus gate | F7 | EXTA-46, §12, §17 | keputusan lulus/tidak | keputusan tertulis menyebut gate mana dan angka mana yang dipakai |
| 22 | Serahkan temuan ke SOP-01 langkah 18 (atau SOP-03 langkah 14 untuk arsip) | F7 | daftar temuan | temuan masuk antrean perbaikan | setiap temuan punya pemilik yang menerima |

## Skrip sesi

### Skrip pembuka (dibacakan F1)

> "Kita akan main satu kasus. Sesi direkam dan ada pengamat yang melihat layar kalian, tapi tidak akan membantu — kalau kalian mentok, itu datanya. Kalian bebas berhenti kapan saja, tinggal bilang. Kalau ada yang terasa aneh atau bikin kesal, sebut saja saat itu, jangan ditahan sampai akhir."

### Daftar pertanyaan wawancara (5 menit, per pemain)

1. Bagian mana yang paling lama terasa menunggu?
2. Ada momen di mana kamu tidak tahu harus berbuat apa? Di menit keberapa?
3. Kalau kamu berhenti main sekarang, apa alasannya?

Pertanyaan 1 dan 2 memasok konteks untuk idle time; pertanyaan 3 memasok konteks untuk quit point. Ketiganya sengaja terbuka — jangan diganti jadi pertanyaan ya/tidak.

### Instrumen idle time

- `ASUMSI`: idle = **5 detik atau lebih tanpa input bermakna** pada role itu. Tidak ada definisi idle di PRD; §6 dan §12 hanya menetapkan target < 25%. Yang menggantikan: definisi resmi di EXTA-36 (kamus metrik).
- Input bermakna = input yang mengubah state sesi (gerak, periksa objek, drag potongan, buka kartu, tandai kontradiksi). Menatap layar, memutar kamera tanpa tujuan, dan menunggu animasi tidak dihitung.
- idle time dihitung dari event telemetri, bukan dari perasaan pengamat. Pengamat hanya dipakai untuk menjelaskan **sebab** idle, bukan mengukur durasinya.
- idle time dihitung per role, bukan per sesi.
- Gate §17: idle < 25% sesi per role. Angka ini dibandingkan di gate minggu 7.

### Instrumen quit point

- quit point = momen pemain keluar dari sesi sebelum kasus berakhir, dicatat dalam menit sejak sesi dimulai.
- Metrik §12 "quit di 5 menit pertama per role" dibaca dari sini: hitung kejadian keluar dengan menit < 5, dipisah per role.
- Setiap quit point wajib punya satu alasan yang dikatakan pemain (langkah 13 dan pertanyaan 3), bukan dugaan pengamat.

## Definisi selesai

Satu sesi playtest selesai bila:

1. Ada lembar sesi yang memuat jenis sesi, gate yang diuji, `case_id`, varian, daftar perangkat, dan hash commit.
2. Ada rekaman sesi dan timestamp rekaman.
3. Ada 3 lembar observasi terisi dengan timestamp.
4. Ada tabel telemetri dengan 4 event §15 dan angka idle time per role, persentase sesi selesai, serta quit point per role.
5. Ada catatan wawancara ketiga pemain.
6. Ada daftar temuan berkelas dengan pemilik untuk setiap butir.
7. Ada keputusan lulus/tidak terhadap kriteria lulus gate, dengan angka yang disebut.

## Failure modes

| Kalau ini gagal | Gejala | Yang dilakukan |
| --- | --- | --- |
| Telemetri tidak merekam idle time | gate minggu 7 tidak bisa dinilai; sesi terbuang | batalkan sesi sebelum dimulai bila langkah 2 tidak lulus; jangan jalankan sesi tanpa instrumen |
| Pengamat ikut membantu pemain | hasil jadi tidak menggambarkan pemain nyata | buang sesi itu untuk keperluan gate, catat sebagai sesi latihan; ulangi |
| Hanya satu pengamat untuk tiga role | idle time per role tidak terukur | ulangi sesi satu role per sesi; jangan gabungkan pengamatan |
| Pemain semua dari dalam tim pada playtest minggu 7 | §17 meminta 3 pemain nyata; hasil tidak sah untuk gate | jadwalkan ulang dengan pemain luar tim; catat sebagai temuan proses |
| Temuan tanpa timestamp | tidak bisa dipotong dari rekaman; tidak bisa diperbaiki | kembalikan ke pengamat; temuan tanpa timestamp tidak masuk daftar |
| Temuan tanpa kelas | tidak ada dasar memutuskan apa yang harus diperbaiki lebih dulu | tetapkan kelas sebelum menyerahkan (langkah 20) |
| Varian kasus tidak tercatat | hasil sesi tidak bisa dibandingkan antar sesi | catat varian di lembar sesi sebelum sesi mulai (langkah 6) |
| Semua sesi "lulus" tanpa temuan | instrumennya yang gagal, bukan produknya yang sempurna | periksa ulang langkah 2 dan langkah 10; ulangi sesi |
| Sesi berjalan lewat waktu jauh dari 15-30 menit (§1) | sesi tidak mewakili target pengalaman | catat sebagai temuan mayor; jangan potong sesi di tengah karena itu menghapus data quit point |
| Pemain keluar tapi alasannya tidak ditanya | quit point jadi angka tanpa sebab, tidak bisa diperbaiki | jalankan pertanyaan 3 sebelum pemain pergi; bila sudah pergi, tandai alasan sebagai tidak diketahui — jangan diisi dugaan |

## Pemilik

Rafael — COO.
