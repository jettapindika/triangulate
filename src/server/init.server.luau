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
local PingPhrases = require(Shared.PingPhrases)
local LocationMap = require(Shared.LocationMap)
local CaseValidator = require(Shared.case.CaseValidator)
local CaseGraph = require(Shared.case.CaseGraph)
local SharedCaseLoader = require(Shared.case.CaseLoader)
local PuzzleTable = require(Shared.PuzzleTable)

local CaseSource = require(script.CaseSource)
local LocationService = require(script.LocationService)
local DeductionEngine = require(script.DeductionEngine)
local AccusationService = require(script.AccusationService)
local AccusationGate = require(script.AccusationGate)
local RoleAssignment = require(script.RoleAssignment)
local Matchmaking = require(script.Matchmaking)
local NPCController = require(script.NPCController)
local TelemetryService = require(script.TelemetryService)
local PuzzleTableService = require(script.PuzzleTableService)

-- `kamus-metrik.md` §0.2 mewajibkan `t_server_ms` untuk seluruh perhitungan
-- metrik, sedangkan `os.clock()` -- sumber waktu yang sudah dipakai berkas ini
-- untuk lobby dan rank -- mengembalikan DETIK. Konversi dilakukan di satu
-- fungsi ini supaya tidak ada cap waktu yang diam-diam bercampur satuan;
-- `TelemetryService` memakai `BUCKET_MS = 1000`, jadi detik yang lolos apa
-- adanya akan menaruh seluruh sesi di satu bucket dan melaporkan idle 0%.
local function telemetryMs(): number
	return os.clock() * 1000
end

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
	-- Id Clue Card yang SUDAH dimiliki Director. Ini yang membuat penandaan
	-- Kontradiksi bermakna (PRD §4): tanpa daftar ini Director bisa menandai
	-- kontradiksi sebelum bukti pembantahnya ada, dan gerbang tuduhan terbuka
	-- tanpa kerja deduksi. Diisi saat sebuah meja bukti selesai dirakit.
	obtainedClues: { [string]: boolean },
	-- Meja puzzle sesi ini (PRD §4, §15, §17 minggu 1). Dibangun sekali saat
	-- sesi mulai dari node bukti yang aktif pada varian yang dipilih.
	puzzle: PuzzleTableService.Service,
	-- Node id meja terakhir yang dikirim ke pemain. Dipakai supaya meja yang
	-- sama tidak dikirim berulang kali saat kunci baru diperoleh.
	sentPuzzle: string?,
	accusation: AccusationService.Session,
	-- Deduksi Kunci varian ini dan ambang N-nya (PRD §5). Hanya hidup di
	-- server: yang menyeberang ke Director adalah angka progresnya, bukan
	-- daftar id-nya -- id `ded_c_*` versus `ded_g_*` menyebut cabang solusi,
	-- dan itu sama dengan menyebut pelakunya.
	keyDeductionIds: { string },
	keyDeductionsRequired: number,
	-- Gerbang form tuduhan, timer cleanup, dan rekap Cold Case (PRD §5, §6).
	gate: AccusationGate.Session,
	-- Pernyataan saksi yang boleh dilihat Director, sudah dibersihkan dan
	-- diberi id (PRD §4). `AccusationGate.publicStatements` yang merakitnya;
	-- berkas ini hanya menyimpannya supaya penandaan Kontradiksi bisa memetakan
	-- id kembali ke pernyataan aslinya tanpa membaca ulang data kasus.
	statements: { { id: string, who: string, text: string } },
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

--[[
	Deduksi Kunci yang sudah selesai pada sesi ini.

	Irisan antara yang sudah dikerjakan dan daftar milik varian -- bukan
	hitungan mentah `completedDeductions`. Resep deduksi di `engine` dibangun
	dari SELURUH node kasus tanpa filter varian (agar pemain tidak bisa
	menyimpulkan cabang dari resep yang hilang), jadi hitungan mentah akan
	memuat deduksi cabang lain dan membuka gerbang terlalu cepat.
]]
local function keyDeductionsDone(current: Session): number
	return AccusationGate.keyDeductionsDone(current.completedDeductions, current.keyDeductionIds)
end

--[[
	Apakah node sudah terbuka di sesi ini: deduksi selesai, atau meja bukti
	selesai. Dipakai rekap Cold Case untuk menghitung kemajuan nyata.
]]
local function nodeRevealed(current: Session, node: CaseGraph.Node): boolean
	if node.type == "deduction" then
		return current.completedDeductions[node.id] == true
	end
	local entry = PuzzleTableService.get(current.puzzle, node.id)
	return entry ~= nil and entry.solved
end

--[[
	Payload `session_state` -- satu view, tiga proyeksi.

	`Net.CLIENT_VIEWS.session_state` yang memutuskan field mana yang sampai ke
	role mana; berkas ini mengisi seluruh field dan membiarkan `fireToRole`
	memangkasnya. Field yang hanya ada di proyeksi Director
	(`key_deductions_done`, `gate_open`, `contradictions_*`) tidak pernah
	dirakit khusus untuk role lain -- itu yang membuat kebocoran lewat
	kelalaian di sini mustahil.

	`revealed` dihitung HANYA atas node yang aktif di varian ini. Node cabang
	lain tidak pernah muncul di angka mana pun, jadi progres tidak bisa dipakai
	menyimpulkan cabang mana yang sedang berjalan.
]]
local function sessionStatePayload(current: Session, role: string): { [string]: any }
	local case = current.case :: any
	local active = CaseGraph.activeNodes(case, current.variantId or "")
	local done = keyDeductionsDone(current)

	local revealed: { [string]: boolean } = {}
	local deductionsDone = 0
	for _, node in active do
		if nodeRevealed(current, node) then
			revealed[node.id] = true
			if node.type == "deduction" then
				deductionsDone += 1
			end
		end
	end

	return {
		case_id = current.caseId,
		role = role,
		phase = "Investigasi",
		-- PRD §5: rank memperhitungkan waktu; ini anggaran waktunya, sama
		-- dengan yang dipakai `AccusationService.rank`.
		seconds_left = math.max(0, Config.RANK_BUDGET_SECONDS - (os.clock() - current.startedAt)),
		-- Rantai bukti paralel (PRD §6) belum punya representasi di state sesi;
		-- `CaseGraph` punya bentuknya, tapi memetakan kemajuan per rantai
		-- adalah pekerjaan clue board minggu 3 yang belum ada di `main`.
		chains = {},
		deductions_done = deductionsDone,
		key_deductions_required = current.keyDeductionsRequired,
		key_deductions_done = done,
		contradictions_marked = current.gate.contradictionsMarked,
		contradictions_required = current.gate.config.contradictionsRequired,
		gate_open = AccusationGate.gateOpen(current.gate, done, current.keyDeductionsRequired),
		cleanup_seconds_left = AccusationGate.cleanupSecondsLeft(current.gate, os.clock()),
		cold_case_recap = AccusationGate.recap(current.gate, {
			active_nodes = active,
			-- Penyebut rekap dihitung atas node yang SAMA di semua cabang
			-- (`common_ids`), supaya "6 dari 6 bukti" tidak berubah arti antar
			-- varian.
			common_ids = AccusationGate.commonNodeIds(
				case.nodes,
				CaseGraph.variantIds(case),
				CaseGraph.isActive
			),
			revealed = revealed,
			key_deductions_done = done,
			key_deductions_required = current.keyDeductionsRequired,
			attempts_used = current.accusation.attemptsUsed,
		}),
	}
end

--[[
	Mengirim ulang `session_state` ke tiap pemain, diproyeksikan untuk role-nya
	masing-masing.

	Payload dirakit per role, bukan sekali untuk semua: field `role` memang
	harus berisi role PENERIMA, dan `fireToRole` mengirim satu payload yang sama
	ke semua penerima.

	Dipanggil saat state berubah (report, deduksi, kontradiksi, tuduhan),
	bukan dari loop. Timer cleanup tetap akurat karena ia dihitung dari deadline
	-- `math.max(0, deadline - now)` -- bukan dihitung mundur oleh client.
]]
local function pushSessionState(): ()
	local current = session
	if current == nil then
		return
	end

	local remote = remotes["SessionState"]
	if remote == nil then
		warn("[Triangulate] remote 'SessionState' tidak terdaftar")
		return
	end

	for userId, role in current.roles do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			local projected = Net.forRole("session_state", role, sessionStatePayload(current, role))
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

--[[
	Angka gerbang form tuduhan (PRD §5), dalam bentuk datar siap kirim.

	Seluruh angkanya dibaca dari `AccusationGate` -- sumber yang sama dengan
	`sessionStatePayload` dan `handleAccuse` -- supaya umpan balik penandaan
	Kontradiksi tidak pernah melaporkan gerbang yang berbeda dari
	`session_state`. Satu penghitung, satu arti: `gate.contradictionsMarked`
	adalah jumlah Kontradiksi yang BENAR, dan hanya `AccusationGate` yang
	menuliskannya.
]]
local function gateState(current: Session): { [string]: any }
	local done = keyDeductionsDone(current)
	return {
		deductions_done = done,
		key_deductions_required = current.keyDeductionsRequired,
		contradictions_marked = current.gate.contradictionsMarked,
		contradictions_required = current.gate.config.contradictionsRequired,
		gate_open = AccusationGate.gateOpen(current.gate, done, current.keyDeductionsRequired),
	}
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

	-- PRD §5: gerbang form tuduhan dibuka oleh N Deduksi Kunci dan minimal 1
	-- Kontradiksi. Daftar deduksi kunci milik varian yang dipilih dan ambang N
	-- dibaca SEKALI di sini, dari data kasus. Keduanya hanya hidup di server:
	-- yang menyeberang ke Director adalah angkanya (`session_state`), bukan
	-- daftar id-nya -- id `ded_c_*` versus `ded_g_*` sama saja dengan menyebut
	-- pelakunya.
	--
	-- `solution` tidak dideklarasikan di `CaseSource.Case` (skema kasus
	-- dimiliki EXTA-33), jadi dibaca lewat cast `any`, sama seperti `briefings`
	-- dan `suspects` di bawah.
	local keyDeductionIds: { string } = {}
	local solutionByVariant = (loaded :: any).solution
	if type(solutionByVariant) == "table" and variantId ~= nil then
		local entry = solutionByVariant[variantId]
		if type(entry) == "table" and type(entry.required_deductions) == "table" then
			for _, id in entry.required_deductions do
				if type(id) == "string" then
					table.insert(keyDeductionIds, id)
				end
			end
		end
	end

	local keyDeductionsRequired: number
	local declaredKeyDeductions = (loaded :: any).key_deductions
	if type(declaredKeyDeductions) == "number" then
		keyDeductionsRequired = declaredKeyDeductions
	else
		-- Ambang cadangan per tipe kasus (PRD §5). `CaseGraph` yang memegang
		-- peta `case_type` -> N; `Config.KEY_DEDUCTIONS` adalah angka dasar
		-- untuk kasus tanpa `case_type` yang dikenal.
		local caseType = (loaded :: any).case_type
		local byType = nil
		if type(caseType) == "string" then
			byType = CaseGraph.REQUIRED_KEY_DEDUCTIONS[caseType]
		end
		if type(byType) == "number" then
			keyDeductionsRequired = byType
		else
			keyDeductionsRequired = Config.KEY_DEDUCTIONS.standard
		end
	end
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

	-- `kamus-metrik.md` §0.2: titik nol semua durasi adalah
	-- `case_started.t_server_ms`. Di scaffold ini lobby dan ready check belum
	-- berjalan (PRD §8, minggu 5), jadi kasus mulai tepat saat sesi dibuat dan
	-- satu cap waktu mewakili keduanya. Minggu 5 tinggal memanggil
	-- `TelemetryService.markCaseStarted(session.telemetry, telemetryMs())` saat
	-- kasus benar-benar mulai, dan angka lama tidak perlu dihitung ulang.
	--
	-- Dua cap waktu, bukan satu: `startedAt` dalam DETIK karena
	-- `AccusationService.rank` dan durasi sesi memakainya begitu, sedangkan
	-- telemetri wajib `t_server_ms` (§0.2).
	local startedAt = os.clock()
	local telemetryStartedAt = telemetryMs()

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
		obtainedClues = {},
		puzzle = PuzzleTableService.new(PuzzleTable),
		sentPuzzle = nil,
		accusation = AccusationService.newSession(
			solution,
			Config.ACCUSATION_FIELDS,
			Config.MAX_ACCUSATIONS
		),
		keyDeductionIds = keyDeductionIds,
		keyDeductionsRequired = keyDeductionsRequired,
		gate = AccusationGate.newSession({
			contradictionsRequired = Config.MIN_CONTRADICTIONS,
			cleanupSeconds = Config.CLEANUP_SECONDS,
			cleanupPenaltySeconds = Config.CLEANUP_PENALTY_SECONDS,
			cleanupFloorSeconds = Config.CLEANUP_FLOOR_SECONDS,
		}, DeductionEngine.gateOpen, os.clock()),
		-- PRD §4: pernyataan saksi untuk Director, sudah dibersihkan dan diberi
		-- id stabil. Disimpan supaya penandaan Kontradiksi bisa memetakan id
		-- kembali ke pernyataan aslinya tanpa membaca ulang data kasus.
		statements = AccusationGate.publicStatements(
			(loaded :: any).statements or {},
			function(statement: any): boolean
				-- Varian yang tidak dikenal menghasilkan `false` untuk
				-- pernyataan ber-`variants` -- hanya pernyataan yang berlaku di
				-- semua cabang yang lolos. Itu perilaku yang benar: tanpa
				-- varian, tidak ada cabang yang boleh dibocorkan.
				return CaseGraph.statementAppliesTo(statement, variantId or "")
			end
		),
		-- PRD §8 menempatkan lobby dan ready check SEBELUM kasus mulai (minggu 5),
		-- dan `kamus-metrik.md` §1.3 memakai `case_started.t_server_ms` sebagai
		-- titik nol jendela idle. Di scaffold ini keduanya berimpit -- sesi
		-- dibuat tepat saat kasus mulai -- jadi satu cap waktu dipakai untuk
		-- keduanya, dan minggu 5 tinggal memanggil
		-- `TelemetryService.markCaseStarted` saat kasus benar-benar mulai.
		--
		-- `variantId` ikut masuk (SOP-02 langkah 12): tanpa itu "varian mana
		-- yang lebih sering buntu" tidak bisa dihitung dari rekaman sesi.
		telemetry = TelemetryService.newSession(telemetryStartedAt, telemetryStartedAt, variantId),
		startedAt = startedAt,
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
	--
	-- PRD §4: "Tiap kasus punya 2-3 pernyataan saksi/tersangka, minimal satu
	-- berbohong." Saksi pembohong itu milik SATU varian (lihat `variants` di
	-- `$defs.statement`), jadi pernyataan yang dikirim ke Director tidak boleh
	-- diambil dari `briefings.Director.statements` apa adanya -- daftar statis
	-- itu hanya memuat pernyataan yang berlaku di semua cabang. Daftar per
	-- varian dihitung `SharedCaseLoader.projectForRole`, modul yang sama yang
	-- dipakai untuk menyaring node; menyaring ulang di sini akan jadi salinan
	-- kedua dari aturan `CaseGraph.statementAppliesTo`.
	local briefings = loaded.briefings
	if type(briefings) == "table" then
		local directorStatements: { any } = {}
		if variantId ~= nil then
			local projectedDirector = SharedCaseLoader.projectForRole(loaded, variantId, "Director")
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

	-- PRD §7: "Table Preview: Director melihat thumbnail meja Handler
	-- (read-only) supaya tahu progres tanpa bertanya." Yang dikirim hanya
	-- progres (terpasang/total) per meja -- bukan potongan, bukan posisi,
	-- bukan sel tujuan.
	fireToRole("TablePreview", "table_preview", {
		entries = tablePreviewEntries(session.puzzle),
	})

	-- Status awal sesi. Dikirim paling akhir supaya seluruh state sesi sudah
	-- lengkap saat client pertama kali membacanya -- form tuduhan, progres
	-- gerbang, dan timer cleanup semuanya berasal dari sini.
	pushSessionState()
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
		-- terbuka -- `completedDeductions` adalah tabel yang sama yang dibaca
		-- `DeductionEngine.combine` di atas, jadi tidak ada dua keadaan.
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

		-- Yang dikirim ke client adalah objek yang BARU terbuka menurut
		-- `LocationService` -- id itu sudah terlihat di dunia sebagai nama
		-- part, jadi ini tidak menambah kebocoran; yang tetap di server adalah
		-- resep `unlocks` itu sendiri.
		--
		-- Cadangan ke `node.unlocks` hanya berlaku kalau lokasi tidak menahan
		-- objek apa pun: kedua kasus minggu 6 tidak punya `unlocks` sama
		-- sekali, dan di sana nil memang jawaban yang benar -- mengarang
		-- daftar akan menampilkan target yang tidak ada di kasus.
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
			t = telemetryMs(),
			detail = result.deductionId,
		})
		fireToRole("DeductionResult", "deduction", {
			id = result.deductionId,
			clue_ids = ids,
			pinpoint = pinpoint,
			pinpoint_label = pinpointLabel,
			unlocks = if #opened > 0 then opened else unlocks,
		})

		-- PRD §7: "Pinpoint: Director menaruh marker yang terlihat di dunia
		-- Searcher." Remote `Pinpoint` dan view `pinpoint` sudah ada, begitu
		-- pula penanganannya di papan Director -- tanpa tembakan ini keduanya
		-- tidak pernah terisi.
		if pinpoint ~= nil then
			fireToRole("Pinpoint", "pinpoint", {
				id = pinpoint,
				label = pinpointLabel,
			})
		end

		-- Progres gerbang berubah; Director perlu tahu tanpa menebak.
		pushSessionState()
	else
		-- Penolakan juga dijawab. Tanpa balasan, Director yang menekan
		-- kombinasi salah tidak melihat apa pun, dan "kombinasi tidak cocok"
		-- jadi tidak bisa dibedakan dari "deduksi sudah selesai" -- dua
		-- keadaan yang menuntut tindakan berbeda.
		--
		-- Yang TIDAK dikirim: daftar resep, id deduksi yang mendekati cocok,
		-- atau field `supports` mana pun. `result.reason` saja, dan itu pun
		-- hanya menyebut bentuk kegagalannya, bukan isi resepnya.
		fireToRole("DeductionResult", "deduction", {
			id = nil,
			clue_ids = ids,
			pinpoint = nil,
			unlocks = nil,
			reason = result.reason,
		})
	end
end

--[[
	Menerima tuduhan dari Director.

	Urutan pemeriksaan penting: gerbang diperiksa SEBELUM `submit` dipanggil.
	`AccusationService.submit` menaikkan `attemptsUsed`, jadi tuduhan yang
	gerbangnya belum terbuka tidak boleh sampai ke sana -- kalau tidak, client
	yang menembak `Accuse` sejak detik pertama akan menghabiskan 3 percobaan
	tim tanpa satu pun deduksi dikerjakan. Percobaan yang ditolak gerbang TIDAK
	dihitung.

	Balasan saat gerbang tertutup hanya memuat angka progres yang sudah
	Director miliki lewat `session_state`; alasan lengkap dari `AccusationGate`
	tinggal di log server karena ia menyebut syarat mana yang kurang.
]]
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

	local done = keyDeductionsDone(current)
	local admitted, gateProblem =
		AccusationGate.admit(current.gate, done, current.keyDeductionsRequired)
	if not admitted then
		warn(string.format("[Triangulate] tuduhan ditolak gerbang: %s", tostring(gateProblem)))
		fireToRole("AccusationResult", "accusation_result", {
			correct_count = current.accusation.correctFieldCount,
			attempts_left = current.accusation.maxAttempts - current.accusation.attemptsUsed,
			resolved = false,
			won = false,
			pending_confirmation = false,
			rank = nil,
		})
		pushSessionState()
		return
	end

	local result = AccusationService.submit(current.accusation, accusation :: { [string]: any })

	TelemetryService.record(current.telemetry, {
		kind = "accusation",
		role = role,
		t = telemetryMs(),
		detail = tostring(result.correctCount),
	})

	-- PRD §5: feedback salah hanya "X dari 3 benar", tanpa menyebut field mana.
	-- Payload di bawah sengaja tidak punya field `reason` yang bisa membocorkan
	-- field mana yang benar; `reason` hanya dipakai untuk log server.
	if result.reason ~= nil then
		warn(string.format("[Triangulate] tuduhan ditolak: %s", result.reason))
	end

	-- PRD §5: tiap tuduhan salah menurunkan rank dan memajukan timer cleanup.
	-- Percobaan yang menunggu konfirmasi bukan "salah", jadi ia tidak kena
	-- penalti.
	if result.accepted and not result.won and not result.pendingConfirmation then
		local left = AccusationGate.applyWrongPenalty(current.gate, os.clock())
		warn(string.format("[Triangulate] timer cleanup dimajukan; sisa %d detik", left))
	end

	-- PRD §5: setelah 3 salah, kasus jadi Cold Case.
	if result.resolved and not result.won then
		TelemetryService.record(current.telemetry, {
			kind = "cold_case",
			role = role,
			t = telemetryMs(),
			detail = tostring(current.accusation.attemptsUsed),
		})
	end

	fireToRole("AccusationResult", "accusation_result", {
		correct_count = result.correctCount,
		attempts_left = result.attemptsLeft,
		resolved = result.resolved,
		won = result.won,
		pending_confirmation = result.pendingConfirmation,
		-- PRD §5: rank hanya bermakna saat kasus benar-benar berakhir. Kasus
		-- yang habis percobaan selalu berakhir di rank terendah.
		rank = if result.resolved
			then AccusationService.rank(
				os.clock() - current.startedAt,
				current.accusation.attemptsUsed,
				0,
				Config.RANK_BUDGET_SECONDS
			)
			else nil,
	})
	pushSessionState()
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
		-- PRD §5: rank S/A/B/C dari waktu, jumlah tuduhan, dan hint terpakai.
		-- `hintsUsed` masih 0 karena kuota hint belum ada produsennya (PRD §13,
		-- pasca-MVP); angkanya benar hari ini justru karena belum ada hint.
		rank = AccusationService.rank(
			os.clock() - current.startedAt,
			current.accusation.attemptsUsed,
			0,
			Config.RANK_BUDGET_SECONDS
		),
	})
	pushSessionState()
end

--[[
	Menandai Kontradiksi antara sebuah pernyataan saksi dan bukti pembantahnya
	(PRD §4: "Director menandai Kontradiksi antara pernyataan dan bukti").

	Client mengirim ID pernyataan saja, bukan kebenaran dan bukan id bukti.
	`statementId` merujuk pernyataan yang MEMANG dikirim ke Director
	(`session.statements`); pernyataan di luar daftar itu ditolak sebelum
	menyentuh gerbang, supaya client tidak bisa mengintip pernyataan cabang lain
	lewat perbedaan jawaban "diterima" versus "ditolak". Bukti pembantahnya
	dibaca server dari `contradicted_by` di data kasus -- satu pernyataan hanya
	punya satu, jadi mengirim id kedua dari client tidak menambah informasi dan
	hanya membuka kanal untuk menebak id Clue Card yang belum dimiliki Director.

	Penandaan baru sah setelah bukti pembantahnya BENAR-BENAR dikumpulkan
	(`obtainedClues`, diisi saat meja bukti selesai dirakit). Tanpa syarat itu
	Director bisa menandai pernyataan mana pun sejak detik pertama, dan gerbang
	tuduhan (PRD §5) terbuka tanpa kerja deduksi.

	Alasan penolakan yang menyeberang ke client adalah pesan publik
	(`AccusationGate.REJECT_REASON`), BUKAN `reason` dari `AccusationGate` --
	yang itu menyebut id Clue Card yang benar dan tinggal di log server.
]]
local function handleMarkContradiction(player: Player, payload: any): ()
	local current = session
	if current == nil then
		return
	end

	local role = roleOf(player.UserId)
	if role ~= "Director" then
		-- PRD §4: hanya Director yang memegang clue board.
		return
	end

	if type(payload) ~= "table" then
		return
	end

	local statementId = (payload :: { [string]: any }).statement_id
	if type(statementId) ~= "string" then
		return
	end

	-- Pemetaan id -> pernyataan asli. Id dirakit `AccusationGate.publicStatements`
	-- dari indeks array `case.statements`, jadi indeksnya dibaca kembali dari
	-- id. Dua pemeriksaan diperlukan: id harus berbentuk `stmt_<n>` (bukan
	-- string sembarang), dan id itu harus ada di daftar yang dikirim ke
	-- Director.
	local index = tonumber(string.match(statementId, "^stmt_(%d+)$"))
	if index == nil then
		return
	end

	local known = false
	for _, entry in current.statements do
		if entry.id == statementId then
			known = true
			break
		end
	end
	if not known then
		return
	end

	local rawStatements = (current.case :: any).statements
	if type(rawStatements) ~= "table" then
		return
	end
	local statement = rawStatements[index]
	if type(statement) ~= "table" then
		return
	end

	local clueId = (statement :: any).contradicted_by
	if type(clueId) ~= "string" then
		-- Pernyataan tanpa `contradicted_by` tidak dibantah bukti mana pun.
		return
	end

	local accepted, correct, reason = AccusationGate.markContradiction(
		current.gate,
		statementId,
		statement,
		clueId,
		current.obtainedClues
	)

	TelemetryService.record(current.telemetry, {
		kind = "contradiction",
		role = role,
		t = telemetryMs(),
		detail = tostring(correct),
	})

	-- Pesan yang menyeberang ke client selalu salah satu dari dua pesan publik.
	-- `reason` dari gerbang menyebut id Clue Card yang benar, jadi ia hanya
	-- boleh masuk log server -- kalau ia ikut terkirim, satu kali salah tekan
	-- memberi tahu Director bukti mana yang seharusnya dipakai.
	local publicReason: string? = nil
	if not accepted then
		publicReason = if correct
			then AccusationGate.ALREADY_MARKED
			else AccusationGate.REJECT_REASON
		warn(string.format("[Triangulate] kontradiksi ditolak: %s", tostring(reason)))
	end

	-- Dijawab pada terima DAN tolak: tanpa balasan, Director yang menekan
	-- pernyataan salah tidak melihat apa pun, dan "bukan pembohongnya" jadi
	-- tidak bisa dibedakan dari "sudah ditandai".
	--
	-- `statement_id` dikirim sebagai ANGKA (indeks 1-based), sama dengan `id`
	-- di `session_state.statements` -- itu bentuk yang dibaca papan Director.
	local gate = gateState(current)
	fireToRole("ContradictionResult", "contradiction_result", {
		accepted = accepted,
		statement_id = index,
		reason = publicReason,
		marked_count = gate.contradictions_marked,
		contradictions_required = gate.contradictions_required,
		deductions_done = gate.deductions_done,
		key_deductions_required = gate.key_deductions_required,
		gate_open = gate.gate_open,
	})

	if accepted then
		-- PRD §5: kontradiksi yang benar adalah salah satu syarat gerbang, jadi
		-- progresnya dikirim ulang.
		pushSessionState()
	end
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

	-- Graf kasus dan dunia sesi adalah dua sumber yang bisa berbeda, dan yang
	-- menentukan apa yang benar-benar bisa diakses Searcher adalah dunia. Jadi
	-- laporan juga harus lolos pemeriksaan lokasi: objeknya ada di lokasi ini,
	-- dan pemeriksaannya sudah terbuka.
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
		t = telemetryMs(),
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
	--
	-- PRD §4: objek yang dilaporkan masuk ke clue board Director, dan kuncinya
	-- sampai ke Handler. Tiap role menerima proyeksi berbeda dari payload yang
	-- sama -- Handler menerima `gives_key`, Searcher dan Director tidak.
	--
	-- `gives_key` dibaca lewat `keysHeld`, bukan langsung dari node: kunci baru
	-- dianggap milik tim setelah pemeriksaannya selesai. Kalau dibaca langsung
	-- dari node, Searcher bisa mengirim laporan objek yang belum diperiksa dan
	-- Handler langsung menerima kuncinya.
	local held = LocationService.keysHeld(current.location)
	local report = {
		id = string.format("%s:%s", current.caseId, objectId),
		object_id = objectId,
		label = node.label,
		location = current.location.location,
		image = "rbxassetid://0",
		gives_key = if node.gives_key ~= nil and held[node.gives_key] == true
			then node.gives_key
			else nil,
	}
	fireToRole("ReportCard", "report_card", report)
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
			t = telemetryMs(),
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
		t = telemetryMs(),
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
		t = telemetryMs(),
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
		-- PRD §4: bukti yang selesai membuka Clue Card untuk Director. Daftar ini
		-- yang dibaca `AccusationGate.markContradiction` sebagai syarat penandaan
		-- Kontradiksi: penandaan baru sah setelah bukti pembantahnya benar-benar
		-- dikumpulkan.
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

		-- Meja berikutnya yang TERSEDIA menyusul, supaya Handler tidak menunggu
		-- perintah. Yang terkunci tidak dikirim: kuncinya baru datang dari
		-- Searcher, dan `handleInspect` yang akan mengirimnya.
		sendAvailablePuzzle(current)

		-- Bukti yang terbuka menambah `evidence_found` di rekap dan mengubah
		-- jumlah rantai yang hidup; state dikirim ulang supaya Director tidak
		-- bekerja dari angka basi.
		pushSessionState()
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
		t = telemetryMs(),
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
remotes.MarkContradiction.OnServerEvent:Connect(handleMarkContradiction)
remotes.Report.OnServerEvent:Connect(handleReport)
remotes.Ping.OnServerEvent:Connect(handlePing)
remotes.SetTarget.OnServerEvent:Connect(handleSetTarget)
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
