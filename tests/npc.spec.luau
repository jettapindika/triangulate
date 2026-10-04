--!strict
-- Uji perilaku NPC (PRD §8).

local Harness = require("./harness")
local NPCController = require("../src/server/NPCController")
local Roles = require("../src/shared/Roles")

Harness.suite("NPCController: pengambilalihan dan rejoin")

-- PRD §8: "AFK 60 detik tanpa input -> NPC mengambil alih role itu."
Harness.ok(NPCController.shouldTakeOver(60, 60), "tepat pada ambang, NPC mengambil alih")
Harness.check(not NPCController.shouldTakeOver(59, 60), "di bawah ambang, belum diambil alih")
Harness.ok(NPCController.shouldTakeOver(120, 60), "jauh di atas ambang, tetap diambil alih")

-- PRD §8: "Disconnect -> slot ditahan 3 menit untuk rejoin."
Harness.ok(NPCController.shouldReleaseSlot(180, 180), "tepat 3 menit, slot dibuka")
Harness.check(not NPCController.shouldReleaseSlot(179, 180), "sebelum 3 menit, slot masih ditahan")

Harness.suite("NPCController: role yang diisi NPC")

-- PRD §8/§16: NPC Director ada di P1, jadi MVP hanya mengisi Searcher dan
-- Handler. Role Director tidak boleh diam-diam diisi NPC.
local filled = NPCController.rolesToFill({ Searcher = true }, Roles.ALL, Roles.NPC_FILLABLE)
Harness.equal(filled, { "Handler" }, "hanya Handler yang diisi NPC")

local allHumans = NPCController.rolesToFill(
	{ Searcher = true, Handler = true, Director = true },
	Roles.ALL,
	Roles.NPC_FILLABLE
)
Harness.equal(allHumans, {}, "semua role dipegang manusia, tidak ada NPC")

local noHumans = NPCController.rolesToFill({}, Roles.ALL, Roles.NPC_FILLABLE)
Harness.equal(noHumans, { "Searcher", "Handler" }, "Director tidak pernah diisi NPC")

Harness.suite("NPCController: aksi berikutnya")

-- PRD §8: Searcher NPC "berjalan ke objek yang ditandai ping/pinpoint dan melapor".
local search = NPCController.nextAction("Searcher", { pingedObject = "obj_schedule" })
Harness.equal(search.kind, "move_to_object", "Searcher NPC bergerak ke objek yang ditandai")
Harness.equal(search.target, "obj_schedule", "target aksi adalah objek yang ditandai")

local searchIdle = NPCController.nextAction("Searcher", {})
Harness.equal(searchIdle.kind, "idle", "tanpa tanda, Searcher NPC menunggu")

-- PRD §8: Handler NPC "merakit potongan otomatis dengan kecepatan lambat
-- setelah kunci diberikan".
local assemble = NPCController.nextAction("Handler", { unlockedEvidence = "ev_schedule" })
Harness.equal(assemble.kind, "assemble_slowly", "Handler NPC merakit bukti yang terbuka")
Harness.equal(assemble.target, "ev_schedule", "target aksi adalah bukti yang terbuka")

local assembleIdle = NPCController.nextAction("Handler", {})
Harness.equal(assembleIdle.kind, "idle", "tanpa bukti terbuka, Handler NPC menunggu")

-- PRD §8: NPC Director "kesulitan tinggi, jadi prioritaskan manusia" dan
-- ditunda ke P1. Modul ini harus mengatakannya, bukan berpura-pura bisa.
local director = NPCController.nextAction("Director", { pingedObject = "obj_schedule" })
Harness.equal(director.kind, "unsupported", "Director NPC tidak didukung pada MVP")

local unknownRole = NPCController.nextAction("Role_Hantu", {})
Harness.equal(unknownRole.kind, "unsupported", "role tak dikenal tidak diberi aksi")

Harness.suite("NPCController: rank terpisah")

-- PRD §8: "Sesi dengan NPC Director dihitung rank terpisah."
Harness.ok(NPCController.separateRank(true, true), "NPC Director memakai rank terpisah")
Harness.check(not NPCController.separateRank(false, true), "tanpa NPC Director, rank utama")
Harness.check(
	not NPCController.separateRank(true, false),
	"toggle host bisa mematikan rank terpisah"
)

return nil
