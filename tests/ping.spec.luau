--!strict
-- Uji frasa ping (PRD §7).

local Harness = require("./harness")
local PingPhrases = require("../src/shared/PingPhrases")

Harness.suite("PingPhrases: isi roda")

for _, role in { "Searcher", "Handler", "Director" } do
	local phrases = PingPhrases.forRole(role)

	-- PRD §7: "Roda dengan 6-8 frasa."
	Harness.check(#phrases >= 6, string.format("%s: minimal 6 frasa (dapat %d)", role, #phrases))
	Harness.check(#phrases <= 8, string.format("%s: maksimal 8 frasa (dapat %d)", role, #phrases))

	local ids: { [string]: boolean } = {}
	for _, phrase in phrases do
		Harness.check(not ids[phrase.id], string.format("%s: id frasa unik '%s'", role, phrase.id))
		ids[phrase.id] = true
		Harness.check(
			phrase.label ~= "",
			string.format("%s: frasa '%s' punya label", role, phrase.id)
		)
	end

	-- PRD §7: "Semua: 'Setuju', 'Ragu', 'Tolong ulangi'" -- tersedia untuk
	-- setiap role.
	Harness.ok(ids.agree, string.format("%s: punya frasa universal 'Setuju'", role))
	Harness.ok(ids.unsure, string.format("%s: punya frasa universal 'Ragu'", role))
	-- `repeat` adalah kata kunci Luau, jadi aksesnya wajib lewat indeks string.
	Harness.ok(ids["repeat"], string.format("%s: punya frasa universal 'Tolong ulangi'", role))
end

Harness.suite("PingPhrases: validasi")

-- Server memakai `isValid` supaya client tidak bisa menyiarkan teks bebas
-- lewat kanal ping (PRD §7, §15).
Harness.ok(PingPhrases.isValid("Searcher", "found"), "frasa milik role sendiri sah")
Harness.ok(PingPhrases.isValid("Searcher", "agree"), "frasa universal sah untuk role mana pun")
Harness.check(not PingPhrases.isValid("Searcher", "target"), "frasa milik role lain ditolak")
Harness.check(not PingPhrases.isValid("Searcher", "teks_bebas"), "id tak dikenal ditolak")
Harness.check(not PingPhrases.isValid("Searcher", ""), "id kosong ditolak")

-- Role tak dikenal tetap mendapat frasa universal, bukan tabel kosong -- roda
-- ping harus selalu bisa dipakai.
local unknown = PingPhrases.forRole("Role_Hantu")
Harness.equal(#unknown, 3, "role tak dikenal hanya mendapat frasa universal")
Harness.ok(PingPhrases.isValid("Role_Hantu", "agree"), "frasa universal sah untuk role tak dikenal")
Harness.finish("ping")
