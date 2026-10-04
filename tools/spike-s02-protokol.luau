--!strict
-- S0.2 (`docs/spike-minggu-0.md`): simulasi protokol drag.
--
-- Mencetak angka pesan remote per detik dan jumlah koreksi server untuk dua
-- jalur drag, memakai modul yang benar-benar dipakai game. Ini pengukuran,
-- bukan uji -- uji yang menjaga kontraknya ada di `tests/puzzle-table.spec.luau`
-- dan `tests/puzzle-table-service.spec.luau`.
--
-- Jalankan dari akar checkout repo:
--   $HOME/.local/roboxtools/lune.d/lune run tools/spike-s02-protokol.luau
--
-- Yang TIDAK diukur di sini dan dinyatakan apa adanya: latensi jaringan nyata
-- dan kehalusan drag di perangkat mobile kelas bawah. Keduanya butuh perangkat
-- dan jaringan sungguhan; yang bisa dihitung di sini adalah jumlah pesan
-- protokol dan tingkat kesepakatan prediksi client dengan keputusan server.

local PuzzleTable = require("../src/shared/PuzzleTable")

local FPS = 60
local AMBANG_PESAN = 20
local AMBANG_KOREKSI = 1

local function baris(judul: string, nilai: number, ambang: number)
	print(
		string.format(
			"%-44s %8.2f   ambang <= %5.2f   %s",
			judul,
			nilai,
			ambang,
			if nilai <= ambang then "LULUS" else "GAGAL"
		)
	)
end

print("=== S0.2 pesan remote saat drag aktif (1 detik) ===")
baris(
	"Jalur A: satu pesan per frame @60fps",
	PuzzleTable.remoteMessages("per_frame", FPS, 1),
	AMBANG_PESAN
)
baris(
	"Jalur B: satu pesan per potongan",
	PuzzleTable.remoteMessages("on_release", FPS, 1),
	AMBANG_PESAN
)
baris(
	"Jalur B: 16 potongan dalam 1 detik",
	PuzzleTable.remoteMessages("on_release", FPS, 16),
	AMBANG_PESAN
)
baris(
	"Jalur A @30fps (perangkat kelas bawah)",
	PuzzleTable.remoteMessages("per_frame", 30, 16),
	AMBANG_PESAN
)

print("")
print("=== S0.2 koreksi server per 16 potongan ===")

local function board(): PuzzleTable.Board
	return PuzzleTable.newBoard(4, 4, 16, 16)
end

local function rng(): () -> number
	local seed = 0
	return function(): number
		seed += 1
		return (seed * 0.37) % 1
	end
end

local function scattered(): PuzzleTable.State
	local regions: { number } = {}
	for index = 0, 15 do
		table.insert(regions, index)
	end
	return PuzzleTable.scatter(
		PuzzleTable.newState("torn_doc:ev_schedule", board(), regions),
		rng()
	)
end

-- Satu kali drop, dihitung dua sisi. Client memakai jalur yang sama dengan
-- `release` di `src/client/Table/init.luau`; server memakai `applyDrop`.
local function drop(offsetX: number, offsetY: number): (number, boolean, boolean, boolean)
	local serverState = scattered()
	local clientState = scattered()
	local pieceId = serverState.pieces[1].id
	local target = serverState.pieces[1].target

	local u = (target.col + 0.5) / serverState.board.cols + offsetX
	local v = (target.row + 0.5) / serverState.board.rows + offsetY

	local serverPayload = PuzzleTable.applyDrop(serverState, pieceId, u, v)

	local normalized = PuzzleTable.clampNormalized(clientState.board, u, v)
	assert(normalized ~= nil, "probe harus berhingga")
	local point = PuzzleTable.normalizedToPoint(clientState.board, normalized.x, normalized.y)
	local clientCell, clientSnapped =
		PuzzleTable.resolveDrop(clientState.board, point, clientState.pieces[1].pos)

	local koreksi = 0
	if
		(clientCell ~= nil) ~= (serverPayload.accepted == true)
		or clientSnapped.x ~= serverPayload.x
		or clientSnapped.y ~= serverPayload.y
	then
		koreksi = 1
	end

	return koreksi, clientCell ~= nil, serverPayload.accepted == true, serverState.pieces[1].correct
end

local tepat, meleset, salahSel = 0, 0, 0
for _ = 1, 16 do
	tepat += drop(0, 0)
end
for _ = 1, 16 do
	meleset += drop(0.4, -0.4)
end
for _ = 1, 16 do
	salahSel += drop(1, 1)
end

baris("16 drop tepat di pusat sel tujuan", tepat, AMBANG_KOREKSI)
baris("16 drop meleset 0,4 sel (dalam toleransi)", meleset, AMBANG_KOREKSI)
baris("16 drop ke sel lain yang masih sah", salahSel, AMBANG_KOREKSI)

print("")
print("=== kontrol: 'accepted' bukan 'correct' ===")
local _, clientOk, serverOk, benar = drop(1, 1)
print(
	string.format(
		"drop ke sel lain: client menerima=%s server menerima=%s server nilai benar=%s",
		tostring(clientOk),
		tostring(serverOk),
		tostring(benar)
	)
)

local rejectState = scattered()
local reject = PuzzleTable.applyDrop(rejectState, rejectState.pieces[1].id, 0 / 0, 0.5)
print(string.format("drop NaN: diterima server=%s", tostring(reject.accepted)))

print("")
print(
	string.format(
		"SNAP_TOLERANCE = %.2f sel, INTERPOLATION_RATE = %d pangsa/detik",
		PuzzleTable.SNAP_TOLERANCE,
		PuzzleTable.INTERPOLATION_RATE
	)
)
