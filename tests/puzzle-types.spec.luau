--!strict
-- Uji tiga tipe puzzle bukti MVP end to end di meja Handler (PRD §4, §17).
--
-- PRD §4 menetapkan tiga tipe puzzle bukti untuk MVP -- `torn_doc`, `timeline`,
-- `cipher` -- dan PRD §17 minggu 1 menaruh gate "bisa selesai 1 puzzle di
-- mobile". Sampai issue ini, hanya `torn_doc` yang pernah dirangkai end to end
-- (lihat `tests/gate-minggu-0.spec.luau`); `timeline` dan `cipher` hanya punya
-- ukuran grid di `PuzzleTable.GRID_FOR_TYPE` tanpa satu pun pemakaian nyata.
--
-- Yang paling mudah salah pada dua tipe yang baru: `timeline` memakai grid
-- TIDAK PERSEGI (4x2), sedangkan `newState` menurunkan `target` dari
-- `index % cols` / `floor(index / cols)` dan `scatter` mengundi x dari
-- `board.cols` tetapi y dari `board.rows`. Satu tempat yang memakai `cols` di
-- sumbu y membuat potongan ke-5..8 dari timeline jatuh ke sel yang tidak ada,
-- dan itu hanya terlihat kalau seluruh potongan benar-benar dirakit. Karena itu
-- suite ini merakit SEMUA potongan tiap tipe, bukan mengambil sampel.
--
-- Dipakai `data/cases/case_00.json` karena ia satu-satunya kasus yang memuat
-- ketiga tipe sekaligus.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")
local PuzzleTable = require("../src/shared/PuzzleTable")
local PuzzleTableService = require("../src/server/PuzzleTableService")
local Net = require("../src/shared/Net")

local function rng(): () -> number
	local seed = 0
	return function(): number
		seed += 1
		return (seed * 0.37) % 1
	end
end

local case = serde.decode("json", fs.readFile("data/cases/case_00.json"))
local variantId = case.variants[1].variant_id

local service = PuzzleTableService.new(PuzzleTable)
local built, skipped = PuzzleTableService.build(service, case.nodes, variantId, 16, 16, rng())
Harness.equal(#skipped, 0, "case_00 tidak punya tipe puzzle tak dikenal")

for _, entry in built do
	PuzzleTableService.register(service, entry)
end

Harness.suite("PuzzleTable: ukuran grid per tipe")

Harness.equal(select(1, PuzzleTable.gridFor("torn_doc")), 4, "torn_doc 4 kolom")
Harness.equal(select(2, PuzzleTable.gridFor("torn_doc")), 4, "torn_doc 4 baris")
Harness.equal(select(1, PuzzleTable.gridFor("timeline")), 4, "timeline 4 kolom")
Harness.equal(select(2, PuzzleTable.gridFor("timeline")), 2, "timeline 2 baris")
Harness.equal(select(1, PuzzleTable.gridFor("cipher")), 3, "cipher 3 kolom")
Harness.equal(select(2, PuzzleTable.gridFor("cipher")), 3, "cipher 3 baris")

local cols, rows = PuzzleTable.gridFor("teka_teki")
Harness.equal(cols, nil, "tipe tak dikenal tidak punya kolom")
Harness.equal(rows, nil, "tipe tak dikenal tidak punya baris")
Harness.equal(
	PuzzleTable.forPuzzle("teka_teki", "p", 16, 16, rng()),
	nil,
	"meja tipe tak dikenal nil"
)

Harness.suite("PuzzleTable: grid tidak persegi (timeline)")

-- Kasus batas yang paling mudah salah: potongan terakhir (indeks 8) harus
-- mendarat di kolom terakhir baris terakhir, bukan di baris 8.
local timelineBoard = PuzzleTable.newBoard(4, 2, 16, 16)
local regions: { number } = {}
for index = 1, 8 do
	table.insert(regions, index)
end
local timelineState = PuzzleTable.newState("t", timelineBoard, regions)

Harness.equal(#timelineState.pieces, 8, "timeline 4x2 = 8 potongan")
local last = timelineState.pieces[8]
Harness.equal(last.target.col, 3, "potongan ke-8 di kolom terakhir")
Harness.equal(last.target.row, 1, "potongan ke-8 di baris terakhir")

for _, piece in timelineState.pieces do
	Harness.check(
		piece.target.col >= 0 and piece.target.col < 4,
		string.format("kolom %s di dalam 4 kolom", piece.id)
	)
	Harness.check(
		piece.target.row >= 0 and piece.target.row < 2,
		string.format("baris %s di dalam 2 baris", piece.id)
	)
end

-- Setelah diacak, tidak ada potongan yang kebetulan sudah berada di sel benar
-- (kalau ada, meja bisa "selesai" tanpa pemain menyentuh apa pun).
local scrambled = PuzzleTable.forPuzzle("timeline", "t2", 16, 16, rng())
assert(scrambled ~= nil, "timeline harus bisa dibuat")
local alreadyCorrect = 0
for _, piece in scrambled.pieces do
	if piece.correct then
		alreadyCorrect += 1
	end
end
Harness.equal(alreadyCorrect, 0, "meja teracak tidak punya potongan yang sudah benar")

Harness.suite("Tiga tipe puzzle: rakitan penuh")

-- Setiap tipe dirakit sampai selesai memakai jalur otoritatif server yang sama
-- yang dipakai `handlePlacePiece`: `PuzzleTableService.place` dari posisi
-- ternormalisasi, bukan penyetelan `piece.cell` langsung.
local EXPECTED = {
	{ node_id = "ev_buku_tamu", puzzle_type = "torn_doc", pieces = 16, yields = "clue_a" },
	{ node_id = "ev_slot_pena", puzzle_type = "timeline", pieces = 8, yields = "clue_b" },
	{ node_id = "ev_label_kotak", puzzle_type = "cipher", pieces = 9, yields = "clue_c" },
}

for _, expect in EXPECTED do
	local entry = PuzzleTableService.get(service, expect.node_id)
	assert(entry ~= nil, expect.node_id .. " harus punya meja")

	Harness.equal(
		entry.puzzle_type,
		expect.puzzle_type,
		expect.node_id .. ": tipe dibaca dari data"
	)
	Harness.equal(
		#entry.state.pieces,
		expect.pieces,
		string.format("%s: %d potongan", expect.node_id, expect.pieces)
	)
	Harness.check(not entry.solved, expect.node_id .. " belum selesai saat sesi dimulai")
	Harness.equal(
		PuzzleTableService.progress(service, expect.node_id),
		0,
		expect.node_id .. ": progres 0"
	)

	local accepted = 0
	for _, piece in entry.state.pieces do
		local u = (piece.target.col + 0.5) / entry.state.board.cols
		local v = (piece.target.row + 0.5) / entry.state.board.rows
		local payload = PuzzleTableService.place(service, expect.node_id, piece.id, u, v)
		if payload.accepted then
			accepted += 1
		end
	end

	Harness.equal(accepted, expect.pieces, expect.node_id .. ": seluruh drop diterima server")
	Harness.check(entry.solved, expect.node_id .. ": meja selesai setelah dirakit penuh")
	Harness.equal(
		PuzzleTableService.progress(service, expect.node_id),
		expect.pieces,
		expect.node_id .. ": progres penuh"
	)
	Harness.equal(entry.yields, expect.yields, expect.node_id .. ": menghasilkan " .. expect.yields)
end

Harness.suite("Tiga tipe puzzle: drop di luar toleransi ditolak")

-- Kontrol: jalur "diterima" di atas tidak boleh berarti "semua drop diterima".
--
-- Drop di SUDUT sel -- titik pertemuan empat sel, ternormalisasi (1/cols,
-- 1/rows) -- berjarak 0,707 sel dari pusat sel terdekat, di luar
-- `SNAP_TOLERANCE` 0.5, jadi harus ditolak.
--
-- Sudut meja (0,0) BUKAN kasus yang tepat untuk ini: `clampNormalized` sengaja
-- menjepit jari yang keluar meja ke PUSAT sel tepi, sehingga drop di (0,0)
-- mendarat tepat di pusat sel (0,0) dan memang diterima. Menguji (0,0) akan
-- mengunci kebalikan dari kontrak modul.
local cipher = PuzzleTableService.get(service, "ev_label_kotak")
assert(cipher ~= nil, "meja cipher harus terdaftar")
local first = cipher.state.pieces[1]
local rejected = PuzzleTableService.place(
	service,
	"ev_label_kotak",
	first.id,
	1 / cipher.state.board.cols,
	1 / cipher.state.board.rows
)
Harness.equal(rejected.accepted, false, "drop di sudut sel di luar toleransi ditolak")

Harness.suite("Tiga tipe puzzle: payload tidak membocorkan target")

for _, expect in EXPECTED do
	local entry = PuzzleTableService.get(service, expect.node_id)
	assert(entry ~= nil, expect.node_id .. " harus punya meja")
	local payload = PuzzleTable.clientPayload(entry.state)

	Harness.equal(
		#Net.findSecrets(Net.forRole("puzzle_state", "Handler", payload), "puzzle_state"),
		0,
		expect.node_id .. ": puzzle_state bersih"
	)
	Harness.equal(
		payload.cols,
		select(1, PuzzleTable.gridFor(expect.puzzle_type)),
		expect.node_id .. ": cols di payload"
	)
	Harness.equal(
		payload.rows,
		select(2, PuzzleTable.gridFor(expect.puzzle_type)),
		expect.node_id .. ": rows di payload"
	)

	for _, piece in payload.pieces do
		Harness.check(piece.target == nil, expect.node_id .. ": payload tanpa `target`")
		Harness.check(piece.correct == nil, expect.node_id .. ": payload tanpa `correct`")
	end
end

Harness.finish("puzzle-types")
