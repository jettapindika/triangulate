--!strict
-- Titik masuk client (PRD §7, §9, §15).
--
-- Aturan yang dipegang berkas ini: client TIDAK PERNAH menghitung hasil.
-- Ia mengirim id (objek, Clue Card, frasa ping, isi form tuduhan) dan
-- menampilkan apa yang dikembalikan server. Tidak ada resep deduksi, tidak ada
-- solusi kasus, dan tidak ada penilaian tuduhan di sisi client.
--
-- Dokumentasi Roblox: "Any content that replicates to a client can be
-- extracted and data-mined by an exploiter."
-- -> https://create.roblox.com/docs/scripting/security/access-control
-- Itulah sebabnya client tidak diberi apa pun yang tidak perlu ditampilkan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PingPhrases = require(Shared.PingPhrases)

-- Rojo: `src/client/init.client.luau` menjadi LocalScript bernama `Client`, dan
-- berkas di sebelahnya menjadi ANAK dari LocalScript itu. Jadi modul-modul ini
-- dijangkau lewat `script.<nama>`, bukan `script.Parent.<nama>`.
local NetClient = require(script.NetClient)
local Hud = require(script.Hud)
local Table = require(script.Table)

local player = Players.LocalPlayer
local bound = NetClient.bind(Shared)

-- Meja puzzle (PRD §4, §15). Dipasang LAZY, saat `puzzle_state` pertama datang
-- -- bukan di sini.
--
-- Alasannya kamera: `Table.mount` memindahkan kamera ke mode `Scriptable`
-- top-down, dan Searcher butuh kamera first/third person untuk menjelajah
-- (PRD §3). Server hanya mengirim `puzzle_state` ke Handler dan Director
-- (`Net.CLIENT_VIEWS`), jadi memasang meja di dalam handler itu sudah menjadi
-- gerbang perannya sendiri -- tidak perlu membaca role dari payload, yang bisa
-- saja belum tiba.
local table_: Table.Mount? = nil

-- Status yang ditampilkan HUD. Server adalah satu-satunya penulis nilai-nilai
-- ini; client tidak menghitungnya sendiri.
local state: Hud.State = {
	role = nil,
	phase = nil,
	correctCount = nil,
	attemptsLeft = nil,
	resolved = nil,
	won = nil,
	pendingConfirmation = nil,
}

local hud = Hud.mount(player, state, function(phraseId: string)
	-- Validasi lokal ini bukan pengamanan -- server tetap memvalidasi ulang.
	-- Gunanya hanya supaya client tidak mengirim ping yang pasti ditolak.
	if state.role ~= nil and PingPhrases.isValid(state.role, phraseId) then
		NetClient.ping(bound, phraseId)
	end
end)

-- Briefing per role (PRD §9). Payload ini sudah diproyeksikan server untuk role
-- pemain ini; field yang tidak ada di view-nya memang tidak dikirim.
bound.SessionState.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	if payload.role ~= nil then
		state.role = payload.role
	end
	if payload.phase ~= nil then
		state.phase = payload.phase
	end

	-- Briefing awal dan pembaruan status datang lewat remote yang sama; yang
	-- membedakannya adalah ada tidaknya `objective`.
	if payload.objective ~= nil then
		hud.showRoleCard(payload)
	end

	hud.update(state)
end)

-- PRD §5: feedback tuduhan. Server hanya mengirim jumlah field yang benar.
bound.AccusationResult.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	state.correctCount = payload.correct_count
	state.attemptsLeft = payload.attempts_left
	state.resolved = payload.resolved
	state.won = payload.won
	state.pendingConfirmation = payload.pending_confirmation

	hud.update(state)
end)

-- PRD §5: begitu server menyatakan tuduhan menunggu konfirmasi, satu role lain
-- mengirim konfirmasi. Client tidak pernah memutuskan siapa yang boleh
-- mengonfirmasi -- server yang memeriksa.
bound.ConfirmAccusation.OnClientEvent:Connect(function()
	NetClient.confirmAccusation(bound)
end)

-- PRD §4, §15: meja puzzle. Payload pertama yang tiba memasang meja; pesan
-- berikutnya hanya memperbarui posisi potongan.
bound.PuzzleState.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local current = table_
	if current == nil then
		current = Table.mount(
			player,
			function(nodeId: string, pieceId: string, u: number, v: number)
				NetClient.placePiece(bound, nodeId, pieceId, u, v)
			end
		)
		table_ = current
	end

	current.applyState(payload)
end)

-- PRD §15: hasil penempatan otoritatif. Client menginterpolasi ke nilai ini;
-- `accepted` false berarti drop ditolak dan potongan ditarik kembali.
bound.PiecePlaced.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local current = table_
	if current ~= nil then
		current.applyPlacement(payload)
	end
end)

return nil
