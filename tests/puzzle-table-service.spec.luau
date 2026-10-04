--!strict
-- Uji state meja puzzle per sesi (PRD §4, §10, §15).
--
-- Yang diuji di sini adalah aturan yang HANYA ada di `PuzzleTableService`:
-- node bukti mana yang hidup pada varian sesi ini, siapa yang boleh
-- menempatkan potongan, bentuk payload remote yang diterima, dan apa yang
-- terjadi saat data kasus memuat tipe puzzle yang belum dikenal.
--
-- Yang tidak diuji di sini: geometri dan protokol drag. Itu `tests/puzzle-table.spec.luau`.

local Harness = require("./harness")
local PuzzleTable = require("../src/shared/PuzzleTable")
local PuzzleTableService = require("../src/server/PuzzleTableService")

local function rng(): () -> number
	local seed = 0
	return function(): number
		seed += 1
		return (seed * 0.37) % 1
	end
end

local function service(): PuzzleTableService.Service
	return PuzzleTableService.new(PuzzleTable)
end

local NODES: { PuzzleTableService.Node } = {
	{ id = "ev_schedule", type = "evidence", puzzle = "torn_doc", yields = "clue_guard_off" },
	{
		id = "ev_ledger",
		type = "evidence",
		puzzle = "cipher",
		yields = "clue_ledger",
		variants = { "v_curator" },
	},
	{ id = "obj_schedule", type = "object" },
	{ id = "ev_unknown", type = "evidence", puzzle = "rune_grid", yields = "clue_x" },
}

Harness.suite("PuzzleTableService: kindOf")

Harness.equal(
	PuzzleTableService.kindOf({ id = "n", kind = "evidence", type = "object" }),
	"evidence",
	"kind diutamakan atas type"
)
Harness.equal(
	PuzzleTableService.kindOf({ id = "n", type = "evidence" }),
	"evidence",
	"type dipakai bila kind tidak ada"
)
Harness.equal(PuzzleTableService.kindOf({ id = "n" }), nil, "node tanpa jenis mengembalikan nil")

Harness.suite("PuzzleTableService: isActive")

Harness.check(PuzzleTableService.isActive({ id = "n" }, nil), "node tanpa variants selalu aktif")
Harness.check(
	PuzzleTableService.isActive({ id = "n", variants = { "v_curator" } }, "v_curator"),
	"node dengan variants aktif pada varian yang cocok"
)
Harness.check(
	not PuzzleTableService.isActive({ id = "n", variants = { "v_curator" } }, "v_guard"),
	"node dengan variants mati pada varian lain"
)
-- Sesi tanpa varian dikenal: node ber-`variants` dianggap MATI. Menganggapnya
-- hidup akan mengirim bukti milik cabang lain ke client.
Harness.check(
	not PuzzleTableService.isActive({ id = "n", variants = { "v_curator" } }, nil),
	"node ber-variants mati bila sesi tidak punya varian"
)

Harness.suite("PuzzleTableService: build")

local built, skipped = PuzzleTableService.build(service(), NODES, "v_curator", 16, 16, rng())
Harness.equal(#built, 2, "dua node bukti aktif pada v_curator")
Harness.equal(#skipped, 1, "satu node bertipe puzzle tak dikenal dilewati")
Harness.equal(skipped[1], "ev_unknown", "node yang dilewati adalah ev_unknown")

-- Node `object` bukan bukti dan tidak boleh menghasilkan meja: meja adalah
-- tempat Handler merekonstruksi bukti (PRD §3), bukan tempat objek diletakkan.
local ids: { string } = {}
for _, entry in built do
	table.insert(ids, entry.node_id)
end
table.sort(ids)
Harness.equal(
	table.concat(ids, ","),
	"ev_ledger,ev_schedule",
	"hanya node evidence yang menjadi meja"
)

-- Varian lain harus menyaring `ev_ledger` keluar.
local guardBuilt = PuzzleTableService.build(service(), NODES, "v_guard", 16, 16, rng())
Harness.equal(#guardBuilt, 1, "hanya satu meja pada v_guard")
Harness.equal(guardBuilt[1].node_id, "ev_schedule", "ev_ledger mati pada v_guard")

Harness.suite("PuzzleTableService: register dan firstUnsolved")

local registered = service()
PuzzleTableService.register(registered, built[1])
PuzzleTableService.register(registered, built[2])
Harness.equal(#registered.order, 2, "dua meja terdaftar")
Harness.equal(
	PuzzleTableService.firstUnsolved(registered).node_id,
	built[1].node_id,
	"meja pertama mengikuti urutan pembuatan, bukan urutan hash"
)

-- Pendaftaran ulang node yang sama tidak boleh menduplikasi urutan.
PuzzleTableService.register(registered, built[1])
Harness.equal(#registered.order, 2, "pendaftaran ulang tidak menambah urutan")

Harness.equal(PuzzleTableService.get(registered, "ev_tidak_ada"), nil, "node tak dikenal -> nil")

Harness.suite("PuzzleTableService: canPlace")

Harness.check(PuzzleTableService.canPlace("Handler"), "Handler boleh menempatkan potongan")
Harness.check(
	PuzzleTableService.canPlace("Director"),
	"Director boleh mengambil alih meja pada mode 2 pemain (PRD §8)"
)
Harness.check(not PuzzleTableService.canPlace("Searcher"), "Searcher tidak menyentuh meja")
Harness.check(not PuzzleTableService.canPlace(nil), "role tak dikenal ditolak")

Harness.suite("PuzzleTableService: parsePlacement")

local pieceId, u, v = PuzzleTableService.parsePlacement({ piece_id = "p1", u = 0.5, v = 0.25 })
Harness.equal(pieceId, "p1", "piece_id diteruskan")
Harness.equal(u, 0.5, "u diteruskan")
Harness.equal(v, 0.25, "v diteruskan")

Harness.equal(PuzzleTableService.parsePlacement(nil), nil, "payload bukan tabel ditolak")
Harness.equal(PuzzleTableService.parsePlacement("p1"), nil, "payload string ditolak")
Harness.equal(
	PuzzleTableService.parsePlacement({ u = 0.5, v = 0.5 }),
	nil,
	"tanpa piece_id ditolak"
)
Harness.equal(
	PuzzleTableService.parsePlacement({ piece_id = "", u = 0.5, v = 0.5 }),
	nil,
	"piece_id kosong ditolak"
)
Harness.equal(
	PuzzleTableService.parsePlacement({ piece_id = "p1", u = "0.5", v = 0.5 }),
	nil,
	"u bertipe string ditolak, bukan dikonversi"
)
Harness.equal(
	PuzzleTableService.parsePlacement({ piece_id = "p1", u = 0.5 }),
	nil,
	"v yang hilang ditolak"
)
-- Di luar [0,1] BUKAN cacat bentuk: itu jari yang keluar meja, dan
-- `applyDrop` yang menjepitnya ke sel tepi.
local outside = PuzzleTableService.parsePlacement({ piece_id = "p1", u = -0.3, v = 1.8 })
Harness.equal(outside, "p1", "posisi di luar bidang tetap diteruskan ke applyDrop")

Harness.suite("PuzzleTableService: place dan progress")

local table_ = service()
PuzzleTableService.register(table_, built[1])
local entry = PuzzleTableService.get(table_, "ev_schedule")

local placedCount, total = PuzzleTableService.progress(table_, "ev_schedule")
Harness.equal(total, 16, "torn_doc 4x4 = 16 potongan")
Harness.equal(placedCount, 0, "potongan belum ada yang terpasang setelah scatter")
Harness.equal(
	select(1, PuzzleTableService.progress(table_, "ev_tidak_ada")),
	0,
	"meja tak dikenal -> kemajuan 0"
)

-- Menjatuhkan tiap potongan pada sel tujuannya harus menyelesaikan meja, dan
-- itulah yang membuat `yields` sebuah Clue Card terbuka (PRD §4).
local solvedPayload: { [string]: any }? = nil
local solvedNow = false
for _, piece in entry.state.pieces do
	local u2 = (piece.target.col + 0.5) / entry.state.board.cols
	local v2 = (piece.target.row + 0.5) / entry.state.board.rows
	local payload, solved = PuzzleTableService.place(table_, "ev_schedule", piece.id, u2, v2)
	solvedPayload = payload
	if solved then
		solvedNow = true
	end
end

Harness.check(solvedNow, "meja selesai setelah seluruh potongan diletakkan di sel tujuannya")
Harness.check(entry.solved, "entry ditandai selesai")
Harness.equal(
	PuzzleTableService.get(table_, "ev_schedule").yields,
	"clue_guard_off",
	"yields terbaca"
)
Harness.check(solvedPayload ~= nil and solvedPayload.accepted == true, "drop terakhir diterima")

local donePlaced = PuzzleTableService.progress(table_, "ev_schedule")
Harness.equal(donePlaced, 16, "16 potongan terpasang")

-- Meja yang selesai tidak lagi dipilih sebagai "meja pertama yang belum selesai".
Harness.equal(PuzzleTableService.firstUnsolved(table_), nil, "tidak ada meja tersisa")

-- Payload yang menyeberang ke client TIDAK memuat target/correct, bahkan saat
-- perayaan selesai sekalipun.
local payloadKeys: { string } = {}
for key in solvedPayload :: { [string]: any } do
	table.insert(payloadKeys, key)
end
table.sort(payloadKeys)
Harness.equal(
	table.concat(payloadKeys, ","),
	"accepted,piece_id,placed,x,y",
	"payload penempatan tidak membocorkan target/correct"
)

Harness.equal(
	select(1, PuzzleTableService.place(table_, "ev_tidak_ada", "p1", 0.5, 0.5)),
	nil,
	"meja tak dikenal -> payload nil, bukan error"
)

Harness.suite("PuzzleTableService: drop cacat ditolak")

local rejectTable = service()
PuzzleTableService.register(rejectTable, built[2])
local rejectEntry = PuzzleTableService.get(rejectTable, "ev_ledger")
local firstPiece = rejectEntry.state.pieces[1]
local beforePos = { x = firstPiece.pos.x, y = firstPiece.pos.y }

local nanPayload = PuzzleTableService.place(rejectTable, "ev_ledger", firstPiece.id, 0 / 0, 0.5)
Harness.check(nanPayload ~= nil and nanPayload.accepted == false, "drop NaN ditolak")
Harness.equal(rejectEntry.state.pieces[1].pos.x, beforePos.x, "posisi potongan tidak bergeser")
Harness.check(not rejectEntry.solved, "meja tidak dianggap selesai")

local unknownPiece = PuzzleTableService.place(rejectTable, "ev_ledger", "tidak:ada", 0.5, 0.5)
Harness.check(
	unknownPiece ~= nil and unknownPiece.accepted == false,
	"piece_id tak dikenal ditolak"
)
Harness.finish("puzzle-table-service")
