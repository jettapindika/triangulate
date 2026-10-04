--!strict
-- Graf ketergantungan kasus (PRD §4).
--
-- Empat jenis node: objek (Searcher menemukan), bukti (Handler merekonstruksi),
-- clue card (Director memegang), deduksi (gabungan 2+ clue card). Graf harus
-- asiklik: PRD §10 menyebut validator memastikan "tanpa dependensi melingkar".
--
-- Modul ini murni -- tidak ada global Roblox -- sehingga bisa diuji dari CLI.
-- Validator penuh milik EXTA-33; modul ini hanya memuat graf dan menyediakan
-- operasi yang dibutuhkan mesin deduksi pada saat sesi berjalan.

local ClueGraph = {}

export type NodeType = "object" | "evidence" | "clue" | "deduction"

export type Node = {
	id: string,
	type: NodeType,
	-- PRD §4: objek memberi kunci, bukti membutuhkannya.
	gives_key: string?,
	puzzle: string?,
	needs: { string }?,
	yields: string?,
	unlocks: { string }?,
}

export type Graph = {
	nodes: { Node },
}

-- Data kasus membawa `nodes` di level atas (bentuk PRD §10), sehingga CaseData
-- sekaligus memenuhi Graph.
export type CaseData = {
	case_id: string,
	location: string?,
	nodes: { Node },
}

local VALID_TYPES: { [string]: boolean } = {
	object = true,
	evidence = true,
	clue = true,
	deduction = true,
}

function ClueGraph.index(graph: Graph): { [string]: Node }
	local byId: { [string]: Node } = {}
	for _, node in graph.nodes do
		byId[node.id] = node
	end
	return byId
end

-- Node yang bisa dikerjakan sekarang: prasyaratnya sudah terpenuhi.
-- `satisfied` adalah himpunan id node yang sudah selesai/dimiliki.
function ClueGraph.available(graph: Graph, satisfied: { [string]: boolean }): { Node }
	local out: { Node } = {}
	for _, node in graph.nodes do
		local needs = node.needs
		if needs == nil or #needs == 0 then
			table.insert(out, node)
		else
			local ready = true
			for _, requirement in needs do
				if not satisfied[requirement] then
					ready = false
					break
				end
			end
			if ready then
				table.insert(out, node)
			end
		end
	end
	return out
end

-- Node yang menjadi terbuka karena sebuah node selesai.
function ClueGraph.unlockedBy(graph: Graph, nodeId: string): { Node }
	local out: { Node } = {}
	for _, node in graph.nodes do
		local needs = node.needs
		if needs ~= nil then
			for _, requirement in needs do
				if requirement == nodeId then
					table.insert(out, node)
					break
				end
			end
		end
	end
	return out
end

-- Graf asiklik? Deteksi siklus dengan DFS tiga warna.
function ClueGraph.isAcyclic(graph: Graph): (boolean, { string }?)
	local byId = ClueGraph.index(graph)
	local state: { [string]: number } = {}
	local path: { string } = {}

	local function visit(id: string): { string }?
		local node = byId[id]
		if node == nil then
			return nil
		end

		local mark = state[id]
		if mark == 2 then
			return nil
		end
		if mark == 1 then
			-- Ketemu siklus; bangun jejaknya untuk pesan kesalahan.
			local cycle: { string } = { id }
			for index = #path, 1, -1 do
				table.insert(cycle, 1, path[index])
				if path[index] == id then
					break
				end
			end
			return cycle
		end

		state[id] = 1
		table.insert(path, id)

		local needs = node.needs
		if needs ~= nil then
			for _, requirement in needs do
				local cycle = visit(requirement)
				if cycle ~= nil then
					return cycle
				end
			end
		end

		table.remove(path)
		state[id] = 2
		return nil
	end

	for _, node in graph.nodes do
		local cycle = visit(node.id)
		if cycle ~= nil then
			return false, cycle
		end
	end

	return true, nil
end

-- Masalah struktural yang bisa dideteksi tanpa aturan penulisan kasus:
-- id duplikat, jenis node tak dikenal, prasyarat menunjuk id yang tidak ada,
-- dan siklus.
function ClueGraph.structuralProblems(graph: Graph): { string }
	local problems: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, node in graph.nodes do
		if seen[node.id] then
			table.insert(problems, string.format("id node duplikat: %s", node.id))
		end
		seen[node.id] = true

		if not VALID_TYPES[node.type] then
			table.insert(
				problems,
				string.format("jenis node tak dikenal '%s' pada %s", node.type, node.id)
			)
		end
	end

	for _, node in graph.nodes do
		local needs = node.needs
		if needs ~= nil then
			for _, requirement in needs do
				if not seen[requirement] then
					table.insert(
						problems,
						string.format(
							"%s membutuhkan '%s' yang tidak ada di graf",
							node.id,
							requirement
						)
					)
				end
			end
		end
	end

	local acyclic, cycle = ClueGraph.isAcyclic(graph)
	if not acyclic and cycle ~= nil then
		table.insert(
			problems,
			string.format("dependensi melingkar: %s", table.concat(cycle, " -> "))
		)
	end

	return problems
end

return ClueGraph
