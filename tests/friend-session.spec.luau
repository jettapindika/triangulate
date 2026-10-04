--!strict
-- Uji sesi teman di reserved server (PRD §8, §15, deliverable 7 EXTA-58).
--
-- `TeleportService` tidak bisa dijalankan di playtest Studio -- butuh place
-- yang sudah dipublikasikan. Karena itu keputusannya dipisahkan ke modul murni
-- yang menerima `ReserveServer`/`TeleportToPrivateServer` sebagai argumen, dan
-- berkas ini menyuntikkan pengganti yang mencatat panggilannya. Yang diuji
-- adalah aturan sesi teman, bukan Roblox-nya.

local Harness = require("./harness")
local FriendSession = require("../src/server/FriendSession")

local function fake(): (FriendSession.Dependencies, { [string]: any })
	local calls: { [string]: any } = { reserved = {}, teleported = {} }

	local deps: FriendSession.Dependencies = {
		reserveServer = function(partySize: number): (string?, string?)
			table.insert(calls.reserved, partySize)
			return "access-code-1", nil
		end,
		teleportTo = function(accessCode: string, userIds: { number }): (boolean, string?)
			table.insert(calls.teleported, { code = accessCode, ids = userIds })
			return true, nil
		end,
	}

	return deps, calls
end

Harness.suite("FriendSession: validasi party")

Harness.equal(
	FriendSession.members({ hostUserId = 1, memberIds = { 2, 3 } }),
	{ 1, 2, 3 },
	"host ikut dalam daftar pemain"
)

Harness.check(
	FriendSession.validate({ hostUserId = 1, memberIds = { 2, 3 } }, 3),
	"host + 2 teman = 3 pemain, sesuai MaxPlayers"
)
Harness.check(
	not FriendSession.validate({ hostUserId = 1, memberIds = { 2, 3, 4 } }, 3),
	"host + 3 teman melebihi MaxPlayers dan ditolak"
)
Harness.check(
	FriendSession.validate({ hostUserId = 1, memberIds = {} }, 3),
	"sesi solo (hanya host) tetap sah"
)
Harness.check(
	not FriendSession.validate({ hostUserId = 1, memberIds = { 1 } }, 3),
	"host tidak boleh muncul dua kali"
)
Harness.check(
	not FriendSession.validate({ hostUserId = 1, memberIds = { 2, 2 } }, 3),
	"teman yang sama dua kali ditolak"
)

Harness.suite("FriendSession: alur reserved server")

local deps, calls = fake()
local session = FriendSession.new(deps)

local code, problem = FriendSession.start(session, { hostUserId = 1, memberIds = { 2, 3 } }, 3)
Harness.equal(code, "access-code-1", "akses reserved server dikembalikan ke pemanggil")
Harness.equal(problem, nil, "tidak ada masalah pada alur yang sah")
Harness.equal(calls.reserved, { 3 }, "reserve dipanggil dengan ukuran party, bukan jumlah teman")
Harness.equal(#calls.teleported, 1, "teleport dipanggil sekali")
Harness.equal(calls.teleported[1].code, "access-code-1", "teleport memakai kode dari reserve")
Harness.equal(calls.teleported[1].ids, { 1, 2, 3 }, "host ikut diteleport bersama teman")

local rejectedCode, rejectedProblem =
	FriendSession.start(session, { hostUserId = 1, memberIds = { 2, 3, 4 } }, 3)
Harness.equal(rejectedCode, nil, "party yang terlalu besar tidak menghasilkan kode")
Harness.check(rejectedProblem ~= nil, "party yang terlalu besar disertai alasan")
Harness.equal(#calls.reserved, 1, "reserve tidak dipanggil untuk party yang ditolak")

Harness.suite("FriendSession: kegagalan reserve dan teleport")

local failReserve: FriendSession.Dependencies = {
	reserveServer = function(): (string?, string?)
		return nil, "reserve ditolak"
	end,
	teleportTo = function(): (boolean, string?)
		return true, nil
	end,
}
local reserveCode, reserveProblem =
	FriendSession.start(FriendSession.new(failReserve), { hostUserId = 1, memberIds = {} }, 3)
Harness.equal(reserveCode, nil, "reserve gagal: tidak ada kode")
Harness.equal(reserveProblem, "reserve ditolak", "alasan reserve diteruskan apa adanya")

local teleported = false
local failTeleport: FriendSession.Dependencies = {
	reserveServer = function(): (string?, string?)
		return "access-code-2", nil
	end,
	teleportTo = function(): (boolean, string?)
		teleported = true
		return false, "teleport ditolak"
	end,
}
local teleportCode, teleportProblem =
	FriendSession.start(FriendSession.new(failTeleport), { hostUserId = 1, memberIds = { 2 } }, 3)
Harness.check(teleported, "teleport tetap dicoba setelah reserve berhasil")
Harness.equal(teleportCode, nil, "teleport gagal: kode tidak dilaporkan sebagai sukses")
Harness.equal(teleportProblem, "teleport ditolak", "alasan teleport diteruskan apa adanya")
Harness.finish("friend-session")
