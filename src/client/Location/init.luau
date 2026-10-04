--!strict
-- Lokasi Searcher (PRD §4, §6, §7, §17 minggu 2).
--
-- Tiga hal yang dipegang berkas ini, dan dua hal yang sengaja TIDAK dipegang:
--
--   1. Menemukan objek lokasi lewat TAG, bukan lewat nama atau path. Server
--      menandai part dengan `CollectionService`; nama part bisa berubah tanpa
--      merusak client, dan tag tidak bisa salah cocok dengan part lain di place.
--   2. Mengirim NIAT, bukan hasil. `begin` saat jari mulai menahan, `cancel`
--      saat jari diangkat, `complete` saat prompt terpicu. Server menghitung
--      sendiri durasi tahannya terhadap jamnya; client yang mengirim
--      `complete` terlalu cepat ditolak.
--   3. Menampilkan apa yang server katakan. Judul objek datang dari `report_card`
--      yang dirakit server, bukan dari atribut part -- atribut hanyalah kanal
--      replikasi (`docs/arsitektur.md`), jadi client tidak pernah dijadikan
--      penentu apa yang benar.
--
-- Yang TIDAK dipegang:
--   * Kamera. `Table.mount` memindahkan kamera ke top-down Scriptable untuk
--     Handler; Searcher butuh kamera first/third person (PRD §3), jadi berkas
--     ini tidak menyentuh `CameraType` sama sekali. Dua modul yang sama-sama
--     menyetel kamera akan saling menimpa saat satu pemain berganti role.
--   * Penilaian. Tidak ada di sini yang memutuskan sebuah pemeriksaan sah.
--     Semua gerbangnya di `src/server/LocationService.luau`.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Location = {}

-- Nama tag ini harus sama dengan `OBJECT_TAG` di `src/server/init.server.luau`.
-- Ia konstanta string, bukan `Instance` yang dibagi, karena client dan server
-- tidak berbagi state -- yang mereka bagi adalah place dan `ReplicatedStorage`.
Location.OBJECT_TAG = "TriangulateObject"

-- Prompt yang dibuat client. Dua prompt per objek, karena keduanya memang aksi
-- berbeda di PRD §4: "memeriksa" (langkah 2: Searcher memeriksa objek) dan
-- "Report" (langkah 2 juga: objek masuk ke clue board Director). Menggabungkan
-- keduanya berarti Handler menerima kunci dari objek yang belum selesai
-- diperiksa.
local INSPECT_PROMPT = "TriangulateInspect"
local REPORT_PROMPT = "TriangulateReport"

export type Mount = {
	-- Memperbarui daftar prompt; dipanggil saat `report_card` datang supaya
	-- objek yang sudah dilaporkan berhenti menawarkan "Lapor" lagi.
	refresh: () -> (),
	destroy: () -> (),
}

--[[
	Durasi tahan sebuah aksi, dibaca dari `Config.SEARCHER_ACTIONS`.

	Client memakai angka yang sama dengan server hanya untuk MENAMPILKAN lama
	tahan. Kalau keduanya berbeda, yang menang tetap server: prompt akan selesai
	lebih cepat atau lebih lambat, dan `complete` yang terlalu cepat ditolak.
	Karena itu nilai yang tidak dikenal jatuh ke 0 (sekali sentuh) -- lebih baik
	terlalu cepat lalu ditolak dengan jelas daripada menggantung tanpa ujung.
]]
local function holdSeconds(actionId: string?): number
	if actionId == nil then
		return 0
	end
	for _, action in Config.SEARCHER_ACTIONS do
		if action.id == actionId then
			return action.hold_seconds
		end
	end
	return 0
end

local function actionLabel(actionId: string?): string
	if actionId == nil then
		return "Periksa"
	end
	for _, action in Config.SEARCHER_ACTIONS do
		if action.id == actionId then
			return action.label
		end
	end
	return "Periksa"
end

--[[
	Apakah server sudah membuka objek ini.

	Client TIDAK memutuskan apa pun di sini: ia hanya membaca dua atribut yang
	dipublikasikan server. `reachable` tetap sepanjang sesi (ia sifat graf,
	PRD §10); `gated` berubah saat deduksi yang membuka objek itu selesai
	(PRD §4 langkah 6, `handleDeduce`). Prompt yang tertutup hanya tidak
	ditawarkan -- server tetap menolak pesan dari objek yang belum terbuka,
	jadi ini kenyamanan, bukan pengamanan.
]]
local function isOpen(part: BasePart): boolean
	if part:GetAttribute("reachable") == false then
		return false
	end
	return part:GetAttribute("gated") ~= true
end

export type Handlers = {
	-- Dipanggil untuk ketiga fase mini-aksi: "begin", "cancel", "complete".
	inspect: (objectId: string, action: string, phase: string) -> (),
	-- Dipanggil saat pemain menekan "Lapor" (PRD §7, Report Card).
	report: (objectId: string, action: string) -> (),
}

--[[
	Memasang lokasi untuk Searcher.

	Handler masuk sebagai TABEL BERNAMA, bukan dua argumen fungsi berurutan:
	keduanya bertipe fungsi dan `inspect` menerima satu parameter lebih banyak,
	dan Luau mengizinkan fungsi dengan parameter lebih sedikit dipakai di tempat
	yang mengharapkan lebih banyak -- jadi urutan yang tertukar tidak akan
	ketahuan compiler. Dengan nama field, kesalahan itu tidak bisa ditulis.

	Tidak ada parameter `Player` di sini: seluruh perilaku berkas ini melekat
	pada part di `Workspace`, bukan pada pemain. `Hud.mount`/`Table.mount`
	menerima `Player` karena keduanya membangun `ScreenGui` di `PlayerGui`;
	berkas ini tidak membangun GUI sama sekali.

	Pemanggil bertanggung jawab memasang ini HANYA untuk Searcher: PRD §3
	membagi role, dan Handler berada di meja, bukan di lokasi. Server tetap
	menolak pesan dari role lain (`handleInspect`/`handleReport` memeriksa
	`roleOf`), jadi salah pasang tidak membuka celah -- hanya memunculkan prompt
	yang tidak berguna.
]]
function Location.mount(handlers: Handlers): Mount
	local connections: { RBXScriptConnection } = {}
	-- Prompt yang KITA buat, supaya bisa dibersihkan tanpa menyentuh part milik
	-- server.
	local created: { ProximityPrompt } = {}
	local mounted: { [BasePart]: boolean } = {}
	-- Penunggu gerbang, satu per part. Dipisahkan dari `connections` supaya bisa
	-- dilepas saat part-nya benar-benar terbuka -- tanpa itu, tiap `refresh`
	-- menambah langganan baru pada part yang sama.
	local gated: { [BasePart]: RBXScriptConnection } = {}

	local function attach(part: BasePart): ()
		if mounted[part] then
			return
		end
		mounted[part] = true

		local pending = gated[part]
		if pending ~= nil then
			pending:Disconnect()
			gated[part] = nil
		end

		local objectId = part:GetAttribute("object_id")
		if type(objectId) ~= "string" then
			-- Part tanpa atribut `object_id` bukan objek yang kita kenal. Ini
			-- bukan kesalahan fatal: place bisa berisi part lain.
			return
		end

		local actionId = part:GetAttribute("action")
		local action = if type(actionId) == "string" then actionId else nil

		if not isOpen(part) then
			-- Objek ada di dunia tetapi belum boleh diperiksa: pintu yang
			-- belum bisa dibuka. Promptnya dipasang nanti, saat server
			-- membuka gerbangnya -- lihat `watchGate` di bawah.
			return
		end

		local inspectPrompt = Instance.new("ProximityPrompt")
		inspectPrompt.Name = INSPECT_PROMPT
		inspectPrompt.ObjectText = tostring(part:GetAttribute("label") or objectId)
		inspectPrompt.ActionText = actionLabel(action)
		inspectPrompt.HoldDuration = holdSeconds(action)
		inspectPrompt.MaxActivationDistance = 10
		inspectPrompt.RequiresLineOfSight = false
		-- KeyboardKeyCode disembunyikan: target utama adalah layar sentuh
		-- (PRD §12 "Mayoritas mobile"), dan prompt sentuh adalah jalur yang
		-- benar-benar dipakai.
		inspectPrompt.KeyboardKeyCode = Enum.KeyCode.None
		inspectPrompt.GamepadKeyCode = Enum.KeyCode.None
		inspectPrompt.Parent = part
		table.insert(created, inspectPrompt)

		local reportPrompt = Instance.new("ProximityPrompt")
		reportPrompt.Name = REPORT_PROMPT
		reportPrompt.ObjectText = tostring(part:GetAttribute("label") or objectId)
		reportPrompt.ActionText = "Lapor"
		reportPrompt.HoldDuration = 0
		reportPrompt.MaxActivationDistance = 10
		reportPrompt.RequiresLineOfSight = false
		reportPrompt.KeyboardKeyCode = Enum.KeyCode.None
		reportPrompt.GamepadKeyCode = Enum.KeyCode.None
		reportPrompt.Parent = part
		table.insert(created, reportPrompt)

		-- Tiga fase yang dipetakan ke tiga event prompt. `begin` sengaja TIDAK
		-- dikirim saat prompt mulai terlihat: memulai tahan adalah keputusan
		-- pemain, dan server mencatat waktu mulai dari pesan itu.
		table.insert(
			connections,
			inspectPrompt.PromptButtonHoldBegan:Connect(function()
				handlers.inspect(objectId, action or "", "begin")
			end)
		)
		table.insert(
			connections,
			inspectPrompt.PromptButtonHoldEnded:Connect(function()
				-- Jari diangkat sebelum tahan selesai. Mengirim `cancel` di
				-- sini berarti tahan yang gagal tidak meninggalkan state
				-- menggantung di server.
				handlers.inspect(objectId, action or "", "cancel")
			end)
		)
		table.insert(
			connections,
			inspectPrompt.Triggered:Connect(function()
				handlers.inspect(objectId, action or "", "complete")
			end)
		)
		table.insert(
			connections,
			reportPrompt.Triggered:Connect(function()
				handlers.report(objectId, action or "")
			end)
		)
	end

	-- PRD §4 langkah 6: sebuah deduksi membuka target baru. Server menandainya
	-- dengan mengubah atribut `gated` pada part yang sudah ada di dunia, jadi
	-- client harus menunggu PERUBAHAN itu -- bukan hanya kemunculan part.
	-- Tanpa langganan ini, pintu yang terbuka di tengah sesi tetap tidak bisa
	-- diperiksa sampai pemain bergabung ulang.
	local function watchGate(part: BasePart): ()
		if mounted[part] or gated[part] ~= nil then
			return
		end
		gated[part] = part:GetAttributeChangedSignal("gated"):Connect(function()
			attach(part)
		end)
	end

	local function scan(): ()
		for _, instance in CollectionService:GetTagged(Location.OBJECT_TAG) do
			if instance:IsA("BasePart") then
				if isOpen(instance) then
					attach(instance)
				else
					watchGate(instance)
				end
			end
		end
	end

	-- Objek yang muncul setelah client siap (lokasi dibuat server saat sesi
	-- mulai, dan itu bisa terjadi setelah pemain masuk). Tanpa langganan ini,
	-- Searcher yang bergabung lebih dulu tidak akan pernah melihat objeknya.
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(Location.OBJECT_TAG):Connect(function(instance)
			if instance:IsA("BasePart") then
				if isOpen(instance) then
					attach(instance)
				else
					watchGate(instance)
				end
			end
		end)
	)

	scan()

	local function destroy(): ()
		for _, connection in connections do
			connection:Disconnect()
		end
		connections = {}
		for part, connection in gated do
			connection:Disconnect()
			gated[part] = nil
		end
		for _, prompt in created do
			prompt:Destroy()
		end
		created = {}
		mounted = {}
	end

	return {
		refresh = scan,
		destroy = destroy,
	}
end

return Location
