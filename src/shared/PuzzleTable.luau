--!strict
-- Geometri meja puzzle dan protokol drag (PRD §4, §15, §17 minggu 1).
--
-- Modul ini MURNI: tidak menyentuh `game`, `Instance`, `CFrame`, `Vector3`,
-- maupun `Vector2`. Seluruh ruang meja dinyatakan sebagai angka biasa, dan
-- pemetaan ke dunia 3D dikerjakan glue di `src/client/` serta
-- `src/server/PuzzleTableService.luau`.
--
-- Kenapa dipisah begini: PRD §17 minggu 1 menuntut "meja puzzle top-down,
-- drag-and-snap" dengan gate "bisa selesai 1 puzzle di mobile". Yang paling
-- mudah salah pada drag-and-snap bukan renderingnya, melainkan matematikanya:
-- sel mana yang dimaksud jari, kapan sebuah potongan dianggap "menempel", dan
-- kapan server perlu mengoreksi. Semua itu bisa diuji dari CLI tanpa Studio --
-- dan memang diuji di `tests/puzzle-table.spec.luau`.
--
-- Ruang meja:
--   * satuan: "sel". Meja berukuran `cols` x `rows` sel.
--   * titik (0,0) adalah sudut kiri-atas meja; (cols, rows) sudut kanan-bawah.
--   * sumbu x ke kanan, sumbu y ke bawah -- sama seperti koordinat layar,
--     supaya tidak ada pembalikan sumbu yang tak terlihat saat menggambar.
--
-- Pemisahan yang menentukan (PRD §15, §18 "Exploit/bocor"):
--   `target` (sel tujuan potongan) dan `correct` HANYA ada di tabel ini dan
--   tidak pernah ikut `clientPayload`. Client menerima `region` (indeks
--   potongan pada gambar sumber, yang memang wajib untuk menggambar) dan posisi
--   sekarang; keputusan benar/salah tetap milik server.
--
--   Batas jujur dari pemisahan ini: pada jigsaw yang gambar jadinya utuh,
--   region ke-`i` memang HARUS berakhir di sel ke-`i` -- jadi client yang
--   dimodifikasi bisa menurunkan target dari `region`. Yang dilindungi bukan
--   itu, melainkan: (a) server tetap satu-satunya yang menilai `correct`
--   (PRD §15 "Pemeriksaan resep deduksi dan tuduhan hanya di server"), dan
--   (b) rahasia kasus -- `solution`, `culprit`, `motive`, `method`, resep
--   deduksi -- tidak punya jalur ke client sama sekali. Menyelesaikan puzzle
--   adalah gameplay yang dimaksud, bukan exploit; yang jadi exploit adalah
--   melompati gerbang deduksi, dan itu tetap di server. Catatan ini ada supaya
--   tidak ada yang membaca pemisahan ini sebagai jaminan yang lebih kuat
--   daripada kenyataannya.

local PuzzleTable = {}

--[[
	Ukuran grid maksimum untuk puzzle MVP.

	PRD §15 membatasi grid di mobile: "grid terbatas (misal maks 6x6)". Angka
	6 diambil dari PRD, bukan dipilih di sini. Grid 4x4 untuk `torn_doc` ada di
	data kasus, bukan di modul ini.
]]
PuzzleTable.MAX_GRID = 6

--[[
	Toleransi "dekat cukup" saat menjatuhkan potongan, dalam satuan sel.

	Ini yang menjawab catatan fallback di `docs/spike-minggu-0.md` S0.2:
	"melonggarkan validasi (server menerima penempatan 'dekat cukup' lalu
	menggeser potongan ke sel terdekat), bukan memindahkan keputusan ke client".
	Nilai 0.5 berarti jari boleh meleset setengah sel dan potongan tetap
	menempel ke sel terdekat.
]]
PuzzleTable.SNAP_TOLERANCE = 0.5

--[[
	Kecepatan interpolasi client, dalam "pangsa jarak per detik".

	PRD §15: "posisi potongan diatur server dan direplikasi (interpolasi di
	client agar halus di mobile)". Interpolasi dipakai HANYA saat client
	mengoreksi posisi otoritatif yang berbeda dari prediksi lokalnya; selama
	jari menempel, posisi digerakkan langsung oleh jari dan fungsi ini tidak
	dipanggil. Nilai besar = cepat menyusul tapi terasa patah; nilai kecil =
	halus tapi koreksi lama terlihat. 12 dipilih sebagai titik tengah yang
	membuat koreksi satu sel selesai dalam ~0,2 detik pada 60 fps.
]]
PuzzleTable.INTERPOLATION_RATE = 12

export type Vec2 = {
	x: number,
	y: number,
}

export type Cell = {
	col: number,
	row: number,
}

export type Board = {
	cols: number,
	rows: number,
	-- Ukuran meja dalam satuan dunia (stud). Dipakai glue untuk memetakan
	-- satuan sel ke geometri meja yang sebenarnya.
	width: number,
	height: number,
}

export type Piece = {
	id: string,
	-- Indeks potongan pada gambar sumber (dipakai `ImageRectOffset`).
	region: number,
	-- Sel tujuan potongan ini. SERVER-ONLY.
	target: Cell,
	-- Posisi sekarang, dalam satuan sel (titik tengah potongan).
	pos: Vec2,
	-- Sel tempat potongan duduk, atau nil bila belum ditempatkan.
	cell: Cell?,
	placed: boolean,
	-- Apakah potongan berada di sel yang benar. SERVER-ONLY.
	correct: boolean,
}

export type State = {
	puzzle_id: string,
	board: Board,
	pieces: { Piece },
}

--[[
	Membuat meja dari ukuran grid. `width`/`height` adalah ukuran dunia (stud)
	dan dipakai glue untuk memetakan hasil raycast ke satuan sel.
]]
function PuzzleTable.newBoard(cols: number, rows: number, width: number, height: number): Board
	assert(cols >= 1 and cols <= PuzzleTable.MAX_GRID, "cols di luar batas grid")
	assert(rows >= 1 and rows <= PuzzleTable.MAX_GRID, "rows di luar batas grid")
	assert(width > 0 and height > 0, "ukuran meja harus positif")

	return { cols = cols, rows = rows, width = width, height = height }
end

--[[
	Membuat meja yang SUDAH selesai: potongan ke-`i` duduk di sel ke-`i` dan
	region-nya juga ke-`i`. Pemanggil yang mengacaknya lewat `scatter`.

	Memisahkan "membuat meja" dari "mengacak potongan" disengaja: pengacakan
	bergantung pada RNG yang hanya ada di server, sedangkan pengujian geometri
	tidak butuh keacakan sama sekali.
]]
function PuzzleTable.newState(puzzle_id: string, board: Board, regions: { number }): State
	local pieces: { Piece } = {}
	for index, region in regions do
		local zero = index - 1
		local col = zero % board.cols
		local row = math.floor(zero / board.cols)
		table.insert(pieces, {
			id = string.format("%s:%d", puzzle_id, region),
			region = region,
			target = { col = col, row = row },
			pos = { x = col + 0.5, y = row + 0.5 },
			cell = { col = col, row = row },
			placed = true,
			correct = true,
		})
	end
	return { puzzle_id = puzzle_id, board = board, pieces = pieces }
end

--[[
	Menggeser seluruh potongan ke posisi acak di dalam meja supaya Handler harus
	merakitnya. `rng` mengembalikan angka di [0,1).

	Potongan diletakkan pada posisi pecahan yang sengaja menghindari pusat sel,
	sehingga tidak ada potongan yang kebetulan sudah benar saat sesi dimulai.
]]
function PuzzleTable.scatter(state: State, rng: () -> number): State
	for _, piece in state.pieces do
		piece.cell = nil
		piece.placed = false
		piece.correct = false
		piece.pos = {
			-- 0.25..0.75 di dalam sel: menjauh dari pusat, tetap di dalam meja.
			x = math.floor(rng() * state.board.cols) + 0.25 + rng() * 0.5,
			y = math.floor(rng() * state.board.rows) + 0.25 + rng() * 0.5,
		}
	end
	return state
end

--[[
	Sel yang paling dekat dengan sebuah titik, dan jaraknya dalam satuan sel.
	Sel di luar meja dijepit ke sel tepi terdekat -- jari yang keluar meja tidak
	boleh membuat potongan menghilang.
]]
function PuzzleTable.cellAt(board: Board, point: Vec2): (Cell, number)
	local col = math.clamp(math.floor(point.x), 0, board.cols - 1)
	local row = math.clamp(math.floor(point.y), 0, board.rows - 1)
	local distance = math.sqrt((point.x - (col + 0.5)) ^ 2 + (point.y - (row + 0.5)) ^ 2)
	return { col = col, row = row }, distance
end

--[[
	Menyelesaikan posisi jatuh potongan menjadi keputusan penempatan.

	Ini fungsi yang menentukan apakah sebuah drop "menempel": bila jarak titik
	jatuh ke pusat sel terdekat <= SNAP_TOLERANCE, potongan menempel ke sel itu;
	bila tidak, potongan kembali ke posisi terakhir yang sah (bukan mengambang
	di antara sel).

	Mengembalikan `(cell, pos)`. `cell` nil berarti drop ditolak.
]]
function PuzzleTable.resolveDrop(
	board: Board,
	point: Vec2,
	lastLegal: Vec2,
	tolerance: number?
): (Cell?, Vec2)
	local limit = tolerance or PuzzleTable.SNAP_TOLERANCE
	local cell, distance = PuzzleTable.cellAt(board, point)
	if distance <= limit then
		return cell, { x = cell.col + 0.5, y = cell.row + 0.5 }
	end
	return nil, lastLegal
end

--[[
	Menerapkan penempatan otoritatif ke meja. Mengembalikan `(state, accepted)`.

	`accepted` false berarti penempatan ditolak dan posisi potongan dikembalikan
	ke `lastLegal` -- client akan menginterpolasi ke sana. Ini jalur yang dipakai
	server saat sebuah drop tidak sah.

	Perhatikan: `accepted` berarti "penempatan sah secara aturan", bukan "benar
	sebagai solusi". `piece.correct` yang menjawab yang kedua, dan itu tetap di
	server.
]]
function PuzzleTable.place(state: State, pieceId: string, cell: Cell?, lastLegal: Vec2): (State, boolean)
	for _, piece in state.pieces do
		if piece.id == pieceId then
			if cell == nil then
				piece.placed = false
				piece.cell = nil
				piece.correct = false
				piece.pos = lastLegal
				return state, false
			end

			piece.cell = cell
			piece.placed = true
			piece.correct = piece.target.col == cell.col and piece.target.row == cell.row
			piece.pos = { x = cell.col + 0.5, y = cell.row + 0.5 }
			return state, true
		end
	end
	return state, false
end

--[[
	Apakah puzzle sudah selesai: seluruh potongan ada di sel yang benar.
]]
function PuzzleTable.isSolved(state: State): boolean
	if #state.pieces == 0 then
		return false
	end
	for _, piece in state.pieces do
		if not (piece.placed and piece.correct) then
			return false
		end
	end
	return true
end

--[[
	Jumlah potongan yang sudah benar. Dipakai untuk progres dan telemetri
	(PRD §12: "waktu ke clue pertama" dan penyelesaian).
]]
function PuzzleTable.solvedCount(state: State): number
	local count = 0
	for _, piece in state.pieces do
		if piece.placed and piece.correct then
			count += 1
		end
	end
	return count
end

--[[
	Interpolasi posisi menuju sasaran otoritatif.

	`dt` dalam detik. Bila sisa jarak sudah lebih kecil dari ambang henti,
	langsung menempel ke sasaran supaya tidak ada sisa gerakan yang tak terlihat.

	PRD §15: "interpolasi di client agar halus di mobile".
]]
function PuzzleTable.interpolate(from: Vec2, to: Vec2, dt: number, rate: number?): Vec2
	local speed = rate or PuzzleTable.INTERPOLATION_RATE
	local dx = to.x - from.x
	local dy = to.y - from.y
	local distance = math.sqrt(dx * dx + dy * dy)

	if distance <= 1e-4 then
		return { x = to.x, y = to.y }
	end

	-- Pangsa jarak yang ditempuh dalam `dt`, dibatasi 1 supaya tidak melompat
	-- melewati sasaran saat frame panjang (mis. hiccup 250 ms di mobile).
	local share = math.min(1, speed * dt)
	return {
		x = from.x + dx * share,
		y = from.y + dy * share,
	}
end

--[[
	Payload yang boleh menyeberang ke client untuk view `puzzle_state`.

	Bentuknya sengaja sempit: `region` (untuk menggambar potongan), posisi
	sekarang, dan `placed`. Tidak ada `target`, tidak ada `correct`, tidak ada
	daftar solusi. Uji `tests/puzzle-table.spec.luau` mengunci himpunan field ini
	supaya penambahan field di kemudian hari tidak diam-diam membocorkan target.
]]
function PuzzleTable.clientPayload(state: State): { [string]: any }
	local pieces: { { [string]: any } } = {}
	for _, piece in state.pieces do
		table.insert(pieces, {
			id = piece.id,
			region = piece.region,
			x = piece.pos.x,
			y = piece.pos.y,
			placed = piece.placed,
		})
	end
	return {
		puzzle_id = state.puzzle_id,
		cols = state.board.cols,
		rows = state.board.rows,
		pieces = pieces,
	}
end

--[[
	Payload hasil satu penempatan, dikirim setelah server memutuskan.

	`accepted` false berarti client harus menarik potongan kembali ke `x`,`y`
	yang ada di payload ini (posisi terakhir yang sah), bukan menyimpannya di
	tempat jari melepas.
]]
function PuzzleTable.placementPayload(
	state: State,
	pieceId: string,
	accepted: boolean
): { [string]: any }
	for _, piece in state.pieces do
		if piece.id == pieceId then
			return {
				piece_id = pieceId,
				x = piece.pos.x,
				y = piece.pos.y,
				placed = piece.placed,
				accepted = accepted,
			}
		end
	end
	return { piece_id = pieceId, x = 0, y = 0, placed = false, accepted = false }
end

--[[
	Memetakan titik pada bidang meja dari koordinat ternormalisasi [0,1] ke
	satuan sel.

	Ini yang menyeberang dari client: client melakukan raycast ke bidang meja
	dan mengirim posisi ternormalisasi, bukan sel. Alasannya kepemilikan:
	memilih sel dari posisi adalah keputusan, dan keputusan ada di server
	(PRD §15). Kalau client mengirim sel langsung, ia bisa mengirim sel mana pun
	tanpa melewati aturan snap.

	Nilai di luar [0,1] tidak dijepit di sini -- `cellAt` yang menjepit, supaya
	satu tempat saja yang menentukan perilaku di tepi meja.
]]
function PuzzleTable.normalizedToPoint(board: Board, u: number, v: number): Vec2
	return { x = u * board.cols, y = v * board.rows }
end

--[[
	Kebalikan `normalizedToPoint`: dari satuan sel ke [0,1]. Dipakai client
	untuk menggambar dan untuk uji bolak-balik.
]]
function PuzzleTable.pointToNormalized(board: Board, point: Vec2): Vec2
	return { x = point.x / board.cols, y = point.y / board.rows }
end

--[[
	Perpotongan sinar dengan bidang horizontal `y = planeY`, dalam angka biasa.

	Kenapa bukan `Vector3`: modul ini murni, dan matematika perpotongan sinar
	adalah tempat kesalahan tanda paling mudah terjadi pada kamera top-down
	(PRD §15: "raycast ke bidang meja"). Dengan angka biasa, ia bisa diuji dari
	CLI -- dan diuji di `tests/puzzle-table.spec.luau` untuk sinar dari atas,
	sinar miring, dan sinar sejajar bidang.

	Mengembalikan `(x, z)` pada bidang, atau `nil` bila sinar sejajar bidang
	atau bidang berada di belakang sinar.
]]
function PuzzleTable.rayPlaneY(
	originX: number,
	originY: number,
	originZ: number,
	dirX: number,
	dirY: number,
	dirZ: number,
	planeY: number
): (number?, number?)
	if math.abs(dirY) <= 1e-9 then
		-- Sinar sejajar bidang: tidak ada perpotongan tunggal.
		return nil, nil
	end

	local t = (planeY - originY) / dirY
	if t <= 0 then
		-- Bidang ada di belakang sinar; memakai `t` negatif akan menghasilkan
		-- titik di belakang kamera yang terlihat seperti jawaban yang sah.
		return nil, nil
	end

	return originX + dirX * t, originZ + dirZ * t
end

--[[
	Ukuran grid per tipe puzzle bukti (PRD §4: torn_doc, timeline, cipher).

	Kenapa di sini dan bukan di data kasus: `data/cases/*.json` belum punya
	tempat untuk menyatakan grid -- skema node di `schema/case.schema.json`
	(`additionalProperties: false`) hanya mengenal `puzzle`, dan mengubah skema
	itu bukan milik issue ini. Sampai skema punya field `grid` per node bukti,
	tipe puzzle adalah satu-satunya sumber yang tersedia, jadi pemetaannya
	tinggal di sini.

	`torn_doc` 4x4 = 16 potongan, angka yang sama dengan yang diukur S0.1 dan
	S0.2 di `docs/spike-minggu-0.md`. `timeline` dan `cipher` belum dirangkai
	end to end, jadi ukurannya `ASUMSI` awal yang menunggu playtest (PRD §19).
]]
local GRID_FOR_TYPE: { [string]: { cols: number, rows: number } } = {
	torn_doc = { cols = 4, rows = 4 },
	timeline = { cols = 4, rows = 2 },
	cipher = { cols = 3, rows = 3 },
}

--[[
	Ukuran grid untuk sebuah tipe puzzle. Mengembalikan `nil` bila tipe tidak
	dikenal -- pemanggil yang memutuskan apa artinya itu, bukan modul ini.
]]
function PuzzleTable.gridFor(puzzleType: string): (number?, number?)
	local grid = GRID_FOR_TYPE[puzzleType]
	if grid == nil then
		return nil, nil
	end
	return grid.cols, grid.rows
end

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

--[[
	Jalur masuk satu drop, dari sudut pandang SERVER.

	Ini komposisi `normalizedToPoint` -> `resolveDrop` -> `place`, yaitu seluruh
	keputusan penempatan dalam satu panggilan. Dipanggil server pada remote
	`PlacePiece`; client memanggil jalur yang sama untuk prediksi lokal, tetapi
	yang mengikat adalah hasil di server.

	`u` dan `v` adalah posisi jari ternormalisasi [0,1] terhadap bidang meja,
	BUKAN indeks sel. Ini disengaja: kalau client boleh mengirim sel, client
	boleh mengklaim penempatan di mana pun tanpa pernah menyentuh layar di
	sana. Dengan kirim posisi, server masih bisa menolak drop yang meleset lebih
	dari `SNAP_TOLERANCE`.

	Mengembalikan `(payload, solved)`; `payload.accepted` false berarti drop
	ditolak dan potongan kembali ke posisi sah terakhirnya. `solved` true berarti
	puzzle selesai SETELAH drop ini diterapkan.
]]
function PuzzleTable.applyDrop(
	state: State,
	pieceId: string,
	u: number,
	v: number,
	tolerance: number?
): ({ [string]: any }, boolean)
	if not (isFinite(u) and isFinite(v)) then
		-- NaN atau infinitas tidak boleh sampai ke `math.floor`: hasilnya bukan
		-- error, melainkan sel yang tampak sah. Drop seperti ini ditolak.
		return PuzzleTable.placementPayload(state, pieceId, false), false
	end

	local piece: Piece? = nil
	for _, candidate in state.pieces do
		if candidate.id == pieceId then
			piece = candidate
			break
		end
	end
	if piece == nil then
		return PuzzleTable.placementPayload(state, pieceId, false), false
	end

	-- Jari yang keluar bidang dijepit ke tepi, bukan ditolak: menyeret potongan
	-- melewati tepi meja adalah hal yang wajar dilakukan pemain.
	--
	-- Jepitannya adalah pusat sel tepi, bukan tepi bidang. Kalau dijepit ke tepi
	-- bidang, jari yang keluar meja selalu mendarat tepat di sudut sel -- jarak
	-- 0,707 sel, di luar toleransi -- sehingga menyeret ke luar justru SELALU
	-- ditolak. Menjepit ke pusat sel tepi membuat "keluar meja" berarti "sel
	-- tepi terdekat", yang itu yang dimaksud pemain.
	local halfCol = 0.5 / state.board.cols
	local halfRow = 0.5 / state.board.rows
	local clampedU = math.clamp(u, halfCol, 1 - halfCol)
	local clampedV = math.clamp(v, halfRow, 1 - halfRow)
	local point = PuzzleTable.normalizedToPoint(state.board, clampedU, clampedV)

	local lastLegal = piece.pos
	local cell = PuzzleTable.resolveDrop(state.board, point, lastLegal, tolerance)
	PuzzleTable.place(state, pieceId, cell, lastLegal)

	return PuzzleTable.placementPayload(state, pieceId, cell ~= nil), PuzzleTable.isSolved(state)
end

--[[
	Menghitung jumlah pesan remote yang dibutuhkan dua jalur drag untuk satu
	potongan yang digerakkan selama `frames` frame.

	Dipakai S0.2 (`docs/spike-minggu-0.md`) untuk menguji ambang "< 20
	pesan/detik saat drag aktif" TANPA perangkat mobile: jalur A mengirim satu
	pesan per frame, jalur B mengirim satu pesan per potongan yang dilepas.

	Ini hitungan protokol, bukan pengukuran runtime -- dan itu dinyatakan apa
	adanya saat dilaporkan.
]]
function PuzzleTable.remoteMessages(mode: string, frames: number, piecesDropped: number): number
	if mode == "per_frame" then
		return frames
	elseif mode == "on_release" then
		return piecesDropped
	end
	error(string.format("mode drag tidak dikenal: %s", tostring(mode)))
end

return PuzzleTable
