--!strict
-- Bukti gate minggu 5 (PRD §17 minggu 5, kriteria terima EXTA-58 a-d).
--
-- Empat kriteria terima diuji berurutan di sini, memakai modul yang benar-benar
-- dipakai server -- bukan salinan tangan:
--
--   (a) sesi 3 pemain (2 manusia + 1 NPC) mulai dari lobby sampai gameplay;
--   (b) pengambilalihan AFK pada detik ke-60 tidak menghilangkan state sesi;
--   (c) rejoin di dalam 3 menit mengembalikan pemain ke slot yang sama;
--   (d) preferensi role dihormati, termasuk kasus keadilan dan pemain baru.
--
-- Waktu seluruhnya waktu virtual (`now` sebagai argumen), jadi tidak ada
-- `task.wait` dan tidak ada uji yang bergantung pada jam dinding. Ambangnya
-- dibaca dari `Config`/`Roles`, bukan ditulis ulang.
--
-- Yang TIDAK bisa dibuktikan di sini dan dinyatakan apa adanya: bahwa klien
-- Roblox benar-benar menjalankan sesi ini. Lingkungan ini tidak punya runtime
-- Studio, jadi yang dibuktikan adalah urutan lobby, penugasan role, dan
-- pengambilalihan pada modul yang sama yang dipanggil server.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")

local Config = require("../src/shared/Config")
local Roles = require("../src/shared/Roles")
local PuzzleTable = require("../src/shared/PuzzleTable")
local CaseLoader = require("../src/shared/case/CaseLoader")

local LobbyFlow = require("../src/server/LobbyFlow")
local Matchmaking = require("../src/server/Matchmaking")
local NPCController = require("../src/server/NPCController")
local PuzzleTableService = require("../src/server/PuzzleTableService")
local RoleAssignment = require("../src/server/RoleAssignment")
local SessionPresence = require("../src/server/SessionPresence")

local CONFIG: Matchmaking.Config = {
	maxPlayers = Config.MAX_PLAYERS,
	lobbySeconds = Config.LOBBY_SECONDS,
	extendedSeconds = Config.LOBBY_EXTENDED_SECONDS,
	readyCheckSeconds = Config.READY_CHECK_SECONDS,
}

local OPTS: RoleAssignment.Options = {
	fairnessStreak = Roles.FAIRNESS_STREAK,
	newPlayerExcludedRole = Roles.NEW_PLAYER_EXCLUDED_ROLE,
}

local T0 = 5000

local function rng(): () -> number
	local seed = 0
	return function(): number
		seed += 1
		return (seed * 0.37) % 1
	end
end

local function ref(
	id: number,
	preferences: { string },
	recentRoles: { string },
	isNew: boolean
): RoleAssignment.PlayerRef
	return { id = id, preferences = preferences, recentRoles = recentRoles, isNew = isNew }
end

-- ---------------------------------------------------------------------------
-- (a) Lobby 3 pemain: 2 manusia + 1 NPC
-- ---------------------------------------------------------------------------

Harness.suite("gate minggu 5: sesi 3 pemain mulai dari lobby")

local flow = LobbyFlow.new(Matchmaking.newLobby(T0), CONFIG)
Harness.equal(LobbyFlow.phase(flow), "waiting", "lobby mulai dari fase menunggu")

local function joinLobby(id: number, at: number): ()
	-- Preferensi awal `Roles.ALL` berarti "belum memilih"; pemain menggantinya
	-- lewat `submitPreferences`, persis seperti lobby `init.server.luau`.
	local ok, reason = Matchmaking.join(flow.lobby, {
		id = id,
		preferences = Roles.ALL,
		ready = false,
		joinedAt = at,
	}, CONFIG)
	assert(ok, string.format("pemain %d harus bisa bergabung: %s", id, tostring(reason)))
end

joinLobby(1, T0)
joinLobby(2, T0 + 1)

local P1_PREFS = { "Handler", "Searcher" }
local P2_PREFS = { "Handler", "Director" }
assert(LobbyFlow.submitPreferences(flow, 1, P1_PREFS), "preferensi pemain 1 diterima")
assert(LobbyFlow.submitPreferences(flow, 2, P2_PREFS), "preferensi pemain 2 diterima")
assert(LobbyFlow.setReady(flow, 1, true), "pemain 1 menyatakan siap")
assert(LobbyFlow.setReady(flow, 2, true), "pemain 2 menyatakan siap")

-- PRD §8: tanpa 3 manusia, pemain menunggu sampai jendela 90 detik habis, lalu
-- role yang kosong diisi NPC. Kedua manusia sudah siap, jadi saat jendela
-- habis lobby langsung masuk ready check dan mulai tanpa menunggu 10 detik.
local atWindowEnd = LobbyFlow.tick(flow, T0 + Config.LOBBY_EXTENDED_SECONDS)
Harness.equal(atWindowEnd.phase, "started", "jendela 90 detik habis: sesi mulai")
Harness.equal(atWindowEnd.dropped, {}, "tidak ada pemain yang diganti")
Harness.equal(#flow.lobby.players, 2, "dua manusia bertahan sampai sesi mulai")

-- Penetapan role memakai masukan nyata dari lobby: preferensi yang dipilih
-- pemain, bukan `Roles.ALL` seperti scaffold minggu 0.
local refs: { RoleAssignment.PlayerRef } = {}
for _, player in flow.lobby.players do
	table.insert(refs, ref(player.id, player.preferences, {}, false))
end

local assigned = RoleAssignment.assign(refs, Roles.ALL, OPTS)
Harness.equal(assigned[1], "Searcher", "pemain 1 mendapat preferensi keduanya")
Harness.equal(assigned[2], "Director", "pemain 2 mendapat preferensi keduanya")

local humanRoles: { [string]: boolean } = {}
for _, role in assigned do
	humanRoles[role] = true
end

local npcRoles = NPCController.rolesToFill(humanRoles, Roles.ALL, Roles.NPC_FILLABLE)
Harness.equal(npcRoles, { "Handler" }, "NPC mengisi satu role yang tersisa")

-- PRD §8/§16: NPC Director adalah P1, jadi Director harus dipegang manusia.
-- Kalau tidak, sesi ini bukan gate minggu 5 melainkan minggu 6.
local unstaffed: { string } = {}
for _, role in Matchmaking.rolesWithoutHumans(Roles.ALL, assigned) do
	local filled = false
	for _, npcRole in npcRoles do
		if npcRole == role then
			filled = true
		end
	end
	if not filled then
		table.insert(unstaffed, role)
	end
end
Harness.equal(unstaffed, {}, "ketiga role terisi: 2 manusia + 1 NPC")

-- ---------------------------------------------------------------------------
-- (a, lanjutan) NPC Handler merakit bukti setelah kuncinya diberikan
-- ---------------------------------------------------------------------------

Harness.suite("gate minggu 5: NPC Handler merakit bukti")

local gallery = serde.decode("json", fs.readFile("data/cases/gallery_01.json"))
local load = CaseLoader.load(gallery, "seed-gate-minggu-5")
assert(load.ok, "gallery_01 harus lolos validator")

local variantId = (load.session :: any).variant_id
local service = PuzzleTableService.new(PuzzleTable)
local built, skipped = PuzzleTableService.build(
	service,
	gallery.nodes,
	variantId,
	Config.TABLE_WIDTH,
	Config.TABLE_HEIGHT,
	rng()
)
Harness.equal(#skipped, 0, "tidak ada node bukti bertipe puzzle tak dikenal")
for _, entry in built do
	PuzzleTableService.register(service, entry)
end

-- PRD §4 langkah 2: Searcher melaporkan objek, dan laporan itu memberi *kunci*
-- ke Handler. Kunci inilah yang membuka potongan bukti -- jadi NPC Handler
-- hanya boleh merakit bukti yang kuncinya benar-benar sudah didapat.
local held: { [string]: boolean } = {}
for _, node in gallery.nodes do
	if node.type == "object" and type(node.gives_key) == "string" then
		held[node.gives_key] = true
		break
	end
end

local unlockedEvidence: { [string]: boolean } = {}
for _, node in gallery.nodes do
	if node.type == "evidence" then
		local ok = true
		if type(node.needs) == "table" then
			for _, key in node.needs do
				if not held[key] then
					ok = false
				end
			end
		end
		if ok then
			unlockedEvidence[node.id] = true
		end
	end
end

local first = PuzzleTableService.firstUnlocked(service, unlockedEvidence)
assert(first ~= nil, "setidaknya satu bukti terbuka setelah objek pertama dilaporkan")
Harness.equal(first.node_id, "ev_schedule", "rantai pertama PRD §4 terbuka")

-- PRD §8: NPC Handler "merakit potongan otomatis dengan kecepatan lambat".
-- Satu potongan per langkah, dan setiap langkah diminta lewat
-- `NPCController.nextAction` -- bukan loop lokal di uji ini.
local ticks = 0
local progressTrace: { number } = {}
while not first.solved and ticks < 64 do
	local action = NPCController.nextAction("Handler", { unlockedEvidence = first.node_id })
	Harness.equal(action.kind, "assemble_slowly", "NPC Handler merakit, bukan menganggur")
	Harness.equal(action.target, "ev_schedule", "NPC merakit bukti yang terbuka")

	local pieceId, u, v = PuzzleTableService.nextPlacement(first)
	assert(
		pieceId ~= nil and u ~= nil and v ~= nil,
		"meja yang belum selesai punya potongan berikutnya"
	)
	local payload = PuzzleTableService.place(service, first.node_id, pieceId, u, v)
	assert(payload ~= nil, "penempatan NPC Handler harus diterima")
	-- Kurung di sekitar panggilan itu wajib: `progress` mengembalikan
	-- `(terpasang, total)`, dan `table.insert(t, f())` membacanya sebagai
	-- `(posisi, nilai)` -- tanpa kurung, `progressTrace` berisi total, bukan
	-- kemajuan. Yang diuji di sini adalah kemajuan per langkah.
	table.insert(progressTrace, (PuzzleTableService.progress(service, first.node_id)))
	ticks += 1
end

Harness.check(first.solved, "meja ev_schedule selesai dirakit NPC Handler")
Harness.equal(progressTrace[1], 1, "progres bertambah satu potongan per langkah, bukan melompat")
Harness.equal(progressTrace[#progressTrace], 16, "progres berakhir 16/16")
Harness.equal(first.yields, "clue_guard_off", "bukti yang selesai menghasilkan Clue Card")

-- ---------------------------------------------------------------------------
-- (b) Pengambilalihan AFK pada detik ke-60
-- ---------------------------------------------------------------------------

Harness.suite("gate minggu 5: pengambilalihan AFK menjaga state sesi")

-- Potongan state sesi yang harus utuh: role yang tercatat, meja puzzle, dan
-- deduksi yang sudah selesai. Inilah "state tetap utuh" pada PRD §8.
local sessionRoles: { [number]: string } = { [1] = "Searcher", [2] = "Director" }
local completedDeductions: { [string]: boolean } = { ded_c_culprit_1 = true }
local progressBefore = PuzzleTableService.progress(service, "ev_schedule")
local solvedBefore = first.solved

local presence = SessionPresence.new(T0)
SessionPresence.touch(presence, 1, T0 + 10)

local below = SessionPresence.takeovers(
	presence,
	sessionRoles,
	T0 + 10 + Config.AFK_SECONDS - 1,
	Config.AFK_SECONDS
)
Harness.equal(below, {}, "di bawah 60 detik belum ada pengambilalihan")

local takeovers = SessionPresence.takeovers(
	presence,
	sessionRoles,
	T0 + 10 + Config.AFK_SECONDS,
	Config.AFK_SECONDS
)
Harness.equal(#takeovers, 1, "tepat 60 detik tanpa input: NPC mengambil alih role itu")
Harness.equal(takeovers[1].userId, 1, "yang diambil alih adalah pemain yang AFK")
Harness.equal(takeovers[1].role, "Searcher", "role yang diambil alih ikut dilaporkan")
Harness.equal(takeovers[1].reason, "afk_60s", "alasan sesuai skema telemetri")

Harness.equal(
	SessionPresence.takeovers(
		presence,
		sessionRoles,
		T0 + 10 + Config.AFK_SECONDS + 30,
		Config.AFK_SECONDS
	),
	{},
	"pengambilalihan yang sama tidak dilaporkan dua kali"
)

-- State sesi tidak boleh tersentuh oleh pengambilalihan.
Harness.equal(sessionRoles[1], "Searcher", "role pemain tetap tercatat selama NPC mengambil alih")
Harness.equal(sessionRoles[2], "Director", "role pemain lain tidak ikut berubah")
Harness.equal(
	PuzzleTableService.progress(service, "ev_schedule"),
	progressBefore,
	"progres meja tidak hilang saat pengambilalihan"
)
Harness.equal(first.solved, solvedBefore, "meja yang selesai tetap selesai")
Harness.equal(
	completedDeductions.ded_c_culprit_1,
	true,
	"deduksi yang sudah selesai tetap tercatat"
)

-- Pemain kembali bermain: kendali role-nya kembali tanpa penugasan ulang.
SessionPresence.touch(presence, 1, T0 + 10 + Config.AFK_SECONDS + 1)
Harness.equal(
	SessionPresence.takeovers(
		presence,
		sessionRoles,
		T0 + 10 + Config.AFK_SECONDS + 30,
		Config.AFK_SECONDS
	),
	{},
	"input baru mengembalikan kendali ke pemain"
)
Harness.equal(sessionRoles[1], "Searcher", "role tidak berpindah pemain setelah pemain kembali")

-- ---------------------------------------------------------------------------
-- (c) Disconnect dan rejoin di dalam 3 menit
-- ---------------------------------------------------------------------------

Harness.suite("gate minggu 5: rejoin kembali ke slot yang sama")

local dropAt = T0 + 400
SessionPresence.markDisconnected(presence, 2, sessionRoles[2], dropAt)

local onDisconnect =
	SessionPresence.takeovers(presence, sessionRoles, dropAt + 1, Config.AFK_SECONDS)
Harness.equal(
	#onDisconnect,
	1,
	"disconnect langsung memicu pengambilalihan, tanpa menunggu 60 detik"
)
Harness.equal(onDisconnect[1].role, "Director", "NPC mengisi role yang ditinggalkan")
Harness.equal(onDisconnect[1].reason, "disconnect", "alasannya disconnect, bukan AFK")
Harness.equal(sessionRoles[2], "Director", "role tetap tercatat supaya slot bisa dikembalikan")

Harness.equal(
	SessionPresence.releasedSlots(
		presence,
		dropAt + Config.REJOIN_HOLD_SECONDS - 1,
		Config.REJOIN_HOLD_SECONDS
	),
	{},
	"sebelum 3 menit, slot masih ditahan untuk pemain yang disconnect"
)

local rejoined, role = SessionPresence.rejoin(
	presence,
	2,
	dropAt + Config.REJOIN_HOLD_SECONDS - 1,
	Config.REJOIN_HOLD_SECONDS
)
Harness.ok(rejoined, "rejoin di dalam 3 menit diterima")
Harness.equal(role, "Director", "rejoin mengembalikan role yang sama, bukan role baru")
Harness.equal(sessionRoles[2], role, "slot yang dikembalikan adalah slot yang sama")

local again, _ = SessionPresence.rejoin(presence, 2, dropAt + 10, Config.REJOIN_HOLD_SECONDS)
Harness.check(not again, "rejoin kedua ditolak: slot sudah kembali ke pemain")

-- Slot yang tidak dipakai kembali dibuka untuk pemain pengganti (PRD §8).
local lateDropAt = T0 + 900
SessionPresence.markDisconnected(presence, 3, "Handler", lateDropAt)
local released = SessionPresence.releasedSlots(
	presence,
	lateDropAt + Config.REJOIN_HOLD_SECONDS,
	Config.REJOIN_HOLD_SECONDS
)
Harness.equal(#released, 1, "tepat 3 menit, slot dibuka")
Harness.equal(released[1].userId, 3, "slot yang dibuka milik pemain yang disconnect")
Harness.equal(released[1].role, "Handler", "role yang dibuka ikut dilaporkan")

local tooLate, lateRole = SessionPresence.rejoin(
	presence,
	3,
	lateDropAt + Config.REJOIN_HOLD_SECONDS,
	Config.REJOIN_HOLD_SECONDS
)
Harness.check(not tooLate, "rejoin setelah slot dibuka ditolak")
Harness.equal(lateRole, nil, "tidak ada role yang dikembalikan")

-- ---------------------------------------------------------------------------
-- (d) Preferensi role, keadilan, dan pemain baru
-- ---------------------------------------------------------------------------

Harness.suite("gate minggu 5: preferensi role dan keadilan")

-- Kasus dasar: tiga pemain, tiga role, semuanya mendapat preferensi pertama.
local basic = RoleAssignment.assign({
	ref(1, { "Searcher", "Handler" }, {}, false),
	ref(2, { "Handler", "Director" }, {}, false),
	ref(3, { "Director", "Searcher" }, {}, false),
}, Roles.ALL, OPTS)
Harness.equal(basic[1], "Searcher", "pemain 1 mendapat preferensi pertama")
Harness.equal(basic[2], "Handler", "pemain 2 mendapat preferensi pertama")
Harness.equal(basic[3], "Director", "pemain 3 mendapat preferensi pertama")
Harness.equal(
	RoleAssignment.reasonFor(
		ref(1, { "Searcher", "Handler" }, {}, false),
		Roles.ALL,
		OPTS,
		"Searcher"
	),
	"preference_1",
	"alasan penugasan preferensi pertama"
)
Harness.equal(
	RoleAssignment.reasonFor(
		ref(1, { "Searcher", "Handler" }, {}, false),
		Roles.ALL,
		OPTS,
		"Handler"
	),
	"preference_2",
	"alasan penugasan preferensi kedua"
)
Harness.equal(
	RoleAssignment.reasonFor(
		ref(1, { "Searcher", "Handler" }, {}, false),
		Roles.ALL,
		OPTS,
		"Director"
	),
	"fill",
	"alasan penugasan di luar preferensi"
)

-- PRD §8: pemain yang memegang role sama 3 sesi berturut-turut diprioritaskan
-- ke preferensi keduanya. Dua pemain dengan preferensi identik: tanpa riwayat,
-- pemain ber-id lebih kecil mendapat Handler lebih dulu dan pemain 2 tetap di
-- Searcher; dengan rentetan 3 sesi Searcher, pemain 2 didorong ke Handler.
local ROLES2 = { "Searcher", "Handler" }
local withoutFairness = RoleAssignment.assign({
	ref(1, { "Searcher", "Handler" }, {}, false),
	ref(2, { "Searcher", "Handler" }, {}, false),
}, ROLES2, OPTS)
Harness.equal(withoutFairness[2], "Searcher", "tanpa riwayat, pemain 2 tetap di role yang sama")

local streaked = ref(2, { "Searcher", "Handler" }, { "Searcher", "Searcher", "Searcher" }, false)
local withFairness = RoleAssignment.assign({
	ref(1, { "Searcher", "Handler" }, {}, false),
	streaked,
}, ROLES2, OPTS)
Harness.equal(withFairness[2], "Handler", "rentetan 3 sesi: pemain 2 dipindah ke preferensi kedua")
Harness.equal(withFairness[1], "Searcher", "pemain lain mengambil role yang ditinggalkan")
Harness.equal(
	RoleAssignment.reasonFor(streaked, ROLES2, OPTS, "Handler"),
	"fairness",
	"alasan penugasannya keadilan, bukan preferensi biasa"
)
Harness.equal(
	RoleAssignment.reasonFor(streaked, ROLES2, OPTS, "Searcher"),
	"fairness",
	"role pertama yang ditinggalkan tetap dilaporkan sebagai keadilan"
)

-- PRD §8: "Pemain baru tidak otomatis jadi Director di sesi pertama."
--
-- Role set-nya HARUS memuat `Director` -- itulah satu-satunya role yang
-- disentuh aturan ini. Dengan `ROLES2` (Searcher/Handler) blok ini tidak
-- menguji apa pun: `assign` tidak pernah bisa mengembalikan role di luar
-- himpunan yang diberikan, jadi harapan "jatuh ke Director" mustahil dipenuhi
-- dan aturan pemain baru tidak akan pernah terlihat bekerja.
local ROLES_NEW_PLAYER = { "Searcher", "Director" }
local newRef = ref(2, { "Director", "Searcher" }, {}, true)
local newWithRule = RoleAssignment.assign({
	ref(1, { "Searcher", "Director" }, {}, false),
	newRef,
}, ROLES_NEW_PLAYER, OPTS)
Harness.equal(
	newWithRule[2],
	"Searcher",
	"pemain baru tidak jatuh ke Director selama ada alternatif"
)

local newWithoutRule = RoleAssignment.assign({
	ref(1, { "Searcher", "Director" }, {}, false),
	ref(2, { "Director", "Searcher" }, {}, false),
}, ROLES_NEW_PLAYER, OPTS)
Harness.equal(
	newWithoutRule[2],
	"Director",
	"tanpa aturan pemain baru, id 2 memang jatuh ke Director"
)

Harness.finish("lobby-gate-minggu-5")
