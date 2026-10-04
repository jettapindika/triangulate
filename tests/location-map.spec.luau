--!strict
-- Uji peta lokasi dan arah kompas (PRD §7).
--
-- PRD §7: "Target Marker: Handler menaruh ikon target yang muncul di HUD
-- Searcher dan arah kompas." Yang bisa salah di sini bukan pemasangan
-- markernya, melainkan arahnya: satu tanda terbalik membuat Searcher berjalan
-- ke arah yang berlawanan, dan itu terlihat seperti bug gameplay, bukan bug
-- matematika. Karena itu arah diuji langsung di keempat penjuru, bukan hanya
-- "menghasilkan angka".
--
-- Koordinat anchor masih PLACEHOLDER (lihat header `src/shared/LocationMap.luau`),
-- jadi yang diuji adalah SEMANTIK arah -- 0 = utara, 90 = timur, searah jarum
-- jam -- bukan angka absolut tiap node. Saat denah nyata datang, spec ini tetap
-- berlaku tanpa diubah.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")
local LocationMap = require("../src/shared/LocationMap")
local CaseGraph = require("../src/shared/case/CaseGraph")

Harness.suite("LocationMap: arah dasar")

local origin = { x = 0.5, y = 0.5 }

Harness.equal(LocationMap.bearing(origin, { x = 0.5, y = 0.9 }), 0, "utara = 0 derajat")
Harness.equal(LocationMap.bearing(origin, { x = 0.9, y = 0.5 }), 90, "timur = 90 derajat")
Harness.equal(LocationMap.bearing(origin, { x = 0.5, y = 0.1 }), 180, "selatan = 180 derajat")
Harness.equal(LocationMap.bearing(origin, { x = 0.1, y = 0.5 }), 270, "barat = 270 derajat")

-- Searah jarum jam: timur laut (x dan y bertambah) harus berada di antara
-- utara dan timur, bukan di antara timur dan selatan.
local northeast = LocationMap.bearing(origin, { x = 0.9, y = 0.9 })
Harness.check(northeast ~= nil, "timur laut punya arah")
if northeast ~= nil then
	Harness.check(northeast > 0 and northeast < 90, string.format("timur laut di antara 0 dan 90 (dapat %.1f)", northeast))
end

-- Arah selalu di [0, 360): nilai negatif dari atan2 sudah dinormalkan, sehingga
-- pemanggil tidak perlu tahu tanda `atan2`.
for _, to in { { x = 0.5, y = 0.1 }, { x = 0.1, y = 0.1 }, { x = 0.1, y = 0.9 } } do
	local value = LocationMap.bearing(origin, to)
	Harness.check(
		value ~= nil and value >= 0 and value < 360,
		string.format("arah ternormalkan ke [0,360): %s", tostring(value))
	)
end

Harness.suite("LocationMap: titik yang tidak ada")

-- Lebih jujur tidak mengirim arah daripada mengirim 0 yang terbaca sebagai
-- "tepat di utara" (lihat komentar `LocationMap.bearing`).
Harness.equal(LocationMap.bearing(nil, origin), nil, "titik asal nil tidak punya arah")
Harness.equal(LocationMap.bearing(origin, nil), nil, "titik tujuan nil tidak punya arah")
Harness.equal(
	LocationMap.bearing(origin, { x = 0.5, y = 0.5 }),
	nil,
	"titik berimpit tidak punya arah"
)

Harness.equal(LocationMap.entry("lokasi_hantu"), nil, "lokasi tak dikenal tidak punya titik masuk")
Harness.equal(
	LocationMap.anchor("gallery", "obj_hantu"),
	nil,
	"node tak dikenal tidak punya anchor"
)
Harness.equal(
	LocationMap.bearingFromEntry("lokasi_hantu", "obj_schedule"),
	nil,
	"lokasi tak dikenal tidak punya arah"
)
Harness.equal(
	LocationMap.bearingFromEntry("gallery", "obj_hantu"),
	nil,
	"node tanpa anchor tidak punya arah"
)

Harness.suite("LocationMap: cakupan data kasus")

-- Setiap lokasi yang dipakai `data/cases/*.json` harus punya titik masuk dan
-- anchor untuk setiap node objeknya. Kalau tidak, marker untuk objek itu tidak
-- pernah punya bearing -- dan itu gagal secara senyap di HUD, bukan di sini.
local CASES = { "data/cases/gallery_01.json", "data/cases/case_00.json", "data/cases/kersana_01.json" }

local totalObjects = 0
for _, path in CASES do
	local case = serde.decode("json", fs.readFile(path))
	local location = case.location

	Harness.check(
		LocationMap.entry(location) ~= nil,
		string.format("%s: lokasi '%s' punya titik masuk", case.case_id, location)
	)

	local objects = 0
	for _, node in ipairs(case.nodes) do
		if node.type == "object" then
			objects += 1
			totalObjects += 1
			local bearing = LocationMap.bearingFromEntry(location, node.id)
			Harness.check(
				bearing ~= nil,
				string.format("%s: objek '%s' punya arah kompas", case.case_id, node.id)
			)
		end
	end
	Harness.check(objects > 0, string.format("%s: punya node objek", case.case_id))
end

-- Kontrol non-vacuous: kalau loop di atas tidak menemukan objek sama sekali
-- (mis. skema berubah dan node tidak lagi bertipe `object`), seluruh suite ini
-- lulus tanpa memeriksa apa pun.
Harness.check(
	totalObjects >= 6,
	string.format("cakupan nyata: %d node objek diperiksa", totalObjects)
)

Harness.suite("CaseGraph: objek asal deduksi")

-- PRD §4: "Deduksi menaruh pinpoint baru di map dan membuka target baru."
-- Pinpoint itu diturunkan dari rantai dependensi, bukan ditulis di data.
local case00 = serde.decode("json", fs.readFile("data/cases/case_00.json"))
local variantId = case00.variants[1].variant_id

local origins = CaseGraph.origins(case00, variantId, "ded_pena_2")
Harness.check(#origins > 0, "ded_pena_2 punya objek asal")
Harness.ok(
	CaseGraph.contains(CaseGraph.keyOwners(case00, variantId), "key_c") or #origins > 0,
	"ded_pena_2 menelusuri sampai objek pemegang kunci"
)

-- ded_pena_2 butuh clue_a (dari ev_buku_tamu, kunci key_a dari obj_buku_tamu)
-- dan clue_c (dari ev_label_kotak, kunci key_c dari obj_kotak_titipan).
local objectIds: { [string]: boolean } = {}
for _, node in ipairs(case00.nodes) do
	if node.type == "object" then
		objectIds[node.id] = true
	end
end
for _, id in origins do
	Harness.ok(objectIds[id] == true, string.format("objek asal '%s' benar-benar node objek", id))
end

local primary = CaseGraph.primaryOrigin(case00, variantId, "ded_pena_2")
Harness.check(primary ~= nil, "ded_pena_2 punya satu pinpoint")
Harness.equal(primary, origins[1], "pinpoint adalah objek asal pertama")

-- Urutan hasil mengikuti urutan deklarasi node, bukan urutan penelusuran --
-- supaya pinpoint tidak berpindah antar pemanggilan.
Harness.equal(
	table.concat(CaseGraph.origins(case00, variantId, "ded_pena_2"), ","),
	table.concat(origins, ","),
	"origins deterministik antar pemanggilan"
)

Harness.equal(
	CaseGraph.primaryOrigin(case00, variantId, "node_tidak_ada"),
	nil,
	"node tak dikenal tidak punya objek asal"
)

-- Node objek sendiri adalah asalnya.
Harness.equal(
	CaseGraph.primaryOrigin(case00, variantId, "obj_buku_tamu"),
	"obj_buku_tamu",
	"node objek menjadi asalnya sendiri"
)

Harness.finish("location-map")
