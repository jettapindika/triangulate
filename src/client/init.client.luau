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
local Location = require(script.Location)
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

-- Lokasi (PRD §4, §6). Dipasang LAZY, saat role diketahui Searcher -- sama
-- alasannya dengan meja di atas: server hanya mengirim objek lokasi lewat
-- atribut part, dan prompt-nya hanya berguna bagi Searcher. Handler dan
-- Director berada di meja dan clue board (PRD §3).
local location: Location.Mount? = nil

-- Clue board Director (PRD §4, §5, §7). Sama seperti meja: dipasang LAZY, bukan
-- di sini.
--
-- Gerbangnya adalah role. Sebagian payload yang memicu papan memang hanya
-- dikirim ke Director (`statements`, `table_preview`, `contradiction_result`),
-- tetapi sebagian lain tidak: `clue_card` dan `deduction` dikirim ke tiga role
-- dan `pinpoint` ke Searcher + Director (`Net.CLIENT_VIEWS`). Tanpa gerbang
-- role, Searcher dan Handler ikut memasang papan dan melihat UI milik Director
-- -- melanggar pemisahan role PRD §3/§15. Role-nya sendiri baru diketahui dari
-- briefing pertama, jadi pemasangan menunggu `state.role` yang asli dari
-- server, bukan tebakan client.
local board: Board.Mount? = nil

-- Status yang ditampilkan HUD. Server adalah satu-satunya penulis nilai-nilai
-- ini; client tidak menghitungnya sendiri.
--
-- Dideklarasikan SEBELUM `ensureBoard` dan `mountLocationIfSearcher` di bawah:
-- keduanya membaca `state.role` untuk memutuskan apa yang perlu dipasang.
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
	gateOpen = nil,
	keyDeductionsDone = nil,
	keyDeductionsRequired = nil,
	contradictionsMarked = nil,
	contradictionsRequired = nil,
	cleanupSecondsLeft = nil,
	coldCaseRecap = nil,
	accusationOptions = nil,
	lobbyPhase = nil,
	lobbySecondsLeft = nil,
	lobbyPlayerCount = nil,
	lobbyReadyCount = nil,
	lobbyMaxPlayers = nil,
	lobbyPreferences = nil,
	lobbyReady = nil,
}

-- Papan dipasang untuk Director saja. Payload yang memicunya BUKAN semua milik
-- Director -- `clue_card` dan `deduction` dikirim ke tiga role, `pinpoint` ke
-- Searcher + Director -- jadi gerbangnya harus dibaca dari `state.role`, bukan
-- disimpulkan dari payload. `nil` berarti "role ini memang tidak punya papan",
-- bukan "belum dipasang".
local function ensureBoard(): Board.Mount?
	if state.role ~= "Director" then
		return nil
	end

	local current = board
	if current == nil then
		current = Board.mount(player, {
			deduce = function(clueIds: { string })
				NetClient.deduce(bound, clueIds)
			end,
			markContradiction = function(statementId: number)
				-- Papan menandai pernyataan dengan indeks 1-based di
				-- `case.statements` (itu `id` yang dikirim di briefing), sedangkan
				-- kabelnya memakai id stabil `stmt_<n>` (`AccusationGate.statementId`).
				-- Penerjemahannya ada di sini, satu tempat: server tidak perlu
				-- tahu bentuk id milik client, dan papan tidak perlu tahu bentuk
				-- id di kabel.
				NetClient.markContradiction(bound, string.format("stmt_%d", statementId))
			end,
		})
		board = current
	end
	return current
end

-- Lokasi dipasang saat role sudah diketahui Searcher (PRD §6: mini-aksi dan
-- prompt ada di sisi Searcher). Dipanggil dari handler `SessionState`, jadi
-- pemasangannya menunggu role yang asli dari server, bukan tebakan client.
local function mountLocationIfSearcher(): ()
	if location ~= nil or state.role ~= "Searcher" then
		return
	end

	location = Location.mount({
		inspect = function(objectId: string, action: string, phase: string)
			NetClient.inspect(bound, objectId, action, phase)
		end,
		report = function(objectId: string, action: string)
			-- Lokasi TIDAK dikirim: server memakai lokasi sesinya sendiri
			-- (`current.location.location`). Mengirimkannya dari client berarti
			-- mengizinkan client mengarang tag lokasi di clue board Director.
			NetClient.report(bound, objectId, action)
		end,
	})
end

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
	onAccuse = function(accusation: { [string]: string })
		-- Gerbang ditampilkan di HUD; server tetap memeriksanya ulang
		-- (`AccusationGate.admit`) dan menolak percobaan di luar gerbang tanpa
		-- memakan jatah percobaan tim.
		NetClient.accuse(bound, accusation)
	end,
	onSubmitPreferences = function(preferences: { string })
		-- PRD §3: dua preferensi role, urut prioritas. Yang dikirim adalah
		-- urutan pilihan, bukan role yang diklaim; penugasan tetap milik server
		-- (`RoleAssignment`).
		NetClient.submitPreferences(bound, preferences)
	end,
	onSetReady = function(ready: boolean)
		-- PRD §8: ready check. Pemain yang tidak siap diganti NPC, dan yang
		-- memutuskan itu `LobbyFlow.tick` -- bukan client.
		NetClient.setReady(bound, ready)
	end,
	onRequestSwap = function(targetUserId: number)
		-- PRD §8: tukar role hanya terjadi bila kedua pihak saling meminta,
		-- jadi ini permintaan, bukan penukaran.
		NetClient.requestSwap(bound, targetUserId)
	end,
})

-- PRD §3, §8: fase lobby. Ini payload pertama yang datang, dan satu-satunya
-- yang berarti sampai sesi dimulai. Server mengirim snapshot baru setiap kali
-- lobby berubah, jadi panel tidak perlu menghitung apa pun sendiri.
bound.LobbyState.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	-- "started" berarti lobby selesai dan HUD sesi yang berlaku. Snapshot
	-- pertama fase itu memang masih terkirim, jadi panelnya disembunyikan di
	-- sini -- bukan menunggu `session_state`.
	if payload.phase == "started" then
		hud.hideLobby()
		return
	end

	hud.updateLobby(payload)
end)

-- Briefing per role (PRD §9), status sesi (PRD §5, §6), dan kandidat form
-- tuduhan (PRD §5). Ketiganya datang lewat remote yang sama, diproyeksikan
-- server per role; client hanya memindahkan field yang ada ke `state`.
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

	-- PRD §5: kandidat isi form tuduhan. Ini daftar pilihan, bukan jawaban --
	-- solusinya tetap hanya ada di server. Dikirim ke semua role, jadi formnya
	-- baru muncul di layar Director (`Hud.mount` memutuskan itu dari
	-- `state.role`).
	if payload.suspects ~= nil or payload.motives ~= nil or payload.methods ~= nil then
		state.accusationOptions = {
			suspects = payload.suspects or {},
			motives = payload.motives or {},
			methods = payload.methods or {},
		}
	end

	-- PRD §5, §6: progres gerbang, timer cleanup, dan rekap Cold Case. Field
	-- yang tidak ada di proyeksi role ini memang tidak dikirim, jadi `nil`
	-- berarti "role ini tidak memegangnya", bukan "belum sampai".
	if payload.gate_open ~= nil then
		state.gateOpen = payload.gate_open
	end
	if payload.key_deductions_done ~= nil then
		state.keyDeductionsDone = payload.key_deductions_done
	end
	if payload.key_deductions_required ~= nil then
		state.keyDeductionsRequired = payload.key_deductions_required
	end
	if payload.contradictions_marked ~= nil then
		state.contradictionsMarked = payload.contradictions_marked
	end
	if payload.contradictions_required ~= nil then
		state.contradictionsRequired = payload.contradictions_required
	end
	if payload.cleanup_seconds_left ~= nil then
		state.cleanupSecondsLeft = payload.cleanup_seconds_left
	end
	if payload.cold_case_recap ~= nil then
		state.coldCaseRecap = payload.cold_case_recap
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
			local current = ensureBoard()
			if current ~= nil then
				current.applyStatements(payload)
			end
		end
	elseif payload.gate_open ~= nil then
		-- PRD §5: status gerbang form tuduhan.
		local current = ensureBoard()
		if current ~= nil then
			current.applySessionState(payload)
		end
	end

	-- Role baru diketahui dari briefing pertama. Inilah saat yang tepat
	-- memasang lokasi: sebelum ini kita belum tahu apakah pemain ini Searcher.
	mountLocationIfSearcher()

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

	local clueBoard = ensureBoard()
	if clueBoard ~= nil then
		clueBoard.applyClueCard(payload)
	end
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

	local clueBoard = ensureBoard()
	if clueBoard ~= nil then
		clueBoard.applyDeduction(payload)
	end
end)

-- PRD §4, §7: pinpoint baru. Server mengirimnya ke Searcher dan Director, tapi
-- yang sudah bisa memakainya baru papan Director: peta di sana menggambar
-- penanda berlabel. Searcher menerima payload yang sama dan BELUM menggambar
-- apa pun -- marka di dunia butuh koordinat objek, dan data kasus belum
-- punya (lihat utang minggu 2 di `README.md`). Karena itu papan hanya dipasang
-- untuk Director; memasangnya di client Searcher akan memunculkan UI milik
-- Director, bukan marker.
bound.Pinpoint.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local clueBoard = ensureBoard()
	if clueBoard ~= nil then
		clueBoard.applyPinpoint(payload)
	end
end)

-- PRD §4: hasil penandaan Kontradiksi. Ditolak selalu disertai alasan yang bisa
-- dibaca pemain.
bound.ContradictionResult.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local clueBoard = ensureBoard()
	if clueBoard ~= nil then
		clueBoard.applyContradictionResult(payload)
	end
end)

-- PRD §7: Table Preview read-only meja Handler.
bound.TablePreview.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local clueBoard = ensureBoard()
	if clueBoard ~= nil then
		clueBoard.applyTablePreview(payload)
	end
end)

return nil
