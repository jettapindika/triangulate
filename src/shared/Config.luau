--!strict
-- Konstanta proyek. Satu-satunya tempat angka gameplay ditulis.
-- Setiap nilai dirujuk dari PRD v0.2 (docs/prd-v0.2.md); jangan menambah
-- angka gameplay di modul lain, supaya tuning hanya menyentuh satu berkas.

local Config = {}

-- PRD §15: "MaxPlayers = 3".
--
-- PENTING: `Players.MaxPlayers` TIDAK dapat diubah dari script. Dokumentasi
-- resminya: "This property can only be set through a specific place's settings
-- on the Creator Dashboard."
-- -> https://create.roblox.com/docs/reference/engine/classes/Players
-- Angka di bawah adalah nilai yang DIHARAPKAN; penegakannya ada di Creator
-- Dashboard (Configure > Places > Access > Maximum Visitor Count). Kode server
-- memverifikasi jumlah pemain terhadap angka ini dan menolak kelebihan, bukan
-- menyetelnya. Lihat `docs/arsitektur.md` bagian "Konfigurasi yang tidak bisa
-- diatur kode".
Config.MAX_PLAYERS = 3

-- PRD §8: timer lobby 45 detik, boleh diperpanjang sampai 90 detik,
-- ready check 10 detik sebelum mulai.
Config.LOBBY_SECONDS = 45
Config.LOBBY_EXTENDED_SECONDS = 90
Config.READY_CHECK_SECONDS = 10

-- PRD §8: AFK 60 detik tanpa input -> NPC mengambil alih role.
-- Disconnect -> slot ditahan 3 menit untuk rejoin.
Config.AFK_SECONDS = 60
Config.REJOIN_HOLD_SECONDS = 180

-- PRD §5: 3 tuduhan per kasus; setelah habis kasus jadi "Cold Case".
-- Feedback salah hanya "X dari 3 benar", tanpa menyebut field mana.
Config.MAX_ACCUSATIONS = 3

-- PRD §5: gerbang N Deduksi Kunci = kira-kira 65% dari total, dibulatkan ke atas.
Config.KEY_DEDUCTIONS = {
	standard = 4,
	daily = 3,
	tutorial = 2,
}

-- PRD §5: minimal satu Kontradiksi harus ditandai sebelum form tuduhan terbuka.
Config.MIN_CONTRADICTIONS = 1

-- PRD §6: batas idle time per role pada playtest.
Config.MAX_IDLE_FRACTION = 0.25

-- PRD §5: tiga field tuduhan. Urutan ini juga urutan di form Director.
Config.ACCUSATION_FIELDS = { "culprit", "motive", "method" }

-- PRD §8: sesi dengan NPC Director dihitung pada rank terpisah.
Config.SEPARATE_RANK_FOR_NPC_DIRECTOR = true

-- PRD §15: meja puzzle Handler, kamera Scriptable top-down dengan raycast ke
-- bidang meja. Angka ini adalah ukuran bidang meja dalam stud; seluruh
-- keputusan snap berjalan dalam satuan sel (`shared/PuzzleTable.luau`), jadi
-- angka ini hanya memetakan sel ke geometri dunia.
--
-- ASUMSI: 16x16 stud berarti 4x4 stud per potongan pada grid 4x4 -- cukup besar
-- untuk jari di layar ponsel pada zoom top-down yang wajar. Belum diukur di
-- perangkat; playtest minggu 7 (PRD §17) yang menentukan angkanya.
Config.TABLE_WIDTH = 16
Config.TABLE_HEIGHT = 16

return Config
