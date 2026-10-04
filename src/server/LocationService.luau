--!strict
-- Lokasi pertama: objek yang bisa diperiksa, mini-aksi Searcher, dan gerbang
-- kunci (PRD §4, §6, §15, §17 minggu 2).
--
-- Pembagian tanggung jawab:
--   * berkas ini -- aturan: objek mana yang ada di lokasi, mini-aksi apa yang
--     dibutuhkan, kapan sebuah pemeriksaan sah, dan kunci apa yang diberikan.
--   * `init.server.luau` -- glue: membuat Part di `Workspace`, memasang handler
--     remote, mengirim balasan.
--
-- Kenapa modul terpisah, bukan langsung di glue: glue menyentuh `game` dan
-- tidak bisa dijalankan dari CLI, sedangkan keputusan di berkas ini -- "boleh
-- diperiksa atau tidak" -- justru satu-satunya yang berdiri antara client dan
-- kunci kasus. `tests/location.spec.luau` mengujinya lewat `lune` tanpa Studio.
--
-- Jam masuk sebagai ARGUMEN, bukan `os.clock()` di dalam. Alasannya sama
-- dengan `PuzzleTableService` yang menerima `PuzzleTable` sebagai argumen:
-- durasi "tahan" tidak bisa diuji kalau satu-satunya cara mengujinya adalah
-- menunggu detik nyata.
--
-- PRD §15: "Client hanya menerima data sesuai role." Modul ini tidak
-- memproyeksikan apa pun ke client; ia memutuskan, dan glue yang memproyeksikan
-- lewat `shared/Net.luau`. Kunci (`gives_key`) hanya sampai ke Handler.

local LocationService = {}

export type Action = {
	id: string,
	label: string,
	-- Detik aksi harus ditahan. 0 berarti sekali sentuh.
	hold_seconds: number,
}

export type Point = {
	x: number,
	z: number,
}

export type WorldObject = {
	id: string,
	label: string,
	-- "object" = objek rantai bukti, memberi kunci. "ambient" = properti
	-- opsional di lokasi, tidak memberi kunci (PRD §6).
	kind: string,
	action: string,
	position: Point,
	gives_key: string?,
	-- PRD §4: node yang hanya terbuka setelah deduksi (mis. `obj_ledger`) ada
	-- secara fisik, tetapi belum bisa dicapai. Objek seperti itu tetap dicatat
	-- supaya bisa ditampilkan sebagai "belum bisa dijangkau", bukan hilang.
	reachable: boolean,
	-- Deduksi yang membuka objek ini lewat `unlocks`. `nil` berarti tidak
	-- bergerbang deduksi. Gerbangnya sendiri diperiksa `isInspectable` --
	-- sengaja TIDAK disimpan sebagai boolean di sini, karena deduksi selesai
	-- di tengah sesi dan salinan boolean akan basi.
	gated_by: { string }?,
}

export type Hold = {
	object_id: string,
	action: string,
	startedAt: number,
}

export type Service = {
	location: string,
	objects: { [string]: WorldObject },
	-- Hanya objek yang BISA diperiksa, terurut. Ambient tidak ikut: ia bukan
	-- bagian dari rantai, dan mencampurnya akan membuat "objek ke-i" berubah
	-- arti saat data kasus bertambah.
	order: { string },
	ambient: { string },
	actions: { [string]: Action },
	-- Kunci yang sudah diberikan lokasi ini (PRD §4: "objek memberi kunci").
	keysHeld: { [string]: boolean },
	-- Deduksi yang sudah selesai pada sesi ini. Dipakai gerbang `unlocks`:
	-- objek yang dibuka sebuah deduksi baru bisa diperiksa setelah deduksi itu
	-- ada di sini (PRD §4 langkah 6).
	completedDeductions: { [string]: boolean },
	holds: { [number]: Hold },
	clock: () -> number,
}

--[[
	Objek ambient per lokasi (PRD §6: "Eksplorasi bebas dengan objek ambient
	(bukti tambahan opsional)").

	Ambient tidak diambil dari data kasus karena ia bukan bagian dari Clue
	Graph: tidak ada node, tidak ada kunci, tidak ada Clue Card. Menaruhnya di
	data kasus akan menuntut skema baru untuk sesuatu yang tidak mengubah
	solusi. Yang dijaga di sini cuma satu: `gives_key` selalu `nil`, sehingga
	ambient tidak pernah bisa mempercepat gerbang deduksi.
]]
local AMBIENT: { [string]: { { id: string, label: string, action: string } } } = {
	gallery = {
		{ id = "amb_poster", label = "Poster pameran di dinding", action = "uv" },
		{ id = "amb_bench", label = "Bangku kayu di tengah ruang", action = "drawer" },
	},
}

LocationService.AMBIENT = AMBIENT

--[[
	Tata letak deterministik: objek ke-`index` dari `count` diletakkan pada
	cincin berjari-jari `radius` di sekitar pusat lokasi.

	Kenapa diturunkan di kode, bukan disimpan di data kasus: `schema/case.schema.json`
	menutup properti tambahan (`additionalProperties: false`), jadi menambah
	`position` ke node berarti mengubah skema dan validator -- dua sumber aturan
	-- untuk urusan yang bukan urusan penulis kasus. Posisi dunia adalah urusan
	presentasi, dan `src/client/` memetakannya ke geometri nyata.
]]
function LocationService.ringPosition(index: number, count: number, radius: number): Point
	local safeCount = if count > 0 then count else 1
	local angle = (2 * math.pi * (index - 1)) / safeCount
	return {
		x = radius * math.cos(angle),
		z = radius * math.sin(angle),
	}
end

--[[
	Mini-aksi untuk objek ke-`index`, diambil bergiliran dari `actions`.

	Bergiliran, bukan acak: dua sesi dengan data yang sama harus memberi
	mini-aksi yang sama, supaya bug "aksi ini selalu gagal" bisa direproduksi.
	Pemetaan berdasarkan indeks juga berarti menambah objek di data kasus tidak
	menggeser aksi objek sebelumnya selama urutannya tetap.
]]
function LocationService.actionIndex(index: number, count: number): number
	if count <= 0 then
		return 1
	end
	return ((index - 1) % count) + 1
end

local function indexActions(actions: { Action }): { [string]: Action }
	local byId: { [string]: Action } = {}
	for _, action in actions do
		byId[action.id] = action
	end
	return byId
end

--[[
	Apakah sebuah node hidup pada varian sesi ini (PRD §10: "tiap story case
	ditulis dengan 2-3 cabang solusi ... Seed server memilih cabang saat sesi
	dibuat").

	Aturan yang sama dengan `PuzzleTableService.isActive`: node tanpa `variants`
	selalu hidup; node DENGAN `variants` tetapi sesi tanpa varian dikenal
	dianggap mati, karena menganggapnya hidup akan menyerahkan isi cabang lain.
]]
local function activeInVariant(node: any, variantId: string?): boolean
	if node.variants == nil then
		return true
	end
	if variantId == nil then
		return false
	end
	for _, id in node.variants do
		if id == variantId then
			return true
		end
	end
	return false
end

export type Options = {
	location: string,
	-- Node mentah dari data kasus; hanya `object` yang dipakai.
	nodes: { any },
	-- Himpunan id yang sudah bisa dicapai (`CaseGraph.reachable`, PRD §4:
	-- deduksi "membuka target baru").
	reachableIds: { [string]: boolean },
	actions: { Action },
	-- Jam yang disuntik. `os.clock()` di glue, jam palsu di uji.
	clock: () -> number,
	variantId: string?,
	-- Tabel deduksi yang sudah selesai pada sesi ini, DIBAGI dengan glue --
	-- bukan disalin. Gerbang `unlocks` harus membaca keadaan yang sama dengan
	-- yang ditulis `handleDeduce`; dua tabel berarti objek yang sudah terbuka
	-- tetap terlihat terkunci.
	completedDeductions: { [string]: boolean }?,
	-- Jari-jari cincin tempat objek rantai dan objek ambient diletakkan.
	radius: number?,
	ambientRadius: number?,
}

--[[
	Membangun lokasi dari node objek aktif sebuah kasus.

	Menerima tabel opsi, bukan daftar argumen posisional: jumlah masukan di sini
	sudah tujuh, dan pemanggil yang menukar dua argumen bertipe sama (mis.
	`radius` dan `ambientRadius`) tidak akan ketahuan compiler. Dengan nama
	field, kesalahan itu tidak bisa ditulis.

	Objek yang belum tercapai tetap masuk `objects` dengan `reachable = false`
	supaya ia bisa ditampilkan sebagai target yang belum terbuka.
]]
function LocationService.new(opts: Options): Service
	local actions = opts.actions
	local variantId = opts.variantId
	local reachableIds = opts.reachableIds
	local nodes = opts.nodes
	local radius = opts.radius or 40
	local ambientRadius = opts.ambientRadius or 12
	local byId = indexActions(actions)

	local service: Service = {
		location = opts.location,
		objects = {},
		order = {},
		ambient = {},
		actions = byId,
		keysHeld = {},
		-- Tabel yang sama dengan yang dipegang glue (opsi `completedDeductions`).
		-- Kalau glue tidak menyerahkan tabelnya, lokasi memakai tabelnya sendiri
		-- supaya modul ini tetap bisa dipakai sendiri di uji.
		completedDeductions = opts.completedDeductions or {},
		holds = {},
		clock = opts.clock,
	}

	-- Peta "node mana yang membuka objek ini" dari `unlocks` (PRD §4 langkah 6:
	-- "Deduksi menaruh pinpoint baru di map dan membuka target baru").
	--
	-- Hanya node AKTIF di varian ini yang masuk: gerbang dari deduksi cabang
	-- lain tidak akan pernah selesai pada sesi ini, dan memasukkannya akan
	-- mengunci objek ini selamanya.
	local unlockers: { [string]: { string } } = {}
	for _, node in nodes do
		if type(node) ~= "table" or type(node.unlocks) ~= "table" then
			continue
		end
		if not activeInVariant(node, variantId) then
			continue
		end
		for _, target in node.unlocks do
			if type(target) == "string" and type(node.id) == "string" then
				local bucket = unlockers[target]
				if bucket == nil then
					bucket = {}
					unlockers[target] = bucket
				end
				table.insert(bucket, node.id)
			end
		end
	end

	local candidates: { any } = {}
	for _, node in nodes do
		if type(node) ~= "table" then
			continue
		end
		local kind = node.kind
		if kind == nil then
			kind = node.type
		end
		if kind ~= "object" then
			continue
		end

		-- PRD §10: node ber-`variants` hanya hidup di cabangnya. Objek cabang
		-- lain tidak boleh ada di lokasi -- memeriksanya akan memberi kunci
		-- yang tidak membuka apa pun pada sesi ini.
		if not activeInVariant(node, variantId) then
			continue
		end

		table.insert(candidates, node)
	end

	for index, node in candidates do
		local reachable = reachableIds[node.id] == true
		local action = actions[LocationService.actionIndex(index, #actions)]
		local object: WorldObject = {
			id = node.id,
			label = node.label,
			kind = "object",
			action = action.id,
			position = LocationService.ringPosition(index, #candidates, radius),
			gives_key = node.gives_key,
			reachable = reachable,
			gated_by = unlockers[node.id],
		}
		table.insert(service.order, node.id)
		service.objects[node.id] = object
	end

	local ambient = AMBIENT[opts.location]
	if ambient ~= nil then
		for index, prop in ambient do
			local action = actions[LocationService.actionIndex(index, #actions)]
			service.objects[prop.id] = {
				id = prop.id,
				label = prop.label,
				kind = "ambient",
				action = action.id,
				-- Ambient diletakkan di cincin dalam supaya tidak bertumpuk
				-- dengan objek rantai, dan tetap deterministik.
				position = LocationService.ringPosition(index, #ambient, ambientRadius),
				gives_key = nil,
				reachable = true,
			}
			table.insert(service.ambient, prop.id)
		end
	end

	-- Hanya objek rantai yang tercapai secara graf masuk `order`. Urutannya
	-- mengikuti urutan data kasus dan TIDAK berubah selama sesi -- itulah yang
	-- membuat penetapan mini-aksi dan posisi cincin stabil. "Bisa diperiksa
	-- sekarang" adalah pertanyaan lain (`isInspectable`/`available`), karena
	-- deduksi bisa membuka objek di tengah sesi.
	local reachableOrder: { string } = {}
	for _, nodeId in service.order do
		if service.objects[nodeId].reachable then
			table.insert(reachableOrder, nodeId)
		end
	end
	service.order = reachableOrder

	return service
end

function LocationService.get(service: Service, objectId: string): WorldObject?
	return service.objects[objectId]
end

--[[
	Apakah objek ini boleh diperiksa SEKARANG.

	Dua syarat, dan keduanya perlu:
	  1. `reachable` -- node ini ada di jalur yang hidup (tidak terpotong
	     siklus atau rantai buntu, PRD §10);
	  2. semua `gated_by` sudah selesai -- deduksi yang membukanya sudah
	     dikerjakan Director (PRD §4 langkah 6).

	Keduanya berbeda, dan `obj_ledger` di `gallery_01` adalah buktinya: ia
	tercapai secara graf sejak sesi mulai, tetapi baru terbuka setelah
	`ded_c_culprit_1` selesai. Memeriksa syarat pertama saja akan membuka buku
	kas tersembunyi di menit pertama.
]]
function LocationService.isInspectable(service: Service, objectId: string): boolean
	local object = service.objects[objectId]
	if object == nil then
		return false
	end
	if not object.reachable then
		return false
	end
	local gates = object.gated_by
	if gates == nil then
		return true
	end
	for _, deductionId in gates do
		if service.completedDeductions[deductionId] ~= true then
			return false
		end
	end
	return true
end

--[[
	Mencatat bahwa sebuah deduksi selesai pada sesi ini, lalu mengembalikan
	daftar objek yang BARU terbuka karenanya (terurut, supaya log dan test
	stabil).

	Mengembalikan daftar, bukan boolean: glue perlu tahu part mana yang harus
	diperbarui, dan menghitung ulang seluruh lokasi di sana akan menduplikasi
	aturan yang sudah ada di sini.
]]
function LocationService.completeDeduction(service: Service, deductionId: string): { string }
	if service.completedDeductions[deductionId] == true then
		return {}
	end
	service.completedDeductions[deductionId] = true

	local unlocked: { string } = {}
	for _, objectId in service.order do
		local object = service.objects[objectId]
		local gates = object.gated_by
		if gates == nil then
			continue
		end
		local relevant = false
		for _, gate in gates do
			if gate == deductionId then
				relevant = true
			end
		end
		-- Objek bisa punya lebih dari satu gerbang; kalau ada gerbang lain yang
		-- belum selesai, ia belum terbuka.
		if relevant and LocationService.isInspectable(service, objectId) then
			table.insert(unlocked, objectId)
		end
	end
	return unlocked
end

--[[
	Objek yang boleh diperiksa sekarang, dalam urutan data kasus.

	Terpisah dari `order` (yang berarti "objek rantai yang tercapai secara
	graf"): yang pertama berubah selama sesi, yang kedua tidak.
]]
function LocationService.available(service: Service): { string }
	local list: { string } = {}
	for _, objectId in service.order do
		if LocationService.isInspectable(service, objectId) then
			table.insert(list, objectId)
		end
	end
	return list
end

function LocationService.actionFor(service: Service, objectId: string): Action?
	local object = service.objects[objectId]
	if object == nil then
		return nil
	end
	return service.actions[object.action]
end

function LocationService.ambientFor(service: Service): { WorldObject }
	local list: { WorldObject } = {}
	for _, objectId in service.ambient do
		table.insert(list, service.objects[objectId])
	end
	return list
end

--[[
	Memulai pemeriksaan sebuah objek.

	Mengembalikan `(ok, alasan)`. Alasan hanya untuk log server -- client
	hanya menerima "diterima/ditolak", karena alasan rinci (mis. "objek belum
	bisa dicapai") akan memberi tahu client objek mana yang masih tersembunyi.

	Tiga penolakan yang harus nyata (PRD §4, §15):
	  1. objek tidak ada di lokasi ini,
	  2. objek ada tetapi belum bisa dicapai,
	  3. mini-aksi yang dikirim client tidak cocok dengan yang dibutuhkan.
]]
function LocationService.beginInspect(
	service: Service,
	playerId: number,
	objectId: string,
	actionId: string
): (boolean, string?)
	local object = service.objects[objectId]
	if object == nil then
		return false, "objek tidak ada di lokasi"
	end
	if not LocationService.isInspectable(service, objectId) then
		return false, "objek belum bisa dicapai"
	end
	if object.action ~= actionId then
		return false, "aksi tidak cocok"
	end

	service.holds[playerId] = {
		object_id = objectId,
		action = actionId,
		startedAt = service.clock(),
	}
	return true, nil
end

--[[
	Menyelesaikan pemeriksaan yang sedang berjalan.

	Mengembalikan `(ok, alasan, kunci)`. Aksi dengan `hold_seconds = 0` selesai
	seketika; aksi tahan hanya selesai setelah durasinya lewat menurut jam yang
	disuntik.

	Pemeriksaan yang terlalu cepat TIDAK membatalkan tahan -- jari yang belum
	selesai menahan masih boleh melanjutkan. Yang membatalkan adalah
	`cancelInspect` (jari diangkat) atau memulai aksi lain.

	Kunci yang dikembalikan dicatat di `service.keysHeld`; memeriksa objek yang
	sama dua kali memberi kunci yang sama, bukan kunci kedua.
]]
function LocationService.completeInspect(
	service: Service,
	playerId: number,
	objectId: string
): (boolean, string?, string?)
	local hold = service.holds[playerId]
	if hold == nil then
		return false, "tidak ada aksi berjalan", nil
	end
	if hold.object_id ~= objectId then
		return false, "aksi berjalan untuk objek lain", nil
	end

	local object = service.objects[objectId]
	if object == nil then
		return false, "objek tidak ada di lokasi", nil
	end

	local action = service.actions[hold.action]
	if action == nil then
		return false, "aksi tidak dikenal", nil
	end

	if service.clock() - hold.startedAt < action.hold_seconds then
		return false, "aksi belum selesai", nil
	end

	service.holds[playerId] = nil

	if object.gives_key ~= nil then
		service.keysHeld[object.gives_key] = true
	end
	return true, nil, object.gives_key
end

--[[
	Membatalkan pemeriksaan yang berjalan (jari diangkat, pemain menjauh,
	atau disconnect). Tidak ada yang dicatat ke `keysHeld` di sini.
]]
function LocationService.cancelInspect(service: Service, playerId: number): ()
	service.holds[playerId] = nil
end

--[[
	Kunci yang dipegang tim, dalam bentuk himpunan yang diterima
	`PuzzleTableService.isUnlocked`/`firstAvailable`.

	Ini yang menutup rantai PRD §4: Searcher memeriksa objek -> objek memberi
	kunci -> kunci membuka meja bukti Handler.
]]
function LocationService.keysHeld(service: Service): { [string]: boolean }
	return service.keysHeld
end

return LocationService
