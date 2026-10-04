--!strict
-- Reducer idle time sesuai `docs/metrics/kamus-metrik.md` §1.3 (EXTA-36).
--
-- Menghitung ulang `idle_time_role_ms` dan `idle_ratio` per role dari aliran
-- input bermakna, lalu membandingkannya dengan tabel §4. §4 menyebut angka itu
-- "hasil yang **wajib** diperoleh pembaca kedua dari fixture yang sama" -- jadi
-- skrip ini adalah pembaca kedua, dan baris `GAGAL` di bawah berarti definisi di
-- kode yang menyimpang, bukan angkanya.
--
-- Jalankan dari akar checkout repo:
--   $HOME/.local/roboxtools/lune.d/lune run tools/idle-reduce.luau
--   $HOME/.local/roboxtools/lune.d/lune run tools/idle-reduce.luau <berkas-input.json>
--
-- Bentuk berkas input (lihat `docs/metrics/fixtures/sesi-contoh-inputs.json`):
--   { "case_started_t_server_ms": n, "session_end_t_server_ms": n,
--     "players": { "<id>": { "role": "searcher", "t_server_ms": [n, ...] } } }
--
-- Yang TIDAK dilakukan skrip ini dan dinyatakan apa adanya: penyaringan kelas
-- aksi §1.1. Skrip menerima daftar `t_server_ms` yang SUDAH tersaring sebagai
-- input bermakna. Delapan kelas §1.1 (`MOVE`, `INTERACT`, `TABLE`, `BOARD`,
-- `UI_NAV`, `COMM`, `CONFIRM`, `CAM_WITH_ACTION`) belum ada sebagai kolom di
-- skema event mana pun -- lihat `docs/playtest/minggu-7/README.md` butir celah
-- C-2 -- sehingga reducer atas lalu lintas sungguhan belum bisa memfilter
-- sendiri. Skrip ini mengukur matematika §1.3-nya, bukan §1.1-nya.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local TelemetryService = require("../src/server/TelemetryService")

local DEFAULT_INPUT = "docs/metrics/fixtures/sesi-contoh-inputs.json"

-- Tabel §4 untuk fixture bawaan. Bila berkas lain yang diberikan, baris
-- pembanding dilewati -- bukan dilemahkan.
local EXPECTED = {
	["docs/metrics/fixtures/sesi-contoh-inputs.json"] = {
		duration_ms = 540000,
		roles = {
			searcher = { idle_ms = 75000, runs = 3, percent = 13.9 },
			handler = { idle_ms = 80000, runs = 2, percent = 14.8 },
			director = { idle_ms = 120000, runs = 2, percent = 22.2 },
		},
	},
}

local path = process.args[1] or DEFAULT_INPUT
local inputs = serde.decode("json", fs.readFile(path))

local caseStart: number = inputs.case_started_t_server_ms
local sessionEnd: number = inputs.session_end_t_server_ms
local duration = sessionEnd - caseStart

if caseStart == nil or sessionEnd == nil or inputs.players == nil then
	error(
		"berkas input tidak lengkap: butuh case_started_t_server_ms, session_end_t_server_ms, players"
	)
end

print(string.format("=== idle reduce §1.3: %s ===", path))
print(
	string.format(
		"case_started = %d, session_end = %d, durasi kasus = %.1f detik",
		caseStart,
		sessionEnd,
		duration / 1000
	)
)
print("")

local failures = 0
local function check(label: string, actual: number, expected: number, tolerance: number?): ()
	local toleranceMs = tolerance or 0
	local ok = math.abs(actual - expected) <= toleranceMs
	if not ok then
		failures += 1
	end
	print(
		string.format(
			"  %-46s %14.1f   harap %14.1f   %s",
			label,
			actual,
			expected,
			if ok then "LULUS" else "GAGAL"
		)
	)
end

print(
	string.format(
		"%-10s %14s %14s %8s %8s %8s %8s",
		"role",
		"idle_ms",
		"aktif_ms",
		"run",
		"3 dtk",
		"5 dtk",
		"10 dtk"
	)
)

local byRole: { [string]: { idleMs: number, activeMs: number, runs: number, ratios: { number } } } =
	{}
for _, player in inputs.players do
	local role: string = player.role
	local session = TelemetryService.newSession(caseStart, caseStart)
	for _, t in player.t_server_ms do
		TelemetryService.record(session, { kind = "input", role = role, t = t, detail = nil })
	end

	local ratios: { number } = {}
	local idleMs = 0
	local runs = 0
	local activeMs = 0
	for _, thresholdS in TelemetryService.REPORTED_THRESHOLDS_S do
		local window: TelemetryService.Window = {
			role = role,
			sessionEndT = sessionEnd,
			roleAssignedAt = caseStart,
			playerLeftAt = nil,
			thresholdS = thresholdS,
		}
		local ratio = TelemetryService.idleRatio(session, window)
		table.insert(ratios, (ratio or 0) * 100)
		if thresholdS == TelemetryService.DEFAULT_IDLE_THRESHOLD_S then
			idleMs = TelemetryService.idleTimeMs(session, window)
			runs = #TelemetryService.idleRuns(session, window)
			activeMs = duration
		end
	end

	byRole[role] = { idleMs = idleMs, activeMs = activeMs, runs = runs, ratios = ratios }
end

for _, role in { "searcher", "handler", "director" } do
	local row = byRole[role]
	if row ~= nil then
		print(
			string.format(
				"%-10s %14d %14d %8d %7.1f%% %7.1f%% %7.1f%%",
				role,
				row.idleMs,
				row.activeMs,
				row.runs,
				row.ratios[1],
				row.ratios[2],
				row.ratios[3]
			)
		)
	end
end

-- §1.4: "Bila peringkat role berubah antar ambang, gate minggu 7 belum layak
-- dipakai sebagai keputusan." Diperiksa, bukan diasumsikan.
local orders: { number: { string } } = {}
for index = 1, 3 do
	local roles: { string } = {}
	for role in byRole do
		table.insert(roles, role)
	end
	table.sort(roles, function(a, b)
		return byRole[a].ratios[index] < byRole[b].ratios[index]
	end)
	orders[index] = roles
end
local stable = orders[1][1] == orders[2][1]
	and orders[2][1] == orders[3][1]
	and orders[1][2] == orders[2][2]
	and orders[2][2] == orders[3][2]
print("")
print(
	string.format(
		"§1.4 peringkat role stabil pada ambang 3/5/10 detik: %s (%s)",
		if stable then "ya" else "TIDAK",
		table.concat(orders[2], " < ")
	)
)
if not stable then
	failures += 1
end

local expected = EXPECTED[path]
if expected ~= nil then
	print("")
	print("=== perbandingan dengan kamus-metrik.md §4 ===")
	check("durasi kasus (ms)", duration, expected.duration_ms)
	for role, want in expected.roles do
		local row = byRole[role]
		check(string.format("%s idle_time_role_ms", role), row.idleMs, want.idle_ms)
		check(string.format("%s jumlah idle run", role), row.runs, want.runs)
		check(string.format("%s idle_ratio (%%)", role), row.ratios[2], want.percent, 0.05)
	end
else
	print("")
	print(
		string.format(
			"§4 tidak punya tabel pembanding untuk %s; hanya angka mentah di atas yang dilaporkan.",
			path
		)
	)
end

print("")
if failures == 0 then
	print("SELURUH ANGKA §4 COCOK")
else
	print(
		string.format(
			"%d baris GAGAL -- definisi di kode menyimpang dari kamus-metrik.md",
			failures
		)
	)
end
