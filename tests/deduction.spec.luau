--!strict
-- Uji mesin deduksi (PRD §4, §5).

local Harness = require("./harness")
local DeductionEngine = require("../src/server/DeductionEngine")

local RECIPES: { DeductionEngine.Recipe } = {
	{ id = "ded_access", needs = { "clue_guard_off", "clue_card_log" } },
	{ id = "ded_motive", needs = { "clue_card_log", "clue_collector_knew" } },
}

local engine, problem = DeductionEngine.new(RECIPES)
Harness.check(engine ~= nil, "mesin terbentuk: " .. tostring(problem))

if engine == nil then
	Harness.finish("deduction")
	return nil
end

Harness.suite("DeductionEngine: kombinasi")

local ok = DeductionEngine.combine(engine, { "clue_guard_off", "clue_card_log" }, {})
Harness.ok(ok.ok, "pasangan yang cocok diterima")
Harness.equal(ok.deductionId, "ded_access", "resep yang benar dikembalikan")

-- PRD §4: Director menggabungkan kartu dengan drag; urutan penggabungan tidak
-- boleh menentukan hasil.
local reversed = DeductionEngine.combine(engine, { "clue_card_log", "clue_guard_off" }, {})
Harness.ok(reversed.ok, "urutan kartu tidak menentukan hasil")
Harness.equal(reversed.deductionId, "ded_access", "hasil sama walau urutan dibalik")

Harness.suite("DeductionEngine: penolakan")

local single = DeductionEngine.combine(engine, { "clue_guard_off" }, {})
Harness.check(not single.ok, "satu kartu tidak cukup")

local duplicated = DeductionEngine.combine(engine, { "clue_card_log", "clue_card_log" }, {})
Harness.check(not duplicated.ok, "kartu yang sama dua kali ditolak")

local unknown = DeductionEngine.combine(engine, { "clue_guard_off", "clue_hantu" }, {})
Harness.check(not unknown.ok, "kombinasi tanpa resep ditolak")

local completed = DeductionEngine.combine(
	engine,
	{ "clue_guard_off", "clue_card_log" },
	{ ded_access = true }
)
Harness.check(not completed.ok, "deduksi yang sudah selesai tidak bisa diulang")

-- Dua resep berbagi satu kartu (clue_card_log). Menyelesaikan yang satu tidak
-- boleh memblokir yang lain.
local shared = DeductionEngine.combine(
	engine,
	{ "clue_card_log", "clue_collector_knew" },
	{ ded_access = true }
)
Harness.ok(shared.ok, "resep berbeda dengan kartu bersama tetap bisa dikerjakan")
Harness.equal(shared.deductionId, "ded_motive", "resep kedua dikembalikan")

Harness.suite("DeductionEngine: validasi resep")

local tooSmall = DeductionEngine.new({ { id = "x", needs = { "a" } } })
Harness.check(tooSmall == nil, "resep dengan kurang dari 2 kartu ditolak")

local duplicate = DeductionEngine.new({
	{ id = "x", needs = { "a", "b" } },
	{ id = "x", needs = { "c", "d" } },
})
Harness.check(duplicate == nil, "id deduksi duplikat ditolak")

Harness.suite("DeductionEngine: gerbang dan hitungan field")

-- PRD §5: kasus standar butuh 4 Deduksi Kunci dan minimal 1 Kontradiksi.
Harness.ok(DeductionEngine.gateOpen(4, 4, 1, 1), "gerbang terbuka saat syarat terpenuhi")
Harness.check(not DeductionEngine.gateOpen(3, 4, 1, 1), "gerbang tertutup saat deduksi kurang")
Harness.check(not DeductionEngine.gateOpen(4, 4, 0, 1), "gerbang tertutup tanpa kontradiksi")

Harness.equal(
	DeductionEngine.correctFieldCount(
		{ culprit = "curator", motive = "greed", method = "swapped_painting" },
		{ culprit = "curator", motive = "debt", method = "swapped_painting" }
	),
	2,
	"menghitung field yang benar"
)

Harness.finish("deduction")
