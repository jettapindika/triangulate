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
local Board = require(script.Board)

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

-- Clue board Director (PRD §4, §5, §7). Sama seperti meja: dipasang LAZY, bukan
-- di sini.
--
-- Gerbangnya kali ini bukan kamera melainkan role: clue board hanya masuk akal
-- untuk Director, dan payload yang memicunya -- `statements`, `table_preview`,
-- `contradiction_result` -- memang hanya dikirim ke Director (`Net.CLIENT_VIEWS`).
-- Jadi client tidak perlu menebak role dari payload; server sudah menyaringnya.
-- Payload pertama yang tiba memasang papan.
local board: Board.Mount? = nil

local function ensureBoard(): Board.Mount
	local current = board
	if current == nil then
		current = Board.mount(player, {
			deduce = function(clueIds: { string })
				NetClient.deduce(bound, clueIds)
			end,
			markContradiction = function(statementId: number)
				NetClient.markContradiction(bound, statementId)
			end,
		})
		board = current
	end
	return current
end

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
	marker = nil,
	briefingTarget = nil,
}

local hud = Hud.mount(player, state, {
	onPing = function(phraseId: string)
		-- Validasi lokal ini bukan pengamanan -- server tetap memvalidasi
		-- ulang. Gunanya hanya supaya client tidak mengirim ping yang pasti
		-- ditolak.
		if state.role ~= nil and PingPhrases.isValid(state.role, phraseId) then
			NetClient.ping(bound, phraseId)
		end
	end,
	onReport = function(objectId: string)
		-- PRD §7: Report Card. Client hanya mengirim id objeknya; tag lokasi
		-- dan label dihitung server dari data kasus, sehingga pemain tidak
		-- bisa memalsukan tag lokasi di clue board Director.
		NetClient.report(bound, objectId)
	end,
	onSetTarget = function(targetId: string)
		-- PRD §7: Handler menandai target. Client mengirim id; server memetakan
		-- id itu ke benda di lokasi dan menghitung arah kompasnya.
		NetClient.setTarget(bound, targetId)
	end,
})

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
	-- PRD §7: target awal dari arsip. Handler menandainya supaya Searcher
	-- melihat arah kompas. Disimpan agar tombol Tandai tahu apa yang dikirim.
	if type(payload.target) == "string" then
		state.briefingTarget = payload.target
	end

	-- Briefing awal dan pembaruan status datang lewat remote yang sama; yang
	-- membedakannya adalah ada tidaknya `objective`.
	if payload.objective ~= nil then
		hud.showRoleCard(payload)
		-- PRD §4: pernyataan saksi menyeberang di dalam briefing Director --
		-- `CaseLoader.projectForRole` yang menyaringnya per varian dan membuang
		-- `lie`/`contradicted_by`/`variants`. Kedatangannya menandai bahwa papan
		-- Director perlu dipasang.
		if payload.statements ~= nil then
			ensureBoard().applyStatements(payload)
		end
	elseif payload.gate_open ~= nil then
		-- PRD §5: status gerbang form tuduhan.
		ensureBoard().applySessionState(payload)
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

-- PRD §4: Clue Card yang terbuka dari bukti yang selesai dirakit Handler.
-- Director menggabungkannya di clue board.
bound.ClueCard.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	ensureBoard().applyClueCard(payload)
end)

-- PRD §7: "Target Marker: Handler menaruh ikon target yang muncul di HUD
-- Searcher dan arah kompas." Label dan arah datang dari server; client tidak
-- menghitung keduanya.
bound.TargetMarker.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	state.marker = {
		target_id = payload.target_id,
		label = payload.label,
		bearing = payload.bearing,
	}
	hud.showMarker(payload)
end)

-- PRD §7: ping dari role lain. Teksnya sudah diputuskan server
-- (`PingPhrases.labelFor`), jadi client tidak menyimpan salinan daftar frasa
-- sendiri -- dua salinan akan menyimpang.
bound.PingRelay.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local from = tostring(payload.from_role or "?")
	local text = payload.label
	if type(text) ~= "string" then
		return
	end

	hud.showPing(from, text)
end)

-- PRD §7: Report Card. Yang kembali sudah diperkaya server: label objek dan tag
-- lokasi dari data kasus.
bound.ReportCard.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	hud.showReport(payload)
end)

-- PRD §4: hasil kombinasi Clue Card. `reason` hanya terisi saat ditolak; saat
-- diterima, payload membawa `pinpoint`/`unlocks` dan BUKAN resepnya.
bound.DeductionResult.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	ensureBoard().applyDeduction(payload)
end)

-- PRD §4, §7: pinpoint baru. Director melihatnya di peta; Searcher melihatnya
-- di dunia sebagai marker.
bound.Pinpoint.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	ensureBoard().applyPinpoint(payload)
end)

-- PRD §4: hasil penandaan Kontradiksi. Ditolak selalu disertai alasan yang bisa
-- dibaca pemain.
bound.ContradictionResult.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	ensureBoard().applyContradictionResult(payload)
end)

-- PRD §7: Table Preview read-only meja Handler.
bound.TablePreview.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	ensureBoard().applyTablePreview(payload)
end)

return nil
