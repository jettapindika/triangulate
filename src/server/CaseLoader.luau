--!strict
-- Loader kasus (PRD §10, §15).
--
-- PRD §10: "Semua kasus berupa data (puzzle, clue, graf, briefing per role,
-- solusi). Menambah kasus tidak menyentuh kode."
--
-- Modul ini adalah sisi server dari aturan itu: satu-satunya tempat kode
-- menyentuh data kasus. Data hidup di `ServerStorage.Cases`, yang tidak pernah
-- direplikasi ke client (PRD §15, dan lihat `shared/Net.luau` untuk argumen
-- lengkapnya).
--
-- SEAM EXTA-33: skema JSON lengkap dan validator graf adalah deliverable
-- EXTA-33. Di sini hanya ada kontrak pemanggilan yang mereka isi:
--
--   CaseLoader.setValidator(fn) -- fn(caseTable) -> (ok, daftarMasalah)
--
-- Selama validator belum dipasang, loader tetap memeriksa bentuk minimum
-- supaya kesalahan data ketahuan saat start, bukan saat sesi berjalan.

local CaseLoader = {}

export type CaseVariant = {
	culprit: string,
	motive: string,
	method: string,
}

export type CaseNode = {
	id: string,
	-- PRD §10 memakai kunci `type` untuk jenis node. `type` sah sebagai nama
	-- field di Luau, tetapi `kind` juga diterima supaya penulis kasus yang
	-- menghindari kata kunci tetap bisa memuat datanya.
	kind: string?,
	type: string?,
	needs: { string }?,
	unlocks: { string }?,
	gives_key: string?,
	yields: string?,
	puzzle: string?,
}

export type Case = {
	case_id: string,
	location: string?,
	variants: { CaseVariant },
	nodes: { CaseNode },
	statements: { [string]: any }?,
}

export type Validator = (case: any) -> (boolean, { string })

local validator: Validator? = nil
local cache: { [string]: Case } = {}

-- Memasang validator skema (diisi EXTA-33). Mengembalikan validator sebelumnya,
-- supaya pemanggil bisa memulihkannya pada uji.
function CaseLoader.setValidator(next: Validator?): Validator?
	local previous = validator
	validator = next
	cache = {}
	return previous
end

-- Node yang wajib ada di setiap kasus (PRD §4): graf harus punya minimal satu
-- objek, satu bukti, satu clue, dan satu deduksi, dan setiap node harus punya
-- id serta jenis.
local VALID_KINDS: { [string]: boolean } = {
	object = true,
	evidence = true,
	clue_card = true,
	deduction = true,
}

-- Pemeriksaan bentuk minimum. Bukan pengganti validator EXTA-33: ini hanya
-- menangkap data yang jelas rusak agar tidak sampai ke sesi.
function CaseLoader.shapeProblems(data: any): { string }
	local problems: { string } = {}

	if type(data) ~= "table" then
		return { "kasus bukan tabel" }
	end
	if type(data.case_id) ~= "string" then
		table.insert(problems, "case_id hilang atau bukan string")
	end
	if type(data.nodes) ~= "table" then
		table.insert(problems, "nodes hilang atau bukan tabel")
		return problems
	end
	if #data.nodes == 0 then
		table.insert(problems, "nodes kosong")
		return problems
	end

	local ids: { [string]: boolean } = {}
	for index, node in data.nodes do
		local where = string.format("nodes[%d]", index)
		if type(node) ~= "table" then
			table.insert(problems, string.format("%s bukan tabel", where))
			continue
		end
		if type(node.id) ~= "string" or node.id == "" then
			table.insert(problems, string.format("%s tidak punya id", where))
			continue
		end
		if ids[node.id] then
			table.insert(problems, string.format("id node duplikat: %s", node.id))
		end
		ids[node.id] = true

		-- PRD §10 memakai kunci `type` untuk jenis node. `type` sah sebagai
		-- nama field di Luau; lihat `docs/arsitektur.md`.
		local kind = node.kind
		if kind == nil then
			kind = node.type
		end
		if type(kind) ~= "string" or not VALID_KINDS[kind] then
			table.insert(problems, string.format("%s punya jenis tidak dikenal", where))
		end
	end

	-- Setiap prasyarat harus menunjuk node yang benar-benar ada (PRD §10:
	-- validator memastikan tidak ada rantai buntu).
	for _, node in data.nodes do
		if type(node) == "table" and type(node.needs) == "table" then
			for _, need in node.needs do
				if not ids[need] then
					table.insert(
						problems,
						string.format("%s membutuhkan '%s' yang tidak ada", node.id, tostring(need))
					)
				end
			end
		end
	end

	return problems
end

-- Memuat satu kasus. Melempar error bila kasus tidak ada atau rusak: kasus
-- rusak harus menghentikan start, bukan muncul sebagai sesi setengah jalan.
function CaseLoader.load(casesFolder: Instance, caseId: string): Case
	local cached = cache[caseId]
	if cached ~= nil then
		return cached
	end

	local module = casesFolder:FindFirstChild(caseId)
	if module == nil or not module:IsA("ModuleScript") then
		error(string.format("kasus '%s' tidak ada di ServerStorage.Cases", caseId))
	end

	local data = require(module)

	local problems = CaseLoader.shapeProblems(data)
	if #problems > 0 then
		error(string.format("kasus '%s' rusak: %s", caseId, table.concat(problems, "; ")))
	end

	if validator ~= nil then
		local ok, validatorProblems = validator(data)
		if not ok then
			error(
				string.format(
					"kasus '%s' gagal validasi: %s",
					caseId,
					table.concat(validatorProblems, "; ")
				)
			)
		end
	end

	cache[caseId] = data
	return data
end

-- Semua kasus yang tersedia, terurut supaya pemilihan kasus deterministik.
function CaseLoader.availableCaseIds(casesFolder: Instance): { string }
	local ids: { string } = {}
	for _, child in casesFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(ids, child.Name)
		end
	end
	table.sort(ids)
	return ids
end

-- PRD §10: "Seed server memilih cabang saat sesi dibuat." Pemilihan cabang
-- harus deterministik dari seed agar dua server dengan seed sama menghasilkan
-- kasus yang sama, dan hasilnya TIDAK pernah dikirim ke client.
--
-- `roll` adalah angka di [0, 1); pemanggil menghasilkannya dari seed sesi.
-- Memisahkan `roll` dari pembangkit acak membuat fungsi ini murni dan bisa
-- diuji dari CLI.
function CaseLoader.pickVariant(case: Case, roll: number): CaseVariant
	local count = #case.variants
	if count == 0 then
		error(string.format("kasus '%s' tidak punya variants", case.case_id))
	end

	local normalized = roll
	if normalized < 0 then
		normalized = 0
	elseif normalized >= 1 then
		normalized = 0.999999
	end

	local index = math.floor(normalized * count) + 1
	return case.variants[index]
end

-- Membersihkan cache. Dipakai uji dan saat kasus dimuat ulang.
function CaseLoader.clearCache(): ()
	cache = {}
end

return CaseLoader
