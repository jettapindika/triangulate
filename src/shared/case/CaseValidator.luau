--!nonstrict
--[[
	CaseValidator.luau — validasi data kasus Triangulate.

	Rujukan: PRD v0.2 §4 (Clue Graph), §5 (win condition & anti brute-force),
	§10 ("validator: memastikan minimal satu jalur solusi, tanpa dependensi
	melingkar, dan tidak ada rantai yang buntu").

	Validator ini adalah otoritas eksekutabel: ia dipanggil server sebelum kasus
	dipakai, dan dipanggil harness CLI saat penulisan kasus. JSON Schema di
	`schema/case.schema.json` adalah artefak spesifikasi untuk editor/tooling.

	Setiap temuan punya `code` stabil (aman untuk diuji) dan `message` Bahasa
	Indonesia yang bisa dibaca penulis kasus.
]]

local Compat = require("./Compat")
local CaseGraph = Compat.requireSibling("CaseGraph")

local CaseValidator = {}

export type Issue = {
	code: string,
	path: string,
	message: string,
}

export type Report = {
	ok: boolean,
	errors: { Issue },
	warnings: { Issue },
}

local CASE_TYPES = { standard = true, daily = true, case0 = true }
local NODE_TYPES = { object = true, evidence = true, clue_card = true, deduction = true }
local PUZZLE_TYPES = { torn_doc = true, timeline = true, cipher = true }
local ACCUSATION_FIELDS = { culprit = true, motive = true, method = true }

local function isNonEmptyString(value: any): boolean
	return type(value) == "string" and #value > 0
end

local function isStringList(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for _, item in ipairs(value) do
		if not isNonEmptyString(item) then
			return false
		end
	end
	return true
end

local function describe(value: any): string
	local kind = type(value)
	if kind == "string" then
		return string.format("%q", value)
	elseif kind == "table" then
		local n = 0
		for _ in pairs(value) do
			n = n + 1
		end
		return string.format("table(%d entri)", n)
	end
	return tostring(value)
end

--[[
	Pernyataan berlaku untuk varian ini bila ia tidak dibatasi varian, atau
	varian ini ada di daftar `variants`-nya. Pelaku berbeda tiap cabang, jadi
	pernyataan pembohong pun bisa berbeda per cabang.
]]
local function statementAppliesTo(statement: any, variantId: string): boolean
	return CaseGraph.statementAppliesTo(statement, variantId)
end

--[[
	Validasi satu kasus. Mengembalikan Report; tidak pernah raise.
]]
function CaseValidator.validate(case: any): Report
	local errors: { Issue } = {}
	local warnings: { Issue } = {}

	local function err(code: string, path: string, message: string)
		table.insert(errors, { code = code, path = path, message = message })
	end

	local function warn(code: string, path: string, message: string)
		table.insert(warnings, { code = code, path = path, message = message })
	end

	if type(case) ~= "table" then
		err("case.not_table", "", "Data kasus harus berupa object JSON.")
		return { ok = false, errors = errors, warnings = warnings }
	end

	--[[ A. Tingkat kasus --------------------------------------------------- ]]

	if not isNonEmptyString(case.case_id) then
		err("case.case_id", "case_id", "`case_id` wajib diisi dan berupa string tidak kosong.")
	end
	if not isNonEmptyString(case.location) then
		err("case.location", "location", "`location` wajib diisi dan berupa string tidak kosong.")
	end
	if case.case_type ~= nil and CASE_TYPES[case.case_type] ~= true then
		err(
			"case.case_type",
			"case_type",
			"`case_type` harus salah satu dari standard, daily, case0 (ditemukan "
				.. describe(case.case_type)
				.. ")."
		)
	end
	if case.key_deductions ~= nil and type(case.key_deductions) ~= "number" then
		err("case.key_deductions_type", "key_deductions", "`key_deductions` harus berupa angka.")
	end

	--[[ B. Varian ---------------------------------------------------------- ]]

	local variantIds: { string } = {}
	local variantSeen: { [string]: boolean } = {}
	local rawVariants: any = case.variants

	if type(rawVariants) ~= "table" or #rawVariants == 0 then
		err("case.variants", "variants", "`variants` wajib berisi minimal satu cabang solusi.")
	else
		for i, raw in ipairs(rawVariants) do
			local variant: any = raw
			local path = string.format("variants[%d]", i)
			if type(variant) ~= "table" then
				err("variant.not_table", path, "Varian harus berupa object JSON.")
			else
				if not isNonEmptyString(variant.variant_id) then
					err("variant.variant_id", path .. ".variant_id", "`variant_id` wajib diisi.")
				elseif variantSeen[variant.variant_id] then
					err(
						"variant.duplicate_id",
						path .. ".variant_id",
						string.format(
							"`variant_id` %q dipakai lebih dari sekali.",
							variant.variant_id
						)
					)
				else
					variantSeen[variant.variant_id] = true
					table.insert(variantIds, variant.variant_id)
				end
				-- PRD §5: form tuduhan meminta Pelaku, Motif, dan Cara.
				for _, field in ipairs(CaseGraph.ACCUSATION_FIELDS) do
					if not isNonEmptyString(variant[field]) then
						err(
							"variant.field",
							path .. "." .. field,
							string.format(
								"Varian wajib punya `%s` (field tuduhan PRD §5) berupa string tidak kosong.",
								field
							)
						)
					end
				end
			end
		end
	end

	--[[ C. Node ------------------------------------------------------------ ]]

	local nodes: { any } = {}
	local nodeSeen: { [string]: boolean } = {}
	local nodeById: { [string]: any } = {}
	local structural = true
	local rawNodes: any = case.nodes

	if type(rawNodes) ~= "table" or #rawNodes == 0 then
		err("case.nodes", "nodes", "`nodes` wajib berisi minimal satu node.")
		structural = false
	else
		for i, raw in ipairs(rawNodes) do
			local node: any = raw
			local path = string.format("nodes[%d]", i)
			if type(node) ~= "table" then
				err("node.not_table", path, "Node harus berupa object JSON.")
				structural = false
			else
				local id = node.id
				if not isNonEmptyString(id) then
					err("node.id", path .. ".id", "`id` node wajib diisi.")
					structural = false
				elseif nodeSeen[id] then
					err(
						"node.duplicate_id",
						path .. ".id",
						string.format("`id` node %q duplikat.", id)
					)
					structural = false
				else
					nodeSeen[id] = true
					nodeById[id] = node
					table.insert(nodes, node)
				end

				if NODE_TYPES[node.type] ~= true then
					err(
						"node.type",
						path .. ".type",
						string.format(
							"`type` node harus salah satu dari object, evidence, clue_card, deduction (ditemukan %s).",
							describe(node.type)
						)
					)
					structural = false
				end

				if node.variants ~= nil and not isStringList(node.variants) then
					err(
						"node.variants",
						path .. ".variants",
						"`variants` node harus daftar id varian."
					)
				end

				if node.type == "object" then
					if not isNonEmptyString(node.gives_key) then
						err(
							"node.object.gives_key",
							path .. ".gives_key",
							"Node object wajib punya `gives_key`."
						)
						structural = false
					end
				elseif node.type == "evidence" then
					if PUZZLE_TYPES[node.puzzle] ~= true then
						err(
							"node.evidence.puzzle",
							path .. ".puzzle",
							string.format(
								"Puzzle MVP harus torn_doc, timeline, atau cipher (ditemukan %s).",
								describe(node.puzzle)
							)
						)
						structural = false
					end
					if node.needs ~= nil and not isStringList(node.needs) then
						err(
							"node.evidence.needs",
							path .. ".needs",
							"`needs` bukti harus daftar id kunci."
						)
						structural = false
					end
					if not isNonEmptyString(node.yields) then
						err(
							"node.evidence.yields",
							path .. ".yields",
							"Node evidence wajib punya `yields`."
						)
						structural = false
					end
				elseif node.type == "clue_card" then
					if not isNonEmptyString(node.source) then
						err(
							"node.clue_card.source",
							path .. ".source",
							"Node clue_card wajib punya `source`."
						)
						structural = false
					end
				elseif node.type == "deduction" then
					if not isStringList(node.needs) or #node.needs < 2 then
						err(
							"node.deduction.needs",
							path .. ".needs",
							"Node deduction wajib menggabungkan minimal 2 Clue Card (PRD §4)."
						)
						structural = false
					end
					if not isStringList(node.supports) or #node.supports == 0 then
						err(
							"node.deduction.supports",
							path .. ".supports",
							"Node deduction wajib punya `supports`: daftar field tuduhan yang ditopangnya."
						)
						structural = false
					else
						for j, field in ipairs(node.supports) do
							if ACCUSATION_FIELDS[field] ~= true then
								err(
									"node.deduction.supports_field",
									string.format("%s.supports[%d]", path, j),
									string.format(
										"Field tuduhan %q tidak dikenal; harus culprit, motive, atau method.",
										field
									)
								)
							end
						end
					end
				end

				if node.unlocks ~= nil and not isStringList(node.unlocks) then
					err("node.unlocks", path .. ".unlocks", "`unlocks` harus daftar id node.")
				end
			end
		end
	end

	--[[ D. Integritas referensi ------------------------------------------- ]]

	if structural then
		for i, node in ipairs(nodes) do
			local path = string.format("nodes[%d]", i)

			if node.variants ~= nil then
				for j, vid in ipairs(node.variants) do
					if not variantSeen[vid] then
						err(
							"node.variants.unknown",
							string.format("%s.variants[%d]", path, j),
							string.format("Varian %q tidak dikenal.", vid)
						)
					end
				end
			end

			if node.type == "clue_card" then
				local source = nodeById[node.source]
				if source == nil then
					err(
						"clue_card.source_unknown",
						path .. ".source",
						string.format("`source` %q bukan id node yang ada.", node.source)
					)
				elseif source.type ~= "evidence" then
					err(
						"clue_card.source_type",
						path .. ".source",
						string.format(
							"`source` %q bertipe %s, harus evidence.",
							node.source,
							source.type
						)
					)
				elseif source.yields ~= node.id then
					err(
						"clue_card.source_mismatch",
						path .. ".source",
						string.format(
							"Bukti %q menghasilkan %q, bukan %q — id Clue Card harus sama dengan `yields` bukti.",
							source.id,
							tostring(source.yields),
							node.id
						)
					)
				end
			end

			if node.type == "deduction" then
				for j, need in ipairs(node.needs) do
					local target = nodeById[need]
					if target == nil then
						err(
							"deduction.need_unknown",
							string.format("%s.needs[%d]", path, j),
							string.format("`needs` %q bukan id node yang ada.", need)
						)
					elseif target.type ~= "clue_card" and target.type ~= "deduction" then
						err(
							"deduction.need_type",
							string.format("%s.needs[%d]", path, j),
							string.format(
								"Deduksi hanya boleh menggabungkan clue_card atau deduction, bukan %s (%q).",
								target.type,
								need
							)
						)
					end
				end
			end

			if node.unlocks ~= nil then
				for j, target in ipairs(node.unlocks) do
					if nodeById[target] == nil then
						err(
							"node.unlocks_unknown",
							string.format("%s.unlocks[%d]", path, j),
							string.format("`unlocks` %q bukan id node yang ada.", target)
						)
					end
				end
			end
		end
	end

	--[[ E. Pernyataan saksi (PRD §4) --------------------------------------- ]]

	local statements: { any } = {}
	local rawStatements: any = case.statements
	if rawStatements ~= nil then
		if type(rawStatements) ~= "table" or #rawStatements == 0 then
			err(
				"case.statements",
				"statements",
				"`statements` harus berisi minimal satu pernyataan."
			)
		else
			for i, raw in ipairs(rawStatements) do
				local statement: any = raw
				local path = string.format("statements[%d]", i)
				if type(statement) ~= "table" then
					err("statement.not_table", path, "Pernyataan harus berupa object JSON.")
				else
					table.insert(statements, statement)
					if not isNonEmptyString(statement.who) then
						err("statement.who", path .. ".who", "`who` wajib diisi.")
					end
					if not isNonEmptyString(statement.text) then
						err("statement.text", path .. ".text", "`text` pernyataan wajib diisi.")
					end
					if type(statement.lie) ~= "boolean" then
						err("statement.lie", path .. ".lie", "`lie` wajib berupa boolean.")
					end
					if statement.variants ~= nil then
						if not isStringList(statement.variants) then
							err(
								"statement.variants",
								path .. ".variants",
								"`variants` harus daftar id varian."
							)
						else
							for j, svid in ipairs(statement.variants) do
								if not variantSeen[svid] then
									err(
										"statement.variants_unknown",
										string.format("%s.variants[%d]", path, j),
										string.format("Varian %q tidak dikenal.", svid)
									)
								end
							end
						end
					end
					if statement.lie == true then
						if not isNonEmptyString(statement.contradicted_by) then
							err(
								"statement.contradicted_by",
								path .. ".contradicted_by",
								"Pernyataan bohong wajib punya `contradicted_by` (id Clue Card)."
							)
						else
							local clue = nodeById[statement.contradicted_by]
							if clue == nil then
								err(
									"statement.contradicted_by_unknown",
									path .. ".contradicted_by",
									string.format(
										"Clue Card %q tidak ada.",
										statement.contradicted_by
									)
								)
							elseif clue.type ~= "clue_card" then
								err(
									"statement.contradicted_by_type",
									path .. ".contradicted_by",
									string.format(
										"`contradicted_by` harus clue_card, bukan %s.",
										clue.type
									)
								)
							end
						end
					end
				end
			end
		end
	else
		err("case.statements_missing", "statements", "`statements` wajib ada (PRD §4).")
	end

	--[[ F. Briefing per role (PRD §9) -------------------------------------- ]]

	if case.briefing == nil then
		err(
			"case.briefing",
			"briefing",
			"`briefing` wajib ada untuk searcher, handler, dan director."
		)
	elseif type(case.briefing) ~= "table" then
		err("case.briefing_type", "briefing", "`briefing` harus object berisi kunci per role.")
	else
		for _, role in ipairs(CaseGraph.ROLES) do
			if not isNonEmptyString(case.briefing[role]) then
				err(
					"briefing.role",
					"briefing." .. role,
					string.format("Briefing untuk role %s wajib diisi.", role)
				)
			end
		end
	end

	--[[ G. Pemeriksaan graf per varian ------------------------------------ ]]
	-- Dilewati bila masih ada kerusakan struktural: menjalankan penelusuran
	-- graf di atas data cacat hanya menghasilkan pesan turunan yang menyesatkan.

	if structural and #errors == 0 then
		local keyDeductions = case.key_deductions

		if keyDeductions ~= nil and keyDeductions < 1 then
			err("gate.key_deductions", "key_deductions", "`key_deductions` harus minimal 1.")
		end

		if
			case.case_type ~= nil
			and CASE_TYPES[case.case_type] == true
			and keyDeductions ~= nil
		then
			local expected = CaseGraph.REQUIRED_KEY_DEDUCTIONS[case.case_type]
			if keyDeductions ~= expected then
				err(
					"gate.key_deductions_type_mismatch",
					"key_deductions",
					string.format(
						"Kasus bertipe %s butuh %d Deduksi Kunci (PRD §5), bukan %d.",
						case.case_type,
						expected,
						keyDeductions
					)
				)
			end
		end

		for _, vid in ipairs(variantIds) do
			local vpath = string.format("variants[%s]", vid)
			local active = CaseGraph.activeNodes(case, vid)
			local reachable = CaseGraph.reachable(case, vid)

			-- G1. Tanpa dependensi melingkar (PRD §10).
			local cycle = CaseGraph.findCycle(case, vid)
			if cycle ~= nil then
				err(
					"graph.cycle",
					vpath,
					string.format("Dependensi melingkar: %s.", table.concat(cycle, " -> "))
				)
			end

			-- G2. Setiap kunci yang diminta bukti harus bisa didapat di varian ini.
			local owners = CaseGraph.keyOwners(case, vid)
			for _, node in ipairs(active) do
				if node.type == "evidence" then
					for _, key in ipairs(node.needs or {}) do
						if owners[key] == nil then
							err(
								"graph.key_unobtainable",
								string.format("variants[%s].%s.needs", vid, node.id),
								string.format(
									"Kunci %q tidak disediakan objek mana pun yang aktif di varian %s — rantai buntu.",
									key,
									vid
								)
							)
						end
					end
				end
			end

			-- G3. Tanpa rantai buntu: setiap node aktif harus bisa dicapai.
			for _, node in ipairs(active) do
				if reachable[node.id] ~= true then
					err(
						"graph.dead_end",
						string.format("variants[%s].%s", vid, node.id),
						string.format(
							"Node %q aktif di varian %s tetapi tidak bisa dicapai dari objek mana pun — rantai buntu.",
							node.id,
							vid
						)
					)
				end
			end

			-- G4. Setiap field tuduhan ditopang minimal satu deduksi.
			local supported: { [string]: number } = {}
			for _, node in ipairs(active) do
				if
					node.type == "deduction"
					and reachable[node.id] == true
					and type(node.supports) == "table"
				then
					for _, field in ipairs(node.supports) do
						supported[field] = (supported[field] or 0) + 1
					end
				end
			end
			for _, field in ipairs(CaseGraph.ACCUSATION_FIELDS) do
				if (supported[field] or 0) == 0 then
					err(
						"graph.field_unsupported",
						vpath,
						string.format(
							"Tidak ada deduksi aktif ber-`supports` %q di varian %s; field tuduhan itu tidak bisa ditopang (PRD §5).",
							field,
							vid
						)
					)
				end
			end

			-- G5. Minimal satu Kontradiksi bisa ditandai di varian ini.
			local markable = 0
			local variantStatements = 0
			local variantLiars = 0
			for _, statement in ipairs(statements) do
				if statementAppliesTo(statement, vid) then
					variantStatements = variantStatements + 1
					if statement.lie == true then
						variantLiars = variantLiars + 1
						if isNonEmptyString(statement.contradicted_by) then
							local clue = nodeById[statement.contradicted_by]
							if
								clue ~= nil
								and CaseGraph.isActive(clue, vid)
								and reachable[clue.id] == true
							then
								markable = markable + 1
							end
						end
					end
				end
			end
			if variantLiars == 0 then
				err(
					"statements.no_liar",
					vpath,
					string.format(
						"Tidak ada pernyataan bohong yang berlaku di varian %s; Kontradiksi tidak bisa ditandai (PRD §4).",
						vid
					)
				)
			end
			if markable == 0 then
				err(
					"graph.no_contradiction",
					vpath,
					string.format(
						"Tidak ada Kontradiksi yang bisa ditandai di varian %s: clue pembantah pernyataan bohong tidak aktif atau tidak tercapai.",
						vid
					)
				)
			end
			if variantStatements > 3 then
				warn(
					"statements.count",
					vpath,
					string.format(
						"%d pernyataan berlaku di varian %s; PRD §4 menyebut 2-3 saksi/tersangka.",
						variantStatements,
						vid
					)
				)
			end

			-- G6. Gerbang N dan jalur solusi penuh per varian.
			local solution = type(case.solution) == "table" and case.solution[vid] or nil
			if type(solution) ~= "table" then
				err(
					"solution.missing",
					string.format("solution.%s", vid),
					string.format("Varian %s wajib punya jalur solusi di `solution.%s`.", vid, vid)
				)
			else
				local required = solution.required_deductions
				if not isStringList(required) or #required == 0 then
					err(
						"solution.required_deductions",
						string.format("solution.%s.required_deductions", vid),
						"`required_deductions` wajib berisi daftar id deduksi kunci."
					)
				else
					local covered: { [string]: number } = {}
					for j, id in ipairs(required) do
						local rpath = string.format("solution.%s.required_deductions[%d]", vid, j)
						local node = nodeById[id]
						if node == nil then
							err(
								"solution.deduction_unknown",
								rpath,
								string.format("Deduksi %q tidak ada.", id)
							)
						elseif node.type ~= "deduction" then
							err(
								"solution.deduction_type",
								rpath,
								string.format(
									"Deduksi kunci %q bertipe %s, bukan deduction.",
									id,
									node.type
								)
							)
						elseif not CaseGraph.isActive(node, vid) then
							err(
								"solution.deduction_inactive",
								rpath,
								string.format("Deduksi %q tidak aktif di varian %s.", id, vid)
							)
						elseif reachable[id] ~= true then
							err(
								"solution.deduction_unreachable",
								rpath,
								string.format(
									"Deduksi kunci %q tidak tercapai di varian %s.",
									id,
									vid
								)
							)
						else
							if type(node.supports) == "table" then
								for _, field in ipairs(node.supports) do
									covered[field] = (covered[field] or 0) + 1
								end
							end
						end
					end

					for _, field in ipairs(CaseGraph.ACCUSATION_FIELDS) do
						if (covered[field] or 0) == 0 then
							err(
								"solution.field_uncovered",
								string.format("solution.%s", vid),
								string.format(
									"Jalur solusi varian %s tidak menutup field tuduhan %q (PRD §5).",
									vid,
									field
								)
							)
						end
					end

					if keyDeductions ~= nil and keyDeductions ~= #required then
						err(
							"gate.key_deductions_count",
							string.format("solution.%s.required_deductions", vid),
							string.format(
								"`key_deductions` bernilai %d tetapi jalur solusi varian %s punya %d deduksi kunci.",
								keyDeductions,
								vid,
								#required
							)
						)
					end
				end

				-- Solusi harus konsisten dengan tuduhan varian.
				for _, field in ipairs(CaseGraph.ACCUSATION_FIELDS) do
					local variant = nil
					for _, candidate in ipairs(case.variants) do
						if candidate.variant_id == vid then
							variant = candidate
							break
						end
					end
					if
						variant ~= nil
						and solution[field] ~= nil
						and solution[field] ~= variant[field]
					then
						err(
							"solution.variant_mismatch",
							string.format("solution.%s.%s", vid, field),
							string.format(
								"Solusi varian %s menulis %s=%q tetapi varian mendeklarasikan %q.",
								vid,
								field,
								tostring(solution[field]),
								tostring(variant[field])
							)
						)
					end
				end
			end

			-- G7. N tidak boleh melebihi deduksi yang benar-benar ada.
			local deductionCount = 0
			for _, node in ipairs(active) do
				if node.type == "deduction" and reachable[node.id] == true then
					deductionCount = deductionCount + 1
				end
			end
			if keyDeductions ~= nil and keyDeductions > deductionCount then
				err(
					"gate.key_deductions_exceeds",
					"key_deductions",
					string.format(
						"`key_deductions` bernilai %d tetapi varian %s hanya punya %d deduksi yang bisa dicapai.",
						keyDeductions,
						vid,
						deductionCount
					)
				)
			end
		end
	end

	return {
		ok = #errors == 0,
		errors = errors,
		warnings = warnings,
	}
end

function CaseValidator.isValid(case: any): boolean
	return CaseValidator.validate(case).ok
end

--[[
	Format Report menjadi teks yang bisa dicetak harness CLI.
]]
function CaseValidator.formatReport(report: Report): string
	local lines: { string } = {}
	table.insert(lines, string.format("status: %s", if report.ok then "LULUS" else "GAGAL"))
	table.insert(lines, string.format("errors: %d", #report.errors))
	for _, issue in ipairs(report.errors) do
		table.insert(lines, string.format("  [%s] %s: %s", issue.code, issue.path, issue.message))
	end
	table.insert(lines, string.format("warnings: %d", #report.warnings))
	for _, issue in ipairs(report.warnings) do
		table.insert(lines, string.format("  [%s] %s: %s", issue.code, issue.path, issue.message))
	end
	return table.concat(lines, "\n")
end

--[[
	Adapter untuk seam `CaseSource.setValidator` di `src/server/CaseSource.luau`.

	EXTA-32 mendeklarasikan kontrak `fn(caseTable) -> (ok, daftarMasalah)` dan
	menyisakan pengisinya untuk EXTA-33. EXTA-33 menyediakan `validate`, yang
	mengembalikan `Report`; fungsi inilah yang menjembatani keduanya, sehingga
	jalur validasi yang dipakai server saat start adalah jalur yang sama persis
	dengan yang diuji dari CLI.
]]
function CaseValidator.asLoaderValidator(case: any): (boolean, { string })
	local report = CaseValidator.validate(case)
	if report.ok then
		return true, {}
	end

	local problems: { string } = {}
	for _, issue in ipairs(report.errors) do
		table.insert(problems, string.format("[%s] %s: %s", issue.code, issue.path, issue.message))
	end
	return false, problems
end

return CaseValidator
