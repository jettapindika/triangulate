--!strict
-- Meja puzzle Handler (PRD §4, §15, §17 minggu 1).
--
-- Tiga hal yang dipegang berkas ini, dan satu hal yang sengaja TIDAK dipegang:
--
--   1. Kamera top-down Scriptable. Pemetaan titik layar ke bidang meja memakai
--      `PuzzleTable.rayPlaneY`, yang matematikanya sudah diuji di CLI
--      (`tests/puzzle-table.spec.luau`). Di sini hanya glue
--      `Camera:ViewportPointToRay`.
--   2. Selama jari menempel, potongan digerakkan LANGSUNG oleh jari. TIDAK ada
--      remote yang dikirim per frame. Satu pesan hanya saat jari dilepas --
--      ini "jalur B" yang diuji S0.2 di `docs/spike-minggu-0.md`.
--   3. Server yang memutuskan. Prediksi lokal memakai `PuzzleTable.resolveDrop`
--      yang sama dengan server, jadi koreksi seharusnya nol; bila tetap ada,
--      client menginterpolasi ke nilai otoritatif itu.
--
-- Yang TIDAK dipegang: penilaian benar/salah. Client tidak pernah menerima
-- `target` maupun `correct` (`PuzzleTable.clientPayload` membuang keduanya),
-- jadi ia memang tidak punya bahan untuk menilainya. Karena itu prediksi lokal
-- memakai `resolveDrop` -- yang hanya butuh geometri -- dan bukan `applyDrop`,
-- yang butuh `target`. Puzzle "selesai" ditentukan server, dan client hanya
-- tahu setelah `clue_card` datang.
--
-- Ruang koordinat yang dipakai:
--   * `u`, `v`  : ternormalisasi [0,1] terhadap bidang meja. INI yang dikirim
--                 ke server (`PlacePiece`).
--   * sel       : satuan internal `PuzzleTable`, x ke kanan dan y ke bawah.
--   * dunia     : stud. Meja adalah bidang horizontal di `PLANE_Y`, berpusat di
--                 `CENTER`, seluas `Config.TABLE_WIDTH` x `Config.TABLE_HEIGHT`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PuzzleTable = require(Shared.PuzzleTable)

local Table = {}

--[[
	Sheet gambar per bukti (docs/art/puzzle-style.md bagian 3 dan 6: satu sheet
	per bukti, grid maksimum 6x6, sel 170 px pada sheet 1024).

	`SHEET` masih placeholder karena aset belum ada -- pengunggahan texture butuh
	akun Creator, di luar lingkungan kerja ini. Selama placeholder, potongan
	tetap terlihat: tiap potongan diberi latar warna dan nomor region, supaya
	drag-and-snap bisa diverifikasi tanpa art. Ganti satu konstanta ini saat
	sheet pertama selesai; tidak ada bagian lain yang perlu berubah.
]]
Table.SHEET = "rbxassetid://0"
Table.SHEET_PIXELS = 1024
Table.SHEET_COLS = 6
Table.SHEET_ROWS = 6

--[[
	Geometri meja di dunia. Ukuran sisi meja datang dari `Config` (PRD §15),
	bukan ditulis ulang di sini.
]]
Table.PLANE_Y = 0
Table.CENTER = Vector3.new(0, 0, 0)
Table.CAMERA_HEIGHT = 24

--[[
	Radius genggam jari, dalam satuan sel.

	ASUMSI: jari di layar ponsel tidak menunjuk tepat ke tengah potongan, jadi
	radius genggam harus lebih longgar daripada `SNAP_TOLERANCE` (0,5 sel, yang
	berlaku untuk PELEPASAN). Nilai 1,2 sel berarti potongan tetangga masih bisa
	terambil bila jari meleset; playtest minggu 7 (PRD §17) yang menentukan
	angkanya. Yang penting di sini: menggenggam salah potongan hanya mengganggu,
	tidak merusak -- pelepasan tetap dinilai server.
]]
Table.GRAB_RADIUS = 1.2

-- Potongan di sisi client. Sengaja BUKAN `PuzzleTable.Piece`: tipe itu memuat
-- `target` dan `correct` yang tidak pernah menyeberang, jadi menyamakannya akan
-- menyiratkan client punya data yang justru dijamin tidak ada.
export type Piece = {
	id: string,
	region: number,
	-- Posisi yang DIGAMBAR sekarang. Selama jari menempel, ini posisi jari.
	pos: PuzzleTable.Vec2,
	-- Posisi sah terakhir menurut aturan snap -- cermin dari `piece.pos` di
	-- server. Dipakai sebagai `lastLegal` saat memprediksi drop yang meleset,
	-- supaya prediksi client sama persis dengan keputusan server dan potongan
	-- tidak perlu dikoreksi dua kali.
	legal: PuzzleTable.Vec2,
	placed: boolean,
}

export type Mount = {
	applyState: ({ [string]: any }) -> (),
	applyPlacement: ({ [string]: any }) -> (),
	destroy: () -> (),
}

--[[
	Memasang meja untuk satu pemain. Mengembalikan handle dengan `applyState`
	dan `applyPlacement`, yang dipanggil glue dari remote.

	`onDrop(nodeId, pieceId, u, v)` dipanggil TEPAT SEKALI per pelepasan jari.
	Glue yang mengubahnya menjadi `NetClient.placePiece`.

	Seluruh pembangunan GUI ditunda sampai `applyState` pertama. Alasannya peran:
	server hanya mengirim `puzzle_state` ke Handler dan Director
	(`Net.CLIENT_VIEWS`), jadi pemain lain tidak pernah membangun meja sama
	sekali -- dan tidak perlu tahu ia ada.
]]
function Table.mount(player: Player, onDrop: (string, string, number, number) -> ()): Mount
	local camera = workspace.CurrentCamera
	local width = Config.TABLE_WIDTH
	local height = Config.TABLE_HEIGHT
	local originX = Table.CENTER.X - width / 2
	local originZ = Table.CENTER.Z - height / 2

	local screen: ScreenGui? = nil
	local boardFrame: Frame? = nil
	local labels: { [string]: ImageLabel } = {}
	local board: PuzzleTable.Board? = nil
	local pieces: { Piece } = {}
	local nodeId: string? = nil

	-- Potongan yang sedang digenggam jari. Selama ini terisi, posisi potongan
	-- itu mengikuti jari dan pembaruan server untuknya diabaikan -- jari pemain
	-- selalu menang atas pesan yang datang terlambat.
	local held: string? = nil

	-- Koreksi otoritatif yang masih harus dianimasikan: `piece_id` -> posisi
	-- sasaran. Hanya berisi potongan yang dropnya DITOLAK server.
	local corrections: { [string]: PuzzleTable.Vec2 } = {}

	local previousCameraType = camera.CameraType

	local function worldOf(u: number, v: number): Vector3
		return Vector3.new(originX + u * width, Table.PLANE_Y, originZ + v * height)
	end

	-- Titik layar -> (u, v) ternormalisasi pada bidang meja. `nil` bila sinar
	-- tidak mengenai bidang (mis. kamera nyaris sejajar meja).
	local function pointerNormalized(point: Vector2): (number?, number?)
		local ray = camera:ViewportPointToRay(point.X, point.Y)
		local worldX, worldZ = PuzzleTable.rayPlaneY(
			ray.Origin.X,
			ray.Origin.Y,
			ray.Origin.Z,
			ray.Direction.X,
			ray.Direction.Y,
			ray.Direction.Z,
			Table.PLANE_Y
		)
		if worldX == nil or worldZ == nil then
			return nil, nil
		end
		return (worldX - originX) / width, (worldZ - originZ) / height
	end

	-- Proyeksi satu titik dunia ke offset piksel viewport.
	local function project(point: Vector3): Vector2?
		local viewport = camera:WorldToViewportPoint(point)
		if viewport.Z <= 0 then
			return nil
		end
		return Vector2.new(viewport.X, viewport.Y)
	end

	-- Satu potongan = satu `ImageLabel` yang menampilkan SEBAGIAN sheet lewat
	-- `ImageRectOffset`/`ImageRectSize` (docs/art/puzzle-style.md bagian 6).
	-- Keduanya diisi eksplisit: salah satu bernilai 0 akan menampilkan seluruh
	-- sheet, bukan potongan kosong.
	local function buildLabel(piece: Piece, parent: Instance): ImageLabel
		local cellPixels = math.floor(Table.SHEET_PIXELS / Table.SHEET_COLS)
		local cellRows = math.floor(Table.SHEET_PIXELS / Table.SHEET_ROWS)
		local zero = piece.region - 1

		local label = Instance.new("ImageLabel")
		label.Name = piece.id
		label.Image = Table.SHEET
		label.ImageRectOffset = Vector2.new(
			(zero % Table.SHEET_COLS) * cellPixels,
			math.floor(zero / Table.SHEET_COLS) * cellRows
		)
		label.ImageRectSize = Vector2.new(cellPixels, cellRows)
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.BackgroundColor3 = Color3.fromRGB(214, 168, 92)
		label.BackgroundTransparency = 0.15
		label.BorderSizePixel = 1
		label.BorderColor3 = Color3.fromRGB(24, 22, 20)
		label.Parent = parent

		-- Penanda region, hanya berguna selama `SHEET` masih placeholder.
		local number = Instance.new("TextLabel")
		number.Name = "Region"
		number.BackgroundTransparency = 1
		number.Size = UDim2.fromScale(1, 1)
		number.Font = Enum.Font.GothamBold
		number.TextScaled = true
		number.TextColor3 = Color3.fromRGB(24, 22, 20)
		number.Text = tostring(piece.region)
		number.Parent = label

		return label
	end

	local function findPiece(pieceId: string): Piece?
		for _, piece in pieces do
			if piece.id == pieceId then
				return piece
			end
		end
		return nil
	end

	local function clearGui(): ()
		for _, label in labels do
			label.Parent = nil
		end
		labels = {}
		if boardFrame ~= nil then
			boardFrame.Parent = nil
			boardFrame = nil
		end
	end

	local function rebuild(payload: { [string]: any }): ()
		local cols = payload.cols
		local rows = payload.rows
		if type(cols) ~= "number" or type(rows) ~= "number" then
			return
		end

		local gui = screen
		if gui == nil then
			return
		end

		board = PuzzleTable.newBoard(cols, rows, width, height)
		pieces = {}
		corrections = {}
		held = nil
		clearGui()

		local frame = Instance.new("Frame")
		frame.Name = "Board"
		frame.BackgroundColor3 = Color3.fromRGB(58, 52, 44)
		frame.BackgroundTransparency = 0.25
		frame.BorderSizePixel = 0
		frame.ZIndex = 0
		frame.Parent = gui
		boardFrame = frame

		local incoming = payload.pieces
		if type(incoming) ~= "table" then
			return
		end

		for _, raw in incoming do
			if type(raw) == "table" and type(raw.id) == "string" then
				local piece: Piece = {
					id = raw.id,
					region = raw.region or 1,
					pos = { x = raw.x or 0, y = raw.y or 0 },
					legal = { x = raw.x or 0, y = raw.y or 0 },
					placed = raw.placed == true,
				}
				table.insert(pieces, piece)
				labels[piece.id] = buildLabel(piece, frame)
			end
		end
	end

	--[[
		Memindahkan gambar potongan sesuai state lokal, lalu memproyeksikannya ke
		layar. Dijalankan tiap frame karena kamera bisa bergerak (mis. pemain
		mencubit untuk zoom pada implementasi berikutnya).
	]]
	local function render(dt: number): ()
		local currentBoard = board
		local frame = boardFrame
		if currentBoard == nil or frame == nil then
			return
		end

		-- Latar meja: diproyeksikan dari dua sudut bidang, jadi tetap benar
		-- walau kamera bergeser.
		local topLeft = project(worldOf(0, 0))
		local bottomRight = project(worldOf(1, 1))
		if topLeft ~= nil and bottomRight ~= nil then
			frame.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
			frame.Size = UDim2.fromOffset(bottomRight.X - topLeft.X, bottomRight.Y - topLeft.Y)
		end

		-- Ukuran potongan di layar mengikuti satu sel, dihitung dari proyeksi
		-- dua titik -- bukan dari asumsi tinggi kamera -- supaya tetap benar
		-- saat kamera diubah.
		local center = project(worldOf(0.5, 0.5))
		local cellEdge = project(worldOf(0.5 + 1 / currentBoard.cols, 0.5))
		local cellPixels = 64
		if center ~= nil and cellEdge ~= nil then
			cellPixels = math.max(8, (cellEdge - center).Magnitude)
		end

		for _, piece in pieces do
			local label = labels[piece.id]
			if label ~= nil then
				-- Koreksi otoritatif dianimasikan, tidak dipatahkan: PRD §15
				-- "interpolasi di client agar halus di mobile".
				local target = corrections[piece.id]
				if target ~= nil then
					piece.pos = PuzzleTable.interpolate(piece.pos, target, dt)
					if piece.pos.x == target.x and piece.pos.y == target.y then
						corrections[piece.id] = nil
					end
				end

				local normalized = PuzzleTable.pointToNormalized(currentBoard, piece.pos)
				local screenPoint = project(worldOf(normalized.x, normalized.y))
				if screenPoint ~= nil then
					label.Visible = true
					label.Size = UDim2.fromOffset(cellPixels, cellPixels)
					label.Position = UDim2.fromOffset(
						screenPoint.X - cellPixels / 2,
						screenPoint.Y - cellPixels / 2
					)
					label.ZIndex = piece.placed and 1 or 2
				else
					label.Visible = false
				end
			end
		end
	end

	local function grab(point: Vector2): ()
		local currentBoard = board
		if currentBoard == nil then
			return
		end

		local u, v = pointerNormalized(point)
		if u == nil or v == nil then
			return
		end

		local boardPoint = PuzzleTable.normalizedToPoint(currentBoard, u, v)
		local piece, distance = PuzzleTable.nearestPiece(pieces, boardPoint)
		if piece == nil or distance > Table.GRAB_RADIUS then
			return
		end

		held = piece.id
		corrections[piece.id] = nil
	end

	local function drag(point: Vector2): ()
		local currentBoard = board
		local pieceId = held
		if currentBoard == nil or pieceId == nil then
			return
		end

		local u, v = pointerNormalized(point)
		if u == nil or v == nil then
			return
		end

		local piece = findPiece(pieceId)
		if piece == nil then
			return
		end

		-- Gerakan mengikuti jari apa adanya, termasuk saat jari keluar meja:
		-- `resolveDrop` yang menjepit lewat `cellAt`, dan menjepit di sini juga
		-- akan membuat potongan tertinggal dari jari.
		piece.pos = PuzzleTable.normalizedToPoint(currentBoard, u, v)
	end

	local function release(point: Vector2): ()
		local currentBoard = board
		local pieceId = held
		local current = nodeId
		held = nil
		if currentBoard == nil or pieceId == nil or current == nil then
			return
		end

		local u, v = pointerNormalized(point)
		if u == nil or v == nil then
			return
		end

		local piece = findPiece(pieceId)
		if piece == nil then
			return
		end

		-- Prediksi lokal memakai aturan snap yang SAMA dengan server
		-- (`clampNormalized` lalu `resolveDrop`), jadi potongan sudah diam di
		-- tempat yang akan diputuskan server. `applyDrop` tidak dipakai di
		-- sini: ia butuh `piece.target`, yang justru tidak pernah dikirim ke
		-- client.
		local normalized = PuzzleTable.clampNormalized(currentBoard, u, v)
		if normalized == nil then
			return
		end

		local boardPoint = PuzzleTable.normalizedToPoint(currentBoard, normalized.x, normalized.y)
		local cell, snapped = PuzzleTable.resolveDrop(currentBoard, boardPoint, piece.legal)

		if cell == nil then
			-- Drop yang pasti ditolak tidak perlu dikirim: server akan
			-- menjawab hal yang sama, dan satu pesan yang tidak mengubah apa
			-- pun hanya menambah lalu lintas. Potongan dikembalikan ke posisi
			-- sah terakhirnya dengan animasi yang sama seperti koreksi server.
			corrections[pieceId] = snapped
			return
		end

		piece.pos = snapped
		piece.legal = snapped
		piece.placed = true
		onDrop(current, pieceId, u, v)
	end

	local connections: { RBXScriptConnection } = {}

	local function onInputBegan(input: InputObject): ()
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		grab(Vector2.new(input.Position.X, input.Position.Y))
	end

	local function onInputChanged(input: InputObject): ()
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseMovement
		then
			return
		end
		drag(Vector2.new(input.Position.X, input.Position.Y))
	end

	local function onInputEnded(input: InputObject): ()
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		release(Vector2.new(input.Position.X, input.Position.Y))
	end

	local function applyState(payload: { [string]: any }): ()
		if type(payload) ~= "table" then
			return
		end

		-- GUI dibangun saat meja pertama datang, bukan saat mount: pemain yang
		-- bukan Handler/Director tidak pernah menerima `puzzle_state`, jadi ia
		-- juga tidak pernah membangun apa pun.
		if screen == nil then
			local gui = Instance.new("ScreenGui")
			gui.Name = "TriangulateTable"
			gui.ResetOnSpawn = false
			-- Koordinat `WorldToViewportPoint` sudah relatif ke viewport, jadi
			-- inset GUI tidak boleh ditambahkan lagi.
			gui.IgnoreGuiInset = true
			gui.Parent = player:WaitForChild("PlayerGui")
			screen = gui
		end

		-- Meja baru (node bukti berikutnya) membangun ulang; meja yang sama
		-- hanya menyegarkan posisi.
		if nodeId ~= payload.puzzle_id or board == nil then
			nodeId = payload.puzzle_id
			rebuild(payload)
			return
		end

		local incoming = payload.pieces
		if type(incoming) ~= "table" then
			return
		end
		for _, raw in incoming do
			if type(raw) == "table" then
				local piece = findPiece(raw.id)
				if piece ~= nil and piece.id ~= held then
					piece.pos = { x = raw.x or piece.pos.x, y = raw.y or piece.pos.y }
					piece.legal = piece.pos
					piece.placed = raw.placed == true
				end
			end
		end
	end

	local function applyPlacement(payload: { [string]: any }): ()
		if type(payload) ~= "table" or type(payload.piece_id) ~= "string" then
			return
		end

		local piece = findPiece(payload.piece_id)
		if piece == nil or piece.id == held then
			return
		end

		local target = { x = payload.x or piece.pos.x, y = payload.y or piece.pos.y }
		if payload.accepted == true then
			-- Prediksi lokal memakai aturan snap yang sama, jadi ini seharusnya
			-- sudah sama persis; menyetel langsung membuat posisi potongan
			-- tidak pernah menyimpang dari keputusan server.
			piece.pos = target
			piece.legal = target
			corrections[piece.id] = nil
		else
			corrections[piece.id] = target
		end
		-- Baik diterima maupun ditolak, `x`,`y` dari server adalah posisi sah
		-- terakhir menurut server (`placementPayload` membaca `piece.pos`).
		-- Menyimpannya menjaga `lastLegal` prediksi lokal tetap sama dengan
		-- milik server.
		piece.legal = target
		piece.placed = payload.placed == true
	end

	-- Kamera top-down: tepat di atas pusat meja, menghadap lurus ke bawah.
	-- Vektor "atas" diberi eksplisit karena `CFrame.lookAt` dengan arah lurus ke
	-- bawah tidak punya acuan untuk memutarnya -- tanpa itu orientasi bisa
	-- berubah-ubah antar perangkat.
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(
		Table.CENTER + Vector3.new(0, Table.CAMERA_HEIGHT, 0),
		Table.CENTER,
		Vector3.new(0, 0, -1)
	)

	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
	table.insert(connections, RunService.RenderStepped:Connect(render))

	local function destroy(): ()
		for _, connection in connections do
			connection:Disconnect()
		end
		connections = {}
		clearGui()
		if screen ~= nil then
			screen:Destroy()
			screen = nil
		end
		board = nil
		pieces = {}
		camera.CameraType = previousCameraType
	end

	return {
		applyState = applyState,
		applyPlacement = applyPlacement,
		destroy = destroy,
	}
end

return Table
