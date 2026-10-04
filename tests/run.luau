--!nonstrict
--[[
	run.luau — uji regresi untuk skema, validator, dan loader kasus.

	Jalankan dari root repo:

		lune run tests/run.luau

	Exit code 0 bila semua uji lulus, 1 bila ada yang gagal.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local CaseValidator = require("../src/shared/case/CaseValidator")
local CaseLoader = require("../src/shared/case/CaseLoader")
local CaseGraph = require("../src/shared/case/CaseGraph")

local failures: { string } = {}
local passed = 0

local function check(label: string, condition: boolean, detail: string?)
	if condition then
		passed = passed + 1
	else
		table.insert(failures, label .. (if detail then " — " .. detail else ""))
	end
end

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

--[[ Uji 1: hasil validator atas fixture punya kode error yang diharapkan. ]]

local expectations = {
	{ path = "data/cases/gallery_01.json", ok = true },
	{ path = "tests/fixtures/cycle.json", ok = false, code = "graph.cycle" },
	{ path = "tests/fixtures/dead_end.json", ok = false, code = "graph.dead_end" },
	{ path = "tests/fixtures/key_deductions_too_high.json", ok = false, code = "gate.key_deductions_exceeds" },
}

for _, expected in ipairs(expectations) do
	local report = CaseValidator.validate(readJson(expected.path))
	check(
		string.format("validator: %s -> ok=%s", expected.path, tostring(expected.ok)),
		report.ok == expected.ok,
		CaseValidator.formatReport(report)
	)
	if expected.code ~= nil then
		check(
			string.format("validator: %s memunculkan %s", expected.path, expected.code),
			codes(report)[expected.code] == true,
			CaseValidator.formatReport(report)
		)
	end
end

--[[ Uji 2: pemilihan varian deterministik untuk seed yang sama. ]]

local gallery = readJson("data/cases/gallery_01.json")
local first = CaseLoader.selectVariant(gallery, "sesi-abc")
local again = CaseLoader.selectVariant(gallery, "sesi-abc")
check(
	"loader: seed sama memilih varian sama",
	first ~= nil and first.variant_id == again.variant_id,
	string.format("%s vs %s", tostring(first and first.variant_id), tostring(again and again.variant_id))
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
check("loader: beberapa seed menjangkau lebih dari satu varian", distinct > 1, "varian terjangkau: " .. distinct)

--[[ Uji 3: load menolak kasus cacat, tidak pernah menjalankannya. ]]

local brokenLoad = CaseLoader.load(readJson("tests/fixtures/cycle.json"), "seed-1")
check("loader: kasus bersiklus ditolak", brokenLoad.ok == false and brokenLoad.session == nil)

local goodLoad = CaseLoader.load(gallery, "seed-1")
check("loader: kasus valid dimuat", goodLoad.ok == true and goodLoad.session ~= nil)
check(
	"loader: session menyimpan solusi di sisi server",
	goodLoad.session ~= nil and goodLoad.session.solution ~= nil
)

--[[ Uji 4: proyeksi client tidak membocorkan field server-only. ]]

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
			table.insert(found, string.format("%s.%s", path, key))
		end
		collectLeaks(item, string.format("%s.%s", path, tostring(key)), found)
	end
end

local variantId = goodLoad.session.variant_id
for _, role in ipairs({ "searcher", "handler", "director" }) do
	local payload = CaseLoader.projectForRole(gallery, variantId, role)
	check(string.format("loader: proyeksi %s ada", role), payload ~= nil)

	local found: { string } = {}
	collectLeaks(payload, role, found)
	check(
		string.format("loader: proyeksi %s bebas field server-only", role),
		#found == 0,
		table.concat(found, ", ")
	)
end

--[[ Uji 5: pernyataan yang diproyeksikan hanya yang berlaku di varian sesi. ]]

local directorPayload = CaseLoader.projectForRole(gallery, "v_curator", "director")
local guardLieVisible = false
for _, statement in ipairs(directorPayload.statements or {}) do
	if statement.who == "guard" and string.find(statement.text, "serah terima", 1, true) then
		guardLieVisible = true
	end
end
check("loader: pernyataan cabang lain tidak ikut terkirim", guardLieVisible == false)

local curatorPayload = CaseLoader.projectForRole(gallery, "v_curator", "director")
local curatorLieVisible = false
for _, statement in ipairs(curatorPayload.statements or {}) do
	if statement.who == "curator" then
		curatorLieVisible = true
	end
end
check("loader: pernyataan cabang sesi ikut terkirim", curatorLieVisible == true)

--[[ Uji 6: unlocks adalah tepi dependensi nyata, bukan metadata. ]]

local unlockers = CaseGraph.unlockers(gallery, "v_curator")
check(
	"graph: obj_ledger tercatat dibuka ded_c_culprit_1",
	unlockers["obj_ledger"] ~= nil and unlockers["obj_ledger"][1] == "ded_c_culprit_1"
)

print(string.format("lulus: %d", passed))
if #failures > 0 then
	print(string.format("gagal: %d", #failures))
	for _, failure in ipairs(failures) do
		print("  - " .. failure)
	end
	process.exit(1)
end
print("SEMUA UJI LULUS")
process.exit(0)
