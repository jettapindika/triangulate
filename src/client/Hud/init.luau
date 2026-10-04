--!strict
-- HUD client (PRD §7, §9, §15).
--
-- Prinsip yang dipegang modul ini: client hanya MENAMPILKAN apa yang dikirim
-- server. Tidak ada perhitungan resep, tidak ada penilaian tuduhan, tidak ada
-- pengetahuan tentang varian kasus. Kalau sebuah nilai tidak datang lewat
-- remote, client tidak menampilkannya -- itu perilaku yang benar, bukan bug.
--
-- Tampilan yang dibangun di sini adalah yang bisa dibangun sekarang: Role Card
-- (PRD §9), status sesi, feedback tuduhan (PRD §5), ping wheel + toast
-- (PRD §7), Report Card (PRD §7), dan Target Marker dengan kompas (PRD §7).
-- Meja puzzle dan clue board punya modulnya sendiri -- `Table` (minggu 1, PRD
-- §17) dan `Board` (minggu 3) -- dan sengaja tidak digabung ke HUD: keduanya
-- menempati layar penuh, dan `Table` memindahkan kamera.

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
	-- PRD §7: marker yang dipasang Handler, terlihat di HUD Searcher.
	marker: { target_id: string?, label: string?, bearing: number? }?,
	-- PRD §7: target awal yang diberikan briefing ke Handler. Inilah yang
	-- dipasang sebagai marker, karena Handler tahu apa yang harus dicari
	-- sebelum Searcher tahu di mana mencarinya.
	briefingTarget: string?,
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
-- `handlers` membawa aksi yang boleh dilakukan client. Ping dan Report sama
-- bentuknya: client mengirim id, server memutuskan efeknya.
function Hud.mount(
	player: Player,
	state: State,
	handlers: {
		onPing: ((string) -> ())?,
		onReport: ((string) -> ())?,
		onSetTarget: ((string) -> ())?,
	}
): {
	update: (State) -> (),
	showRoleCard: ({ [string]: any }) -> (),
	openPingWheel: () -> (),
	showMarker: ({ [string]: any }) -> (),
	showReport: ({ [string]: any }) -> (),
	showPing: (string, string) -> (),
}
	local gui = Instance.new("ScreenGui")
	gui.Name = "TriangulateHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Bilah status kiri atas: role dan fase sesi.
	local status = panel(gui, "Status", UDim2.fromOffset(16, 16), UDim2.fromOffset(280, 96))

	local roleLabel = label(status, "Role", 20, COLORS.accent)
	roleLabel.Position = UDim2.new(0, 0, 0, 0)
	roleLabel.Size = UDim2.new(1, 0, 0, 26)

	local phaseLabel = label(status, "Phase", 15, COLORS.text)
	phaseLabel.Position = UDim2.fromOffset(0, 32)

	local accusationLabel = label(status, "Accusation", 15, COLORS.muted)
	accusationLabel.Position = UDim2.fromOffset(0, 56)

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
	local toast = panel(gui, "Toast", UDim2.fromOffset(16, 120), UDim2.fromOffset(320, 50))
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

		-- PRD §5: feedback salah hanya "X dari 3 benar", tanpa menyebut field
		-- mana. Client hanya bisa menampilkan angka yang dikirim server.
		local correct = state.correctCount
		local left = state.attemptsLeft
		if correct == nil or left == nil then
			accusationLabel.Text = ""
			return
		end

		if state.resolved then
			accusationLabel.Text = state.won and "Kasus terpecahkan!" or "Cold Case"
		elseif state.pendingConfirmation then
			accusationLabel.Text =
				string.format("%d dari 3 benar - butuh konfirmasi role lain", correct)
		else
			accusationLabel.Text =
				string.format("%d dari 3 benar - sisa %d percobaan", correct, left)
		end
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
		showMarker = showMarker,
		showReport = showReport,
		showPing = showPing,
	}
end

return Hud
