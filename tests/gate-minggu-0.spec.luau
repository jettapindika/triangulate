--!strict
-- Bukti gate minggu 0-1 (PRD §17 minggu 0-1, `docs/spike-minggu-0.md`).
--
-- Tiga hal yang diukur di sini, semuanya lewat modul yang benar-benar dipakai
-- game -- bukan salinan tangan:
--
--   1. S0.2 pesan remote per detik: jalur A (satu pesan per frame) vs jalur B
--      (satu pesan saat jari dilepas), terhadap ambang "< 20/detik".
--   2. S0.2 koreksi server per 16 potongan, terhadap ambang "<= 1 per 16".
--   3. Rantai `torn_doc` end to end pada data kasus nyata:
--      `obj_schedule -> ev_schedule -> clue_guard_off`.
--
-- Yang TIDAK bisa diukur di sini dan dinyatakan apa adanya: apakah drag terasa
-- halus di perangkat mobile kelas bawah. Itu butuh perangkat; yang diukur di
-- sini adalah jumlah pesan dan tingkat kesepakatan prediksi client dengan
-- keputusan server, keduanya properti protokol yang bisa dihitung.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")

local Net = require("../src/shared/Net")
local PuzzleTable = require("../src/shared/PuzzleTable")
local PuzzleTableService = require("../src/server/PuzzleTableService")

local FPS = 60
local AMBANG_PESAN = 20
local AMBANG_KOREKSI = 1

local function board(): PuzzleTable.Board
	return PuzzleTable.newBoard(4, 4, 16, 16)
end

local function rng(): () -> number
	local seed = 0
	return function(): number
		seed += 1
		return (seed * 0.37) % 1
	end
end

-- Meja 4x4 yang sudah diacak: 16 potongan, tidak ada yang kebetulan benar.
local function scattered(): PuzzleTable.State
	local regions: { number } = {}
	for index = 0, 15 do
		table.insert(regions, index)
	end
	return PuzzleTable.scatter(
		PuzzleTable.newState("torn_doc:ev_schedule", board(), regions),
		rng()
	)
end

Harness.suite("S0.2: pesan remote per detik")

-- Satu detik drag aktif = 60 frame. Jalur A mengirim tiap frame; jalur B hanya
-- saat jari dilepas, jadi panjang drag tidak menambah pesan sama sekali.
local pesanA = PuzzleTable.remoteMessages("per_frame", FPS, 1)
local pesanB = PuzzleTable.remoteMessages("on_release", FPS, 1)

Harness.equal(pesanA, FPS, "jalur A: satu pesan per frame, jadi tumbuh dengan framerate")
Harness.equal(pesanB, 1, "jalur B: satu pesan per potongan, panjang drag tidak berpengaruh")

-- Ambang lulus/gagal `docs/spike-minggu-0.md` S0.2: lulus < 20/detik, gagal
-- >= 100/detik. Jalur A sudah melewati ambang lulus di 60 fps.
Harness.check(
	pesanA >= AMBANG_PESAN,
	string.format("jalur A gagal ambang (< %d): %d", AMBANG_PESAN, pesanA)
)
Harness.check(
	pesanB < AMBANG_PESAN,
	string.format("jalur B lulus ambang (< %d): %d", AMBANG_PESAN, pesanB)
)

-- Beban terberat jalur B bukan satu potongan, melainkan meja penuh yang
-- dirakit cepat: 16 potongan dalam satu detik.
local puncakB = PuzzleTable.remoteMessages("on_release", FPS, 16)
Harness.equal(puncakB, 16, "meja penuh = 16 pesan, satu per potongan")
Harness.check(
	puncakB < AMBANG_PESAN,
	string.format(
		"bahkan meja penuh selesai dalam 1 detik tetap lulus (%d < %d)",
		puncakB,
		AMBANG_PESAN
	)
)

-- Jalur A pada perangkat kelas bawah yang jatuh ke 30 fps tetap 30 pesan/detik
-- -- masih di atas ambang lulus, dan tidak pernah turun mengikuti jumlah
-- potongan. Itu alasan jalur A ditolak, bukan sekadar angkanya lebih besar.
local pesanA30 = PuzzleTable.remoteMessages("per_frame", 30, 16)
Harness.check(
	pesanA30 >= AMBANG_PESAN,
	string.format("jalur A di 30 fps tetap di atas ambang: %d", pesanA30)
)

Harness.suite("S0.2: koreksi server per 16 potongan")

--[[
	Satu kali drop, dihitung dua sisi:

	  * client -- jalur yang sama dengan `release` di `src/client/Table/init.luau`:
	    `clampNormalized` lalu `normalizedToPoint` lalu `resolveDrop`.
	  * server -- `PuzzleTable.applyDrop`, yang memakai `clampNormalized` yang
	    sama di dalamnya.

	`koreksi` bertambah saat keputusan keduanya berbeda, karena hanya perbedaan
	itulah yang terlihat pemain sebagai potongan melompat.
]]
local function ukurDrop(offsetX: number, offsetY: number): (number, boolean, boolean)
	local serverState = scattered()
	local clientState = scattered()
	local pieceId = serverState.pieces[1].id
	local target = serverState.pieces[1].target

	local u = (target.col + 0.5) / serverState.board.cols + offsetX
	local v = (target.row + 0.5) / serverState.board.rows + offsetY

	-- Sisi server: `applyDrop` menjepit sendiri, jadi u/v mentah diteruskan.
	local serverPayload = PuzzleTable.applyDrop(serverState, pieceId, u, v)

	-- Sisi client.
	local normalized = PuzzleTable.clampNormalized(clientState.board, u, v)
	assert(normalized ~= nil, "probe harus berhingga")
	local point = PuzzleTable.normalizedToPoint(clientState.board, normalized.x, normalized.y)
	local clientCell, clientSnapped =
		PuzzleTable.resolveDrop(clientState.board, point, clientState.pieces[1].pos)

	local clientAccepted = clientCell ~= nil
	local serverAccepted = serverPayload.accepted == true
	local koreksi = 0
	if
		clientAccepted ~= serverAccepted
		or clientSnapped.x ~= serverPayload.x
		or clientSnapped.y ~= serverPayload.y
	then
		koreksi = 1
	end

	return koreksi, clientAccepted, serverState.pieces[1].correct
end

-- Drop tepat di pusat sel tujuan: nol koreksi.
local totalKoreksi = 0
for _ = 1, 16 do
	local koreksi = ukurDrop(0, 0)
	totalKoreksi += koreksi
end
Harness.equal(
	totalKoreksi,
	0,
	"16 drop tepat sasaran: prediksi client sama dengan keputusan server"
)

-- Jari meleset tapi masih di dalam toleransi (SNAP_TOLERANCE = 0.5 sel):
-- potongan tetap menempel ke sel tujuan, tetap nol koreksi.
local koreksiMeleset = 0
for _ = 1, 16 do
	koreksiMeleset += ukurDrop(0.4, -0.4)
end
Harness.equal(
	koreksiMeleset,
	0,
	"16 drop meleset 0.4 sel (masih dalam toleransi): tetap nol koreksi"
)
Harness.check(
	totalKoreksi + koreksiMeleset <= AMBANG_KOREKSI,
	string.format(
		"total koreksi %d <= ambang %d per 16 potongan",
		totalKoreksi + koreksiMeleset,
		AMBANG_KOREKSI
	)
)

-- Kontrol non-vacuous: `accepted` BUKAN `correct`. Drop ke sel yang sah tapi
-- bukan sel tujuan tetap diterima (potongan menempel), tidak dikoreksi, dan
-- TIDAK menyelesaikan meja. Tanpa kontrol ini, "nol koreksi" bisa berarti
-- "server menerima apa saja", bukan "prediksi dan validasi sepakat".
local koreksiSalahSel, acceptedSalahSel, correctSalahSel = ukurDrop(1, 1)
Harness.equal(koreksiSalahSel, 0, "drop ke sel lain yang masih di dalam meja tidak dikoreksi")
Harness.check(acceptedSalahSel, "drop ke sel lain tetap DITERIMA -- aturan snap, bukan solusi")
Harness.check(not correctSalahSel, "tapi potongan itu TIDAK dihitung benar: accepted bukan correct")

-- Drop yang pasti ditolak: client mendeteksinya lokal dan tidak mengirim apa
-- pun, jadi tidak ada koreksi server -- tapi servernya juga menolak.
local serverReject = scattered()
local rejectPayload = PuzzleTable.applyDrop(serverReject, serverReject.pieces[1].id, 0 / 0, 0.5)
Harness.check(rejectPayload.accepted == false, "drop NaN tetap ditolak server")

Harness.suite("rantai torn_doc: obj_schedule -> ev_schedule -> clue_guard_off")

-- Data kasus nyata, bukan fixture karangan: yang diuji di sini adalah rantai
-- pertama PRD §4 pada `data/cases/gallery_01.json`.
local gallery = serde.decode("json", fs.readFile("data/cases/gallery_01.json"))
local load = require("../src/shared/case/CaseLoader").load(gallery, "seed-gate-minggu-0")
assert(load.ok, "gallery_01 harus lolos validator")

local variantId = (load.session :: any).variant_id
Harness.check(
	variantId == "v_curator" or variantId == "v_guard",
	string.format("seed memilih varian yang dikenal: %s", tostring(variantId))
)

local service = PuzzleTableService.new(PuzzleTable)
local built, skipped = PuzzleTableService.build(service, gallery.nodes, variantId, 16, 16, rng())
Harness.equal(#skipped, 0, "tidak ada node bukti bertipe puzzle tak dikenal di gallery_01")

local nodeIds: { string } = {}
for _, entry in built do
	table.insert(nodeIds, entry.node_id)
	PuzzleTableService.register(service, entry)
end
table.sort(nodeIds)
Harness.check(
	table.find(nodeIds, "ev_schedule") ~= nil,
	"meja ev_schedule (torn_doc) terbangun dari data kasus"
)
Harness.check(
	table.find(nodeIds, "obj_schedule") == nil,
	"obj_schedule adalah objek, bukan bukti: ia tidak menghasilkan meja"
)

local entry = PuzzleTableService.get(service, "ev_schedule")
assert(entry ~= nil, "meja ev_schedule harus terdaftar")
Harness.equal(entry.puzzle_type, "torn_doc", "tipe puzzle dibaca dari data kasus")
Harness.equal(#entry.state.pieces, 16, "torn_doc 4x4 = 16 potongan")

-- Merakit seluruh potongan ke sel tujuannya harus menyelesaikan meja. Inilah
-- "satu puzzle selesai" pada gate minggu 0-1, dihitung pada modul yang sama
-- yang dijalankan server.
local lastPayload: { [string]: any }? = nil
for _, piece in entry.state.pieces do
	local u = (piece.target.col + 0.5) / entry.state.board.cols
	local v = (piece.target.row + 0.5) / entry.state.board.rows
	local payload = PuzzleTableService.place(service, "ev_schedule", piece.id, u, v)
	lastPayload = payload
end

Harness.check(entry.solved, "meja ev_schedule selesai setelah 16 potongan dirakit")
Harness.equal(PuzzleTableService.progress(service, "ev_schedule"), 16, "progres meja 16/16")
Harness.check(lastPayload ~= nil and lastPayload.accepted == true, "drop terakhir diterima server")

-- PRD §4 langkah 4: bukti yang selesai menjadi Clue Card. `yields` adalah
-- jembatan dari meja ke clue board, dan isinya dibaca dari data kasus.
Harness.equal(entry.yields, "clue_guard_off", "ev_schedule menghasilkan clue_guard_off")

local clueNode: { [string]: any }? = nil
for _, node in gallery.nodes do
	if node.id == "clue_guard_off" then
		clueNode = node
	end
end
assert(clueNode ~= nil, "clue_guard_off harus ada di data kasus")

-- Bentuk payload Clue Card persis seperti yang dirakit `handlePlacePiece`.
local cluePayload: { [string]: any } = {
	id = clueNode.id,
	title = clueNode.label,
	source = clueNode.source,
}

Harness.equal(cluePayload.title, "Satpam off duty jam 21.00", "judul Clue Card dibaca dari `label`")

-- PRD §4: Clue Card sampai ke clue board Director. Proyeksi per role harus
-- lolos whitelist `Net` -- dan tidak ada role yang menerima `source` kecuali
-- Director, karena `source` menunjuk bukti asal (petunjuk arah bagi Director,
-- bukan bagi role lain).
for _, role in { "Searcher", "Handler", "Director" } do
	local projected = Net.forRole("clue_card", role, cluePayload)
	Harness.check(projected ~= nil, string.format("clue_card sampai ke %s", role))
	if projected ~= nil then
		Harness.equal(
			#Net.findSecrets(projected, string.format("clue_card/%s", role)),
			0,
			string.format("clue_card untuk %s bersih dari field rahasia", role)
		)
	end
end

local forDirector = Net.forRole("clue_card", "Director", cluePayload)
local forHandler = Net.forRole("clue_card", "Handler", cluePayload)
assert(forDirector ~= nil and forHandler ~= nil, "proyeksi kedua role harus ada")
Harness.equal(forDirector.source, "ev_schedule", "Director melihat bukti asal Clue Card")
Harness.equal(forHandler.source, nil, "Handler tidak menerima `source`")

-- Payload meja dan payload penempatan yang menyeberang juga harus bersih.
local statePayload = PuzzleTable.clientPayload(entry.state)
Harness.equal(
	#Net.findSecrets(Net.forRole("puzzle_state", "Handler", statePayload), "puzzle_state"),
	0,
	"puzzle_state bersih dari target/correct"
)
Harness.check(
	#Net.findSecrets(
			Net.forRole("piece_placed", "Handler", lastPayload :: { [string]: any }),
			"piece_placed"
		) == 0,
	"piece_placed bersih dari field rahasia"
)
Harness.finish("gate-minggu-0")
