--!strict
-- Uji kebocoran solusi lintas lapisan (PRD §15, kriteria terima EXTA-54).
--
-- `net.spec.luau` menguji `Net` dengan data sintetis dan `case-loader.spec.luau`
-- menguji proyeksi EXTA-33. Yang belum terjaga: payload yang benar-benar
-- menyeberang, yaitu `briefings` (field yang ditambahkan saat integrasi stage 1)
-- yang dirakit `init.server.luau` lalu dilewatkan `Net.forRole`. Itu yang
-- diuji di sini, untuk seluruh pasangan view x role.
--
-- Dua kontrol menjaga uji ini tidak vacuous: data mentah dan `session` harus
-- menghasilkan temuan, dan payload yang sengaja dirusak harus ketahuan.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")

local Net = require("../src/shared/Net")
local CaseLoader = require("../src/shared/case/CaseLoader")
local PuzzleTable = require("../src/shared/PuzzleTable")
local DirectorBoardService = require("../src/server/DirectorBoardService")

local gallery = serde.decode("json", fs.readFile("data/cases/gallery_01.json"))
local load = CaseLoader.load(gallery, "seed-kebocoran")
assert(load.ok, "kasus gabungan harus lolos validator")

local solution = load.session.solution

local nodeById: { [string]: any } = {}
for _, node in ipairs(gallery.nodes) do
	nodeById[node.id] = node
end
assert(nodeById["clue_guard_off"] ~= nil, "fixture harus punya clue_guard_off")

-- Payload per view, bentuknya sama dengan yang dirakit `init.server.luau`.
-- Beberapa view sengaja disuntik field rahasia supaya terbukti proyeksinya
-- benar-benar menyaring, bukan sekadar tidak diberi apa-apa.
local function payloadFor(view: string, role: string): { [string]: any }
	if view == "briefing" then
		return gallery.briefings[role]
	elseif view == "clue_card" then
		local node = nodeById["clue_guard_off"]
		return {
			id = node.id,
			title = node.id,
			summary = "Satpam off duty 21.00",
			source = node.source,
		}
	elseif view == "deduction" then
		return {
			id = "ded_a_1",
			pinpoint = "pin_office",
			unlocks = { "obj_ledger" },
			clue_ids = { "clue_guard_off", "clue_card_log" },
		}
	elseif view == "pinpoint" then
		return {
			id = "obj_ledger",
			label = "Buku kas tersembunyi di belakang lukisan",
			culprit = solution.culprit,
		}
	elseif view == "contradiction_result" then
		return {
			accepted = false,
			statement_id = 3,
			reason = DirectorBoardService.REJECT_REASON,
			marked_count = 0,
			contradictions_required = 1,
			deductions_done = 1,
			key_deductions_required = gallery.key_deductions,
			gate_open = false,
			lie = true,
		}
	elseif view == "table_preview" then
		return {
			entries = {
				{
					puzzle_id = "torn_doc:ev_schedule",
					puzzle_type = "torn_doc",
					placed = 1,
					total = 4,
					solved = false,
				},
			},
			culprit = solution.culprit,
		}
	elseif view == "session_state" then
		return {
			case_id = gallery.case_id,
			role = role,
			phase = "Investigasi",
			seconds_left = 600,
			chains = { { id = "A", done = false } },
			deductions_done = 0,
			key_deductions_required = gallery.key_deductions,
			solution = solution,
			culprit = solution.culprit,
		}
	elseif view == "report_card" then
		return {
			id = "rc_1",
			object_id = "obj_schedule",
			label = "Jadwal jaga",
			location = "staff_room",
			image = "rbxassetid://0",
			gives_key = "key_a",
		}
	elseif view == "target_marker" then
		return {
			target_id = "obj_schedule",
			label = "Jadwal jaga",
			bearing = 45,
			culprit = solution.culprit,
		}
	elseif view == "ping" then
		return {
			from_role = "Handler",
			phrase_id = "target",
			label = "Cari benda bertanda ini",
			lie = true,
		}
	elseif view == "accusation_result" then
		return {
			correct_count = 2,
			attempts_left = 2,
			resolved = false,
			won = false,
			pending_confirmation = true,
			rank = "B",
			culprit = solution.culprit,
		}
	elseif view == "accusation_options" then
		return { suspects = gallery.suspects, motives = gallery.motives, methods = gallery.methods }
	elseif view == "puzzle_state" then
		-- Payload dirakit oleh builder yang sama yang dipakai server, supaya uji
		-- ini benar-benar menguji apa yang menyeberang, bukan salinan tangan.
		local board = PuzzleTable.newBoard(4, 4, 8, 8)
		local puzzleState = PuzzleTable.newState("torn_doc:ev_schedule", board, { 0, 1, 2, 3 })
		return PuzzleTable.clientPayload(puzzleState)
	elseif view == "piece_placed" then
		return {
			piece_id = "torn_doc:ev_schedule:0",
			x = 1.5,
			y = 2.5,
			placed = true,
			accepted = true,
		}
	end

	error(string.format("view %s belum punya payload uji", view))
end

Harness.suite("kebocoran: seluruh view x role")

local pairsChecked = 0
local findings = 0
for view, byRole in Net.CLIENT_VIEWS do
	for role in byRole do
		local where = string.format("%s/%s", view, role)
		local projected = Net.forRole(view, role, payloadFor(view, role))
		Harness.check(projected ~= nil, string.format("kebocoran: %s punya proyeksi", where))
		if projected ~= nil then
			local found = Net.findSecrets(projected, where)
			Harness.check(
				#found == 0,
				string.format(
					"kebocoran: %s bersih (%s)",
					where,
					if #found == 0 then "0 temuan" else table.concat(found, ", ")
				)
			)
			pairsChecked += 1
			findings += #found
		end
	end
end

-- 34 pasangan view x role dari 14 view:
--   * 8 view x 3 role = 24 -- `briefing`, `clue_card`, `deduction`,
--     `session_state`, `report_card`, `ping`, `accusation_result`,
--     `accusation_options`;
--   * 4 view x 2 role = 8 -- `pinpoint` tanpa Handler (PRD §3: ia di meja,
--     bukan di lokasi), `target_marker` tanpa Director (PRD §7: ia tidak
--     melihat dunia Searcher), dan `puzzle_state`/`piece_placed` tanpa
--     Searcher (PRD §4: meja milik Handler; §8: Director boleh mengambil alih
--     puzzle manual di mode 2 pemain);
--   * 2 view x 1 role = 2 -- `contradiction_result` dan `table_preview`, hanya
--     Director.
-- Pasangan yang tidak ada itu sengaja: `Net.forRole` mengembalikan nil untuknya,
-- dan nil berarti "jangan kirim", bukan kelalaian.
Harness.check(
	pairsChecked == 34,
	string.format("kebocoran: 14 view x role tersapu (terperiksa: %d)", pairsChecked)
)

Harness.suite("kebocoran: kontrol detektor")

local rawHits = Net.findSecrets(gallery, "raw")
Harness.check(#rawHits > 0, string.format("kontrol: data mentah punya temuan (%d)", #rawHits))

local sessionHits = Net.findSecrets(load.session, "session")
Harness.check(#sessionHits > 0, string.format("kontrol: session punya temuan (%d)", #sessionHits))

-- Mode kegagalan yang paling mungkin: `briefings.Director.statements` keliru
-- diisi dari `case.statements` akar, yang memuat `lie` dan `contradicted_by`.
local badBriefing = {
	case_id = gallery.case_id,
	location = gallery.location,
	objective = "x",
	knowns = { "y" },
	unknowns = { "z" },
	statements = gallery.statements,
}
local badHits =
	Net.findSecrets(Net.forRole("briefing", "Director", badBriefing), "briefing.Director")
Harness.check(
	#badHits > 0,
	string.format("kontrol: statements akar terdeteksi di view briefing (%d)", #badHits)
)

-- Mode kegagalan yang sama untuk pernyataan saksi: `Net` menyalin nilai apa
-- adanya, jadi kalau daftar pernyataan diisi langsung dari `case.statements`
-- (tanpa lewat `CaseLoader.projectForRole`), `lie` dan `contradicted_by` ikut
-- menyeberang di dalam item list. Sweep di atas memakai payload briefing yang
-- ditulis tangan dan memang bersih; kontrol ini membuktikan detektornya memang
-- bisa melihat pelanggarannya.
local rawStatementHits = Net.findSecrets(
	Net.forRole("briefing", "Director", { statements = gallery.statements }),
	"briefing.Director.raw"
)
Harness.check(
	#rawStatementHits > 0,
	string.format("kontrol: pernyataan mentah terdeteksi di view briefing (%d)", #rawStatementHits)
)

-- Dan jalur produksinya bersih: `CaseLoader.projectForRole` yang merakit daftar
-- pernyataan Director, dan hasilnya hanya membawa `id`, `who`, `text`.
local projectedDirector = CaseLoader.projectForRole(gallery, load.session.variant_id, "Director")
assert(projectedDirector ~= nil, "proyeksi Director harus terbentuk")
Harness.check(
	#Net.findSecrets(
			Net.forRole("briefing", "Director", projectedDirector),
			"briefing.Director.projected"
		) == 0,
	"kontrol: proyeksi pernyataan dari projectForRole bersih"
)
Harness.check(
	#projectedDirector.statements > 0 and projectedDirector.statements[1].id ~= nil,
	string.format(
		"kontrol: proyeksi pernyataan membawa id (%d pernyataan)",
		#projectedDirector.statements
	)
)

local viewsOk, viewProblems = Net.validateViews()
Harness.check(
	viewsOk,
	string.format(
		"kontrol: tidak ada view yang mengizinkan field rahasia (%d masalah)",
		#viewProblems
	)
)

-- Kontrol khusus view meja puzzle: payload yang BENAR-BENAR berisi potongan
-- harus lolos, dan payload yang disuntik field rahasia harus ketahuan. Tanpa
-- dua assertion ini, `puzzle_state` bisa "bersih" hanya karena payloadnya
-- kosong.
local board = PuzzleTable.newBoard(4, 4, 8, 8)
local puzzleState = PuzzleTable.newState("torn_doc:ev_schedule", board, { 0, 1, 2, 3 })
local puzzlePayload = PuzzleTable.clientPayload(puzzleState)
Harness.check(
	#puzzlePayload.pieces == 4,
	string.format("kontrol: payload meja membawa potongan (%d)", #puzzlePayload.pieces)
)

local cleanPuzzle = Net.forRole("puzzle_state", "Handler", puzzlePayload)
Harness.check(
	#Net.findSecrets(cleanPuzzle, "puzzle_state.Handler") == 0,
	"kontrol: payload meja bersih dari field rahasia"
)

local dirtyPuzzle = {
	puzzle_id = "torn_doc:ev_schedule",
	cols = 4,
	rows = 4,
	pieces = puzzlePayload.pieces,
	culprit = "curator",
}
Harness.check(
	#Net.findSecrets(dirtyPuzzle, "puzzle.dirty") > 0,
	"kontrol: payload meja yang disuntik rahasia memang terdeteksi detektor"
)
Harness.check(
	#Net.findSecrets(Net.forRole("puzzle_state", "Handler", dirtyPuzzle), "puzzle") == 0,
	"kontrol: field rahasia yang disuntik ke payload meja disaring"
)

-- Ringkasan eksplisit, supaya keluaran spec ini bisa dilampirkan sebagai bukti
-- gate tanpa harus membaca laporan runner: `Harness.check` hanya bersuara saat
-- gagal, jadi tanpa baris ini keluarannya tidak menunjukkan berapa yang diperiksa.
print(
	string.format(
		"kebocoran: %d pasangan view x role terperiksa, %d temuan rahasia",
		pairsChecked,
		findings
	)
)

-- Lewat `run.luau` baris ini diam (runner yang melapor). Dijalankan sendiri
-- sebagai bukti gate, ia yang mencetak ringkasan dan menetapkan kode keluar.
Harness.finish("leak-sweep")
