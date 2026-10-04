--!strict
-- Laporan gate playtest minggu 7 dari ekspor telemetri mentah (PRD §17).
--
-- Membaca berkas JSONL berisi event sesuai `docs/metrics/skema-event-telemetri.md`
-- dan mencetak tabel gate PRD §17: idle per role (ambang 3/5/10 detik),
-- persentase sesi yang menamatkan kasus, quit 5 menit pertama per role, hint
-- per sesi, dan median waktu tunggu matchmaking. Definisi setiap metrik diambil
-- dari `docs/metrics/kamus-metrik.md` -- skrip ini TIDAK mendefinisikan ulang
-- apa pun, dan TIDAK mengarang angka.
--
-- Jalankan dari akar checkout repo:
--   $HOME/.local/roboxtools/lune.d/lune run tools/playtest-report.luau
--   $HOME/.local/roboxtools/lune.d/lune run tools/playtest-report.luau <ekspor.jsonl>
--
-- Metrik yang sumbernya belum ada di ekspor dicetak `TIDAK ADA DATA` beserta
-- penghalangnya (butir §6 kamus-metrik), BUKAN 0. Metrik kosong yang tidak
-- dijelaskan terbaca sebagai nol (§0.5).
--
-- Batas yang dinyatakan apa adanya: ekspor ini hanya memuat event yang benar
-- benar dikirim server. Sepanjang `case_started`/`case_completed`/`lobby_enter`/
-- `player_left`/`hint_used` belum dipancarkan server (lihat butir celah C-1 di
-- `docs/playtest/minggu-7/README.md`), laporan ini akan mencetak `TIDAK ADA DATA`
-- untuk hampir semua baris -- dan itu jawaban yang benar, bukan kesalahan skrip.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local DEFAULT_EXPORT = "docs/metrics/fixtures/sesi-contoh.jsonl"
local METRICS_JSON = "docs/metrics.json"

local ROLES = { "searcher", "handler", "director" }
local QUIT_WINDOW_MS = 300000
local NO_DATA = "TIDAK ADA DATA"

local path = process.args[1] or DEFAULT_EXPORT
if not fs.isFile(path) then
	print(string.format("ekspor tidak ditemukan: %s", path))
	print("Jalankan dengan berkas ekspor telemetri; lihat docs/playtest/minggu-7/README.md.")
	process.exit(1)
end

-- Target dibaca dari `docs/metrics.json`, mengikuti `tools/metric-report.py`.
-- Sengaja TIDAK ada angka cadangan di kode: target yang disalin ke sini akan
-- menyimpang dari PRD tanpa ada yang tahu, dan laporan akan menyatakan LULUS
-- terhadap ambang yang sudah tidak berlaku.
type Target = { value: number?, low: number?, high: number?, direction: string, text: string }

local function loadTargets(): { [string]: Target }
	if not fs.isFile(METRICS_JSON) then
		print(string.format("berkas metrik tidak ditemukan: %s", METRICS_JSON))
		process.exit(1)
	end
	local spec = serde.decode("json", fs.readFile(METRICS_JSON))
	local out: { [string]: Target } = {}
	for _, entry in spec.metrics do
		local direction = entry.direction
		if direction == "band" then
			if entry.target_low == nil or entry.target_high == nil then
				print(
					string.format(
						"%s: %s berarah band tanpa target_low/target_high",
						METRICS_JSON,
						entry.id
					)
				)
				process.exit(1)
			end
			out[entry.id] = {
				low = entry.target_low,
				high = entry.target_high,
				direction = direction,
				text = entry.target_text or "",
			}
		elseif direction == "gte" or direction == "lte" then
			if entry.target == nil then
				print(
					string.format(
						"%s: %s berarah %s tanpa 'target'",
						METRICS_JSON,
						entry.id,
						direction
					)
				)
				process.exit(1)
			end
			out[entry.id] =
				{ value = entry.target, direction = direction, text = entry.target_text or "" }
		elseif direction == "track" then
			out[entry.id] = { direction = direction, text = entry.target_text or "" }
		else
			print(
				string.format(
					"%s: %s punya direction tidak dikenal: %s",
					METRICS_JSON,
					entry.id,
					tostring(direction)
				)
			)
			process.exit(1)
		end
	end
	return out
end

local targets = loadTargets()

-- Verdict dari arah pembanding di `docs/metrics.json`; `nil` bila metrik
-- berarah `track` (dipantau, tanpa ambang) atau bila nilainya belum ada.
local function verdict(metricId: string, value: number?): boolean?
	if value == nil then
		return nil
	end
	local spec = targets[metricId]
	if spec == nil or spec.direction == "track" then
		return nil
	end
	if spec.direction == "gte" then
		return value >= (spec.value :: number)
	elseif spec.direction == "lte" then
		return value <= (spec.value :: number)
	end
	return value >= (spec.low :: number) and value <= (spec.high :: number)
end

local function label(metricId: string): string
	local spec = targets[metricId]
	if spec == nil or spec.text == "" then
		return ""
	end
	return spec.text
end

local events = {}
for line in string.gmatch(fs.readFile(path), "[^\n]+") do
	local ok, decoded = pcall(serde.decode, "json", line)
	if ok and type(decoded) == "table" and decoded.event_name ~= nil then
		table.insert(events, decoded)
	end
end

-- ---------------------------------------------------------------------------
-- Agregasi ke unit analisis §0.1 sebelum membagi apa pun.
-- ---------------------------------------------------------------------------

type SessionAgg = {
	caseStartedAt: number?,
	completedOutcome: string?,
	endReason: string?,
	sessionEndAt: number?,
	hintCount: number,
	lobbyEnterAt: number?,
	idleMsByRole: { [string]: number },
	roleAssignedAt: { [string]: number },
	playerLeftAt: { [string]: number },
	players: { [string]: boolean },
}

local sessions: { [string]: SessionAgg } = {}
local function sessionOf(sessionId: string): SessionAgg
	local existing = sessions[sessionId]
	if existing == nil then
		existing = {
			caseStartedAt = nil,
			completedOutcome = nil,
			endReason = nil,
			sessionEndAt = nil,
			hintCount = 0,
			lobbyEnterAt = nil,
			idleMsByRole = {},
			roleAssignedAt = {},
			playerLeftAt = {},
			players = {},
		}
		sessions[sessionId] = existing
	end
	return existing
end

-- Pasangan idle_start -> idle_end per (sesi, role). Kunci HARUS memuat role:
-- `idle_start` Searcher dan `idle_end` Director bisa berselang-seling pada
-- urutan event, dan kunci per sesi saja akan menutup run yang salah lalu
-- melaporkan idle yang hilang. Run yang tidak pernah ditutup (sesi terpotong)
-- TIDAK dihitung -- §1.3 mendefinisikan durasi run lewat `idle_end.t` -- dan
-- jumlahnya dilaporkan terpisah supaya angka yang hilang tidak terbaca nol.
local openIdle: { [string]: { sessionId: string, role: string } } = {}
local danglingIdle = 0

for _, event in events do
	local sessionId = event.session_id
	if type(sessionId) ~= "string" then
		continue
	end
	local agg = sessionOf(sessionId)
	local name = event.event_name
	local role = if type(event.role) == "string" then string.lower(event.role) else "none"

	if event.player_id ~= nil then
		agg.players[tostring(event.player_id)] = true
	end

	if name == "lobby_enter" then
		if agg.lobbyEnterAt == nil then
			agg.lobbyEnterAt = event.t_server_ms
		end
	elseif name == "role_assigned" and role ~= "none" then
		agg.roleAssignedAt[role] = event.t_server_ms
	elseif name == "case_started" then
		agg.caseStartedAt = event.t_server_ms
	elseif name == "case_completed" then
		agg.completedOutcome = event.outcome
	elseif name == "session_end" then
		agg.endReason = event.end_reason
		-- §1.3 langkah 6 memakai `min(player_left.t, session_end.t)`. Event
		-- `session_end` dipancarkan per pemain, jadi yang dipakai adalah yang
		-- paling awal.
		local t = event.t_server_ms
		if type(t) == "number" and (agg.sessionEndAt == nil or t < agg.sessionEndAt) then
			agg.sessionEndAt = t
		end
	elseif name == "hint_used" then
		agg.hintCount += 1
	elseif name == "player_left" and role ~= "none" then
		agg.playerLeftAt[role] = event.t_server_ms
	elseif name == "idle_start" then
		openIdle[sessionId .. ":" .. role] = { sessionId = sessionId, role = role }
	elseif name == "idle_end" then
		local key = sessionId .. ":" .. role
		local open = openIdle[key]
		if open == nil then
			danglingIdle += 1
		else
			local durationMs = event.idle_duration_ms
			if type(durationMs) == "number" then
				agg.idleMsByRole[role] = (agg.idleMsByRole[role] or 0) + durationMs
			end
			openIdle[key] = nil
		end
	end
end
for _ in openIdle do
	danglingIdle += 1
end

-- ---------------------------------------------------------------------------
-- Metrik
-- ---------------------------------------------------------------------------

local function median(values: { number }): number?
	if #values == 0 then
		return nil
	end
	table.sort(values)
	local middle = math.floor((#values + 1) / 2)
	if #values % 2 == 1 then
		return values[middle]
	end
	return (values[middle] + values[middle + 1]) / 2
end

-- M-03: % sesi yang menamatkan kasus. Sesi `end_reason = error` keluar dari
-- denominator (§0.3), tetapi tetap dihitung terpisah.
local startedSessions, wonSessions, errorSessions = 0, 0, 0
for _, agg in sessions do
	if agg.caseStartedAt ~= nil then
		if agg.endReason == "error" then
			errorSessions += 1
		else
			startedSessions += 1
			if agg.completedOutcome == "win" then
				wonSessions += 1
			end
		end
	end
end

-- M-06: idle per role. `player_active_duration_ms` = min(player_left, session_end)
-- - max(role_assigned, case_started) (§1.3 langkah 6). Idle time hanya dihitung
-- untuk sesi yang punya kedua ujungnya.
local idleNumerator: { [string]: number } = {}
local idleDenominator: { [string]: number } = {}
for _, agg in sessions do
	if agg.caseStartedAt == nil then
		continue
	end
	local caseStart = agg.caseStartedAt
	for _, role in ROLES do
		local idleMs = agg.idleMsByRole[role]
		if idleMs == nil then
			continue
		end
		local assignedAt = agg.roleAssignedAt[role] or caseStart
		local from = math.max(caseStart, assignedAt)
		local to = math.min(agg.playerLeftAt[role] or math.huge, agg.sessionEndAt or math.huge)
		if to == math.huge then
			-- Tanpa `player_left` maupun `session_end`, ujung jendela tidak
			-- diketahui. Angka idle lalu tidak punya penyebut dan dilewati --
			-- bukan diisi dengan asumsi.
			continue
		end
		if to > from then
			idleNumerator[role] = (idleNumerator[role] or 0) + idleMs
			idleDenominator[role] = (idleDenominator[role] or 0) + (to - from)
		end
	end
end

-- M-08: quit 5 menit pertama per role.
local quitByRole: { [string]: number } = {}
local quitDenominator: { [string]: number } = {}
for _, agg in sessions do
	if agg.caseStartedAt == nil or agg.endReason == "error" then
		continue
	end
	for _, role in ROLES do
		if agg.roleAssignedAt[role] == nil then
			continue
		end
		quitDenominator[role] = (quitDenominator[role] or 0) + 1
		local leftAt = agg.playerLeftAt[role]
		if
			leftAt ~= nil
			and agg.completedOutcome == nil
			and leftAt - agg.caseStartedAt < QUIT_WINDOW_MS
		then
			quitByRole[role] = (quitByRole[role] or 0) + 1
		end
	end
end

-- M-04: median waktu tunggu lobby, per pemain per sesi.
local waits: { number } = {}
for _, agg in sessions do
	if agg.lobbyEnterAt ~= nil and agg.caseStartedAt ~= nil then
		table.insert(waits, agg.caseStartedAt - agg.lobbyEnterAt)
	end
end
local medianWait = median(waits)

-- M-09: hint per sesi.
local hintSessions, hintTotal = 0, 0
for _, agg in sessions do
	if agg.caseStartedAt ~= nil and agg.endReason ~= "error" then
		hintSessions += 1
		hintTotal += agg.hintCount
	end
end

-- ---------------------------------------------------------------------------
-- Keluaran
-- ---------------------------------------------------------------------------

local sessionCount = 0
for _ in sessions do
	sessionCount += 1
end

local function verdictText(ok: boolean?): string
	if ok == nil then
		return ""
	end
	return if ok then "   LULUS" else "   GAGAL"
end

print(string.format("=== laporan gate PRD §17 minggu 7: %s ===", path))
print(string.format("event terbaca = %d, sesi = %d", #events, sessionCount))
print("")

print(
	string.format(
		"--- M-03 persentase sesi menamatkan kasus (target %s) ---",
		label("session_completion")
	)
)
if startedSessions == 0 then
	print(
		string.format(
			"  %s (butir §6 G2: `case_started`/`case_completed` belum dipancarkan)",
			NO_DATA
		)
	)
else
	local ratio = wonSessions / startedSessions
	print(
		string.format(
			"  %d menang / %d sesi dimulai = %.1f%%%s",
			wonSessions,
			startedSessions,
			ratio * 100,
			verdictText(verdict("session_completion", ratio))
		)
	)
	print(string.format("  sesi end_reason=error (di luar denominator §0.3): %d", errorSessions))
end

print("")
print(string.format("--- M-06 idle time per role (target %s) ---", label("idle_time_per_role")))
print(
	string.format(
		"  %-10s %12s %14s %10s   %s",
		"role",
		"idle_ms",
		"aktif_ms",
		"idle_ratio",
		"ambang §1.4"
	)
)
for _, role in ROLES do
	local numerator = idleNumerator[role]
	local denominator = idleDenominator[role]
	if numerator == nil or denominator == nil or denominator <= 0 then
		print(string.format("  %-10s %12s %14s %10s", role, NO_DATA, NO_DATA, NO_DATA))
	else
		local ratio = numerator / denominator
		print(
			string.format(
				"  %-10s %12d %14d %9.1f%%%s",
				role,
				numerator,
				denominator,
				ratio * 100,
				verdictText(verdict("idle_time_per_role", ratio))
			)
		)
	end
end
print(
	"  catatan: ekspor membawa `idle_end.idle_duration_ms` pada satu ambang; "
		.. "sensitivitas 3/5/10 detik dihitung oleh tools/idle-reduce.luau dari aliran input."
)
if danglingIdle > 0 then
	print(string.format("  idle_start tanpa idle_end (tidak dihitung): %d", danglingIdle))
end

print("")
print(
	string.format(
		"--- M-08 quit di 5 menit pertama per role (%s) ---",
		label("quit_first_5min_per_role")
	)
)
for _, role in ROLES do
	local denominator = quitDenominator[role]
	if denominator == nil or denominator == 0 then
		print(
			string.format(
				"  %-10s %s (butir §6 G4: `player_left` belum dipancarkan)",
				role,
				NO_DATA
			)
		)
	else
		print(
			string.format(
				"  %-10s %d dari %d role-instance = %.1f%%",
				role,
				quitByRole[role] or 0,
				denominator,
				(quitByRole[role] or 0) / denominator * 100
			)
		)
	end
end

print("")
print(string.format("--- M-09 hint per sesi (target %s) ---", label("hint_per_session")))
if hintSessions == 0 then
	print(string.format("  %s (butir §6 G2)", NO_DATA))
else
	local perSession = hintTotal / hintSessions
	print(
		string.format(
			"  %d hint / %d sesi = %.2f%s",
			hintTotal,
			hintSessions,
			perSession,
			verdictText(verdict("hint_per_session", perSession))
		)
	)
end

print("")
print(
	string.format(
		"--- M-04 median waktu tunggu matchmaking (target %s) ---",
		label("matchmaking_wait_median")
	)
)
if medianWait == nil then
	print(string.format("  %s (butir §6 G3: `lobby_enter` belum dipancarkan)", NO_DATA))
else
	local seconds = medianWait / 1000
	print(
		string.format(
			"  %.1f detik dari %d pemain-lobby%s",
			seconds,
			#waits,
			verdictText(verdict("matchmaking_wait_median", seconds))
		)
	)
end

print("")
print("--- gate PRD §17 minggu 7 ---")
print(
	string.format(
		"  idle %s per role DAN selesai %s.",
		label("idle_time_per_role"),
		label("session_completion")
	)
)
print("  Status gate hanya sah bila M-03 dan M-06 di atas keduanya punya angka.")
