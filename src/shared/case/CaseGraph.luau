--!strict
--[[
	CaseGraph.luau — utilitas graf murni untuk data kasus Triangulate.

	Rujukan: PRD v0.2 §4 (Clue Graph) dan §10 (validator kasus).

	Empat tipe node: object, evidence, clue_card, deduction.
	Arah dependensi: object --gives_key--> evidence --yields--> clue_card --> deduction.

	Modul ini tidak menyentuh API Roblox, sehingga dipakai bersama oleh server,
	harness CLI, dan (nanti) tooling build.
]]

local CaseGraph = {}

--[[ Tipe data kasus ---------------------------------------------------------- ]]

export type IdList = { string }
export type IdSet = { [string]: boolean }

-- Node bersifat terbuka: field di luar daftar ini boleh ada (mis. label, art),
-- validator yang menentukan mana yang wajib per tipe.
export type Node = {
	id: string,
	type: string,
	variants: IdList?,
	gives_key: string?,
	puzzle: string?,
	needs: IdList?,
	yields: string?,
	source: string?,
	unlocks: IdList?,
	-- Field tuduhan yang ditopang deduksi ini: culprit, motive, dan/atau method.
	supports: IdList?,
	label: string?,
}

export type Variant = {
	variant_id: string,
	culprit: string,
	motive: string,
	method: string?,
	label: string?,
}

export type Statement = {
	who: string,
	lie: boolean,
	contradicted_by: string?,
	text: string?,
	variants: IdList?,
}

export type Case = {
	case_id: string,
	location: string,
	variants: { Variant },
	nodes: { Node },
	case_type: string?,
	title: string?,
	key_deductions: number?,
	statements: { Statement }?,
	briefing: { [string]: any }?,
	solution: { [string]: any }?,
}

--[[ Konstanta ---------------------------------------------------------------- ]]

CaseGraph.NODE_TYPES = { "object", "evidence", "clue_card", "deduction" }
CaseGraph.PUZZLE_TYPES = { "torn_doc", "timeline", "cipher" }
CaseGraph.ACCUSATION_FIELDS = { "culprit", "motive", "method" }
CaseGraph.ROLES = { "searcher", "handler", "director" }

-- Jumlah Deduksi Kunci yang wajib selesai sebelum form tuduhan terbuka (PRD §5).
CaseGraph.REQUIRED_KEY_DEDUCTIONS = {
	standard = 4,
	daily = 3,
	case0 = 2,
}

--[[ Utilitas ----------------------------------------------------------------- ]]

local function contains(list: IdList?, value: string): boolean
	if list == nil then
		return false
	end
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

CaseGraph.contains = contains

function CaseGraph.variantIds(case: Case): IdList
	local ids: IdList = {}
	for _, variant in ipairs(case.variants) do
		if type(variant) == "table" and type(variant.variant_id) == "string" then
			table.insert(ids, variant.variant_id)
		end
	end
	return ids
end

function CaseGraph.nodeIndex(case: Case): { [string]: Node }
	local index: { [string]: Node } = {}
	for _, node in ipairs(case.nodes) do
		if type(node) == "table" and type(node.id) == "string" and index[node.id] == nil then
			index[node.id] = node
		end
	end
	return index
end

-- Node aktif untuk sebuah varian. Tanpa field `variants`, node aktif di semua varian.
function CaseGraph.isActive(node: Node, variantId: string): boolean
	if node.variants == nil then
		return true
	end
	return contains(node.variants, variantId)
end

function CaseGraph.activeNodes(case: Case, variantId: string): { Node }
	local active: { Node } = {}
	for _, node in ipairs(case.nodes) do
		if type(node) == "table" and CaseGraph.isActive(node, variantId) then
			table.insert(active, node)
		end
	end
	return active
end

-- Peta kunci -> id objek yang menyediakan kunci tersebut (hanya objek aktif di varian).
function CaseGraph.keyOwners(case: Case, variantId: string): { [string]: IdList }
	local owners: { [string]: IdList } = {}
	for _, node in ipairs(CaseGraph.activeNodes(case, variantId)) do
		if node.type == "object" and type(node.gives_key) == "string" then
			local list = owners[node.gives_key]
			if list == nil then
				list = {}
				owners[node.gives_key] = list
			end
			table.insert(list, node.id)
		end
	end
	return owners
end

--[[
	Peta node -> daftar node yang membukanya lewat `unlocks`.

	PRD §4: Deduksi "membuka target baru, pinpoint, atau tuduhan". Jadi node
	yang muncul di `unlocks` sebuah deduksi bergantung pada deduksi itu — bukan
	sekadar metadata. Tanpa ini, target hasil deduksi akan terlihat sebagai
	rantai buntu.
]]
function CaseGraph.unlockers(case: Case, variantId: string): { [string]: IdList }
	local map: { [string]: IdList } = {}
	for _, node in ipairs(CaseGraph.activeNodes(case, variantId)) do
		if type(node.unlocks) == "table" then
			for _, target in ipairs(node.unlocks) do
				local bucket = map[target]
				if bucket == nil then
					bucket = {}
					map[target] = bucket
				end
				table.insert(bucket, node.id)
			end
		end
	end
	return map
end

--[[
	Pernyataan berlaku untuk varian ini bila ia tidak dibatasi varian, atau
	varian ini ada di daftar `variants`-nya. Pelaku berbeda tiap cabang, jadi
	pernyataan pembohong pun berbeda per cabang.
]]
function CaseGraph.statementAppliesTo(statement: Statement, variantId: string): boolean
	if type(statement.variants) ~= "table" then
		return true
	end
	return contains(statement.variants, variantId)
end

-- Dependensi langsung: node lain yang harus selesai sebelum node ini bisa dikerjakan.
function CaseGraph.dependenciesOf(
	node: Node,
	keyOwners: { [string]: IdList },
	unlockers: { [string]: IdList }?
): IdList
	local deps: IdList = {}
	if node.type == "evidence" then
		for _, key in ipairs(node.needs or {}) do
			local owners = keyOwners[key]
			if owners ~= nil then
				for _, ownerId in ipairs(owners) do
					table.insert(deps, ownerId)
				end
			end
		end
	elseif node.type == "clue_card" then
		if type(node.source) == "string" then
			table.insert(deps, node.source)
		end
	elseif node.type == "deduction" then
		for _, need in ipairs(node.needs or {}) do
			table.insert(deps, need)
		end
	end
	-- Node yang membuka node ini harus selesai lebih dulu.
	if unlockers ~= nil then
		for _, opener in ipairs(unlockers[node.id] or {}) do
			table.insert(deps, opener)
		end
	end
	return deps
end

-- Graf dependensi terbatas pada node aktif di varian tersebut.
function CaseGraph.edges(case: Case, variantId: string): { [string]: IdList }
	local owners = CaseGraph.keyOwners(case, variantId)
	local unlockers = CaseGraph.unlockers(case, variantId)
	local deps: { [string]: IdList } = {}
	for _, node in ipairs(CaseGraph.activeNodes(case, variantId)) do
		deps[node.id] = CaseGraph.dependenciesOf(node, owners, unlockers)
	end
	return deps
end

-- Kebalikan dari edges: untuk tiap node, siapa saja yang memakainya.
function CaseGraph.consumers(case: Case, variantId: string): { [string]: IdList }
	local consumers: { [string]: IdList } = {}
	for id, deps in pairs(CaseGraph.edges(case, variantId)) do
		for _, dep in ipairs(deps) do
			local bucket = consumers[dep]
			if bucket == nil then
				bucket = {}
				consumers[dep] = bucket
			end
			table.insert(bucket, id)
		end
	end
	return consumers
end

--[[
	Deteksi siklus dependensi (PRD §10: "tanpa dependensi melingkar").
	Mengembalikan jalur siklus, misal { "ded_a", "ded_b", "ded_a" }, atau nil.
	Urutan penelusuran mengikuti urutan deklarasi node agar pesan stabil.
]]
function CaseGraph.findCycle(case: Case, variantId: string): IdList?
	local deps = CaseGraph.edges(case, variantId)
	local order: IdList = {}
	for _, node in ipairs(CaseGraph.activeNodes(case, variantId)) do
		table.insert(order, node.id)
	end

	local finished: IdSet = {}
	local onPath: IdSet = {}
	local path: IdList = {}

	local function visit(id: string): IdList?
		if onPath[id] then
			local cycle: IdList = {}
			local start = 1
			for i, item in ipairs(path) do
				if item == id then
					start = i
					break
				end
			end
			for i = start, #path do
				table.insert(cycle, path[i])
			end
			table.insert(cycle, id)
			return cycle
		end
		if finished[id] then
			return nil
		end
		onPath[id] = true
		table.insert(path, id)
		for _, dep in ipairs(deps[id] or {}) do
			local found = visit(dep)
			if found ~= nil then
				return found
			end
		end
		table.remove(path)
		onPath[id] = nil
		finished[id] = true
		return nil
	end

	for _, id in ipairs(order) do
		local found = visit(id)
		if found ~= nil then
			return found
		end
	end
	return nil
end

--[[
	Himpunan node yang bisa dicapai dari objek di varian tersebut.
	Semantik AND: sebuah node baru dianggap tercapai bila SEMUA dependensinya tercapai.
	Pada graf bersiklus, node di dalam siklus tidak pernah tercapai — inilah yang
	membuat rantai buntu terdeteksi.
]]
function CaseGraph.reachable(case: Case, variantId: string): IdSet
	local deps = CaseGraph.edges(case, variantId)
	local done: IdSet = {}
	local progressed = true
	while progressed do
		progressed = false
		for id, list in pairs(deps) do
			if not done[id] then
				local ready = true
				for _, dep in ipairs(list) do
					if not done[dep] then
						ready = false
						break
					end
				end
				if ready then
					done[id] = true
					progressed = true
				end
			end
		end
	end
	return done
end

--[[
	Objek asal sebuah node: benda di lokasi yang harus ditemukan Searcher supaya
	node ini bisa dikerjakan.

	PRD §4: "Deduksi menaruh pinpoint baru di map dan membuka target baru."
	Pinpoint itu harus menunjuk ke suatu tempat, dan satu-satunya node yang
	mewakili "tempat" di model data adalah `object`. Rantainya:
	deduction -> needs (clue_card) -> source (evidence) -> needs (key) -> object.

	Kenapa menurunkan rantai ini alih-alih menulis `unlocks` di data: `unlocks`
	adalah sisi dependensi yang NYATA (`dependenciesOf` memasukkannya), jadi
	menambahnya ke kasus yang sudah lulus gate berarti menambah busur ke graf --
	dan busur baru bisa memunculkan `graph.cycle` atau `graph.dead_end`. Turunan
	di sini tidak menyentuh data sama sekali, jadi kasus yang lulus tetap lulus.

	Urutan hasil mengikuti urutan deklarasi node, bukan urutan penelusuran,
	supaya pinpoint tidak berpindah-pindah antar pemanggilan.
]]
function CaseGraph.origins(case: Case, variantId: string, nodeId: string): IdList
	local deps = CaseGraph.edges(case, variantId)

	local visited: IdSet = {}
	local stack: IdList = { nodeId }
	while #stack > 0 do
		local current = table.remove(stack) :: string
		if not visited[current] then
			visited[current] = true
			for _, dep in ipairs(deps[current] or {}) do
				if not visited[dep] then
					table.insert(stack, dep)
				end
			end
		end
	end

	local objects: IdList = {}
	for _, node in ipairs(CaseGraph.activeNodes(case, variantId)) do
		if node.type == "object" and visited[node.id] then
			table.insert(objects, node.id)
		end
	end
	return objects
end

--[[
	Objek asal pertama dalam urutan deklarasi, atau nil bila tidak ada. Dipakai
	server untuk mengisi pinpoint deduksi: PRD §4 menyebut satu pinpoint per
	deduksi, bukan daftar.
]]
function CaseGraph.primaryOrigin(case: Case, variantId: string, nodeId: string): string?
	local objects = CaseGraph.origins(case, variantId, nodeId)
	if #objects == 0 then
		return nil
	end
	return objects[1]
end

return CaseGraph
