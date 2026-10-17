--!strict
--[[
	simulate_lobby.luau — menjalankan lobby minggu 5 dengan waktu virtual, memakai
	modul yang benar-benar dipanggil server (PRD §3, §8, §17 minggu 5).

	Yang dibuktikan: urutan fase `LobbyFlow` (menunggu -> started setelah jendela
	perpanjangan 90 detik), penetapan role dari preferensi nyata lewat
	`RoleAssignment`, pengisian role sisa oleh `NPCController`, pengambilalihan
	AFK tepat pada detik ke-60, dan rejoin yang mengembalikan role yang sama
	selama masa tahan 3 menit. Waktu masuk sebagai argumen `now`, jadi tidak ada
	`task.wait` dan tidak ada ketergantungan pada jam dinding.

	Yang TIDAK dibuktikan dan dinyatakan apa adanya: sesi 3 pemain yang benar-
	benar berjalan di Roblox. Lingkungan ini tidak punya runtime Studio, jadi
	yang terbukti adalah urutan lobby dan keputusan role pada modul yang sama —
	bukan tampilan, kontrol sentuh, atau sinkronisasi ke klien.

	Skrip keluar non-nol lewat `error(...)` begitu satu invarian tidak terpenuhi,
	sehingga log di bawahnya adalah artefak lulus/gagal, bukan hiasan.

	Jalankan dari akar checkout repo:

		$HOME/.local/roboxtools/lune.d/lune run tools/simulate_lobby.luau
]]

local Config = require("../src/shared/Config")
local Roles = require("../src/shared/Roles")

local LobbyFlow = require("../src/server/LobbyFlow")
local Matchmaking = require("../src/server/Matchmaking")
local NPCController = require("../src/server/NPCController")
local RoleAssignment = require("../src/server/RoleAssignment")
local SessionPresence = require("../src/server/SessionPresence")

local T0 = 5000

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

-- Nilai sah `assignment_reason` menurut `docs/metrics/skema-event-telemetri.md`.
-- `swap` dan `rejoin` dipakai jalur lain; di sini NPC mengisi role dengan
-- `npc_fill`.
local REASONS: { [string]: boolean } = {
	preference_1 = true,
	preference_2 = true,
	fairness = true,
	npc_fill = true,
	swap = true,
	rejoin = true,
	fill = true,
}

local checks = 0

local function expect(condition: boolean, message: string): ()
	checks += 1
	if not condition then
		error(string.format("INVARIAN GAGAL: %s", message), 2)
	end
end

local function log(at: number, text: string): ()
	print(string.format("[t=%d] %s", at, text))
end

print(string.rep("=", 76))
print("SIMULASI LOBBY MINGGU 5 — 2 manusia + 1 NPC (PRD §3, §8, §17)")
print(string.rep("=", 76))

-- ---------------------------------------------------------------------------
-- Dua manusia masuk, memilih preferensi, lalu menyatakan siap
-- ---------------------------------------------------------------------------

local flow = LobbyFlow.new(Matchmaking.newLobby(T0), CONFIG)
expect(LobbyFlow.phase(flow) == "waiting", "lobby harus mulai dari fase menunggu")

local function join(playerId: number, at: number): ()
	-- Preferensi awal `Roles.ALL` berarti "belum memilih", sama seperti glue
	-- `init.server.luau`; pemain menggantinya lewat `submitPreferences`.
	local ok, reason = Matchmaking.join(flow.lobby, {
		id = playerId,
		preferences = Roles.ALL,
		ready = false,
		joinedAt = at,
	}, CONFIG)
	expect(ok, string.format("pemain %d harus bisa bergabung: %s", playerId, tostring(reason)))
	log(at, string.format("join pemain %d (preferensi belum dipilih)", playerId))
end

join(1, T0)
join(2, T0 + 1)

local P1_PREFS = { "Handler", "Searcher" }
local P2_PREFS = { "Handler", "Director" }

expect(LobbyFlow.submitPreferences(flow, 1, P1_PREFS), "preferensi pemain 1 harus diterima")
log(T0 + 2, string.format("preferensi pemain 1: %s", table.concat(P1_PREFS, ", ")))
expect(LobbyFlow.submitPreferences(flow, 2, P2_PREFS), "preferensi pemain 2 harus diterima")
log(T0 + 3, string.format("preferensi pemain 2: %s", table.concat(P2_PREFS, ", ")))

expect(LobbyFlow.setReady(flow, 1, true), "pemain 1 harus bisa menyatakan siap")
log(T0 + 4, "pemain 1 siap")
expect(LobbyFlow.setReady(flow, 2, true), "pemain 2 harus bisa menyatakan siap")
log(T0 + 5, "pemain 2 siap")

-- ---------------------------------------------------------------------------
-- Jendela dasar 45 detik diperpanjang sampai 90 detik (PRD §8)
-- ---------------------------------------------------------------------------

local atBase = T0 + Config.LOBBY_SECONDS
local early = LobbyFlow.tick(flow, atBase)
expect(early.phase == "waiting", "di detik ke-45 lobby masih menunggu: perpanjangan menahan")
expect(not early.changed, "fase tidak berubah di jendela dasar")
expect(
	LobbyFlow.secondsLeft(flow, atBase) == Config.LOBBY_EXTENDED_SECONDS - Config.LOBBY_SECONDS,
	"sisa waktu mengikuti jendela perpanjangan, bukan jendela dasar"
)
log(atBase, string.format("tick: fase=waiting sisa=%ds", LobbyFlow.secondsLeft(flow, atBase)))

local atStart = T0 + Config.LOBBY_EXTENDED_SECONDS
local started = LobbyFlow.tick(flow, atStart)
expect(started.phase == "started", "jendela 90 detik habis: lobby harus mulai")
expect(started.changed, "perubahan fase harus dilaporkan")
expect(#started.dropped == 0, "tidak ada pemain yang diganti karena keduanya siap")
expect(#flow.lobby.players == 2, "dua manusia bertahan sampai sesi mulai")
log(atStart, "tick: fase=started (jendela perpanjangan 90s habis)")

local view = LobbyFlow.snapshot(flow, atStart, 1)
local viewPrefs = view.preferences or {}
expect(view.phase == "started", "snapshot melaporkan fase started")
expect(view.player_count == 2 and view.ready_count == 2, "snapshot melaporkan 2 pemain, 2 siap")
expect(view.max_players == Config.MAX_PLAYERS, "batas pemain diambil dari Config")
log(
	atStart,
	string.format(
		"lobby_state (pemain 1): fase=%s pemain=%d/%d siap=%d sisa=%ds preferensi=%s",
		view.phase,
		view.player_count,
		view.max_players,
		view.ready_count,
		view.seconds_left,
		table.concat(viewPrefs, ",")
	)
)

local outsider = LobbyFlow.snapshot(flow, atStart, 99)
expect(
	outsider.preferences == nil and outsider.ready == nil,
	"pemain di luar lobby tidak diberi preferensi maupun status siap"
)

-- ---------------------------------------------------------------------------
-- Penetapan role dari preferensi nyata, lalu role sisa diisi NPC (PRD §8)
-- ---------------------------------------------------------------------------

local refs: { RoleAssignment.PlayerRef } = {}
local refById: { [number]: RoleAssignment.PlayerRef } = {}
for _, player in flow.lobby.players do
	local ref: RoleAssignment.PlayerRef = {
		id = player.id,
		preferences = player.preferences,
		recentRoles = {},
		isNew = false,
	}
	table.insert(refs, ref)
	refById[player.id] = ref
end

local assigned = RoleAssignment.assign(refs, Roles.ALL, OPTS)
expect(assigned[1] == "Searcher", "pemain 1 mendapat preferensi keduanya")
expect(assigned[2] == "Director", "pemain 2 mendapat preferensi keduanya")

local humanRoles: { [string]: boolean } = {}
for _, role in assigned do
	humanRoles[role] = true
end

local npcRoles = NPCController.rolesToFill(humanRoles, Roles.ALL, Roles.NPC_FILLABLE)
expect(#npcRoles == 1, "NPC harus mengisi tepat satu role")
expect(npcRoles[1] == "Handler", "role yang diisi NPC adalah Handler")

local unstaffed = Matchmaking.rolesWithoutHumans(Roles.ALL, assigned)
expect(#unstaffed == 1 and unstaffed[1] == npcRoles[1], "role kosong sama dengan yang diisi NPC")

local covered: { [string]: boolean } = {}
for _, role in assigned do
	covered[role] = true
end
for _, role in npcRoles do
	covered[role] = true
end
for _, role in Roles.ALL do
	expect(covered[role] == true, string.format("role %s harus terisi", role))
end

log(atStart, string.format("role: 1=%s 2=%s npc=%s", assigned[1], assigned[2], npcRoles[1]))

local reasonParts: { string } = {}
for _, player in flow.lobby.players do
	local role = assigned[player.id]
	local reason = RoleAssignment.reasonFor(refById[player.id], Roles.ALL, OPTS, role)
	expect(REASONS[reason] == true, string.format("alasan '%s' harus dari skema telemetri", reason))
	table.insert(reasonParts, string.format("%d=%s/%s", player.id, role, reason))
end
table.insert(reasonParts, string.format("npc=%s/npc_fill", npcRoles[1]))
log(atStart, "assignment_reason: " .. table.concat(reasonParts, " "))

local npcAction = NPCController.nextAction("Handler", { unlockedEvidence = nil })
expect(npcAction.kind == "idle", "NPC Handler menganggur selama belum ada bukti terbuka")
log(atStart, string.format("NPC Handler aksi berikutnya: %s", npcAction.kind))

-- ---------------------------------------------------------------------------
-- Pengambilalihan AFK tepat pada detik ke-60 (PRD §8, kriteria terima b)
-- ---------------------------------------------------------------------------

local sessionRoles: { [number]: string } = { [1] = assigned[1], [2] = assigned[2] }
local presence = SessionPresence.new(T0)
SessionPresence.touch(presence, 1, atStart)
log(atStart, "input pemain 1 dicatat: jam AFK mulai")

local atAfk = atStart + Config.AFK_SECONDS
local below = SessionPresence.takeovers(presence, sessionRoles, atAfk - 1, Config.AFK_SECONDS)
expect(#below == 0, "di bawah ambang AFK belum ada pengambilalihan")
expect(
	not NPCController.shouldTakeOver(Config.AFK_SECONDS - 1, Config.AFK_SECONDS),
	"shouldTakeOver belum jatuh tempo di bawah ambang"
)
log(atAfk - 1, "cek AFK 59s: belum jatuh tempo")

local due = SessionPresence.takeovers(presence, sessionRoles, atAfk, Config.AFK_SECONDS)
expect(#due == 1, "tepat 60 detik tanpa input: NPC harus mengambil alih")
expect(
	NPCController.shouldTakeOver(Config.AFK_SECONDS, Config.AFK_SECONDS),
	"shouldTakeOver jatuh tempo tepat di ambang"
)
expect(due[1].userId == 1, "yang diambil alih adalah pemain 1")
expect(due[1].role == "Searcher", "role yang diambil alih ikut dilaporkan")
expect(due[1].reason == "afk_60s", "alasan pengambilalihan sesuai skema telemetri")
log(
	atAfk,
	string.format(
		"NPC takeover: pemain %d role=%s alasan=%s",
		due[1].userId,
		due[1].role,
		due[1].reason
	)
)

-- PRD §8: "state tetap utuh" — role tetap tercatat pada pemainnya selama NPC
-- mengambil alih, sehingga tidak ada penugasan ulang.
expect(sessionRoles[1] == "Searcher", "role pemain tetap tercatat selama NPC mengambil alih")
expect(assigned[1] == "Searcher", "penugasan awal tidak berubah")

local again = SessionPresence.takeovers(presence, sessionRoles, atAfk + 30, Config.AFK_SECONDS)
expect(#again == 0, "pengambilalihan yang sama tidak dilaporkan dua kali")
log(atAfk + 30, "cek ulang: pengambilalihan yang sama tidak dilaporkan lagi")

-- ---------------------------------------------------------------------------
-- Disconnect, rejoin di dalam masa tahan, dan rejoin setelah masa tahan
-- (PRD §8, kriteria terima c)
-- ---------------------------------------------------------------------------

local dropAt = atAfk + 50
SessionPresence.markDisconnected(presence, 2, sessionRoles[2], dropAt)
log(dropAt, string.format("pemain 2 disconnect (role %s ditahan)", sessionRoles[2]))

local onDrop = SessionPresence.takeovers(presence, sessionRoles, dropAt + 1, Config.AFK_SECONDS)
expect(#onDrop == 1, "disconnect langsung memicu pengambilalihan")
expect(onDrop[1].reason == "disconnect", "alasannya disconnect, bukan AFK")
expect(onDrop[1].role == "Director", "NPC mengisi role yang ditinggalkan")
expect(sessionRoles[2] == "Director", "role tetap tercatat supaya slot bisa dikembalikan")
log(
	dropAt + 1,
	string.format(
		"NPC takeover: pemain %d role=%s alasan=%s",
		onDrop[1].userId,
		onDrop[1].role,
		onDrop[1].reason
	)
)

local holdSeconds = Config.REJOIN_HOLD_SECONDS
local beforeHold = SessionPresence.releasedSlots(presence, dropAt + holdSeconds - 1, holdSeconds)
expect(#beforeHold == 0, "sebelum 3 menit slot masih ditahan")
expect(
	not NPCController.shouldReleaseSlot(holdSeconds - 1, holdSeconds),
	"shouldReleaseSlot menolak di bawah masa tahan"
)

local rejoined, role = SessionPresence.rejoin(presence, 2, dropAt + holdSeconds - 1, holdSeconds)
expect(rejoined, "rejoin di dalam 3 menit harus diterima")
expect(role == sessionRoles[2], "rejoin mengembalikan role yang sama, bukan role baru")
log(
	dropAt + holdSeconds - 1,
	string.format("rejoin pemain 2: role=%s alasan=rejoin (slot yang sama)", tostring(role))
)

-- Setelah kembali, pemain disconnect lagi; kali ini masa tahan dibiarkan habis.
local drop2 = dropAt + holdSeconds + 1
SessionPresence.markDisconnected(presence, 2, sessionRoles[2], drop2)
log(drop2, string.format("pemain 2 disconnect lagi (role %s ditahan)", sessionRoles[2]))

local released = SessionPresence.releasedSlots(presence, drop2 + holdSeconds, holdSeconds)
expect(#released == 1, "tepat 3 menit slot dibuka untuk pengganti")
expect(
	NPCController.shouldReleaseSlot(holdSeconds, holdSeconds),
	"shouldReleaseSlot jatuh tempo tepat di masa tahan"
)
expect(
	released[1].userId == 2 and released[1].role == "Director",
	"slot yang dibuka milik pemain 2"
)
log(
	drop2 + holdSeconds,
	string.format(
		"slot pemain %d dibuka untuk pengganti (role %s)",
		released[1].userId,
		released[1].role
	)
)

local lateOk, lateRole = SessionPresence.rejoin(presence, 2, drop2 + holdSeconds, holdSeconds)
expect(not lateOk, "rejoin setelah masa tahan harus ditolak")
expect(lateRole == nil, "tidak ada role yang dikembalikan setelah masa tahan")
log(drop2 + holdSeconds, "rejoin pemain 2 ditolak: di luar masa tahan")

-- ---------------------------------------------------------------------------
-- Ringkasan
-- ---------------------------------------------------------------------------

print(string.rep("=", 76))
print(string.format("HASIL: %d invarian terpenuhi, 0 gagal.", checks))
print("Lobby 3 pemain (2 manusia + 1 NPC) mulai; AFK 60s, disconnect, dan rejoin terbukti.")
