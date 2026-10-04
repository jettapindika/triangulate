--!strict
-- Penetapan role (PRD §8).
--
-- Murni: seluruh masukan diberikan sebagai argumen, tanpa global Roblox.
-- Karena itu logika keadilan bisa diuji dari CLI (`tests/role-assignment.spec.luau`).
-- Modul glue (`Matchmaking.luau`) yang menyuplai `roles` dan riwayat sesi.

local RoleAssignment = {}

export type PlayerRef = {
	id: number,
	-- PRD §3: 2 preferensi role, urutan prioritas.
	preferences: { string },
	-- Riwayat role dari sesi sebelumnya, terbaru di akhir.
	recentRoles: { string },
	-- PRD §8: "Pemain baru tidak otomatis jadi Director di sesi pertama."
	isNew: boolean,
}

export type Options = {
	-- PRD §8: pemain yang memegang role sama N sesi berturut-turut mendapat
	-- prioritas ke preferensi keduanya.
	fairnessStreak: number,
	-- Role yang tidak diberikan ke pemain baru bila masih ada alternatif.
	newPlayerExcludedRole: string,
}

-- Daftar prioritas efektif seorang pemain: preferensi yang sudah dihormati
-- aturan keadilan, diikuti role lain sebagai cadangan supaya penugasan selalu
-- punya solusi.
local function priorityList(player: PlayerRef, roles: { string }, options: Options): { string }
	local ordered: { string } = {}

	local function push(role: string)
		for _, existing in ordered do
			if existing == role then
				return
			end
		end
		table.insert(ordered, role)
	end

	-- Hitung rentetan role yang sama di akhir riwayat, bukan jumlah kemunculan.
	-- PRD §8 berbicara tentang pemain yang memegang role sama "3 sesi
	-- berturut-turut", jadi yang relevan hanya ekor riwayat.
	local lastRole: string? = player.recentRoles[#player.recentRoles]
	local streak = 0
	if lastRole ~= nil then
		for index = #player.recentRoles, 1, -1 do
			if player.recentRoles[index] == lastRole then
				streak += 1
			else
				break
			end
		end
	end

	-- Pemain yang terjebak di role yang sama melewati ambang keadilan: naikkan
	-- preferensi kedua ke depan, seperti diminta PRD §8.
	local unfair = lastRole ~= nil and streak >= options.fairnessStreak
	if unfair and #player.preferences >= 2 then
		push(player.preferences[2])
		push(player.preferences[1])
	else
		for _, pref in player.preferences do
			push(pref)
		end
	end

	-- Cadangan: role lain, agar penugasan tidak pernah gagal.
	for _, role in roles do
		push(role)
	end

	-- PRD §8: pemain baru tidak otomatis jadi Director. Dorong ke belakang,
	-- bukan buang, supaya tetap bisa ditugaskan bila tidak ada pilihan lain.
	if player.isNew then
		local filtered: { string } = {}
		for _, role in ordered do
			if role ~= options.newPlayerExcludedRole then
				table.insert(filtered, role)
			end
		end
		for _, role in ordered do
			if role == options.newPlayerExcludedRole then
				table.insert(filtered, role)
			end
		end
		ordered = filtered
	end

	return ordered
end

local function rankOf(list: { string }, role: string): number
	for index, value in list do
		if value == role then
			return index
		end
	end
	return #list + 1
end

-- Menetapkan tepat satu role ke tiap pemain.
--
-- Deterministik: pemain diurutkan berdasarkan `id`, dan seri diputus oleh `id`
-- terkecil. Urutan pemrosesan role dipilih dari yang paling langka (paling
-- sedikit pemain yang menempatkannya di prioritas pertama) supaya preferensi
-- pertama lebih sering terpenuhi.
function RoleAssignment.assign(
	players: { PlayerRef },
	roles: { string },
	options: Options
): { [number]: string }
	local priorities: { [number]: { string } } = {}
	for _, player in players do
		priorities[player.id] = priorityList(player, roles, options)
	end

	local remainingRoles: { string } = table.clone(roles)
	local unassigned: { number } = {}
	for _, player in players do
		table.insert(unassigned, player.id)
	end
	table.sort(unassigned)

	local assignment: { [number]: string } = {}

	while #remainingRoles > 0 do
		-- Pilih role dengan peminat prioritas-pertama paling sedikit.
		local chosenIndex = 1
		local chosenCount = math.huge
		for index, role in remainingRoles do
			local count = 0
			for _, playerId in unassigned do
				if priorities[playerId][1] == role then
					count += 1
				end
			end
			if count < chosenCount then
				chosenCount = count
				chosenIndex = index
			end
		end

		local role = remainingRoles[chosenIndex]
		table.remove(remainingRoles, chosenIndex)

		-- Pilih pemain yang menempatkan role ini paling tinggi; seri -> id terkecil.
		local bestPlayerId: number? = nil
		local bestRank = math.huge
		for _, playerId in unassigned do
			local rank = rankOf(priorities[playerId], role)
			if
				rank < bestRank
				or (rank == bestRank and (bestPlayerId == nil or playerId < bestPlayerId))
			then
				bestRank = rank
				bestPlayerId = playerId
			end
		end

		if bestPlayerId ~= nil then
			assignment[bestPlayerId] = role
			for index, playerId in unassigned do
				if playerId == bestPlayerId then
					table.remove(unassigned, index)
					break
				end
			end
		end
	end

	return assignment
end

-- Rotasi otomatis untuk private server / seri kasus (PRD §10):
-- Searcher -> Handler -> Director -> Searcher.
function RoleAssignment.rotate(roles: { string }, currentRole: string): string
	for index, role in roles do
		if role == currentRole then
			return roles[(index % #roles) + 1]
		end
	end
	return roles[1]
end

return RoleAssignment
