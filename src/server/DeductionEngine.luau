--!strict
-- Mesin deduksi (PRD §4, §5).
--
-- PRD §15: "Pemeriksaan resep deduksi dan tuduhan hanya di server." Modul ini
-- adalah tempat pemeriksaan itu hidup. Client hanya mengirim daftar id Clue
-- Card; keputusan ada di sini.
--
-- Murni: tanpa global Roblox, bisa diuji dari CLI.

local DeductionEngine = {}

export type Recipe = {
	id: string,
	-- Id Clue Card yang harus digabungkan. Urutan tidak penting.
	needs: { string },
}

export type Engine = {
	recipes: { Recipe },
}

export type Result = {
	ok: boolean,
	deductionId: string?,
	reason: string?,
}

-- Membangun mesin dari daftar resep. Resep duplikat ditolak: dua resep dengan
-- himpunan `needs` yang sama membuat hasil deduksi tidak deterministik, dan
-- itu bug data, bukan bug runtime.
function DeductionEngine.new(recipes: { Recipe }): (Engine?, string?)
	local seen: { [string]: boolean } = {}
	for _, recipe in recipes do
		if #recipe.needs < 2 then
			return nil, string.format("resep '%s' butuh minimal 2 Clue Card", recipe.id)
		end
		if seen[recipe.id] then
			return nil, string.format("id deduksi duplikat: %s", recipe.id)
		end
		seen[recipe.id] = true
	end

	return { recipes = recipes }, nil
end

local function keyOf(ids: { string }): string
	local sorted = table.clone(ids)
	table.sort(sorted)
	return table.concat(sorted, "|")
end

-- Indeks resep: himpunan id -> resep. Dipakai supaya pemeriksaan kombinasi
-- tidak perlu memindai seluruh daftar resep tiap kali Director menggabungkan
-- kartu (PRD §4: penggabungan terjadi berulang selama sesi).
function DeductionEngine.index(engine: Engine): { [string]: Recipe }
	local byKey: { [string]: Recipe } = {}
	for _, recipe in engine.recipes do
		byKey[keyOf(recipe.needs)] = recipe
	end
	return byKey
end

-- Memeriksa satu kombinasi Clue Card.
--
-- `completed` adalah himpunan id deduksi yang sudah selesai; deduksi yang sama
-- tidak bisa dihasilkan dua kali.
function DeductionEngine.combine(
	engine: Engine,
	clueIds: { string },
	completed: { [string]: boolean }
): Result
	if #clueIds < 2 then
		return { ok = false, deductionId = nil, reason = "butuh minimal 2 Clue Card" }
	end

	local unique: { [string]: boolean } = {}
	for _, id in clueIds do
		if unique[id] then
			return { ok = false, deductionId = nil, reason = "Clue Card yang sama dipakai dua kali" }
		end
		unique[id] = true
	end

	local recipe = DeductionEngine.index(engine)[keyOf(clueIds)]
	if recipe == nil then
		return {
			ok = false,
			deductionId = nil,
			reason = "kombinasi tidak cocok dengan resep mana pun",
		}
	end

	if completed[recipe.id] then
		return { ok = false, deductionId = nil, reason = "deduksi ini sudah selesai" }
	end

	return { ok = true, deductionId = recipe.id, reason = nil }
end

-- PRD §5: gerbang form tuduhan terbuka bila N Deduksi Kunci selesai dan
-- minimal 1 Kontradiksi ditandai.
function DeductionEngine.gateOpen(
	keyDeductionsDone: number,
	keyDeductionsRequired: number,
	contradictions: number,
	contradictionsRequired: number
): boolean
	return keyDeductionsDone >= keyDeductionsRequired and contradictions >= contradictionsRequired
end

-- PRD §5: "Feedback salah: hanya 'X dari 3 benar', tidak menyebutkan field mana."
-- Mengembalikan JUMLAH field yang benar, bukan daftar field-nya -- bentuk
-- kembalian ini yang membuat kebocoran field mustahil secara struktural.
function DeductionEngine.correctFieldCount(
	accusation: { [string]: string },
	solution: { [string]: string }
): number
	local correct = 0
	for field, value in accusation do
		if solution[field] == value then
			correct += 1
		end
	end
	return correct
end

return DeductionEngine
