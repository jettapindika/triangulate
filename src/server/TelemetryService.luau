--!strict
-- Telemetri (PRD §12, §15).
--
-- PRD §15: "Telemetri: event per role (idle time, waktu ke clue pertama,
-- tuduhan, quit point) sejak build pertama." PRD §12 memasang target pada
-- angka-angka ini (idle time per role < 25% sesi, penyelesaian > 55%).
--
-- Modul ini murni: hanya mencatat waktu dan menghitung, tidak mengirim ke mana
-- pun. Pengiriman (DataStore/AnalyticsService) adalah seam EXTA-34.
--
-- DEFINISI IDLE. Modul ini mengikuti `docs/metrics/kamus-metrik.md` §1.3 apa
-- adanya -- bukan definisi sendiri. Sebelum EXTA-60 di sini dipakai definisi
-- lain ("pemain aktif pada detik t bila ada input dalam 5 detik terakhir",
-- jendela digabung bila tumpang tindih) dan angka yang dihasilkan berbeda dari
-- angka yang dipakai gate PRD §17. Definisi yang berlaku hanya satu, dan itu
-- milik EXTA-36:
--
--   1. bucket 1 detik selaras dengan `case_started.t_server_ms`;
--   2. bucket ACTIVE <=> ada >= 1 input bermakna di dalamnya;
--   3. run maksimal bucket INACTIVE yang berurutan;
--   4. run dengan durasi >= `IDLE_THRESHOLD_S` menjadi satu idle run;
--   5. `idle_time_role_ms` = jumlah durasi seluruh idle run di jendela;
--   6. `idle_ratio` = idle_time_role_ms / player_active_duration_ms.
--
-- Jendela idle adalah `[case_started.t, min(player_left.t, session_end.t)]`.
-- Penyebutnya berbeda dari jendela: `max(role_assigned.t, case_started.t)`
-- sebagai batas bawah (§1.3 langkah 6). Karena itu `case_started` wajib
-- diketahui; tanpa itu modul ini mengembalikan "tidak bisa dihitung", bukan 0.

-- WAKTU. `kamus-metrik.md` §0.2: "semua perhitungan memakai `t_server_ms`",
-- dan titik nolnya `case_started.t_server_ms`. Jadi `Event.t` dan seluruh
-- parameter waktu di modul ini dalam MILIDETIK. Field yang satuannya detik
-- dinamai `seconds_*` dan hanya itu yang dikonversi.

local TelemetryService = {}

export type EventKind = "input" | "clue" | "deduction" | "accusation" | "quit"

export type Event = {
	kind: EventKind,
	role: string,
	-- `t_server_ms`.
	t: number,
	detail: string?,
}

export type Session = {
	events: { Event },
	-- `t_server_ms` saat sesi dibuat. Titik nol cadangan bila `caseStartedAt`
	-- belum ada; BUKAN pengganti `case_started` (§1.3).
	startedAt: number,
	-- kamus-metrik.md §1.3: titik nol jendela idle, `t_server_ms`. `nil` selama
	-- kasus belum mulai -- di scaffold MVP ini kasus mulai bersamaan dengan sesi
	-- dibuat, tetapi lobby dan ready check (PRD §8, minggu 5) memisahkan
	-- keduanya.
	caseStartedAt: number?,
}

-- Jendela perhitungan satu role. Field opsional sengaja eksplisit: `player_left`
-- dan `role_assigned` belum tentu ada (pemain bisa selesai tanpa keluar lebih
-- dulu), dan ketiadaannya mengubah arti batas jendela, bukan hanya angkanya.
export type Window = {
	role: string,
	sessionEndT: number,
	roleAssignedAt: number?,
	playerLeftAt: number?,
	thresholdS: number?,
}

export type IdleRun = {
	startT: number,
	endT: number,
	durationMs: number,
	-- kamus-metrik.md skema `idle_end`: enum
	-- `input | npc_takeover | player_left | session_end | paused`.
	endedBy: string,
}

export type IdleEvent = {
	event_name: string,
	role: string,
	t: number,
	idle_threshold_ms: number?,
	idle_duration_ms: number?,
	ended_by: string?,
	t_since_case_start_ms: number,
}

-- kamus-metrik.md §1.3: BUCKET_MS = 1000.
local BUCKET_MS = 1000

-- kamus-metrik.md §1.3: IDLE_THRESHOLD_S = 5, ditandai ASUMSI di sana dan
-- dinaikkan/diturunkan lewat §1.4 (laporan pada 3/5/10 detik) dan keputusan E7
-- (pemilik: CTO/CIO). Angka ini konstanta PENGUKURAN, bukan gameplay, jadi
-- tempatnya di sini -- bukan di `shared/Config.luau` yang memuat angka gameplay.
TelemetryService.DEFAULT_IDLE_THRESHOLD_S = 5

-- Ambang yang wajib dilaporkan §1.4.
TelemetryService.REPORTED_THRESHOLDS_S = { 3, 5, 10 }

function TelemetryService.newSession(startedAt: number, caseStartedAt: number?): Session
	return {
		events = {},
		startedAt = startedAt,
		caseStartedAt = caseStartedAt,
	}
end

-- Menandai `case_started.t`. Idempoten terhadap nilai yang sama; panggilan
-- kedua dengan nilai berbeda adalah bug pemanggil, bukan sesuatu yang ditelan
-- diam-diam.
function TelemetryService.markCaseStarted(session: Session, t: number): ()
	session.caseStartedAt = t
end

function TelemetryService.record(session: Session, event: Event): ()
	table.insert(session.events, event)
end

local function timestamps(session: Session, role: string, kind: EventKind): { number }
	local out: { number } = {}
	for _, event in session.events do
		if event.role == role and event.kind == kind then
			table.insert(out, event.t)
		end
	end
	table.sort(out)
	return out
end

-- Jendela idle §1.3: `[case_started.t, min(player_left.t, session_end.t)]`.
local function idleWindow(session: Session, window: Window): (number?, number)
	local caseStartedAt = session.caseStartedAt
	if caseStartedAt == nil then
		return nil, 0
	end
	local to = math.min(window.sessionEndT, window.playerLeftAt or window.sessionEndT)
	return caseStartedAt, to
end

-- Penyebut §1.3 langkah 6: `min(player_left.t, session_end.t)
-- - max(role_assigned.t, case_started.t)`.
local function activeDurationMs(session: Session, window: Window): number
	local caseStartedAt, to = idleWindow(session, window)
	if caseStartedAt == nil then
		return 0
	end
	local from = math.max(caseStartedAt, window.roleAssignedAt or caseStartedAt)
	return to - from
end

-- kamus-metrik.md §1.3 langkah 1-4: bucket 1 detik, run maksimal INACTIVE,
-- run >= ambang menjadi satu idle run.
function TelemetryService.idleRuns(session: Session, window: Window): { IdleRun }
	local runs: { IdleRun } = {}
	local caseStartedAt, to = idleWindow(session, window)
	if caseStartedAt == nil or to <= caseStartedAt then
		return runs
	end

	local thresholdS = window.thresholdS or TelemetryService.DEFAULT_IDLE_THRESHOLD_S
	local thresholdMs = thresholdS * 1000

	-- Jendela bucket menutup `[caseStartedAt, to)`; input tepat di `to` tidak
	-- mengakhiri run yang mencapai ujung jendela -- yang berlaku untuk run itu
	-- adalah `session_end`/`player_left` (§1.3 langkah 4).
	local times = timestamps(session, window.role, "input")
	local bucketCount = math.ceil((to - caseStartedAt) / BUCKET_MS)
	local active = table.create(bucketCount, false)
	for _, t in times do
		if t >= caseStartedAt and t < to then
			active[math.floor((t - caseStartedAt) / BUCKET_MS) + 1] = true
		end
	end

	-- `times` terurut dan batas run naik monoton, jadi satu penunjuk cukup:
	-- tidak ada input yang dilewati atau dihitung dua kali.
	local pointer = 1
	local index = 1
	while index <= bucketCount do
		if active[index] then
			index += 1
			continue
		end

		local runStart = index
		while index <= bucketCount and not active[index] do
			index += 1
		end
		local runEnd = index - 1

		local startT = caseStartedAt + (runStart - 1) * BUCKET_MS
		local boundary = caseStartedAt + runEnd * BUCKET_MS
		while pointer <= #times and times[pointer] < boundary do
			pointer += 1
		end
		local firstInput: number? = if pointer <= #times then times[pointer] else nil

		local endT: number
		local endedBy: string
		if firstInput ~= nil then
			endT = firstInput
			endedBy = "input"
		else
			endT = to
			endedBy = if window.playerLeftAt ~= nil
					and window.playerLeftAt < window.sessionEndT
				then "player_left"
				else "session_end"
		end

		local durationMs = endT - startT
		if durationMs >= thresholdMs then
			table.insert(runs, {
				startT = startT,
				endT = endT,
				durationMs = durationMs,
				endedBy = endedBy,
			})
		end
	end

	return runs
end

-- kamus-metrik.md §1.3 langkah 5.
function TelemetryService.idleTimeMs(session: Session, window: Window): number
	local total = 0
	for _, run in TelemetryService.idleRuns(session, window) do
		total += run.durationMs
	end
	return total
end

-- kamus-metrik.md §1.3 langkah 6 dan §1.5: `idle_ratio` adalah metrik gate
-- (PRD §6 "25% sesi"). `idle_ratio_adj` adalah diagnostik dan TIDAK boleh
-- dipakai untuk klaim gate. `nil` = tidak bisa dihitung, bukan 0.
function TelemetryService.idleRatio(session: Session, window: Window): number?
	local denominator = activeDurationMs(session, window)
	if denominator <= 0 then
		return nil
	end
	return TelemetryService.idleTimeMs(session, window) / denominator
end

-- kamus-metrik.md §1.4: laporkan `idle_ratio` pada ambang 3, 5, dan 10 detik.
-- Bila urutan role berubah antar ambang, gate belum layak dipakai memutuskan.
function TelemetryService.idleRatioByThreshold(
	session: Session,
	window: Window
): { [number]: number? }
	local out: { [number]: number? } = {}
	for _, thresholdS in TelemetryService.REPORTED_THRESHOLDS_S do
		out[thresholdS] = TelemetryService.idleRatio(session, {
			role = window.role,
			sessionEndT = window.sessionEndT,
			roleAssignedAt = window.roleAssignedAt,
			playerLeftAt = window.playerLeftAt,
			thresholdS = thresholdS,
		})
	end
	return out
end

-- kamus-metrik.md §1.3 langkah 4 dan skema `idle_start`/`idle_end`: pasangan
-- event yang membuat M-06 bisa dipanen dari ekspor telemetri. `idle_start`
-- membawa `t_since_case_start_ms` bucket INACTIVE pertama -- bukan waktu kirim,
-- karena ambang baru terlewati beberapa detik setelah run dimulai.
function TelemetryService.idleEvents(session: Session, window: Window): { IdleEvent }
	local caseStartedAt = session.caseStartedAt
	if caseStartedAt == nil then
		return {}
	end

	local thresholdS = window.thresholdS or TelemetryService.DEFAULT_IDLE_THRESHOLD_S
	local thresholdMs = thresholdS * 1000
	local out: { IdleEvent } = {}
	for _, run in TelemetryService.idleRuns(session, window) do
		table.insert(out, {
			event_name = "idle_start",
			role = window.role,
			t = run.startT,
			idle_threshold_ms = thresholdMs,
			idle_duration_ms = nil,
			ended_by = nil,
			t_since_case_start_ms = run.startT - caseStartedAt,
		})
		table.insert(out, {
			event_name = "idle_end",
			role = window.role,
			t = run.endT,
			idle_threshold_ms = nil,
			idle_duration_ms = run.durationMs,
			ended_by = run.endedBy,
			t_since_case_start_ms = run.endT - caseStartedAt,
		})
	end
	return out
end

-- PRD §12: "waktu ke clue pertama" per role. Diukur dari `case_started`
-- (kamus-metrik.md §0.2), bukan dari awal sesi, dan hasilnya DETIK -- bukan
-- milidetik seperti sisa modul ini (§0.2: "durasi dalam detik (1 desimal)").
-- `nil` bila belum ada clue.
function TelemetryService.secondsToFirstClue(session: Session, role: string): number?
	local times = timestamps(session, role, "clue")
	if #times == 0 then
		return nil
	end
	return (times[1] - (session.caseStartedAt or session.startedAt)) / 1000
end

-- Ringkasan untuk Case Recap (PRD §11) dan untuk perbandingan antar role
-- (PRD §12). `duration` juga diukur dari `case_started`.
function TelemetryService.summary(
	session: Session,
	roles: { string },
	sessionEndT: number,
	roleAssignedAt: number?
): { [string]: any }
	local byRole: { [string]: any } = {}
	for _, role in roles do
		local window: Window = {
			role = role,
			sessionEndT = sessionEndT,
			roleAssignedAt = roleAssignedAt,
			playerLeftAt = nil,
			thresholdS = nil,
		}
		local runs = TelemetryService.idleRuns(session, window)
		byRole[role] = {
			idle_ratio = TelemetryService.idleRatio(session, window),
			idle_time_ms = TelemetryService.idleTimeMs(session, window),
			idle_runs = #runs,
			idle_ratio_by_threshold = TelemetryService.idleRatioByThreshold(session, window),
			seconds_to_first_clue = TelemetryService.secondsToFirstClue(session, role),
			inputs = #timestamps(session, role, "input"),
			accusations = #timestamps(session, role, "accusation"),
		}
	end
	return {
		-- Milidetik, sesuai §0.2 ("semua perhitungan memakai `t_server_ms`").
		-- Pembulatan ke detik 1 desimal terjadi sekali saat output laporan.
		duration = sessionEndT - (session.caseStartedAt or session.startedAt),
		roles = byRole,
	}
end

return TelemetryService
