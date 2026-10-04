--!strict
-- Uji kontrak jaringan (PRD §15).
--
-- Yang diuji di sini bukan plumbing, melainkan sifat yang menahan kebocoran
-- solusi: tidak ada view yang boleh mengizinkan field rahasia, dan proyeksi
-- payload yang penuh rahasia tidak boleh meloloskan satu pun.

local Harness = require("./harness")
local Net = require("../src/shared/Net")

Harness.suite("Net: proyeksi whitelist")

Harness.equal(
	Net.project({ a = 1, b = 2, c = 3 }, { "a", "c" }),
	{ a = 1, c = 3 },
	"project menyalin hanya field yang diizinkan"
)

Harness.equal(Net.project({ a = 1 }, {}), {}, "daftar kosong menghasilkan tabel kosong")

Harness.equal(
	Net.project({ a = 1 }, { "tidak_ada" }),
	{},
	"field yang tidak ada di sumber tidak diciptakan"
)

Harness.suite("Net: forRole")

Harness.equal(Net.forRole("view_tidak_ada", "Director", { a = 1 }), nil, "view tak dikenal -> nil")
Harness.equal(Net.forRole("briefing", "Role_Tidak_Ada", { a = 1 }), nil, "role tak dikenal -> nil")

Harness.suite("Net: guard view")

local viewsOk, viewProblems = Net.validateViews()
Harness.ok(
	viewsOk,
	"tidak ada view yang mengizinkan field rahasia: " .. table.concat(viewProblems, "; ")
)

-- Sifat inti: payload yang berisi SEMUA field rahasia, dilewatkan ke setiap
-- view x role, tidak boleh meloloskan satu pun.
local hostile: { [string]: any } = {}
for _, secret in Net.SECRET_FIELDS do
	hostile[secret] = "rahasia"
end
hostile.id = "clue_1"
hostile.title = "Clue sah"

local leaked: { string } = {}
for viewName, byRole in Net.CLIENT_VIEWS do
	for roleName in byRole do
		local projected = Net.forRole(viewName, roleName, hostile)
		Harness.check(projected ~= nil, string.format("view %s/%s dikenal", viewName, roleName))
		if projected ~= nil then
			for _, found in Net.findSecrets(projected) do
				table.insert(leaked, string.format("%s/%s%s", viewName, roleName, found))
			end
		end
	end
end

Harness.equal(leaked, {}, "tidak ada field rahasia yang lolos ke payload client")

-- Bukti bahwa pemeriksaannya benar-benar bekerja: payload yang BELUM
-- diproyeksikan memang terdeteksi membawa rahasia.
local rawSecrets = Net.findSecrets({ culprit = "curator", nested = { solution = {} } })
Harness.equal(#rawSecrets, 2, "findSecrets menemukan rahasia di level atas dan bersarang")

Harness.suite("Net: arah remote")

local names: { [string]: boolean } = {}
for _, name in Net.REMOTE_NAMES do
	Harness.check(not names[name], string.format("nama remote unik: %s", name))
	names[name] = true
end

for _, name in Net.REMOTE_NAMES do
	local outbound = Net.SERVER_TO_CLIENT[name] == true
	local inbound = Net.CLIENT_TO_SERVER[name] == true
	Harness.check(outbound or inbound, string.format("remote %s punya arah", name))
	Harness.check(not (outbound and inbound), string.format("remote %s tidak dua arah", name))
end
Harness.finish("net")
