--!strict
-- Uji graf kasus (PRD §4, §10).

local Harness = require("./harness")
local ClueGraph = require("../src/server/ClueGraph")

local VALID: ClueGraph.Graph = {
	nodes = {
		{ id = "obj_schedule", type = "object", gives_key = "key_a" },
		{
			id = "ev_schedule",
			type = "evidence",
			needs = { "obj_schedule" },
			yields = "clue_guard_off",
		},
		{ id = "clue_guard_off", type = "clue_card" },
		{
			id = "ded_access",
			type = "deduction",
			needs = { "clue_guard_off", "clue_card_log" },
			unlocks = { "pin_office" },
		},
		{ id = "clue_card_log", type = "clue_card" },
	},
}

Harness.suite("ClueGraph: keterjangkauan")

local available = ClueGraph.available(VALID, {})
local availableIds: { string } = {}
for _, node in available do
	table.insert(availableIds, node.id)
end
table.sort(availableIds)

-- Hanya node tanpa prasyarat yang boleh tersedia di awal.
Harness.equal(
	availableIds,
	{ "clue_card_log", "clue_guard_off", "obj_schedule" },
	"node tanpa prasyarat tersedia"
)

local afterObject = ClueGraph.available(VALID, { obj_schedule = true })
local afterIds: { string } = {}
for _, node in afterObject do
	table.insert(afterIds, node.id)
end
table.sort(afterIds)
Harness.check(
	table.find(afterIds, "ev_schedule") ~= nil,
	"menyelesaikan objek membuka bukti yang membutuhkannya"
)

local unlocked = ClueGraph.unlockedBy(VALID, "obj_schedule")
Harness.equal(#unlocked, 1, "satu node terbuka karena objek")
Harness.equal(unlocked[1].id, "ev_schedule", "node yang terbuka adalah bukti yang benar")

Harness.suite("ClueGraph: asiklik")

local acyclic, cycle = ClueGraph.isAcyclic(VALID)
Harness.ok(acyclic, "graf sah tidak punya siklus")
Harness.equal(cycle, nil, "tidak ada siklus yang dilaporkan")

-- PRD §10: validator memastikan "tanpa dependensi melingkar".
local cyclic: ClueGraph.Graph = {
	nodes = {
		{ id = "a", type = "clue_card", needs = { "c" } },
		{ id = "b", type = "clue_card", needs = { "a" } },
		{ id = "c", type = "clue_card", needs = { "b" } },
	},
}

local cyclicOk, cyclicPath = ClueGraph.isAcyclic(cyclic)
Harness.check(not cyclicOk, "siklus terdeteksi")
Harness.check(cyclicPath ~= nil, "jejak siklus dilaporkan")

Harness.suite("ClueGraph: masalah struktural")

Harness.equal(ClueGraph.structuralProblems(VALID), {}, "graf sah tidak punya masalah")

local duplicate = ClueGraph.structuralProblems({
	nodes = {
		{ id = "a", type = "clue_card" },
		{ id = "a", type = "clue_card" },
	},
})
Harness.check(#duplicate > 0, "id duplikat dilaporkan")

-- `:: any` disengaja: ujinya justru memberi validator jenis node yang tidak ada
-- di tipe, untuk memastikan validator menolaknya alih-alih melewatinya.
local unknownType = ClueGraph.structuralProblems({
	nodes = { { id = "a", type = "teka_teki" } },
} :: any)
Harness.check(#unknownType > 0, "jenis node tak dikenal dilaporkan")

local dangling = ClueGraph.structuralProblems({
	nodes = { { id = "a", type = "clue_card", needs = { "tidak_ada" } } },
})
Harness.check(#dangling > 0, "prasyarat yang menunjuk node tidak ada dilaporkan")

return nil
