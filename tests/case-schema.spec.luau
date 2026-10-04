--!strict
-- Uji skema, validator, dan loader data kasus (EXTA-33).
--
-- Berkas ini adalah port dari runner EXTA-33 ke harness bersama EXTA-32
-- (`tests/harness.luau`), supaya seluruh suite keluar dari satu pintu:
-- `lune run tests/run.luau`.
--
-- Modul yang diuji murni (tidak menyentuh API Roblox), jadi suite ini berjalan
-- tanpa Studio.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")

local CaseValidator = require("../src/shared/case/CaseValidator")
local CaseLoader = require("../src/shared/case/CaseLoader")
local CaseGraph = require("../src/shared/case/CaseGraph")

local function readJson(path: string): any
	local ok, decoded = pcall(serde.decode, "json", fs.readFile(path))
	if not ok then
		error(string.format("gagal membaca %s: %s", path, tostring(decoded)))
	end
	return decoded
end

local function codes(report: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, issue in ipairs(report.errors) do
		set[issue.code] = true
	end
	return set
end

Harness.suite("case-schema: validator")

-- Hasil validator atas fixture punya kode error yang diharapkan. Fixture rusak
-- disimpan supaya perilaku validator terbukti, bukan diklaim.
local expectations = {
	{ path = "data/cases/gallery_01.json", ok = true },
	{ path = "tests/fixtures/cycle.json", ok = false, code = "graph.cycle" },
	{ path = "tests/fixtures/dead_end.json", ok = false, code = "graph.dead_end" },
	{
		path = "tests/fixtures/key_deductions_too_high.json",
		ok = false,
		code = "gate.key_deductions_exceeds",
	},
}

for _, expected in ipairs(expectations) do
	local report = CaseValidator.validate(readJson(expected.path))
	Harness.check(
		report.ok == expected.ok,
		string.format(
			"validator: %s -> ok=%s\n%s",
			expected.path,
			tostring(expected.ok),
			CaseValidator.formatReport(report)
		)
	)
	if expected.code ~= nil then
		Harness.check(
			codes(report)[expected.code] == true,
			string.format("validator: %s memunculkan %s", expected.path, expected.code)
		)
	end
end

Harness.suite("case-schema: pemilihan varian dari seed")

local gallery = readJson("data/cases/gallery_01.json")

local first = CaseLoader.selectVariant(gallery, "sesi-abc")
local again = CaseLoader.selectVariant(gallery, "sesi-abc")
Harness.check(
	first ~= nil and first.variant_id == again.variant_id,
	string.format(
		"loader: seed sama memilih varian sama (%s vs %s)",
		tostring(first and first.variant_id),
		tostring(again and again.variant_id)
	)
)

local picked: { [string]: boolean } = {}
for i = 1, 64 do
	local variant = CaseLoader.selectVariant(gallery, "seed-" .. i)
	picked[variant.variant_id] = true
end
local distinct = 0
for _ in pairs(picked) do
	distinct = distinct + 1
end
Harness.check(
	distinct > 1,
	string.format(
		"loader: beberapa seed menjangkau lebih dari satu varian (terjangkau: %d)",
		distinct
	)
)

Harness.suite("case-schema: load menolak kasus cacat")

local brokenLoad = CaseLoader.load(readJson("tests/fixtures/cycle.json"), "seed-1")
Harness.check(
	brokenLoad.ok == false and brokenLoad.session == nil,
	"loader: kasus bersiklus ditolak dan tidak menghasilkan sesi"
)

local goodLoad = CaseLoader.load(gallery, "seed-1")
Harness.check(goodLoad.ok == true and goodLoad.session ~= nil, "loader: kasus valid dimuat")
Harness.check(
	goodLoad.session ~= nil and goodLoad.session.solution ~= nil,
	"loader: session menyimpan solusi di sisi server"
)

Harness.suite("case-schema: proyeksi client")

local serverOnly: { [string]: boolean } = {}
for _, field in ipairs(CaseLoader.SERVER_ONLY_FIELDS) do
	serverOnly[field] = true
end

local function collectLeaks(value: any, path: string, found: { string })
	if type(value) ~= "table" then
		return
	end
	for key, item in pairs(value) do
		if serverOnly[key] == true then
			table.insert(found, string.format("%s.%s", path, tostring(key)))
		end
		collectLeaks(item, string.format("%s.%s", path, tostring(key)), found)
	end
end

local variantId = goodLoad.session.variant_id
for _, role in ipairs({ "searcher", "handler", "director" }) do
	local payload = CaseLoader.projectForRole(gallery, variantId, role)
	Harness.check(payload ~= nil, string.format("loader: proyeksi %s ada", role))

	local found: { string } = {}
	collectLeaks(payload, role, found)
	Harness.check(
		#found == 0,
		string.format(
			"loader: proyeksi %s bebas field server-only (%s)",
			role,
			table.concat(found, ", ")
		)
	)
end

Harness.suite("case-schema: pernyataan per varian")

local directorPayload = CaseLoader.projectForRole(gallery, "v_curator", "director")
local guardLieVisible = false
local curatorVisible = false
for _, statement in ipairs(directorPayload.statements or {}) do
	if statement.who == "guard" and string.find(statement.text, "serah terima", 1, true) then
		guardLieVisible = true
	end
	if statement.who == "curator" then
		curatorVisible = true
	end
end
Harness.check(guardLieVisible == false, "loader: pernyataan cabang lain tidak ikut terkirim")
Harness.check(curatorVisible == true, "loader: pernyataan cabang sesi ikut terkirim")

Harness.suite("case-schema: adapter seam ke loader server")

-- EXTA-32 menyisakan `CaseLoader.setValidator` untuk diisi EXTA-33. Kontraknya
-- `(case) -> (ok, daftarMasalah)`; adapter inilah yang dipasang server saat
-- start (lihat `src/server/init.server.luau`).
local adapterOk, adapterProblems = CaseValidator.asLoaderValidator(gallery)
Harness.check(
	adapterOk == true and #adapterProblems == 0,
	string.format("adapter: kasus valid -> ok=true tanpa masalah (%d masalah)", #adapterProblems)
)

local cycleOk, cycleProblems =
	CaseValidator.asLoaderValidator(readJson("tests/fixtures/cycle.json"))
Harness.check(cycleOk == false, "adapter: kasus bersiklus -> ok=false")
local mentionsCycle = false
for _, problem in ipairs(cycleProblems) do
	if string.find(problem, "graph.cycle", 1, true) then
		mentionsCycle = true
	end
end
Harness.check(
	mentionsCycle,
	string.format("adapter: masalah menyebut kode stabil (contoh: %s)", cycleProblems[1] or "-")
)

Harness.suite("case-schema: unlocks adalah tepi dependensi")

local unlockers = CaseGraph.unlockers(gallery, "v_curator")
Harness.check(
	unlockers["obj_ledger"] ~= nil and unlockers["obj_ledger"][1] == "ded_c_culprit_1",
	"graph: obj_ledger tercatat dibuka ded_c_culprit_1"
)

return nil
