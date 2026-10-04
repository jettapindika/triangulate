# Prompt autopilot: laporan metrik mingguan

Dipakai sebagai `--description` pada `multica autopilot create` (lihat
`docs/automation-spec.md` §3). Mode `create_issue`.

---

Jalankan laporan metrik mingguan Triangulate (PRD §12).

Langkah:

1. `multica repo checkout https://github.com/jettapindika/triangulate`
2. Ekspor event telemetri 7 hari terakhir ke berkas NDJSON. Jalur ekspor ada
   di EXTA-32/EXTA-34 dan belum tersedia — kalau belum ada, jangan mengarang
   data: laporkan di komentar bahwa sumber data belum ada, dan berhenti.
3. `tools/metric-report.py --events <ndjson> --as-of <tanggal hari ini>`
4. Tempel keluaran skrip **apa adanya** ke dalam komentar issue ini. Jangan
   mengubah angka, jangan membulatkan ulang, jangan menambahkan tafsiran.
5. Kalau ada baris ber-verdict `FAIL`, sebutkan baris itu satu per satu di
   akhir komentar tanpa menjelaskan penyebabnya — penyebab adalah pekerjaan
   Rani dan Dewi.

Aturan:

- Skrip ini deterministik. Angka berasal dari skrip, bukan dari penilaianmu.
- Metrik tanpa data muncul sebagai `NO DATA`. Itu bukan nol. Jangan
  menggantinya dengan 0 dan jangan menyimpulkan apa pun darinya.
- Jangan menutup issue ini; owner yang menutup.
- Jangan mengubah `docs/metrics.json` atau `docs/roadmap.json`.
