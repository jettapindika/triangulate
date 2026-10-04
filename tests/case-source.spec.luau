--!strict
-- Uji sumber data kasus sisi server (PRD §10, §15).
--
-- Yang diuji di sini HANYA bagian yang tidak butuh `Instance`: pemeriksaan
-- bentuk minimum dan seam validator. Pemilihan varian dan validasi penuh ada
-- di `src/shared/case/CaseLoader.luau`, dan diuji di `tests/case-schema.spec.luau`.

local Harness = require("./harness")
local CaseSource = require("../src/server/CaseSource")

-- `any` disengaja: fixture di bawah adalah JSON mentah, termasuk yang sengaja
-- rusak. Anotasi tipe di sini justru akan menyembunyikan bug -- tujuan ujinya
-- adalah memberi loader masukan sembarang dan memeriksa reaksinya.
local VALID: any = {
	case_id = "gallery_01",
	location = "gallery",
	variants = {
		{ variant_id = "v_curator", culprit = "curator", motive = "debt", method = "access_card" },
		{ variant_id = "v_guard", culprit = "guard", motive = "revenge", method = "alarm_off" },
	},
	nodes = {
		{ id = "obj_schedule", type = "object", gives_key = "key_a" },
		{
			id = "ev_schedule",
			type = "evidence",
			needs = { "key_a" },
			yields = "clue_guard_off",
		},
		{ id = "clue_guard_off", type = "clue_card", source = "ev_schedule" },
	},
}

Harness.suite("CaseSource: bentuk kasus")

Harness.equal(CaseSource.shapeProblems(VALID), {}, "kasus sah tidak punya masalah")

Harness.equal(
	CaseSource.shapeProblems("bukan tabel"),
	{ "kasus bukan tabel" },
	"nilai bukan tabel ditolak"
)
Harness.check(#CaseSource.shapeProblems({ case_id = "x" }) > 0, "kasus tanpa nodes ditolak")
Harness.check(
	#CaseSource.shapeProblems({ case_id = "x", nodes = {} }) > 0,
	"kasus tanpa node ditolak"
)
Harness.check(#CaseSource.shapeProblems({ nodes = VALID.nodes }) > 0, "kasus tanpa case_id ditolak")

Harness.suite("CaseSource: jenis node")

-- PRD §10 memakai kunci `type`. `kind` juga diterima supaya penulis kasus yang
-- menghindari kata kunci tetap bisa memuat datanya.
local withKind = {
	case_id = "x",
	nodes = { { id = "a", kind = "object" } },
}
Harness.equal(CaseSource.shapeProblems(withKind), {}, "kunci `kind` diterima")

local withType = {
	case_id = "x",
	nodes = { { id = "a", type = "object" } },
}
Harness.equal(CaseSource.shapeProblems(withType), {}, "kunci `type` diterima")

local unknownKind = {
	case_id = "x",
	nodes = { { id = "a", type = "teka_teki" } },
}
Harness.check(#CaseSource.shapeProblems(unknownKind) > 0, "jenis node tak dikenal ditolak")

local missingKind = {
	case_id = "x",
	nodes = { { id = "a" } },
}
Harness.check(#CaseSource.shapeProblems(missingKind) > 0, "node tanpa jenis ditolak")

Harness.suite("CaseSource: id dan prasyarat")

local duplicate = {
	case_id = "x",
	nodes = { { id = "a", type = "clue_card" }, { id = "a", type = "clue_card" } },
}
Harness.check(#CaseSource.shapeProblems(duplicate) > 0, "id node duplikat ditolak")

local noId = {
	case_id = "x",
	nodes = { { type = "clue_card" } },
}
Harness.check(#CaseSource.shapeProblems(noId) > 0, "node tanpa id ditolak")

-- PRD §10: validator memastikan "tidak ada rantai yang buntu".
local dangling = {
	case_id = "x",
	nodes = {
		{ id = "ded_a", type = "deduction", needs = { "tidak_ada" }, supports = { "culprit" } },
	},
}
Harness.check(
	#CaseSource.shapeProblems(dangling) > 0,
	"deduksi yang menunjuk node tidak ada ditolak"
)

-- `needs` pada bukti menunjuk KUNCI, bukan node. Kunci yang tidak pernah
-- diberikan objek mana pun berarti rantai yang tidak bisa dibuka.
local keyless = {
	case_id = "x",
	nodes = {
		{
			id = "ev_a",
			type = "evidence",
			puzzle = "torn_doc",
			needs = { "key_hilang" },
			yields = "c",
		},
	},
}
Harness.check(#CaseSource.shapeProblems(keyless) > 0, "bukti yang menuntut kunci tidak ada ditolak")

Harness.suite("CaseSource: seam validator EXTA-33")

-- Seam yang diisi EXTA-33: `setValidator(fn)`. Diuji di sini hanya kontraknya
-- -- pemasangan dan pemulihan -- karena `load` sendiri butuh Instance Roblox.
local previous = CaseSource.setValidator(function(case)
	if case.case_id == "buruk" then
		return false, { "case_id terlarang" }
	end
	return true, {}
end)

Harness.equal(previous, nil, "validator awal kosong")

local restored = CaseSource.setValidator(nil)
Harness.check(restored ~= nil, "setValidator mengembalikan validator sebelumnya")
Harness.finish("case-source")
