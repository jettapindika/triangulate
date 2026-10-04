--!strict
-- Sesi teman di reserved server (PRD §8, §15).
--
-- `ReserveServer`/`TeleportToPrivateServer` tidak bisa dijalankan di playtest
-- Studio -- keduanya butuh place yang sudah dipublikasikan. Karena itu
-- keputusannya dipisahkan ke modul murni: pemanggil menyuntikkan kedua fungsi
-- itu, modul ini yang menentukan urutan, validasi party, dan penerusan alasan.
-- `tests/friend-session.spec.luau` menyuntikkan pengganti yang mencatat
-- panggilannya, jadi aturan sesi teman teruji tanpa Roblox.

local FriendSession = {}

-- PRD §8: "Satu pemain yang punya, semua anggota sesi bisa main" -- party
-- dipimpin host, dan host selalu ikut bermain.
export type Party = {
	hostUserId: number,
	memberIds: { number },
}

export type Dependencies = {
	reserveServer: (partySize: number) -> (string?, string?),
	teleportTo: (accessCode: string, userIds: { number }) -> (boolean, string?),
}

export type Session = {
	deps: Dependencies,
}

function FriendSession.new(deps: Dependencies): Session
	return { deps = deps }
end

-- Daftar pemain sesi: host lebih dulu, diikuti teman. Urutan ini yang dipakai
-- untuk teleport, dan yang dicek terhadap `MaxPlayers`.
function FriendSession.members(party: Party): { number }
	local ids: { number } = { party.hostUserId }
	for _, memberId in party.memberIds do
		table.insert(ids, memberId)
	end
	return ids
end

-- Party ditolak sebelum `ReserveServer` dipanggil: reserved server yang sudah
-- dibuat tidak bisa dibatalkan tanpa membuang kuota, jadi validasi harus lebih
-- dulu. Host ganda dan teman ganda ditolak karena slot sesi dihitung per orang.
function FriendSession.validate(party: Party, maxPlayers: number): boolean
	local ids = FriendSession.members(party)
	if #ids > maxPlayers then
		return false
	end

	local seen: { [number]: boolean } = {}
	for _, userId in ids do
		if seen[userId] then
			return false
		end
		seen[userId] = true
	end

	return true
end

-- Membuat reserved server untuk party lalu memindahkan seluruh anggotanya ke
-- sana. Mengembalikan access code bila berhasil, atau `(nil, alasan)`.
function FriendSession.start(session: Session, party: Party, maxPlayers: number): (string?, string?)
	local ids = FriendSession.members(party)
	if not FriendSession.validate(party, maxPlayers) then
		return nil, "party tidak sah"
	end

	local accessCode, reserveProblem = session.deps.reserveServer(#ids)
	if accessCode == nil then
		return nil, reserveProblem or "reserve gagal"
	end

	local teleported, teleportProblem = session.deps.teleportTo(accessCode, ids)
	if not teleported then
		return nil, teleportProblem or "teleport gagal"
	end

	return accessCode, nil
end

return FriendSession
