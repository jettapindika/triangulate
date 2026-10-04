--!strict
-- Binding remote di sisi client.
--
-- Client TIDAK membuat remote apa pun -- server yang membuatnya (lihat
-- `src/server/init.server.luau`), dan client hanya menunggu instance-nya
-- muncul di `ReplicatedStorage.Shared.Remotes`. Ini penting: kalau client bisa
-- membuat remote sendiri, daftar remote bisa berbeda antara server dan client.
--
-- Modul ini juga sengaja tidak menyediakan jalan pintas untuk mengirim payload
-- bebas. Tiap remote yang dikirim punya fungsi bernama di `NetClient`, supaya
-- terlihat jelas di code review data apa saja yang meninggalkan client.

local NetClient = {}

export type Bound = {
	SessionState: RemoteEvent,
	ClueCard: RemoteEvent,
	TargetMarker: RemoteEvent,
	Pinpoint: RemoteEvent,
	ReportCard: RemoteEvent,
	AccusationResult: RemoteEvent,
	DeductionResult: RemoteEvent,
	PuzzleState: RemoteEvent,
	PiecePlaced: RemoteEvent,
	Report: RemoteEvent,
	SubmitDeduction: RemoteEvent,
	Accuse: RemoteEvent,
	Ping: RemoteEvent,
	RequestHint: RemoteEvent,
	ConfirmAccusation: RemoteEvent,
	PlacePiece: RemoteEvent,
}

-- Menunggu seluruh remote muncul. Dipanggil sekali di awal; kalau salah satu
-- tidak muncul, itu bug kontrak dan lebih baik terlihat sebagai warning
-- daripada gagal diam-diam saat pemain menekan tombol.
function NetClient.bind(shared: Instance): Bound
	local folder = shared:WaitForChild("Remotes")

	local function waitFor(name: string): RemoteEvent
		return folder:WaitForChild(name) :: RemoteEvent
	end

	return {
		SessionState = waitFor("SessionState"),
		ClueCard = waitFor("ClueCard"),
		TargetMarker = waitFor("TargetMarker"),
		Pinpoint = waitFor("Pinpoint"),
		ReportCard = waitFor("ReportCard"),
		AccusationResult = waitFor("AccusationResult"),
		DeductionResult = waitFor("DeductionResult"),
		PuzzleState = waitFor("PuzzleState"),
		PiecePlaced = waitFor("PiecePlaced"),
		Report = waitFor("Report"),
		SubmitDeduction = waitFor("SubmitDeduction"),
		Accuse = waitFor("Accuse"),
		Ping = waitFor("Ping"),
		RequestHint = waitFor("RequestHint"),
		ConfirmAccusation = waitFor("ConfirmAccusation"),
		PlacePiece = waitFor("PlacePiece"),
	}
end

-- PRD §7: Report Card. Client hanya mengirim ID objek dan lokasinya; server
-- yang memutuskan apa yang kembali ke tiap role.
function NetClient.report(bound: Bound, objectId: string, location: string): ()
	bound.Report:FireServer({ object_id = objectId, location = location })
end

-- PRD §4: Director menggabungkan Clue Card. Client mengirim daftar id; resep
-- diperiksa di server (PRD §15).
function NetClient.deduce(bound: Bound, clueIds: { string }): ()
	bound.SubmitDeduction:FireServer(clueIds)
end

-- PRD §5: tuduhan. Server yang menghitung berapa field benar.
function NetClient.accuse(bound: Bound, accusation: { [string]: string }): ()
	bound.Accuse:FireServer(accusation)
end

-- PRD §5: konfirmasi dari role selain Director.
function NetClient.confirmAccusation(bound: Bound): ()
	bound.ConfirmAccusation:FireServer()
end

-- PRD §7: ping wheel. Yang dikirim adalah ID frasa, bukan teks bebas.
function NetClient.ping(bound: Bound, phraseId: string): ()
	bound.Ping:FireServer(phraseId)
end

-- PRD §8: hint butuh persetujuan 2 role, jadi ini permintaan, bukan aksi.
function NetClient.requestHint(bound: Bound): ()
	bound.RequestHint:FireServer()
end

-- PRD §15: pelepasan satu potongan di meja puzzle.
--
-- Yang dikirim adalah posisi jari TERNORMALISASI terhadap bidang meja, bukan
-- indeks sel. Server yang memutuskan potongan itu menempel di sel mana, dan
-- apakah drop-nya sah (lihat `PuzzleTable.applyDrop`). Client mengirim ini
-- sekali per pelepasan jari, bukan tiap frame.
function NetClient.placePiece(
	bound: Bound,
	nodeId: string,
	pieceId: string,
	u: number,
	v: number
): ()
	bound.PlacePiece:FireServer({ node_id = nodeId, piece_id = pieceId, u = u, v = v })
end

return NetClient
