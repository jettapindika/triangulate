--!strict
-- Harness uji minimal.
--
-- Lune 0.10.5 tidak membawa pustaka uji (tidak ada `@lune/test`), jadi harness
-- ini ditulis sendiri: tanpa dependensi, deterministik, dan keluar dengan kode
-- non-nol bila ada assertion gagal -- sehingga bisa dipakai di CI (seam
-- EXTA-34).
--
-- Yang diuji adalah modul murni: modul yang tidak menyentuh global Roblox.
-- Itu bukan kebetulan -- justru alasan modul-modul itu dipisahkan dari glue.

local Harness = {}

local failures: { string } = {}
local assertions = 0
local suite = "(tanpa suite)"

local function describe(value: any): string
	local t = type(value)
	if t == "string" then
		return string.format("%q", value)
	end
	if t == "table" then
		local parts: { string } = {}
		local asTable = value :: { [any]: any }
		for key, child in asTable do
			table.insert(parts, string.format("%s = %s", tostring(key), describe(child)))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end

	local tableA = a :: { [any]: any }
	local tableB = b :: { [any]: any }
	local countA = 0
	for key, valueA in tableA do
		countA += 1
		if not deepEqual(valueA, tableB[key]) then
			return false
		end
	end
	local countB = 0
	for _ in tableB do
		countB += 1
	end
	return countA == countB
end

function Harness.suite(name: string): ()
	suite = name
	print(string.format("\n== %s", name))
end

function Harness.check(condition: boolean, message: string): ()
	assertions += 1
	if condition then
		return
	end
	table.insert(failures, string.format("%s: %s", suite, message))
	print(string.format("  FAIL  %s", message))
end

function Harness.equal(actual: any, expected: any, message: string): ()
	assertions += 1
	if deepEqual(actual, expected) then
		return
	end
	table.insert(
		failures,
		string.format(
			"%s: %s (dapat %s, harap %s)",
			suite,
			message,
			describe(actual),
			describe(expected)
		)
	)
	print(
		string.format(
			"  FAIL  %s\n          dapat %s\n          harap %s",
			message,
			describe(actual),
			describe(expected)
		)
	)
end

function Harness.ok(actual: any, message: string): ()
	Harness.equal(actual, true, message)
end

-- Perbandingan angka dengan toleransi. Pembagian floating point tidak pernah
-- memberi hasil eksak (1 - 8/10 bukan 0.2), jadi pecahan diuji dengan toleransi,
-- bukan kesamaan bit.
function Harness.near(actual: number, expected: number, message: string, tolerance: number?): ()
	local epsilon = tolerance or 1e-9
	assertions += 1
	if math.abs(actual - expected) <= epsilon then
		return
	end
	table.insert(
		failures,
		string.format("%s: %s (dapat %.9f, harap %.9f)", suite, message, actual, expected)
	)
	print(
		string.format(
			"  FAIL  %s\n          dapat %.9f\n          harap %.9f",
			message,
			actual,
			expected
		)
	)
end

-- Menguji bahwa `fn` melempar. Dipakai untuk jalur kesalahan yang memang harus
-- menghentikan start, bukan diam-diam lolos.
function Harness.throws(fn: () -> (), message: string): ()
	assertions += 1
	local ok = pcall(fn)
	if ok then
		table.insert(failures, string.format("%s: %s (tidak melempar)", suite, message))
		print(string.format("  FAIL  %s (tidak melempar)", message))
	end
end

-- Menandai bahwa laporan akhir dipegang `tests/run.luau`, yang memuat semua
-- spec lalu melapor sekali di akhir. Dipanggil runner SEBELUM memuat spec.
local aggregating = false

function Harness.aggregate(): ()
	aggregating = true
end

-- Dipanggil spec di baris terakhirnya, dan di `tests/run.luau` setelah semua
-- spec dimuat.
--
-- Lewat runner ia diam untuk spec (runner yang melapor), supaya keluarannya
-- tidak berisi beberapa ringkasan di tengah. Dijalankan sendiri
-- (`lune run tests/<spec>.luau`), ia mencetak ringkasan dan keluar non-nol bila
-- ada yang gagal -- tanpa itu, spec yang dijalankan sendiri selalu keluar 0 dan
-- keluarannya tidak membuktikan apa pun.
function Harness.finish(label: string): ()
	if aggregating then
		return
	end
	print(string.format("\n%s: %d assertion, %d gagal", label, assertions, #failures))
	if #failures > 0 then
		for _, failure in failures do
			print("  - " .. failure)
		end
		require("@lune/process").exit(1)
	end
	print("SEMUA LULUS")
end

-- Laporan akhir, tanpa syarat. Hanya `tests/run.luau` yang memanggilnya.
function Harness.report(): ()
	print(string.format("\n%d assertion, %d gagal", assertions, #failures))
	if #failures > 0 then
		print("\nGagal:")
		for _, failure in failures do
			print("  - " .. failure)
		end
		local process = require("@lune/process")
		process.exit(1)
	end
	print("SEMUA LULUS")
end

return Harness
