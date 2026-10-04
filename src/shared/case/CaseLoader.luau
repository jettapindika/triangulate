--!nonstrict
--[[
	CaseLoader.luau — memuat kasus dari data dan memproyeksikannya per role.

	Rujukan: PRD v0.2 §10 ("seed server memilih cabang saat sesi dibuat"),
	§15 ("Server menyimpan state kasus dan solusi. Client hanya menerima data
	sesuai role. Pemeriksaan resep deduksi dan tuduhan hanya di server.").

	Prinsip modul ini:

	1. Data kasus adalah satu-satunya sumber kebenaran. Tidak ada kasus yang
	   ditulis di dalam kode.
	2. Pemilihan varian deterministik dari seed, sehingga seluruh pemain dalam
	   satu sesi mendapat cabang yang sama tanpa perlu saling memberi tahu.
	3. Proyeksi client memakai ALLOWLIST per role, bukan denylist. Field baru
	   yang ditambahkan ke skema tidak pernah bocor ke client secara tidak
	   sengaja.

	Modul ini murni: tidak menyentuh filesystem maupun API Roblox. Harness CLI
	yang membaca file dan memanggil `CaseLoader.load`.
]]

local Compat = require("./Compat")
local CaseGraph = Compat.requireSibling("CaseGraph")
local CaseValidator = Compat.requireSibling("CaseValidator")

local CaseLoader = {}

--[[
	Field yang TIDAK PERNAH dikirim ke client, dalam bentuk apa pun.

	Daftar ini didokumentasikan di `docs/case-schema.md` dan dipakai sebagai
	bahan uji kebocoran (`tests/`). Menambah field rahasia baru berarti
	menambahkannya di sini.
]]
CaseLoader.SERVER_ONLY_FIELDS = {
	"solution",
	"culprit",
	"motive",
	"method",
	"lie",
	"contradicted_by",
	"required_deductions",
}

--[[
	Hash FNV-1a 32-bit. Dipakai untuk memetakan seed sesi ke indeks varian.
	Stabil lintas platform, sehingga seed yang sama selalu memilih varian yang
	sama.

	Perkalian FNV (`hash * 16777619`) mencapai 2^56 bila dikerjakan sebagai
	number 64-bit floating point, dan bit rendahnya hilang — akibatnya semua
	seed jatuh ke varian yang sama. Karena itu perkalian dipecah per 16 bit
	supaya tetap eksak di bawah 2^53.
]]
local FNV_PRIME = 16777619
local TWO_32 = 4294967296

local function fnvMultiply(hash: number): number
	local low = hash % 65536
	local high = math.floor(hash / 65536)
	return ((low * FNV_PRIME) % TWO_32 + ((high * FNV_PRIME) % 65536) * 65536) % TWO_32
end

local function hashSeed(seed: any): number
	local text = tostring(seed)
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = fnvMultiply(hash)
	end
	-- Penyelesaian akhir (avalanche). Tanpa ini bit rendah hash hanya
	-- mencerminkan byte terakhir, sehingga seed seperti "kasus-1" dan
	-- "sidang-1" bisa jatuh ke varian yang sama dan pemilihan varian jadi
	-- bisa ditebak dari karakter terakhir seed.
	hash = bit32.bxor(hash, bit32.rshift(hash, 16))
	hash = fnvMultiply(hash)
	hash = bit32.bxor(hash, bit32.rshift(hash, 13))
	hash = fnvMultiply(hash)
	hash = bit32.bxor(hash, bit32.rshift(hash, 16))
	return hash
end

CaseLoader.hashSeed = hashSeed

--[[
	Memilih varian untuk sebuah seed. Deterministik dan seragam.

	Mengembalikan Variant (tabel), atau nil bila kasus tidak punya varian.
]]
function CaseLoader.selectVariant(case: any, seed: any): any
	local variants = case.variants
	if type(variants) ~= "table" or #variants == 0 then
		return nil
	end
	local index = (hashSeed(seed) % #variants) + 1
	return variants[index]
end

--[[
	Memuat satu kasus siap-sesi.

	Langkah:
	  1. validasi data; menolak kasus cacat dengan pesan validator,
	  2. pilih varian dari seed,
	  3. bangun peta node aktif untuk varian tersebut.

	Mengembalikan `ok=false` beserta `report` bila validasi gagal — server tidak
	pernah menjalankan kasus yang belum lolos validator.
]]
function CaseLoader.load(case: any, seed: any): any
	local report = CaseValidator.validate(case)
	if not report.ok then
		return { ok = false, report = report, session = nil }
	end

	local variant = CaseLoader.selectVariant(case, seed)
	if variant == nil then
		return {
			ok = false,
			report = {
				ok = false,
				errors = {
					{
						code = "loader.no_variant",
						path = "variants",
						message = "Kasus tidak punya varian.",
					},
				},
				warnings = {},
			},
			session = nil,
		}
	end

	local variantId = variant.variant_id
	local active = CaseGraph.activeNodes(case, variantId)
	local reachable = CaseGraph.reachable(case, variantId)

	local activeById: { [string]: boolean } = {}
	for _, node in ipairs(active) do
		activeById[node.id] = true
	end

	return {
		ok = true,
		report = report,
		session = {
			case_id = case.case_id,
			title = case.title,
			location = case.location,
			case_type = case.case_type,
			variant_id = variantId,
			key_deductions = case.key_deductions,
			seed = tostring(seed),
			active_node_ids = (function()
				local ids = {}
				for _, node in ipairs(active) do
					table.insert(ids, node.id)
				end
				return ids
			end)(),
			reachable_node_ids = (function()
				local ids = {}
				for _, node in ipairs(active) do
					if reachable[node.id] == true then
						table.insert(ids, node.id)
					end
				end
				return ids
			end)(),
			-- Disimpan server saja; tidak pernah diproyeksikan ke client.
			variant = variant,
			solution = case.solution[variantId],
		},
	}
end

--[[
	Proyeksi payload untuk satu role.

	Hanya field di allowlist yang ikut. `gives_key`, `yields`, `source`, dan
	`needs` bukti memang terlihat role terkait karena mereka butuh tahu kunci
	mana yang membuka bukti mana; resep deduksi, pernyataan bohong, pembantah,
	dan seluruh blok solusi tidak pernah ikut.
]]

local ROLE_PROJECTION = {
	-- Searcher menjelajah lokasi: butuh objek, label, dan kunci yang diberikannya.
	searcher = {
		nodes = { object = { "id", "label", "gives_key" } },
		includeStatements = false,
	},

	-- Handler merakit bukti: butuh tipe puzzle dan kunci yang diminta.
	handler = {
		nodes = { evidence = { "id", "label", "puzzle", "needs" } },
		includeStatements = false,
	},

	-- Director menyusun deduksi: butuh Clue Card dan teks pernyataan, TANPA
	-- resep deduksi, tanpa penanda bohong, tanpa clue pembantah.
	director = {
		nodes = { clue_card = { "id", "label" }, deduction = { "id", "label" } },
		includeStatements = true,
	},
}

CaseLoader.ROLE_PROJECTION = ROLE_PROJECTION

function CaseLoader.projectForRole(case: any, variantId: string, role: string): any
	local spec = ROLE_PROJECTION[role]
	if spec == nil then
		return nil
	end

	local nodes = {}
	for _, node in ipairs(CaseGraph.activeNodes(case, variantId)) do
		local allowed = spec.nodes[node.type]
		if allowed ~= nil then
			local out = { type = node.type }
			for _, field in ipairs(allowed) do
				if node[field] ~= nil then
					out[field] = node[field]
				end
			end
			table.insert(nodes, out)
		end
	end

	local payload = {
		case_id = case.case_id,
		title = case.title,
		location = case.location,
		variant_id = variantId,
		role = role,
		key_deductions = case.key_deductions,
		nodes = nodes,
		briefing = type(case.briefing) == "table" and case.briefing[role] or nil,
	}

	if spec.includeStatements and type(case.statements) == "table" then
		local statements = {}
		for _, statement in ipairs(case.statements) do
			-- Hanya pernyataan yang berlaku di varian sesi ini. Pelaku berbeda
			-- tiap cabang, jadi pernyataan cabang lain akan membocorkan cabang.
			if CaseGraph.statementAppliesTo(statement, variantId) then
				table.insert(statements, {
					who = statement.who,
					text = statement.text,
				})
			end
		end
		payload.statements = statements
	end

	return payload
end

return CaseLoader
