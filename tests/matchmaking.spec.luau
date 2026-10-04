--!strict
-- Uji alur lobby (PRD §8).

local Harness = require("./harness")
local Matchmaking = require("../src/server/Matchmaking")

local CONFIG: Matchmaking.Config = {
	maxPlayers = 3,
	lobbySeconds = 45,
	extendedSeconds = 90,
	readyCheckSeconds = 10,
}

local function player(id: number, preferences: { string }, ready: boolean): Matchmaking.LobbyPlayer
	return { id = id, preferences = preferences, ready = ready, joinedAt = 0 }
end

Harness.suite("Matchmaking: bergabung")

local lobby = Matchmaking.newLobby(1000)
Harness.ok(
	Matchmaking.join(lobby, player(1, { "Searcher" }, false), CONFIG),
	"pemain pertama masuk"
)
Harness.ok(Matchmaking.join(lobby, player(2, { "Handler" }, false), CONFIG), "pemain kedua masuk")

local duplicateJoin = Matchmaking.join(lobby, player(1, { "Searcher" }, false), CONFIG)
Harness.check(not duplicateJoin, "pemain yang sama tidak bisa masuk dua kali")

Harness.ok(Matchmaking.join(lobby, player(3, { "Director" }, false), CONFIG), "pemain ketiga masuk")

-- PRD §15: MaxPlayers = 3.
local fourth = Matchmaking.join(lobby, player(4, { "Director" }, false), CONFIG)
Harness.check(not fourth, "pemain keempat ditolak")

local noPreference = Matchmaking.join(Matchmaking.newLobby(0), player(9, {}, false), CONFIG)
Harness.check(not noPreference, "pemain tanpa preferensi role ditolak")

Harness.suite("Matchmaking: batas waktu")

-- PRD §8: 45 detik dasar; perpanjangan ke 90 hanya bila lobby belum penuh.
local partial = Matchmaking.newLobby(1000)
Matchmaking.join(partial, player(1, { "Searcher" }, false), CONFIG)
Harness.equal(
	Matchmaking.deadline(partial, CONFIG),
	1090,
	"lobby belum penuh memakai batas 90 detik"
)
Harness.equal(Matchmaking.secondsLeft(partial, 1050, CONFIG), 40, "sisa waktu dihitung dari batas")

local full = Matchmaking.newLobby(1000)
Matchmaking.join(full, player(1, { "Searcher" }, false), CONFIG)
Matchmaking.join(full, player(2, { "Handler" }, false), CONFIG)
Matchmaking.join(full, player(3, { "Director" }, false), CONFIG)
Harness.equal(Matchmaking.deadline(full, CONFIG), 1045, "lobby penuh memakai batas 45 detik")

Harness.equal(Matchmaking.secondsLeft(partial, 2000, CONFIG), 0, "sisa waktu tidak pernah negatif")

Harness.suite("Matchmaking: ready check")

-- PRD §8: "Ready check 10 detik sebelum mulai. Pemain yang tidak ready diganti."
local check = Matchmaking.newLobby(0)
Matchmaking.join(check, player(1, { "Searcher" }, true), CONFIG)
Matchmaking.join(check, player(2, { "Handler" }, false), CONFIG)

Harness.equal(Matchmaking.readyFailures(check), { 2 }, "pemain yang belum ready dilaporkan")

local canStart, reason = Matchmaking.canStart(check)
Harness.check(not canStart, "lobby belum bisa mulai sebelum semua ready")
Harness.check(reason ~= nil, "penolakan menyertakan alasan")

Matchmaking.setReady(check, 2, true)
Harness.equal(Matchmaking.readyFailures(check), {}, "tidak ada lagi yang gagal ready")
Harness.ok(Matchmaking.canStart(check), "lobby bisa mulai setelah semua ready")

-- PRD §8 mengizinkan sesi dimulai dengan kurang dari 3 manusia; role kosong
-- diisi NPC. Jadi lobby dengan 2 pemain yang siap tetap bisa mulai.
Harness.equal(#check.players, 2, "lobby berisi 2 pemain")

Harness.suite("Matchmaking: keluar dan isi NPC")

Harness.ok(Matchmaking.leave(check, 2), "pemain bisa keluar")
Harness.check(Matchmaking.find(check, 2) == nil, "pemain yang keluar tidak lagi di lobby")
Harness.check(not Matchmaking.leave(check, 99), "keluar dengan id tak dikenal gagal")

local roles = Matchmaking.rolesWithoutHumans({ "Searcher", "Handler", "Director" }, {
	[1] = "Searcher",
	[2] = "Handler",
})
Harness.equal(roles, { "Director" }, "role tanpa manusia dilaporkan untuk diisi NPC")

Harness.suite("Matchmaking: tukar role")

local swapLobby = Matchmaking.newLobby(0)
Matchmaking.join(swapLobby, player(1, { "Searcher" }, true), CONFIG)
Matchmaking.join(swapLobby, player(2, { "Handler" }, true), CONFIG)

local assigned: { [number]: string } = { [1] = "Searcher", [2] = "Handler" }
Harness.ok(Matchmaking.swap(swapLobby, 1, 2, assigned), "tukar role berhasil")
Harness.equal(assigned[1], "Handler", "role pemain 1 setelah tukar")
Harness.equal(assigned[2], "Searcher", "role pemain 2 setelah tukar")

local badSwap = Matchmaking.swap(swapLobby, 1, 99, assigned)
Harness.check(not badSwap, "tukar dengan pemain di luar lobby ditolak")

return nil
