--!strict
-- Uji papan Director: pernyataan saksi, penandaan Kontradiksi, pinpoint, dan
-- hitungan Deduksi Kunci (PRD §4, §5, §7).
--
-- Yang diuji di sini adalah aturan yang paling mudah salah dan paling mahal
-- kalau salah: pernyataan mana yang berlaku di varian sesi ini, kapan sebuah
-- Kontradiksi sah ditandai, dan dari mana pinpoint sebuah Deduksi berasal.
-- Semuanya murni -- `DirectorBoardService` tidak menyentuh global Roblox --
-- jadi bisa dijalankan tanpa Studio.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")

local CaseGraph = require("../src/shared/case/CaseGraph")
local DirectorBoardService = require("../src/server/DirectorBoardService")

local gallery = serde.decode("json", fs.readFile("data/cases/gallery_01.json"))

local vCurator = DirectorBoardService.new(CaseGraph, gallery, "v_curator")
local vGuard = DirectorBoardService.new(CaseGraph, gallery, "v_guard")
Harness.check(vCurator ~= nil, "papan v_curator terbentuk")
Harness.check(vGuard ~= nil, "papan v_guard terbentuk")

if vCurator == nil or vGuard == nil then
	Harness.finish("director-board")
	return nil
end

Harness.suite("papan Director: penyaringan pernyataan per varian")

-- PRD §4: "Tiap kasus punya 2-3 pernyataan saksi/tersangka, minimal satu
-- berbohong." `gallery_01.json` menulis empat pernyataan; dua di antaranya
-- hanya berlaku di satu varian.
Harness.equal(#vCurator.statements, 3, "v_curator punya 3 pernyataan berlaku")
Harness.equal(#vGuard.statements, 3, "v_guard punya 3 pernyataan berlaku")

-- Identitas pernyataan adalah indeks 1-based di `case.statements`, bukan `who`:
-- data kasus memuat dua pernyataan dengan `who = "guard"`.
local curatorIds: { number } = {}
for _, statement in vCurator.statements do
	table.insert(curatorIds, statement.id)
end
Harness.equal(table.concat(curatorIds, ","), "1,3,4", "v_curator memakai pernyataan 1, 3, 4")

local guardIds: { number } = {}
for _, statement in vGuard.statements do
	table.insert(guardIds, statement.id)
end
Harness.equal(table.concat(guardIds, ","), "2,3,4", "v_guard memakai pernyataan 2, 3, 4")

-- Pembohong tiap varian: indeks 1 di v_curator, indeks 2 di v_guard. Karena
-- daftar papan sudah disaring varian, pembohong v_guard ada di posisi pertama
-- daftar v_guard -- dan `who`-nya `guard`, sama seperti pernyataan jujur
-- nomor 4. Itu sebabnya identitasnya nomor, bukan nama.
Harness.check(vCurator.statements[1].lie, "pernyataan 1 bohong di v_curator")
Harness.check(vGuard.statements[1].lie, "pembohong v_guard ada di daftar v_guard")
Harness.equal(vGuard.statements[1].id, 2, "pembohong v_guard adalah pernyataan 2")
Harness.equal(vGuard.statements[1].who, "guard", "pembohong v_guard bernama guard")
Harness.equal(
	vGuard.statements[3].who,
	"guard",
	"pernyataan jujur bernama guard juga ada -- who tidak unik"
)
Harness.check(not vGuard.statements[3].lie, "pernyataan guard kedua tidak bohong")

Harness.suite("papan Director: pernyataan yang menyeberang ke client")

-- Pernyataan sampai ke client lewat `CaseLoader.projectForRole` -- satu jalur
-- saja, bukan dua. Proyeksi itu yang membuang `lie`/`contradicted_by` dan
-- menambahkan `id` yang dipakai `MarkContradiction`.
local CaseLoader = require("../src/shared/case/CaseLoader")

local projected = CaseLoader.projectForRole(gallery, "v_curator", "Director")
Harness.check(projected ~= nil, "proyeksi Director terbentuk")
if projected ~= nil then
	Harness.equal(#projected.statements, 3, "tiap pernyataan berlaku punya satu view")
	Harness.equal(projected.statements[1].id, 1, "view membawa id pernyataan")
	Harness.equal(projected.statements[1].who, "curator", "view membawa who")
	Harness.check(type(projected.statements[1].text) == "string", "view membawa text")

	-- `Net.project` menyalin nilai apa adanya, jadi `lie`/`contradicted_by`
	-- harus sudah hilang SEBELUM proyeksi. Kalau tidak, keduanya menyeberang di
	-- dalam item list dan Director bisa membaca jawabannya langsung.
	for index, view in projected.statements do
		Harness.check(view.lie == nil, string.format("view pernyataan %d tidak membawa lie", index))
		Harness.check(
			view.contradicted_by == nil,
			string.format("view pernyataan %d tidak membawa contradicted_by", index)
		)
	end

	-- `id` yang dikirim ke client harus cocok dengan `id` yang dipakai server
	-- saat memeriksa penandaan -- itu yang membuat `MarkContradiction` bisa
	-- memetakan balik ke pernyataan yang benar.
	local idsMatch = true
	for index, view in projected.statements do
		if view.id ~= vCurator.statements[index].id then
			idsMatch = false
		end
	end
	Harness.check(idsMatch, "id proyeksi cocok dengan id papan server")
end

Harness.suite("papan Director: penandaan Kontradiksi")

local function clues(...: string): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, id in { ... } do
		set[id] = true
	end
	return set
end

-- Diterima: pernyataan 1 bohong DAN bukti pembantahnya (`clue_curator_card`)
-- sudah dikumpulkan Director.
local accepted, reason, statement =
	DirectorBoardService.checkMark(vCurator, 1, clues("clue_curator_card"), {})
Harness.ok(accepted, "pembohong dengan bukti pembantah diterima")
Harness.equal(reason, nil, "penandaan yang diterima tidak punya alasan")
Harness.equal(
	statement ~= nil and statement.id,
	1,
	"pernyataan yang dikembalikan adalah yang ditandai"
)

-- Ditolak: pernyataan 3 bukan pembohong. Alasan yang dikirim tetap pesan yang
-- sama dengan "bukti belum ada" -- membedakannya akan jadi oracle pembohong.
local notLiar, notLiarReason =
	DirectorBoardService.checkMark(vCurator, 3, clues("clue_curator_card"), {})
Harness.check(not notLiar, "pernyataan yang tidak bohong ditolak")
Harness.equal(
	notLiarReason,
	DirectorBoardService.REJECT_REASON,
	"penolakan memberi alasan yang bisa dibaca pemain"
)

-- Ditolak: pernyataan 1 bohong, tapi bukti pembantahnya belum dikumpulkan.
-- PRD §5 mengaitkan gerbang tuduhan dengan Kontradiksi yang ditandai; tanpa
-- syarat bukti, Director bisa menandai semua pernyataan sampai ketemu.
local tooEarly, tooEarlyReason =
	DirectorBoardService.checkMark(vCurator, 1, clues("clue_guard_off"), {})
Harness.check(not tooEarly, "pembohong tanpa bukti pembantah ditolak")
Harness.equal(
	tooEarlyReason,
	notLiarReason,
	"dua mode kegagalan memberi pesan yang sama (tidak jadi oracle)"
)

-- Ditolak: sudah ditandai. Pesannya berbeda karena ia tidak membocorkan apa pun.
local marked: { [number]: boolean } = { [1] = true }
local again, againReason =
	DirectorBoardService.checkMark(vCurator, 1, clues("clue_curator_card"), marked)
Harness.check(not again, "penandaan ulang ditolak")
Harness.equal(
	againReason,
	DirectorBoardService.ALREADY_MARKED,
	"penandaan ulang punya alasan sendiri"
)

-- Ditolak: nomor pernyataan di luar daftar varian ini (pernyataan 2 milik
-- v_guard). Ini yang mencegah client menandai pernyataan yang tidak dikirim.
local wrongVariant = DirectorBoardService.checkMark(vCurator, 2, clues("clue_shift_swap"), {})
Harness.check(not wrongVariant, "pernyataan varian lain ditolak")

-- Ditolak: nomor yang bukan bilangan bulat, termasuk payload yang dikirim
-- client secara mentah. Server tidak boleh percaya tipe dari client.
local notNumber = DirectorBoardService.checkMark(vCurator, "1", clues("clue_curator_card"), {})
Harness.check(not notNumber, "nomor pernyataan non-numerik ditolak")
local fractional = DirectorBoardService.checkMark(vCurator, 1.5, clues("clue_curator_card"), {})
Harness.check(not fractional, "nomor pernyataan pecahan ditolak")

-- Sisi v_guard: pembohongnya pernyataan 2, dan bukti pembantahnya berbeda.
local guardAccepted = DirectorBoardService.checkMark(vGuard, 2, clues("clue_shift_swap"), {})
Harness.ok(guardAccepted, "pembohong v_guard diterima dengan bukti variannya")
local guardWrongClue = DirectorBoardService.checkMark(vGuard, 2, clues("clue_curator_card"), {})
Harness.check(not guardWrongClue, "bukti milik varian lain tidak membantah")

Harness.suite("papan Director: Deduksi Kunci")

-- PRD §5: yang dihitung hanya Deduksi Kunci; deduksi bonus tidak mendekatkan
-- tim ke form tuduhan.
local required = vCurator.required_deductions
Harness.check(required["ded_c_culprit_1"], "deduksi kunci v_curator terdaftar")
Harness.check(not required["ded_c_extra"], "deduksi di luar daftar bukan kunci")

Harness.equal(
	DirectorBoardService.keyDeductionsDone(vCurator, { ded_c_culprit_1 = true }),
	1,
	"satu deduksi kunci terhitung"
)
Harness.equal(
	DirectorBoardService.keyDeductionsDone(
		vCurator,
		{ ded_c_culprit_1 = true, ded_c_extra = true, ded_bonus = true }
	),
	1,
	"deduksi bonus tidak menambah hitungan kunci"
)
Harness.equal(
	DirectorBoardService.keyDeductionsDone(vCurator, {
		ded_c_culprit_1 = true,
		ded_c_method_1 = true,
		ded_c_motive_1 = true,
		ded_c_motive_2 = true,
	}),
	4,
	"seluruh deduksi kunci terhitung"
)

-- N diambil dari ANGKA di data kasus, bukan dihitung ulang dari rumus 65%.
Harness.equal(
	vCurator.key_deductions_required,
	gallery.key_deductions,
	"N mengikuti angka eksplisit data kasus"
)
Harness.equal(vCurator.required_count, 4, "kasus ini punya 4 deduksi kunci")

-- Kasus tanpa `key_deductions` jatuh ke tabel per `case_type`, lalu ke jumlah
-- deduksi kunci. Ini jalur cadangan, bukan aturan kedua: validator EXTA-33
-- mewajibkan field-nya untuk kasus baru.
local noNumber = table.clone(gallery)
noNumber.key_deductions = nil
local fallback = DirectorBoardService.new(CaseGraph, noNumber, "v_curator")
Harness.check(fallback ~= nil, "kasus tanpa angka tetap membentuk papan")
if fallback ~= nil then
	Harness.equal(
		fallback.key_deductions_required,
		CaseGraph.REQUIRED_KEY_DEDUCTIONS[gallery.case_type],
		"cadangan memakai angka per case_type"
	)
end

Harness.suite("papan Director: pinpoint dari Deduksi")

-- PRD §4: "Deduksi menaruh pinpoint baru di map dan membuka target baru."
-- Pinpoint DITURUNKAN dari graf oleh `CaseGraph.primaryOrigin`, bukan dibaca
-- dari field `unlocks` di data: `unlocks` adalah busur dependensi nyata, jadi
-- menambahkannya ke kasus yang sudah lulus gate akan mengubah graf. Yang
-- diuji di sini adalah aturan turunannya, pada data kasus nyata.
local function pinpointOf(variantId: string, deductionId: string): string?
	return CaseGraph.primaryOrigin(gallery, variantId, deductionId)
end

-- `ded_c_culprit_1` butuh `clue_curator_card` + `clue_guard_off`; keduanya
-- berasal dari `obj_schedule` lewat rantai bukti, dan `obj_schedule` adalah
-- objek pertama dalam urutan deklarasi.
Harness.equal(
	pinpointOf("v_curator", "ded_c_culprit_1"),
	"obj_schedule",
	"pinpoint deduksi kunci v_curator"
)

-- Yang penting untuk kriteria terima: SETIAP deduksi aktif menghasilkan
-- pinpoint, termasuk yang tidak punya `unlocks` sama sekali. Ini yang membuat
-- "satu deduksi 2 kartu membuka pinpoint baru" berlaku umum, bukan kebetulan
-- satu deduksi di data.
local deductionsWithPinpoint = 0
local activeDeductions = 0
for _, node in ipairs(CaseGraph.activeNodes(gallery, "v_curator")) do
	if node.type == "deduction" then
		activeDeductions += 1
		if pinpointOf("v_curator", node.id) ~= nil then
			deductionsWithPinpoint += 1
		end
	end
end
Harness.equal(
	deductionsWithPinpoint,
	activeDeductions,
	string.format("seluruh %d deduksi aktif punya pinpoint", activeDeductions)
)

-- Deduksi yang tidak aktif di varian ini tidak punya pinpoint di sini --
-- cabangnya memang tidak ada.
Harness.equal(
	pinpointOf("v_guard", "ded_c_culprit_1"),
	nil,
	"deduksi varian lain tidak punya pinpoint di varian ini"
)

-- Deduksi tak dikenal tidak melempar galat; ia hanya tidak punya asal.
Harness.equal(
	pinpointOf("v_curator", "ded_tidak_ada"),
	nil,
	"deduksi tak dikenal tidak punya pinpoint"
)

-- Label pinpoint diambil dari node kasusnya (`init.server.luau`), bukan
-- dikarang: yang menyeberang tetap kalimat yang ditulis penulis kasus.
local pinNode = CaseGraph.nodeIndex(gallery)["obj_schedule"]
Harness.equal(
	pinNode ~= nil and pinNode.label,
	"Sobekan jadwal di ruang staf",
	"label pinpoint diambil dari data kasus"
)

Harness.suite("papan Director: masukan yang rusak")

Harness.check(DirectorBoardService.new(CaseGraph, nil, "v_curator") == nil, "kasus nil ditolak")
Harness.check(DirectorBoardService.new(CaseGraph, gallery, "") == nil, "varian kosong ditolak")

Harness.finish("director-board")
