--!strict
-- Uji telemetri (PRD §12, §15).
--
-- Yang diuji adalah definisi idle time, karena itulah angka yang dipakai
-- memutuskan lulus/tidaknya gate playtest minggu 7 (PRD §17: "Idle < 25%").
-- Definisi yang berlaku ada di `docs/metrics/kamus-metrik.md` §1.3 (EXTA-36),
-- dan bagian akhir berkas ini mereproduksi angka §4 dari fixture yang sama:
-- "Angka di bawah adalah hasil yang wajib diperoleh pembaca kedua dari fixture
-- yang sama." Bila angka itu tidak cocok, definisi di kode yang salah -- bukan
-- angkanya.
--
-- Dua detail §1.3 yang mudah salah dibaca, dan karena itu diuji eksplisit:
--
--   * `idle_start.t` adalah `t_server_ms` bucket INACTIVE PERTAMA. Input
--     bermakna sendiri menempati satu bucket, jadi run yang memisahkan input di
--     detik 0 dan detik 6 berdurasi 5 detik -- bukan 6.
--   * Run yang mencapai ambang dihitung SELURUHNYA, bukan hanya bagian setelah
--     ambang (jarak 11 detik -> 10 detik idle, bukan 5).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")
local TelemetryService = require("../src/server/TelemetryService")

local CASE_START = 1000000
local SESSION_END = 1540000

local function inputAt(session: TelemetryService.Session, role: string, t: number): ()
	TelemetryService.record(session, { kind = "input", role = role, t = t, detail = nil })
end

-- Jendela uji. `endT` dipendekkan di sebagian uji supaya run ekor -- yang selalu
-- ada bila input terakhir jauh dari ujung jendela -- tidak ikut terhitung.
local function windowFor(
	role: string,
	endT: number?,
	thresholdS: number?,
	roleAssignedAt: number?,
	playerLeftAt: number?
): TelemetryService.Window
	return {
		role = role,
		sessionEndT = endT or SESSION_END,
		roleAssignedAt = roleAssignedAt or CASE_START,
		playerLeftAt = playerLeftAt,
		thresholdS = thresholdS,
	}
end

Harness.suite("TelemetryService §1.3: bucket 1 detik dan ambang run")

-- Input tiap detik sepanjang jendela: tidak ada bucket INACTIVE berurutan, jadi
-- tidak ada idle run sama sekali.
local dense = TelemetryService.newSession(0, CASE_START)
for t = CASE_START, SESSION_END, 1000 do
	inputAt(dense, "Searcher", t)
end
Harness.equal(
	#TelemetryService.idleRuns(dense, windowFor("Searcher")),
	0,
	"input tiap detik tidak menghasilkan idle run"
)

-- Jarak 5 detik antar input -> 4 bucket INACTIVE berurutan, run 4 detik: belum
-- mencapai ambang 5 detik, jadi bukan idle run. Definisi lama sudah menghitung
-- celah ini sebagai waktu tidak aktif; §1.3 tidak.
local under = TelemetryService.newSession(0, CASE_START)
inputAt(under, "Searcher", CASE_START)
inputAt(under, "Searcher", CASE_START + 5000)
Harness.equal(
	#TelemetryService.idleRuns(under, windowFor("Searcher", CASE_START + 6000)),
	0,
	"run 4 detik belum mencapai ambang 5 detik"
)

-- Jarak 6 detik -> 5 bucket INACTIVE berurutan -> satu idle run tepat 5 detik.
local exact = TelemetryService.newSession(0, CASE_START)
inputAt(exact, "Searcher", CASE_START)
inputAt(exact, "Searcher", CASE_START + 6000)
local exactRuns = TelemetryService.idleRuns(exact, windowFor("Searcher", CASE_START + 7000))
Harness.equal(#exactRuns, 1, "run 5 detik mencapai ambang")
Harness.equal(exactRuns[1].startT, CASE_START + 1000, "idle_start memakai bucket INACTIVE pertama")
Harness.equal(exactRuns[1].endT, CASE_START + 6000, "idle_end memakai input yang mengakhiri run")
Harness.equal(exactRuns[1].durationMs, 5000, "durasi run = idle_end.t - idle_start.t")

-- §1.3 langkah 4: run yang mencapai ambang dihitung SELURUHNYA.
local longGap = TelemetryService.newSession(0, CASE_START)
inputAt(longGap, "Searcher", CASE_START)
inputAt(longGap, "Searcher", CASE_START + 11000)
local longRuns = TelemetryService.idleRuns(longGap, windowFor("Searcher", CASE_START + 12000))
Harness.equal(#longRuns, 1, "satu celah panjang menjadi satu idle run")
Harness.equal(
	longRuns[1].durationMs,
	10000,
	"seluruh run dihitung, bukan hanya bagian lewat ambang"
)

-- Ambang adalah parameter, dan §1.4 mewajibkan laporan pada 3/5/10 detik.
local sweep = TelemetryService.newSession(0, CASE_START)
inputAt(sweep, "Searcher", CASE_START)
inputAt(sweep, "Searcher", CASE_START + 4000)
Harness.equal(
	#TelemetryService.idleRuns(sweep, windowFor("Searcher", CASE_START + 5000, 3)),
	1,
	"ambang 3 detik menangkap run 3 detik"
)
Harness.equal(
	#TelemetryService.idleRuns(sweep, windowFor("Searcher", CASE_START + 5000, 5)),
	0,
	"ambang 5 detik tidak menangkap run 3 detik"
)

-- Run terakhir yang mencapai ujung jendela berakhir di `session_end`.
local tail = TelemetryService.newSession(0, CASE_START)
inputAt(tail, "Searcher", CASE_START)
local tailRuns = TelemetryService.idleRuns(tail, windowFor("Searcher"))
Harness.equal(#tailRuns, 1, "tanpa input setelahnya, run mencapai ujung jendela")
Harness.equal(tailRuns[1].endT, SESSION_END, "idle_end run terakhir = session_end")
Harness.equal(tailRuns[1].endedBy, "session_end", "ended_by run terakhir = session_end")

-- Tanpa `case_started` tidak ada titik nol, jadi rasio tidak bisa dihitung --
-- dan itu `nil`, bukan 0.
local noCase = TelemetryService.newSession(0)
inputAt(noCase, "Searcher", 1000)
Harness.equal(
	TelemetryService.idleRatio(noCase, windowFor("Searcher")),
	nil,
	"tanpa case_started rasio tidak bisa dihitung"
)

Harness.suite("TelemetryService §1.3: jendela dan penyebut")

-- §1.3 langkah 6: penyebut mulai dari `max(role_assigned, case_started)`. Role
-- diberikan di lobby SEBELUM kasus mulai (PRD §8), jadi `max` memilih
-- `case_started` dan penyebutnya sama dengan durasi kasus.
local early = TelemetryService.newSession(0, CASE_START)
inputAt(early, "Searcher", CASE_START)
Harness.near(
	TelemetryService.idleRatio(early, windowFor("Searcher", nil, 5, CASE_START - 60000)) :: number,
	539000 / 540000,
	"role_assigned sebelum case_started tidak memperbesar penyebut"
)

-- `player_left` memotong jendela: sesudah pemain keluar, sisa sesi bukan idle
-- miliknya, dan penyebutnya ikut terpotong.
local leftSession = TelemetryService.newSession(0, CASE_START)
inputAt(leftSession, "Searcher", CASE_START)
local left = windowFor("Searcher", nil, 5, CASE_START, CASE_START + 100000)
Harness.equal(TelemetryService.idleTimeMs(leftSession, left), 99000, "player_left memotong jendela")
Harness.equal(
	TelemetryService.idleRuns(leftSession, left)[1].endedBy,
	"player_left",
	"ended_by run yang dipotong player_left"
)
Harness.near(
	TelemetryService.idleRatio(leftSession, left) :: number,
	99000 / 100000,
	"penyebut juga dipotong player_left"
)

Harness.suite("TelemetryService §1.3: pemisahan per role")

-- PRD §12 membandingkan idle time ANTAR role, jadi keaktifan satu role tidak
-- boleh terhitung untuk role lain.
local mixed = TelemetryService.newSession(0, CASE_START)
for t = CASE_START, SESSION_END, 1000 do
	inputAt(mixed, "Searcher", t)
end
Harness.equal(
	TelemetryService.idleTimeMs(mixed, windowFor("Handler")),
	SESSION_END - CASE_START,
	"input Searcher tidak mengurangi idle Handler"
)
Harness.near(
	TelemetryService.idleRatio(mixed, windowFor("Handler")),
	1,
	"Handler yang diam penuh idle"
)

-- Tanpa input sama sekali, seluruh jendela idle.
local silent = TelemetryService.newSession(0, CASE_START)
Harness.near(
	TelemetryService.idleRatio(silent, windowFor("Searcher")),
	1,
	"tanpa input, seluruh jendela idle"
)

-- Jendela nol tidak menghasilkan pembagian nol.
Harness.equal(
	TelemetryService.idleRatio(silent, windowFor("Searcher", CASE_START, 5)),
	nil,
	"jendela nol tidak menghasilkan pembagian nol"
)

Harness.suite("TelemetryService: waktu ke clue pertama")

local clues = TelemetryService.newSession(0, CASE_START)
TelemetryService.record(
	clues,
	{ kind = "clue", role = "Searcher", t = CASE_START + 7000, detail = nil }
)
TelemetryService.record(
	clues,
	{ kind = "clue", role = "Searcher", t = CASE_START + 12000, detail = nil }
)
Harness.equal(
	TelemetryService.secondsToFirstClue(clues, "Searcher"),
	7,
	"clue pertama, bukan yang terakhir, diukur dari case_started"
)
Harness.equal(
	TelemetryService.secondsToFirstClue(clues, "Handler"),
	nil,
	"role tanpa clue mengembalikan nil"
)

Harness.suite("TelemetryService: event idle_start/idle_end")

local emitted = TelemetryService.newSession(0, CASE_START)
inputAt(emitted, "Searcher", CASE_START)
inputAt(emitted, "Searcher", CASE_START + 6000)
local events = TelemetryService.idleEvents(emitted, windowFor("Searcher", CASE_START + 7000))
Harness.equal(#events, 2, "satu idle run menghasilkan sepasang event")
Harness.equal(events[1].event_name, "idle_start", "event pertama adalah idle_start")
Harness.equal(
	events[1].t,
	CASE_START + 1000,
	"idle_start dibawa pada bucket INACTIVE pertama, bukan saat ambang terlewati"
)
Harness.equal(events[1].idle_threshold_ms, 5000, "idle_start membawa ambang yang dipakai")
Harness.equal(
	events[1].t_since_case_start_ms,
	1000,
	"t_since_case_start_ms dihitung dari bucket INACTIVE pertama"
)
Harness.equal(events[2].event_name, "idle_end", "event kedua adalah idle_end")
Harness.equal(events[2].idle_duration_ms, 5000, "idle_end membawa durasi run")
Harness.equal(events[2].ended_by, "input", "idle_end membawa penyebab berakhirnya run")
Harness.equal(
	TelemetryService.idleEvents(noCase, windowFor("Searcher")),
	{},
	"tanpa case_started tidak ada event idle"
)

Harness.suite("TelemetryService: ringkasan")

local summarySession = TelemetryService.newSession(0, CASE_START)
inputAt(summarySession, "Searcher", CASE_START)
TelemetryService.record(
	summarySession,
	{ kind = "clue", role = "Searcher", t = CASE_START + 4000, detail = nil }
)
TelemetryService.record(
	summarySession,
	{ kind = "accusation", role = "Director", t = CASE_START + 20000, detail = "2" }
)

local summary = TelemetryService.summary(
	summarySession,
	{ "Searcher", "Handler", "Director" },
	SESSION_END,
	CASE_START
)
Harness.equal(summary.duration, SESSION_END - CASE_START, "ringkasan memuat durasi jendela")
Harness.equal(summary.roles.Searcher.inputs, 1, "ringkasan menghitung input per role")
Harness.equal(
	summary.roles.Searcher.seconds_to_first_clue,
	4,
	"ringkasan memuat waktu ke clue pertama"
)
Harness.equal(summary.roles.Director.accusations, 1, "ringkasan menghitung tuduhan per role")
Harness.equal(summary.roles.Handler.inputs, 0, "role tanpa aktivitas tetap muncul")
Harness.ok(summary.roles.Searcher.idle_time_ms > 0, "ringkasan memuat idle time per role")
Harness.equal(
	summary.roles.Searcher.idle_ratio_by_threshold[3],
	summary.roles.Searcher.idle_ratio_by_threshold[5],
	"ringkasan memuat rasio pada tiap ambang §1.4"
)

-- ---------------------------------------------------------------------------
-- Reproduksi kamus-metrik.md §4 dari fixture yang sama
-- ---------------------------------------------------------------------------
--
-- §4: "Angka di bawah adalah hasil yang wajib diperoleh pembaca kedua dari
-- fixture yang sama." Fixture berisi aliran input 1 Hz per pemain, dan seluruh
-- angka §4 diturunkan darinya lewat §1.3 -- jadi kode inilah pembaca keduanya.

Harness.suite("kamus-metrik.md §4: reproduksi dari fixture")

local inputs = serde.decode("json", fs.readFile("docs/metrics/fixtures/sesi-contoh-inputs.json"))
local fixtureStart: number = inputs.case_started_t_server_ms
local fixtureEnd: number = inputs.session_end_t_server_ms
local fixtureDuration = fixtureEnd - fixtureStart

Harness.equal(fixtureDuration, 540000, "fixture: durasi kasus 540 detik")

local expectedIdleMs = { p1 = 75000, p2 = 80000, p3 = 120000 }
local expectedRuns = { p1 = 3, p2 = 2, p3 = 2 }

local fixtureSessions: { [string]: TelemetryService.Session } = {}
for playerId, player in inputs.players do
	local session = TelemetryService.newSession(fixtureStart, fixtureStart)
	for _, t in player.t_server_ms do
		inputAt(session, player.role, t)
	end
	fixtureSessions[playerId] = session
end

for playerId, expectedMs in expectedIdleMs do
	local role: string = inputs.players[playerId].role
	local window = windowFor(role, fixtureEnd, 5, fixtureStart)
	local session = fixtureSessions[playerId]
	Harness.equal(
		TelemetryService.idleTimeMs(session, window),
		expectedMs,
		string.format("§4 M-06 %s: idle_time_role_ms = %d", playerId, expectedMs)
	)
	Harness.equal(
		#TelemetryService.idleRuns(session, window),
		expectedRuns[playerId],
		string.format("§4 M-06 %s: jumlah idle run", playerId)
	)
	local ratio = TelemetryService.idleRatio(session, window)
	Harness.ok(ratio ~= nil, string.format("§4 M-06 %s: rasio bisa dihitung", playerId))
	Harness.near(
		(ratio :: number) * 100,
		expectedMs / fixtureDuration * 100,
		string.format("§4 M-06 %s: idle_ratio", playerId),
		1e-6
	)
	Harness.check(
		(ratio :: number) < 0.25,
		string.format("§4 gate: %s di bawah ambang 25%%", role)
	)
end

-- §1.4: urutan role harus stabil antar ambang 3/5/10 detik. Bila tidak stabil,
-- gate belum layak dipakai memutuskan.
local ranking: { number: { string } } = {}
for _, thresholdS in TelemetryService.REPORTED_THRESHOLDS_S do
	local rows: { { role: string, ratio: number } } = {}
	for playerId in expectedIdleMs do
		local role: string = inputs.players[playerId].role
		local ratio = TelemetryService.idleRatio(
			fixtureSessions[playerId],
			windowFor(role, fixtureEnd, thresholdS, fixtureStart)
		)
		table.insert(rows, { role = role, ratio = ratio :: number })
	end
	table.sort(rows, function(a, b)
		return a.ratio < b.ratio
	end)
	local order: { string } = {}
	for _, row in rows do
		table.insert(order, row.role)
	end
	ranking[thresholdS] = order
end
Harness.equal(ranking[3], ranking[5], "§1.4: urutan role sama pada ambang 3 dan 5 detik")
Harness.equal(ranking[5], ranking[10], "§1.4: urutan role sama pada ambang 5 dan 10 detik")

-- §4 M-11 (waktu ke clue pertama) dan M-04 (tunggu lobby) dari fixture event
-- yang sama: `first_clue` per role dan `lobby_enter` -> `case_started`.
local eventsText = fs.readFile("docs/metrics/fixtures/sesi-contoh.jsonl")
local fixtureEvents = {}
for line in string.gmatch(eventsText, "[^\n]+") do
	table.insert(fixtureEvents, serde.decode("json", line))
end

local clueSession = TelemetryService.newSession(fixtureStart, fixtureStart)
for _, event in fixtureEvents do
	if event.event_name == "first_clue" then
		TelemetryService.record(clueSession, {
			kind = "clue",
			role = string.lower(event.role),
			t = event.t_server_ms,
			detail = nil,
		})
	end
end
Harness.equal(
	TelemetryService.secondsToFirstClue(clueSession, "searcher"),
	95,
	"§4 M-11 searcher: 95 detik ke clue pertama"
)
Harness.equal(
	TelemetryService.secondsToFirstClue(clueSession, "handler"),
	120,
	"§4 M-11 handler: 120 detik ke clue pertama"
)
Harness.equal(
	TelemetryService.secondsToFirstClue(clueSession, "director"),
	150,
	"§4 M-11 director: 150 detik ke clue pertama"
)

local lobbyEnter: number? = nil
local caseStarted: number? = nil
for _, event in fixtureEvents do
	if event.event_name == "lobby_enter" and lobbyEnter == nil then
		lobbyEnter = event.t_server_ms
	elseif event.event_name == "case_started" then
		caseStarted = event.t_server_ms
	end
end
Harness.equal(
	(caseStarted :: number) - (lobbyEnter :: number),
	42000,
	"§4 M-04: tunggu matchmaking 42 detik"
)

Harness.finish("telemetry")
