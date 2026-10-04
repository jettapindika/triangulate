--!strict
-- Uji layanan lokasi: objek, mini-aksi, dan gerbang kunci (PRD §4, §6, §15).
--
-- Semua yang diuji di sini murni: tidak ada `Instance`, tidak ada `Workspace`.
-- Itu yang membuat aturan "objek mana yang boleh diperiksa dan kapan" bisa
-- dibuktikan dari CLI, bukan dari Studio.

local Harness = require("./harness")
local LocationService = require("../src/server/LocationService")

local ACTIONS = {
	{ id = "uv", label = "Senter UV", hold_seconds = 0 },
	{ id = "drawer", label = "Buka laci (tahan)", hold_seconds = 1.2 },
	{ id = "lockpick", label = "Lockpick sederhana (tahan)", hold_seconds = 2.5 },
}

-- Jam yang bisa digerakkan. Inilah alasan `clock` disuntik: durasi "tahan"
-- tidak boleh diuji dengan menunggu detik nyata.
local now = 0
local function clock(): number
	return now
end

local NODES = {
	{
		id = "obj_schedule",
		type = "object",
		label = "Sobekan jadwal di ruang staf",
		gives_key = "key_a",
	},
	{
		id = "obj_access_card",
		type = "object",
		label = "Kartu akses di loker",
		gives_key = "key_b",
	},
	{
		id = "obj_ledger",
		type = "object",
		label = "Buku kas tersembunyi",
		variants = { "v_curator" },
		gives_key = "key_ledger",
	},
	{ id = "obj_behind_deduction", type = "object", label = "Buku kas kedua", gives_key = "key_c" },
	{
		id = "ev_schedule",
		type = "evidence",
		label = "Jadwal",
		puzzle = "torn_doc",
		needs = { "key_a" },
	},
	-- PRD §4 langkah 6: "Deduksi menaruh pinpoint baru di map dan membuka target
	-- baru." Node ini yang membuka `obj_ledger`, dan `obj_ledger` ada di
	-- `REACHABLE` -- persis seperti `obj_ledger` di `gallery_01`, yang tercapai
	-- secara graf sejak sesi mulai tetapi baru boleh diperiksa setelah
	-- `ded_c_culprit_1` selesai.
	{
		id = "ded_open_ledger",
		type = "deduction",
		label = "Kurator memegang buku kas",
		needs = { "clue_a", "clue_b" },
		unlocks = { "obj_ledger" },
		variants = { "v_curator" },
	},
	-- Gerbang milik cabang LAIN. Kalau ia ikut dihitung pada varian `v_curator`,
	-- objeknya akan terkunci selamanya: deduksi ini tidak akan pernah selesai di
	-- sesi itu.
	{
		id = "ded_guard_only",
		type = "deduction",
		label = "Satpam memegang kartu akses",
		needs = { "clue_c" },
		unlocks = { "obj_access_card" },
		variants = { "v_guard" },
	},
}

-- `obj_behind_deduction` aktif tapi BELUM tercapai: hanya bisa dicapai setelah
-- sebuah deduksi selesai (`CaseGraph.reachable`). Ia harus ada di lokasi tetapi
-- tidak boleh bisa diperiksa.
local REACHABLE: { [string]: boolean } = {
	obj_schedule = true,
	obj_access_card = true,
	obj_ledger = true,
}

local function newService(variantId: string?)
	return LocationService.new({
		location = "gallery",
		nodes = NODES,
		reachableIds = REACHABLE,
		actions = ACTIONS,
		clock = clock,
		variantId = variantId,
	})
end

Harness.suite("LocationService: objek di lokasi")

local service = newService("v_curator")
Harness.equal(#service.order, 3, "hanya node object yang jadi objek di lokasi")
Harness.check(service.objects.obj_schedule ~= nil, "objek tercapai ada di lokasi")
Harness.check(service.objects.ev_schedule == nil, "node bukti bukan objek di lokasi")

-- PRD §10: node ber-`variants` hanya hidup di cabangnya. Objek cabang lain
-- tidak boleh muncul di lokasi, karena memeriksanya akan memberi kunci yang
-- tidak dipakai apa pun pada sesi ini.
local guardService = newService("v_guard")
Harness.check(guardService.objects.obj_ledger == nil, "objek cabang lain tidak ada di lokasi")

Harness.suite("LocationService: mini-aksi")

-- PRD §6: "mini-aksi (senter UV, buka laci dengan hold, lockpick sederhana)".
local seen: { [string]: boolean } = {}
for _, objectId in service.order do
	seen[service.objects[objectId].action] = true
end
local distinct = 0
for _ in seen do
	distinct += 1
end
Harness.check(distinct >= 2, "mini-aksi tidak seragam untuk semua objek")

local action = LocationService.actionFor(service, "obj_schedule")
Harness.check(action ~= nil, "objek punya mini-aksi")
Harness.equal(
	LocationService.actionFor(service, "tidak_ada"),
	nil,
	"objek tak dikenal tidak punya mini-aksi"
)

-- Deterministik: dua kali bangun dengan data yang sama memberi aksi yang sama.
local rebuilt = newService("v_curator")
local same = true
for _, objectId in service.order do
	if service.objects[objectId].action ~= rebuilt.objects[objectId].action then
		same = false
	end
end
Harness.check(same, "penetapan mini-aksi deterministik")

Harness.suite("LocationService: gerbang pemeriksaan")

-- PRD §4/§15: keputusan "boleh diperiksa" ada di server. Tiga penolakan yang
-- harus nyata: objek tak dikenal, objek di luar jangkauan rantai, dan aksi yang
-- tidak cocok.
local okUnknown, whyUnknown = LocationService.beginInspect(service, 1, "tidak_ada", "uv")
Harness.check(not okUnknown, "objek tak dikenal ditolak")
Harness.equal(whyUnknown, "objek tidak ada di lokasi", "alasan penolakan objek tak dikenal")

local okFar, whyFar = LocationService.beginInspect(service, 1, "obj_behind_deduction", "uv")
Harness.check(not okFar, "objek yang belum tercapai ditolak")
Harness.equal(whyFar, "objek belum bisa dicapai", "alasan penolakan objek belum tercapai")

local scheduleAction = service.objects.obj_schedule.action
local wrongAction = if scheduleAction == "uv" then "drawer" else "uv"
local okWrong, whyWrong = LocationService.beginInspect(service, 1, "obj_schedule", wrongAction)
Harness.check(not okWrong, "aksi yang tidak cocok ditolak")
Harness.equal(whyWrong, "aksi tidak cocok", "alasan penolakan aksi tidak cocok")

Harness.suite("LocationService: aksi tahan butuh durasi")

-- Objek uji dipilih dari aksi yang benar-benar butuh tahan, bukan dari id
-- tertentu: penetapan mini-aksi bergiliran menurut urutan data kasus, jadi
-- mengunci uji ke satu id akan patah begitu `gallery_01` menambah objek.
local holdObjectId: string? = nil
local holdActionId: string? = nil
local holdSeconds = 0
for _, objectId in service.order do
	local object = service.objects[objectId]
	local candidate = service.actions[object.action]
	if candidate ~= nil and candidate.hold_seconds > 0 then
		holdObjectId = objectId
		holdActionId = candidate.id
		holdSeconds = candidate.hold_seconds
		break
	end
end
Harness.check(holdObjectId ~= nil, "lokasi punya minimal satu objek dengan aksi tahan")

now = 0
local held =
	LocationService.beginInspect(service, 7, holdObjectId :: string, holdActionId :: string)
Harness.check(held, "aksi yang cocok diterima")

local tooEarly, earlyWhy = LocationService.completeInspect(service, 7, holdObjectId :: string)
Harness.check(not tooEarly, "aksi tahan belum selesai sebelum durasinya")
Harness.equal(earlyWhy, "aksi belum selesai", "alasan penolakan aksi belum selesai")

-- Melepaskan jari membatalkan tahan.
LocationService.cancelInspect(service, 7)
local afterCancel, cancelWhy = LocationService.completeInspect(service, 7, holdObjectId :: string)
Harness.check(not afterCancel, "aksi yang dibatalkan tidak bisa diselesaikan")
Harness.equal(cancelWhy, "tidak ada aksi berjalan", "alasan penolakan tanpa aksi berjalan")

-- Aksi dengan `hold_seconds = 0` selesai seketika; yang butuh durasi menunggu
-- jam yang disuntik, bukan waktu nyata.
now = 0
LocationService.beginInspect(service, 7, holdObjectId :: string, holdActionId :: string)
now = holdSeconds - 0.1
local stillEarly = LocationService.completeInspect(service, 7, holdObjectId :: string)
Harness.check(not stillEarly, "0,1 detik sebelum durasi masih ditolak")

now = holdSeconds
local done, problem, key = LocationService.completeInspect(service, 7, holdObjectId :: string)
Harness.check(done, "aksi selesai setelah durasinya")
Harness.equal(problem, nil, "aksi yang selesai tidak punya masalah")
Harness.equal(key, service.objects[holdObjectId :: string].gives_key, "objek memberi kuncinya")
Harness.check(key ~= nil, "objek uji memberi kunci")

-- PRD §4: "objek memberi kunci". Kunci masuk ke himpunan yang dipegang tim.
Harness.equal(service.keysHeld[key :: string], true, "kunci yang diberikan tercatat")
local otherKey = if key == "key_a" then "key_b" else "key_a"
Harness.equal(service.keysHeld[otherKey], nil, "kunci yang belum diambil tidak tercatat")

Harness.suite("LocationService: satu kunci satu kali")

-- Memeriksa ulang objek yang sudah diperiksa tidak menggandakan kunci dan tidak
-- melempar; ia hanya mengembalikan kunci yang sama.
now = 0
LocationService.beginInspect(service, 7, holdObjectId :: string, holdActionId :: string)
now = holdSeconds
local again, _, againKey = LocationService.completeInspect(service, 7, holdObjectId :: string)
Harness.check(again, "objek yang sudah diperiksa masih bisa diperiksa")
Harness.equal(againKey, key, "kunci yang sama dikembalikan")

Harness.suite("LocationService: objek ambient")

-- PRD §6: "Eksplorasi bebas dengan objek ambient (bukti tambahan opsional)".
-- Ambient ada supaya Searcher punya kerja saat rantai lain menunggu, dan ia
-- TIDAK memberi kunci apa pun.
local ambient = LocationService.ambientFor(service)
Harness.check(#ambient >= 1, "lokasi punya minimal satu objek ambient")
for _, prop in ambient do
	Harness.equal(prop.gives_key, nil, "objek ambient tidak memberi kunci")
	Harness.equal(prop.kind, "ambient", "objek ambient bertanda ambient")
end

local firstAmbient = ambient[1]
local ambientOk = LocationService.beginInspect(service, 7, firstAmbient.id, firstAmbient.action)
Harness.check(ambientOk, "objek ambient bisa diperiksa")

Harness.suite("LocationService: ambient hanya untuk lokasi yang punya")

Harness.equal(#LocationService.ambientFor(LocationService.new({
	location = "lokasi_lain",
	nodes = NODES,
	reachableIds = REACHABLE,
	actions = ACTIONS,
	clock = clock,
})), 0, "lokasi tanpa data ambient tidak dikarang-karang")

Harness.suite("LocationService: gerbang deduksi (unlocks)")

-- PRD §4 langkah 6: deduksi "membuka target baru". `reachable` saja tidak
-- cukup: `obj_ledger` tercapai secara graf sejak sesi mulai, tetapi baru boleh
-- diperiksa setelah `ded_open_ledger` selesai. Tanpa gerbang ini, buku kas
-- tersembunyi bisa dibuka di menit pertama.
local gated = newService("v_curator")
Harness.equal(
	gated.objects.obj_ledger.reachable,
	true,
	"objek bergerbang tetap tercapai secara graf"
)
Harness.equal(
	gated.objects.obj_ledger.gated_by,
	{ "ded_open_ledger" },
	"objek mencatat deduksi yang membukanya"
)
Harness.check(
	not LocationService.isInspectable(gated, "obj_ledger"),
	"objek bergerbang belum boleh diperiksa"
)

local lockedOk, lockedWhy =
	LocationService.beginInspect(gated, 1, "obj_ledger", gated.objects.obj_ledger.action)
Harness.check(not lockedOk, "pemeriksaan objek bergerbang ditolak")
Harness.equal(lockedWhy, "objek belum bisa dicapai", "alasan penolakan objek bergerbang")

-- Gerbang cabang lain tidak dihitung: `ded_guard_only` tidak pernah selesai
-- pada varian `v_curator`, jadi memasukkannya akan mengunci `obj_access_card`
-- selamanya.
Harness.equal(
	gated.objects.obj_access_card.gated_by,
	nil,
	"gerbang dari varian lain tidak dipasang"
)
Harness.check(
	LocationService.isInspectable(gated, "obj_access_card"),
	"objek tanpa gerbang aktif boleh diperiksa"
)

-- Objek tak bergerbang tidak terpengaruh.
Harness.equal(LocationService.available(gated), {
	"obj_schedule",
	"obj_access_card",
}, "hanya objek tanpa gerbang yang tersedia di awal")

local opened = LocationService.completeDeduction(gated, "ded_open_ledger")
Harness.equal(opened, { "obj_ledger" }, "deduksi melaporkan objek yang baru terbuka")
Harness.check(
	LocationService.isInspectable(gated, "obj_ledger"),
	"objek terbuka setelah deduksi selesai"
)

local nowOk = LocationService.beginInspect(gated, 1, "obj_ledger", gated.objects.obj_ledger.action)
Harness.check(nowOk, "pemeriksaan diterima setelah gerbangnya selesai")

-- Deduksi yang tidak membuka apa pun tidak mengubah apa-apa.
Harness.equal(
	LocationService.completeDeduction(gated, "ded_tidak_ada"),
	{},
	"deduksi tanpa gerbang tidak membuka objek"
)
Harness.equal(
	LocationService.completeDeduction(gated, "ded_open_ledger"),
	{},
	"deduksi yang sama dua kali tidak membuka objek lagi"
)

-- Deduksi tanpa node gerbang sama sekali tetap tercatat, dan lokasi tanpa
-- `unlocks` sama sekali tetap berperilaku seperti sebelumnya.
local plain = newService(nil)
Harness.equal(plain.objects.obj_schedule.gated_by, nil, "objek tanpa gerbang tetap nil")

Harness.suite("LocationService: tata letak deterministik")

-- Tata letak diturunkan di kode, bukan dari data kasus: skema kasus tidak punya
-- field posisi dunia (`schema/case.schema.json` menutup properti tambahan), dan
-- menambahkannya berarti mengubah skema untuk urusan yang bukan urusan penulis
-- kasus.
local p1 = LocationService.ringPosition(1, 4, 40)
local p2 = LocationService.ringPosition(1, 4, 40)
Harness.check(p1.x == p2.x and p1.z == p2.z, "posisi cincin deterministik")

local allDistinct = true
local positions: { { x: number, z: number } } = {}
for i = 1, 4 do
	table.insert(positions, LocationService.ringPosition(i, 4, 40))
end
for i = 1, #positions do
	for j = i + 1, #positions do
		local dx = positions[i].x - positions[j].x
		local dz = positions[i].z - positions[j].z
		if dx * dx + dz * dz < 1 then
			allDistinct = false
		end
	end
end
Harness.check(allDistinct, "empat objek tidak bertumpuk di satu titik")

local placed = true
for _, objectId in service.order do
	local object = service.objects[objectId]
	if object.position == nil or object.position.x == nil then
		placed = false
	end
end
Harness.check(placed, "setiap objek di lokasi punya posisi")

Harness.finish("location")
