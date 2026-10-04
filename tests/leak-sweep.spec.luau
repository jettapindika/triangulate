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
			location = "staff_room",
			image = "rbxassetid://0",
			gives_key = "key_a",
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
	end

	error(string.format("view %s belum punya payload uji", view))
end

Harness.suite("kebocoran: seluruh view x role")

local pairsChecked = 0
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
			pairsChecked = pairsChecked + 1
		end
	end
end

Harness.check(
	pairsChecked == 21,
	string.format("kebocoran: 7 view x 3 role tersapu (terperiksa: %d)", pairsChecked)
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

local viewsOk, viewProblems = Net.validateViews()
Harness.check(
	viewsOk,
	string.format(
		"kontrol: tidak ada view yang mengizinkan field rahasia (%d masalah)",
		#viewProblems
	)
)

return nil
