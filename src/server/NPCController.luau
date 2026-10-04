--!strict
-- Perilaku NPC dan pengambilalihan saat AFK/disconnect (PRD §8).
--
-- PRD §8 menetapkan prioritas NPC:
--   Searcher -- "Berjalan ke objek yang ditandai ping/pinpoint dan melapor" (kesulitan rendah)
--   Handler  -- "Merakit potongan otomatis dengan kecepatan lambat setelah kunci diberikan" (rendah)
--   Director -- "Mode terpandu: menyarankan kombinasi Clue Card dengan hint terbatas" (tinggi, P1)
--
-- Modul ini murni: keputusan dihitung dari angka dan himpunan, bukan dari
-- instance Roblox, sehingga bisa diuji dari CLI. Yang menjalankan keputusan
-- (menggerakkan Humanoid, memanggil puzzle) adalah seam di `init.server.luau`.

local NPCController = {}

export type Action = {
	kind: string,
	-- Target aksi, mis. id objek atau id bukti; `nil` bila tidak relevan.
	target: string?,
}

-- PRD §8: "AFK 60 detik tanpa input -> NPC mengambil alih role itu, state tetap utuh."
function NPCController.shouldTakeOver(secondsSinceInput: number, afkSeconds: number): boolean
	return secondsSinceInput >= afkSeconds
end

-- PRD §8: "Disconnect -> slot ditahan 3 menit untuk rejoin, NPC mengisi
-- sementara. Setelah 3 menit slot dibuka untuk pemain pengganti atau tetap NPC."
function NPCController.shouldReleaseSlot(
	secondsSinceDisconnect: number,
	holdSeconds: number
): boolean
	return secondsSinceDisconnect >= holdSeconds
end

-- Role yang perlu diisi NPC: role yang tidak dipegang manusia dan boleh diisi
-- NPC. PRD §8 menempatkan NPC Director di P1, jadi pada MVP hanya Searcher dan
-- Handler yang masuk daftar `npcFillable` (lihat `shared/Roles.luau`).
-- Generik atas tipe role pemanggil: `{ "Searcher" | "Handler" | "Director" }`
-- BUKAN subtipe `{ string }` di Luau (array tidak kovarian), jadi memakai
-- `{ string }` akan menolak `Roles.ALL` di pemanggil yang bertipe ketat.
function NPCController.rolesToFill<T>(
	humanRoles: { [string]: boolean },
	roles: { T },
	npcFillable: { T }
): { T }
	local fillable: { [T]: boolean } = {}
	for _, role in npcFillable do
		fillable[role] = true
	end

	local out: { T } = {}
	for _, role in roles do
		if not humanRoles[role] and fillable[role] then
			table.insert(out, role)
		end
	end
	return out
end

-- Aksi berikutnya untuk sebuah NPC.
--
-- `state` adalah potongan state sesi yang relevan untuk role itu:
--   Searcher: `pingedObject` -- id objek yang ditandai ping/pinpoint.
--   Handler:  `unlockedEvidence` -- id bukti yang kuncinya sudah didapat.
--   Director: tidak diisi pada MVP (P1).
function NPCController.nextAction(role: string, state: { [string]: any }): Action
	if role == "Searcher" then
		local target = state.pingedObject
		if type(target) == "string" then
			return { kind = "move_to_object", target = target }
		end
		return { kind = "idle", target = nil }
	end

	if role == "Handler" then
		local target = state.unlockedEvidence
		if type(target) == "string" then
			return { kind = "assemble_slowly", target = target }
		end
		return { kind = "idle", target = nil }
	end

	-- Director NPC adalah P1 (PRD §8 dan §16). Jangan diam-diam memberi NPC
	-- kemampuan yang belum dirancang.
	return { kind = "unsupported", target = nil }
end

-- PRD §8: "Sesi dengan NPC Director dihitung rank terpisah (tanpa leaderboard
-- utama)." Dipakai pemanggil untuk memutuskan leaderboard mana yang ditulis.
function NPCController.separateRank(hasNpcDirector: boolean, separateRankEnabled: boolean): boolean
	return hasNpcDirector and separateRankEnabled
end

return NPCController
