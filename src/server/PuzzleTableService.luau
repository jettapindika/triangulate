--!strict
-- State meja puzzle per sesi (PRD §4, §15, §17 minggu 1).
--
-- Pembagian tanggung jawab yang dipegang berkas ini:
--   * `shared/PuzzleTable.luau` -- geometri dan protokol drag, murni, tanpa
--     pengetahuan tentang kasus maupun role.
--   * berkas ini -- meja mana saja yang hidup di satu sesi, node bukti mana
--     yang menaunginya, siapa yang boleh menempatkan potongan, dan bagaimana
--     payload mentah dari client diubah menjadi keputusan.
--   * `init.server.luau` -- glue: membuat meja saat sesi mulai, memasang
--     handler remote, mengirim `puzzle_state`/`piece_placed`.
--
-- Kenapa modul terpisah, bukan langsung di `init.server.luau`: glue tidak bisa
-- diuji dari CLI (ia menyentuh `game`), sedangkan aturan di berkas ini --
-- penyaringan node per varian, gerbang role, validasi bentuk payload -- justru
-- yang paling mudah salah dan paling murah diuji. `tests/puzzle-table-service.spec.luau`
-- mengujinya lewat `lune` tanpa Studio.
--
-- Dependensi `PuzzleTable` masuk sebagai ARGUMEN, bukan `require` ke
-- `ReplicatedStorage`. Alasannya sama dengan `AccusationService` yang menerima
-- daftar field sebagai argumen: `require(game:GetService(...))` di dalam modul
-- membuat modul ini hanya bisa dijalankan di dalam Roblox, dan menghapus
-- justru alasan modul ini ada.
--
-- Catatan tipe: `PuzzleTable` dan `state` di bawah bertipe `any`. Keduanya
-- didefinisikan di modul yang tidak di-require di sini (itu konsekuensi
-- injeksi), dan `luau-analyze` mandiri tidak punya definisi API Roblox sehingga
-- glue yang memakainya juga tidak diperiksa. Yang menjaga kontrak ini bukan
-- analyzer, melainkan `tests/puzzle-table-service.spec.luau` dan
-- `tests/puzzle-table.spec.luau` yang memanggil jalur yang sama.

local PuzzleTableService = {}

-- Node bukti dari data kasus. Bentuknya sengaja lebih longgar daripada
-- `CaseSource.CaseNode` supaya modul ini tidak perlu ikut berubah saat loader
-- menambah field.
export type Node = {
	id: string,
	kind: string?,
	type: string?,
	puzzle: string?,
	-- Kunci yang harus dipegang Handler sebelum meja ini boleh disentuh
	-- (PRD §4: objek memberi kunci, kunci membuka potongan bukti).
	needs: { string }?,
	yields: string?,
	variants: { string }?,
}

export type Entry = {
	node_id: string,
	puzzle_id: string,
	puzzle_type: string,
	state: any,
	-- Kunci yang diminta node bukti ini. `nil` berarti meja terbuka sejak awal.
	-- Dipakai `isUnlocked`/`firstAvailable`; disimpan di sini supaya gerbangnya
	-- tidak perlu membaca ulang data kasus.
	needs: { string }?,
	-- Node Clue Card yang terbuka saat meja ini selesai (PRD §4: bukti
	-- `yields` sebuah Clue Card). Dipakai glue untuk mengirim ClueCard.
	yields: string?,
	solved: boolean,
}

export type Service = {
	PuzzleTable: any,
	entries: { [string]: Entry },
	-- Urutan pembuatan, supaya "meja pertama" deterministik dan tidak
	-- bergantung pada urutan iterasi tabel hash.
	order: { string },
}

function PuzzleTableService.new(PuzzleTable: any): Service
	return {
		PuzzleTable = PuzzleTable,
		entries = {},
		order = {},
	}
end

--[[
	Jenis sebuah node, menerima `kind` maupun `type`.

	`src/server/CaseSource.luau` menerima keduanya dengan alasan yang sama
	(`kind` untuk penulis kasus yang menghindari kata kunci), jadi aturan
	tersebut diulang di sini alih-alih diasumsikan sudah dinormalkan loader.
]]
function PuzzleTableService.kindOf(node: Node): string?
	if node.kind ~= nil then
		return node.kind
	end
	return node.type
end

--[[
	Apakah sebuah node hidup pada varian sesi ini (PRD §10: "tiap story case
	ditulis dengan 2-3 cabang solusi ... Seed server memilih cabang saat sesi
	dibuat").

	Node tanpa `variants` selalu hidup. Node DENGAN `variants` tetapi sesi tanpa
	varian dikenal dianggap mati: menganggapnya hidup akan menyerahkan ke client
	bukti milik cabang lain -- persis kebocoran yang dicegah `shared/Net.luau`.
]]
function PuzzleTableService.isActive(node: Node, variantId: string?): boolean
	local variants = node.variants
	if variants == nil or #variants == 0 then
		return true
	end
	if variantId == nil then
		return false
	end
	for _, id in variants do
		if id == variantId then
			return true
		end
	end
	return false
end

--[[
	Membangun meja untuk seluruh node bukti aktif yang punya `puzzle`.

	Mengembalikan `(daftar entry, daftar node yang dilewati)`. Node bertipe
	puzzle tak dikenal DILEWATI, bukan menggagalkan sesi: satu node bertipe baru
	di data kasus tidak boleh menjatuhkan sesi tiga pemain. Yang melewati
	dikembalikan ke pemanggil supaya glue bisa `warn` -- modul ini tidak
	mencetak apa pun supaya tetap bisa diuji dari CLI.

	`rng` adalah fungsi `() -> number` di [0,1), sama dengan yang diterima
	`PuzzleTable.forPuzzle`.
]]
function PuzzleTableService.build(
	service: Service,
	nodes: { Node },
	variantId: string?,
	width: number,
	height: number,
	rng: () -> number
): ({ Entry }, { string })
	local built: { Entry } = {}
	local skipped: { string } = {}

	for _, node in nodes do
		if PuzzleTableService.kindOf(node) ~= "evidence" then
			continue
		end

		local puzzleType = node.puzzle
		if puzzleType == nil then
			continue
		end

		if not PuzzleTableService.isActive(node, variantId) then
			continue
		end

		local state = service.PuzzleTable.forPuzzle(puzzleType, node.id, width, height, rng)
		if state == nil then
			table.insert(skipped, node.id)
			continue
		end

		table.insert(built, {
			node_id = node.id,
			puzzle_id = node.id,
			puzzle_type = puzzleType,
			state = state,
			needs = node.needs,
			yields = node.yields,
			solved = false,
		})
	end

	return built, skipped
end

--[[
	Mendaftarkan entry ke state sesi. Entry dengan node id yang sama menimpa
	yang lama tanpa menduplikasi urutan, supaya pemanggilan ulang tidak membuat
	`order` tumbuh.
]]
function PuzzleTableService.register(service: Service, entry: Entry): ()
	if service.entries[entry.node_id] == nil then
		table.insert(service.order, entry.node_id)
	end
	service.entries[entry.node_id] = entry
end

function PuzzleTableService.get(service: Service, nodeId: string): Entry?
	return service.entries[nodeId]
end

--[[
	Meja pertama yang belum selesai, atau `nil` bila semuanya selesai.

	Dipakai glue untuk memutuskan meja mana yang dikirim ke Handler saat sesi
	mulai. Iterasinya lewat `order`, bukan `pairs(entries)`, supaya meja yang
	dipilih tidak berubah-ubah antar sesi dengan data yang sama.
]]
function PuzzleTableService.firstUnsolved(service: Service): Entry?
	for _, nodeId in service.order do
		local entry = service.entries[nodeId]
		if entry ~= nil and not entry.solved then
			return entry
		end
	end
	return nil
end

--[[
	Apakah meja ini boleh disentuh dengan kunci yang dipegang sekarang.

	PRD §4: rantai bukti berjalan objek -> kunci -> bukti. Meja tanpa `needs`
	terbuka sejak awal (mis. bukti yang memang tidak terkunci); meja dengan
	`needs` menuntut SEMUA kuncinya sudah dipegang -- `needs` adalah daftar
	syarat, bukan pilihan.

	Meja yang tidak dikenal mengembalikan `false`: "tidak ada" tidak sama dengan
	"terbuka".
]]
function PuzzleTableService.isUnlocked(
	service: Service,
	nodeId: string,
	keysHeld: { [string]: boolean }
): boolean
	local entry = service.entries[nodeId]
	if entry == nil then
		return false
	end

	local needs = entry.needs
	if needs == nil or #needs == 0 then
		return true
	end

	for _, key in needs do
		if keysHeld[key] ~= true then
			return false
		end
	end
	return true
end

--[[
	Meja pertama yang belum selesai DAN sudah terbuka.

	Dipakai glue supaya Handler tidak dikirimi meja yang kuncinya belum ia
	pegang -- mengirimnya akan menampilkan bukti yang belum boleh dibuka, dan
	itu kebocoran urutan, bukan sekadar UX. Urutannya tetap `order`, jadi
	pilihannya deterministik.

	`firstUnsolved` tetap ada dan tetap dipakai untuk pertanyaan berbeda
	("apakah masih ada meja tersisa"), sehingga kedua pertanyaan tidak
	tercampur dalam satu fungsi.
]]
function PuzzleTableService.firstAvailable(
	service: Service,
	keysHeld: { [string]: boolean }
): Entry?
	for _, nodeId in service.order do
		local entry = service.entries[nodeId]
		if
			entry ~= nil
			and not entry.solved
			and PuzzleTableService.isUnlocked(service, nodeId, keysHeld)
		then
			return entry
		end
	end
	return nil
end

--[[
	Gerbang role untuk penempatan potongan.

	Handler adalah pemilik meja (PRD §3: "Handler merekonstruksi bukti di meja
	top-down"). Director ikut diizinkan karena PRD §8: pada mode 2 pemain,
	"puzzle manual bisa diambil alih Director jika mau lebih cepat". Searcher
	TIDAK diizinkan -- ia ada di lokasi, bukan di meja, dan membiarkannya
	menyentuh meja akan menghapus pemisahan informasi yang jadi inti desain.
]]
function PuzzleTableService.canPlace(role: string?): boolean
	return role == "Handler" or role == "Director"
end

--[[
	Membaca payload remote `PlacePiece` menjadi `(piece_id, u, v)`.

	Mengembalikan `nil` untuk payload cacat. Pemeriksaan bentuknya ketat dan
	sengaja tidak memaafkan: `u`/`v` harus `number` (bukan string yang bisa
	dikonversi), `piece_id` harus string tidak kosong. Nilai di luar [0,1] bukan
	cacat bentuk -- itu jari yang keluar meja, dan `PuzzleTable.applyDrop` yang
	menjepitnya.
]]
function PuzzleTableService.parsePlacement(payload: any): (string?, number?, number?)
	if type(payload) ~= "table" then
		return nil, nil, nil
	end

	local table_ = payload :: { [string]: any }
	local pieceId = table_.piece_id
	local u = table_.u
	local v = table_.v

	if type(pieceId) ~= "string" or pieceId == "" then
		return nil, nil, nil
	end
	if type(u) ~= "number" or type(v) ~= "number" then
		return nil, nil, nil
	end

	return pieceId, u, v
end

--[[
	Menjatuhkan satu potongan pada satu meja. Ini pembungkus `applyDrop` yang
	juga menandai meja selesai.

	Mengembalikan `(payload, solved)`; `payload` `nil` berarti node id tidak
	dikenal -- pemanggil yang memutuskan apakah itu perlu dicatat.
]]
function PuzzleTableService.place(
	service: Service,
	nodeId: string,
	pieceId: string,
	u: number,
	v: number
): ({ [string]: any }?, boolean)
	local entry = service.entries[nodeId]
	if entry == nil then
		return nil, false
	end

	local payload, solved = service.PuzzleTable.applyDrop(entry.state, pieceId, u, v)
	if solved then
		entry.solved = true
	end
	return payload, solved
end

--[[
	Kemajuan satu meja: `(potongan terpasang, total potongan)`.

	Dipakai telemetri (PRD §12 "Drop-off: quit di 5 menit pertama per role") dan
	untuk memutuskan meja mana yang dikirim berikutnya. Meja yang tidak dikenal
	mengembalikan `(0, 0)`, bukan error.
]]
function PuzzleTableService.progress(service: Service, nodeId: string): (number, number)
	local entry = service.entries[nodeId]
	if entry == nil then
		return 0, 0
	end

	local total = 0
	local placed = 0
	for _, piece in entry.state.pieces do
		total += 1
		if piece.placed then
			placed += 1
		end
	end
	return placed, total
end

return PuzzleTableService
