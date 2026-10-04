--!strict
-- Titik masuk server (PRD §15).
--
-- Tanggung jawab berkas ini:
--   1. Guard arsitektur: menolak start bila ada view client yang membocorkan
--      field rahasia.
--   2. Membuat RemoteEvent dari satu sumber kebenaran (`Net.REMOTE_NAMES`),
--      supaya daftar remote tidak bisa berbeda dari kontrak datanya.
--   3. Memuat kasus dari `ServerStorage` dan memilih varian dari seed sesi.
--   4. Menjalankan alur lobby dan menetapkan role.
--   5. Menangani remote yang WAJIB diperiksa di server: Deduce dan Accuse.
--
-- Yang sengaja TIDAK ada di sini: loop permainan lengkap (meja puzzle, clue
-- board, gerak NPC). Itu scope minggu 1-6 (PRD §17). Modul-modulnya sudah ada
-- dan sudah punya kontrak, jadi minggu-minggu itu mengisi pemanggil, bukan
-- menulis ulang logika.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Roles = require(Shared.Roles)
local PingPhrases = require(Shared.PingPhrases)
local LocationMap = require(Shared.LocationMap)
local CaseValidator = require(Shared.case.CaseValidator)
local CaseGraph = require(Shared.case.CaseGraph)
local PuzzleTable = require(Shared.PuzzleTable)

local CaseLoader = require(script.CaseLoader)
local DeductionEngine = require(script.DeductionEngine)
local AccusationService = require(script.AccusationService)
local RoleAssignment = require(script.RoleAssignment)
local Matchmaking = require(script.Matchmaking)
local NPCController = require(script.NPCController)
local TelemetryService = require(script.TelemetryService)
local PuzzleTableService = require(script.PuzzleTableService)
local DirectorBoardService = require(script.DirectorBoardService)

-- `NPCController` dipakai di `startSession` untuk menghitung role mana yang
-- diisi NPC (PRD §8). Yang BELUM ada adalah loop yang menjalankan aksinya --
-- `nextAction`, takeover AFK, dan rejoin adalah deliverable minggu 5 (PRD §17),
-- dan kontraknya sudah diuji di `tests/npc.spec.luau`.

-- ---------------------------------------------------------------------------
-- 1. Guard arsitektur
-- ---------------------------------------------------------------------------

local viewsOk, viewProblems = Net.validateViews()
if not viewsOk then
	error("[Triangulate] Kontrak Net bocor, start dibatalkan: " .. table.concat(viewProblems, "; "))
end

-- ---------------------------------------------------------------------------
-- 1b. Validasi kasus (EXTA-33 diisi ke seam EXTA-32)
-- ---------------------------------------------------------------------------

-- Sebelum ini seam `setValidator` dibiarkan kosong karena validatornya belum
-- ada. Sekarang ada, dan dipasang di sini: kasus yang gagal skema atau graf
-- menghentikan start, bukan menghasilkan sesi setengah jalan.
CaseLoader.setValidator(CaseValidator.asLoaderValidator)

-- ---------------------------------------------------------------------------
-- 2. RemoteEvent dari satu sumber kebenaran
-- ---------------------------------------------------------------------------

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"

local remotes: { [string]: RemoteEvent } = {}
for _, name in Net.REMOTE_NAMES do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remotes[name] = remote
	remote.Parent = remotesFolder
end

remotesFolder.Parent = Shared

-- ---------------------------------------------------------------------------
-- 3. Verifikasi konfigurasi place
-- ---------------------------------------------------------------------------

-- PRD §15: "MaxPlayers = 3". `Players.MaxPlayers` TIDAK bisa disetel dari
-- script -- dokumentasi: "This property can only be set through a specific
-- place's settings on the Creator Dashboard."
-- -> https://create.roblox.com/docs/reference/engine/classes/Players
-- Karena itu kode hanya bisa memverifikasi, dan itu yang dilakukan di sini.
if Players.MaxPlayers ~= Config.MAX_PLAYERS then
	warn(
		string.format(
			"[Triangulate] Players.MaxPlayers = %d, diharapkan %d. Setel di Creator Dashboard: "
				.. "Configure > Places > Access > Maximum Visitor Count.",
			Players.MaxPlayers,
			Config.MAX_PLAYERS
		)
	)
end

-- ---------------------------------------------------------------------------
-- 4. State sesi
-- ---------------------------------------------------------------------------

type Session = {
	caseId: string,
	case: CaseLoader.Case,
	variant: CaseLoader.CaseVariant,
	-- Id varian yang dipilih. `CaseVariant` tidak membawa `variant_id` (lihat
	-- `CaseLoader.pickVariant`), jadi id-nya disimpan terpisah di sini: node
	-- ber-`variants` disaring terhadap nilai ini.
	variantId: string?,
	roles: { [number]: string },
	-- PRD §8: "Jika belum 3 manusia, role kosong diisi NPC." `roles` di atas
	-- di-key oleh `UserId`, dan NPC tidak punya UserId -- jadi role yang tidak
	-- dipegang manusia dicatat terpisah di sini. Perilaku NPC-nya sendiri baru
	-- ada di minggu 5 (PRD §17); yang sudah nyata sekarang adalah catatannya,
	-- sehingga minggu 5 menambah pelaku, bukan mencari tahu role mana yang
	-- kosong.
	npcRoles: { [string]: boolean },
	engine: DeductionEngine.Engine,
	completedDeductions: { [string]: boolean },
	-- Papan Director sesi ini (PRD §4, §5, §7): pernyataan saksi yang berlaku
	-- di varian ini, target yang dibuka tiap Deduksi, daftar Deduksi Kunci, dan
	-- angka gerbang N dari data kasus.
	board: DirectorBoardService.Board?,
	-- Id Clue Card yang SUDAH dimiliki Director. Ini yang membuat penandaan
	-- Kontradiksi bermakna (PRD §4): tanpa daftar ini Director bisa menandai
	-- kontradiksi sebelum bukti pembantahnya ada.
	obtainedClues: { [string]: boolean },
	-- Id pernyataan (indeks 1-based) yang sudah ditandai kontradiksi.
	markedContradictions: { [number]: boolean },
	-- Meja puzzle sesi ini (PRD §4, §15, §17 minggu 1). Dibangun sekali saat
	-- sesi mulai dari node bukti yang aktif pada varian yang dipilih.
	puzzle: PuzzleTableService.Service,
	accusation: AccusationService.Session,
	telemetry: TelemetryService.Session,
	startedAt: number,
}

local session: Session? = nil
local lobby = Matchmaking.newLobby(os.clock())

local function roleOf(userId: number): string?
	local current = session
	if current == nil then
		return nil
	end
	return current.roles[userId]
end

-- Mengirim payload ke satu role, sudah diproyeksikan sesuai view-nya.
-- `Net.forRole` mengembalikan `nil` bila view/role tidak dikenal, dan `nil`
-- berarti "jangan kirim" -- bukan "kirim kosong".
local function fireToRole(remoteName: string, view: string, payload: { [string]: any }): ()
	local remote = remotes[remoteName]
	if remote == nil then
		warn(string.format("[Triangulate] remote '%s' tidak terdaftar", remoteName))
		return
	end

	local current = session
	if current == nil then
		return
	end

	for userId, role in current.roles do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			local projected = Net.forRole(view, role, payload)
			if projected ~= nil then
				remote:FireClient(player, projected)
			end
		end
	end
end

-- Sama seperti `fireToRole`, tetapi melewati satu pemain. Dipakai relay ping:
-- pengirim tidak perlu menerima ping-nya sendiri, dan mengirimkannya akan
-- membuat satu ping tampil dua kali di layar pengirim.
local function fireToRoleExcept(
	remoteName: string,
	view: string,
	payload: { [string]: any },
	exceptUserId: number
): ()
	local remote = remotes[remoteName]
	if remote == nil then
		warn(string.format("[Triangulate] remote '%s' tidak terdaftar", remoteName))
		return
	end

	local current = session
	if current == nil then
		return
	end

	for userId, role in current.roles do
		if userId ~= exceptUserId then
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				local projected = Net.forRole(view, role, payload)
				if projected ~= nil then
					remote:FireClient(player, projected)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 5. Mulai sesi
-- ---------------------------------------------------------------------------

--[[
	Menghitung status gerbang form tuduhan (PRD §5).

	PRD §5: "Form hanya terbuka jika N Deduksi Kunci selesai dan minimal 1
	Kontradiksi ditandai." Angka N datang dari data kasus (`case.key_deductions`),
	bukan dari rumus 65% di PRD dan bukan dari `Config.KEY_DEDUCTIONS` --
	`DirectorBoardService.new` yang memutuskan presedensinya, dan keputusan
	keputusan gerbangnya tetap milik `DeductionEngine.gateOpen` yang sudah diuji.

	`gate_open` yang dikirim ke client adalah INFORMASI, bukan pengaman:
	`handleAccuse` memanggil helper yang sama dan menolak bila tertutup.
]]
local function gateState(current: Session): { [string]: any }
	local board = current.board
	if board == nil then
		-- Tanpa papan, gerbangnya tidak bisa dihitung. Yang dipilih adalah
		-- MENUTUP gerbang, bukan membukanya: form tuduhan yang terbuka tanpa
		-- data deduksi akan mengubah kasus jadi tebak-tebakan.
		return {
			deductions_done = 0,
			key_deductions_required = 0,
			contradictions_marked = 0,
			contradictions_required = Config.MIN_CONTRADICTIONS,
			gate_open = false,
		}
	end

	local done = DirectorBoardService.keyDeductionsDone(board, current.completedDeductions)
	local marked = DirectorBoardService.countMarked(current.markedContradictions)

	return {
		deductions_done = done,
		key_deductions_required = board.key_deductions_required,
		contradictions_marked = marked,
		contradictions_required = Config.MIN_CONTRADICTIONS,
		gate_open = DeductionEngine.gateOpen(
			done,
			board.key_deductions_required,
			marked,
			Config.MIN_CONTRADICTIONS
		),
	}
end

--[[
	Mengirim status sesi terkini ke semua pemain.

	Yang penting di sini: `gate_open` dihitung ulang setiap kali status dikirim,
	sehingga Director melihat form tuduhan terbuka tepat saat syaratnya
	terpenuhi, bukan menebak-nebak dari jumlah deduksi.
]]
local function pushSessionState(current: Session): ()
	local gate = gateState(current)
	fireToRole("SessionState", "session_state", {
		case_id = current.caseId,
		role = nil,
		phase = "Investigasi",
		seconds_left = 0,
		chains = {},
		deductions_done = gate.deductions_done,
		key_deductions_required = gate.key_deductions_required,
		contradictions_marked = gate.contradictions_marked,
		contradictions_required = gate.contradictions_required,
		gate_open = gate.gate_open,
	})
end

--[[
	Progres tiap meja untuk Table Preview (PRD §7).

	Bentuknya sengaja datar dan hanya angka: `node_id`, `placed`, `total`,
	`solved`. Yang TIDAK ikut: potongan, posisi, sel tujuan, dan `correct` --
	ketiganya server-only (`src/shared/PuzzleTable.luau`), dan mengirimnya akan
	mengubah pratinjau read-only menjadi kendali meja.

	`puzzle_id` dipakai sebagai identitas di payload, bukan `node_id`: itu nama
	yang sama dengan yang dipakai `puzzle_state`, sehingga client bisa
	mencocokkan pratinjau dengan meja yang sedang digambar.
]]
local function tablePreviewEntries(puzzle: PuzzleTableService.Service): { { [string]: any } }
	local entries: { { [string]: any } } = {}
	for _, nodeId in puzzle.order do
		local entry = puzzle.entries[nodeId]
		if entry ~= nil then
			local placed, total = PuzzleTableService.progress(puzzle, nodeId)
			table.insert(entries, {
				puzzle_id = entry.puzzle_id,
				puzzle_type = entry.puzzle_type,
				placed = placed,
				total = total,
				solved = entry.solved,
			})
		end
	end
	return entries
end

local function startSession(): ()
	if session ~= nil then
		return
	end

	local casesFolder = ServerStorage:FindFirstChild("Cases")
	if casesFolder == nil then
		warn("[Triangulate] ServerStorage.Cases tidak ada; sesi tidak bisa dimulai.")
		return
	end

	local caseIds = CaseLoader.availableCaseIds(casesFolder)
	if #caseIds == 0 then
		warn("[Triangulate] tidak ada kasus di ServerStorage.Cases; sesi tidak bisa dimulai.")
		return
	end

	local caseId = caseIds[1]
	local loaded = CaseLoader.load(casesFolder, caseId)

	-- PRD §10: "Seed server memilih cabang saat sesi dibuat."
	-- Pemilihan ini terjadi di server dan hasilnya tidak pernah dikirim ke client.
	local rng = Random.new(os.time())
	local roll = rng:NextNumber()
	local variant = CaseLoader.pickVariant(loaded, roll)
	-- `CaseVariant` tidak membawa `variant_id`, jadi indeksnya diambil dari
	-- fungsi yang sama dengan `roll` yang sama. Node bukti ber-`variants`
	-- (mis. `ev_ledger`) disaring terhadap id ini -- membiarkannya hidup akan
	-- mengirim bukti milik cabang lain ke client.
	local variantId: string? = nil
	local rawVariants = (loaded :: any).variants
	if type(rawVariants) == "table" then
		local chosen = rawVariants[CaseLoader.pickVariantIndex(loaded, roll)]
		if type(chosen) == "table" and type(chosen.variant_id) == "string" then
			variantId = chosen.variant_id
		end
	end

	local players = Players:GetPlayers()
	local refs: { RoleAssignment.PlayerRef } = {}
	for _, player in players do
		local prefs = Roles.ALL
		table.insert(refs, {
			id = player.UserId,
			preferences = prefs,
			recentRoles = {},
			isNew = true,
		})
	end

	local assigned = RoleAssignment.assign(refs, Roles.ALL, {
		fairnessStreak = Roles.FAIRNESS_STREAK,
		newPlayerExcludedRole = Roles.NEW_PLAYER_EXCLUDED_ROLE,
	})

	-- PRD §8: role yang tidak dipegang manusia diisi NPC. Untuk sekarang ini
	-- hanya dicatat dan dilog; `NPCController` (sudah ada dan sudah diuji di
	-- `tests/npc.spec.luau`) belum punya loop yang menjalankannya -- itu
	-- deliverable minggu 5 (PRD §17).
	--
	-- Dipakai `NPCController.rolesToFill`, bukan `Matchmaking.rolesWithoutHumans`,
	-- karena keduanya menjawab pertanyaan berbeda: `rolesWithoutHumans` = role
	-- yang tidak ada manusianya, `rolesToFill` = role yang benar-benar diisi
	-- NPC. Bedanya adalah role yang kosong TAPI tidak boleh diisi NPC -- pada
	-- MVP itu Director, karena NPC Director adalah P1 (PRD §8 tabel prioritas
	-- NPC, dan §16). Perbedaan itu dilaporkan, bukan didiamkan.
	local humanRoles: { [string]: boolean } = {}
	for _, role in assigned do
		humanRoles[role] = true
	end

	local npcRoles: { [string]: boolean } = {}
	for _, role in NPCController.rolesToFill(humanRoles, Roles.ALL, Roles.NPC_FILLABLE) do
		npcRoles[role] = true
	end

	local unstaffed: { string } = {}
	for _, role in Matchmaking.rolesWithoutHumans(Roles.ALL, assigned) do
		if not npcRoles[role] then
			table.insert(unstaffed, role)
		end
	end

	if next(npcRoles) ~= nil then
		local names: { string } = {}
		for role in npcRoles do
			table.insert(names, role)
		end
		table.sort(names)
		print(string.format("[Triangulate] role diisi NPC: %s", table.concat(names, ", ")))
	end
	if #unstaffed > 0 then
		-- Sesi tetap jalan: PRD §5 dan §16 tidak mewajibkan ketiga role ada
		-- manusia, dan §8 mengizinkan mode 2 pemain. Yang tidak boleh terjadi
		-- adalah role ini diam-diam dianggap terisi.
		warn(
			string.format(
				"[Triangulate] role tanpa manusia dan tanpa NPC pada MVP: %s (NPC Director = P1, PRD §8/§16)",
				table.concat(unstaffed, ", ")
			)
		)
	end

	local recipes: { DeductionEngine.Recipe } = {}
	for _, node in loaded.nodes do
		local kind = node.kind
		if kind == nil then
			kind = node.type
		end
		if kind == "deduction" and node.needs ~= nil then
			table.insert(recipes, { id = node.id, needs = node.needs })
		end
	end

	local engine, engineProblem = DeductionEngine.new(recipes)
	if engine == nil then
		warn(
			string.format(
				"[Triangulate] resep deduksi kasus '%s' tidak sah: %s",
				caseId,
				tostring(engineProblem)
			)
		)
		return
	end

	local solution: { [string]: string } = {
		culprit = variant.culprit,
		motive = variant.motive,
		method = variant.method,
	}

	session = {
		caseId = caseId,
		case = loaded,
		variant = variant,
		variantId = variantId,
		roles = assigned,
		npcRoles = npcRoles,
		engine = engine,
		completedDeductions = {},
		-- Papan Director dibangun dari data kasus + varian yang sudah dipilih
		-- (PRD §4). `nil` di sini berarti data kasus tidak bisa dibaca sebagai
		-- papan -- sesi tetap jalan tanpa clue board, dan itu dilaporkan,
		-- bukan didiamkan.
		board = DirectorBoardService.new(CaseGraph, loaded, variantId or ""),
		obtainedClues = {},
		markedContradictions = {},
		puzzle = PuzzleTableService.new(PuzzleTable),
		accusation = AccusationService.newSession(
			solution,
			Config.ACCUSATION_FIELDS,
			Config.MAX_ACCUSATIONS
		),
		telemetry = TelemetryService.newSession(os.clock(), nil, variantId),
		startedAt = os.clock(),
	}

	-- Meja puzzle sesi ini (PRD §4, §15). Node bukti yang hidup pada varian
	-- yang dipilih menjadi meja; tipe puzzle yang belum dikenal DILEWATI, bukan
	-- menggagalkan sesi -- satu node bertipe baru di data kasus tidak boleh
	-- menjatuhkan sesi tiga pemain. Yang dilewati dicatat supaya ketahuan.
	local puzzleEntries, puzzleSkipped = PuzzleTableService.build(
		session.puzzle,
		(loaded :: any).nodes,
		variantId,
		Config.TABLE_WIDTH,
		Config.TABLE_HEIGHT,
		function(): number
			return rng:NextNumber()
		end
	)
	for _, nodeId in puzzleSkipped do
		warn(
			string.format(
				"[Triangulate] node bukti '%s' punya tipe puzzle yang belum dikenal; dilewati",
				nodeId
			)
		)
	end
	for _, entry in puzzleEntries do
		PuzzleTableService.register(session.puzzle, entry)
	end

	-- Briefing per role. PRD §9: Role Card berisi "Kamu tahu apa / Tidak tahu
	-- apa / Tugas pertamamu". Tiap role menerima proyeksi berbeda, dan tidak
	-- ada role yang menerima field solusi.
	--
	-- PRD §4: "Tiap kasus punya 2-3 pernyataan saksi/tersangka, minimal satu
	-- berbohong." Saksi pembohong itu milik SATU varian (lihat `variants` di
	-- `$defs.statement`), jadi pernyataan yang dikirim ke Director tidak boleh
	-- diambil dari `briefings.Director.statements` apa adanya -- daftar statis
	-- itu hanya memuat pernyataan yang berlaku di semua cabang. Daftar per
	-- varian dihitung `CaseLoader.projectForRole`, modul yang sama yang dipakai
	-- untuk menyaring node; menyaring ulang di sini akan jadi salinan kedua
	-- dari aturan `CaseGraph.statementAppliesTo`.
	local briefings = (loaded :: any).briefings
	if type(briefings) == "table" then
		local directorStatements: { any } = {}
		if variantId ~= nil then
			local projectedDirector = CaseLoader.projectForRole(loaded, variantId, "Director")
			if
				type(projectedDirector) == "table"
				and type(projectedDirector.statements) == "table"
			then
				directorStatements = projectedDirector.statements
			end
		end

		for userId, role in assigned do
			local player = Players:GetPlayerByUserId(userId)
			local briefing = briefings[role]
			if player ~= nil and type(briefing) == "table" then
				-- Disalin, bukan dimutasi: `briefing` masih menunjuk ke tabel
				-- di dalam `loaded`, dan menulis ke sana akan mengubah data
				-- kasus yang di-cache untuk sesi berikutnya.
				local payload: { [string]: any } = table.clone(briefing)
				if role == Roles.DIRECTOR and #directorStatements > 0 then
					payload.statements = directorStatements
				end

				local projected = Net.forRole("briefing", role, payload)
				if projected ~= nil then
					remotes.SessionState:FireClient(player, projected)
				end
			end
		end
	end

	-- PRD §5: ruang pilihan form tuduhan. Ini kandidat, bukan jawaban.
	local options = {
		suspects = (loaded :: any).suspects,
		motives = (loaded :: any).motives,
		methods = (loaded :: any).methods,
	}
	fireToRole("SessionState", "accusation_options", options)

	-- PRD §4: pernyataan saksi di clue board Director sudah menyeberang lewat
	-- `briefing.statements` di atas -- `CaseLoader.projectForRole` yang
	-- menyaringnya per varian dan membuang `lie`/`contradicted_by`/`variants`.
	-- Remote terpisah untuk daftar yang sama hanya akan jadi jalur kedua yang
	-- bisa menyimpang dari yang pertama.
	if session.board == nil then
		warn(
			string.format(
				"[Triangulate] kasus '%s' tidak bisa dibaca sebagai papan Director; clue board dinonaktifkan",
				caseId
			)
		)
	end

	-- PRD §7: "Table Preview: Director melihat thumbnail meja Handler
	-- (read-only) supaya tahu progres tanpa bertanya." Yang dikirim hanya
	-- progres (terpasang/total) per meja -- bukan potongan, bukan posisi,
	-- bukan sel tujuan.
	fireToRole("TablePreview", "table_preview", {
		entries = tablePreviewEntries(session.puzzle),
	})

	-- Gerbang awal (PRD §5). Saat sesi mulai ia pasti tertutup -- 0 deduksi,
	-- 0 kontradiksi -- tapi mengirimnya sekarang membuat clue board tidak perlu
	-- menebak keadaan awal.
	pushSessionState(session)

	-- Meja pertama yang belum selesai dikirim ke Handler dan Director. Searcher
	-- tidak menerimanya: `Net.CLIENT_VIEWS.puzzle_state` sengaja tidak punya
	-- entri untuknya -- ia ada di lokasi, bukan di meja (PRD §3), dan
	-- `fireToRole` melewati role yang view-nya `nil`.
	local first = PuzzleTableService.firstUnsolved(session.puzzle)
	if first ~= nil then
		fireToRole("PuzzleState", "puzzle_state", PuzzleTable.clientPayload(first.state))
	else
		warn(string.format("[Triangulate] kasus '%s' tidak punya meja puzzle aktif", caseId))
	end
end

-- ---------------------------------------------------------------------------
-- 6. Handler remote yang wajib diperiksa di server
-- ---------------------------------------------------------------------------

-- PRD §15: "Pemeriksaan resep deduksi dan tuduhan hanya di server."
-- Dokumentasi Roblox: "Every piece of data sent from a client must be validated
-- by the server before it's used."
-- -> https://create.roblox.com/docs/scripting/security/client-server-boundary

local function handleDeduce(player: Player, clueIds: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role ~= "Director" then
		-- Hanya Director yang menggabungkan Clue Card (PRD §4).
		return
	end

	if type(clueIds) ~= "table" then
		return
	end

	local ids: { string } = {}
	for _, value in clueIds :: { any } do
		if type(value) ~= "string" then
			return
		end
		table.insert(ids, value)
	end

	local result = DeductionEngine.combine(current.engine, ids, current.completedDeductions)
	if not result.ok or result.deductionId == nil then
		-- PRD §5 melarang menyebut field mana yang salah pada tuduhan, tapi ini
		-- bukan tuduhan: ini pemeriksaan resep Clue Card, dan `DeductionEngine`
		-- sudah mengembalikan alasan yang tidak menyebut resep mana pun
		-- ("kombinasi tidak cocok dengan resep mana pun"). Tanpa alasan,
		-- Director tidak bisa membedakan kartu belum lengkap dari kombinasi
		-- salah -- dua hal yang menuntut tindakan berbeda.
		--
		-- Yang TIDAK dikirim: daftar resep, id deduksi yang mendekati cocok,
		-- atau field `supports` mana pun. `result.reason` saja.
		fireToRole("DeductionResult", "deduction", {
			id = nil,
			clue_ids = ids,
			pinpoint = nil,
			pinpoint_label = nil,
			unlocks = nil,
			reason = result.reason,
		})
		return
	end

	current.completedDeductions[result.deductionId] = true

	-- PRD §4: "Deduksi menaruh pinpoint baru di map dan membuka target
	-- baru." Pinpoint diturunkan dari graf, bukan dibaca dari field
	-- `unlocks` di data: `unlocks` adalah busur dependensi yang nyata
	-- (lihat `CaseGraph.dependenciesOf`), jadi menambahkannya ke kasus yang
	-- sudah lulus gate berarti mengubah graf dan bisa memunculkan
	-- `graph.cycle`/`graph.dead_end`. Turunan tidak menyentuh data.
	local pinpoint: string? = nil
	if current.variantId ~= nil then
		pinpoint = CaseGraph.primaryOrigin(current.case, current.variantId, result.deductionId)
	end

	-- Label pinpoint diambil dari node kasusnya, bukan dikarang di sini: yang
	-- menyeberang tetap kalimat yang sudah ditulis penulis kasus, dan client
	-- tidak perlu tabel terjemahan id -> nama.
	local pinpointLabel: string? = nil
	if pinpoint ~= nil then
		local pinNode = CaseGraph.nodeIndex(current.case)[pinpoint]
		if pinNode ~= nil and type(pinNode.label) == "string" then
			pinpointLabel = pinNode.label
		end
	end

	-- `unlocks` tetap dikirim apa adanya dari data. Kedua kasus minggu 6
	-- tidak punya `unlocks` sama sekali, jadi nil memang jawaban yang
	-- benar -- mengarang daftar di sini akan menampilkan target yang tidak
	-- ada di kasus.
	local node = CaseGraph.nodeIndex(current.case)[result.deductionId]
	local unlocks: { string }? = nil
	if node ~= nil and type(node.unlocks) == "table" and #node.unlocks > 0 then
		unlocks = node.unlocks
	end

	-- PRD §12: deduksi adalah salah satu peristiwa yang diukur. `deduction`
	-- sudah ada di `EventKind` sejak awal tetapi belum pernah dicatat,
	-- sehingga jumlah deduksi per role selalu nol di ringkasan.
	TelemetryService.record(current.telemetry, {
		kind = "deduction",
		role = role,
		t = os.clock(),
		detail = result.deductionId,
	})

	fireToRole("DeductionResult", "deduction", {
		id = result.deductionId,
		clue_ids = ids,
		pinpoint = pinpoint,
		pinpoint_label = pinpointLabel,
		unlocks = unlocks,
		reason = nil,
	})

	-- PRD §7: "Pinpoint: Director menaruh marker yang terlihat di dunia
	-- Searcher." Remote `Pinpoint` sudah ada sejak scaffold tetapi belum
	-- pernah ditembakkan -- inilah pemanggil pertamanya.
	if pinpoint ~= nil then
		fireToRole("Pinpoint", "pinpoint", {
			id = pinpoint,
			label = pinpointLabel,
		})
	end

	-- Gerbang bisa saja baru terbuka oleh deduksi ini (PRD §5).
	pushSessionState(current)
end

local function handleAccuse(player: Player, accusation: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role ~= "Director" then
		-- PRD §5: Director yang mengisi form tuduhan.
		return
	end

	if type(accusation) ~= "table" then
		return
	end

	-- PRD §5: "Form hanya terbuka jika N Deduksi Kunci selesai dan minimal 1
	-- Kontradiksi ditandai." Gerbang ini diperiksa DI SERVER, bukan hanya
	-- disembunyikan di UI: client yang mengirim form mentah pun tetap ditolak.
	local gate = gateState(current)
	if not gate.gate_open then
		warn(
			string.format(
				"[Triangulate] tuduhan ditolak: gerbang belum terbuka (%d/%d deduksi kunci, %d/%d kontradiksi)",
				gate.deductions_done,
				gate.key_deductions_required,
				gate.contradictions_marked,
				gate.contradictions_required
			)
		)
		-- Yang dikirim tetap bentuk `accusation_result` yang sama, dengan angka
		-- yang sama seperti sebelumnya -- tuduhan tidak dihitung, jadi
		-- `attempts_left` tidak berubah. Alasan gerbangnya TIDAK dikirim sebagai
		-- teks: angkanya sudah ada di `session_state`, dan mengirimnya di sini
		-- akan memberi client dua sumber kebenaran yang bisa berbeda.
		fireToRole("AccusationResult", "accusation_result", {
			correct_count = current.accusation.correctFieldCount,
			attempts_left = current.accusation.maxAttempts - current.accusation.attemptsUsed,
			resolved = false,
			won = false,
			pending_confirmation = false,
			rank = nil,
		})
		return
	end

	local result = AccusationService.submit(current.accusation, accusation :: { [string]: any })

	TelemetryService.record(current.telemetry, {
		kind = "accusation",
		role = role,
		t = os.clock(),
		detail = tostring(result.correctCount),
	})

	-- PRD §5: feedback salah hanya "X dari 3 benar", tanpa menyebut field mana.
	-- Payload di bawah sengaja tidak punya field `reason` yang bisa membocorkan
	-- field mana yang benar; `reason` hanya dipakai untuk log server.
	if result.reason ~= nil then
		warn(string.format("[Triangulate] tuduhan ditolak: %s", result.reason))
	end

	fireToRole("AccusationResult", "accusation_result", {
		correct_count = result.correctCount,
		attempts_left = result.attemptsLeft,
		resolved = result.resolved,
		won = result.won,
		pending_confirmation = result.pendingConfirmation,
		rank = nil,
	})
end

local function handleConfirm(player: Player, _: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role == nil then
		return
	end

	-- PRD §5: konfirmasi harus datang dari role selain Director.
	local ok, problem = AccusationService.confirm(current.accusation, role, Roles.DIRECTOR)
	if not ok then
		warn(string.format("[Triangulate] konfirmasi ditolak: %s", tostring(problem)))
		return
	end

	fireToRole("AccusationResult", "accusation_result", {
		correct_count = current.accusation.correctFieldCount,
		attempts_left = current.accusation.maxAttempts - current.accusation.attemptsUsed,
		resolved = true,
		won = true,
		pending_confirmation = false,
		rank = AccusationService.rank(
			os.clock() - current.startedAt,
			current.accusation.attemptsUsed,
			0,
			900
		),
	})
end

local function handleReport(player: Player, payload: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role == nil then
		return
	end

	if type(payload) ~= "table" then
		return
	end

	-- Client hanya mengirim `object_id`. Lokasi dan label TIDAK dipercaya dari
	-- client: keduanya dibaca dari data kasus, sehingga pemain tidak bisa
	-- mengirim tag lokasi palsu ke clue board Director (PRD §4: laporan masuk
	-- ke clue board). Payload lama yang membawa `location` sendiri diabaikan.
	local objectId = (payload :: any).object_id
	if type(objectId) ~= "string" or objectId == "" then
		return
	end

	local node = CaseGraph.nodeIndex(current.case)[objectId]
	if node == nil or node.type ~= "object" then
		-- Laporan atas node yang bukan objek di kasus ini tidak punya arti:
		-- tidak ada yang bisa ditampilkan di clue board.
		warn(string.format("[Triangulate] Report ditolak: '%s' bukan objek kasus", objectId))
		return
	end

	local variantId = current.variantId
	if variantId == nil or not CaseGraph.isActive(node, variantId) then
		warn(
			string.format(
				"[Triangulate] Report ditolak: objek '%s' tidak aktif di varian ini",
				objectId
			)
		)
		return
	end

	TelemetryService.record(current.telemetry, {
		kind = "clue",
		role = role,
		t = os.clock(),
		detail = objectId,
	})

	-- PRD §7: "Report Card: Searcher menekan Report, foto objek + tag lokasi
	-- otomatis terkirim. Tidak perlu mengetik."
	--
	-- `image` masih placeholder: belum ada satu pun aset foto objek di repo
	-- (satu-satunya `rbxassetid` adalah `Table.SHEET`). Field-nya tetap
	-- dikirim supaya bentuk payload tidak berubah saat art pertama masuk.
	-- `label` adalah nama objeknya, dan sekaligus jadi teks pengganti selama
	-- gambarnya masih kosong.
	local report = {
		id = string.format("%s:%s", current.caseId, objectId),
		object_id = objectId,
		label = node.label,
		location = (current.case :: any).location,
		image = "rbxassetid://0",
		gives_key = node.gives_key,
	}

	-- PRD §4: objek yang dilaporkan masuk ke clue board Director, dan kuncinya
	-- sampai ke Handler. Tiap role menerima proyeksi berbeda dari payload yang
	-- sama -- Handler menerima `gives_key`, Searcher dan Director tidak.
	fireToRole("ReportCard", "report_card", report)
end

-- PRD §4: Director menandai Kontradiksi antara pernyataan dan bukti.
--
-- Yang diperiksa server, dan kenapa: pernyataan itu memang bohong (field
-- server-only `lie`), dan bukti pembantahnya (`contradicted_by`) sudah
-- dikumpulkan Director. Client hanya mengirim nomor pernyataan; ia tidak
-- pernah menerima `lie` maupun `contradicted_by` -- lihat
-- `CaseLoader.projectForRole`.
local function handleMarkContradiction(player: Player, statementId: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role ~= "Director" then
		-- PRD §4: clue board milik Director.
		return
	end

	local board = current.board
	if board == nil then
		return
	end

	local accepted, reason, statement = DirectorBoardService.checkMark(
		board,
		statementId,
		current.obtainedClues,
		current.markedContradictions
	)

	if accepted and statement ~= nil then
		current.markedContradictions[statement.id] = true
		TelemetryService.record(current.telemetry, {
			kind = "input",
			role = role,
			t = os.clock(),
			detail = string.format("contradiction:%d", statement.id),
		})
	end

	-- Gerbang ikut dikirim ulang: satu kontradiksi bisa jadi syarat terakhir
	-- yang membuka form tuduhan (PRD §5).
	local gate = gateState(current)
	fireToRole("ContradictionResult", "contradiction_result", {
		accepted = accepted,
		statement_id = statementId,
		reason = reason,
		marked_count = gate.contradictions_marked,
		contradictions_required = gate.contradictions_required,
		deductions_done = gate.deductions_done,
		key_deductions_required = gate.key_deductions_required,
		gate_open = gate.gate_open,
	})

	if accepted then
		pushSessionState(current)
	end
end

-- Mencari node `clue_card` berdasarkan id-nya di data kasus. Dipakai saat
-- sebuah meja bukti selesai: `entry.yields` adalah id Clue Card, dan isinya
-- dibaca dari data supaya tidak ada salinan teks clue di kode.
local function clueCardById(case: CaseLoader.Case, id: string): { [string]: any }?
	local nodes = (case :: any).nodes
	if type(nodes) ~= "table" then
		return nil
	end
	for _, node in nodes do
		if type(node) == "table" and node.id == id then
			return node
		end
	end
	return nil
end

local function handlePlacePiece(player: Player, payload: any): ()
	local current = session
	if current == nil then
		return
	end

	-- PRD §3 dan §8: Handler pemilik meja; Director boleh mengambil alih pada
	-- mode 2 pemain. Searcher tidak pernah menyentuh meja.
	local role = roleOf(player.UserId)
	if not PuzzleTableService.canPlace(role) then
		return
	end

	local pieceId, u, v = PuzzleTableService.parsePlacement(payload)
	if pieceId == nil or u == nil or v == nil then
		return
	end

	-- Meja mana yang sedang disentuh pemain ini. Node id dikirim client hanya
	-- sebagai penanda meja, dan tetap divalidasi terhadap meja yang memang ada
	-- di sesi ini -- client tidak bisa mengarang node id.
	local nodeId = (payload :: { [string]: any }).node_id
	if type(nodeId) ~= "string" then
		return
	end

	local entry = PuzzleTableService.get(current.puzzle, nodeId)
	if entry == nil then
		return
	end

	TelemetryService.record(current.telemetry, {
		kind = "input",
		role = role,
		t = os.clock(),
		detail = nodeId,
	})

	local result, solved = PuzzleTableService.place(current.puzzle, nodeId, pieceId, u, v)
	if result == nil then
		return
	end

	-- Hasil keputusan server dikirim kembali ke kedua role yang memegang meja.
	-- Payload ini TIDAK memuat `target`/`correct` (lihat `PuzzleTable.clientPayload`
	-- dan `applyDrop`), jadi client tidak pernah tahu letak yang benar.
	fireToRole("PiecePlaced", "piece_placed", result)

	if solved and entry.yields ~= nil then
		-- PRD §4: bukti yang selesai membuka Clue Card untuk Director. Daftar
		-- ini yang dipakai `DirectorBoardService.checkMark`: kontradiksi baru
		-- sah ditandai setelah bukti pembantahnya benar-benar ada.
		current.obtainedClues[entry.yields] = true

		-- PRD §4: "Bukti yang selesai terkirim ke Director sebagai Clue Card."
		-- Isi Clue Card dibaca dari node `clue_card` di data kasus, bukan
		-- dikarang di sini: data kasus tetap satu sumber kebenaran, dan
		-- `source` (id bukti asalnya) hanya sampai ke Director lewat
		-- `Net.CLIENT_VIEWS.clue_card`.
		local node = clueCardById(current.case, entry.yields)
		if node ~= nil then
			-- Nama field di sini mengikuti kontrak view `clue_card`
			-- (`docs/integrasi-stage-1.md`: `id`, `title`, `summary`, dan
			-- `source` khusus Director), sedangkan data kasus menamai teks
			-- manusianya `label`. Pemetaan `label` -> `title` dilakukan di
			-- sini, satu tempat, alih-alih menambah alias di data.
			-- `summary` tidak diisi karena data kasus belum punya teks
			-- ringkas terpisah; field kosong lebih jujur daripada mengarang.
			fireToRole("ClueCard", "clue_card", {
				id = node.id,
				title = node.label,
				source = node.source,
			})
		else
			warn(
				string.format(
					"[Triangulate] bukti '%s' menghasilkan Clue Card '%s' yang tidak ada di kasus",
					nodeId,
					entry.yields
				)
			)
		end

		-- Meja berikutnya menyusul, supaya Handler tidak menunggu perintah.
		local nextEntry = PuzzleTableService.firstUnsolved(current.puzzle)
		if nextEntry ~= nil then
			fireToRole("PuzzleState", "puzzle_state", PuzzleTable.clientPayload(nextEntry.state))
		end
	end

	-- PRD §7: Table Preview ikut diperbarui tiap potongan, supaya Director tahu
	-- progres Handler tanpa bertanya. Dikirim juga saat belum selesai --
	-- justru progres itulah isinya.
	fireToRole("TablePreview", "table_preview", {
		entries = tablePreviewEntries(current.puzzle),
	})
end

-- PRD §7: "Ping Wheel kontekstual ... Roda dengan 6-8 frasa yang berubah
-- sesuai role dan situasi."
--
-- Client mengirim HANYA id frasa. Teksnya dicari di `PingPhrases` -- satu
-- daftar yang sama dengan yang dipakai client untuk menggambar roda -- supaya
-- client tidak bisa menyiarkan teks bebas lewat kanal ping. `isValid` menolak
-- frasa milik role lain, jadi Searcher tidak bisa mengirim frasa Director.
local function handlePing(player: Player, phraseId: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role == nil then
		return
	end

	if type(phraseId) ~= "string" then
		return
	end

	if not PingPhrases.isValid(role, phraseId) then
		warn(string.format("[Triangulate] ping ditolak: frasa '%s' bukan milik %s", phraseId, role))
		return
	end

	local label = PingPhrases.labelFor(role, phraseId)
	if label == nil then
		-- Tidak mungkin terjadi bila `isValid` sudah lolos, tetapi `nil` di
		-- sini berarti roda dan label menyimpang -- lebih baik tidak terkirim
		-- daripada terkirim tanpa teks.
		return
	end

	-- PRD §7: "Komunikasi tanpa mengetik. Cukup sentuh." Ping adalah input
	-- bermakna untuk telemetri idle time (PRD §12), sama seperti menaruh
	-- potongan.
	TelemetryService.record(current.telemetry, {
		kind = "input",
		role = role,
		t = os.clock(),
		detail = phraseId,
	})

	-- Pengirim tidak menerima ping-nya sendiri: ia baru saja menekannya, dan
	-- mengirimkannya kembali akan membuat satu ping tampil dua kali.
	fireToRoleExcept("PingRelay", "ping", {
		from_role = role,
		phrase_id = phraseId,
		label = label,
	}, player.UserId)
end

-- PRD §7: "Target Marker: Handler menaruh ikon target yang muncul di HUD
-- Searcher dan arah kompas."
--
-- Yang dikirim Handler hanyalah id node. Label dan arah kompas dihitung di
-- sini dari data kasus dan `LocationMap`, jadi Searcher tidak bisa menerima
-- teks atau arah yang dikarang pemain lain.
--
-- Target yang dipasang boleh berupa node objek (benda di lokasi) maupun node
-- bukti (yang dipegang Handler, seperti `briefings.Handler.target`). Bukti
-- dipetakan ke objek pemilik kuncinya, karena Searcher mencari BENDA -- arah
-- kompas ke meja Handler tidak ada artinya di lokasi.
local function handleSetTarget(player: Player, targetId: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role ~= Roles.HANDLER then
		-- Marker dipasang Handler (PRD §7). Searcher dan Director tidak punya
		-- tombol ini.
		return
	end

	local variantId = current.variantId
	if variantId == nil then
		return
	end

	if type(targetId) ~= "string" or targetId == "" then
		return
	end

	local node = CaseGraph.nodeIndex(current.case)[targetId]
	if node == nil then
		warn(string.format("[Triangulate] SetTarget ditolak: '%s' tidak ada di kasus", targetId))
		return
	end

	if not CaseGraph.isActive(node, variantId) then
		warn(
			string.format(
				"[Triangulate] SetTarget ditolak: '%s' tidak aktif di varian ini",
				targetId
			)
		)
		return
	end

	local objectId: string? = nil
	if node.type == "object" then
		objectId = node.id
	elseif node.type == "evidence" and type(node.needs) == "table" then
		-- `node.needs` bukti adalah daftar id kunci. `keyOwners` memetakan
		-- kunci itu ke objek yang menyediakannya -- satu-satunya cara Searcher
		-- tahu benda mana yang harus dicari tanpa membocorkan isi bukti.
		local owners = CaseGraph.keyOwners(current.case, variantId)
		for _, key in node.needs do
			local candidates = owners[key]
			if candidates ~= nil and #candidates > 0 then
				objectId = candidates[1]
				break
			end
		end
	end

	if objectId == nil then
		warn(
			string.format(
				"[Triangulate] SetTarget ditolak: '%s' bukan objek dan tidak punya objek asal",
				targetId
			)
		)
		return
	end

	local target = CaseGraph.nodeIndex(current.case)[objectId]
	local location = (current.case :: any).location
	local payload = {
		target_id = objectId,
		label = if target ~= nil then target.label else node.label,
		bearing = LocationMap.bearingFromEntry(location, objectId),
	}

	-- Hanya Searcher yang menerima marker: `Net.CLIENT_VIEWS.target_marker`
	-- sengaja tidak punya entri untuk Handler (pengirim) dan Director.
	fireToRole("TargetMarker", "target_marker", payload)
end

remotes.SubmitDeduction.OnServerEvent:Connect(handleDeduce)
remotes.PlacePiece.OnServerEvent:Connect(handlePlacePiece)
remotes.Accuse.OnServerEvent:Connect(handleAccuse)
remotes.ConfirmAccusation.OnServerEvent:Connect(handleConfirm)
remotes.Report.OnServerEvent:Connect(handleReport)
remotes.Ping.OnServerEvent:Connect(handlePing)
remotes.SetTarget.OnServerEvent:Connect(handleSetTarget)
remotes.MarkContradiction.OnServerEvent:Connect(handleMarkContradiction)

-- ---------------------------------------------------------------------------
-- 7. Lobby
-- ---------------------------------------------------------------------------

-- PRD §8: "Timer lobby 45 detik. Jika belum 3 manusia, role kosong diisi NPC.
-- Pemain bisa memilih tunggu sampai 90 detik."
--
-- Yang BELUM terpasang di sini, dan kenapa: PRD §17 menempatkan "Lobby,
-- preferensi role, NPC, AFK/rejoin" di minggu 5. Jadi scaffold minggu 0 ini
-- memakai jalur sederhana -- sesi mulai saat 3 pemain sudah ada -- dan belum
-- menjalankan:
--   * timer 45/90 detik (`Matchmaking.deadline`/`secondsLeft` sudah ada dan
--     sudah diuji, belum ada penjadwal yang memanggilnya),
--   * ready check (`Matchmaking.readyFailures`/`canStart` sudah ada dan sudah
--     diuji, belum ada UI yang menyetel `ready`),
--   * preferensi role dari pemain: `preferences` di bawah masih `Roles.ALL`,
--     artinya "tanpa preferensi". Rotasi dan prioritas keadilan di
--     `RoleAssignment` sudah diuji dan aktif, tetapi belum diberi input nyata.
--   * perilaku NPC untuk `session.npcRoles`.
-- Semuanya bernama dan bernomor baris, jadi minggu 5 mengisi pemanggil.
local function lobbyConfig(): Matchmaking.Config
	return {
		maxPlayers = Config.MAX_PLAYERS,
		lobbySeconds = Config.LOBBY_SECONDS,
		extendedSeconds = Config.LOBBY_EXTENDED_SECONDS,
		readyCheckSeconds = Config.READY_CHECK_SECONDS,
	}
end

Players.PlayerAdded:Connect(function(player: Player)
	Matchmaking.join(lobby, {
		id = player.UserId,
		preferences = Roles.ALL,
		ready = false,
		joinedAt = os.clock(),
	}, lobbyConfig())

	if #lobby.players >= Config.MAX_PLAYERS then
		startSession()
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	Matchmaking.leave(lobby, player.UserId)
end)

for _, player in Players:GetPlayers() do
	Matchmaking.join(lobby, {
		id = player.UserId,
		preferences = Roles.ALL,
		ready = false,
		joinedAt = os.clock(),
	}, lobbyConfig())
end

if #lobby.players >= Config.MAX_PLAYERS then
	startSession()
end

-- Deadline lobby diperiksa berkala, bukan dengan satu `task.delay`, supaya
-- pemain yang bergabung di tengah tidak memperpanjang timer secara tak sengaja.
task.spawn(function()
	while session == nil do
		task.wait(1)
		if
			Matchmaking.secondsLeft(lobby, os.clock(), lobbyConfig()) <= 0
			and #lobby.players > 0
		then
			startSession()
		end
	end
end)

return nil
