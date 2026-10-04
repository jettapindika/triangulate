# Lampiran A: Instrumen playtest

Lampiran untuk [SOP-04](sop-04-playtest.md). Dipakai apa adanya: cetak atau salin formulir di bawah ke lembar kerja sesi.

- Pemilik instrumen: Rani — Data & Metrics Engineer
- Rujukan PRD: §6 (idle time), §12 (metrik), §15 (event telemetri), §17 (gate minggu 6-7)

## A1. Lembar sesi

| Kolom | Isi |
| --- | --- |
| Jenis sesi | internal / verifikasi / 3 pemain nyata |
| Gate yang diuji | minggu 6 / minggu 7 / kasus baru |
| Tanggal dan jam mulai | |
| `case_id` dan varian | |
| Hash commit / versi build | |
| Perangkat peserta | merek, model, OS, jenis (mobile kelas bawah / mobile / PC) |
| Nama peserta dan role | satu baris per peserta |
| Nama pengamat dan role yang diamati | satu baris per pengamat |
| Kondisi akhir sesi | selesai / gagal (Cold Case) / waktu habis / keluar |
| Anomali selama sesi | termasuk intervensi fasilitator bila ada |

## A2. Lembar observasi per role

Satu lembar per role. Satu pengamat satu role.

| Timestamp (mm:ss) | Kejadian yang terlihat | Diduga idle? (ya/tidak) | Ditandai untuk dipotong? |
| --- | --- | --- | --- |
| | | | |
| | | | |
| | | | |

Aturan pengisian:

1. Isi timestamp dari jam yang sama dengan perekam layar.
2. Kolom "diduga idle" hanya dugaan sebab; angka resmi idle time datang dari telemetri.
3. Tandai momen yang ingin dilihat ulang — bukan semua momen.
4. Jangan mencatat dugaan sebab sebagai fakta.

## A3. Kolom quit point

| Timestamp keluar | Role | Menit ke- (sejak sesi mulai) | Alasan yang dikatakan pemain | Masuk 5 menit pertama? |
| --- | --- | --- | --- | --- |
| | | | | |

Aturan: alasan diisi kalimat pemain, bukan rangkuman. Bila alasan tidak sempat ditanya, tulis `tidak diketahui`.

## A4. Tabel telemetri pasca sesi

Diisi dari event §15 (bukan dari lembar observasi). Nama event kanonik menunggu EXTA-36; kolom di bawah adalah empat event yang diminta PRD.

| Metrik | Searcher | Handler | Director | Sumber |
| --- | --- | --- | --- | --- |
| Idle time (% durasi sesi) | | | | event idle time §15 |
| Waktu ke clue pertama | | | | event waktu ke clue pertama §15 |
| Jumlah tuduhan | | | | event tuduhan §15 |
| Quit point (menit ke-) | | | | event quit point §15 |
| Kontradiksi ditandai (ya/tidak) | | | | event tuduhan §15 |

Angka pembanding gate:

| Gate | Angka | Sumber |
| --- | --- | --- |
| Idle time per role | < 25% sesi | §6, §12, §17 |
| Sesi selesai | > 55% | §12, §17 |
| Median waktu tunggu matchmaking | < 60 detik | §12 |
| Sesi gagal start | < 10% | §12 |
| Rata-rata hint per sesi | 1-2 | §12 |
| Menamatkan Case 0 | > 80% | §12 |

## A5. Template temuan

Satu baris satu temuan. Semua kolom wajib terisi sebelum temuan diserahkan (SOP-04 langkah 22).

| ID | Sesi | Timestamp | Role | Kejadian | Kelas | Dugaan sebab | Usul perbaikan | Pemilik | Status | Bukti verifikasi |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T-001 | | | | | blocker / mayor / minor | | | | terbuka / tertutup | |

Definisi kelas:

| Kelas | Arti | Tenggat |
| --- | --- | --- |
| blocker | sesi tidak bisa dilanjutkan atau gate tidak bisa dinilai | diperbaiki sebelum playtest berikutnya |
| mayor | sesi berjalan tetapi pengalaman menyimpang jauh dari target (mis. idle di atas 25%, sesi melewati 30 menit) | masuk antrean perbaikan terdekat |
| minor | mengganggu tetapi tidak mengubah hasil gate | backlog |

## A6. Wawancara pasca sesi

Tiga pertanyaan, tiap pemain, 5 menit:

1. Bagian mana yang paling lama terasa menunggu?
2. Ada momen di mana kamu tidak tahu harus berbuat apa? Di menit keberapa?
3. Kalau kamu berhenti main sekarang, apa alasannya?

Jawaban ditulis apa adanya. Jangan meringkas dan jangan menambahkan tafsir di kolom jawaban — tafsir masuk ke kolom "dugaan sebab" di template temuan.

## A7. Ringkasan hasil sesi

Diisi fasilitator di akhir sesi.

| Butir | Isi |
| --- | --- |
| Idle time per role terhadap gate < 25% | lulus / tidak lulus |
| Sesi selesai terhadap gate > 55% | lulus / tidak lulus |
| Jumlah temuan blocker / mayor / minor | |
| Keputusan terhadap gate | lulus / tidak lulus / perlu sesi ulang |
| Alasan keputusan | sebut angka dan gate |
