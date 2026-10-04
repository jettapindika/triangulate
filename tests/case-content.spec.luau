--!strict
-- Uji konten kasus nyata: pemilihan varian dari seed dan pemisahan pernyataan
-- antar varian (PRD §10, §4; SOP-02 langkah 9-12).
--
-- Kenapa pakai data kasus yang sebenarnya dan bukan fixture sintetis: yang
-- paling mudah salah pada kasus bervarian bukan kodenya, melainkan datanya.
-- Satu pernyataan pembohong yang lupa diberi `variants` akan muncul di kedua
-- cabang, dan itu langsung membocorkan pelaku cabang yang lain (PRD §10:
-- "Spoiler dari video/wiki jadi tidak berlaku penuh"). Fixture kecil buatan
-- sendiri selalu benar; `data/cases/kersana_01.json` yang ditulis manusia tidak.
--
-- Jalur pemilihan yang diuji di sini adalah `CaseLoader.selectVariant` (hash
-- FNV-1a atas seed) dari `src/shared/case/CaseLoader.luau`. Server memakai
-- `src/server/CaseLoader.pickVariant(roll)` dengan `Random.new`; keduanya
-- memetakan ke daftar varian yang sama, dan yang diuji di sini adalah kontrak
-- datanya, bukan sumber keacakannya.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")
local CaseLoader = require("../src/shared/case/CaseLoader")
local CaseGraph = require("../src/shared/case/CaseGraph")
local Net = require("../src/shared/Net")

local case = serde.decode("json", fs.readFile("data/cases/kersana_01.json"))

local function textsOf(payload: any): { string }
	local out: { string } = {}
	for _, statement in ipairs(payload.statements) do
		table.insert(out, statement.text)
	end
	return out
end

local function containsText(list: { string }, needle: string): boolean
	for _, item in list do
		if string.find(item, needle, 1, true) ~= nil then
			return true
		end
	end
	return false
end

Harness.suite("Konten kasus: seed memilih varian")

-- SOP-02 langkah 9: tabel seed -> varian. Dua seed ini dipilih supaya jatuh ke
-- cabang yang berbeda, dan diverifikasi lewat `hashSeed` yang sebenarnya.
Harness.equal(
	CaseLoader.selectVariant(case, "kasus-1").variant_id,
	"v_bowo",
	"seed kasus-1 memilih v_bowo"
)
Harness.equal(
	CaseLoader.selectVariant(case, "kasus-2").variant_id,
	"v_rani",
	"seed kasus-2 memilih v_rani"
)

-- Determinisme (PRD §10: seluruh pemain satu sesi mendapat cabang yang sama).
Harness.equal(
	CaseLoader.selectVariant(case, "kasus-1").variant_id,
	CaseLoader.selectVariant(case, "kasus-1").variant_id,
	"seed yang sama selalu memberi varian yang sama"
)

-- SOP-02 langkah 10: setiap varian harus benar-benar terpilih pada rentang
-- seed uji. Varian yang tidak pernah muncul berarti cabangnya mati.
local counts: { [string]: number } = {}
local SEEDS = 128
for index = 1, SEEDS do
	local variant = CaseLoader.selectVariant(case, "kasus-" .. tostring(index))
	counts[variant.variant_id] = (counts[variant.variant_id] or 0) + 1
end

Harness.check((counts.v_rani or 0) > 0, "v_rani terpilih pada rentang seed uji")
Harness.check((counts.v_bowo or 0) > 0, "v_bowo terpilih pada rentang seed uji")

-- Distribusi tidak boleh condong: penyelesaian avalanche di `hashSeed` ada
-- justru supaya bit rendah hash tidak hanya mencerminkan byte terakhir seed.
-- Tanpa pemeriksaan ini, `hashSeed` yang kehilangan langkah terakhirnya tetap
-- lulus uji determinisme di atas.
local total = (counts.v_rani or 0) + (counts.v_bowo or 0)
Harness.equal(total, SEEDS, "seluruh seed dipetakan ke salah satu varian")
for _, variantId in { "v_rani", "v_bowo" } do
	local share = (counts[variantId] or 0) / SEEDS
	Harness.check(
		share >= 0.25 and share <= 0.75,
		string.format("%s terpilih pada pangsa wajar rentang seed (%.2f)", variantId, share)
	)
end

Harness.suite("Konten kasus: pernyataan terpisah per varian")

local raniStatements = textsOf(CaseLoader.projectForRole(case, "v_rani", "Director"))
local bowoStatements = textsOf(CaseLoader.projectForRole(case, "v_bowo", "Director"))

-- PRD §4: "Tiap kasus punya 2-3 pernyataan saksi/tersangka, minimal satu
-- berbohong." Tiap varian harus melihat tepat 3, bukan 5 (seluruh berkas).
Harness.equal(#raniStatements, 3, "v_rani melihat 3 pernyataan")
Harness.equal(#bowoStatements, 3, "v_bowo melihat 3 pernyataan")

-- Saksi pembohong cabang ini ada...
Harness.ok(
	containsText(raniStatements, "Aku menutup kotak 27 jam 18.25"),
	"v_rani membawa pernyataan pembohongnya sendiri"
)
Harness.ok(
	containsText(bowoStatements, "Aku tidak pernah masuk bengkel Jumat malam"),
	"v_bowo membawa pernyataan pembohongnya sendiri"
)

-- ...dan pembohong cabang lain TIDAK ada. Ini inti anti-spoiler PRD §10.
Harness.check(
	not containsText(raniStatements, "Aku tidak pernah masuk bengkel Jumat malam"),
	"v_rani tidak membocorkan pembohong v_bowo"
)
Harness.check(
	not containsText(bowoStatements, "Aku menutup kotak 27 jam 18.25"),
	"v_bowo tidak membocorkan pembohong v_rani"
)

-- Saksi jujur pun berbeda antar cabang (kesaksiannya mengikuti jam yang cocok
-- dengan cabang itu), jadi pemisahannya bukan sekadar menyembunyikan pembohong.
Harness.ok(
	containsText(raniStatements, "Aku ke bengkel jam 19.47"),
	"v_rani memakai kesaksian Bowo versi v_rani"
)
Harness.check(
	not containsText(raniStatements, "Aku menutup kotak 27 jam 18.55"),
	"v_rani tidak memakai kesaksian Rani versi v_bowo"
)
Harness.ok(
	containsText(bowoStatements, "Aku menutup kotak 27 jam 18.55"),
	"v_bowo memakai kesaksian Rani versi v_bowo"
)

-- Saksi netral (tanpa `variants`) muncul di kedua cabang.
Harness.ok(
	containsText(raniStatements, "Aku menutup toko jam 17.10"),
	"pernyataan netral muncul di v_rani"
)
Harness.ok(
	containsText(bowoStatements, "Aku menutup toko jam 17.10"),
	"pernyataan netral muncul di v_bowo"
)

-- Proyeksi Director tidak pernah membawa penanda bohong maupun pembantahnya.
local directorPayload = CaseLoader.projectForRole(case, "v_rani", "Director")
Harness.equal(
	#Net.findSecrets(directorPayload),
	0,
	"proyeksi Director bersih dari field rahasia"
)
for _, statement in ipairs(directorPayload.statements) do
	Harness.equal(statement.lie, nil, "pernyataan yang dikirim tidak punya penanda `lie`")
	Harness.equal(statement.contradicted_by, nil, "pernyataan yang dikirim tidak punya `contradicted_by`")
end

-- Searcher dan Handler tidak menerima pernyataan sama sekali.
local searcherPayload = CaseLoader.projectForRole(case, "v_rani", "Searcher")
local handlerPayload = CaseLoader.projectForRole(case, "v_rani", "Handler")
Harness.equal(searcherPayload.statements, nil, "Searcher tidak menerima pernyataan")
Harness.equal(handlerPayload.statements, nil, "Handler tidak menerima pernyataan")

Harness.suite("Konten kasus: ejaan role di proyeksi")

-- Regresi: `ROLE_PROJECTION` berkunci huruf kecil, sedangkan server memanggil
-- `projectForRole` dengan nama role tampilan (`Roles.DIRECTOR` = "Director").
-- Sebelum ejaan dinormalkan, panggilan itu mengembalikan nil secara senyap dan
-- pernyataan per varian tidak pernah sampai ke Director.
local displayDirector = CaseLoader.projectForRole(case, "v_rani", "Director")
Harness.check(displayDirector ~= nil, "proyeksi Director dengan ejaan tampilan ada")
Harness.equal(
	#displayDirector.statements,
	#directorPayload.statements,
	"ejaan tampilan dan huruf kecil memberi pernyataan yang sama"
)
Harness.equal(
	displayDirector.briefing,
	directorPayload.briefing,
	"briefing ikut terbaca dengan ejaan tampilan"
)

local displaySearcher = CaseLoader.projectForRole(case, "v_rani", "Searcher")
Harness.check(displaySearcher ~= nil, "proyeksi Searcher dengan ejaan tampilan ada")
Harness.equal(displaySearcher.briefing, searcherPayload.briefing, "briefing Searcher ejaan tampilan")

Harness.equal(CaseLoader.projectForRole(case, "v_rani", "Kurator"), nil, "role tak dikenal tetap nil")
Harness.equal(CaseLoader.projectForRole(case, "v_rani", 42 :: any), nil, "role bukan string tetap nil")

Harness.suite("Konten kasus: node aktif mengikuti varian")

local raniNodes: { [string]: boolean } = {}
for _, node in ipairs(CaseGraph.activeNodes(case, "v_rani")) do
	raniNodes[node.id] = true
end
local bowoNodes: { [string]: boolean } = {}
for _, node in ipairs(CaseGraph.activeNodes(case, "v_bowo")) do
	bowoNodes[node.id] = true
end

Harness.ok(raniNodes.obj_rak_gudang == true, "v_rani punya rak gudangnya sendiri")
Harness.check(raniNodes.obj_rak_gudang_bowo == nil, "v_rani tidak memuat node khusus v_bowo")
Harness.ok(bowoNodes.obj_rak_gudang_bowo == true, "v_bowo punya rak gudangnya sendiri")
Harness.check(bowoNodes.obj_rak_gudang == nil, "v_bowo tidak memuat node khusus v_rani")

-- Node bersama tetap aktif di kedua cabang (PRD §10: cabang "berbagi aset
-- lokasi dan puzzle").
for _, shared in { "obj_buku_pesanan", "ev_buku_pesanan", "obj_kartu_akses", "ev_log_akses" } do
	Harness.ok(raniNodes[shared] == true, shared .. " aktif di v_rani")
	Harness.ok(bowoNodes[shared] == true, shared .. " aktif di v_bowo")
end

-- Proyeksi Searcher hanya berisi objek: ia menjelajah lokasi, bukan meja.
for _, node in ipairs(searcherPayload.nodes) do
	Harness.equal(node.type, "object", "proyeksi Searcher hanya berisi objek")
end

Harness.suite("Konten kasus: deduksi kunci menutup tiga field tuduhan")

-- PRD §5: "Tiap rantai menopang satu field tuduhan (Pelaku / Motif / Cara)".
for _, variantId in { "v_rani", "v_bowo" } do
	local entry = case.solution[variantId]
	Harness.check(entry ~= nil, string.format("solusi %s ada", variantId))

	local covered: { [string]: boolean } = {}
	for _, deductionId in ipairs(entry.required_deductions) do
		local node = CaseGraph.nodeIndex(case)[deductionId]
		Harness.check(node ~= nil, string.format("%s: deduksi kunci '%s' ada", variantId, deductionId))
		if node ~= nil then
			for _, field in ipairs(node.supports) do
				covered[field] = true
			end
		end
	end

	for _, field in ipairs({ "culprit", "motive", "method" }) do
		Harness.ok(
			covered[field] == true,
			string.format("%s: deduksi kunci menutup field %s", variantId, field)
		)
	end

	-- Gate PRD §5: N deduksi kunci harus sama dengan `key_deductions` kasus.
	Harness.equal(
		#entry.required_deductions,
		case.key_deductions,
		string.format("%s: jumlah deduksi kunci sama dengan gate", variantId)
	)
end

-- Solusi tiap cabang menunjuk pelaku yang berbeda -- kalau tidak, dua cabang
-- bukan dua cabang.
Harness.check(
	case.solution.v_rani.culprit ~= case.solution.v_bowo.culprit,
	"dua varian menuduh pelaku yang berbeda"
)
Harness.check(
	case.solution.v_rani.method ~= case.solution.v_bowo.method,
	"dua varian memakai cara yang berbeda"
)

Harness.finish("case-content")
