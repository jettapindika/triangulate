--!strict
-- HUD client (PRD §7, §9, §15).
--
-- Prinsip yang dipegang modul ini: client hanya MENAMPILKAN apa yang dikirim
-- server. Tidak ada perhitungan resep, tidak ada penilaian tuduhan, tidak ada
-- pengetahuan tentang varian kasus. Kalau sebuah nilai tidak datang lewat
-- remote, client tidak menampilkannya -- itu perilaku yang benar, bukan bug.
--
-- Tampilan yang dibangun di sini adalah yang bisa dibangun sekarang: Role Card
-- (PRD §9), status sesi, feedback tuduhan (PRD §5), dan ping wheel (PRD §7).
-- Meja puzzle dan clue board adalah scope minggu 1-3 (PRD §17) dan belum ada
-- di sini.

local PingWheel = require(script.PingWheel)

local Hud = {}

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
}

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
function Hud.mount(
	player: Player,
	state: State,
	onPing: (string) -> ()
): {
	update: (State) -> (),
	showRoleCard: ({ [string]: any }) -> (),
	openPingWheel: () -> (),
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
	pingButton.Size = UDim2.fromOffset(96, 96)
	pingButton.Parent = gui

	local pingCorner = Instance.new("UICorner")
	pingCorner.CornerRadius = UDim.new(1, 0)
	pingCorner.Parent = pingButton

	local wheel: Frame? = nil

	local function update(next: State): ()
		state = next

		roleLabel.Text = state.role or "Menunggu role"
		phaseLabel.Text = state.phase or ""

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
		if wheel == nil then
			local role = state.role or "Searcher"
			wheel = PingWheel.mount(gui, role, onPing)
		end
		if wheel ~= nil then
			wheel.Visible = not wheel.Visible
		end
	end

	pingButton.Activated:Connect(openPingWheel)

	update(state)

	return {
		update = update,
		showRoleCard = function(briefing: { [string]: any })
			Hud.showRoleCard(gui, briefing)
		end,
		openPingWheel = openPingWheel,
	}
end

return Hud
