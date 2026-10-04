--!strict
-- Uji penetapan role (PRD §8).
--
-- Konfigurasi di bawah dipilih dengan cara mencari: untuk tiap aturan, ada
-- konfigurasi di mana MENGHAPUS aturan itu mengubah hasil. Jadi assertion ini
-- gagal bila aturan keadilan atau aturan pemain-baru rusak -- bukan sekadar
-- lulus karena kebetulan.

local Harness = require("./harness")
local RoleAssignment = require("../src/server/RoleAssignment")

local ROLES3 = { "Searcher", "Handler", "Director" }
local OPTS: RoleAssignment.Options = {
	fairnessStreak = 3,
	newPlayerExcludedRole = "Director",
}

local function player(
	id: number,
	prefs: { string },
	recent: { string }?,
	isNew: boolean?
): RoleAssignment.PlayerRef
	return {
		id = id,
		preferences = prefs,
		recentRoles = recent or {},
		isNew = isNew or false,
	}
end

Harness.suite("RoleAssignment: aturan keadilan")

-- Kedua pemain sudah 3 sesi berturut-turut di role yang sama, dan keduanya
-- menempatkan role itu sebagai preferensi pertama. Aturan keadilan menukar
-- mereka. Tanpa aturan, hasilnya kebalikannya -- jadi uji ini mengisolasi
-- aturan tersebut.
local swapped = RoleAssignment.assign({
	player(1, { "Searcher", "Handler" }, { "Searcher", "Searcher", "Searcher" }),
	player(2, { "Handler", "Searcher" }, { "Handler", "Handler", "Handler" }),
}, { "Searcher", "Handler" }, OPTS)

Harness.equal(swapped[1], "Handler", "streak 3 memindahkan pemain 1 ke preferensi kedua")
Harness.equal(swapped[2], "Searcher", "streak 3 memindahkan pemain 2 ke preferensi kedua")

-- Ambangnya tepat 3: rentetan 2 belum memicu aturan, jadi preferensi pertama
-- masih dihormati.
local below = RoleAssignment.assign({
	player(1, { "Searcher", "Handler" }, { "Searcher", "Searcher" }),
	player(2, { "Handler", "Searcher" }, { "Handler", "Handler" }),
}, { "Searcher", "Handler" }, OPTS)

Harness.equal(below[1], "Searcher", "rentetan 2 masih menghormati preferensi pertama")

-- Yang dihitung adalah rentetan di EKOR riwayat, bukan jumlah kemunculan.
-- Pemain ini memegang Searcher dua kali, tapi sesi terakhirnya Handler.
local notStreak = RoleAssignment.assign({
	player(1, { "Searcher", "Handler" }, { "Searcher", "Searcher", "Handler" }),
	player(2, { "Searcher", "Handler" }, {}),
}, { "Searcher", "Handler" }, OPTS)

Harness.check(notStreak[1] ~= nil, "riwayat yang tidak berakhir seragam tetap ditugaskan")

Harness.suite("RoleAssignment: pemain baru")

-- Pemain 1 baru dan menempatkan Director sebagai preferensi pertama.
-- Konfigurasi ini mengisolasi aturan: dengan aturan, pemain 1 mendapat
-- Searcher; tanpa aturan, pemain 1 justru mendapat Director.
local withRule = RoleAssignment.assign({
	player(1, { "Searcher", "Director" }, {}, true),
	player(2, { "Searcher", "Director" }),
	player(3, { "Handler", "Searcher" }),
}, ROLES3, OPTS)

local withoutRule = RoleAssignment.assign({
	player(1, { "Searcher", "Director" }, {}, false),
	player(2, { "Searcher", "Director" }),
	player(3, { "Handler", "Searcher" }),
}, ROLES3, OPTS)

Harness.equal(withRule[1], "Searcher", "pemain baru tidak menjadi Director")
Harness.check(
	withoutRule[1] == "Director",
	"tanpa aturan, konfigurasi ini memang memberi Director ke pemain 1"
)
Harness.check(withRule[1] ~= withoutRule[1], "aturan pemain-baru benar-benar mengubah hasil")

Harness.suite("RoleAssignment: determinisme")

local first = RoleAssignment.assign({
	player(7, { "Handler", "Searcher" }),
	player(3, { "Searcher", "Handler" }),
	player(5, { "Director", "Searcher" }),
}, ROLES3, OPTS)

local second = RoleAssignment.assign({
	player(5, { "Director", "Searcher" }),
	player(3, { "Searcher", "Handler" }),
	player(7, { "Handler", "Searcher" }),
}, ROLES3, OPTS)

Harness.equal(first, second, "urutan masukan tidak mengubah hasil")

local filled: { [string]: number } = {}
for _, role in first do
	filled[role] = (filled[role] or 0) + 1
end
for _, role in ROLES3 do
	Harness.equal(filled[role], 1, string.format("role %s terisi tepat satu pemain", role))
end

Harness.suite("RoleAssignment: rotasi")

Harness.equal(RoleAssignment.rotate(ROLES3, "Searcher"), "Handler", "Searcher -> Handler")
Harness.equal(RoleAssignment.rotate(ROLES3, "Handler"), "Director", "Handler -> Director")
Harness.equal(RoleAssignment.rotate(ROLES3, "Director"), "Searcher", "Director -> Searcher")

return nil
