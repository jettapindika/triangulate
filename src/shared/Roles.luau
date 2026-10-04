--!strict
-- Role dan aturan pemilihannya (PRD §3, §8, §10).

export type Role = "Searcher" | "Handler" | "Director"

-- Luau tidak mengizinkan anotasi tipe pada penugasan field tabel
-- (`Roles.X: Role = ...` diurai sebagai pemanggilan metode). Karena itu bentuk
-- tabelnya dideklarasikan lewat tipe, bukan anotasi per baris.
type RolesModule = {
	SEARCHER: Role,
	HANDLER: Role,
	DIRECTOR: Role,
	ALL: { Role },

	-- PRD §3: pemain memilih 2 preferensi role (urutan prioritas) sebelum
	-- matchmaking.
	PREFERENCE_COUNT: number,

	-- PRD §10: rotasi otomatis di private server/seri kasus.
	-- Kasus pertama bebas pilih, lalu rotasi berurutan.
	ROTATION: { Role },

	-- PRD §8: pemain yang memegang role sama 3 sesi berturut-turut mendapat
	-- prioritas ke preferensi keduanya. Pemain baru tidak otomatis jadi Director.
	FAIRNESS_STREAK: number,
	NEW_PLAYER_EXCLUDED_ROLE: Role,

	-- PRD §8: role yang bisa diisi NPC. NPC Director ada di P1, jadi pada MVP
	-- hanya Searcher dan Handler yang punya NPC.
	NPC_FILLABLE: { Role },

	isRole: (value: string) -> boolean,
}

-- Dideklarasikan lebih dulu supaya `isRole` bisa merujuknya: di dalam literal
-- tabel, nama `Roles` belum terikat sehingga `Roles.ALL` akan terbaca sebagai
-- global yang tidak dikenal.
local ALL: { Role } = { "Searcher", "Handler", "Director" }

local Roles: RolesModule = {
	SEARCHER = "Searcher",
	HANDLER = "Handler",
	DIRECTOR = "Director",
	ALL = ALL,
	PREFERENCE_COUNT = 2,
	ROTATION = { "Searcher", "Handler", "Director" },
	FAIRNESS_STREAK = 3,
	NEW_PLAYER_EXCLUDED_ROLE = "Director",
	NPC_FILLABLE = { "Searcher", "Handler" },

	isRole = function(value: string): boolean
		for _, role in ALL do
			if role == value then
				return true
			end
		end
		return false
	end,
}

return Roles
