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
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Roles = require(Shared.Roles)
local CaseValidator = require(Shared.case.CaseValidator)
local SharedCaseLoader = require(Shared.case.CaseLoader)
local PuzzleTable = require(Shared.PuzzleTable)

local CaseSource = require(script.CaseSource)
local LocationService = require(script.LocationService)
local DeductionEngine = require(script.DeductionEngine)
local AccusationService = require(script.AccusationService)
local RoleAssignment = require(script.RoleAssignment)
local Matchmaking = require(script.Matchmaking)
local NPCController = require(script.NPCController)
local TelemetryService = require(script.TelemetryService)
local PuzzleTableService = require(script.PuzzleTableService)

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
--
-- Ada DUA jalur validasi, dan keduanya harus terpasang:
--   * `CaseSource.setValidator` -- saat data dibaca dari `ServerStorage`,
--     sebelum ada sesi. Ini yang menangkap kasus cacat paling awal.
--   * `SharedCaseLoader.load` -- memanggil `CaseValidator` sendiri, dan
--     mengembalikan `ok = false` alih-alih melempar. Ini yang dipakai
--     `startSession` karena sekaligus memilih varian.
-- Keduanya menjalankan validator yang sama (`CaseValidator.asLoaderValidator`
-- adalah pembungkus `CaseValidator.validate`), jadi tidak ada dua aturan.
CaseSource.setValidator(CaseValidator.asLoaderValidator)

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
	case: CaseSource.Case,
	variant: CaseSource.CaseVariant,
	-- Id varian yang dipilih. `CaseVariant` dari `CaseSource` sudah membawa
	-- `variant_id`, tetapi `SharedCaseLoader.load` juga mengembalikannya di
	-- `session.variant_id`; yang disimpan di sini adalah nilai dari loader murni,
	-- karena itulah yang dipakai untuk menyaring node.
	variantId: string,
	-- Lokasi sesi ini (PRD §4, §6, §17 minggu 2): objek yang bisa diperiksa,
	-- mini-aksi Searcher, dan kunci yang sudah dipegang tim.
	location: LocationService.Service,
	-- Part dunia yang sudah dibuat, di-key oleh id objek. Dipakai saat sesi
	-- dibersihkan; tidak dibaca oleh logika permainan.
	world: { [string]: BasePart },
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
	-- Meja puzzle sesi ini (PRD §4, §15, §17 minggu 1). Dibangun sekali saat
	-- sesi mulai dari node bukti yang aktif pada varian yang dipilih.
	puzzle: PuzzleTableService.Service,
	-- Node id meja terakhir yang dikirim ke pemain. Dipakai supaya meja yang
	-- sama tidak dikirim berulang kali saat kunci baru diperoleh.
	sentPuzzle: string?,
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

-- Mengirim meja puzzle yang sedang TERSEDIA ke Handler dan Director.
--
-- Dua kata yang mudah tertukar dan di sini dibedakan dengan sengaja:
--   * "belum selesai" (`firstUnsolved`) -- masih ada pekerjaan tersisa;
--   * "tersedia" (`firstAvailable`) -- pekerjaan itu sudah terbuka kuncinya.
-- Yang dikirim ke pemain adalah yang kedua. Mengirim meja yang masih terkunci
-- akan menampilkan papan yang tidak bisa dimajukan, dan Handler akan menyangka
-- dirinya gagal.
--
-- Pengiriman ulang dicegah lewat `sentPuzzle`: meja yang sama tidak dikirim dua
-- kali hanya karena ada kunci lain yang diperoleh. Tanpa penanda ini, Handler
-- yang sedang menyeret potongan bisa menerima papan yang sama di tengah
-- tarikan.
local function sendAvailablePuzzle(current: Session): ()
	local entry = PuzzleTableService.firstAvailable(
		current.puzzle,
		LocationService.keysHeld(current.location)
	)
	if entry == nil then
		return
	end
	if current.sentPuzzle == entry.node_id then
		return
	end

	current.sentPuzzle = entry.node_id
	fireToRole("PuzzleState", "puzzle_state", PuzzleTable.clientPayload(entry.state))
end

-- ---------------------------------------------------------------------------
-- 4b. Dunia: lokasi fisik sesi ini (PRD §4, §6)
-- ---------------------------------------------------------------------------

-- Nama tag `CollectionService`. Client mencarinya lewat tag, bukan lewat nama
-- atau path -- path part bisa berubah tanpa merusak client, dan tag tidak bisa
-- salah cocok dengan part lain di place.
local OBJECT_TAG = "TriangulateObject"
local WORLD_FOLDER = "TriangulateLocation"

--[[
	Membuat part untuk tiap objek lokasi dan mengembalikan petanya.

	Aturan yang dipegang di sini: part yang direplikasi TIDAK boleh membawa
	rahasia. Dokumentasi arsitektur (`docs/arsitektur.md`) menyebut atribut
	Instance sebagai kanal replikasi, bukan kanal rahasia -- siapa pun yang
	menjalankan client bisa membacanya. Karena itu:

	  * tidak ada `gives_key` di atribut mana pun. Kunci adalah hasil
	    pemeriksaan, dan pemeriksaannya diputuskan server.
	  * tidak ada field solusi, tidak ada resep deduksi, tidak ada isi bukti.
	  * `label` boleh: Searcher memang melihat objeknya, dan label itu juga
	    muncul di Report Card miliknya sendiri.

	Posisi part berasal dari `LocationService.ringPosition` -- deterministik,
	tanpa angka acak, supaya dua sesi dengan varian yang sama menaruh objek di
	tempat yang sama.
]]
local function buildWorld(service: LocationService.Service): { [string]: BasePart }
	local existing = Workspace:FindFirstChild(WORLD_FOLDER)
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = WORLD_FOLDER

	local parts: { [string]: BasePart } = {}

	local function makePart(object: LocationService.WorldObject, color: Color3): BasePart
		local part = Instance.new("Part")
		part.Name = object.id
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(2, 2, 2)
		part.Position = Vector3.new(object.position.x, 1.5, object.position.z)
		part.Color = color
		-- Hanya identitas dan label. Sengaja BUKAN `gives_key`.
		part:SetAttribute("object_id", object.id)
		part:SetAttribute("label", object.label)
		part:SetAttribute("kind", object.kind)
		part:SetAttribute("reachable", object.reachable)
		-- Gerbang deduksi (PRD §4 langkah 6). Sama seperti `reachable`, ini
		-- bukan rahasia: Searcher memang melihat pintu yang belum bisa dibuka.
		-- Yang tidak boleh menyeberang adalah resepnya (`unlocks` menunjuk id
		-- objek, bukan sebaliknya) dan kuncinya.
		--
		-- Atribut ini BERUBAH selama sesi (lihat `handleDeduce`), dan itulah
		-- cara client tahu kapan sebuah pintu terbuka tanpa menebak sendiri.
		part:SetAttribute("gated", object.gated_by ~= nil)
		part:SetAttribute("action", object.action)
		CollectionService:AddTag(part, OBJECT_TAG)
		part.Parent = folder
		parts[object.id] = part
		return part
	end

	for _, nodeId in service.order do
		local object = service.objects[nodeId]
		if object ~= nil then
			makePart(object, Color3.fromRGB(226, 196, 132))
		end
	end

	for _, nodeId in service.ambient do
		local object = service.objects[nodeId]
		if object ~= nil then
			makePart(object, Color3.fromRGB(150, 150, 165))
		end
	end

	-- Objek yang ada di lokasi tapi belum tercapai tetap dibuat, dengan warna
	-- berbeda dan `reachable = false`: Searcher boleh melihat pintu yang belum
	-- bisa dibuka, tapi server menolak memeriksanya.
	for nodeId, object in service.objects do
		if parts[nodeId] == nil then
			makePart(object, Color3.fromRGB(96, 96, 108))
		end
	end

	folder.Parent = Workspace
	return parts
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

	local caseIds = CaseSource.availableCaseIds(casesFolder)
	if #caseIds == 0 then
		warn("[Triangulate] tidak ada kasus di ServerStorage.Cases; sesi tidak bisa dimulai.")
		return
	end

	local caseId = caseIds[1]
	local loaded = CaseSource.load(casesFolder, caseId)

	-- PRD §10: "Seed server memilih cabang saat sesi dibuat."
	-- Pemilihan varian ada di SATU tempat: `SharedCaseLoader.load`, yang
	-- memvalidasi dulu lalu memilih varian dari seed. Server ini tidak lagi
	-- memilih varian sendiri -- dulu ada dua jalur (`CaseLoader.pickVariant`
	-- di sini dan fungsi sejenis di modul loader), dan dua jalur berarti dua
	-- jawaban yang bisa berbeda.
	--
	-- `load.ok == false` berarti kasus cacat. Sesi TIDAK dijalankan: PRD §10
	-- menuntut validator memastikan jalur solusi ada, dan menjalankan kasus
	-- yang gagal validasi berarti menjalankan kasus yang mungkin tidak bisa
	-- dimenangkan.
	local load = SharedCaseLoader.load(loaded, tostring(os.time()))
	if not load.ok then
		local codes: { string } = {}
		for _, problem in load.report.errors do
			table.insert(codes, string.format("%s (%s)", problem.code, problem.path))
		end
		warn(
			string.format(
				"[Triangulate] kasus '%s' ditolak validator; sesi tidak dijalankan: %s",
				caseId,
				table.concat(codes, ", ")
			)
		)
		return
	end

	local variantId: string = load.session.variant_id
	local variant = load.session.variant

	-- RNG tetap dipakai untuk scatter potongan puzzle. Ia TIDAK lagi dipakai
	-- untuk memilih varian -- kalau dipakai untuk keduanya, menarik angka
	-- untuk scatter akan menggeser varian sesi.
	local rng = Random.new(os.time())

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

	-- Lokasi sesi ini (PRD §4, §6, §17 minggu 2).
	--
	-- Himpunan objek yang bisa diperiksa datang dari `reachable_node_ids`
	-- milik loader, bukan dari penelusuran sendiri: itulah satu-satunya tempat
	-- yang tahu node mana yang masih terjangkau pada varian ini (PRD §10 --
	-- "tidak ada rantai yang buntu"). Menghitung ulang di sini berarti dua
	-- jawaban yang bisa berbeda.
	--
	-- `reachableIds` saja belum cukup: `LocationService` juga membaca `unlocks`
	-- dari node dan menahan objek yang dibuka sebuah deduksi sampai deduksi itu
	-- selesai (PRD §4 langkah 6). Ia membaca `nodes` yang sama, jadi tidak ada
	-- salinan kedua dari aturan itu di sini.
	local reachableIds: { [string]: boolean } = {}
	for _, nodeId in load.session.reachable_node_ids do
		reachableIds[nodeId] = true
	end

	-- Deduksi selesai: satu tabel untuk sesi dan lokasi. Dua tabel berarti
	-- gerbang `unlocks` membaca keadaan yang berbeda dari yang ditulis
	-- `handleDeduce`, dan objek yang sudah terbuka tetap terlihat terkunci.
	local completedDeductions: { [string]: boolean } = {}

	local locationService = LocationService.new({
		location = loaded.location,
		nodes = loaded.nodes,
		reachableIds = reachableIds,
		actions = Config.SEARCHER_ACTIONS,
		clock = os.clock,
		variantId = variantId,
		completedDeductions = completedDeductions,
		radius = Config.LOCATION_RADIUS,
		ambientRadius = Config.AMBIENT_RADIUS,
	})

	local world = buildWorld(locationService)

	session = {
		caseId = caseId,
		case = loaded,
		variant = variant,
		variantId = variantId,
		location = locationService,
		world = world,
		roles = assigned,
		npcRoles = npcRoles,
		engine = engine,
		completedDeductions = completedDeductions,
		puzzle = PuzzleTableService.new(PuzzleTable),
		sentPuzzle = nil,
		accusation = AccusationService.newSession(
			solution,
			Config.ACCUSATION_FIELDS,
			Config.MAX_ACCUSATIONS
		),
		telemetry = TelemetryService.newSession(os.clock()),
		startedAt = os.clock(),
	}

	-- Meja puzzle sesi ini (PRD §4, §15). Node bukti yang hidup pada varian
	-- yang dipilih menjadi meja; tipe puzzle yang belum dikenal DILEWATI, bukan
	-- menggagalkan sesi -- satu node bertipe baru di data kasus tidak boleh
	-- menjatuhkan sesi tiga pemain. Yang dilewati dicatat supaya ketahuan.
	local puzzleEntries, puzzleSkipped = PuzzleTableService.build(
		session.puzzle,
		loaded.nodes,
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
	local briefings = loaded.briefings
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
		suspects = loaded.suspects,
		motives = loaded.motives,
		methods = loaded.methods,
	}
	fireToRole("SessionState", "accusation_options", options)

	-- Meja pertama yang TERSEDIA (bukan sekadar belum selesai) dikirim ke
	-- Handler dan Director. Bedanya nyata: meja yang belum dibuka kuncinya
	-- tidak boleh muncul sebagai pekerjaan. Searcher tidak menerimanya:
	-- `Net.CLIENT_VIEWS.puzzle_state` sengaja tidak punya entri untuknya --
	-- ia ada di lokasi, bukan di meja (PRD §3), dan `fireToRole` melewati role
	-- yang view-nya `nil`.
	sendAvailablePuzzle(session)
	if session.sentPuzzle == nil then
		if PuzzleTableService.firstUnsolved(session.puzzle) ~= nil then
			-- Ada meja, tapi semuanya masih terkunci. Ini keadaan sah: Searcher
			-- belum menemukan objek pertama. Bukan peringatan.
			print(
				string.format(
					"[Triangulate] kasus '%s': semua meja menunggu kunci; Handler menunggu Searcher",
					caseId
				)
			)
		else
			warn(string.format("[Triangulate] kasus '%s' tidak punya meja puzzle aktif", caseId))
		end
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
	if result.ok and result.deductionId ~= nil then
		-- PRD §4 langkah 6: deduksi "membuka target baru". Pencatatannya lewat
		-- `LocationService` supaya satu tempat memutuskan objek mana yang
		-- terbuka -- `completedDeductions` adalah tabel yang sama.
		local opened = LocationService.completeDeduction(current.location, result.deductionId)
		for _, objectId in opened do
			-- Part-nya sudah ada sejak sesi mulai (Searcher melihat pintu yang
			-- belum bisa dibuka); yang berubah hanya gerbangnya. Client
			-- mendengarkan perubahan atribut ini dan mengaktifkan promptnya.
			local part = current.world[objectId]
			if part ~= nil then
				part:SetAttribute("gated", false)
			end
			print(
				string.format(
					"[Triangulate] deduksi '%s' membuka objek '%s'; Searcher bisa memeriksanya",
					result.deductionId,
					objectId
				)
			)
		end

		fireToRole("DeductionResult", "deduction", {
			id = result.deductionId,
			clue_ids = ids,
			pinpoint = nil,
			-- PRD §4 langkah 6: deduksi "membuka target baru". Yang dikirim
			-- adalah id objek yang BARU terbuka -- id itu sudah terlihat di
			-- dunia sebagai nama part, jadi ini tidak menambah kebocoran; yang
			-- tetap di server adalah resep `unlocks` itu sendiri.
			unlocks = opened,
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

-- PRD §7: Report Card. Client mengirim ID objek; server memutuskan apa yang
-- kembali.
--
-- Sebelum ini payload client diteruskan apa adanya ke `fireToRole`, dan itu
-- berarti client bisa mengarang `gives_key`, mengarang `title`, atau mengirim
-- objek yang tidak ada di kasus. Sekarang payload yang menyeberang DIRAKIT DI
-- SINI dari data sesi: id objek divalidasi terhadap lokasi, judul diambil dari
-- label objek, dan kunci diambil dari `LocationService` -- bukan dari client.
--
-- Pemeriksaan yang dilakukan, berurutan:
--   1. role pemain dikenal,
--   2. payload berupa tabel dan `object_id` bertipe string,
--   3. objek ada di lokasi sesi ini,
--   4. objek sudah bisa dicapai (belum tercapai = masih terkunci deduksi).
-- `gives_key` tidak ikut diperiksa dari client: nilainya tidak pernah dibaca
-- dari payload.
local function handleReport(player: Player, payload: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role ~= Roles.SEARCHER then
		-- PRD §6: Report Card adalah alat Searcher ("Searcher menekan Report").
		-- Role lain tidak memeriksa objek di lokasi.
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local objectId = (payload :: { [string]: any }).object_id
	if type(objectId) ~= "string" then
		return
	end

	local object = LocationService.get(current.location, objectId)
	if object == nil then
		warn(
			string.format(
				"[Triangulate] laporan objek '%s' ditolak: tidak ada di lokasi '%s'",
				objectId,
				current.location.location
			)
		)
		return
	end

	if not LocationService.isInspectable(current.location, objectId) then
		warn(
			string.format("[Triangulate] laporan objek '%s' ditolak: belum bisa dicapai", objectId)
		)
		return
	end

	TelemetryService.record(current.telemetry, {
		kind = "clue",
		role = role,
		t = os.clock(),
		detail = objectId,
	})

	-- PRD §4: objek yang dilaporkan masuk ke clue board Director, dan kuncinya
	-- sampai ke Handler. Payload dirakit server; tiap role menerima proyeksi
	-- berbeda dari payload yang SAMA, dan `gives_key` hanya ada di allowlist
	-- Handler (`Net.CLIENT_VIEWS.report_card`).
	--
	-- `gives_key` dibaca dari lokasi, bukan dari data kasus langsung: kunci
	-- baru dianggap milik tim setelah pemeriksaannya selesai. Kalau dibaca
	-- langsung dari node, Searcher bisa mengirim laporan objek yang belum
	-- diperiksa dan Handler langsung menerima kuncinya.
	local held = LocationService.keysHeld(current.location)
	fireToRole("ReportCard", "report_card", {
		id = string.format("rc_%s", objectId),
		object_id = objectId,
		title = object.label,
		location = current.location.location,
		image = nil,
		gives_key = if object.gives_key ~= nil and held[object.gives_key] == true
			then object.gives_key
			else nil,
	})
end

-- PRD §6: mini-aksi Searcher (senter UV, buka laci dengan hold, lockpick).
--
-- Klien mengirim niat, bukan hasil. Tiga fase:
--   * "begin"    -- mulai menahan aksi; server mencatat waktu mulai dengan
--                   jamnya sendiri.
--   * "complete" -- klaim jari sudah selesai menahan; server memeriksa
--                   durasinya terhadap jam yang sama. Klaim yang terlalu cepat
--                   ditolak, jadi client tidak bisa mempercepat perolehan kunci
--                   dengan mengirim "complete" lebih awal.
--   * "cancel"   -- jari diangkat; tidak ada kunci yang diberikan.
--
-- Efek yang terlihat tim: kunci masuk ke `LocationService`, lalu meja bukti
-- yang terbuka dikirim ke Handler dan Director. Itulah rantai PRD §4 --
-- objek memberi kunci, kunci membuka potongan bukti.
local function handleInspect(player: Player, payload: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role ~= Roles.SEARCHER then
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local data = payload :: { [string]: any }
	local objectId = data.object_id
	local actionId = data.action
	local phase = data.phase
	if type(objectId) ~= "string" or type(actionId) ~= "string" or type(phase) ~= "string" then
		return
	end

	if phase == "begin" then
		local ok, problem =
			LocationService.beginInspect(current.location, player.UserId, objectId, actionId)
		if not ok then
			warn(string.format("[Triangulate] mulai periksa ditolak: %s", tostring(problem)))
			return
		end

		TelemetryService.record(current.telemetry, {
			kind = "input",
			role = role,
			t = os.clock(),
			detail = objectId,
		})
		return
	elseif phase == "cancel" then
		LocationService.cancelInspect(current.location, player.UserId)
		return
	elseif phase ~= "complete" then
		return
	end

	local ok, problem, key =
		LocationService.completeInspect(current.location, player.UserId, objectId)
	if not ok then
		-- Termasuk "aksi belum selesai": klaim client yang terlalu cepat.
		warn(string.format("[Triangulate] selesai periksa ditolak: %s", tostring(problem)))
		return
	end

	TelemetryService.record(current.telemetry, {
		kind = "clue",
		role = role,
		t = os.clock(),
		detail = objectId,
	})

	local object = LocationService.get(current.location, objectId)
	if object == nil then
		return
	end

	-- Objek ambient tidak memberi kunci (PRD §6: "bukti tambahan opsional"),
	-- jadi tidak ada meja yang terbuka. Searcher tetap boleh melaporkannya
	-- lewat aksi Report.
	if key == nil then
		print(
			string.format(
				"[Triangulate] objek ambient '%s' diperiksa; tidak ada kunci yang diberikan",
				objectId
			)
		)
		return
	end

	print(
		string.format(
			"[Triangulate] kunci '%s' diperoleh dari objek '%s'; meja bukti terkait terbuka",
			key,
			objectId
		)
	)

	-- Yang dikirim ke Handler/Director di sini adalah MEJA yang baru terbuka,
	-- bukan Report Card. Report Card tetap milik aksi Report (PRD §4 langkah 2
	-- memisahkan keduanya: objek "memberi kunci" ke Handler, dan "masuk ke clue
	-- board Director sebagai Laporan"). Mengirim kartu dari dua tempat akan
	-- menaruh dua kartu untuk satu objek di clue board.
	sendAvailablePuzzle(current)
end

-- Mencari node `clue_card` berdasarkan id-nya di data kasus. Dipakai saat
-- sebuah meja bukti selesai: `entry.yields` adalah id Clue Card, dan isinya
-- dibaca dari data supaya tidak ada salinan teks clue di kode.
local function clueCardById(case: CaseSource.Case, id: string): { [string]: any }?
	local nodes = case.nodes
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

	-- PRD §4: "Kunci membuka potongan bukti di meja." Meja yang belum terbuka
	-- tidak boleh bisa dimajukan -- kalau tidak, seluruh gerbang kunci di
	-- `LocationService` bisa dilewati hanya dengan mengirim `PlacePiece` ke
	-- node yang sudah diketahui id-nya dari data.
	if
		not PuzzleTableService.isUnlocked(
			current.puzzle,
			nodeId,
			LocationService.keysHeld(current.location)
		)
	then
		warn(
			string.format(
				"[Triangulate] penempatan di meja '%s' ditolak: kuncinya belum dipegang tim",
				nodeId
			)
		)
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

		-- Meja berikutnya yang TERSEDIA menyusul, supaya Handler tidak menunggu
		-- perintah. Yang terkunci tidak dikirim: kuncinya baru datang dari
		-- Searcher, dan `handleInspect` yang akan mengirimnya.
		sendAvailablePuzzle(current)
	end
end

remotes.SubmitDeduction.OnServerEvent:Connect(handleDeduce)
remotes.PlacePiece.OnServerEvent:Connect(handlePlacePiece)
remotes.Accuse.OnServerEvent:Connect(handleAccuse)
remotes.ConfirmAccusation.OnServerEvent:Connect(handleConfirm)
remotes.Report.OnServerEvent:Connect(handleReport)
remotes.Inspect.OnServerEvent:Connect(handleInspect)

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
