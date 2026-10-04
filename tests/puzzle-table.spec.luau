--!strict
-- Uji geometri dan protokol meja puzzle (PRD §4, §15, §17 minggu 1).
--
-- Yang diuji di sini adalah bagian drag-and-snap yang paling mudah salah dan
-- paling mahal salahnya: sel mana yang dimaksud jari, kapan potongan menempel,
-- kapan server mengoreksi, dan field apa yang menyeberang ke client. Semuanya
-- matematika dan bentuk payload, jadi semuanya bisa diuji tanpa Studio.
--
-- Yang TIDAK diuji di sini dan memang tidak bisa: apakah drag terasa halus di
-- perangkat mobile. Itu butuh perangkat dan diukur terpisah (S0.2 di
-- `docs/spike-minggu-0.md`).

local Harness = require("./harness")
local PuzzleTable = require("../src/shared/PuzzleTable")

local function board(): PuzzleTable.Board
	return PuzzleTable.newBoard(4, 4, 8, 8)
end

local function solved(): PuzzleTable.State
	return PuzzleTable.newState("torn_doc:ev_schedule", board(), { 0, 1, 2, 3, 4, 5, 6, 7 })
end

Harness.suite("PuzzleTable: newBoard")

Harness.throws(function()
	PuzzleTable.newBoard(7, 4, 8, 8)
end, "cols di atas MAX_GRID ditolak")

Harness.throws(function()
	PuzzleTable.newBoard(0, 4, 8, 8)
end, "cols nol ditolak")

Harness.throws(function()
	PuzzleTable.newBoard(4, 4, 0, 8)
end, "meja tanpa lebar ditolak")

Harness.equal(
	PuzzleTable.newBoard(PuzzleTable.MAX_GRID, PuzzleTable.MAX_GRID, 8, 8).cols,
	6,
	"grid maksimum PRD §15 adalah 6x6"
)

Harness.suite("PuzzleTable: cellAt")

local cells = board()
Harness.equal(PuzzleTable.cellAt(cells, { x = 0.5, y = 0.5 }), { col = 0, row = 0 }, "pusat sel pertama")
Harness.equal(PuzzleTable.cellAt(cells, { x = 3.5, y = 3.5 }), { col = 3, row = 3 }, "pusat sel terakhir")

-- Jari yang keluar meja tidak boleh membuat potongan menghilang: sel dijepit.
local edge = PuzzleTable.cellAt(cells, { x = -5, y = -5 })
Harness.equal(edge, { col = 0, row = 0 }, "titik di kiri-atas meja dijepit ke sel tepi")

local over = PuzzleTable.cellAt(cells, { x = 99, y = 99 })
Harness.equal(over, { col = 3, row = 3 }, "titik di kanan-bawah meja dijepit ke sel tepi")

local _, distanceAtCenter = PuzzleTable.cellAt(cells, { x = 2.5, y = 1.5 })
Harness.near(distanceAtCenter, 0, "jarak di pusat sel adalah nol")

local _, distanceAtCorner = PuzzleTable.cellAt(cells, { x = 1, y = 1 })
Harness.near(distanceAtCorner, math.sqrt(0.5), "jarak di sudut sel adalah setengah diagonal")

Harness.suite("PuzzleTable: resolveDrop")

local _, center = PuzzleTable.cellAt(cells, { x = 0.5, y = 0.5 })
local lastLegal = { x = 2.5, y = 2.5 }

local hitCell, hitPos = PuzzleTable.resolveDrop(cells, { x = 0.5, y = 0.5 }, lastLegal)
Harness.equal(hitCell, { col = 0, row = 0 }, "drop di pusat sel menempel")
Harness.equal(hitPos, { x = 0.5, y = 0.5 }, "posisi hasil snap adalah pusat sel")

-- Toleransi 0.5 sel: meleset sedikit masih menempel, itu yang menjawab catatan
-- fallback S0.2 ("dekat cukup" lalu digeser ke sel terdekat).
local nearCell = PuzzleTable.resolveDrop(cells, { x = 1.45, y = 0.5 }, lastLegal)
Harness.equal(nearCell, { col = 1, row = 0 }, "meleset 0,05 sel masih menempel")

local boundaryCell = PuzzleTable.resolveDrop(cells, { x = 0.99, y = 0.5 }, lastLegal)
Harness.equal(boundaryCell, { col = 0, row = 0 }, "meleset 0,49 sel masih menempel")

-- Di sudut sel jaraknya 0,707 sel, di luar toleransi 0,5: ditolak.
local missCell, missPos = PuzzleTable.resolveDrop(cells, { x = 1, y = 1 }, lastLegal)
Harness.equal(missCell, nil, "drop di sudut sel ditolak")
Harness.equal(missPos, lastLegal, "drop yang ditolak mengembalikan posisi sah terakhir")

local customCell = PuzzleTable.resolveDrop(cells, { x = 1, y = 1 }, lastLegal, 0.75)
Harness.equal(customCell, { col = 1, row = 1 }, "toleransi yang dilonggarkan menerima drop yang sama")

Harness.suite("PuzzleTable: place")

local state = solved()
local _, placedAccepted = PuzzleTable.place(state, "torn_doc:ev_schedule:0", { col = 0, row = 0 }, lastLegal)
Harness.ok(placedAccepted, "menempatkan potongan ke sel tujuannya diterima")

local piece0 = state.pieces[1]
Harness.ok(piece0.correct, "potongan di sel tujuan ditandai correct")
Harness.ok(piece0.placed, "potongan di sel tujuan ditandai placed")

local _, wrongAccepted = PuzzleTable.place(state, "torn_doc:ev_schedule:0", { col = 3, row = 3 }, lastLegal)
Harness.ok(wrongAccepted, "penempatan ke sel lain tetap sah secara aturan")
Harness.check(not piece0.correct, "potongan di sel yang salah TIDAK ditandai correct")
Harness.equal(piece0.cell, { col = 3, row = 3 }, "sel potongan diperbarui")

local _, unknownAccepted = PuzzleTable.place(state, "potongan:hantu", { col = 0, row = 0 }, lastLegal)
Harness.check(not unknownAccepted, "id potongan tak dikenal ditolak")

local _, nilCellAccepted = PuzzleTable.place(state, "torn_doc:ev_schedule:0", nil, lastLegal)
Harness.check(not nilCellAccepted, "drop dengan sel nil ditolak")
Harness.equal(piece0.pos, lastLegal, "drop yang ditolak mengembalikan potongan ke posisi sah terakhir")
Harness.check(not piece0.placed, "drop yang ditolak melepas potongan dari sel")

Harness.suite("PuzzleTable: isSolved dan solvedCount")

Harness.equal(PuzzleTable.solvedCount(solved()), 8, "meja yang baru dibuat sudah lengkap")
Harness.ok(PuzzleTable.isSolved(solved()), "meja yang baru dibuat dianggap selesai")

local broken = solved()
PuzzleTable.place(broken, "torn_doc:ev_schedule:5", { col = 0, row = 0 }, lastLegal)
Harness.equal(PuzzleTable.solvedCount(broken), 7, "satu potongan yang salah menurunkan hitungan")
Harness.check(not PuzzleTable.isSolved(broken), "satu potongan yang salah membuat puzzle belum selesai")

local empty = PuzzleTable.newState("kosong", board(), {})
Harness.check(
	not PuzzleTable.isSolved(empty),
	"meja tanpa potongan TIDAK dianggap selesai"
)

Harness.suite("PuzzleTable: interpolate")

Harness.equal(
	PuzzleTable.interpolate({ x = 0, y = 0 }, { x = 1, y = 0 }, 1, 12),
	{ x = 1, y = 0 },
	"frame panjang tidak melompati sasaran"
)

Harness.equal(
	PuzzleTable.interpolate({ x = 3, y = 4 }, { x = 3, y = 4 }, 0.016, 12),
	{ x = 3, y = 4 },
	"jarak nol langsung menempel ke sasaran"
)

local stepped = PuzzleTable.interpolate({ x = 0, y = 0 }, { x = 1, y = 0 }, 0.05, 12)
Harness.near(stepped.x, 0.6, "satu langkah menempuh pangsa jarak sesuai rate")

-- Konvergen dan tidak pernah melewati sasaran, bahkan dengan dt raksasa.
local cursor = { x = 0, y = 0 }
for _ = 1, 60 do
	cursor = PuzzleTable.interpolate(cursor, { x = 1, y = 0 }, 1 / 60, 12)
end
Harness.near(cursor.x, 1, "interpolasi konvergen ke sasaran", 1e-3)
Harness.check(cursor.x <= 1, "interpolasi tidak melewati sasaran")

Harness.suite("PuzzleTable: payload potongan")

local payload = PuzzleTable.clientPayload(solved())
Harness.equal(
	{ payload.cols, payload.rows, payload.puzzle_id },
	{ 4, 4, "torn_doc:ev_schedule" },
	"payload membawa dimensi dan id puzzle"
)
Harness.equal(#payload.pieces, 8, "payload membawa seluruh potongan")

local pieceKeys: { string } = {}
for key in payload.pieces[1] do
	table.insert(pieceKeys, key)
end
table.sort(pieceKeys)
Harness.equal(
	pieceKeys,
	{ "id", "placed", "region", "x", "y" },
	"payload potongan TIDAK membawa target atau correct"
)

local payloadKeys: { string } = {}
for key in payload do
	table.insert(payloadKeys, key)
end
table.sort(payloadKeys)
Harness.equal(
	payloadKeys,
	{ "cols", "pieces", "puzzle_id", "rows" },
	"payload meja tidak membawa field di luar yang digambar"
)

local placement = PuzzleTable.placementPayload(solved(), "torn_doc:ev_schedule:0", true)
Harness.equal(
	{ placement.piece_id, placement.x, placement.y, placement.accepted },
	{ "torn_doc:ev_schedule:0", 0.5, 0.5, true },
	"payload penempatan membawa posisi otoritatif"
)

local rejected = PuzzleTable.placementPayload(solved(), "tidak:ada", false)
Harness.check(not rejected.accepted, "penempatan untuk potongan tak dikenal ditolak")

Harness.suite("PuzzleTable: normalizedToPoint dan rayPlaneY")

local round = PuzzleTable.pointToNormalized(cells, PuzzleTable.normalizedToPoint(cells, 0.25, 0.75))
Harness.near(round.x, 0.25, "u bolak-balik utuh")
Harness.near(round.y, 0.75, "v bolak-balik utuh")

local rayX, rayZ = PuzzleTable.rayPlaneY(0, 10, 0, 0, -1, 0, 0)
Harness.near(rayX :: number, 0, "sinar tegak lurus mengenai tepat di bawah kamera")
Harness.near(rayZ :: number, 0, "sinar tegak lurus tidak menyimpang di z")

local slantX = PuzzleTable.rayPlaneY(0, 10, 0, 1, -1, 0, 0)
Harness.near(slantX :: number, 10, "sinar miring 45 derajat mengenai bidang pada jarak sesuai")

local parallelX = PuzzleTable.rayPlaneY(0, 10, 0, 1, 0, 0, 0)
Harness.equal(parallelX, nil, "sinar sejajar bidang tidak menghasilkan perpotongan")

local behindX = PuzzleTable.rayPlaneY(0, -5, 0, 0, -1, 0, 0)
Harness.equal(behindX, nil, "bidang di belakang sinar tidak menghasilkan perpotongan")

Harness.suite("PuzzleTable: remoteMessages")

Harness.equal(PuzzleTable.remoteMessages("per_frame", 60, 1), 60, "jalur A mengirim satu pesan per frame")
Harness.equal(PuzzleTable.remoteMessages("on_release", 60, 1), 1, "jalur B mengirim satu pesan per potongan")
Harness.throws(function()
	PuzzleTable.remoteMessages("jalur_tidak_ada", 60, 1)
end, "mode drag tak dikenal ditolak, bukan diam-diam dianggap nol")

Harness.suite("PuzzleTable: gridFor")

Harness.equal({ PuzzleTable.gridFor("torn_doc") }, { 4, 4 }, "torn_doc 4x4")
Harness.equal({ PuzzleTable.gridFor("timeline") }, { 4, 2 }, "timeline 4x2")
Harness.equal({ PuzzleTable.gridFor("cipher") }, { 3, 3 }, "cipher 3x3")
Harness.equal({ PuzzleTable.gridFor("puzzle_hantu") }, { nil, nil }, "tipe tak dikenal -> nil")

for _, puzzleType in { "torn_doc", "timeline", "cipher" } do
	local cols, rows = PuzzleTable.gridFor(puzzleType)
	Harness.check(
		(cols :: number) <= PuzzleTable.MAX_GRID and (rows :: number) <= PuzzleTable.MAX_GRID,
		string.format("grid %s menghormati batas %dx%d PRD §15", puzzleType, PuzzleTable.MAX_GRID, PuzzleTable.MAX_GRID)
	)
end

Harness.suite("PuzzleTable: applyDrop")

-- Meja 4x4 dengan 16 potongan, sama seperti yang diukur S0.1/S0.2.
local function scattered(): PuzzleTable.State
	local seed = 0
	local function rng(): number
		seed += 1
		return (seed * 0.37) % 1
	end
	local regions: { number } = {}
	for index = 0, 15 do
		table.insert(regions, index)
	end
	return PuzzleTable.scatter(
		PuzzleTable.newState("torn_doc:ev_schedule", PuzzleTable.newBoard(4, 4, 8, 8), regions),
		rng
	)
end

local tableState = scattered()
Harness.equal(PuzzleTable.solvedCount(tableState), 0, "meja teracak tidak punya potongan yang sudah benar")

-- Potongan 0 bertarget sel (0,0); pusatnya di ternormalisasi (0.125, 0.125).
local piece0Id = tableState.pieces[1].id
local dropPayload, dropSolved = PuzzleTable.applyDrop(tableState, piece0Id, 0.125, 0.125)
Harness.ok(dropPayload.accepted, "drop tepat di pusat sel tujuan diterima")
Harness.check(not dropSolved, "satu potongan benar belum menyelesaikan puzzle")
Harness.equal(PuzzleTable.solvedCount(tableState), 1, "hitungan potongan benar naik setelah drop diterima")
Harness.near(dropPayload.x :: number, 0.5, "payload membawa posisi otoritatif x")
Harness.near(dropPayload.y :: number, 0.5, "payload membawa posisi otoritatif y")

-- Sudut sel jauhnya 0,707 sel, di luar SNAP_TOLERANCE 0,5.
local beforeX = tableState.pieces[2].pos.x
local missPayload = PuzzleTable.applyDrop(tableState, tableState.pieces[2].id, 0.25, 0.25)
Harness.check(not missPayload.accepted, "drop di sudut sel ditolak")
Harness.near(tableState.pieces[2].pos.x, beforeX, "potongan yang ditolak kembali ke posisi sah terakhirnya")

-- Potongan yang sengaja ditaruh di sel yang salah tetap diterima sebagai
-- penempatan, tetapi tidak dihitung sebagai benar.
local wrongPayload = PuzzleTable.applyDrop(tableState, tableState.pieces[3].id, 0.875, 0.875)
Harness.ok(wrongPayload.accepted, "drop di sel yang bukan tujuan tetap sah secara aturan")
Harness.equal(PuzzleTable.solvedCount(tableState), 1, "drop di sel yang salah tidak dihitung benar")

-- Payload penempatan tidak boleh membawa target atau correct.
local placementKeys: { string } = {}
for key in dropPayload do
	table.insert(placementKeys, key)
end
table.sort(placementKeys)
Harness.equal(
	placementKeys,
	{ "accepted", "piece_id", "placed", "x", "y" },
	"payload penempatan tidak membawa target atau correct"
)

Harness.check(
	not PuzzleTable.applyDrop(tableState, "potongan:hantu", 0.125, 0.125).accepted,
	"drop untuk id potongan tak dikenal ditolak"
)
Harness.check(
	not PuzzleTable.applyDrop(tableState, piece0Id, 0 / 0, 0.125).accepted,
	"drop dengan NaN ditolak, bukan menghasilkan sel yang tampak sah"
)
Harness.check(
	not PuzzleTable.applyDrop(tableState, piece0Id, math.huge, 0.125).accepted,
	"drop dengan infinitas ditolak"
)

-- Jari yang keluar bidang dijepit ke tepi meja, bukan ditolak.
local edgePayload = PuzzleTable.applyDrop(tableState, tableState.pieces[4].id, 2.5, -1.5)
Harness.ok(edgePayload.accepted, "drop di luar bidang dijepit ke sel tepi dan diterima")

-- Menyelesaikan seluruh meja harus menghasilkan solved = true.
local finish = scattered()
local solvedPayload = nil
for _, piece in finish.pieces do
	local target = piece.target
	solvedPayload = PuzzleTable.applyDrop(
		finish,
		piece.id,
		(target.col + 0.5) / finish.board.cols,
		(target.row + 0.5) / finish.board.rows
	)
end
Harness.equal(PuzzleTable.solvedCount(finish), 16, "seluruh 16 potongan bisa diselesaikan lewat applyDrop")
Harness.ok((solvedPayload :: { [string]: any }).accepted, "drop terakhir diterima")
Harness.ok(PuzzleTable.isSolved(finish), "meja selesai setelah seluruh potongan benar")
