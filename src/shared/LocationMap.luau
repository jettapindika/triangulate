--!strict
-- Peta lokasi dan arah kompas (PRD §7).
--
-- PRD §7: "Target Marker: Handler menaruh ikon target yang muncul di HUD
-- Searcher dan arah kompas." Arah kompas butuh dua titik: dari mana, dan ke
-- mana. Titik "ke mana" adalah anchor node target; titik "dari mana" adalah
-- titik masuk lokasi.
--
-- ASUMSI YANG PERLU DIBACA SEBELUM MEMAKAI ANGKA DI BAWAH
--
-- Lokasi 3D-nya BELUM ADA. Tidak ada Instance, tidak ada part, tidak ada
-- geometri di repo ini -- PRD §17 menempatkan "lokasi, objek + kunci" di minggu
-- 2, dan sampai sekarang yang dibangun baru meja puzzle. Karena itu anchor di
-- sini adalah KOORDINAT PLACEHOLDER pada bidang ternormalisasi (x = timur,
-- y = utara, rentang 0..1), ditulis supaya kompas bisa dihitung dan diuji
-- sekarang, bukan supaya cocok dengan denah yang belum digambar.
--
-- Ini pola yang sama dengan `Table.SHEET = "rbxassetid://0"` di
-- `src/client/Table/init.luau`: satu konstanta yang diganti saat aset nyata
-- ada, dan tidak ada bagian lain yang perlu berubah.
--
-- Yang TIDAK berubah saat denah nyata datang: bentuk API modul ini. Yang
-- berubah hanya isi tabel `ANCHORS` dan `ENTRIES`, plus titik "dari mana" yang
-- nanti diisi posisi Searcher yang sebenarnya, bukan titik masuk.
--
-- Modul ini murni: tidak menyentuh global Roblox, sehingga bisa diuji dari CLI.

local LocationMap = {}

export type Point = { x: number, y: number }

-- Titik masuk tiap lokasi: tempat Searcher mulai menjelajah. Dipakai sebagai
-- titik asal kompas selama belum ada kanal posisi pemain.
local ENTRIES: { [string]: Point } = {
	gallery = { x = 0.5, y = 0.05 },
	agency_hq = { x = 0.5, y = 0.08 },
	kersana_workshop = { x = 0.1, y = 0.5 },
}

-- Anchor node di dalam lokasi. Kunci pertama adalah `location` pada data kasus,
-- kunci kedua adalah id node objek.
local ANCHORS: { [string]: { [string]: Point } } = {
	gallery = {
		obj_schedule = { x = 0.22, y = 0.30 },
		obj_shift_note = { x = 0.74, y = 0.26 },
		obj_access_card = { x = 0.18, y = 0.62 },
		obj_door_log = { x = 0.80, y = 0.58 },
		obj_photo_stack = { x = 0.50, y = 0.46 },
		obj_debt_letter = { x = 0.62, y = 0.80 },
		obj_ledger = { x = 0.34, y = 0.86 },
	},
	agency_hq = {
		obj_buku_tamu = { x = 0.24, y = 0.34 },
		obj_slot_pena = { x = 0.52, y = 0.30 },
		obj_kotak_titipan = { x = 0.78, y = 0.66 },
	},
	kersana_workshop = {
		obj_buku_pesanan = { x = 0.30, y = 0.72 },
		obj_kartu_akses = { x = 0.16, y = 0.22 },
		obj_meja_kerja = { x = 0.48, y = 0.44 },
		obj_kotak_alat = { x = 0.36, y = 0.24 },
		obj_rak_gudang = { x = 0.78, y = 0.34 },
		obj_buku_besar = { x = 0.70, y = 0.78 },
		obj_rak_gudang_bowo = { x = 0.78, y = 0.34 },
		obj_buku_besar_bowo = { x = 0.70, y = 0.78 },
	},
}

function LocationMap.entry(location: string): Point?
	return ENTRIES[location]
end

function LocationMap.anchor(location: string, nodeId: string): Point?
	local byNode = ANCHORS[location]
	if byNode == nil then
		return nil
	end
	return byNode[nodeId]
end

--[[
	Arah dari `from` ke `to`, dalam derajat: 0 = utara, 90 = timur, searah jarum
	jam. `y` bertambah ke utara dan `x` bertambah ke timur, jadi sudut dihitung
	dari sumbu y dengan `atan2(dx, dy)`.

	Mengembalikan nil bila salah satu titik tidak ada. Pemanggil memperlakukan
	nil sebagai "jangan kirim bearing" -- lebih jujur daripada mengirim 0 yang
	terbaca sebagai "tepat di utara".
]]
function LocationMap.bearing(from: Point?, to: Point?): number?
	if from == nil or to == nil then
		return nil
	end

	local dx = to.x - from.x
	local dy = to.y - from.y
	if dx == 0 and dy == 0 then
		-- Titik asal dan tujuan berimpit: arah tidak terdefinisi.
		return nil
	end

	local degrees = math.deg(math.atan2(dx, dy))
	if degrees < 0 then
		degrees += 360
	end
	return degrees
end

--[[
	Arah dari titik masuk lokasi ke sebuah node. Ini yang dipakai server untuk
	mengisi field `bearing` pada view `target_marker`.

	Selama belum ada kanal posisi pemain, kompas bersifat utara-tetap: arahnya
	relatif terhadap denah, bukan terhadap hadapan Searcher. Begitu posisi
	live ada, fungsi ini yang dipanggil dengan posisi itu sebagai `from`, dan
	bentuk payload-nya tidak berubah.
]]
function LocationMap.bearingFromEntry(location: string, nodeId: string): number?
	return LocationMap.bearing(LocationMap.entry(location), LocationMap.anchor(location, nodeId))
end

return LocationMap
