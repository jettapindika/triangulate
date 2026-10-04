--!strict
-- Alur tuduhan (PRD §5).
--
-- Aturan yang ditegakkan modul ini, semuanya di server:
--   * 3 tuduhan per kasus; setelah habis kasus jadi "Cold Case";
--   * feedback salah hanya "X dari 3 benar", tanpa menyebut field mana;
--   * menang butuh ketiga field benar DAN konfirmasi dari 1 role lain;
--   * tiap tuduhan salah menurunkan rank.
--
-- Murni: tidak ada global Roblox, sehingga bisa diuji dari CLI. Nilai
-- konfigurasi (daftar field, batas percobaan) masuk sebagai argumen, bukan
-- lewat `require` ke modul shared -- itu yang menjaga modul ini tetap bisa
-- dijalankan `lune` tanpa runtime Roblox.

local AccusationService = {}

export type Session = {
	solution: { [string]: string },
	fields: { string },
	maxAttempts: number,
	attemptsUsed: number,
	resolved: boolean,
	won: boolean,
	-- Menunggu konfirmasi role lain setelah tuduhan sepenuhnya benar.
	pendingConfirmation: boolean,
	correctFieldCount: number,
}

export type Result = {
	-- Usulan diterima sebagai tuduhan yang sah (bukan masukan cacat).
	accepted: boolean,
	reason: string?,
	correctCount: number,
	attemptsLeft: number,
	resolved: boolean,
	won: boolean,
	pendingConfirmation: boolean,
}

function AccusationService.newSession(
	solution: { [string]: string },
	fields: { string },
	maxAttempts: number
): Session
	return {
		solution = solution,
		fields = fields,
		maxAttempts = maxAttempts,
		attemptsUsed = 0,
		resolved = false,
		won = false,
		pendingConfirmation = false,
		correctFieldCount = 0,
	}
end

-- Memvalidasi bentuk tuduhan. Field yang tidak dikenal ditolak, bukan diabaikan:
-- tuduhan dengan field asing berarti client mengirim sesuatu yang tidak
-- seharusnya, dan itu layak dicatat sebagai sinyal.
function AccusationService.validate(
	session: Session,
	accusation: { [string]: any }
): (boolean, string?)
	local expected: { [string]: boolean } = {}
	for _, field in session.fields do
		expected[field] = true
	end

	for field, value in accusation do
		if not expected[field] then
			return false, string.format("field tuduhan tak dikenal: %s", field)
		end
		if type(value) ~= "string" then
			return false, string.format("field '%s' harus string", field)
		end
		if value == "" then
			return false, string.format("field '%s' kosong", field)
		end
	end

	for _, field in session.fields do
		if accusation[field] == nil then
			return false, string.format("field '%s' belum diisi", field)
		end
	end

	return true, nil
end

-- Mengajukan tuduhan. Mengembalikan `correctCount` saja -- tidak pernah daftar
-- field yang benar (PRD §5).
function AccusationService.submit(session: Session, accusation: { [string]: any }): Result
	if session.resolved then
		return {
			accepted = false,
			reason = "kasus sudah selesai",
			correctCount = session.correctFieldCount,
			attemptsLeft = session.maxAttempts - session.attemptsUsed,
			resolved = true,
			won = session.won,
			pendingConfirmation = false,
		}
	end

	if session.pendingConfirmation then
		return {
			accepted = false,
			reason = "menunggu konfirmasi role lain",
			correctCount = session.correctFieldCount,
			attemptsLeft = session.maxAttempts - session.attemptsUsed,
			resolved = false,
			won = false,
			pendingConfirmation = true,
		}
	end

	local valid, reason = AccusationService.validate(session, accusation)
	if not valid then
		return {
			accepted = false,
			reason = reason,
			correctCount = session.correctFieldCount,
			attemptsLeft = session.maxAttempts - session.attemptsUsed,
			resolved = false,
			won = false,
			pendingConfirmation = false,
		}
	end

	session.attemptsUsed += 1

	local correct = 0
	for _, field in session.fields do
		if accusation[field] == session.solution[field] then
			correct += 1
		end
	end
	session.correctFieldCount = correct

	local allCorrect = correct == #session.fields
	if allCorrect then
		-- PRD §5: tuduhan akhir butuh konfirmasi dari 1 role lain.
		session.pendingConfirmation = true
		return {
			accepted = true,
			reason = nil,
			correctCount = correct,
			attemptsLeft = session.maxAttempts - session.attemptsUsed,
			resolved = false,
			won = false,
			pendingConfirmation = true,
		}
	end

	local exhausted = session.attemptsUsed >= session.maxAttempts
	if exhausted then
		-- PRD §5: setelah 3 salah, kasus jadi "Cold Case".
		session.resolved = true
		session.won = false
	end

	return {
		accepted = true,
		reason = nil,
		correctCount = correct,
		attemptsLeft = session.maxAttempts - session.attemptsUsed,
		resolved = exhausted,
		won = false,
		pendingConfirmation = false,
	}
end

-- Konfirmasi dari role lain. PRD §5: "Tuduhan akhir butuh konfirmasi dari
-- 1 role lain" dan PRD §8: hanya tuduhan akhir dan hint yang butuh persetujuan
-- 2 role.
function AccusationService.confirm(
	session: Session,
	confirmingRole: string,
	directorRole: string
): (boolean, string?)
	if not session.pendingConfirmation then
		return false, "tidak ada tuduhan yang menunggu konfirmasi"
	end
	if confirmingRole == directorRole then
		return false, "konfirmasi harus datang dari role lain"
	end

	session.pendingConfirmation = false
	session.resolved = true
	session.won = true
	return true, nil
end

-- PRD §5: rank S/A/B/C dari waktu, jumlah tuduhan, dan hint terpakai.
--
-- Ambang di bawah adalah titik awal scaffold, BUKAN angka dari PRD. PRD §19
-- menyatakan N deduksi dan tuning baru divalidasi pada playtest minggu 7;
-- ambang rank tunduk pada validasi yang sama.
function AccusationService.rank(
	elapsedSeconds: number,
	attemptsUsed: number,
	hintsUsed: number,
	budgetSeconds: number
): string
	local overBudget = elapsedSeconds > budgetSeconds

	if attemptsUsed <= 1 and hintsUsed == 0 and not overBudget then
		return "S"
	end
	if attemptsUsed <= 1 and hintsUsed <= 1 then
		return "A"
	end
	if attemptsUsed <= 2 then
		return "B"
	end
	return "C"
end

return AccusationService
