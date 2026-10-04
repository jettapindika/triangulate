--!nonstrict
--[[
	validate_case.luau — harness CLI untuk memvalidasi file kasus Triangulate.

	Jalankan dari root repo:

		lune run tools/validate_case.luau -- data/cases/gallery_01.json
		lune run tools/validate_case.luau -- tests/fixtures/*.json

	Exit code 0 bila semua file lulus, 1 bila ada yang gagal. Keluarannya
	dirancang untuk disalin apa adanya sebagai bukti di issue/PR.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local CaseValidator = require("../src/shared/case/CaseValidator")

local rawArgs = process.args
-- Lune meneruskan pemisah `--` sebagai argumen; buang agar path bisa dipakai apa adanya.
local args = {}
for _, arg in ipairs(rawArgs) do
	if arg ~= "--" then
		table.insert(args, arg)
	end
end
if #args == 0 then
	print("pemakaian: lune run tools/validate_case.luau -- <file.json> [file.json ...]")
	process.exit(2)
end

local failures = 0

for _, path in ipairs(args) do
	print(string.rep("=", 72))
	print("file: " .. path)
	print(string.rep("=", 72))

	if not fs.isFile(path) then
		print("status: GAGAL")
		print("  [io.not_found] file tidak ditemukan atau bukan berkas biasa.")
		failures = failures + 1
		continue
	end

	local raw = fs.readFile(path)
	local decodedOk, decoded = pcall(serde.decode, "json", raw)
	if not decodedOk then
		print("status: GAGAL")
		print("  [json.invalid] JSON tidak bisa di-parse: " .. tostring(decoded))
		failures = failures + 1
		continue
	end

	local report = CaseValidator.validate(decoded)
	print(CaseValidator.formatReport(report))
	if not report.ok then
		failures = failures + 1
	end
end

print(string.rep("=", 72))
if failures == 0 then
	print(string.format("HASIL: %d file lulus.", #args))
	process.exit(0)
else
	print(string.format("HASIL: %d dari %d file gagal.", failures, #args))
	process.exit(1)
end
