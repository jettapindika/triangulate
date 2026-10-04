# Rencana spike minggu 0

PRD §17 minggu 0: *"Spike teknis: resolusi gambar, replikasi drag di mobile,
ping wheel prototipe"* dengan gate *"Drag halus di mobile, puzzle tidak blur"*.

**Status dokumen ini: rencana, bukan hasil.** Belum ada satu pun spike di bawah
yang dijalankan. Lingkungan tempat scaffold ini dibuat tidak punya Roblox Studio
dan tidak punya perangkat mobile, jadi seluruh angka di kolom "hasil" masih
kosong dan memang harus diisi di Studio.

Aturan mainnya: **tiap spike punya ambang lulus/gagal yang ditetapkan sebelum
pengukuran.** Kalau ambangnya ditentukan setelah melihat hasil, spike-nya tidak
membuktikan apa pun.

Basis temuan: laporan riset sumber primer yang dirujuk per klaim di bawah.

---

## Kenapa minggu 0 ada

PRD §18 mencantumkan dua risiko yang tidak bisa dimitigasi dengan menulis kode
lebih banyak:

| Risiko (PRD §18) | Mitigasi (PRD §18) | Spike |
|---|---|---|
| Puzzle blur di mobile | Spike minggu 0, fallback sheet kecil | S0.1 |
| (implisit) drag tidak nyaman di mobile | — | S0.2 |
| Komunikasi buruk tanpa voice | Ping wheel, Report Card, Table Preview | S0.3 |

Dan satu lagi dari PRD §15: *"Gambar puzzle: jangan asumsi satu gambar raksasa.
Platform bisa menurunkan resolusi texture besar"*. Ini bukan kekhawatiran
teoretis — lihat S0.1.

**Kenapa harus minggu 0 dan bukan nanti:** ketiga spike ini menentukan bentuk
aset (S0.1), bentuk kontrol (S0.2), dan bentuk UI (S0.3). Kalau dijalankan di
minggu 3, aset dan UI yang sudah dibuat harus dibongkar. PRD §17 sudah
menempatkannya paling awal; dokumen ini mengisi isinya.

---

## S0.1 — Resolusi gambar dan `ImageRectOffset`/`ImageRectSize`

**Pertanyaan:** berapa resolusi sheet bukti terbesar yang masih tajam di
perangkat mobile kelas bawah, dan apakah pemotongan lewat
`ImageRectOffset`/`ImageRectSize` menimbulkan artefak tepi?

**Kenapa dipertanyakan.** Dokumentasi resmi `ImageRectSize` hanya
mendefinisikan kasus nilai `0`: *"If either dimension is set to `0`, the entire
image is displayed instead."* Perilaku lain — termasuk bila rect melebihi ukuran
gambar sumber — tidak didokumentasikan
(https://create.roblox.com/docs/reference/engine/classes/ImageLabel).

Yang **sudah** terdokumentasi lewat laporan staf:

- **Bleeding tepi adalah konsekuensi sampling bilinear, bukan bug.** Staf Roblox
  `@Tiffblocks`, 2019-01-14: *"in order for spritesheet rendering to work well,
  you need to add padding around each sprite. Otherwise, the linear blending
  will cause bleeding from surrounding pixels when rendered upscaled or
  downscaled."* → https://devforum.roblox.com/t/imagerectoffsetsize-issues/224476
  Mekanismenya: *"The pixels get sampled from the center."*
- **Jitter 1 px muncul kalau dimensi sheet tidak habis dibagi grid.** Kasus
  terukur: sheet 799×999 untuk grid 800×1000 menyebabkan *"each frame to move
  ~0.25 pixels"* → https://devforum.roblox.com/t/need-help-to-fix-shaking-in-sprite-sheet-using-imagerectoffset/1603967
- **`ResampleMode = Pixelated` hanya untuk pembesaran.** Staf `@0xabcdef1234`,
  2021-08-16: nearest neighbor *"can result in aliasing and shimmering during
  size reduction, so we suggest you always use the Default ResampleMode, unless
  you specifically want a pixelated effect during the magnification of an
  image."* → https://devforum.roblox.com/t/resamplemode-new-property-for-image-gui-objects/1418681
- **UI 2D tidak masuk texture streaming.** Status "2D UI Textures" adalah Work in
  Progress, dan `ImageLabel` tidak ada di daftar instance yang didukung
  → https://devforum.roblox.com/t/introducing-texture-streaming/4144855
- **Kompresi di mobile diakui dan tidak akan segera diperbaiki.** Staf
  `@m0bsterlobster`, 2025-07-01: kompresi tekstur *"inherently lossy and, in its
  current implementation, unavoidable for performance on certain platforms"*,
  dan *"we currently do not have specific work planned to directly address this
  particular artifact."* → https://devforum.roblox.com/t/compression-of-pixelated-imagelabels-on-mobile-unavoidably-ruins-our-games-aesthetic-graphics/2506241

**Konsekuensi yang harus diuji, bukan diasumsikan:** kalau kompresi mobile tidak
bisa dihindari, pertanyaannya berubah dari "bagaimana supaya tidak blur" menjadi
**"pada ukuran dan gaya gambar seperti apa, blur itu tidak merusak puzzle?"**
Itu pertanyaan yang bisa dijawab spike ini.

### Metode

1. Siapkan tiga sheet, semuanya untuk grid 4×4 (16 potongan, sesuai ukuran
   puzzle yang masuk akal untuk PRD §4):
   - **A** — 1024×1024, ilustrasi flat berwarna solid, gutter 1 px di sekeliling
     tiap sel;
   - **B** — 1024×1024, ilustrasi bergradasi/detail halus, gutter 1 px;
   - **C** — 1024×1024, sama seperti A tetapi **tanpa** gutter.
   Ukuran 1024 dipilih karena itu plafon praktis yang dilaporkan komunitas
   untuk aset gambar, dan karena sheet 1024×1024 dengan grid 4×4 memberi sel
   256×256 — cukup besar untuk dinilai mata.
2. Render tiap sheet sebagai 16 `ImageLabel` yang dipotong lewat
   `ImageRectOffset`/`ImageRectSize`, disusun membentuk gambar utuh.
3. Uji di tiga kelas perangkat: Android kelas bawah (< 3,5 GB, kelas yang di
   laporan texture streaming disebut *"Low-end Android [< 3.5GB] [4k textures
   disabled]"* → https://devforum.roblox.com/t/introducing-texture-streaming/4144855),
   Android/iPhone kelas menengah, dan PC sebagai kontrol.
4. Untuk tiap kombinasi (sheet × perangkat), rekam tangkapan layar pada ukuran
   tampil yang realistis, lalu nilai: apakah tepi potongan terlihat bergaris?
   apakah isi potongan masih bisa dicocokkan dengan potongan tetangganya?
5. Ulangi dengan `ResampleMode = Pixelated` dan `Default` untuk melihat apakah
   ada perbedaan yang berarti (diharapkan **tidak** ada pada penurunan skala,
   sesuai peringatan staf di atas).

### Ambang lulus/gagal

| Ukuran | Lulus | Gagal |
|---|---|---|
| Garis tepi (bleeding) pada sheet C | Terlihat jelas, A/B tidak | A/B sama buruknya → gutter tidak menyelesaikan |
| Pencocokan potongan | ≥ 9 dari 10 penguji mencocokkan 4 potongan berturut-turut tanpa ragu | < 7 dari 10 |
| Perbedaan A vs B | A bertahan lebih baik (indikasi gaya flat lebih tahan kompresi) | Tidak ada perbedaan → gaya bukan variabel |
| Waktu render 16 potongan | Tidak ada jank yang terlihat pada perangkat kelas bawah | Jank terlihat |

Kalau **A lulus dan B gagal**: gaya ilustrasi flat masuk ke PRD §19 sebagai
keputusan visual, bukan sekadar preferensi estetika.

Kalau **ketiganya gagal**: jatuh ke fallback PRD §15 — *"satu sheet per bukti
(resolusi sedang), grid terbatas (misal maks 6x6), atau gaya ilustrasi flat yang
tahan downscale."* Perhatikan bahwa fallback itu menurunkan resolusi **per
bukti**, artinya satu potongan = satu gambar utuh, bukan satu sel dari sheet.
Itu menghapus masalah bleeding sepenuhnya dengan mengorbankan jumlah permintaan
aset.

### Yang diukur dan dicatat

Resolusi perangkat, versi klien Roblox, ukuran sheet, ada/tidak gutter,
`ResampleMode`, dan tangkapan layar sebelum/sesudah. Tangkapan layar disimpan
sebagai lampiran hasil spike.

### Perkiraan

`ASUMSI`: 1 hari kerja untuk membuat aset, 0,5 hari untuk menjalankan dan
menilai. Angka ini tidak berasal dari PRD dan tidak ada dasar pengukuran; saya
tulis supaya bisa dibantah.

---

## S0.2 — Replikasi drag di mobile

**Pertanyaan:** bisakah posisi potongan puzzle ditentukan server dan tetap
terasa halus di mobile, sesuai PRD §15?

PRD §15: *"Handler: kamera Scriptable top-down, raycast ke bidang meja, posisi
potongan diatur server dan direplikasi (interpolasi di client agar halus di
mobile)."*

**Kenapa dipertanyakan.** Latensi jaringan yang tipikal: *"Most players on
Roblox game between 100–300 milliseconds of network latency"*
(https://create.roblox.com/docs/projects/client-server). Kalau setiap gerakan
jari menunggu konfirmasi server, potongan akan tertinggal 100–300 ms di belakang
jari. Di layar sentuh, itu terasa rusak, bukan cuma lambat.

Yang **tidak** bisa dikompromikan: server tetap otoritas
(https://create.roblox.com/docs/scripting/security/security-tactics). Jadi
pertanyaannya bukan "server atau client", melainkan **di mana garisnya**.

Hipotesis yang diuji: garis yang benar adalah **prediksi lokal untuk gerakan,
server untuk hasil akhir.** Client menggerakkan potongan secara lokal mengikuti
jari (tanpa menunggu), dan hanya mengirim **satu** pesan saat jari dilepas:
"potongan X mendarat di sel Y". Server memutuskan apakah penempatan itu sah.

Kalau hipotesis ini benar, jumlah pesan remote jadi **satu per potongan yang
ditempatkan**, bukan satu per frame. Ini penting karena throttle remote
*"approximately 500 requests per second, per client"* dan batas itu *"shared
among all remote events of the same type"*
(https://create.roblox.com/docs/reference/engine/classes/RemoteEvent). Drag yang
mengirim satu pesan per frame akan menabrak batas itu.

### Metode

1. Bangun meja top-down di Studio: satu `Part` datar sebagai meja, kamera
   `Scriptable`, raycast dari posisi jari ke bidang meja.
2. 16 potongan sebagai `ImageLabel` di `SurfaceGui` (atau `Part` dengan `Decal`,
   mana yang lebih mulus — itu sendiri bagian dari pengukuran).
3. Implementasikan dua jalur:
   - **Jalur A (naif):** posisi dikirim tiap `RenderStepped` ke server, server
     mengembalikan posisi otoritatif, client menampilkan posisi dari server.
   - **Jalur B (prediksi):** client menggerakkan lokal; satu pesan dikirim saat
     jari dilepas; server memvalidasi penempatan dan mengoreksi bila perlu.
4. Ukur di kedua jalur: pesan per detik, keterlambatan yang dirasakan, dan
   berapa kali koreksi server terlihat.
5. Uji dengan latensi buatan: 100 ms dan 300 ms, ditambah packet loss.

### Ambang lulus/gagal

| Ukuran | Lulus | Gagal |
|---|---|---|
| Pesan remote puncak | < 20/detik saat drag aktif | ≥ 100/detik → mendekati batas throttle |
| Keterlambatan yang dirasakan (jalur B) | Potongan menempel di jari, tidak ada lag yang terlihat | Potongan tertinggal |
| Koreksi server yang terlihat | ≤ 1 per 16 potongan | > 3 → prediksi dan validasi tidak sepakat |
| Jalan di perangkat kelas bawah | Lancar | Jank |

**Kalau jalur B gagal pada ambang "koreksi terlihat"**, artinya validasi server
terlalu ketat atau prediksi client terlalu longgar — dan itu temuan desain yang
berharga, bukan kegagalan teknis. Jalan keluarnya adalah melonggarkan validasi
(server menerima penempatan "dekat cukup" lalu menggeser potongan ke sel
terdekat), bukan memindahkan keputusan ke client.

### Yang diukur dan dicatat

Pesan remote per detik (dari Developer Console), keterlambatan yang dirasakan
(dinilai penguji), jumlah koreksi, dan kelas perangkat.

### Perkiraan

`ASUMSI`: 1,5 hari kerja.

---

## S0.3 — Ping wheel prototipe

**Pertanyaan:** bisakah pemain berkomunikasi tanpa mengetik, dengan satu tangan,
di layar ponsel?

PRD §2 pilar 2: *"Komunikasi tanpa mengetik. Cukup sentuh, tidak harus ketik."*
PRD §7: roda dengan 6–8 frasa yang berubah sesuai role dan situasi.

**Kenapa dipertanyakan.** Ini satu-satunya spike yang tidak punya risiko
platform — tidak ada API yang bisa gagal. Risikonya adalah **UX**, dan itu
justru lebih mahal kalau salah: kalau ping wheel tidak dipakai, seluruh pilar
komunikasi PRD §7 ambruk dan tidak ada rencana B selain text chat, yang PRD §7
sendiri akui bermasalah di mobile (dan PRD §18 mencantumkan *"Komunikasi buruk
tanpa voice"* sebagai risiko).

Yang sudah ada dan **tidak** perlu dibangun ulang: kontrak frasanya.
`src/shared/PingPhrases.luau` sudah mendefinisikan 3 frasa universal
(Setuju / Ragu / Tolong ulangi) dan 4+3+3 frasa per role (Searcher 4, Handler 3,
Director 3), dengan `MAX_PHRASES = 8` sesuai PRD §7. Fungsi `forRole(role)` dan
`isValid(role, phraseId)` sudah diuji.

### Metode

1. Bangun roda sebagai UI touch-first: muncul saat jari menahan di satu area,
   frasa dipilih dengan menggeser ke arah, dilepas untuk mengirim. Ini pola yang
   tidak butuh melihat layar setelah terbiasa — penting karena Searcher sedang
   menjelajah lokasi.
2. Ambang ukuran sentuh: PRD §15 menuntut *"target sentuh besar"*. Uji pada
   ukuran jari nyata, bukan simulasi mouse.
3. Uji tiga hal:
   - **Kecepatan:** berapa lama dari "ingin bilang sesuatu" sampai frasa terkirim?
   - **Akurasi:** berapa kali frasa yang terkirim salah?
   - **Tanpa melihat:** setelah 10 kali pakai, apakah penguji bisa memilih frasa
     yang benar tanpa melihat layar?
4. Uji juga jalur kegagalan: apakah roda menghalangi pandangan saat Searcher
   sedang bergerak? Apakah bisa dibatalkan?

### Ambang lulus/gagal

| Ukuran | Lulus | Gagal |
|---|---|---|
| Waktu kirim | < 1,5 detik | > 3 detik |
| Akurasi | ≥ 9 dari 10 benar | < 7 dari 10 |
| Tanpa melihat | ≥ 8 dari 10 benar | < 6 dari 10 |
| Target sentuh | Tidak ada salah tekan | Sering salah tekan |

**Kalau "tanpa melihat" gagal** sementara dua yang lain lulus: roda tetap
berguna, tetapi ia bukan kanal komunikasi utama dan PRD §7 perlu ditinjau —
mungkin Report Card (yang tidak butuh pilihan sama sekali) yang harus jadi
kanal utama, bukan ping wheel.

### Yang diukur dan dicatat

Waktu, akurasi, dan catatan kualitatif penguji. Kalau ada frasa yang tidak
pernah dipakai, itu sinyal untuk memangkasnya — roda 8 frasa yang 3 di antaranya
mati lebih buruk daripada roda 5 frasa yang semuanya hidup.

### Perkiraan

`ASUMSI`: 1 hari kerja.

---

## Ringkasan minggu 0

| Spike | Gate PRD §17 | Ambang utama | Perkiraan |
|---|---|---|---|
| S0.1 Resolusi gambar | "puzzle tidak blur" | 9/10 penguji cocok tanpa ragu; gaya flat bertahan | 1,5 hari |
| S0.2 Drag mobile | "drag halus di mobile" | < 20 pesan/detik; ≤ 1 koreksi per 16 potongan | 1,5 hari |
| S0.3 Ping wheel | (tidak ada gate eksplisit) | < 1,5 dtk; ≥ 9/10 akurasi | 1 hari |

Total `ASUMSI`: 4 hari kerja. Sisa minggu 0 dipakai untuk menutup temuan dan
memutuskan fallback sebelum minggu 1 mulai membangun meja puzzle.

### Yang harus diputuskan setelah spike

1. Resolusi dan gaya sheet bukti → masuk PRD §19 (arah visual).
2. Garis prediksi/otoritas untuk drag → masuk `docs/arsitektur.md` sebagai
   keputusan, bukan lagi hipotesis.
3. Apakah ping wheel jadi kanal utama → kalau tidak, PRD §7 ditinjau ulang.
4. Durasi timer cleanup (PRD §6 dan §19) — **tidak** diukur di minggu 0; PRD §19
   menempatkan validasinya di playtest minggu 7.

---

## Yang sengaja TIDAK ada di minggu 0

- **`EditableImage` sebagai jalan keluar blur.** Batas kerasnya 1024×1024, satu
  update per frame, budget memori ketat di klien, wajib 13+ dan ID-verified
  dengan opt-in "Enable Mesh / Image APIs", dan dilaporkan tetap terkompresi di
  mobile → https://create.roblox.com/docs/reference/engine/classes/EditableImage,
  https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293.
  Bukan perbaikan gratis; kalau S0.1 gagal total, ini opsi terakhir, bukan
  langkah pertama.
- **Texture streaming sebagai penyelamat UI.** UI 2D belum didukung.
- **Optimasi ukuran berkas gambar.** Memori grafis ditentukan jumlah piksel,
  bukan ukuran berkas: *"the number of pixels in the texture determines memory
  usage. For example, a 1024x1024 pixel texture consumes four times the graphics
  memory of a 512x512 texture."*
  → https://create.roblox.com/docs/performance-optimization/improve
  Jadi mengecilkan berkas tidak menghemat memori; mengecilkan **dimensi** iya.
