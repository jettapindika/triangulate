--!strict
-- Bukti gate minggu 4 (PRD §5, §6, §15; kriteria terima EXTA-57).
--
-- Empat hal yang dibuktikan di sini, semuanya pada `data/cases/gallery_01.json`
-- yang nyata dan modul yang benar-benar dipakai server -- bukan salinan tangan
-- dari aturannya:
--
--   1. payload tiap role bersih dari field solusi (detektor `Net.findSecrets`,
--      ditambah pemindaian NILAI solusi yang tidak dilakukan detektor nama);
--   2. tuduhan yang menembus gerbang ditolak server dan TIDAK memakan jatah
--      percobaan tim;
--   3. umpan balik salah tidak menyebut field mana -- dibuktikan secara
--      struktural: dua tuduhan dengan pola benar yang berbeda menghasilkan
--      payload yang identik;
--   4. tiga percobaan habis -> Cold Case + rekap parsial yang seluruhnya angka.
--
-- Yang TIDAK bisa dibuktikan di sini dan dinyatakan apa adanya: perilaku HUD di
-- Roblox. `src/client/Hud/init.luau` menyentuh `Instance` dan `Player`, jadi ia
-- tidak bisa dimuat `lune`. Yang diuji di sini adalah penegakannya di server --
-- yang memang satu-satunya penegakan yang berarti, karena client bisa diubah.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")

local Config = require("../src/shared/Config")
local Net = require("../src/shared/Net")
local CaseGraph = require("../src/shared/case/CaseGraph")
local AccusationGate = require("../src/server/AccusationGate")
local AccusationService = require("../src/server/AccusationService")
local DeductionEngine = require("../src/server/DeductionEngine")

local gallery = serde.decode("json", fs.readFile("data/cases/gallery_01.json"))

local VARIANTS = { "v_curator", "v_guard" }

local function gateConfig(): AccusationGate.Config
	return {
		contradictionsRequired = Config.MIN_CONTRADICTIONS,
		cleanupSeconds = Config.CLEANUP_SECONDS,
		cleanupPenaltySeconds = Config.CLEANUP_PENALTY_SECONDS,
		cleanupFloorSeconds = Config.CLEANUP_FLOOR_SECONDS,
	}
end

type Case = {
	variantId: string,
	solution: { [string]: any },
	keyIds: { string },
	keyDeductionsRequired: number,
	completed: { [string]: boolean },
	revealed: { [string]: boolean },
	gate: AccusationGate.Session,
	accusation: AccusationService.Session,
	statements: { { id: string, who: string, text: string } },
}

-- Satu sesi seperti yang dirakit `startSession`: daftar Deduksi Kunci dari
-- `solution[variant].required_deductions`, ambang N dari `key_deductions`, dan
-- pernyataan publik yang sudah disaring per varian.
local function newCase(variantId: string, now: number): Case
	local solution = gallery.solution[variantId]
	local keyIds: { string } = {}
	for _, id in solution.required_deductions do
		table.insert(keyIds, id)
	end

	local completed: { [string]: boolean } = {}
	for _, id in keyIds do
		completed[id] = true
	end

	local revealed: { [string]: boolean } = {}
	for _, node in CaseGraph.activeNodes(gallery, variantId) do
		revealed[node.id] = true
	end

	local gate = AccusationGate.newSession(gateConfig(), DeductionEngine.gateOpen, now)

	return {
		variantId = variantId,
		solution = solution,
		keyIds = keyIds,
		keyDeductionsRequired = gallery.key_deductions,
		completed = completed,
		revealed = revealed,
		gate = gate,
		accusation = AccusationService.newSession(
			{ culprit = solution.culprit, motive = solution.motive, method = solution.method },
			Config.ACCUSATION_FIELDS,
			Config.MAX_ACCUSATIONS
		),
		statements = AccusationGate.publicStatements(
			gallery.statements,
			function(statement: any): boolean
				return CaseGraph.statementAppliesTo(statement, variantId)
			end
		),
	}
end

--[[
	Sesi yang seluruh syarat gerbangnya sudah terpenuhi (PRD §5): N Deduksi Kunci
	selesai DAN satu Kontradiksi ditandai.

	Kontradiksinya ditemukan dari data, bukan ditempel: pernyataan pembohong
	(`lie = true`) adalah satu-satunya yang punya `contradicted_by`, dan ia hanya
	berlaku di satu varian. Mencari lewat `statementAppliesTo` membuat uji ini
	ikut benar kalau kelak kasusnya ditulis ulang, alih-alih menempel pada
	indeks array.

	Sesi yang gerbangnya MASIH tertutup dibuat dengan merobohkan satu syaratnya
	(`completed = {}` atau gate yang belum ditandai), bukan dengan mengubah
	ambangnya -- yang diuji harus tetap ambang asli dari `Config` dan data kasus.
]]
local function openCase(variantId: string, now: number): Case
	local current = newCase(variantId, now)
	local marked = false

	for index, statement in gallery.statements do
		if statement.lie == true and CaseGraph.statementAppliesTo(statement, variantId) then
			marked = AccusationGate.markContradiction(
				current.gate,
				AccusationGate.statementId(index),
				statement,
				statement.contradicted_by,
				{ [statement.contradicted_by] = true }
			)
			break
		end
	end

	assert(marked, "kasus harus punya pernyataan pembohong di varian ini")
	return current
end

--[[
	Payload `session_state`, disusun dengan urutan yang sama seperti
	`sessionStatePayload` di `init.server.luau`.

	Envelope-nya memang diulang di sini -- glue-nya tidak bisa dimuat `lune`.
	Yang penting: seluruh NILAI yang menyeberang berasal dari modul asli
	(`AccusationGate`, `CaseGraph`), dan yang menguji kebocorannya adalah
	`Net.forRole` + `Net.findSecrets` yang asli juga.
]]
local function sessionStatePayload(current: Case, role: string, now: number): { [string]: any }
	local active = CaseGraph.activeNodes(gallery, current.variantId)
	local done = AccusationGate.keyDeductionsDone(current.completed, current.keyIds)

	local revealed: { [string]: boolean } = {}
	local deductionsDone = 0
	for _, node in active do
		if current.revealed[node.id] == true then
			revealed[node.id] = true
			if node.type == "deduction" then
				deductionsDone += 1
			end
		end
	end

	return {
		case_id = gallery.case_id,
		role = role,
		phase = "Investigasi",
		seconds_left = Config.RANK_BUDGET_SECONDS,
		chains = {},
		deductions_done = deductionsDone,
		key_deductions_required = current.keyDeductionsRequired,
		key_deductions_done = done,
		contradictions_marked = current.gate.contradictionsMarked,
		contradictions_required = current.gate.config.contradictionsRequired,
		gate_open = AccusationGate.gateOpen(current.gate, done, current.keyDeductionsRequired),
		cleanup_seconds_left = AccusationGate.cleanupSecondsLeft(current.gate, now),
		cold_case_recap = AccusationGate.recap(current.gate, {
			active_nodes = active,
			common_ids = AccusationGate.commonNodeIds(
				gallery.nodes,
				CaseGraph.variantIds(gallery),
				CaseGraph.isActive
			),
			revealed = revealed,
			key_deductions_done = done,
			key_deductions_required = current.keyDeductionsRequired,
			attempts_used = current.accusation.attemptsUsed,
		}),
	}
end

-- Mengumpulkan seluruh string di dalam sebuah payload, sedalam apa pun.
local function stringsIn(value: any, out: { string }): { string }
	if type(value) == "string" then
		table.insert(out, value)
	elseif type(value) == "table" then
		for _, child in value :: { [any]: any } do
			stringsIn(child, out)
		end
	end
	return out
end

local function solutionValues(variantId: string): { string }
	local solution = gallery.solution[variantId]
	return { solution.culprit, solution.motive, solution.method }
end

-- Nama field tuduhan DAN nilai solusinya. Detektor `Net.findSecrets` hanya
-- menangkap nama field; yang ini menangkap kebocoran lewat nilai, misalnya
-- pelaku yang ikut terkirim sebagai teks di dalam rekap.
local function leakedSolutionText(value: any, variantId: string): { string }
	local hits: { string } = {}
	for _, text in stringsIn(value, {}) do
		for _, field in Config.ACCUSATION_FIELDS do
			if text == field then
				table.insert(hits, text)
			end
		end
		for _, candidate in solutionValues(variantId) do
			if text == candidate then
				table.insert(hits, text)
			end
		end
		if string.match(text, "^ded_") ~= nil then
			table.insert(hits, text)
		end
	end
	return hits
end

--[[
	Satu tuduhan seperti yang dijalankan `handleAccuse`: gerbang diperiksa
	SEBELUM `AccusationService.submit`.

	Urutannya sendiri yang sedang diuji -- itu sebabnya percobaan yang ditolak
	gerbang tidak boleh menaikkan `attemptsUsed`. Glue di `init.server.luau`
	tidak bisa dimuat `lune`, jadi komposisinya ditulis ulang di sini dan
	hasilnya diuji pada modul aslinya.
]]
local function attempt(
	current: Case,
	accusation: { [string]: any }
): (boolean, AccusationService.Result?)
	local done = AccusationGate.keyDeductionsDone(current.completed, current.keyIds)
	local admitted = AccusationGate.admit(current.gate, done, current.keyDeductionsRequired)
	if not admitted then
		return false, nil
	end
	return true, AccusationService.submit(current.accusation, accusation)
end

-- ---------------------------------------------------------------------------

Harness.suite("gerbang: tertutup sampai syaratnya terpenuhi")

local curator = openCase("v_curator", 1000)

-- Tanpa satu pun Deduksi Kunci selesai.
local emptyCase = newCase("v_curator", 1000)
emptyCase.completed = {}
local admitted, reason = AccusationGate.admit(
	emptyCase.gate,
	AccusationGate.keyDeductionsDone(emptyCase.completed, emptyCase.keyIds),
	emptyCase.keyDeductionsRequired
)
Harness.check(not admitted, "gerbang tertutup saat belum ada Deduksi Kunci selesai")
Harness.check(
	reason ~= nil and string.find(reason, "Deduksi Kunci") ~= nil,
	string.format("alasan menyebut Deduksi Kunci: %s", tostring(reason))
)

-- Deduksi Kunci lengkap tapi belum ada Kontradiksi: PRD §5 menuntut keduanya.
local noContradiction = newCase("v_curator", 1000)
local doneFull = AccusationGate.keyDeductionsDone(noContradiction.completed, noContradiction.keyIds)
Harness.equal(doneFull, gallery.key_deductions, "seluruh Deduksi Kunci varian terhitung")
Harness.check(
	not AccusationGate.admit(noContradiction.gate, doneFull, noContradiction.keyDeductionsRequired),
	"gerbang tetap tertutup tanpa satu pun Kontradiksi"
)

-- Penandaan dengan bukti yang keliru ditolak. Client tidak lagi mengirim id
-- bukti -- server yang membacanya dari data kasus -- tapi gerbang tetap harus
-- menolak pasangan yang tidak cocok: itu penjaga terakhir bila kelak ada jalur
-- lain yang memanggilnya.
local wrongMark = AccusationGate.markContradiction(
	noContradiction.gate,
	"stmt_1",
	gallery.statements[1],
	"clue_salah",
	{ clue_salah = true }
)
Harness.check(not wrongMark, "kontradiksi dengan bukti yang keliru ditolak")
Harness.equal(
	noContradiction.gate.contradictionsMarked,
	0,
	"penandaan keliru tidak menambah hitungan"
)
Harness.check(
	not AccusationGate.admit(noContradiction.gate, doneFull, noContradiction.keyDeductionsRequired),
	"gerbang masih tertutup setelah penandaan keliru"
)

-- PRD §4: Kontradiksi adalah hasil kerja tim, bukan tebakan. Pernyataan yang
-- memang dibantah bukti tetap ditolak selama bukti pembantahnya BELUM
-- dikumpulkan; tanpa syarat itu Director bisa menandai semua pernyataan sejak
-- detik pertama dan gerbang tuduhan (PRD §5) terbuka tanpa satu pun deduksi.
local liar = gallery.statements[1]
local tooEarly, tooEarlyCorrect =
	AccusationGate.markContradiction(noContradiction.gate, "stmt_1", liar, liar.contradicted_by, {})
Harness.check(not tooEarly, "pembohong tanpa bukti pembantah ditolak")
Harness.check(
	not tooEarlyCorrect,
	"penolakan itu bukan 'sudah ditandai' -- dua mode kegagalan berbeda pesannya"
)
Harness.equal(
	noContradiction.gate.contradictionsMarked,
	0,
	"penandaan terlalu dini tidak menambah hitungan"
)

-- Penandaan yang benar membukanya, dan idempoten.
local obtained: { [string]: boolean } = { [liar.contradicted_by] = true }
local correctMark = AccusationGate.markContradiction(
	noContradiction.gate,
	"stmt_1",
	liar,
	liar.contradicted_by,
	obtained
)
Harness.check(correctMark, "kontradiksi yang benar diterima")
Harness.equal(noContradiction.gate.contradictionsMarked, 1, "hitungan Kontradiksi naik satu")
Harness.ok(
	AccusationGate.admit(noContradiction.gate, doneFull, noContradiction.keyDeductionsRequired),
	"gerbang terbuka setelah N Deduksi Kunci + 1 Kontradiksi"
)

local again = AccusationGate.markContradiction(
	noContradiction.gate,
	"stmt_1",
	liar,
	liar.contradicted_by,
	obtained
)
Harness.check(not again, "penandaan ulang pernyataan yang sama tidak dihitung baru")
Harness.equal(
	noContradiction.gate.contradictionsMarked,
	1,
	"hitungan tidak bertambah oleh pengulangan"
)

--[[
	Kontrak id pernyataan di kabel.

	`handleMarkContradiction` menerima `stmt_<n>`, memetakan `n` kembali ke
	indeks array `case.statements`, lalu membaca `contradicted_by` dari sana.
	Rantai itu hanya benar kalau id yang dirakit `publicStatements` memang
	indeks aslinya -- bukan nomor urut hasil penyaringan. Dua pernyataan di
	`gallery_01.json` hanya berlaku di satu varian, jadi penyaringan memang
	menggeser urutan; inilah yang membuat penggeseran itu tidak merusak
	pemetaan balik.
]]
local stmtIds = AccusationGate.publicStatements(
	gallery.statements,
	function(statement: any): boolean
		return CaseGraph.statementAppliesTo(statement, "v_curator")
	end
)
local stmtIndexes: { number } = {}
for _, entry in stmtIds do
	table.insert(stmtIndexes, tonumber(string.match(entry.id, "^stmt_(%d+)$")) or -1)
end
Harness.equal(
	table.concat(stmtIndexes, ","),
	"1,3,4",
	"id memakai indeks asli, bukan urutan tersaring"
)
Harness.check(
	gallery.statements[stmtIndexes[1]].contradicted_by ~= nil,
	"indeks pertama varian ini memang pembohongnya"
)

-- Deduksi cabang lain tidak boleh ikut terhitung: `keyDeductionsDone` adalah
-- irisan dengan daftar milik varian, bukan hitungan mentah.
local crossBranch: { [string]: boolean } = {}
for _, id in curator.keyIds do
	crossBranch[id] = true
end
for _, node in gallery.nodes do
	if node.type == "deduction" then
		crossBranch[node.id] = true
	end
end
Harness.equal(
	AccusationGate.keyDeductionsDone(crossBranch, curator.keyIds),
	gallery.key_deductions,
	"deduksi cabang lain tidak menambah hitungan Deduksi Kunci"
)

Harness.suite("pernyataan publik: bohong dan pembantah tidak ikut")

local curatorStatements = curator.statements
local ids: { string } = {}
for _, statement in curatorStatements do
	table.insert(ids, statement.id)
end
table.sort(ids)
Harness.equal(
	ids,
	{ "stmt_1", "stmt_3", "stmt_4" },
	"pernyataan varian curator memakai indeks akar yang stabil"
)
Harness.equal(
	#Net.findSecrets(curatorStatements, "statements"),
	0,
	"daftar pernyataan publik bersih dari `lie` dan `contradicted_by`"
)
Harness.equal(#curatorStatements, 3, "empat pernyataan akar menjadi tiga di varian ini")

local guardCase = newCase("v_guard", 1000)
local guardIds: { string } = {}
for _, statement in guardCase.statements do
	table.insert(guardIds, statement.id)
end
table.sort(guardIds)
Harness.equal(guardIds, { "stmt_2", "stmt_3", "stmt_4" }, "varian guard menukar pembohongnya")

Harness.suite("tuduhan menembus gerbang ditolak tanpa memakan percobaan")

local piercing = newCase("v_curator", 1000)
piercing.completed = {}
local piercingAccusation = {
	culprit = piercing.solution.culprit,
	motive = piercing.solution.motive,
	method = piercing.solution.method,
}

-- Lima tuduhan berturut-turut dari client yang menembak sebelum gerbangnya
-- terbuka. Tidak satu pun boleh tercatat.
local acceptedPiercing = 0
for _ = 1, 5 do
	local ok = attempt(piercing, piercingAccusation)
	if ok then
		acceptedPiercing += 1
	end
end
Harness.equal(acceptedPiercing, 0, "tidak ada tuduhan yang lolos sebelum gerbang terbuka")
Harness.equal(piercing.accusation.attemptsUsed, 0, "jatah percobaan tim tidak tersentuh")
Harness.equal(piercing.accusation.correctFieldCount, 0, "tidak ada field yang dinilai")
Harness.check(not piercing.accusation.resolved, "kasus belum ditutup oleh percobaan yang ditolak")

-- Gerbang dibuka pada sesi yang sama: sekarang tuduhan yang sama diproses dan
-- MEMAKAN satu percobaan. Tanpa langkah ini, "nol percobaan" di atas bisa berarti
-- "submit-nya memang tidak pernah jalan", bukan "gerbangnya menahan".
local opened = openCase("v_curator", 1000)
local openedAdmitted, openedResult = attempt(
	opened,
	{ culprit = opened.solution.culprit, motive = opened.solution.motive, method = "forged_log" }
)
Harness.ok(openedAdmitted, "tuduhan diterima setelah gerbang terbuka")
Harness.equal(
	opened.accusation.attemptsUsed,
	1,
	"tuduhan yang lolos gerbang memakai satu percobaan"
)
Harness.check(openedResult ~= nil and openedResult.accepted, "hasil tuduhan dikembalikan")

Harness.suite("umpan balik salah tidak menyebut field mana")

local function resultPayload(result: AccusationService.Result)
	return {
		correct_count = result.correctCount,
		attempts_left = result.attemptsLeft,
		resolved = result.resolved,
		won = result.won,
		pending_confirmation = result.pendingConfirmation,
		rank = nil,
	}
end

-- Dua pola yang berbeda tapi sama-sama "1 dari 3 benar": pelaku saja, dan cara
-- saja. Kalau payload yang menyeberang berbeda, pemain bisa menyimpulkan field
-- mana yang benar dari perbedaannya.
local fieldA = newCase("v_curator", 1000)
local resultA = AccusationService.submit(fieldA.accusation, {
	culprit = fieldA.solution.culprit,
	motive = "greed",
	method = "forged_log",
})

local fieldB = newCase("v_curator", 1000)
local resultB = AccusationService.submit(fieldB.accusation, {
	culprit = "collector",
	motive = "greed",
	method = fieldB.solution.method,
})

Harness.equal(resultA.correctCount, 1, "pola pertama: satu field benar")
Harness.equal(resultB.correctCount, 1, "pola kedua: satu field benar")
Harness.equal(
	resultPayload(resultA),
	resultPayload(resultB),
	"dua pola benar yang berbeda menghasilkan payload identik"
)

for _, role in { "Searcher", "Handler", "Director" } do
	local projected = Net.forRole("accusation_result", role, resultPayload(resultA))
	assert(projected ~= nil, "proyeksi harus ada")
	Harness.equal(
		#Net.findSecrets(projected, string.format("accusation_result/%s", role)),
		0,
		string.format("accusation_result/%s bersih dari field rahasia", role)
	)
	Harness.equal(
		leakedSolutionText(projected, "v_curator"),
		{},
		string.format("accusation_result/%s tidak memuat nama field atau nilai solusi", role)
	)
end

-- `reason` pada hasil memang ada, tapi ia hanya untuk log server: yang dikirim
-- ke client adalah payload di atas, bukan hasil mentahnya.
Harness.check(resultA.reason == nil, "tuduhan yang sah tidak membawa alasan yang bisa dibocorkan")

-- Director menerima status kasus; Searcher dan Handler tidak, supaya mereka
-- tidak bisa membaca hasil dari payload mereka sendiri (PRD §5: tuduhan milik
-- Director). Yang dibandingkan adalah himpunan kuncinya, bukan keberadaan satu
-- field -- bedanya itulah kontraknya.
local function keysOf(value: { [string]: any }): { string }
	local keys: { string } = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local directorResult = Net.forRole("accusation_result", "Director", resultPayload(resultA))
local searcherResult = Net.forRole("accusation_result", "Searcher", resultPayload(resultA))
assert(directorResult ~= nil and searcherResult ~= nil, "proyeksi kedua role harus ada")
Harness.equal(keysOf(directorResult), {
	"attempts_left",
	"correct_count",
	"pending_confirmation",
	"resolved",
	"won",
}, "rank tidak dikirim selama kasus belum berakhir")

-- Payload yang sudah berakhir memang membawa `rank`; tanpa pemeriksaan ini,
-- "rank tidak dikirim" di atas juga lolos kalau allowlist-nya salah ketik.
local resolvedPayload = resultPayload(resultA)
resolvedPayload.rank = "B"
local resolvedDirector = Net.forRole("accusation_result", "Director", resolvedPayload)
assert(resolvedDirector ~= nil, "proyeksi Director harus ada")
Harness.equal(keysOf(resolvedDirector), {
	"attempts_left",
	"correct_count",
	"pending_confirmation",
	"rank",
	"resolved",
	"won",
}, "Director menerima rank saat kasus berakhir")

Harness.equal(
	keysOf(searcherResult),
	{ "attempts_left", "correct_count" },
	"Searcher hanya menerima jumlah benar dan sisa percobaan"
)

Harness.suite("tiga percobaan habis: Cold Case dan rekap parsial")

local cold = openCase("v_curator", 1000)
local wrongAccusation = { culprit = "collector", motive = "greed", method = "forged_log" }

-- Sebagian bukti sengaja dibiarkan belum terbuka. Tanpa ini, "3 dari 3" dan
-- "6 dari 6" sama-sama lolos, dan angka yang tidak pernah beda tidak
-- membuktikan apa-apa.
local hidden = 0
for _, node in CaseGraph.activeNodes(gallery, cold.variantId) do
	if node.type == "evidence" and hidden < 2 then
		cold.revealed[node.id] = nil
		hidden += 1
	end
end
Harness.equal(hidden, 2, "dua bukti dibiarkan belum terbuka")

local firstAdmitted, firstWrong = attempt(cold, wrongAccusation)
Harness.ok(firstAdmitted, "percobaan pertama lolos gerbang")
assert(firstWrong ~= nil, "hasil percobaan pertama harus ada")
Harness.check(not firstWrong.resolved, "percobaan pertama yang salah belum menutup kasus")

local secondAdmitted, secondWrong = attempt(cold, wrongAccusation)
Harness.ok(secondAdmitted, "percobaan kedua lolos gerbang")
assert(secondWrong ~= nil, "hasil percobaan kedua harus ada")
Harness.check(not secondWrong.resolved, "percobaan kedua yang salah belum menutup kasus")

local thirdAdmitted, thirdWrong = attempt(cold, wrongAccusation)
Harness.ok(thirdAdmitted, "percobaan ketiga lolos gerbang")
assert(thirdWrong ~= nil, "hasil percobaan ketiga harus ada")
Harness.ok(thirdWrong.resolved, "percobaan ketiga yang salah menutup kasus")
Harness.check(not thirdWrong.won, "kasus yang habis percobaan bukan kemenangan")
Harness.equal(thirdWrong.attemptsLeft, 0, "tidak ada percobaan tersisa")
Harness.equal(
	AccusationService.rank(600, cold.accusation.attemptsUsed, 0, Config.RANK_BUDGET_SECONDS),
	"C",
	"kasus Cold Case berakhir di rank terendah"
)

local coldPayload = sessionStatePayload(cold, "Director", 1000)
local recap = coldPayload.cold_case_recap
assert(recap ~= nil, "rekap Cold Case harus ada di payload")

Harness.equal(recap.attempts_used, 3, "rekap mencatat tiga percobaan terpakai")
Harness.equal(
	recap.key_deductions_done,
	gallery.key_deductions,
	"rekap mencatat Deduksi Kunci selesai"
)
Harness.equal(
	recap.key_deductions_required,
	gallery.key_deductions,
	"rekap mencatat ambang Deduksi Kunci"
)
Harness.equal(
	recap.evidence_total,
	6,
	"penyebut bukti hanya menghitung node yang sama di semua cabang"
)
Harness.equal(
	recap.evidence_found,
	recap.evidence_total - hidden,
	"pembilang bukti menghitung yang benar-benar terbuka"
)
Harness.equal(recap.contradictions_marked, 1, "rekap mencatat Kontradiksi yang sudah ditandai")

-- Kunci rekap dipatok persis. SOP-03 A.2 mewajibkan rekap menyebut bukti,
-- deduksi, dan kontradiksi; daftar ini yang menjaganya tetap begitu, sekaligus
-- menahan penambahan field baru yang bisa membocorkan sesuatu.
local recapKeys: { string } = {}
for key in recap do
	table.insert(recapKeys, key)
end
table.sort(recapKeys)
Harness.equal(recapKeys, {
	"attempts_used",
	"contradictions_marked",
	"evidence_found",
	"evidence_total",
	"key_deductions_done",
	"key_deductions_required",
}, "rekap hanya memuat angka yang dijanjikan SOP-03 A.2")

-- Seluruh nilai rekap harus angka. Satu string saja sudah cukup untuk
-- membocorkan sesuatu (nama node, nama pelaku).
for key, value in recap do
	Harness.check(type(value) == "number", string.format("rekap '%s' berupa angka", key))
end

-- Varian kedua memberi penyebut yang SAMA. Kalau berbeda, "6 dari 7" versus
-- "6 dari 6" sudah menyebut cabang mana yang sedang berjalan.
local coldGuard = openCase("v_guard", 1000)
for _ = 1, 3 do
	attempt(coldGuard, wrongAccusation)
end
local guardRecap = sessionStatePayload(coldGuard, "Director", 1000).cold_case_recap
assert(guardRecap ~= nil, "rekap varian guard harus ada")
Harness.equal(
	guardRecap.evidence_total,
	recap.evidence_total,
	"penyebut bukti identik di kedua cabang"
)

Harness.suite("penalti cleanup: 90 detik, -30 tiap salah, lantai 30")

Harness.equal(Config.CLEANUP_SECONDS, 90, "timer cleanup dasar 90 detik")
Harness.equal(Config.CLEANUP_PENALTY_SECONDS, 30, "penalti 30 detik per tuduhan salah")
Harness.equal(Config.CLEANUP_FLOOR_SECONDS, 30, "lantai 30 detik")

local timed = newCase("v_curator", 1000)
Harness.equal(
	AccusationGate.cleanupSecondsLeft(timed.gate, 1000),
	Config.CLEANUP_SECONDS,
	"timer mulai dari 90 detik"
)
Harness.equal(
	AccusationGate.applyWrongPenalty(timed.gate, 1000),
	60,
	"salah pertama memajukan 30 detik"
)
Harness.equal(
	AccusationGate.applyWrongPenalty(timed.gate, 1000),
	30,
	"salah kedua memajukan 30 detik lagi"
)
Harness.equal(
	AccusationGate.applyWrongPenalty(timed.gate, 1000),
	Config.CLEANUP_FLOOR_SECONDS,
	"salah ketiga berhenti di lantai 30 detik"
)

-- Timer berjalan dengan waktu, bukan hanya turun oleh penalti.
Harness.equal(
	AccusationGate.cleanupSecondsLeft(timed.gate, 1010),
	20,
	"timer menghitung sisa waktu nyata"
)
Harness.equal(
	AccusationGate.cleanupSecondsLeft(timed.gate, 9999),
	0,
	"sisa waktu tidak pernah negatif"
)

Harness.suite("kebocoran: payload tiap role di sesi nyata")

local leakChecks = 0
local leakHits = 0

for _, variantId in VARIANTS do
	for _, role in { "Searcher", "Handler", "Director" } do
		local current = openCase(variantId, 1000)

		local payload = sessionStatePayload(current, role, 1000)
		local projected = Net.forRole("session_state", role, payload)
		local where = string.format("session_state/%s/%s", variantId, role)
		Harness.check(projected ~= nil, string.format("%s punya proyeksi", where))
		if projected ~= nil then
			leakChecks += 2
			local fieldHits = #Net.findSecrets(projected, where)
			local valueHits = #leakedSolutionText(projected, variantId)
			leakHits += fieldHits + valueHits
			Harness.equal(fieldHits, 0, string.format("%s bersih dari field solusi", where))
			Harness.equal(
				valueHits,
				0,
				string.format("%s bersih dari nilai solusi dan id deduksi", where)
			)
		end
	end
end

-- Sisi lain dari kebocoran: yang MEMANG harus sampai. Tanpa ini, "bersih" bisa
-- berarti "payloadnya kosong".
local directorView =
	Net.forRole("session_state", "Director", sessionStatePayload(curator, "Director", 1000))
local searcherView =
	Net.forRole("session_state", "Searcher", sessionStatePayload(curator, "Searcher", 1000))
assert(directorView ~= nil and searcherView ~= nil, "proyeksi kedua role harus ada")

Harness.equal(directorView.gate_open, true, "Director melihat gerbangnya terbuka")
Harness.equal(
	directorView.key_deductions_done,
	gallery.key_deductions,
	"Director melihat progres deduksi"
)
Harness.check(directorView.cold_case_recap ~= nil, "Director menerima rekap Cold Case")
Harness.equal(searcherView.gate_open, nil, "Searcher tidak menerima status gerbang")
Harness.equal(
	searcherView.key_deductions_done,
	nil,
	"Searcher tidak menerima progres Deduksi Kunci"
)
Harness.check(searcherView.cold_case_recap ~= nil, "Searcher tetap menerima rekap parsial")
Harness.equal(
	searcherView.cleanup_seconds_left,
	Config.CLEANUP_SECONDS,
	"Searcher melihat timer cleanup"
)

-- Ringkasan eksplisit: `Harness.check` hanya bersuara saat gagal, jadi tanpa
-- baris ini keluarannya tidak menunjukkan berapa yang diperiksa. Angka
-- kebocoran dihitung dari pemeriksaan di atas, bukan ditulis tangan.
print(
	string.format(
		"accusation-gate: %d varian x 3 role payload bersih (%d pemeriksaan, %d temuan); rekap %d dari %d bukti; Cold Case di percobaan ke-%d",
		#VARIANTS,
		leakChecks,
		leakHits,
		recap.evidence_found,
		recap.evidence_total,
		recap.attempts_used
	)
)

Harness.finish("accusation-gate")
