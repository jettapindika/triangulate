# Instruksi wakeup: pengingat gate roadmap

Dipakai sebagai `--instruction-file` pada `multica issue wakeup create`
(lihat `docs/automation-spec.md` §4). Pemicu: cron mingguan.

---

Jalankan pengingat gate roadmap Triangulate (PRD §17).

Langkah:

1. `tools/roadmap-gate.sh --date <tanggal hari ini> --parent EXTA-31`
2. Kalau skrip keluar dengan status 1 dan pesan "anchor minggu 0 belum
   diisi": laporkan satu baris bahwa `docs/roadmap.json` belum punya
   `start_date`, dan berhenti. Jangan menebak tanggal mulai.
3. Kalau berhasil: tempel keluaran skrip apa adanya sebagai komentar di issue
   ini.

Aturan:

- Kolom verdict gate sengaja kosong. Jangan mengisinya. Gate minggu 0 ("drag
  halus di mobile") dan minggu 6 ("playtest internal") tidak bisa dinilai dari
  board.
- Jangan mengubah status issue apa pun, termasuk EXTA-31 dan sub-issuenya.
- Jangan menyebut siapa pun dengan mention. Follower issue sudah melihat
  komentarnya.
- Jangan mengubah `docs/roadmap.json` kecuali owner memintanya di issue.
