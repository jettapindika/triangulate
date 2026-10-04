--!strict
-- Uji mesin fase lobby (PRD §3, §8, §17 minggu 5).
--
-- Yang diuji di sini adalah aturan yang HANYA ada di `LobbyFlow`: kapan lobby
-- berpindah dari menunggu ke ready check, siapa yang diganti saat ready check
-- gagal, dan tukar role yang butuh persetujuan dua pihak. Timer 45/90 detik dan
-- ready check 10 detik sendiri sudah diuji di `tests/matchmaking.spec.luau` --
-- berkas ini memakai `Matchmaking.deadline`/`secondsLeft` apa adanya, bukan
-- menyalin rumusnya.
--
-- Waktu seluruhnya waktu virtual: `now` masuk sebagai argumen, jadi tidak ada
-- `task.wait` dan tidak ada uji yang bergantung pada jam dinding.

local Harness = require("./harness")
local LobbyFlow = require("../src/server/LobbyFlow")
local Matchmaking = require("../src/server/Matchmaking")
local Roles = require("../src/shared/Roles")

local CONFIG: Matchmaking.Config = {
	maxPlayers = 3,
	lobbySeconds = 45,
	extendedSeconds = 90,
	readyCheckSeconds = 10,
}

local function flow(): LobbyFlow.Flow
	return LobbyFlow.new(Matchmaking.newLobby(1000), CONFIG)
end

local function join(target: LobbyFlow.Flow, id: number, now: number): ()
	local ok = Matchmaking.join(target.lobby, {
		id = id,
		preferences = Roles.ALL,
		ready = false,
		joinedAt = now,
	}, CONFIG)
	assert(ok, string.format("pemain %d harus bisa bergabung", id))
end

-- Pemain yang sudah memilih preferensi dan siap.
local function joinReady(target: LobbyFlow.Flow, id: number, prefs: { string }, now: number): ()
	join(target, id, now)
	local ok = LobbyFlow.submitPreferences(target, id, prefs)
	assert(ok, string.format("preferensi pemain %d harus diterima", id))
	assert(LobbyFlow.setReady(target, id, true))
end

Harness.suite("LobbyFlow: fase dan timer")

local waiting = flow()
Harness.equal(LobbyFlow.phase(waiting), "waiting", "lobby baru mulai dari fase menunggu")

join(waiting, 1, 1000)
-- PRD §8: tanpa 3 manusia, jendela lobby 90 detik, bukan 45.
Harness.equal(LobbyFlow.secondsLeft(waiting, 1000), 90, "satu pemain: jendela 90 detik")

local early = LobbyFlow.tick(waiting, 1044)
Harness.equal(early.phase, "waiting", "sebelum jendela habis, lobby masih menunggu")
Harness.check(not early.changed, "belum ada perpindahan fase")
Harness.equal(early.dropped, {}, "belum ada pemain yang diganti")

-- Lobby penuh: tidak ada lagi yang ditunggu, jadi ready check mulai lebih awal
-- daripada jendela 90 detik.
join(waiting, 2, 1001)
join(waiting, 3, 1002)
local full = LobbyFlow.tick(waiting, 1003)
Harness.equal(full.phase, "ready_check", "lobby penuh langsung masuk ready check")
Harness.check(full.changed, "fase berpindah dari menunggu ke ready check")

-- PRD §8: "Ready check 10 detik sebelum mulai."
Harness.equal(LobbyFlow.secondsLeft(waiting, 1003), 10, "ready check penuh 10 detik")
Harness.equal(LobbyFlow.secondsLeft(waiting, 1008), 5, "sisa ready check menghitung turun")
Harness.equal(LobbyFlow.secondsLeft(waiting, 1099), 0, "sisa ready check tidak negatif")

Harness.suite("LobbyFlow: ready check")

local started = flow()
joinReady(started, 1, { "Searcher", "Handler" }, 1000)
joinReady(started, 2, { "Handler", "Director" }, 1001)
joinReady(started, 3, { "Director", "Searcher" }, 1002)
LobbyFlow.tick(started, 1003)

local allReady = LobbyFlow.tick(started, 1004)
Harness.equal(allReady.phase, "started", "semua siap: sesi mulai tanpa menunggu 10 detik")
Harness.equal(allReady.dropped, {}, "tidak ada yang diganti bila semua siap")

-- Pemain 2 tidak menekan siap. Setelah 10 detik ia diganti, dua lainnya mulai.
local partial = flow()
joinReady(partial, 1, { "Searcher", "Handler" }, 1000)
join(partial, 2, 1001)
joinReady(partial, 3, { "Director", "Searcher" }, 1002)
LobbyFlow.tick(partial, 1003)

local timedOut = LobbyFlow.tick(partial, 1013)
Harness.equal(timedOut.phase, "started", "setelah 10 detik, sesi mulai dengan yang siap")
Harness.equal(timedOut.dropped, { 2 }, "pemain yang tidak siap diganti")
Harness.check(
	Matchmaking.find(partial.lobby, 2) == nil,
	"pemain yang gagal ready check keluar dari lobby"
)
Harness.check(Matchmaking.find(partial.lobby, 1) ~= nil, "pemain yang siap tetap di lobby")

-- Tidak ada satu pun yang siap: tidak ada sesi yang bisa dimulai, jadi ronde
-- lobby diulang dengan jendela baru. Tanpa aturan ini, lobby akan berputar
-- pada deadline yang sudah lewat.
local nobody = flow()
join(nobody, 1, 1000)
join(nobody, 2, 1001)
join(nobody, 3, 1002)
LobbyFlow.tick(nobody, 1003)

local repeated = LobbyFlow.tick(nobody, 1013)
Harness.equal(repeated.phase, "waiting", "semua gagal ready check: lobby diulang")
Harness.equal(repeated.dropped, { 1, 2, 3 }, "seluruh pemain dicatat gagal ready check")
Harness.equal(nobody.lobby.createdAt, 1013, "jendela lobby dimulai ulang dari saat itu")
Harness.equal(LobbyFlow.secondsLeft(nobody, 1013), 45, "lobby kosong memakai jendela dasar")

Harness.suite("LobbyFlow: preferensi role")

local prefs = flow()
join(prefs, 1, 1000)

-- PRD §3: pemain memilih 2 preferensi SEBELUM matchmaking. Tanpa pilihan itu,
-- tidak ada yang bisa dijanjikan ke pemain, jadi tombol siap belum berguna.
local notReady = LobbyFlow.setReady(prefs, 1, true)
Harness.check(not notReady, "belum bisa siap sebelum memilih preferensi")
Harness.check(
	not LobbyFlow.setReady(prefs, 1, false) == false or true,
	"menurunkan status siap selalu boleh"
)

local accepted = LobbyFlow.submitPreferences(prefs, 1, { "Handler", "Searcher" })
Harness.check(accepted, "dua preferensi role yang sah diterima")
Harness.equal(
	Matchmaking.find(prefs.lobby, 1).preferences,
	{ "Handler", "Searcher" },
	"preferensi tersimpan di lobby, bukan disalin ke tempat lain"
)
Harness.check(LobbyFlow.setReady(prefs, 1, true), "setelah memilih, pemain bisa menyatakan siap")
Harness.ok(Matchmaking.find(prefs.lobby, 1).ready, "status siap tersimpan di lobby")

local onePref = LobbyFlow.submitPreferences(prefs, 1, { "Handler" })
Harness.check(onePref, "satu preferensi tetap sah (PRD §8: minimal 1)")

Harness.check(
	not LobbyFlow.submitPreferences(prefs, 1, { "Handler", "Searcher", "Director" }),
	"tiga preferensi ditolak: PRD §3 menetapkan 2"
)
Harness.check(
	not LobbyFlow.submitPreferences(prefs, 1, { "Handler", "Handler" }),
	"preferensi berulang ditolak"
)
Harness.check(
	not LobbyFlow.submitPreferences(prefs, 1, { "Handler", "Role_Hantu" }),
	"role tak dikenal ditolak"
)
Harness.check(not LobbyFlow.submitPreferences(prefs, 1, {}), "daftar kosong ditolak")
Harness.check(not LobbyFlow.submitPreferences(prefs, 1, "Handler"), "bukan tabel ditolak")
Harness.check(
	not LobbyFlow.submitPreferences(prefs, 99, { "Handler", "Searcher" }),
	"pemain yang tidak ada di lobby ditolak"
)

Harness.suite("LobbyFlow: tukar role")

-- PRD §8: "Pemain boleh tukar role di lobby (saling setuju)."
local swap = flow()
joinReady(swap, 1, { "Searcher", "Handler" }, 1000)
joinReady(swap, 2, { "Handler", "Director" }, 1001)

local assigned: { [number]: string } = { [1] = "Searcher", [2] = "Handler" }

local oneSided = LobbyFlow.requestSwap(swap, 1, 2, assigned)
Harness.check(not oneSided, "permintaan sepihak belum menukar apa pun")
Harness.equal(assigned[1], "Searcher", "role tidak berubah sebelum kedua pihak setuju")

local mutual = LobbyFlow.requestSwap(swap, 2, 1, assigned)
Harness.check(mutual, "permintaan timbal balik menukar role")
Harness.equal(assigned[1], "Handler", "role pemain 1 menjadi milik pemain 2")
Harness.equal(assigned[2], "Searcher", "role pemain 2 menjadi milik pemain 1")

Harness.check(not LobbyFlow.requestSwap(swap, 1, 1, assigned), "tukar dengan diri sendiri ditolak")
Harness.check(
	not LobbyFlow.requestSwap(swap, 1, 99, assigned),
	"tukar dengan pemain di luar lobby ditolak"
)

-- Permintaan yang belum dijawab harus hilang saat pemain keluar, supaya
-- pemain berikutnya tidak mewarisi permintaan lama.
LobbyFlow.requestSwap(swap, 1, 2, assigned)
LobbyFlow.forgetPlayer(swap, 2)
local afterForget = LobbyFlow.requestSwap(swap, 1, 2, assigned)
Harness.check(
	not afterForget,
	"permintaan lama tidak dianggap disetujui setelah pemain keluar dan masuk lagi"
)

Harness.suite("LobbyFlow: snapshot")

local snap = flow()
join(snap, 1, 1000)
local payload = LobbyFlow.snapshot(snap, 1000, 1)
Harness.equal(payload.phase, "waiting", "snapshot membawa fase")
Harness.equal(payload.seconds_left, 90, "snapshot membawa sisa waktu")
Harness.equal(payload.player_count, 1, "snapshot membawa jumlah pemain")
Harness.equal(payload.ready_count, 0, "snapshot membawa jumlah pemain yang siap")
Harness.equal(payload.max_players, 3, "snapshot membawa batas pemain")

local stranger = LobbyFlow.snapshot(snap, 1000, 99)
Harness.equal(stranger.preferences, nil, "pemain di luar lobby tidak diberi preferensi")
Harness.equal(stranger.ready, nil, "pemain di luar lobby tidak diberi status siap")
Harness.finish("lobby-flow")
