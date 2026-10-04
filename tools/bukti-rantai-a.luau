--!nonstrict
--[[
	bukti-rantai-a.luau — membuktikan rantai A -> bukti jalan end to end, dan
	membuktikan kasus cacat ditolak sebelum sesi dijalankan (PRD §4, §10, §17
	minggu 2).

	Ini BUKAN uji. Uji yang menjaga kontrak ada di `tests/`. Berkas ini
	menggerakkan modul yang sama yang dijalankan server -- `CaseLoader`,
	`LocationService`, `PuzzleTableService`, `Net` -- dan mencetak satu baris
	berurut per langkah, supaya hasilnya bisa disalin apa adanya sebagai bukti
	issue/PR.

	Jalankan dari akar checkout repo:

		$HOME/.local/roboxtools/lune.d/lune run tools/bukti-rantai-a.luau

	Yang TIDAK dibuktikan di sini dan dinyatakan apa adanya: tampilan di Studio
	dan kehalusan kontrol sentuh. Studio MCP di lingkungan ini adalah jalur mati
	(`docs/mvp-notes.md` §2.3 -- `tools/list` kosong, butuh autentikasi Assistant
	interaktif), jadi bukti yang tersedia adalah log berurut ini plus
	`rojo build` sebagai pemeriksaan struktur. Yang diukur di sini adalah
	keputusan server, dan itu justru bagian yang paling mudah salah.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Net = require("../src/shared/Net")
local PuzzleTable = require("../src/shared/PuzzleTable")
local CaseLoader = require("../src/shared/case/CaseLoader")
local CaseValidator = require("../src/shared/case/CaseValidator")
local LocationService = require("../src/server/LocationService")
local PuzzleTableService = require("../src/server/PuzzleTableService")

local ACTIONS = {
	{ id = "uv", label = "Senter UV", hold_seconds = 0 },
	{ id = "drawer", label = "Buka laci", hold_seconds = 1.2 },
	{ id = "lockpick", label = "Lockpick", hold_seconds = 2.5 },
}

local SEED = "bukti-rantai-a"
local failures = 0

local function step(no: number, text: string): ()
	print(string.format("[%02d] %s", no, text))
end

local function detail(text: string): ()
	print(string.format("     %s", text))
end

local function verdict(ok: boolean, text: string): ()
	print(string.format("     %s %s", if ok then "OK  " else "GAGAL", text))
	if not ok then
		failures += 1
	end
end

-- Jam palsu: durasi tahan diuji tanpa menunggu detik nyata.
local now = 0
local function clock(): number
	return now
end

local function rng(): () -> number
	local seed = 0
	return function(): number
		seed += 1
		return (seed * 0.37) % 1
	end
end

local function readJson(path: string): any
	local ok, decoded = pcall(serde.decode, "json", fs.readFile(path))
	if not ok then
		error(string.format("JSON '%s' tidak bisa dibaca: %s", path, tostring(decoded)))
	end
	return decoded
end

local function findNode(case: any, id: string): any
	for _, node in case.nodes do
		if node.id == id then
			return node
		end
	end
	return nil
end

print(string.rep("=", 76))
print("BUKTI RANTAI A -> BUKTI, END TO END (PRD §4, §10, §17 minggu 2)")
print(string.rep("=", 76))
print("")

-- ---------------------------------------------------------------------------
-- 1. Loader: validasi dulu, lalu pilih varian dari seed (PRD §10)
-- ---------------------------------------------------------------------------

print("--- 1. Loader kasus ---")

local gallery = readJson("data/cases/gallery_01.json")

-- Jalur pertama: validator berdiri sendiri, dipasang sebagai `setValidator` di
-- `CaseSource` (`src/server/CaseSource.luau`). Dijalankan sebelum kasus dibaca.
local validatorOk, validatorProblems = CaseValidator.asLoaderValidator(gallery)
step(1, "CaseValidator.asLoaderValidator(gallery_01)")
verdict(validatorOk, string.format("validator berdiri sendiri: %d masalah", #validatorProblems))

-- Jalur kedua: `CaseLoader.load` -- validasi + pilih varian dari seed.
local load = CaseLoader.load(gallery, SEED)
step(2, string.format("CaseLoader.load(gallery_01, seed='%s')", SEED))
verdict(
	load.ok,
	string.format(
		"ok=%s, error=%d, warning=%d",
		tostring(load.ok),
		#load.report.errors,
		#load.report.warnings
	)
)

local session = load.session
if not load.ok or session == nil then
	print("")
	print("GAGAL: kasus tidak lolos loader; sisa bukti tidak bisa dijalankan.")
	process.exit(1)
end

local variantId = session.variant_id
local variant = session.variant
step(3, "varian dipilih dari seed")
detail(string.format("variant_id = %s", tostring(variantId)))
detail(
	string.format(
		"culprit=%s motive=%s method=%s",
		tostring(variant.culprit),
		tostring(variant.motive),
		tostring(variant.method)
	)
)
verdict(
	variantId == "v_curator" or variantId == "v_guard",
	"seed memilih varian yang memang ada di data"
)
detail(string.format("reachable_node_ids = %d node", #session.reachable_node_ids))
print("")

-- ---------------------------------------------------------------------------
-- 2. Lokasi: objek, mini-aksi, objek ambient (PRD §6)
-- ---------------------------------------------------------------------------

print("--- 2. Lokasi ---")

local reachableIds: { [string]: boolean } = {}
for _, nodeId in session.reachable_node_ids do
	reachableIds[nodeId] = true
end

local location = LocationService.new({
	location = gallery.location,
	nodes = gallery.nodes,
	reachableIds = reachableIds,
	actions = ACTIONS,
	clock = clock,
	variantId = variantId,
})

step(4, string.format("lokasi '%s' dibangun", location.location))
detail(string.format("objek rantai yang bisa diperiksa: %d", #location.order))
for _, objectId in location.order do
	local object = location.objects[objectId]
	detail(
		string.format(
			"  %-18s aksi=%-9s kunci=%-11s pos=(%.1f, %.1f)  %s",
			object.id,
			object.action,
			tostring(object.gives_key),
			object.position.x,
			object.position.z,
			object.label
		)
	)
end

local ambient = LocationService.ambientFor(location)
step(5, string.format("objek ambient: %d (PRD §6)", #ambient))
for _, prop in ambient do
	detail(
		string.format(
			"  %-18s aksi=%-9s kunci=%s  %s",
			prop.id,
			prop.action,
			tostring(prop.gives_key),
			prop.label
		)
	)
end
verdict(#ambient >= 1, "minimal satu objek ambient supaya Searcher punya kerja saat menunggu")
local ambientClean = true
for _, prop in ambient do
	if prop.gives_key ~= nil then
		ambientClean = false
	end
end
verdict(ambientClean, "tidak ada objek ambient yang memberi kunci")
print("")

-- ---------------------------------------------------------------------------
-- 3. Meja bukti: terkunci sampai kuncinya dipegang (PRD §4)
-- ---------------------------------------------------------------------------

print("--- 3. Meja bukti sebelum kunci ---")

local puzzle = PuzzleTableService.new(PuzzleTable)
local built, skipped = PuzzleTableService.build(puzzle, gallery.nodes, variantId, 16, 16, rng())
for _, entry in built do
	PuzzleTableService.register(puzzle, entry)
end

step(6, string.format("meja terbangun: %d (dilewati: %d)", #built, #skipped))
verdict(#skipped == 0, "tidak ada node bukti bertipe puzzle tak dikenal")

local lockedCount = 0
for _, entry in built do
	if
		not PuzzleTableService.isUnlocked(puzzle, entry.node_id, LocationService.keysHeld(location))
	then
		lockedCount += 1
	end
end
step(7, string.format("meja terkunci sebelum ada kunci: %d dari %d", lockedCount, #built))
verdict(
	lockedCount > 0,
	"gerbang kunci nyata: ada meja yang belum bisa disentuh sebelum Searcher bekerja"
)

local before = PuzzleTableService.firstAvailable(puzzle, LocationService.keysHeld(location))
detail(
	string.format(
		"meja tersedia sebelum kunci: %s",
		if before == nil then "(tidak ada)" else before.node_id
	)
)
print("")

-- ---------------------------------------------------------------------------
-- 4. Rantai A: Searcher menemukan objek -> objek memberi kunci (PRD §4 langkah 1-2)
-- ---------------------------------------------------------------------------

print("--- 4. Searcher menemukan objek, objek memberi kunci ---")

-- `obj_schedule` adalah target briefing Searcher di data kasus; ambil dari
-- briefing supaya berkas ini tidak mengunci id yang bisa berubah.
local targetId = gallery.briefings.Searcher.target
step(8, string.format("briefing Searcher menandai target '%s'", targetId))

local target = LocationService.get(location, targetId)
verdict(target ~= nil, string.format("objek '%s' ada di lokasi", targetId))
if target == nil then
	process.exit(1)
end
detail(string.format("label = %s", target.label))
detail(string.format("mini-aksi = %s", target.action))

-- Penolakan yang harus nyata sebelum pemeriksaan yang sah: objek tak dikenal,
-- dan objek yang masih di belakang deduksi.
local unknownOk, unknownWhy = LocationService.beginInspect(location, 1, "obj_tidak_ada", "uv")
verdict(not unknownOk, string.format("objek tak dikenal ditolak: %s", tostring(unknownWhy)))

-- PRD §4 langkah 6: "Deduksi menaruh pinpoint baru di map dan membuka target
-- baru." `reachable` saja tidak cukup -- `obj_ledger` di `gallery_01` tercapai
-- secara graf sejak sesi mulai, tetapi baru boleh diperiksa setelah
-- `ded_c_culprit_1` selesai. Itu yang diuji di sini.
local gatedId: string? = nil
local gateId: string? = nil
for _, objectId in location.order do
	local object = location.objects[objectId]
	if object.gated_by ~= nil then
		gatedId = objectId
		gateId = object.gated_by[1]
	end
end
if gatedId ~= nil and gateId ~= nil then
	local lockedOk, lockedWhy =
		LocationService.beginInspect(location, 1, gatedId, location.objects[gatedId].action)
	verdict(
		not lockedOk,
		string.format(
			"objek bergerbang '%s' (dibuka '%s') ditolak: %s",
			gatedId,
			gateId,
			tostring(lockedWhy)
		)
	)
else
	detail("(tidak ada objek bergerbang pada varian ini)")
end

-- Pemeriksaan yang sah. `hold_seconds` dihormati server: klaim `complete` yang
-- terlalu cepat ditolak.
now = 0
local started = LocationService.beginInspect(location, 1, targetId, target.action)
verdict(
	started,
	string.format("pemeriksaan '%s' dimulai dengan aksi '%s'", targetId, target.action)
)

local holdSeconds = location.actions[target.action].hold_seconds
if holdSeconds > 0 then
	now = holdSeconds - 0.1
	local early, earlyWhy = LocationService.completeInspect(location, 1, targetId)
	verdict(
		not early,
		string.format("selesai 0,1 dtk terlalu cepat ditolak: %s", tostring(earlyWhy))
	)
	now = holdSeconds
end

local done, problem, key = LocationService.completeInspect(location, 1, targetId)
step(9, string.format("objek '%s' selesai diperiksa", targetId))
verdict(done, string.format("pemeriksaan diterima (masalah: %s)", tostring(problem)))
verdict(key ~= nil, string.format("objek memberi kunci: %s", tostring(key)))
if key == nil then
	process.exit(1)
end
detail(string.format("kunci dipegang tim: %s", tostring(location.keysHeld[key])))
print("")

-- ---------------------------------------------------------------------------
-- 5. Kunci membuka potongan bukti di meja (PRD §4 langkah 3)
-- ---------------------------------------------------------------------------

print("--- 5. Kunci membuka meja ---")

-- Node bukti mana yang menuntut kunci ini. Dibaca dari data kasus, bukan
-- ditulis tangan, supaya berkas ini tidak perlu ikut berubah saat kasus
-- bertambah.
local unlockedNodeId: string? = nil
for _, node in gallery.nodes do
	local kind = node.kind or node.type
	if kind == "evidence" and node.needs ~= nil then
		for _, need in node.needs do
			if need == key and PuzzleTableService.get(puzzle, node.id) ~= nil then
				unlockedNodeId = node.id
			end
		end
	end
end
step(10, string.format("bukti yang menuntut kunci '%s': %s", key, tostring(unlockedNodeId)))
verdict(unlockedNodeId ~= nil, "kunci membuka tepat satu potongan bukti di data kasus")
if unlockedNodeId == nil then
	process.exit(1)
end

local available = PuzzleTableService.firstAvailable(puzzle, LocationService.keysHeld(location))
verdict(
	available ~= nil and available.node_id == unlockedNodeId,
	string.format(
		"meja tersedia sekarang: %s",
		if available == nil then "(tidak ada)" else available.node_id
	)
)
print("")

-- ---------------------------------------------------------------------------
-- 5b. Deduksi membuka objek baru (PRD §4 langkah 6)
-- ---------------------------------------------------------------------------

print("--- 5b. Deduksi membuka objek bergerbang ---")

if gatedId ~= nil and gateId ~= nil then
	local beforeIds = LocationService.available(location)
	local opens = LocationService.completeDeduction(location, gateId)
	step(11, string.format("deduksi '%s' selesai", gateId))
	verdict(
		table.find(opens, gatedId) ~= nil,
		string.format(
			"deduksi membuka objek '%s' (kembalian: %s)",
			gatedId,
			table.concat(opens, ", ")
		)
	)

	local afterOk, afterWhy =
		LocationService.beginInspect(location, 1, gatedId, location.objects[gatedId].action)
	verdict(
		afterOk,
		string.format("objek '%s' bisa diperiksa setelah deduksi: %s", gatedId, tostring(afterWhy))
	)
	local afterIds = LocationService.available(location)
	detail(string.format("objek bisa diperiksa sebelum: %d, sesudah: %d", #beforeIds, #afterIds))

	-- Idempoten: mengulang deduksi yang sama tidak membuka apa pun lagi.
	local repeatOpens = LocationService.completeDeduction(location, gateId)
	verdict(#repeatOpens == 0, "mengulang deduksi yang sama tidak membuka objek dua kali")
else
	detail("(tidak ada objek bergerbang pada varian ini; bagian ini dilewati)")
end
print("")

-- ---------------------------------------------------------------------------
-- 6. Handler menyelesaikan puzzle -> Clue Card lahir (PRD §4 langkah 4)
-- ---------------------------------------------------------------------------

print("--- 6. Handler menyelesaikan puzzle ---")

local entry = PuzzleTableService.get(puzzle, unlockedNodeId)
detail(string.format("tipe puzzle = %s, potongan = %d", entry.puzzle_type, #entry.state.pieces))

local placed = 0
for _, piece in entry.state.pieces do
	local u = (piece.target.col + 0.5) / entry.state.board.cols
	local v = (piece.target.row + 0.5) / entry.state.board.rows
	local payload = PuzzleTableService.place(puzzle, unlockedNodeId, piece.id, u, v)
	if payload ~= nil and payload.accepted == true then
		placed += 1
	end
end

step(12, string.format("potongan terpasang: %d/%d", placed, #entry.state.pieces))
verdict(entry.solved, "meja selesai setelah seluruh potongan dirakit")

local clueNode = findNode(gallery, entry.yields)
step(
	13,
	string.format("bukti '%s' menghasilkan Clue Card '%s'", unlockedNodeId, tostring(entry.yields))
)
verdict(clueNode ~= nil, "node Clue Card ada di data kasus")
if clueNode == nil then
	process.exit(1)
end

-- Bentuk payload persis seperti yang dirakit `handlePlacePiece` di
-- `src/server/init.server.luau`: dibaca dari data kasus, bukan dikarang.
local cluePayload = {
	id = clueNode.id,
	title = clueNode.label,
	source = clueNode.source,
}
detail(string.format("Clue Card: id=%s title=%s", cluePayload.id, cluePayload.title))
print("")

-- ---------------------------------------------------------------------------
-- 7. Clue Card sampai ke clue board Director, tanpa kebocoran (PRD §15)
-- ---------------------------------------------------------------------------

print("--- 7. Proyeksi per role + detektor kebocoran (PRD §15) ---")

local secretHits = 0
for _, role in { "Searcher", "Handler", "Director" } do
	local projected = Net.forRole("clue_card", role, cluePayload)
	if projected == nil then
		verdict(false, string.format("clue_card tidak sampai ke %s", role))
		continue
	end
	local secrets = Net.findSecrets(projected, string.format("clue_card/%s", role))
	if #secrets > 0 then
		secretHits += #secrets
	end
	step(14, string.format("clue_card -> %s", role))
	detail(
		string.format(
			"  id=%s title=%s source=%s",
			tostring(projected.id),
			tostring(projected.title),
			tostring(projected.source)
		)
	)
	verdict(#secrets == 0, string.format("%s bersih dari field rahasia", role))
end

local forDirector = Net.forRole("clue_card", "Director", cluePayload)
local forHandler = Net.forRole("clue_card", "Handler", cluePayload)
verdict(forDirector.source == unlockedNodeId, "Director melihat bukti asal Clue Card")
verdict(forHandler.source == nil, "Handler tidak menerima `source`")

-- Payload meja dan penempatan juga menyeberang; keduanya harus bersih.
local statePayload = PuzzleTable.clientPayload(entry.state)
local stateSecrets =
	Net.findSecrets(Net.forRole("puzzle_state", "Handler", statePayload), "puzzle_state")
verdict(#stateSecrets == 0, "puzzle_state bersih dari target/correct")

-- Keseluruhan `SECRET_FIELDS` diuji sekali lagi terhadap data kasus mentah,
-- sebagai kontrol bahwa detektornya memang bisa menemukan sesuatu.
local caseSecrets = Net.findSecrets(gallery, "gallery_01")
verdict(
	#caseSecrets > 0,
	string.format("kontrol: detektor menemukan %d rahasia di data kasus mentah", #caseSecrets)
)
detail(string.format("total pelanggaran kebocoran di payload yang menyeberang: %d", secretHits))
print("")

-- ---------------------------------------------------------------------------
-- 8. Kasus cacat: loader menolak, sesi tidak jalan (PRD §10)
-- ---------------------------------------------------------------------------

print("--- 8. Kasus cacat ditolak loader ---")

local fixtures = {
	"tests/fixtures/cycle.json",
	"tests/fixtures/dead_end.json",
	"tests/fixtures/key_deductions_too_high.json",
}

for _, path in fixtures do
	local ok, decoded = pcall(readJson, path)
	if not ok then
		verdict(false, string.format("fixture '%s' tidak bisa dibaca", path))
		continue
	end

	local loadOk = CaseLoader.load(decoded, SEED)
	step(15, string.format("%s", path))
	verdict(not loadOk.ok, "loader MENOLAK kasus cacat")
	for _, issue in loadOk.report.errors do
		detail(string.format("  [%s] %s", issue.code, issue.path))
	end
	detail("sesi TIDAK dijalankan (startSession bail di `load.ok == false`)")
end
print("")

-- ---------------------------------------------------------------------------
-- Ringkasan
-- ---------------------------------------------------------------------------

print(string.rep("=", 76))
if failures == 0 then
	print("HASIL: rantai A -> bukti jalan end to end; kasus cacat ditolak; tidak ada kebocoran.")
	print("Jumlah pemeriksaan gagal: 0")
	process.exit(0)
else
	print(string.format("HASIL: %d pemeriksaan GAGAL.", failures))
	process.exit(1)
end
