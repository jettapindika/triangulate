--!strict
-- Uji telemetri (PRD §12, §15).
--
-- Yang diuji adalah definisi idle time, karena itulah angka yang dipakai
-- memutuskan lulus/tidaknya gate playtest minggu 7 (PRD §17: "Idle < 25%").

local Harness = require("./harness")
local TelemetryService = require("../src/server/TelemetryService")

local WINDOW = 5

local function inputAt(session: TelemetryService.Session, role: string, t: number): ()
	TelemetryService.record(session, { kind = "input", role = role, t = t, detail = nil })
end

Harness.suite("TelemetryService: jendela keaktifan")

local single = TelemetryService.newSession(0, WINDOW)
inputAt(single, "Searcher", 0)
Harness.equal(
	TelemetryService.activeSeconds(single, "Searcher", 10),
	5,
	"satu input menutup satu jendela penuh"
)

-- Dua input dalam satu jendela dihitung satu blok, bukan dua: yang diukur
-- adalah rentang waktu aktif, bukan jumlah tombol yang ditekan.
local overlapping = TelemetryService.newSession(0, WINDOW)
inputAt(overlapping, "Searcher", 0)
inputAt(overlapping, "Searcher", 3)
Harness.equal(
	TelemetryService.activeSeconds(overlapping, "Searcher", 10),
	8,
	"jendela yang tumpang tindih digabung"
)

-- Dua input berjauhan dihitung dua blok.
local apart = TelemetryService.newSession(0, WINDOW)
inputAt(apart, "Searcher", 0)
inputAt(apart, "Searcher", 20)
Harness.equal(
	TelemetryService.activeSeconds(apart, "Searcher", 30),
	10,
	"jendela yang terpisah tidak digabung"
)

Harness.suite("TelemetryService: idle fraction")

Harness.near(
	TelemetryService.idleFraction(overlapping, "Searcher", 10),
	0.2,
	"8 detik aktif dari 10 detik sesi"
)

Harness.near(
	TelemetryService.idleFraction(apart, "Searcher", 30),
	10 / 30 * 2,
	"10 detik aktif dari 30 detik sesi"
)

-- Tanpa input sama sekali, seluruh sesi idle.
local silent = TelemetryService.newSession(0, WINDOW)
Harness.equal(
	TelemetryService.activeSeconds(silent, "Searcher", 10),
	0,
	"tanpa input tidak ada waktu aktif"
)
Harness.near(
	TelemetryService.idleFraction(silent, "Searcher", 10),
	1,
	"tanpa input, seluruh sesi idle"
)

-- Keaktifan tidak pernah melebihi durasi sesi: jendela dipotong di `untilT`.
local longWindow = TelemetryService.newSession(0, 100)
inputAt(longWindow, "Searcher", 0)
Harness.near(
	TelemetryService.idleFraction(longWindow, "Searcher", 10),
	0,
	"jendela panjang tidak membuat idle negatif"
)

-- Durasi nol atau negatif tidak menghasilkan pembagian nol.
Harness.near(TelemetryService.idleFraction(single, "Searcher", 0), 0, "durasi nol menghasilkan 0")

Harness.suite("TelemetryService: pemisahan per role")

-- PRD §12 membandingkan idle time ANTAR role, jadi keaktifan satu role tidak
-- boleh terhitung untuk role lain.
local mixed = TelemetryService.newSession(0, WINDOW)
inputAt(mixed, "Searcher", 0)
Harness.equal(
	TelemetryService.activeSeconds(mixed, "Handler", 10),
	0,
	"input Searcher tidak dihitung untuk Handler"
)
Harness.near(
	TelemetryService.idleFraction(mixed, "Handler", 10),
	1,
	"Handler yang diam sepenuhnya idle"
)

Harness.suite("TelemetryService: waktu ke clue pertama")

local clues = TelemetryService.newSession(0, WINDOW)
TelemetryService.record(clues, { kind = "clue", role = "Searcher", t = 7, detail = nil })
TelemetryService.record(clues, { kind = "clue", role = "Searcher", t = 12, detail = nil })
Harness.equal(
	TelemetryService.secondsToFirstClue(clues, "Searcher"),
	7,
	"clue pertama, bukan yang terakhir"
)
Harness.equal(
	TelemetryService.secondsToFirstClue(clues, "Handler"),
	nil,
	"role tanpa clue mengembalikan nil"
)

Harness.suite("TelemetryService: ringkasan")

local summarySession = TelemetryService.newSession(0, WINDOW)
inputAt(summarySession, "Searcher", 0)
inputAt(summarySession, "Searcher", 6)
TelemetryService.record(summarySession, { kind = "clue", role = "Searcher", t = 4, detail = nil })
TelemetryService.record(
	summarySession,
	{ kind = "accusation", role = "Director", t = 20, detail = "2" }
)

local summary = TelemetryService.summary(summarySession, { "Searcher", "Handler", "Director" }, 30)
Harness.equal(summary.duration, 30, "ringkasan memuat durasi sesi")
Harness.equal(summary.roles.Searcher.inputs, 2, "ringkasan menghitung input per role")
Harness.equal(
	summary.roles.Searcher.seconds_to_first_clue,
	4,
	"ringkasan memuat waktu ke clue pertama"
)
Harness.equal(summary.roles.Director.accusations, 1, "ringkasan menghitung tuduhan per role")
Harness.equal(summary.roles.Handler.inputs, 0, "role tanpa aktivitas tetap muncul")
Harness.finish("telemetry")
