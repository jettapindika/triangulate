--!strict
-- Clue board Director (PRD §4, §5, §6, §7).
--
-- Isi layar ini:
--   * Clue Card yang sudah dimiliki Director, bisa di-drag satu ke atas yang
--     lain untuk mengirim kombinasi (PRD §4: "Director menggabungkan Clue
--     Card (drag kartu ke kartu), server memeriksa resep").
--   * Pernyataan saksi dan penandaan Kontradiksi (PRD §4).
--   * Peta dengan pinpoint hasil Deduksi (PRD §4, §7).
--   * Table Preview read-only meja Handler (PRD §7).
--   * Status gerbang form tuduhan (PRD §5).
--
-- Aturan yang dipegang modul ini, sama dengan `Hud` dan `Table`: client hanya
-- MENAMPILKAN. Tidak ada resep, tidak ada daftar Deduksi Kunci, tidak ada
-- `lie`/`contradicted_by`, dan tidak ada penilaian tuduhan. Kombinasi dikirim
-- sebagai daftar id Clue Card; server yang memutuskan hasilnya. Penandaan
-- kontradiksi dikirim sebagai nomor pernyataan; server yang memutuskan sah
-- atau tidak, dan mengembalikan alasannya.
--
-- Modul ini TIDAK menyentuh kamera. `Table` memindahkannya ke mode Scriptable
-- top-down karena Handler bekerja di meja; Director bekerja di UI 2D (PRD §3:
-- "Director UI 2D"), jadi clue board harus bisa hidup berdampingan dengan
-- kamera apa pun.
--
-- Aset: tidak ada. Peta di sini adalah skema, bukan minimap: data kasus belum
-- membawa koordinat dunia untuk objek (itu scope EXTA-55 / minggu 2). Karena
-- itu pinpoint digambar sebagai penanda berlabel di dalam panel, bukan
-- ditempelkan ke posisi 3D. Menggambar marker di tempat yang salah akan lebih
-- menyesatkan daripada tidak menggambarnya.

local UserInputService = game:GetService("UserInputService")

local Board = {}

local COLORS = {
	background = Color3.fromRGB(24, 22, 20),
	panel = Color3.fromRGB(38, 34, 30),
	card = Color3.fromRGB(52, 46, 40),
	selected = Color3.fromRGB(96, 78, 46),
	text = Color3.fromRGB(240, 236, 228),
	muted = Color3.fromRGB(168, 158, 146),
	accent = Color3.fromRGB(214, 168, 92),
	danger = Color3.fromRGB(196, 96, 84),
	good = Color3.fromRGB(122, 176, 118),
}

local GATE_CLOSED = "Form tuduhan: tertutup"
local GATE_OPEN = "Form tuduhan: terbuka"

export type ClueCard = { id: string, title: string?, summary: string?, source: string? }

export type Statement = { id: number, who: string, text: string }

export type Pinpoint = { id: string, label: string? }

export type TableProgress = {
	puzzle_id: string,
	puzzle_type: string?,
	placed: number,
	total: number,
	solved: boolean,
}

export type Gate = {
	deductionsDone: number?,
	deductionsRequired: number?,
	contradictionsMarked: number?,
	contradictionsRequired: number?,
	open: boolean?,
}

export type Hooks = {
	deduce: ({ string }) -> (),
	markContradiction: (number) -> (),
}

export type Mount = {
	applyClueCard: ({ [string]: any }) -> (),
	applyDeduction: ({ [string]: any }) -> (),
	applyStatements: ({ [string]: any }) -> (),
	applyContradictionResult: ({ [string]: any }) -> (),
	applyPinpoint: ({ [string]: any }) -> (),
	applyTablePreview: ({ [string]: any }) -> (),
	applySessionState: ({ [string]: any }) -> (),
	destroy: () -> (),
}

local function panel(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = COLORS.panel
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
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

--[[
	Kartu Clue yang bisa di-drag.

	Sentuh = pilih; sentuh kartu kedua = kirim kombinasi. Drag ke atas kartu
	lain juga mengirim kombinasi. Dua jalan itu disengaja: drag adalah cara yang
	diminta (PRD §4), tapi di layar kecil drag sering meleset, dan kombinasi
	yang tidak pernah terkirim berarti sesi yang mandek.
]]
local function makeCard(
	parent: Instance,
	order: number,
	card: ClueCard,
	onSelect: (string) -> ()
): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Card_" .. card.id
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = COLORS.card
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(148, 74)
	button.Position = UDim2.fromOffset((order - 1) % 3 * 156, math.floor((order - 1) / 3) * 82)
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local title = label(button, "Title", 14, COLORS.text)
	title.Position = UDim2.fromOffset(8, 6)
	title.Size = UDim2.new(1, -16, 0, 34)

	local summary = label(button, "Summary", 12, COLORS.muted)
	summary.Position = UDim2.fromOffset(8, 40)
	summary.Size = UDim2.new(1, -16, 0, 30)

	button.Activated:Connect(function()
		onSelect(card.id)
	end)

	return button
end

--[[
	Membangun clue board dan mengembalikan fungsi pembaru per jenis payload.

	`hooks.deduce` menerima daftar id Clue Card; `hooks.markContradiction`
	menerima nomor pernyataan. Keduanya hanya meneruskan ke `NetClient` -- modul
	ini tidak memutuskan apa pun.
]]
function Board.mount(player: Player, hooks: Hooks): Mount
	local gui = Instance.new("ScreenGui")
	gui.Name = "TriangulateBoard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Header: status gerbang (PRD §5) dan pesan hasil aksi terakhir.
	local header = panel(gui, "Header", UDim2.new(0, 16, 0, 16), UDim2.new(1, -32, 0, 52))
	local gateLabel = label(header, "Gate", 16, COLORS.accent)
	gateLabel.Position = UDim2.fromOffset(0, 0)
	gateLabel.Size = UDim2.new(1, 0, 0, 20)

	local messageLabel = label(header, "Message", 13, COLORS.muted)
	messageLabel.Position = UDim2.fromOffset(0, 22)
	messageLabel.Size = UDim2.new(1, 0, 0, 18)

	-- Kiri atas: Clue Card.
	local cardPanel = panel(gui, "Cards", UDim2.new(0, 16, 0, 80), UDim2.new(0.6, -24, 0.42, -92))
	label(cardPanel, "Title", 15, COLORS.accent).Text = "Clue Card"
	local cardArea = Instance.new("Frame")
	cardArea.Name = "Area"
	cardArea.BackgroundTransparency = 1
	cardArea.Position = UDim2.fromOffset(0, 26)
	cardArea.Size = UDim2.new(1, 0, 1, -26)
	cardArea.Parent = cardPanel

	-- Kanan atas: pernyataan saksi.
	local statementPanel =
		panel(gui, "Statements", UDim2.new(0.6, 8, 0, 80), UDim2.new(0.4, -24, 0.42, -92))
	label(statementPanel, "Title", 15, COLORS.accent).Text = "Pernyataan saksi"
	local statementArea = Instance.new("Frame")
	statementArea.Name = "Area"
	statementArea.BackgroundTransparency = 1
	statementArea.Position = UDim2.fromOffset(0, 26)
	statementArea.Size = UDim2.new(1, 0, 1, -26)
	statementArea.Parent = statementPanel

	-- Kiri bawah: peta + pinpoint (PRD §4, §7).
	local mapPanel = panel(gui, "Map", UDim2.new(0, 16, 0.42, 88), UDim2.new(0.6, -24, 0.58, -104))
	label(mapPanel, "Title", 15, COLORS.accent).Text = "Peta & pinpoint"
	local mapArea = Instance.new("Frame")
	mapArea.Name = "Area"
	mapArea.BackgroundTransparency = 1
	mapArea.Position = UDim2.fromOffset(0, 26)
	mapArea.Size = UDim2.new(1, 0, 1, -26)
	mapArea.Parent = mapPanel

	-- Kanan bawah: Table Preview (PRD §7).
	local previewPanel =
		panel(gui, "Preview", UDim2.new(0.6, 8, 0.42, 88), UDim2.new(0.4, -24, 0.58, -104))
	label(previewPanel, "Title", 15, COLORS.accent).Text = "Meja Handler"
	local previewArea = Instance.new("Frame")
	previewArea.Name = "Area"
	previewArea.BackgroundTransparency = 1
	previewArea.Position = UDim2.fromOffset(0, 26)
	previewArea.Size = UDim2.new(1, 0, 1, -26)
	previewArea.Parent = previewPanel

	-- State lokal. Tidak satu pun dari nilai ini adalah kebenaran permainan --
	-- semuanya salinan tampilan dari payload server.
	local cards: { ClueCard } = {}
	local cardFrames: { [string]: TextButton } = {}
	local selected: { string } = {}
	local statements: { Statement } = {}
	local statementFrames: { [number]: TextButton } = {}
	local marked: { [number]: boolean } = {}
	local pinpoints: { Pinpoint } = {}
	local dragging: { id: string, frame: TextButton, offset: Vector2, origin: UDim2 }? = nil
	local connections: { RBXScriptConnection } = {}

	local function setMessage(text: string, color: Color3?): ()
		messageLabel.Text = text
		messageLabel.TextColor3 = color or COLORS.muted
	end

	local function clearArea(area: Instance): ()
		for _, child in area:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function renderGate(gate: Gate): ()
		if gate.open == nil then
			gateLabel.Text = GATE_CLOSED
			return
		end

		local done = gate.deductionsDone or 0
		local need = gate.deductionsRequired or 0
		local contradictions = gate.contradictionsMarked or 0
		local contradictionsNeed = gate.contradictionsRequired or 0

		gateLabel.Text = string.format(
			"%s - deduksi kunci %d/%d, kontradiksi %d/%d",
			if gate.open then GATE_OPEN else GATE_CLOSED,
			done,
			need,
			contradictions,
			contradictionsNeed
		)
		gateLabel.TextColor3 = if gate.open then COLORS.good else COLORS.accent
	end

	local function clearSelection(): ()
		for _, id in selected do
			local frame = cardFrames[id]
			if frame ~= nil then
				frame.BackgroundColor3 = COLORS.card
			end
		end
		selected = {}
	end

	-- Mengirim kombinasi yang sedang terpilih, lalu membersihkan pilihan.
	-- Server yang memutuskan hasilnya; client hanya menunggu `DeductionResult`.
	local function submitSelection(): ()
		if #selected < 2 then
			return
		end

		local ids = { selected[1], selected[2] }
		clearSelection()
		setMessage(string.format("Menggabungkan %s + %s...", ids[1], ids[2]))
		hooks.deduce(ids)
	end

	local function selectCard(id: string): ()
		for index, chosen in selected do
			if chosen == id then
				table.remove(selected, index)
				local frame = cardFrames[id]
				if frame ~= nil then
					frame.BackgroundColor3 = COLORS.card
				end
				return
			end
		end

		if #selected >= 2 then
			clearSelection()
		end

		table.insert(selected, id)
		local frame = cardFrames[id]
		if frame ~= nil then
			frame.BackgroundColor3 = COLORS.selected
		end

		if #selected == 2 then
			submitSelection()
		end
	end

	local function renderCards(): ()
		clearArea(cardArea)
		cardFrames = {}
		selected = {}

		for order, card in cards do
			local button = makeCard(cardArea, order, card, selectCard)
			cardFrames[card.id] = button

			-- Drag kartu ke kartu (PRD §4). Titik sentuh pertama disimpan
			-- sebagai offset supaya kartu tidak melompat ke bawah jari.
			connections[#connections + 1] = button.InputBegan:Connect(function(input: InputObject)
				if
					input.UserInputType ~= Enum.UserInputType.Touch
					and input.UserInputType ~= Enum.UserInputType.MouseButton1
				then
					return
				end
				dragging = {
					id = card.id,
					frame = button,
					offset = Vector2.new(input.Position.X, input.Position.Y)
						- button.AbsolutePosition,
					origin = button.Position,
				}
				button.ZIndex = 5
			end)
		end
	end

	local function dropAt(position: Vector2): ()
		local current = dragging
		if current == nil then
			return
		end
		dragging = nil
		current.frame.ZIndex = 1

		for id, frame in cardFrames do
			if id ~= current.id then
				local topLeft = frame.AbsolutePosition
				local size = frame.AbsoluteSize
				local inside = position.X >= topLeft.X
					and position.X <= topLeft.X + size.X
					and position.Y >= topLeft.Y
					and position.Y <= topLeft.Y + size.Y
				if inside then
					-- Drop di atas kartu lain = kombinasi kedua kartu itu.
					clearSelection()
					selected = { current.id, id }
					current.frame.Position = current.origin
					submitSelection()
					return
				end
			end
		end

		-- Tidak jatuh di kartu mana pun: kembalikan kartu ke tempatnya. Drop
		-- yang meleset tidak boleh menghapus pilihan yang sudah ada.
		current.frame.Position = current.origin
	end

	local function renderStatements(): ()
		clearArea(statementArea)
		statementFrames = {}

		for order, statement in statements do
			local button = Instance.new("TextButton")
			button.Name = "Statement_" .. tostring(statement.id)
			button.Text = string.format("%s: %s", statement.who, statement.text)
			button.TextSize = 12
			button.Font = Enum.Font.GothamMedium
			button.TextColor3 = COLORS.text
			button.TextWrapped = true
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.TextYAlignment = Enum.TextYAlignment.Top
			button.AutoButtonColor = false
			button.BackgroundColor3 = COLORS.card
			button.BorderSizePixel = 0
			button.Size = UDim2.new(1, 0, 0, 62)
			button.Position = UDim2.fromOffset(0, (order - 1) * 68)
			button.Parent = statementArea

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = button

			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 6)
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			padding.Parent = button

			button.Activated:Connect(function()
				if marked[statement.id] then
					return
				end
				hooks.markContradiction(statement.id)
			end)

			if marked[statement.id] then
				button.BackgroundColor3 = COLORS.good
			end

			statementFrames[statement.id] = button
		end
	end

	local function renderPinpoints(): ()
		clearArea(mapArea)

		if #pinpoints == 0 then
			local empty = label(mapArea, "Empty", 12, COLORS.muted)
			empty.Text = "Belum ada pinpoint. Selesaikan Deduksi untuk membukanya."
			empty.Position = UDim2.fromOffset(0, 0)
			return
		end

		for order, pinpoint in pinpoints do
			local chip = Instance.new("TextLabel")
			chip.Name = "Pinpoint_" .. pinpoint.id
			chip.Text = string.format("* %s", pinpoint.label or pinpoint.id)
			chip.TextSize = 13
			chip.Font = Enum.Font.GothamMedium
			chip.TextColor3 = COLORS.text
			chip.TextXAlignment = Enum.TextXAlignment.Left
			chip.BackgroundColor3 = COLORS.card
			chip.BorderSizePixel = 0
			chip.Size = UDim2.new(1, 0, 0, 28)
			chip.Position = UDim2.fromOffset(0, (order - 1) * 34)
			chip.Parent = mapArea

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = chip
		end
	end

	local function renderPreview(entries: { TableProgress }): ()
		clearArea(previewArea)

		if #entries == 0 then
			local empty = label(previewArea, "Empty", 12, COLORS.muted)
			empty.Text = "Belum ada meja aktif."
			empty.Position = UDim2.fromOffset(0, 0)
			return
		end

		for order, entry in entries do
			local row = Instance.new("Frame")
			row.Name = "Row_" .. entry.puzzle_id
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 34)
			row.Position = UDim2.fromOffset(0, (order - 1) * 40)
			row.Parent = previewArea

			local name = label(row, "Name", 12, COLORS.text)
			name.Text = string.format("%s (%s)", entry.puzzle_id, entry.puzzle_type or "?")
			name.Position = UDim2.fromOffset(0, 0)
			name.Size = UDim2.new(1, 0, 0, 16)

			local track = Instance.new("Frame")
			track.Name = "Track"
			track.BackgroundColor3 = COLORS.card
			track.BorderSizePixel = 0
			track.Position = UDim2.fromOffset(0, 20)
			track.Size = UDim2.new(1, 0, 0, 10)
			track.Parent = row

			local trackCorner = Instance.new("UICorner")
			trackCorner.CornerRadius = UDim.new(1, 0)
			trackCorner.Parent = track

			local fraction = if entry.total > 0 then entry.placed / entry.total else 0
			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.BackgroundColor3 = if entry.solved then COLORS.good else COLORS.accent
			fill.BorderSizePixel = 0
			fill.Size = UDim2.new(fraction, 0, 1, 0)
			fill.Parent = track

			local fillCorner = Instance.new("UICorner")
			fillCorner.CornerRadius = UDim.new(1, 0)
			fillCorner.Parent = fill

			local count = label(row, "Count", 11, COLORS.muted)
			count.Text = string.format("%d/%d", entry.placed, entry.total)
			count.Position = UDim2.fromOffset(0, 20)
			count.Size = UDim2.new(1, -4, 0, 12)
			count.TextXAlignment = Enum.TextXAlignment.Right
		end
	end

	-- Input drag ditangani di tingkat layar, bukan per kartu: kartu yang sedang
	-- di-drag bergerak, sehingga hit-test saat jari diangkat harus dilakukan
	-- terhadap posisi kartu LAIN, dan itu tidak bisa dilakukan dari dalam kartu
	-- yang bergerak.
	connections[#connections + 1] = UserInputService.InputChanged:Connect(
		function(input: InputObject)
			local current = dragging
			if current == nil then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.Touch
				and input.UserInputType ~= Enum.UserInputType.MouseMovement
			then
				return
			end

			local parent = current.frame.Parent
			if parent == nil or not parent:IsA("GuiObject") then
				return
			end

			local position = Vector2.new(input.Position.X, input.Position.Y)
			local local_ = position - parent.AbsolutePosition - current.offset
			current.frame.Position = UDim2.fromOffset(local_.X, local_.Y)
		end
	)

	connections[#connections + 1] = UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragging == nil then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end

		-- Jari bisa saja sudah lepas di luar layar; posisi terakhir dari
		-- `InputEnded` tetap yang paling dekat dengan pelepasan.
		dropAt(Vector2.new(input.Position.X, input.Position.Y))
	end)

	return {
		-- PRD §4: Clue Card yang sudah dimiliki Director. Satu kartu bisa
		-- datang lebih dari sekali (server mengirim ulang setelah meja
		-- berikutnya); id yang sama tidak digandakan.
		applyClueCard = function(payload: { [string]: any }): ()
			if type(payload.id) ~= "string" then
				return
			end
			for _, card in cards do
				if card.id == payload.id then
					return
				end
			end
			table.insert(cards, {
				id = payload.id,
				title = payload.title,
				summary = payload.summary,
				source = payload.source,
			})
			renderCards()
		end,

		-- PRD §4: hasil kombinasi. `reason` hanya ada saat kombinasi ditolak.
		applyDeduction = function(payload: { [string]: any }): ()
			if type(payload.reason) == "string" and payload.reason ~= "" then
				setMessage(payload.reason, COLORS.danger)
				return
			end

			if type(payload.id) == "string" then
				setMessage(string.format("Deduksi terbuka: %s", payload.id), COLORS.good)
			end
		end,

		-- PRD §4: pernyataan saksi, tanpa `lie` dan `contradicted_by`.
		applyStatements = function(payload: { [string]: any }): ()
			if type(payload.statements) ~= "table" then
				return
			end
			statements = {}
			for _, raw in payload.statements do
				if type(raw) == "table" and type(raw.id) == "number" then
					table.insert(statements, {
						id = raw.id,
						who = tostring(raw.who),
						text = tostring(raw.text),
					})
				end
			end
			renderStatements()
		end,

		-- PRD §4: hasil penandaan kontradiksi. Ditolak = alasan ditampilkan apa
		-- adanya; client tidak menyimpulkan apa pun dari penolakan itu.
		applyContradictionResult = function(payload: { [string]: any }): ()
			if payload.accepted == true then
				local id = payload.statement_id
				if type(id) == "number" then
					marked[id] = true
					local frame = statementFrames[id]
					if frame ~= nil then
						frame.BackgroundColor3 = COLORS.good
					end
				end
				setMessage("Kontradiksi ditandai.", COLORS.good)
			else
				setMessage(tostring(payload.reason or "Kontradiksi ditolak."), COLORS.danger)
			end

			renderGate({
				deductionsDone = payload.deductions_done,
				deductionsRequired = payload.key_deductions_required,
				contradictionsMarked = payload.marked_count,
				contradictionsRequired = payload.contradictions_required,
				open = payload.gate_open,
			})
		end,

		-- PRD §7: pinpoint yang terlihat juga oleh Searcher.
		applyPinpoint = function(payload: { [string]: any }): ()
			if type(payload.id) ~= "string" then
				return
			end
			for _, pinpoint in pinpoints do
				if pinpoint.id == payload.id then
					return
				end
			end
			table.insert(pinpoints, { id = payload.id, label = payload.label })
			renderPinpoints()
		end,

		-- PRD §7: Table Preview read-only.
		applyTablePreview = function(payload: { [string]: any }): ()
			if type(payload.entries) ~= "table" then
				return
			end
			local entries: { TableProgress } = {}
			for _, raw in payload.entries do
				if type(raw) == "table" and type(raw.puzzle_id) == "string" then
					table.insert(entries, {
						puzzle_id = raw.puzzle_id,
						puzzle_type = raw.puzzle_type,
						placed = tonumber(raw.placed) or 0,
						total = tonumber(raw.total) or 0,
						solved = raw.solved == true,
					})
				end
			end
			renderPreview(entries)
		end,

		-- PRD §5: status gerbang form tuduhan.
		applySessionState = function(payload: { [string]: any }): ()
			if payload.gate_open == nil and payload.deductions_done == nil then
				return
			end
			renderGate({
				deductionsDone = payload.deductions_done,
				deductionsRequired = payload.key_deductions_required,
				contradictionsMarked = payload.contradictions_marked,
				contradictionsRequired = payload.contradictions_required,
				open = payload.gate_open,
			})
		end,

		destroy = function(): ()
			for _, connection in connections do
				connection:Disconnect()
			end
			connections = {}
			dragging = nil
			gui:Destroy()
		end,
	}
end

return Board
