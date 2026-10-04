--!strict
-- Alur lobby dan matchmaking (PRD §8).
--
-- Murni: seluruh kebijakan masuk sebagai argumen, tidak ada global Roblox.
-- Karena itu alur lobby bisa diuji dari CLI (`tests/matchmaking.spec.luau`).
-- Yang menyentuh `Players` dan `TeleportService` adalah `init.server.luau`.

local Matchmaking = {}

export type LobbyPlayer = {
	id: number,
	preferences: { string },
	ready: boolean,
	joinedAt: number,
}

export type Lobby = {
	players: { LobbyPlayer },
	createdAt: number,
}

export type Config = {
	maxPlayers: number,
	lobbySeconds: number,
	extendedSeconds: number,
	readyCheckSeconds: number,
}

function Matchmaking.newLobby(createdAt: number): Lobby
	return { players = {}, createdAt = createdAt }
end

function Matchmaking.find(lobby: Lobby, playerId: number): LobbyPlayer?
	for _, player in lobby.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

-- PRD §8: 3 manusia. Kelebihan ditolak di sini, dan `init.server.luau` juga
-- memverifikasi terhadap `Players.MaxPlayers` yang sebenarnya.
function Matchmaking.join(lobby: Lobby, player: LobbyPlayer, config: Config): (boolean, string?)
	if Matchmaking.find(lobby, player.id) ~= nil then
		return false, "sudah di lobby"
	end
	if #lobby.players >= config.maxPlayers then
		return false, "lobby penuh"
	end
	if #player.preferences == 0 then
		return false, "pemain harus memilih minimal 1 preferensi role"
	end
	table.insert(lobby.players, player)
	return true, nil
end

function Matchmaking.leave(lobby: Lobby, playerId: number): boolean
	for index, player in lobby.players do
		if player.id == playerId then
			table.remove(lobby.players, index)
			return true
		end
	end
	return false
end

function Matchmaking.setReady(lobby: Lobby, playerId: number, ready: boolean): boolean
	local player = Matchmaking.find(lobby, playerId)
	if player == nil then
		return false
	end
	player.ready = ready
	return true
end

-- PRD §8: timer lobby 45 detik; pemain bisa memilih menunggu sampai 90 detik
-- bila belum ada 3 manusia. Perpanjangan hanya berlaku selama lobby belum penuh.
function Matchmaking.deadline(lobby: Lobby, config: Config): number
	local base = lobby.createdAt + config.lobbySeconds
	if #lobby.players >= config.maxPlayers then
		return base
	end
	return lobby.createdAt + config.extendedSeconds
end

function Matchmaking.secondsLeft(lobby: Lobby, now: number, config: Config): number
	local remaining = Matchmaking.deadline(lobby, config) - now
	if remaining < 0 then
		return 0
	end
	return remaining
end

-- PRD §8: "Ready check 10 detik sebelum mulai. Pemain yang tidak ready diganti."
function Matchmaking.readyFailures(lobby: Lobby): { number }
	local out: { number } = {}
	for _, player in lobby.players do
		if not player.ready then
			table.insert(out, player.id)
		end
	end
	return out
end

-- Lobby siap mulai bila sudah ada cukup pemain DAN semua ready.
-- PRD §8 mengizinkan lobby dimulai dengan kurang dari 3 manusia; role kosong
-- diisi NPC. Jadi syaratnya adalah minimal 1 manusia dan semua yang ada ready.
-- Jumlah minimum itu tidak berasal dari `Config` -- `maxPlayers` adalah batas
-- ATAS, bukan syarat mulai.
function Matchmaking.canStart(lobby: Lobby): (boolean, string?)
	if #lobby.players == 0 then
		return false, "tidak ada pemain"
	end
	local failures = Matchmaking.readyFailures(lobby)
	if #failures > 0 then
		return false, "menunggu ready check"
	end
	return true, nil
end

-- Role yang perlu diisi NPC karena tidak ada manusia yang memegangnya.
function Matchmaking.rolesWithoutHumans(
	roles: { string },
	assigned: { [number]: string }
): { string }
	local taken: { [string]: boolean } = {}
	for _, role in assigned do
		taken[role] = true
	end

	local out: { string } = {}
	for _, role in roles do
		if not taken[role] then
			table.insert(out, role)
		end
	end
	return out
end

-- PRD §8: "Pemain boleh tukar role di lobby (saling setuju)."
-- Server hanya menerapkan setelah kedua pihak menyatakan setuju.
function Matchmaking.swap(
	lobby: Lobby,
	playerA: number,
	playerB: number,
	assigned: { [number]: string }
): (boolean, string?)
	local roleA = assigned[playerA]
	local roleB = assigned[playerB]
	if roleA == nil or roleB == nil then
		return false, "kedua pemain harus sudah punya role"
	end
	if Matchmaking.find(lobby, playerA) == nil or Matchmaking.find(lobby, playerB) == nil then
		return false, "kedua pemain harus ada di lobby"
	end

	assigned[playerA] = roleB
	assigned[playerB] = roleA
	return true, nil
end

return Matchmaking
