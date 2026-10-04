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
-- Definisi idle time yang dipakai: seorang pemain dianggap AKTIF pada detik t
-- bila ia menghasilkan input bermakna dalam `activityWindow` detik terakhir.
-- Idle fraction = 1 - (total waktu aktif / durasi sesi). Definisi ini dipilih
-- karena bisa dihitung dari daftar timestamp saja dan tidak bergantung pada
-- cara input masuk.

local TelemetryService = {}

export type EventKind = "input" | "clue" | "deduction" | "accusation" | "quit"

export type Event = {
	kind: EventKind,
	role: string,
	t: number,
	detail: string?,
}

export type Session = {
	events: { Event },
	startedAt: number,
	-- Jendela keaktifan, dalam detik.
	activityWindow: number,
	-- PRD §10: "Seed server memilih cabang saat sesi dibuat."
	--
	-- SOP-02 langkah 12: varian yang dipilih WAJIB terekam di telemetri, karena
	-- tanpa itu perbandingan "varian mana yang lebih sering buntu" tidak bisa
	-- dihitung dari data sesi. Nilainya hanya hidup di server -- ia tidak
	-- pernah masuk `Net.CLIENT_VIEWS` mana pun, karena id varian memberi tahu
	-- client cabang mana yang sedang berjalan.
	variant: string?,
}

function TelemetryService.newSession(
	startedAt: number,
	activityWindow: number?,
	variant: string?
): Session
	return {
		events = {},
		startedAt = startedAt,
		activityWindow = activityWindow or 5,
		variant = variant,
	}
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

-- Total waktu aktif seorang pemain, dengan menggabungkan jendela keaktifan yang
-- tumpang tindih. Satu pemain yang menekan tombol dua kali dalam satu jendela
-- dihitung satu blok, bukan dua.
function TelemetryService.activeSeconds(session: Session, role: string, untilT: number): number
	local times = timestamps(session, role, "input")
	if #times == 0 then
		return 0
	end

	local total = 0
	local blockStart = times[1]
	local blockEnd = math.min(times[1] + session.activityWindow, untilT)

	for index = 2, #times do
		local t = times[index]
		if t <= blockEnd then
			-- Tumpang tindih atau bersambung: perpanjang blok.
			blockEnd = math.min(math.max(blockEnd, t + session.activityWindow), untilT)
		else
			total += blockEnd - blockStart
			blockStart = t
			blockEnd = math.min(t + session.activityWindow, untilT)
		end
	end

	total += blockEnd - blockStart
	return total
end

-- PRD §6: pada playtest, idle time tiap role harus di bawah 25% sesi.
function TelemetryService.idleFraction(session: Session, role: string, untilT: number): number
	local duration = untilT - session.startedAt
	if duration <= 0 then
		return 0
	end
	local active = TelemetryService.activeSeconds(session, role, untilT)
	local fraction = 1 - (active / duration)
	if fraction < 0 then
		return 0
	end
	if fraction > 1 then
		return 1
	end
	return fraction
end

-- PRD §12: "waktu ke clue pertama" per role. `nil` bila belum ada.
function TelemetryService.secondsToFirstClue(session: Session, role: string): number?
	local times = timestamps(session, role, "clue")
	if #times == 0 then
		return nil
	end
	return times[1] - session.startedAt
end

-- Ringkasan untuk Case Recap (PRD §11) dan untuk perbandingan antar role.
function TelemetryService.summary(
	session: Session,
	roles: { string },
	untilT: number
): { [string]: any }
	local byRole: { [string]: any } = {}
	for _, role in roles do
		byRole[role] = {
			idle_fraction = TelemetryService.idleFraction(session, role, untilT),
			seconds_to_first_clue = TelemetryService.secondsToFirstClue(session, role),
			inputs = #timestamps(session, role, "input"),
			accusations = #timestamps(session, role, "accusation"),
			-- `deduction` sudah ada di `EventKind` sejak awal tetapi belum
			-- pernah dihitung; sekarang deduksi yang sah dicatat server, jadi
			-- angkanya nyata. Tanpa ini, satu-satunya jejak deduksi adalah
			-- pesan remote yang tidak pernah disimpan.
			deductions = #timestamps(session, role, "deduction"),
		}
	end
	return {
		duration = untilT - session.startedAt,
		-- SOP-02 langkah 12: varian ikut di ringkasan supaya rekaman sesi bisa
		-- dipisah per cabang tanpa tabel lain.
		variant = session.variant,
		roles = byRole,
	}
end

return TelemetryService
