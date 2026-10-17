--!strict
-- HUD client (PRD §5, §7, §9, §15).
--
-- Prinsip yang dipegang modul ini: client hanya MENAMPILKAN apa yang dikirim
-- server. Tidak ada perhitungan resep, tidak ada penilaian tuduhan, tidak ada
-- pengetahuan tentang varian kasus. Kalau sebuah nilai tidak datang lewat
-- remote, client tidak menampilkannya -- itu perilaku yang benar, bukan bug.
--
-- Tampilan yang dibangun di sini adalah yang bisa dibangun sekarang: Role Card
-- (PRD §9), status sesi, feedback tuduhan (PRD §5), form tuduhan (PRD §5),
-- rekap Cold Case (PRD §5), ping wheel + toast (PRD §7), Report Card (PRD §7),
-- dan Target Marker dengan kompas (PRD §7). Meja puzzle dan clue board punya
-- modulnya sendiri -- `Table` (minggu 1, PRD §17) dan `Board` (minggu 3) -- dan
-- sengaja tidak digabung ke HUD: keduanya menempati layar penuh, dan `Table`
-- memindahkan kamera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
-- Daftar role untuk pemilih preferensi di lobby (PRD §3, §8). Diambil dari
-- modul bersama supaya tidak ada salinan kedua yang bisa menyimpang.
local Roles = require(Shared.Roles)

local PingWheel = require(script.PingWheel)

local Hud = {}

-- docs/art/ui-spec.md, Layar 4 "HUD Searcher": aksi utama 56, aksi sekunder
-- 48, slot ping wheel lebar 96, dan tidak ada aksi di bawah 36. Angka-angka
-- itu offset POINT, bukan piksel.
local TOUCH_MAIN = 56
local TOUCH_PING = 96

-- Toast ping hilang sendiri. Cukup lama untuk dibaca di ponsel sambil
-- mengerjakan hal lain, cukup pendek untuk tidak menutupi layar.
local TOAST_SECONDS = 3

local COLORS = {
	background = Color3.fromRGB(24, 22, 20),
	panel = Color3.fromRGB(38, 34, 30),
	text = Color3.fromRGB(240, 236, 228),
	muted = Color3.fromRGB(168, 158, 146),
	accent = Color3.fromRGB(214, 168, 92),
}

local function panel(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = COLORS.panel
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = frame

	return frame
end

local function label(parent: Instance, name: string, size: number, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamMedium
	text.TextSize = size
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	text.Size = UDim2.new(1, 0, 0, size + 8)
	text.Parent = parent
	return text
end

export type State = {
	role: string?,
	phase: string?,
	correctCount: number?,
	attemptsLeft: number?,
	resolved: boolean?,
	won: boolean?,
	pendingConfirmation: boolean?,
	-- PRD §5: progres gerbang dan timer cleanup. Client hanya menampilkan;
	-- yang menghitung dan menegakkan keduanya adalah server.
	gateOpen: boolean?,
	keyDeductionsDone: number?,
	keyDeductionsRequired: number?,
	contradictionsMarked: number?,
	contradictionsRequired: number?,
	cleanupSecondsLeft: number?,
	-- PRD §5: rekap parsial Cold Case. Seluruhnya angka -- server tidak pernah
	-- mengirim id node atau teks jawaban ke sini.
	coldCaseRecap: { [string]: number }?,
	-- PRD §5: kandidat isi form tuduhan, yaitu payload `accusation_options`
	-- (`suspects`/`motives`/`methods`). Kandidat, bukan jawaban.
	accusationOptions: { [string]: { string } }?,
	-- PRD §7: marker yang dipasang Handler, terlihat di HUD Searcher.
	marker: { target_id: string?, label: string?, bearing: number? }?,
	-- PRD §7: target awal yang diberikan briefing ke Handler. Inilah yang
	-- dipasang sebagai marker, karena Handler tahu apa yang harus dicari
	-- sebelum Searcher tahu di mana mencarinya.
	briefingTarget: string?,
	-- PRD §3, §8: status lobby. `lobbyPhase` terpisah dari `phase` di atas --
	-- yang itu fase sesi, yang ini "waiting" | "ready_check". `lobbyPreferences`
	-- dan `lobbyReady` boleh `nil`: `LobbyFlow.snapshot` hanya mengisinya untuk
	-- pemain yang benar-benar ada di lobby.
	lobbyPhase: string?,
	lobbySecondsLeft: number?,
	lobbyPlayerCount: number?,
	lobbyReadyCount: number?,
	lobbyMaxPlayers: number?,
	lobbyPreferences: { string }?,
	lobbyReady: boolean?,
}

-- PRD §5: tiga field tuduhan, dan daftar kandidatnya di `accusation_options`.
-- Kunci `field` HARUS sama dengan `Config.ACCUSATION_FIELDS` -- itu yang
-- divalidasi `AccusationService.validate`; kunci `option` adalah nama daftar
-- kandidat di payload server.
local ACCUSATION_ROWS = {
	{ field = "culprit", option = "suspects", title = "Pelaku" },
	{ field = "motive", option = "motives", title = "Motif" },
	{ field = "method", option = "methods", title = "Cara" },
}

-- Arah kompas dalam teks. Searcher melihat "utara-timur laut", bukan "37.5" --
-- angka derajat tidak berarti apa-apa saat berdiri di lokasi.
local COMPASS_POINTS = {
	"utara",
	"timur laut",
	"timur",
	"tenggara",
	"selatan",
	"barat daya",
	"barat",
	"barat laut",
}

local function compassText(bearing: number?): string
	if bearing == nil then
		-- Lokasi target belum punya anchor. Lebih jujur daripada menampilkan
		-- "0 derajat" yang terbaca sebagai "tepat di utara".
		return "arah belum tersedia"
	end
	local index = math.floor(((bearing % 360) / 45) + 0.5) % 8 + 1
	return COMPASS_POINTS[index]
end

-- PRD §9: Role Card -- "Kamu tahu apa / Tidak tahu apa / Tugas pertamamu".
-- Kartu ini ditampilkan sekali di awal sesi, dari payload briefing yang sudah
-- diproyeksikan server untuk role ini.
function Hud.showRoleCard(parent: Instance, briefing: { [string]: any }): Frame
	local card =
		panel(parent, "RoleCard", UDim2.new(0.5, -220, 0.5, -150), UDim2.fromOffset(440, 300))

	local title = label(card, "Title", 26, COLORS.accent)
	title.Text = tostring(briefing.case_id or "Kasus")
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Size = UDim2.new(1, 0, 0, 34)

	local location = label(card, "Location", 15, COLORS.muted)
	location.Text = tostring(briefing.location or "")
	location.Position = UDim2.fromOffset(0, 38)

	local objective = label(card, "Objective", 17, COLORS.text)
	objective.Text = "Tugas pertamamu: " .. tostring(briefing.objective or "-")
	objective.Position = UDim2.fromOffset(0, 70)
	objective.Size = UDim2.new(1, 0, 0, 60)

	local knowns = label(card, "Knowns", 15, COLORS.text)
	knowns.Text = "Kamu tahu:\n" .. table.concat(briefing.knowns or {}, "\n")
	knowns.Position = UDim2.fromOffset(0, 140)
	knowns.Size = UDim2.new(1, 0, 0, 80)

	local unknowns = label(card, "Unknowns", 15, COLORS.muted)
	unknowns.Text = "Kamu tidak tahu:\n" .. table.concat(briefing.unknowns or {}, "\n")
	unknowns.Position = UDim2.fromOffset(0, 226)
	unknowns.Size = UDim2.new(1, 0, 0, 70)

	return card
end

-- Membangun HUD dan mengembalikan fungsi untuk memperbarui statusnya.
--
-- `handlers` membawa aksi yang boleh dilakukan client. Ping, Report, dan
-- Tandai sama bentuknya: client mengirim id, server memutuskan efeknya.
-- `onAccuse` hanya dipanggil dari tombol yang hidup, dan hidupnya ditentukan
-- `state.gateOpen` -- nilai yang datang dari server. Server tetap menegakkan
-- gerbangnya sendiri (`AccusationGate.admit`), karena client bisa dimodifikasi.
function Hud.mount(
	player: Player,
	state: State,
	handlers: {
		onPing: ((string) -> ())?,
		onReport: ((string) -> ())?,
		onSetTarget: ((string) -> ())?,
		onAccuse: (({ [string]: string }) -> ())?,
		-- PRD §3, §8: aksi fase lobby. Sama polanya dengan yang di atas --
		-- HUD hanya melaporkan niat, server yang memutuskan hasilnya.
		onSubmitPreferences: (({ string }) -> ())?,
		onSetReady: ((boolean) -> ())?,
		onRequestSwap: ((number) -> ())?,
	}
): {
	update: (State) -> (),
	showRoleCard: ({ [string]: any }) -> (),
	openPingWheel: () -> (),
	openAccusationForm: () -> (),
	showMarker: ({ [string]: any }) -> (),
	showReport: ({ [string]: any }) -> (),
	showPing: (string, string) -> (),
	updateLobby: ({ [string]: any }) -> (),
	hideLobby: () -> (),
}
	local gui = Instance.new("ScreenGui")
	gui.Name = "TriangulateHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Bilah status kiri atas: role, fase, feedback tuduhan, progres gerbang,
	-- dan sisa waktu cleanup.
	local status = panel(gui, "Status", UDim2.fromOffset(16, 16), UDim2.fromOffset(300, 140))

	local roleLabel = label(status, "Role", 20, COLORS.accent)
	roleLabel.Position = UDim2.new(0, 0, 0, 0)
	roleLabel.Size = UDim2.new(1, 0, 0, 26)

	local phaseLabel = label(status, "Phase", 15, COLORS.text)
	phaseLabel.Position = UDim2.fromOffset(0, 32)

	local accusationLabel = label(status, "Accusation", 15, COLORS.muted)
	accusationLabel.Position = UDim2.fromOffset(0, 56)

	local gateLabel = label(status, "Gate", 15, COLORS.muted)
	gateLabel.Position = UDim2.fromOffset(0, 80)

	local cleanupLabel = label(status, "Cleanup", 15, COLORS.muted)
	cleanupLabel.Position = UDim2.fromOffset(0, 104)

	-- PRD §7: "Target Marker: Handler menaruh ikon target yang muncul di HUD
	-- Searcher dan arah kompas." Panel ini hanya muncul setelah marker datang.
	local markerPanel =
		panel(gui, "TargetMarker", UDim2.new(1, -276, 0, 16), UDim2.fromOffset(260, 74))
	markerPanel.Visible = false

	local markerLabel = label(markerPanel, "Target", 17, COLORS.accent)
	markerLabel.Position = UDim2.fromOffset(0, 0)
	markerLabel.Size = UDim2.new(1, 0, 0, 28)

	local bearingLabel = label(markerPanel, "Bearing", 15, COLORS.text)
	bearingLabel.Position = UDim2.fromOffset(0, 30)
	bearingLabel.Size = UDim2.new(1, 0, 0, 34)

	-- Satu jalur tampil untuk pesan singkat: ping yang masuk, dan konfirmasi
	-- Report yang baru dikirim. Keduanya "tanpa mengetik" (PRD §7), jadi
	-- keduanya butuh tempat yang sama untuk terlihat.
	local toast = panel(gui, "Toast", UDim2.fromOffset(16, 176), UDim2.fromOffset(320, 50))
	toast.Visible = false

	local toastLabel = label(toast, "Text", 16, COLORS.text)
	toastLabel.Position = UDim2.fromOffset(0, 0)
	toastLabel.Size = UDim2.new(1, 0, 0, 34)

	local toastToken = 0
	local function showToast(text: string): ()
		toastLabel.Text = text
		toast.Visible = true
		toastToken += 1
		local token = toastToken
		task.delay(TOAST_SECONDS, function()
			-- Hanya sembunyikan bila tidak ada pesan lebih baru yang masuk.
			if toastToken == token then
				toast.Visible = false
			end
		end)
	end

	-- PRD §7: "Report Card: Searcher menekan Report." Aksi utama, ukuran sentuh
	-- 56 point (docs/art/ui-spec.md, Layar 4).
	local reportButton = Instance.new("TextButton")
	reportButton.Name = "ReportButton"
	reportButton.Text = "Report"
	reportButton.TextSize = 18
	reportButton.Font = Enum.Font.GothamBold
	reportButton.TextColor3 = COLORS.text
	reportButton.BackgroundColor3 = COLORS.panel
	reportButton.BorderSizePixel = 0
	reportButton.AnchorPoint = Vector2.new(1, 1)
	-- 24 dari tepi + 96 tombol ping + 8 jarak: Report duduk tepat di atas Ping.
	reportButton.Position = UDim2.new(1, -24, 1, -(24 + TOUCH_PING + 8))
	reportButton.Size = UDim2.fromOffset(TOUCH_MAIN, TOUCH_MAIN)
	reportButton.Parent = gui

	local reportCorner = Instance.new("UICorner")
	reportCorner.CornerRadius = UDim.new(0, 12)
	reportCorner.Parent = reportButton

	-- PRD §7: "Target Marker: Handler menaruh ikon target". Handler yang tahu
	-- benda apa yang dicari (dari arsip), Searcher yang bisa melihat lokasinya.
	-- Tombol ini hanya berarti bagi Handler, jadi HUD menampilkannya sesuai role
	-- dan menyembunyikannya untuk yang lain.
	local markButton = Instance.new("TextButton")
	markButton.Name = "MarkButton"
	markButton.Text = "Tandai"
	markButton.TextSize = 18
	markButton.Font = Enum.Font.GothamBold
	markButton.TextColor3 = COLORS.text
	markButton.BackgroundColor3 = COLORS.panel
	markButton.BorderSizePixel = 0
	markButton.AnchorPoint = Vector2.new(1, 1)
	markButton.Position = UDim2.new(1, -24, 1, -(24 + TOUCH_PING + 8 + TOUCH_MAIN + 8))
	markButton.Size = UDim2.fromOffset(TOUCH_MAIN, TOUCH_MAIN)
	markButton.Visible = false
	markButton.Parent = gui

	local markCorner = Instance.new("UICorner")
	markCorner.CornerRadius = UDim.new(0, 12)
	markCorner.Parent = markButton

	-- PRD §7: tombol ping. Target sentuh besar (PRD §15).
	local pingButton = Instance.new("TextButton")
	pingButton.Name = "PingButton"
	pingButton.Text = "Ping"
	pingButton.TextSize = 22
	pingButton.Font = Enum.Font.GothamBold
	pingButton.TextColor3 = COLORS.background
	pingButton.BackgroundColor3 = COLORS.accent
	pingButton.BorderSizePixel = 0
	pingButton.AnchorPoint = Vector2.new(1, 1)
	pingButton.Position = UDim2.new(1, -24, 1, -24)
	pingButton.Size = UDim2.fromOffset(TOUCH_PING, TOUCH_PING)
	pingButton.Parent = gui

	local pingCorner = Instance.new("UICorner")
	pingCorner.CornerRadius = UDim.new(1, 0)
	pingCorner.Parent = pingButton

	-- PRD §5: pembuka form tuduhan. Hanya Director yang pernah melihatnya, dan
	-- hanya setelah server menyatakan gerbangnya terbuka -- jadi formnya tidak
	-- bisa dibuka sama sekali sebelum gerbang terpenuhi.
	local accusationButton = Instance.new("TextButton")
	accusationButton.Name = "AccusationButton"
	accusationButton.Text = "Tuduhan"
	accusationButton.TextSize = 20
	accusationButton.Font = Enum.Font.GothamBold
	accusationButton.TextColor3 = COLORS.background
	accusationButton.BackgroundColor3 = COLORS.accent
	accusationButton.BorderSizePixel = 0
	accusationButton.AnchorPoint = Vector2.new(1, 1)
	accusationButton.Position = UDim2.new(1, -24, 1, -140)
	accusationButton.Size = UDim2.fromOffset(120, 56)
	accusationButton.Visible = false
	accusationButton.Parent = gui

	local accusationCorner = Instance.new("UICorner")
	accusationCorner.CornerRadius = UDim.new(0, 12)
	accusationCorner.Parent = accusationButton

	local form =
		panel(gui, "AccusationForm", UDim2.new(0.5, -200, 0.5, -170), UDim2.fromOffset(400, 340))
	form.Visible = false

	local formTitle = label(form, "Title", 22, COLORS.accent)
	formTitle.Text = "Form Tuduhan"
	formTitle.Position = UDim2.fromOffset(0, 0)
	formTitle.Size = UDim2.new(1, 0, 0, 28)

	local formGate = label(form, "Gate", 15, COLORS.muted)
	formGate.Position = UDim2.fromOffset(0, 32)
	formGate.Size = UDim2.new(1, 0, 0, 20)

	local formResult = label(form, "Result", 15, COLORS.text)
	formResult.Position = UDim2.fromOffset(0, 54)
	formResult.Size = UDim2.new(1, 0, 0, 20)

	local chosen: { [string]: string } = {}
	local rowValues: { [string]: TextLabel } = {}

	local submitButton = Instance.new("TextButton")
	submitButton.Name = "Submit"
	submitButton.Text = "Kirim tuduhan"
	submitButton.TextSize = 18
	submitButton.Font = Enum.Font.GothamBold
	submitButton.TextColor3 = COLORS.background
	submitButton.BackgroundColor3 = COLORS.accent
	submitButton.BorderSizePixel = 0
	submitButton.Position = UDim2.fromOffset(0, 274)
	submitButton.Size = UDim2.new(1, 0, 0, 40)
	submitButton.Parent = form

	local submitCorner = Instance.new("UICorner")
	submitCorner.CornerRadius = UDim.new(0, 8)
	submitCorner.Parent = submitButton

	-- Rekap Cold Case. Dibuat saat kasus benar-benar berakhir sebagai Cold Case
	-- (PRD §5, SOP-03 A.2).
	local recapLabel: TextLabel? = nil

	local function refresh(): ()
		local open = state.gateOpen == true
		local finished = state.resolved == true

		-- PRD §5: progres gerbang. Hanya Director yang menerima angka ini dari
		-- server (`Net.CLIENT_VIEWS.session_state`), jadi hanya dia yang
		-- menampilkannya.
		local gateText = ""
		if state.role == "Director" and state.keyDeductionsRequired ~= nil then
			gateText = string.format(
				"Gerbang: %d/%d Deduksi Kunci, %d/%d Kontradiksi",
				state.keyDeductionsDone or 0,
				state.keyDeductionsRequired,
				state.contradictionsMarked or 0,
				state.contradictionsRequired or 0
			)
		end
		gateLabel.Text = gateText
		formGate.Text = gateText

		-- PRD §6: timer cleanup. Semua role menerimanya -- bukti yang terhapus
		-- ada di lokasi, dan Searcher yang paling perlu tahu.
		local cleanup = state.cleanupSecondsLeft
		cleanupLabel.Text = if cleanup ~= nil
			then string.format("Bukti terhapus dalam %d dtk", math.max(0, cleanup))
			else ""

		-- PRD §5: feedback salah hanya "X dari 3 benar", tanpa menyebut field
		-- mana. Client hanya bisa menampilkan angka yang dikirim server.
		local correct = state.correctCount
		local left = state.attemptsLeft
		local feedback = ""
		if correct ~= nil and left ~= nil then
			if finished then
				feedback = if state.won then "Kasus terpecahkan!" else "Cold Case"
			elseif state.pendingConfirmation then
				feedback = string.format("%d dari 3 benar - butuh konfirmasi role lain", correct)
			else
				feedback = string.format("%d dari 3 benar - sisa %d percobaan", correct, left)
			end
		end
		accusationLabel.Text = feedback
		formResult.Text = feedback

		-- Tombol buka form: Director, gerbang terbuka, kasus belum berakhir.
		accusationButton.Visible = state.role == "Director" and open and not finished
		if not accusationButton.Visible then
			form.Visible = false
		end

		-- Tombol kirim: butuh gerbang terbuka dan ketiga field terisi. Ini
		-- gerbang TAMPILAN saja; `AccusationGate.admit` di server yang menolak
		-- percobaan menembus.
		local ready = open and not finished
		for _, row in ACCUSATION_ROWS do
			if chosen[row.field] == nil then
				ready = false
			end
		end

		submitButton.Text = if open then "Kirim tuduhan" else "Gerbang belum terbuka"
		submitButton.Active = ready
		submitButton.AutoButtonColor = ready
		submitButton.BackgroundColor3 = if ready then COLORS.accent else COLORS.muted
		submitButton.TextColor3 = if ready then COLORS.background else COLORS.panel

		-- PRD §5, SOP-03 A.2: rekap parsial. Angka-angka ini datang dari server;
		-- client tidak menghitung apa pun.
		local recap = state.coldCaseRecap
		if finished and state.won ~= true and recap ~= nil then
			if recapLabel == nil then
				local card = panel(
					gui,
					"ColdCaseRecap",
					UDim2.new(0.5, -170, 0.5, -110),
					UDim2.fromOffset(340, 220)
				)
				local heading = label(card, "Heading", 20, COLORS.accent)
				heading.Text = "Cold Case - rekap parsial"
				heading.Position = UDim2.fromOffset(0, 0)
				heading.Size = UDim2.new(1, 0, 0, 26)
				recapLabel = label(card, "Body", 16, COLORS.text)
				recapLabel.Position = UDim2.fromOffset(0, 34)
				recapLabel.Size = UDim2.new(1, 0, 0, 160)
			end

			recapLabel.Text = string.format(
				"Bukti ditemukan: %d dari %d\nDeduksi kunci: %d dari %d\nKontradiksi ditandai: %d\nTuduhan terpakai: %d",
				recap.evidence_found or 0,
				recap.evidence_total or 0,
				recap.key_deductions_done or 0,
				recap.key_deductions_required or 0,
				recap.contradictions_marked or 0,
				recap.attempts_used or 0
			)
		elseif recapLabel ~= nil then
			recapLabel.Text = ""
		end
	end

	-- Daftar kandidat datang dari payload `accusation_options`; sampai ia tiba,
	-- barisnya menampilkan "-" dan tombol kirimnya mati.
	local function refreshRows(): ()
		local options = state.accusationOptions
		if options == nil then
			return
		end

		for _, row in ACCUSATION_ROWS do
			local list = options[row.option]
			local valueLabel = rowValues[row.field]
			if valueLabel == nil or type(list) ~= "table" or #list == 0 then
				continue
			end

			local current = chosen[row.field]
			local valid = false
			for _, candidate in list do
				if candidate == current then
					valid = true
					break
				end
			end

			if not valid then
				chosen[row.field] = list[1]
			end
			valueLabel.Text = chosen[row.field]
		end
	end

	-- Menggeser pilihan satu langkah dengan pembungkusan. Daftar kandidat hanya
	-- belasan entri, jadi berputar lebih cepat di layar sentuh daripada membuka
	-- daftar dropdown (PRD §7).
	local function cycle(row: { field: string, option: string, title: string }, step: number): ()
		local options = state.accusationOptions
		if options == nil then
			return
		end

		local list = options[row.option]
		if list == nil or #list == 0 then
			return
		end

		local index = 1
		for position, value in list do
			if value == chosen[row.field] then
				index = position
				break
			end
		end

		index = ((index - 1 + step) % #list) + 1
		chosen[row.field] = list[index]

		local valueLabel = rowValues[row.field]
		if valueLabel ~= nil then
			valueLabel.Text = list[index]
		end
		refresh()
	end

	local function smallButton(name: string, text: string, position: UDim2): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Text = text
		button.TextSize = 18
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = COLORS.text
		button.BackgroundColor3 = COLORS.background
		button.BorderSizePixel = 0
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = position
		button.Size = UDim2.fromOffset(40, 32)
		button.Parent = form

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		return button
	end

	for index, row in ACCUSATION_ROWS do
		local y = 82 + (index - 1) * 60

		local fieldLabel = label(form, row.field .. "Label", 13, COLORS.muted)
		fieldLabel.Text = row.title
		fieldLabel.Position = UDim2.fromOffset(0, y)
		fieldLabel.Size = UDim2.new(0.5, 0, 0, 18)

		local valueLabel = label(form, row.field .. "Value", 20, COLORS.text)
		valueLabel.Text = "-"
		valueLabel.Position = UDim2.fromOffset(0, y + 18)
		valueLabel.Size = UDim2.new(0.6, 0, 0, 26)
		rowValues[row.field] = valueLabel

		local previous = smallButton(row.field .. "Prev", "<", UDim2.new(1, -46, 0, y + 12))
		previous.Activated:Connect(function()
			cycle(row, -1)
		end)

		local next_ = smallButton(row.field .. "Next", ">", UDim2.new(1, 0, 0, y + 12))
		next_.Activated:Connect(function()
			cycle(row, 1)
		end)
	end

	submitButton.Activated:Connect(function()
		if state.gateOpen ~= true or state.resolved == true then
			return
		end

		local accusation: { [string]: string } = {}
		for _, row in ACCUSATION_ROWS do
			local value = chosen[row.field]
			if value == nil then
				return
			end
			accusation[row.field] = value
		end

		local accuse = handlers.onAccuse
		if accuse ~= nil then
			accuse(accusation)
		end
	end)

	-- PRD §3, §8: layar lobby -- dua preferensi role, tombol siap, hitungan
	-- pemain, hitungan waktu, dan tukar role. Semua kontrolnya tombol: PRD §2
	-- "Cukup sentuh, tidak harus ketik". Ukurannya mengikuti `docs/art/ui-spec.md`
	-- §2, layar 5: baris role 62, aksi utama 56, jarak antar target 8.
	local LOBBY_WIDTH = 460
	local LOBBY_ROW = 62
	local LOBBY_ACTION = 56
	local LOBBY_GAP = 8

	local lobby =
		panel(gui, "Lobby", UDim2.new(0.5, -230, 0.5, -310), UDim2.fromOffset(LOBBY_WIDTH, 620))
	-- Di atas panel status dan toast: selama fase lobby, panel ini yang utama.
	lobby.ZIndex = 12
	lobby.Visible = false

	local lobbyTitle = label(lobby, "Title", 24, COLORS.accent)
	lobbyTitle.Text = "Lobby"
	lobbyTitle.Position = UDim2.fromOffset(0, 0)
	lobbyTitle.Size = UDim2.new(1, 0, 0, 30)

	local lobbyCount = label(lobby, "Count", 15, COLORS.muted)
	lobbyCount.Position = UDim2.fromOffset(0, 34)
	lobbyCount.Size = UDim2.new(1, 0, 0, 20)

	local lobbyTimer = label(lobby, "Timer", 20, COLORS.text)
	lobbyTimer.Position = UDim2.fromOffset(0, 56)
	lobbyTimer.Size = UDim2.new(1, 0, 0, 26)

	local lobbyRolesTitle = label(lobby, "RolesTitle", 13, COLORS.muted)
	lobbyRolesTitle.Text = "Pilih 2 preferensi role"
	lobbyRolesTitle.Position = UDim2.fromOffset(0, 90)
	lobbyRolesTitle.Size = UDim2.new(1, 0, 0, 18)

	-- PRD §3: satu kalimat per role, supaya pemain baru tahu apa yang ia pilih
	-- tanpa membuka apa pun.
	local ROLE_DESCRIPTIONS = {
		Searcher = "Jelajah lokasi, temukan objek",
		Handler = "Rekonstruksi bukti di meja",
		Director = "Gabungkan clue, tuduh pelaku",
	}

	-- Satu baris per role, seluruh baris bisa disentuh -- bentuk yang sama
	-- dengan mockup layar 5. Anak-anaknya label, jadi ketukan tetap jatuh ke
	-- tombolnya.
	type RoleRow = {
		button: TextButton,
		badge: TextLabel,
		stroke: UIStroke,
		name: TextLabel,
		status: TextLabel,
	}
	local roleRows: { [string]: RoleRow } = {}

	for index, role in Roles.ALL do
		local button = Instance.new("TextButton")
		button.Name = role
		button.Text = ""
		button.BackgroundColor3 = COLORS.background
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(0, 110 + (index - 1) * (LOBBY_ROW + LOBBY_GAP))
		button.Size = UDim2.new(1, 0, 0, LOBBY_ROW)
		button.Parent = lobby

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = button

		local badge = label(button, "Badge", 13, COLORS.muted)
		badge.Text = tostring(index)
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.TextYAlignment = Enum.TextYAlignment.Center
		badge.Position = UDim2.fromOffset(12, 18)
		badge.Size = UDim2.fromOffset(26, 26)

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0.5, 0)
		badgeCorner.Parent = badge

		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = COLORS.muted
		badgeStroke.Thickness = 1
		badgeStroke.Parent = badge

		local name = label(button, "Name", 14, COLORS.text)
		name.Font = Enum.Font.GothamBold
		name.Text = role
		name.Position = UDim2.fromOffset(48, 8)
		name.Size = UDim2.new(1, -200, 0, 20)

		local desc = label(button, "Desc", 11, COLORS.muted)
		desc.Text = ROLE_DESCRIPTIONS[role] or role
		desc.Position = UDim2.fromOffset(48, 28)
		desc.Size = UDim2.new(1, -200, 0, 18)

		local status = label(button, "Status", 11, COLORS.muted)
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.TextYAlignment = Enum.TextYAlignment.Center
		status.Position = UDim2.new(1, -140, 0, 0)
		status.Size = UDim2.fromOffset(128, LOBBY_ROW)

		roleRows[role] =
			{ button = button, badge = badge, stroke = badgeStroke, name = name, status = status }
	end

	local lobbyPrefs = label(lobby, "Prefs", 13, COLORS.muted)
	lobbyPrefs.Position = UDim2.fromOffset(0, 322)
	lobbyPrefs.Size = UDim2.new(1, 0, 0, 18)

	local readyButton = Instance.new("TextButton")
	readyButton.Name = "Ready"
	readyButton.Text = "Siap, mulai kasus"
	readyButton.TextSize = 20
	readyButton.Font = Enum.Font.GothamBold
	readyButton.TextColor3 = COLORS.background
	readyButton.BackgroundColor3 = COLORS.accent
	readyButton.BorderSizePixel = 0
	readyButton.Position = UDim2.fromOffset(0, 524)
	readyButton.Size = UDim2.new(1, 0, 0, LOBBY_ACTION)
	readyButton.Parent = lobby

	local readyCorner = Instance.new("UICorner")
	readyCorner.CornerRadius = UDim.new(0, 12)
	readyCorner.Parent = readyButton

	local swapTitle = label(lobby, "SwapTitle", 13, COLORS.muted)
	swapTitle.Position = UDim2.fromOffset(0, 350)
	swapTitle.Size = UDim2.new(1, 0, 0, 18)

	-- PRD §8: tukar role butuh persetujuan dua pihak, jadi yang dikirim hanya
	-- permintaan ke satu pemain. Dua baris cukup: `Config.MAX_PLAYERS` = 3,
	-- jadi lawan tukar paling banyak dua.
	local swapRows: { TextButton } = {}
	local swapTargets: { number? } = { nil, nil }

	for index = 1, 2 do
		local row = Instance.new("TextButton")
		row.Name = string.format("Swap%d", index)
		row.TextSize = 14
		row.TextWrapped = true
		row.Font = Enum.Font.GothamBold
		row.TextColor3 = COLORS.text
		row.BackgroundColor3 = COLORS.background
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(0, 376 + (index - 1) * (LOBBY_ROW + LOBBY_GAP))
		row.Size = UDim2.new(1, 0, 0, LOBBY_ROW)
		row.Visible = false
		row.Parent = lobby

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = row

		row.Activated:Connect(function()
			local target = swapTargets[index]
			if target == nil then
				return
			end

			local requestSwap = handlers.onRequestSwap
			if requestSwap ~= nil then
				requestSwap(target)
			end
		end)

		swapRows[index] = row
	end

	local function refreshSwap(): ()
		local index = 0
		for _, other in Players:GetPlayers() do
			if other ~= player and index < #swapRows then
				index += 1
				local row = swapRows[index]
				row.Text = string.format("Tukar dengan %s", other.DisplayName)
				row.Visible = true
				swapTargets[index] = other.UserId
			end
		end

		for position = index + 1, #swapRows do
			swapRows[position].Visible = false
			swapTargets[position] = nil
		end

		swapTitle.Text = if index == 0
			then "Menunggu pemain lain"
			else "Tukar role dengan pemain lain"
	end

	local function refreshLobby(): ()
		lobbyCount.Text = string.format(
			"Pemain %d/%d - siap %d",
			state.lobbyPlayerCount or 0,
			state.lobbyMaxPlayers or 0,
			state.lobbyReadyCount or 0
		)

		local phase = state.lobbyPhase
		local left = state.lobbySecondsLeft
		if phase == "ready_check" then
			lobbyTimer.Text = string.format("Siap dalam %d dtk", math.max(0, left or 0))
		elseif phase == "waiting" then
			lobbyTimer.Text = string.format("Menunggu pemain: %d dtk", math.max(0, left or 0))
		else
			lobbyTimer.Text = ""
		end

		local chosen = state.lobbyPreferences
		for index, role in Roles.ALL do
			local row = roleRows[role]
			local order = if chosen ~= nil then table.find(chosen, role) else nil
			local picked = order ~= nil

			row.badge.TextColor3 = if picked then COLORS.background else COLORS.muted
			row.badge.BackgroundColor3 = if picked then COLORS.accent else COLORS.background
			row.badge.BackgroundTransparency = if picked then 0 else 1
			row.stroke.Transparency = if picked then 1 else 0
			row.name.TextColor3 = if picked then COLORS.accent else COLORS.text
			row.status.TextColor3 = if picked then COLORS.accent else COLORS.muted
			row.status.Text = if picked then string.format("Prioritas %d", order) else "Tersedia"
			row.button.BackgroundColor3 = if picked then COLORS.panel else COLORS.background

			-- Angka di badge tetap nomor baris, bukan prioritas: urutan baris
			-- tidak berubah saat pemain memilih, jadi angkanya tidak melompat.
			row.badge.Text = tostring(index)
		end

		lobbyPrefs.Text = if chosen == nil or #chosen == 0
			then "Belum ada pilihan. Ketuk sampai dua role."
			else "Pilihanmu: " .. table.concat(chosen, " lalu ")

		local ready = state.lobbyReady == true
		readyButton.Text = if ready then "Siap - ketuk untuk batal" else "Siap, mulai kasus"
		readyButton.BackgroundColor3 = if ready then COLORS.muted else COLORS.accent
		readyButton.TextColor3 = if ready then COLORS.panel else COLORS.background
	end

	-- `state` ditulis optimistis lalu ditimpa snapshot berikutnya. Tanpa itu,
	-- dua ketukan cepat sebelum balasan server datang dihitung dari pilihan
	-- lama, dan ketukan pertama hilang.
	local function chooseRole(role: string): ()
		local next_ = table.clone(state.lobbyPreferences or {})

		local position = table.find(next_, role)
		if position ~= nil then
			table.remove(next_, position)
		elseif #next_ >= Roles.PREFERENCE_COUNT then
			-- Dua preferensi sudah penuh. Menekan role ketiga tidak menggeser
			-- yang sudah dipilih -- pemain membatalkan dulu salah satunya.
			return
		else
			table.insert(next_, role)
		end

		state.lobbyPreferences = next_
		refreshLobby()

		local submit = handlers.onSubmitPreferences
		if submit ~= nil then
			submit(next_)
		end
	end

	for _, role in Roles.ALL do
		roleRows[role].button.Activated:Connect(function()
			chooseRole(role)
		end)
	end

	readyButton.Activated:Connect(function()
		-- Yang dikirim adalah keadaan yang DIINGINKAN, dibalik dari status
		-- terakhir -- ditulis optimistis dengan alasan yang sama seperti role.
		local wanted = state.lobbyReady ~= true
		state.lobbyReady = wanted
		refreshLobby()

		local setReady = handlers.onSetReady
		if setReady ~= nil then
			setReady(wanted)
		end
	end)

	local function updateLobby(payload: { [string]: any }): ()
		state.lobbyPhase = payload.phase
		state.lobbySecondsLeft = payload.seconds_left
		state.lobbyPlayerCount = payload.player_count
		state.lobbyReadyCount = payload.ready_count
		state.lobbyMaxPlayers = payload.max_players
		state.lobbyPreferences = if type(payload.preferences) == "table"
			then table.clone(payload.preferences)
			else nil
		state.lobbyReady = payload.ready

		lobby.Visible = true
		refreshSwap()
		refreshLobby()
	end

	local function hideLobby(): ()
		lobby.Visible = false
	end

	local wheel: Frame? = nil
	-- Role yang dipakai roda saat ini dibangun. Disimpan terpisah dari
	-- `state.role` supaya roda dibangun ULANG saat role baru tiba -- kalau
	-- tidak, pemain yang menekan Ping sebelum role-nya sampai akan memakai
	-- roda role default sepanjang sesi, dan frasa yang ia kirim ditolak server.
	local wheelRole: string? = nil

	local function update(next: State): ()
		state = next

		roleLabel.Text = state.role or "Menunggu role"
		phaseLabel.Text = state.phase or ""

		-- Tombol aksi hanya muncul untuk role yang memakainya (PRD §7):
		-- Report milik Searcher, Tandai milik Handler.
		reportButton.Visible = state.role == "Searcher"
		markButton.Visible = state.role == "Handler"

		refreshRows()
		refresh()
	end

	local function openPingWheel(): ()
		local role = state.role
		if role == nil then
			-- Server menolak ping dari pemain yang belum punya role
			-- (`PingPhrases.isValid` butuh role). Roda berisi frasa role
			-- default akan menyesatkan, jadi roda tidak dibuka.
			return
		end

		if wheel == nil or wheelRole ~= role then
			if wheel ~= nil then
				wheel:Destroy()
			end
			wheel = PingWheel.mount(gui, role, handlers.onPing or function() end)
			wheelRole = role
		end

		wheel.Visible = not wheel.Visible
	end

	local function openAccusationForm(): ()
		if not accusationButton.Visible then
			return
		end
		form.Visible = not form.Visible
	end

	local function showMarker(payload: { [string]: any }): ()
		-- Label datang dari server (nama node di data kasus). Client tidak
		-- menyusun teks targetnya sendiri, dan tidak menghitung arahnya.
		markerLabel.Text = tostring(payload.label or payload.target_id or "Target")
		bearingLabel.Text = string.format("Arah kompas: %s", compassText(payload.bearing))
		markerPanel.Visible = true

		-- Disimpan juga di state: tombol Report melaporkan benda yang sedang
		-- ditandai, dan marker adalah satu-satunya sumber tahu benda mana itu.
		state.marker = {
			target_id = payload.target_id,
			label = payload.label,
			bearing = payload.bearing,
		}
	end

	local function showReport(payload: { [string]: any }): ()
		-- PRD §7: "foto objek + tag lokasi otomatis terkirim. Tidak perlu
		-- mengetik." Selama belum ada aset foto, yang tampil adalah nama objek
		-- dan lokasi yang dihitung server dari data kasus.
		local where = tostring(payload.location or "-")
		local what = tostring(payload.label or payload.object_id or "objek")
		showToast(string.format("Report: %s (%s)", what, where))
	end

	local function showPing(fromRole: string, text: string): ()
		showToast(string.format("%s: %s", fromRole, text))
	end

	markButton.Activated:Connect(function()
		-- Handler menandai target yang diberikan arsipnya. Bila briefing belum
		-- sampai, tidak ada yang bisa ditandai.
		local target = state.briefingTarget
		if target == nil then
			showToast("Target dari arsip belum siap")
			return
		end

		local setTarget = handlers.onSetTarget
		if setTarget ~= nil then
			setTarget(target)
		end
	end)

	pingButton.Activated:Connect(openPingWheel)
	accusationButton.Activated:Connect(openAccusationForm)

	reportButton.Activated:Connect(function()
		-- Yang dilaporkan adalah benda yang sedang ditandai Handler. Searcher
		-- tidak memilih objek dari daftar: ia berdiri di depannya lalu menekan
		-- Report (PRD §7). Tanpa marker, tidak ada yang bisa dilaporkan, dan
		-- server akan menolaknya -- jadi tombolnya menjelaskan, bukan diam.
		local marker = state.marker
		local target: string? = nil
		if marker ~= nil then
			target = marker.target_id
		end

		if target == nil then
			showToast("Belum ada target dari Handler")
			return
		end

		local report = handlers.onReport
		if report ~= nil then
			report(target)
		end
	end)

	update(state)

	return {
		update = update,
		showRoleCard = function(briefing: { [string]: any })
			Hud.showRoleCard(gui, briefing)
		end,
		openPingWheel = openPingWheel,
		openAccusationForm = openAccusationForm,
		showMarker = showMarker,
		showReport = showReport,
		showPing = showPing,
		updateLobby = updateLobby,
		hideLobby = hideLobby,
	}
end

return Hud
