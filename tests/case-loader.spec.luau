--!strict
-- Uji loader kasus (PRD §10, §15).

local Harness = require("./harness")
local CaseLoader = require("../src/server/CaseLoader")

-- `any` disengaja: fixture di bawah adalah JSON mentah, termasuk yang sengaja
-- rusak. Anotasi tipe di sini justru akan menyembunyikan bug -- tujuan ujinya
-- adalah memberi loader masukan sembarang dan memeriksa reaksinya.
local VALID: any = {
	case_id = "gallery_01",
	location = "gallery",
	variants = {
		{ culprit = "curator", motive = "debt", method = "swapped_painting" },
		{ culprit = "guard", motive = "revenge", method = "forged_log" },
	},
	nodes = {
		{ id = "obj_schedule", type = "object", gives_key = "key_a" },
		{
			id = "ev_schedule",
			type = "evidence",
			needs = { "obj_schedule" },
			yields = "clue_guard_off",
		},
		{ id = "clue_guard_off", type = "clue" },
	},
}

Harness.suite("CaseLoader: bentuk kasus")

Harness.equal(CaseLoader.shapeProblems(VALID), {}, "kasus sah tidak punya masalah")

Harness.equal(
	CaseLoader.shapeProblems("bukan tabel"),
	{ "kasus bukan tabel" },
	"nilai bukan tabel ditolak"
)
Harness.check(#CaseLoader.shapeProblems({ case_id = "x" }) > 0, "kasus tanpa nodes ditolak")
Harness.check(
	#CaseLoader.shapeProblems({ case_id = "x", nodes = {} }) > 0,
	"kasus tanpa node ditolak"
)
Harness.check(#CaseLoader.shapeProblems({ nodes = VALID.nodes }) > 0, "kasus tanpa case_id ditolak")

Harness.suite("CaseLoader: jenis node")

-- PRD §10 memakai kunci `type`. `kind` juga diterima supaya penulis kasus yang
-- menghindari kata kunci tetap bisa memuat datanya.
local withKind = {
	case_id = "x",
	nodes = { { id = "a", kind = "object" } },
}
Harness.equal(CaseLoader.shapeProblems(withKind), {}, "kunci `kind` diterima")

local withType = {
	case_id = "x",
	nodes = { { id = "a", type = "object" } },
}
Harness.equal(CaseLoader.shapeProblems(withType), {}, "kunci `type` diterima")

local unknownKind = {
	case_id = "x",
	nodes = { { id = "a", type = "teka_teki" } },
}
Harness.check(#CaseLoader.shapeProblems(unknownKind) > 0, "jenis node tak dikenal ditolak")

local missingKind = {
	case_id = "x",
	nodes = { { id = "a" } },
}
Harness.check(#CaseLoader.shapeProblems(missingKind) > 0, "node tanpa jenis ditolak")

Harness.suite("CaseLoader: id dan prasyarat")

local duplicate = {
	case_id = "x",
	nodes = { { id = "a", type = "clue" }, { id = "a", type = "clue" } },
}
Harness.check(#CaseLoader.shapeProblems(duplicate) > 0, "id node duplikat ditolak")

local noId = {
	case_id = "x",
	nodes = { { type = "clue" } },
}
Harness.check(#CaseLoader.shapeProblems(noId) > 0, "node tanpa id ditolak")

-- PRD §10: validator memastikan "tidak ada rantai yang buntu".
local dangling = {
	case_id = "x",
	nodes = { { id = "a", type = "clue", needs = { "tidak_ada" } } },
}
Harness.check(
	#CaseLoader.shapeProblems(dangling) > 0,
	"prasyarat yang menunjuk node tidak ada ditolak"
)

Harness.suite("CaseLoader: pemilihan varian")

Harness.equal(CaseLoader.pickVariant(VALID, 0).culprit, "curator", "roll 0 memilih varian pertama")
Harness.equal(CaseLoader.pickVariant(VALID, 0.5).culprit, "guard", "roll 0.5 memilih varian kedua")
Harness.equal(
	CaseLoader.pickVariant(VALID, 0.999999).culprit,
	"guard",
	"roll mendekati 1 tetap dalam rentang"
)
Harness.equal(
	CaseLoader.pickVariant(VALID, 1).culprit,
	"guard",
	"roll 1 dijepit ke varian terakhir"
)
Harness.equal(
	CaseLoader.pickVariant(VALID, -5).culprit,
	"curator",
	"roll negatif dijepit ke varian pertama"
)

-- Deterministik: seed yang sama harus memberi varian yang sama (PRD §10).
Harness.equal(
	CaseLoader.pickVariant(VALID, 0.42),
	CaseLoader.pickVariant(VALID, 0.42),
	"roll yang sama memberi varian yang sama"
)

local threeVariants: any = {
	case_id = "x",
	variants = {
		{ culprit = "a", motive = "m", method = "x" },
		{ culprit = "b", motive = "m", method = "x" },
		{ culprit = "c", motive = "m", method = "x" },
	},
	nodes = { { id = "n", type = "clue" } },
}
Harness.equal(
	CaseLoader.pickVariant(threeVariants, 0).culprit,
	"a",
	"tiga varian: roll 0 -> pertama"
)
Harness.equal(
	CaseLoader.pickVariant(threeVariants, 0.34).culprit,
	"b",
	"tiga varian: roll 0.34 -> kedua"
)
Harness.equal(
	CaseLoader.pickVariant(threeVariants, 0.67).culprit,
	"c",
	"tiga varian: roll 0.67 -> ketiga"
)

local noVariants: any = { case_id = "x", variants = {}, nodes = { { id = "n", type = "clue" } } }
Harness.throws(function()
	CaseLoader.pickVariant(noVariants, 0.5)
end, "kasus tanpa varian melempar")

Harness.suite("CaseLoader: seam validator EXTA-33")

-- Seam yang akan diisi EXTA-33: `setValidator(fn)`. Diuji di sini hanya
-- kontraknya -- pemasangan dan pemulihan -- karena `load` sendiri butuh
-- Instance Roblox.
local previous = CaseLoader.setValidator(function(case)
	if case.case_id == "buruk" then
		return false, { "case_id terlarang" }
	end
	return true, {}
end)

Harness.equal(previous, nil, "validator awal kosong")

local restored = CaseLoader.setValidator(nil)
Harness.check(restored ~= nil, "setValidator mengembalikan validator sebelumnya")

return nil
