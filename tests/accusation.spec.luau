--!strict
-- Uji alur tuduhan (PRD §5).
--
-- Sifat yang paling penting di sini: server tidak pernah mengembalikan FIELD
-- mana yang benar. Uji menegakkannya secara struktural -- hasilnya hanya berisi
-- angka, dan tidak ada nilai dari `solution` yang boleh muncul di hasil.

local Harness = require("./harness")
local AccusationService = require("../src/server/AccusationService")

local FIELDS = { "culprit", "motive", "method" }
local SOLUTION = { culprit = "curator", motive = "debt", method = "swapped_painting" }

local function newSession()
	return AccusationService.newSession(SOLUTION, FIELDS, 3)
end

local function containsSolutionValue(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for _, field in FIELDS do
		for _, candidate in value :: { [any]: any } do
			if candidate == SOLUTION[field] then
				return true
			end
		end
	end
	return false
end

Harness.suite("AccusationService: feedback tidak membocorkan field")

local session = newSession()
local partial = AccusationService.submit(session, {
	culprit = "curator",
	motive = "greed",
	method = "forged_log",
})

Harness.equal(partial.correctCount, 1, "satu field benar dilaporkan sebagai angka")
Harness.equal(partial.attemptsLeft, 2, "percobaan berkurang satu")
Harness.check(not containsSolutionValue(partial), "hasil tidak memuat nilai solusi")

Harness.suite("AccusationService: batas percobaan")

local attempts = newSession()
local wrong = { culprit = "guard", motive = "greed", method = "forged_log" }

local first = AccusationService.submit(attempts, wrong)
Harness.check(not first.resolved, "percobaan pertama yang salah belum menutup kasus")

local second = AccusationService.submit(attempts, wrong)
Harness.check(not second.resolved, "percobaan kedua yang salah belum menutup kasus")

local third = AccusationService.submit(attempts, wrong)
Harness.ok(third.resolved, "percobaan ketiga yang salah menutup kasus")
Harness.check(not third.won, "kasus yang habis percobaan bukan kemenangan")
Harness.equal(third.attemptsLeft, 0, "tidak ada percobaan tersisa")

local fourth = AccusationService.submit(attempts, wrong)
Harness.check(not fourth.accepted, "tuduhan setelah kasus ditutup ditolak")

Harness.suite("AccusationService: konfirmasi dua role")

local winning = newSession()
local exact = AccusationService.submit(winning, {
	culprit = "curator",
	motive = "debt",
	method = "swapped_painting",
})

Harness.equal(exact.correctCount, 3, "tiga field benar dilaporkan")
Harness.check(not exact.resolved, "tuduhan benar belum selesai sebelum dikonfirmasi")
Harness.ok(exact.pendingConfirmation, "tuduhan benar menunggu konfirmasi")
Harness.check(not exact.won, "belum menang sebelum konfirmasi")

-- PRD §5: konfirmasi harus datang dari role selain Director.
local directorConfirm, directorProblem = AccusationService.confirm(winning, "Director", "Director")
Harness.check(not directorConfirm, "Director tidak bisa mengonfirmasi tuduhannya sendiri")
Harness.check(directorProblem ~= nil, "penolakan menyertakan alasan")

local searcherConfirm = AccusationService.confirm(winning, "Searcher", "Director")
Harness.ok(searcherConfirm, "role lain bisa mengonfirmasi")
Harness.ok(winning.won, "kasus dimenangkan setelah konfirmasi")
Harness.ok(winning.resolved, "kasus selesai setelah konfirmasi")

Harness.suite("AccusationService: validasi masukan")

local function rejects(accusation: { [string]: any }, message: string)
	local s = newSession()
	local ok, reason = AccusationService.validate(s, accusation)
	Harness.check(not ok, message)
	Harness.check(reason ~= nil, message .. " (dengan alasan)")
end

rejects({ culprit = "curator", motive = "debt" }, "field yang belum diisi ditolak")
rejects(
	{ culprit = "curator", motive = "debt", method = "x", extra = "y" },
	"field tak dikenal ditolak"
)
rejects({ culprit = "curator", motive = "", method = "x" }, "nilai kosong ditolak")
rejects({ culprit = 1, motive = "debt", method = "x" }, "nilai bukan string ditolak")

local validSession = newSession()
local validOk = AccusationService.validate(validSession, {
	culprit = "curator",
	motive = "debt",
	method = "swapped_painting",
})
Harness.ok(validOk, "tuduhan lengkap dan sah diterima")

Harness.suite("AccusationService: rank")

Harness.equal(AccusationService.rank(100, 1, 0, 900), "S", "cepat, sekali coba, tanpa hint -> S")
Harness.equal(AccusationService.rank(100, 1, 1, 900), "A", "sekali coba dengan hint -> A")
Harness.equal(AccusationService.rank(100, 2, 0, 900), "B", "dua percobaan -> B")
Harness.equal(AccusationService.rank(100, 3, 0, 900), "C", "tiga percobaan -> C")

return nil
