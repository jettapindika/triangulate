--!strict
-- Mesin fase lobby: menunggu -> ready check -> mulai (PRD §3, §8, §17 minggu 5).
--
-- Pembagian tanggung jawab yang dipegang berkas ini:
--   * `Matchmaking.luau` -- keanggotaan lobby dan batas waktunya (45/90 detik,
--     ready check 10 detik). Modul itu tidak tahu apa-apa soal fase.
--   * berkas ini -- kapan lobby berpindah fase, siapa yang diganti saat ready
--     check gagal, dan tukar role yang butuh persetujuan dua pihak.
--   * `init.server.luau` -- glue: memasang remote, memanggil `tick` dari loop,
--     dan memulai sesi saat fase mencapai "started".
--
-- Waktu masuk sebagai ARGUMEN (`now`), bukan dibaca dari jam dinding: tidak ada
-- `task.wait` di sini, sehingga alurnya bisa diuji dari CLI dengan waktu
-- virtual (`tests/lobby-flow.spec.luau`, `tests/lobby-gate-minggu-5.spec.luau`).
-- Itu alasan modul ini dipisahkan dari glue.
--
-- Kenapa `Matchmaking` di-`require` alih-alih disalin: aturan 45/90 detik hanya
-- boleh ditulis di satu tempat. Require lintas runtime memakai pola yang sama
-- dengan `shared/case/Compat.luau` -- di Roblox global `script` ada, di harness
-- CLI nil sehingga dipakai require relatif. Ini satu-satunya dependensi modul
-- ini; daftar role masuk sebagai argumen supaya `ReplicatedStorage` tidak perlu
-- disentuh dari sini.

local robloxScript: any = script :: any
local Matchmaking: any = if robloxScript ~= nil
	then require(robloxScript.Matchmaking)
	else require("./Matchmaking")

local LobbyFlow = {}

-- Bentuk data yang sama dengan `Matchmaking`, ditulis ulang di sini karena
-- modul itu di-`require` secara dinamis (`any`), sehingga tipenya tidak bisa
-- dirujuk dari posisi tipe. Struktural, jadi tetap saling bertukar dengan
-- `Matchmaking.Lobby`/`Matchmaking.Config` tanpa konversi.
export type Config = {
	maxPlayers: number,
	lobbySeconds: number,
	extendedSeconds: number,
	readyCheckSeconds: number,
}

export type LobbyPlayer = {
	id: number,
	preferences: { string },
	ready: boolean,
	joinedAt: number,
}

export type Lobby = {
	players: { LobbyPlayer },
	createdAt: number,
}

--[[
	Kebijakan yang dimiliki pemanggil, bukan berkas ini.

	`roles`/`preferenceCount` masuk dari glue sebagai `Roles.ALL` dan
	`Roles.PREFERENCE_COUNT`, sehingga di server yang berjalan hanya ada SATU
	sumber kebenaran untuk daftar role. Nilai default di bawah adalah salinan
	untuk harness CLI -- bandingkan `NPCController.nextAction` dan
	`PuzzleTableService.canPlace` yang juga menulis nama role sebagai literal
	supaya modulnya bisa dijalankan `lune` tanpa runtime Roblox.
]]
export type Options = {
	roles: { string },
	preferenceCount: number,
}

local DEFAULT_OPTIONS: Options = {
	roles = { "Searcher", "Handler", "Director" },
	preferenceCount = 2,
}

export type Phase = "waiting" | "ready_check" | "started"

export type PendingSwap = {
	from: number,
	to: number,
}

export type Flow = {
	lobby: Lobby,
	config: Config,
	options: Options,
	phase: Phase,
	-- Saat tick yang mendeteksi lobby penuh / jendela habis. Ready check
	-- menghitung 10 detik dari SINI, bukan dari `lobby.createdAt`: lobby yang
	-- baru penuh di detik ke-80 tidak boleh langsung kehabisan ready check.
	readyCheckStartedAt: number?,
	pendingSwap: PendingSwap?,
}

export type TickResult = {
	phase: Phase,
	-- Apakah fase berpindah pada tick ini.
	changed: boolean,
	-- Pemain yang diganti karena tidak menekan siap, terurut seperti lobby.
	dropped: { number },
}

export type Snapshot = {
	phase: Phase,
	seconds_left: number,
	player_count: number,
	ready_count: number,
	max_players: number,
	-- Hanya diisi untuk pemain yang ada di lobby.
	preferences: { string }?,
	ready: boolean?,
}

function LobbyFlow.new(lobby: Lobby, config: Config, options: Options?): Flow
	return {
		lobby = lobby,
		config = config,
		options = options or DEFAULT_OPTIONS,
		phase = "waiting",
		readyCheckStartedAt = nil,
		pendingSwap = nil,
	}
end

local function isRole(flow: Flow, value: string): boolean
	for _, role in flow.options.roles do
		if role == value then
			return true
		end
	end
	return false
end

--[[
	Apakah pemain sudah memilih preferensi.

	Lobby `init.server.luau` memasukkan pemain dengan `preferences = Roles.ALL`
	sebagai penanda "belum memilih" (PRD §3: pemain memilih 2 preferensi SEBELUM
	matchmaking). Karena itu yang dihitung bukan "ada isinya" melainkan "sudah
	diganti dengan pilihan sepanjang yang sah".
]]
local function hasChosenPreferences(flow: Flow, player: LobbyPlayer): boolean
	local count = #player.preferences
	return count >= 1 and count <= flow.options.preferenceCount
end

function LobbyFlow.phase(flow: Flow): Phase
	return flow.phase
end

--[[
	Sisa waktu fase sekarang.

	Fase menunggu memakai `Matchmaking.secondsLeft` apa adanya, dengan SATU
	pengecualian: lobby kosong memakai jendela dasar 45 detik. Jendela
	perpanjangan 90 detik ada supaya pemain punya waktu menunggu teman, dan
	tidak ada teman yang ditunggu saat lobby kosong.
]]
function LobbyFlow.secondsLeft(flow: Flow, now: number): number
	if flow.phase == "ready_check" then
		local startedAt = flow.readyCheckStartedAt
		if startedAt == nil then
			return 0
		end
		return math.max(0, startedAt + flow.config.readyCheckSeconds - now)
	end

	if flow.phase == "started" then
		return 0
	end

	if #flow.lobby.players == 0 then
		return math.max(0, flow.lobby.createdAt + flow.config.lobbySeconds - now)
	end

	return Matchmaking.secondsLeft(flow.lobby, now, flow.config)
end

--[[
	Satu langkah fase.

	Fase menunggu berakhir lebih awal saat lobby penuh (PRD §8: "Timer lobby 45
	detik"; tidak ada lagi yang ditunggu), atau saat jendela perpanjangan habis
	dengan setidaknya satu pemain -- role yang kosong diisi NPC.

	Ready check berakhir saat semua siap, atau setelah 10 detik; pemain yang
	belum siap diganti. Bila TIDAK ADA satu pun yang siap, tidak ada sesi yang
	bisa dimulai, jadi ronde lobby diulang dengan jendela baru -- tanpa aturan
	itu lobby akan berputar pada deadline yang sudah lewat.
]]
function LobbyFlow.tick(flow: Flow, now: number): TickResult
	local before = flow.phase
	local dropped: { number } = {}

	if flow.phase == "waiting" then
		local full = #flow.lobby.players >= flow.config.maxPlayers
		local expired = now >= Matchmaking.deadline(flow.lobby, flow.config)
		if full or (expired and #flow.lobby.players > 0) then
			flow.phase = "ready_check"
			flow.readyCheckStartedAt = now
		end
	end

	if flow.phase == "ready_check" then
		local startedAt = flow.readyCheckStartedAt or now
		local failures = Matchmaking.readyFailures(flow.lobby)
		if #failures == 0 then
			flow.phase = "started"
		elseif now - startedAt >= flow.config.readyCheckSeconds then
			for _, playerId in failures do
				Matchmaking.leave(flow.lobby, playerId)
				LobbyFlow.forgetPlayer(flow, playerId)
				table.insert(dropped, playerId)
			end
			if #flow.lobby.players == 0 then
				flow.phase = "waiting"
				flow.lobby.createdAt = now
				flow.readyCheckStartedAt = nil
			else
				flow.phase = "started"
			end
		end
	end

	return { phase = flow.phase, changed = flow.phase ~= before, dropped = dropped }
end

--[[
	Menyimpan preferensi role seorang pemain (PRD §3: 2 preferensi, urutan
	prioritas; PRD §8: minimal 1).

	Ditolak tanpa mengubah apa pun bila pemain tidak ada di lobby, daftarnya
	bukan tabel, panjangnya di luar 1..`preferenceCount`, ada role tak dikenal,
	atau ada role berulang.
]]
function LobbyFlow.submitPreferences(flow: Flow, playerId: number, preferences: any): boolean
	local player = Matchmaking.find(flow.lobby, playerId)
	if player == nil or type(preferences) ~= "table" then
		return false
	end

	local list = preferences :: { any }
	local count = #list
	if count < 1 or count > flow.options.preferenceCount then
		return false
	end

	local seen: { [string]: boolean } = {}
	local accepted: { string } = {}
	for _, value in list do
		if type(value) ~= "string" or not isRole(flow, value) or seen[value] then
			return false
		end
		seen[value] = true
		table.insert(accepted, value)
	end

	player.preferences = accepted
	return true
end

--[[
	Menyatakan siap atau membatalkannya.

	Menurunkan status siap selalu boleh; menaikkannya hanya setelah pemain
	memilih preferensi -- tanpa pilihan itu tidak ada yang bisa dijanjikan ke
	pemain, jadi tombol siap belum berguna.
]]
function LobbyFlow.setReady(flow: Flow, playerId: number, ready: boolean): boolean
	local player = Matchmaking.find(flow.lobby, playerId)
	if player == nil then
		return false
	end
	if ready and not hasChosenPreferences(flow, player) then
		return false
	end

	player.ready = ready
	return true
end

--[[
	Permintaan tukar role (PRD §8: "Pemain boleh tukar role di lobby (saling
	setuju)").

	Satu permintaan hanya dicatat; penukaran terjadi saat pihak lain meminta
	arah sebaliknya. `assigned` diubah di tempat supaya server memegang satu
	salinan penugasan saja -- sama seperti `Matchmaking.swap`.
]]
function LobbyFlow.requestSwap(
	flow: Flow,
	playerA: number,
	playerB: number,
	assigned: { [number]: string }
): boolean
	if playerA == playerB then
		return false
	end
	if
		Matchmaking.find(flow.lobby, playerA) == nil
		or Matchmaking.find(flow.lobby, playerB) == nil
	then
		return false
	end

	local pending = flow.pendingSwap
	if pending ~= nil and pending.from == playerB and pending.to == playerA then
		local ok = Matchmaking.swap(flow.lobby, playerA, playerB, assigned)
		if ok then
			flow.pendingSwap = nil
		end
		return ok
	end

	flow.pendingSwap = { from = playerA, to = playerB }
	return false
end

--[[
	Melupakan state sementara seorang pemain.

	Permintaan tukar yang belum dijawab harus hilang saat pemain keluar, supaya
	pemain berikutnya tidak mewarisi permintaan lama. Keanggotaan lobby sendiri
	diurus `Matchmaking.leave` oleh pemanggil: berkas ini hanya memegang state
	fase.
]]
function LobbyFlow.forgetPlayer(flow: Flow, playerId: number): ()
	local pending = flow.pendingSwap
	if pending ~= nil and (pending.from == playerId or pending.to == playerId) then
		flow.pendingSwap = nil
	end
end

--[[
	Potongan state lobby untuk satu pemain. Pemain di luar lobby tidak diberi
	preferensi maupun status siap: `nil` berarti "tidak ada", bukan "kosong".
]]
function LobbyFlow.snapshot(flow: Flow, now: number, playerId: number): Snapshot
	local readyCount = 0
	for _, player in flow.lobby.players do
		if player.ready then
			readyCount += 1
		end
	end

	local payload: Snapshot = {
		phase = flow.phase,
		seconds_left = LobbyFlow.secondsLeft(flow, now),
		player_count = #flow.lobby.players,
		ready_count = readyCount,
		max_players = flow.config.maxPlayers,
	}

	local player = Matchmaking.find(flow.lobby, playerId)
	if player ~= nil then
		payload.preferences = player.preferences
		payload.ready = player.ready
	end

	return payload
end

return LobbyFlow
