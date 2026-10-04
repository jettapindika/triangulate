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

local CaseLoader = require(script.CaseLoader)
local DeductionEngine = require(script.DeductionEngine)
local AccusationService = require(script.AccusationService)
local RoleAssignment = require(script.RoleAssignment)
local Matchmaking = require(script.Matchmaking)
local NPCController = require(script.NPCController)
local TelemetryService = require(script.TelemetryService)

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

-- ---------------------------------------------------------------------------
-- 5. Mulai sesi
-- ---------------------------------------------------------------------------

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
	local variant = CaseLoader.pickVariant(loaded, rng:NextNumber())

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
		roles = assigned,
		npcRoles = npcRoles,
		engine = engine,
		completedDeductions = {},
		accusation = AccusationService.newSession(
			solution,
			Config.ACCUSATION_FIELDS,
			Config.MAX_ACCUSATIONS
		),
		telemetry = TelemetryService.newSession(os.clock()),
		startedAt = os.clock(),
	}

	-- Briefing per role. PRD §9: Role Card berisi "Kamu tahu apa / Tidak tahu
	-- apa / Tugas pertamamu". Tiap role menerima proyeksi berbeda, dan tidak
	-- ada role yang menerima field solusi.
	local briefings = (loaded :: any).briefings
	if type(briefings) == "table" then
		for userId, role in assigned do
			local player = Players:GetPlayerByUserId(userId)
			local briefing = briefings[role]
			if player ~= nil and type(briefing) == "table" then
				local projected = Net.forRole("briefing", role, briefing)
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
	if result.ok and result.deductionId ~= nil then
		current.completedDeductions[result.deductionId] = true
		fireToRole("DeductionResult", "deduction", {
			id = result.deductionId,
			clue_ids = ids,
			pinpoint = nil,
			unlocks = nil,
		})
	end
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

	TelemetryService.record(current.telemetry, {
		kind = "clue",
		role = role,
		t = os.clock(),
		detail = nil,
	})

	-- PRD §4: objek yang dilaporkan masuk ke clue board Director, dan kuncinya
	-- sampai ke Handler. Tiap role menerima proyeksi berbeda dari payload yang
	-- sama -- Handler menerima `gives_key`, Searcher dan Director tidak.
	fireToRole("ReportCard", "report_card", payload :: { [string]: any })
end

remotes.SubmitDeduction.OnServerEvent:Connect(handleDeduce)
remotes.Accuse.OnServerEvent:Connect(handleAccuse)
remotes.ConfirmAccusation.OnServerEvent:Connect(handleConfirm)
remotes.Report.OnServerEvent:Connect(handleReport)

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
