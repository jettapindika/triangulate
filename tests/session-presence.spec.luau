--!strict
-- Uji kehadiran pemain: AFK dan rejoin (PRD §8, kriteria terima EXTA-58 b dan c).
--
-- Ambangnya tidak ditulis ulang di sini: `Config.AFK_SECONDS` (60) dan
-- `Config.REJOIN_HOLD_SECONDS` (180) dibaca dari modul yang sama yang dipakai
-- server, sehingga mengubah angka di `Config` mengubah uji ini juga.
--
-- Yang dibuktikan berkas ini adalah aturan waktunya. Yang membuktikan bahwa
-- state sesi tidak hilang saat pengambilalihan adalah
-- `tests/lobby-gate-minggu-5.spec.luau`, karena state sesi hidup di sana.

local Harness = require("./harness")
local SessionPresence = require("../src/server/SessionPresence")
local Config = require("../src/shared/Config")

Harness.suite("SessionPresence: input bermakna")

local presence = SessionPresence.new(1000)
Harness.equal(
	SessionPresence.secondsSinceInput(presence, 1, 1030),
	30,
	"pemain yang belum pernah input dihitung dari awal sesi"
)

SessionPresence.touch(presence, 1, 1030)
Harness.equal(SessionPresence.secondsSinceInput(presence, 1, 1030), 0, "input menyetel ulang jam")
Harness.equal(SessionPresence.secondsSinceInput(presence, 1, 1070), 40, "jam berjalan lagi")

Harness.suite("SessionPresence: pengambilalihan AFK")

local roles: { [number]: string } = { [1] = "Searcher", [2] = "Handler" }
SessionPresence.touch(presence, 2, 1030)

-- PRD §8: "AFK 60 detik tanpa input -> NPC mengambil alih role itu."
local before = SessionPresence.takeovers(presence, roles, 1089, Config.AFK_SECONDS)
Harness.equal(before, {}, "di bawah ambang, belum ada pengambilalihan")

local atThreshold = SessionPresence.takeovers(presence, roles, 1090, Config.AFK_SECONDS)
Harness.equal(#atThreshold, 1, "tepat pada ambang 60 detik, NPC mengambil alih")
Harness.equal(atThreshold[1].userId, 1, "yang diambil alih adalah pemain yang AFK")
Harness.equal(atThreshold[1].role, "Searcher", "role yang diambil alih ikut dilaporkan")
Harness.equal(atThreshold[1].reason, "afk_60s", "alasan pengambilalihan sesuai skema telemetri")

-- Pemain 2 juga melewati ambang pada tick yang sama dengan pemain 1, tetapi
-- hanya satu pengambilalihan yang dilaporkan per panggilan. Episode pemain 2
-- TIDAK boleh hilang karena itu: panggilan berikutnya melaporkannya, sebab
-- pemain AFK tidak pernah memanggil `touch`.
local repeated = SessionPresence.takeovers(presence, roles, 1200, Config.AFK_SECONDS)
Harness.equal(#repeated, 1, "kandidat kedua dilaporkan pada panggilan berikutnya")
Harness.equal(repeated[1].userId, 2, "pengambilalihan pemain 1 tidak dilaporkan dua kali")
Harness.equal(repeated[1].role, "Handler", "role kandidat kedua ikut dilaporkan")

-- Pemain kembali bermain: kendali role-nya kembali, dan siklus AFK berikutnya
-- bisa dilaporkan lagi.
SessionPresence.touch(presence, 1, 1200)
Harness.equal(
	SessionPresence.takeovers(presence, roles, 1250, Config.AFK_SECONDS),
	{},
	"input baru mengembalikan kendali ke pemain"
)
local again = SessionPresence.takeovers(presence, roles, 1260, Config.AFK_SECONDS)
Harness.equal(#again, 1, "AFK berikutnya dilaporkan lagi")
Harness.equal(again[1].userId, 1, "yang AFK kedua kali tetap pemain yang sama")

Harness.suite("SessionPresence: disconnect dan rejoin")

local drop = SessionPresence.new(2000)
SessionPresence.touch(drop, 7, 2000)
SessionPresence.markDisconnected(drop, 7, "Director", 2000)

-- PRD §8: "Disconnect -> slot ditahan 3 menit untuk rejoin, NPC mengisi
-- sementara." Pengambilalihan saat disconnect tidak menunggu 60 detik.
local onDisconnect = SessionPresence.takeovers(drop, { [7] = "Director" }, 2001, Config.AFK_SECONDS)
Harness.equal(#onDisconnect, 1, "disconnect langsung memicu pengambilalihan")
Harness.equal(onDisconnect[1].reason, "disconnect", "alasannya disconnect, bukan AFK")

Harness.equal(
	SessionPresence.releasedSlots(drop, 2179, Config.REJOIN_HOLD_SECONDS),
	{},
	"sebelum 3 menit, slot masih ditahan"
)

-- Kriteria terima (c): rejoin di dalam 3 menit kembali ke slot yang sama.
local rejoined, role = SessionPresence.rejoin(drop, 7, 2150, Config.REJOIN_HOLD_SECONDS)
Harness.ok(rejoined, "rejoin di dalam 3 menit diterima")
Harness.equal(role, "Director", "rejoin mengembalikan role yang sama, bukan role baru")

local rejoinTwice, _ = SessionPresence.rejoin(drop, 7, 2151, Config.REJOIN_HOLD_SECONDS)
Harness.check(not rejoinTwice, "rejoin kedua ditolak: slot sudah kembali ke pemain")

Harness.suite("SessionPresence: slot kedaluwarsa")

local expired = SessionPresence.new(3000)
SessionPresence.markDisconnected(expired, 5, "Handler", 3000)

Harness.equal(
	#SessionPresence.releasedSlots(expired, 3179, Config.REJOIN_HOLD_SECONDS),
	0,
	"179 detik: slot belum dibuka"
)

local released = SessionPresence.releasedSlots(expired, 3180, Config.REJOIN_HOLD_SECONDS)
Harness.equal(#released, 1, "tepat 180 detik, slot dibuka")
Harness.equal(released[1].userId, 5, "slot yang dibuka milik pemain yang disconnect")
Harness.equal(released[1].role, "Handler", "role yang dibuka ikut dilaporkan")

Harness.equal(
	SessionPresence.releasedSlots(expired, 3181, Config.REJOIN_HOLD_SECONDS),
	{},
	"slot yang sudah dibuka tidak dilaporkan dua kali"
)

local tooLate, lateRole = SessionPresence.rejoin(expired, 5, 3181, Config.REJOIN_HOLD_SECONDS)
Harness.check(not tooLate, "rejoin setelah slot dibuka ditolak")
Harness.equal(lateRole, nil, "tidak ada role yang dikembalikan")

local unknown, unknownRole = SessionPresence.rejoin(expired, 99, 3181, Config.REJOIN_HOLD_SECONDS)
Harness.check(not unknown, "pemain yang tidak pernah disconnect tidak bisa rejoin")
Harness.equal(unknownRole, nil, "tidak ada role untuk pemain yang tidak disconnect")

-- PRD §8: "Setelah 3 menit slot dibuka untuk pemain pengganti (join-in-progress)
-- atau tetap NPC." Slot yang SUDAH diisi NPC sementara tetap dibuka; kalau
-- syaratnya dibaca sebagai "belum diambil alih", role itu dipegang NPC
-- selamanya dan tidak ada pemain pengganti yang bisa masuk.
local filled = SessionPresence.new(4000)
SessionPresence.markDisconnected(filled, 8, "Searcher", 4000)
local takeover = SessionPresence.takeovers(filled, { [8] = "Searcher" }, 4001, Config.AFK_SECONDS)
Harness.equal(#takeover, 1, "disconnect memicu pengambilalihan sebelum slot dibuka")

local releasedAfterTakeover = SessionPresence.releasedSlots(
	filled,
	4000 + Config.REJOIN_HOLD_SECONDS,
	Config.REJOIN_HOLD_SECONDS
)
Harness.equal(
	#releasedAfterTakeover,
	1,
	"slot yang sudah diambil alih NPC tetap dibuka setelah 3 menit"
)
Harness.equal(releasedAfterTakeover[1].userId, 8, "slot yang dibuka milik pemain yang disconnect")

Harness.finish("session-presence")
