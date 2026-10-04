--!strict
--[[
	Papan Director (PRD §4, §5, §7).

	Isi berkas ini adalah aturan yang dipakai clue board Director:
	  * pernyataan saksi mana yang berlaku di varian sesi ini (PRD §4:
	    "Tiap kasus punya 2-3 pernyataan saksi/tersangka, minimal satu
	    berbohong");
	  * kapan sebuah Kontradiksi sah ditandai -- pernyataannya bohong DAN bukti
	    pembantahnya sudah dikumpulkan Director;
	  * berapa Deduksi Kunci yang sudah selesai, untuk gerbang form tuduhan
	    (PRD §5).

	Kenapa modul terpisah: aturan-aturan itu justru yang paling mudah salah dan
	paling murah diuji, sedangkan glue di `init.server.luau` menyentuh `game`
	dan karena itu tidak bisa dijalankan `lune`. Pemisahan yang sama sudah
	dipakai `PuzzleTableService` dan `AccusationService`.

	Murni: tidak menyentuh global Roblox. `CaseGraph` masuk sebagai ARGUMEN
	(pola yang sama dengan `PuzzleTableService.new(PuzzleTable)`), supaya modul
	ini bisa diuji dari CLI tanpa Studio.

	Yang sengaja TIDAK ada di sini: pemeriksaan resep kombinasi
	(`DeductionEngine`), keputusan gerbangnya (`DeductionEngine.gateOpen`), dan
	penurunan pinpoint sebuah Deduksi (`CaseGraph.primaryOrigin`). Semuanya
	sudah ada dan sudah diuji; modul ini hanya menyiapkan angka dan pernyataan
	yang mereka butuhkan.
]]

local DirectorBoardService = {}

--[[
	Satu pernyataan saksi, seperti yang dipakai server.

	`id` adalah indeks 1-based di `case.statements`, dan itulah identitas
	pernyataan -- BUKAN `who`. `data/cases/gallery_01.json` memuat dua
	pernyataan dengan `who = "guard"` (satu pembohong di varian `v_guard`, satu
	bukan), jadi `who` tidak unik dan tidak boleh dipakai sebagai kunci payload.
]]
export type Statement = {
	id: number,
	who: string,
	text: string,
	-- Server-only. Tidak pernah ikut ke client: `CaseLoader.projectForRole`
	-- yang merakit versi client, dan ia hanya menyalin `id`, `who`, `text`.
	lie: boolean,
	contradicted_by: string?,
}

export type Board = {
	case_id: string,
	variant_id: string,
	statements: { Statement },
	required_deductions: { [string]: boolean },
	required_count: number,
	-- N pada PRD §5 ("Form hanya terbuka jika N Deduksi Kunci selesai").
	key_deductions_required: number,
}

--[[
	Pesan penolakan penandaan Kontradiksi.

	Dua pesan saja, dan itu disengaja: pernyataan yang tidak bohong dan
	pernyataan bohong yang buktinya belum dikumpulkan memberi pesan yang SAMA.
	Kalau keduanya dibedakan, Director bisa menemukan pembohong dengan mencoba
	satu per satu pernyataan sampai pesannya berubah -- oracle yang menghapus
	justru bagian berpikirnya. Pesan "sudah ditandai" aman: ia hanya
	mengulang apa yang client sudah lakukan sendiri.
]]
DirectorBoardService.REJECT_REASON =
	"pernyataan itu belum terbantah oleh bukti yang sudah dikumpulkan"
DirectorBoardService.ALREADY_MARKED = "kontradiksi itu sudah ditandai"

local function idSet(ids: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(ids) ~= "table" then
		return set
	end
	for _, id in ids do
		if type(id) == "string" then
			set[id] = true
		end
	end
	return set
end

local function countKeys(set: { [any]: any }): number
	local count = 0
	for _ in set do
		count += 1
	end
	return count
end

--[[
	Membangun papan untuk satu sesi. Mengembalikan `nil` bila data kasusnya
	tidak berbentuk tabel -- pemanggil memperlakukannya sebagai kasus rusak,
	bukan sebagai sesi tanpa clue board.
]]
function DirectorBoardService.new(CaseGraph: any, case: any, variantId: string): Board?
	if type(case) ~= "table" then
		return nil
	end
	if type(variantId) ~= "string" or variantId == "" then
		return nil
	end

	local statements: { Statement } = {}
	-- `case` bertipe `any`, tapi `type(...) == "table"` mempersempitnya jadi
	-- `table`, dan iterasi `table` memberi elemen bertipe `table` juga --
	-- itulah kenapa isinya diambil lewat variabel terpisah di bawah.
	local rawStatements: any = case.statements
	if type(rawStatements) == "table" then
		for index, statement in ipairs(rawStatements) do
			if
				type(statement) == "table" and CaseGraph.statementAppliesTo(statement, variantId)
			then
				local raw = statement :: any
				local contradictedBy = raw.contradicted_by
				table.insert(statements, {
					id = index,
					who = tostring(raw.who),
					text = tostring(raw.text),
					lie = raw.lie == true,
					contradicted_by = if type(contradictedBy) == "string"
						then contradictedBy
						else nil,
				})
			end
		end
	end

	local variant = nil
	if type(case.solution) == "table" then
		variant = case.solution[variantId]
	end
	local requiredDeductions =
		idSet(if type(variant) == "table" then variant.required_deductions else nil)
	local requiredCount = countKeys(requiredDeductions)

	-- PRD §5: "N = 4 dari 6 untuk kasus standar ... Rumusnya kira-kira 65% dari
	-- total, dibulatkan ke atas." Yang dipakai di sini adalah ANGKA EKSPLISIT
	-- dari data kasus (`key_deductions`), bukan rumus 65% itu: rumus adalah
	-- penjelasan cara penulis kasus memilih angkanya, bukan aturan runtime.
	-- Cadangan di bawah hanya untuk kasus yang lupa mengisi field-nya, dan
	-- dicatat sebagai perbedaan supaya tidak diam-diam jadi aturan kedua.
	local declared = case.key_deductions
	local requiredGate: number
	if type(declared) == "number" and declared >= 1 and declared % 1 == 0 then
		requiredGate = declared
	else
		local byType = CaseGraph.REQUIRED_KEY_DEDUCTIONS[case.case_type]
		requiredGate = byType or requiredCount
	end

	return {
		case_id = tostring(case.case_id),
		variant_id = variantId,
		statements = statements,
		required_deductions = requiredDeductions,
		required_count = requiredCount,
		key_deductions_required = requiredGate,
	}
end

function DirectorBoardService.statementById(board: Board, id: number): Statement?
	for _, statement in board.statements do
		if statement.id == id then
			return statement
		end
	end
	return nil
end

--[[
	Memeriksa satu penandaan Kontradiksi (PRD §4).

	`obtainedClues` adalah himpunan id Clue Card yang SUDAH dimiliki Director --
	diisi glue saat sebuah meja bukti selesai. Syarat itu yang membuat
	penandaan bermakna: tanpa itu, Director bisa menandai kontradiksi sebelum
	bukti pembantahnya ada, dan gerbang tuduhan terbuka tanpa kerja deduksi.

	Mengembalikan `(diterima, alasan, pernyataan)`.
]]
function DirectorBoardService.checkMark(
	board: Board,
	statementId: any,
	obtainedClues: { [string]: boolean },
	marked: { [number]: boolean }
): (boolean, string?, Statement?)
	if type(statementId) ~= "number" or statementId % 1 ~= 0 then
		return false, DirectorBoardService.REJECT_REASON, nil
	end

	if marked[statementId] then
		return false, DirectorBoardService.ALREADY_MARKED, nil
	end

	local statement = DirectorBoardService.statementById(board, statementId)
	if statement == nil or not statement.lie then
		return false, DirectorBoardService.REJECT_REASON, nil
	end

	local clueId = statement.contradicted_by
	if clueId == nil or not obtainedClues[clueId] then
		return false, DirectorBoardService.REJECT_REASON, nil
	end

	return true, nil, statement
end

--[[
	Berapa Deduksi Kunci yang sudah selesai (PRD §5).

	Yang dihitung hanya deduksi yang ADA di `solution[variant].required_deductions`
	-- menyelesaikan deduksi bonus tidak boleh mendekatkan tim ke form tuduhan.
	Kasus tanpa daftar itu (data lama) jatuh ke "semua deduksi yang selesai",
	supaya gerbangnya tetap berfungsi; validator EXTA-33 sudah mewajibkan daftar
	itu untuk kasus baru.
]]
function DirectorBoardService.keyDeductionsDone(
	board: Board,
	completed: { [string]: boolean }
): number
	if board.required_count > 0 then
		local count = 0
		for id in board.required_deductions do
			if completed[id] then
				count += 1
			end
		end
		return count
	end
	return countKeys(completed)
end

function DirectorBoardService.countMarked(marked: { [number]: boolean }): number
	return countKeys(marked)
end

return DirectorBoardService
