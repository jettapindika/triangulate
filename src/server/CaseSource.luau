--!strict
-- Sumber data kasus dari ServerStorage (PRD §10, §15).
--
-- PRD §10: "Semua kasus berupa data (puzzle, clue, graf, briefing per role,
-- solusi). Menambah kasus tidak menyentuh kode."
--
-- Pembagian tanggung jawab, dan kenapa dua modul:
--   * berkas ini -- sisi Roblox saja: menemukan ModuleScript di
--     `ServerStorage.Cases`, membacanya, dan menolak data yang bentuknya jelas
--     rusak sebelum ada sesi. Ia menyentuh `Instance`, jadi tidak bisa diuji
--     dari CLI.
--   * `src/shared/case/CaseLoader.luau` -- sisi murni: validasi penuh lewat
--     `CaseValidator`, pemilihan varian dari seed, proyeksi per role. Itu
--     satu-satunya tempat varian dipilih.
--
-- SEAM EXTA-33: skema JSON lengkap dan validator graf adalah deliverable
-- EXTA-33. Kontrak pemanggilan yang mereka isi:
--
--   CaseSource.setValidator(fn) -- fn(caseTable) -> (ok, daftarMasalah)
--
-- Selama validator belum dipasang, berkas ini tetap memeriksa bentuk minimum
-- supaya kesalahan data ketahuan saat start, bukan saat sesi berjalan.

local CaseSource = {}

export type CaseVariant = {
	variant_id: string,
	culprit: string,
	motive: string,
	method: string?,
	label: string?,
}

export type CaseNode = {
	id: string,
	-- PRD §10 memakai kunci `type` untuk jenis node. `type` sah sebagai nama
	-- field di Luau, tetapi `kind` juga diterima supaya penulis kasus yang
	-- menghindari kata kunci tetap bisa memuat datanya.
	kind: string?,
	type: string?,
	label: string?,
	-- Node yang hanya hidup pada cabang tertentu (PRD §10 "varian solusi").
	variants: { string }?,
	gives_key: string?,
	puzzle: string?,
	needs: { string }?,
	yields: string?,
	source: string?,
	unlocks: { string }?,
	supports: { string }?,
}

export type CaseStatement = {
	who: string,
	text: string?,
	lie: boolean?,
	contradicted_by: string?,
	variants: { string }?,
}

export type Case = {
	case_id: string,
	title: string?,
	case_type: string?,
	key_deductions: number?,
	location: string?,
	suspects: { string }?,
	motives: { string }?,
	methods: { string }?,
	variants: { CaseVariant },
	nodes: { CaseNode },
	statements: { CaseStatement }?,
	briefing: { [string]: string }?,
	briefings: { [string]: any }?,
	solution: { [string]: any }?,
}

export type Validator = (case: any) -> (boolean, { string })

local validator: Validator? = nil
local cache: { [string]: Case } = {}

-- Memasang validator skema (diisi EXTA-33). Mengembalikan validator sebelumnya,
-- supaya pemanggil bisa memulihkannya pada uji.
function CaseSource.setValidator(next: Validator?): Validator?
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
function CaseSource.shapeProblems(data: any): { string }
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
	local keys: { [string]: boolean } = {}
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
		if type(node.gives_key) == "string" then
			keys[node.gives_key] = true
		end

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

	--[[
		Setiap prasyarat harus menunjuk sesuatu yang benar-benar ada.

		`needs` bermakna berbeda menurut jenis node (PRD §4):
		  * pada `evidence`, `needs` menunjuk KUNCI yang diberikan objek
		    (`gives_key`), bukan node -- bukti dibuka oleh kunci, bukan oleh
		    node lain;
		  * pada `deduction`, `needs` menunjuk id node (Clue Card) yang
		    digabungkan.

		Menyamakan keduanya akan menolak kasus yang sah, jadi pemisahan ini
		bukan detail: tanpa itu `gallery_01` sendiri ditolak.
	]]
	for _, node in data.nodes do
		if type(node) ~= "table" or type(node.needs) ~= "table" then
			continue
		end
		local kind = node.kind
		if kind == nil then
			kind = node.type
		end
		local pool = if kind == "evidence" then keys else ids
		local label = if kind == "evidence" then "kunci" else "node"
		for _, need in node.needs do
			if not pool[need] then
				table.insert(
					problems,
					string.format(
						"%s membutuhkan %s '%s' yang tidak ada",
						tostring(node.id),
						label,
						tostring(need)
					)
				)
			end
		end
	end

	return problems
end

-- Memuat satu kasus. Melempar error bila kasus tidak ada atau rusak: kasus
-- rusak harus menghentikan start, bukan muncul sebagai sesi setengah jalan.
function CaseSource.load(casesFolder: Instance, caseId: string): Case
	local cached = cache[caseId]
	if cached ~= nil then
		return cached
	end

	local module = casesFolder:FindFirstChild(caseId)
	if module == nil or not module:IsA("ModuleScript") then
		error(string.format("kasus '%s' tidak ada di ServerStorage.Cases", caseId))
	end

	local data = require(module)

	local problems = CaseSource.shapeProblems(data)
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
function CaseSource.availableCaseIds(casesFolder: Instance): { string }
	local ids: { string } = {}
	for _, child in casesFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(ids, child.Name)
		end
	end
	table.sort(ids)
	return ids
end

-- Membersihkan cache. Dipakai uji dan saat kasus dimuat ulang.
function CaseSource.clearCache(): ()
	cache = {}
end

return CaseSource
