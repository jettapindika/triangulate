--!strict
-- Gerbang form tuduhan, penalti cleanup, dan rekap Cold Case (PRD §5, §6, §10).
--
-- Pembagian tanggung jawab yang dipegang berkas ini:
--   * `AccusationService` -- menilai tuduhan, menghitung percobaan, dan
--     menghitung rank.
--   * berkas ini -- SYARAT yang harus terpenuhi SEBELUM tuduhan boleh dinilai
--     (N Deduksi Kunci selesai + minimal 1 Kontradiksi ditandai), timer
--     *cleanup* beserta penaltinya, dan rekap parsial saat kasus menjadi
--     Cold Case.
--   * `init.server.luau` -- glue: memanggil keduanya dalam urutan yang benar
--     dan mengirim hasilnya ke client.
--
-- Kenapa dipisah dari glue: glue menyentuh `game` dan karena itu tidak bisa
-- dijalankan `lune`, sedangkan aturan di berkas ini justru yang paling mahal
-- kalau salah. Gerbang yang bocor membuat form tuduhan bisa dibuka sebelum tim
-- mengumpulkan bukti; rekap yang bocor memberi jawaban gratis (SOP-03, failure
-- mode "rekap parsial menyebut jawaban" berujung "hentikan tayang").
--
-- Rumus gerbang masuk sebagai ARGUMEN (`gateFn`, yaitu `DeductionEngine.gateOpen`)
-- alih-alih di-`require`. Alasannya sama dengan `AccusationService` yang
-- menerima daftar field sebagai argumen: satu rumus, dua pemakai, tanpa salinan
-- kedua yang bisa menyimpang -- dan modul ini tetap bisa dijalankan `lune`
-- tanpa runtime Roblox.

local AccusationGate = {}

--[[
	Pesan penolakan penandaan Kontradiksi yang BOLEH dibaca pemain (PRD §4).

	Dua pesan saja, dan itu disengaja: pernyataan yang tidak dibantah bukti mana
	pun dan pernyataan yang bukti pembantahnya belum dikumpulkan memberi pesan
	yang SAMA. Kalau keduanya dibedakan, Director bisa menemukan pembohong
	dengan mencoba satu per satu pernyataan sampai pesannya berubah -- oracle
	yang menghapus justru bagian berpikirnya.

	Pesan "sudah ditandai" aman dipisah: ia hanya mengulang apa yang client
	sudah lakukan sendiri, jadi tidak mengungkap apa pun tentang kebenaran
	pernyataannya.

	Ini TERPISAH dari `reason` yang dikembalikan `AccusationGate.markContradiction`:
	yang itu untuk log server dan menyebut id pernyataan sekaligus id Clue Card
	yang benar, sehingga tidak boleh menyeberang ke client.
]]
AccusationGate.REJECT_REASON = "pernyataan itu belum terbantah oleh bukti yang sudah dikumpulkan"
AccusationGate.ALREADY_MARKED = "kontradiksi itu sudah ditandai"

export type Config = {
	contradictionsRequired: number,
	cleanupSeconds: number,
	cleanupPenaltySeconds: number,
	cleanupFloorSeconds: number,
}

export type GateFn = (
	keyDeductionsDone: number,
	keyDeductionsRequired: number,
	contradictions: number,
	contradictionsRequired: number
) -> boolean

export type Session = {
	config: Config,
	gateFn: GateFn,
	-- Jumlah Kontradiksi yang BENAR. Server tahu kebenarannya (PRD §15), dan
	-- hanya yang benar yang membuka gerbang.
	contradictionsMarked: number,
	-- Id pernyataan yang sudah ditandai, supaya menandai hal yang sama dua kali
	-- tidak menambah hitungan.
	markedStatements: { [string]: boolean },
	cleanupDeadline: number,
}

export type NodeRef = {
	id: string,
	type: string,
}

--[[
	Masukan rekap Cold Case.

	Seluruhnya berupa angka dan himpunan, bukan teks pernyataan atau label:
	rekap yang memuat id node aktif akan membocorkan cabang kasus (id deduksi
	`ded_c_*` versus `ded_g_*` sama saja dengan menyebut pelakunya). Karena itu
	`common_ids` ada -- rekap dihitung HANYA atas node yang aktif di semua
	varian, sehingga penyebutnya tidak berubah antar cabang.
]]
export type RecapInput = {
	active_nodes: { NodeRef },
	common_ids: { [string]: boolean },
	revealed: { [string]: boolean },
	key_deductions_done: number,
	key_deductions_required: number,
	attempts_used: number,
}

function AccusationGate.newSession(config: Config, gateFn: GateFn, now: number): Session
	return {
		config = config,
		gateFn = gateFn,
		contradictionsMarked = 0,
		markedStatements = {},
		cleanupDeadline = now + config.cleanupSeconds,
	}
end

-- PRD §5: gerbang dihitung dari Deduksi Kunci yang selesai, bukan dari seluruh
-- deduksi. Irisan inilah yang membuat deduksi bonus tidak bisa menggantikan
-- deduksi kunci.
function AccusationGate.keyDeductionsDone(
	completed: { [string]: boolean },
	required: { string }
): number
	local count = 0
	for _, id in required do
		if completed[id] == true then
			count += 1
		end
	end
	return count
end

function AccusationGate.gateOpen(
	session: Session,
	keyDeductionsDone: number,
	keyDeductionsRequired: number
): boolean
	return session.gateFn(
		keyDeductionsDone,
		keyDeductionsRequired,
		session.contradictionsMarked,
		session.config.contradictionsRequired
	)
end

--[[
	Keputusan "tuduhan ini boleh dinilai atau tidak", beserta alasannya.

	Alasan HANYA untuk log server. Yang dikirim ke client adalah angka progres
	gerbang (`session_state`), bukan kalimat ini -- kalimatnya menyebut syarat
	mana yang kurang, dan itu lebih banyak daripada yang perlu client tahu.
]]
function AccusationGate.admit(
	session: Session,
	keyDeductionsDone: number,
	keyDeductionsRequired: number
): (boolean, string?)
	if not AccusationGate.gateOpen(session, keyDeductionsDone, keyDeductionsRequired) then
		if keyDeductionsDone < keyDeductionsRequired then
			return false,
				string.format(
					"gerbang tertutup: %d dari %d Deduksi Kunci selesai",
					keyDeductionsDone,
					keyDeductionsRequired
				)
		end
		return false,
			string.format(
				"gerbang tertutup: %d dari %d Kontradiksi ditandai",
				session.contradictionsMarked,
				session.config.contradictionsRequired
			)
	end
	return true, nil
end

--[[
	Menandai satu Kontradiksi: pernyataan `statementId` dibantah bukti `clueId`.

	Mengembalikan `(accepted, correct, reason)`:
	  * `accepted` -- penandaan BARU yang tercatat (bukan pengulangan);
	  * `correct` -- pernyataan itu memang dibantah bukti tersebut. Server yang
	    tahu (PRD §15); client tidak pernah menerima nilai ini, karena
	    umpan balik langsung akan mengubah penandaan menjadi oracle tebak-tebakan.
	  * `reason` -- untuk log server saja.

	Menandai pernyataan yang sudah ditandai tidak menambah hitungan; itu yang
	membuat `contradictionsMarked` berarti "jumlah Kontradiksi", bukan "jumlah
	ketukan".
]]
function AccusationGate.markContradiction(
	session: Session,
	statementId: string,
	statement: { contradicted_by: string? }?,
	clueId: string,
	obtained: { [string]: boolean }
): (boolean, boolean, string?)
	if statement == nil then
		return false, false, string.format("pernyataan '%s' tidak dikenal", statementId)
	end
	if session.markedStatements[statementId] == true then
		return false, true, string.format("pernyataan '%s' sudah ditandai", statementId)
	end

	local expected = statement.contradicted_by
	if expected == nil then
		return false,
			false,
			string.format("pernyataan '%s' tidak dibantah bukti mana pun", statementId)
	end
	if expected ~= clueId then
		return false,
			false,
			string.format("pernyataan '%s' tidak dibantah '%s'", statementId, clueId)
	end
	-- PRD §4: Kontradiksi adalah hasil kerja tim, bukan tebakan. Bukti
	-- pembantahnya harus SUDAH dikumpulkan (`obtained` diisi glue saat meja
	-- bukti selesai dirakit); tanpa syarat ini Director bisa menandai pernyataan
	-- mana pun sejak detik pertama dan gerbang tuduhan (PRD §5) terbuka tanpa
	-- satu pun deduksi.
	if obtained[clueId] ~= true then
		return false, false, string.format("bukti '%s' belum dikumpulkan", clueId)
	end

	session.markedStatements[statementId] = true
	session.contradictionsMarked += 1
	return true, true, nil
end

-- PRD §6: timer *cleanup*. Dihitung dari tenggat, bukan dari penjadwal
-- (`task.delay`), supaya penalti bisa memajukan tenggat tanpa membatalkan
-- timer yang sedang berjalan -- dan supaya nilainya bisa diuji dari CLI.
function AccusationGate.cleanupSecondsLeft(session: Session, now: number): number
	local left = session.cleanupDeadline - now
	if left < 0 then
		return 0
	end
	return left
end

-- PRD §5: "Penalti: tiap tuduhan salah menurunkan rank kasus dan memajukan
-- timer cleanup." Lantai `cleanupFloorSeconds` menjaga tuduhan ketiga tidak
-- menghabiskan sisa waktu seketika -- tanpa lantai, penalti beruntun membuat
-- timer kehilangan maknanya sebagai tekanan ringan (PRD §6).
function AccusationGate.applyWrongPenalty(session: Session, now: number): number
	local moved = session.cleanupDeadline - session.config.cleanupPenaltySeconds
	local floor = now + session.config.cleanupFloorSeconds
	if moved < floor then
		moved = floor
	end
	session.cleanupDeadline = moved
	return AccusationGate.cleanupSecondsLeft(session, now)
end

--[[
	Id node yang aktif di SETIAP varian kasus.

	Penyebut rekap dihitung hanya atas node ini. Node khas satu cabang
	(`ev_ledger`, `ded_c_*`, `ded_g_*`) sengaja tidak ikut: kalau ikut, jumlah
	buktinya berbeda antar cabang dan "6 dari 7" versus "6 dari 6" langsung
	menyebut cabang mana yang sedang berjalan -- yaitu pelakunya.

	`isActive` adalah `CaseGraph.isActive` yang di-inject. Aturan varian tetap
	satu: milik `CaseGraph`, yang dipakai validator dan loader. Modul ini tidak
	menyalinnya -- yang dilakukannya hanya menanyakan aturan itu untuk setiap
	varian.
]]
function AccusationGate.commonNodeIds(
	nodes: { { id: string, variants: { string }? } },
	variantIds: { string },
	isActive: (any, string) -> boolean
): { [string]: boolean }
	local common: { [string]: boolean } = {}
	for _, node in nodes do
		if type(node) == "table" and type(node.id) == "string" then
			local inAll = true
			for _, variantId in variantIds do
				if not isActive(node, variantId) then
					inAll = false
					break
				end
			end
			if inAll then
				common[node.id] = true
			end
		end
	end
	return common
end

--[[
	Pernyataan saksi dalam bentuk yang boleh sampai ke Director.

	Menyalin HANYA `who` dan `text`, dan memberi `id` turunan posisi array akar.
	`id` sengaja `stmt_<indeks>` dan bukan sesuatu yang dibaca dari data: nama
	saksi tidak unik (`guard` muncul dua kali di `gallery_01`), dan `id` dari
	data akan membuat `schema/case.schema.json` -- yang menutup
	`briefings.*.statements` dengan `additionalProperties: false` -- harus
	diubah. Indeks akar juga membuat id stabil lintas varian, sehingga
	penandaan Kontradiksi tidak bergeser saat cabang berganti.

	Field `lie` dan `contradicted_by` dibuang di sini, bukan disaring nanti:
	`Net.project` menyalin nilai apa adanya, jadi begitu keduanya ikut masuk ke
	payload, keduanya sampai ke client. Itu mode kegagalan yang sudah dijaga
	kontrol di `tests/leak-sweep.spec.luau`.
]]
function AccusationGate.statementId(index: number): string
	return string.format("stmt_%d", index)
end

function AccusationGate.publicStatements(
	statements: { any },
	applies: (any) -> boolean
): { { id: string, who: string, text: string } }
	local out: { { id: string, who: string, text: string } } = {}
	for index, statement in statements do
		if type(statement) ~= "table" or not applies(statement) then
			continue
		end
		if type(statement.who) ~= "string" or type(statement.text) ~= "string" then
			continue
		end
		table.insert(out, {
			id = AccusationGate.statementId(index),
			who = statement.who,
			text = statement.text,
		})
	end
	return out
end

--[[
	Rekap parsial untuk Cold Case (PRD §5, SOP-03 A.2).

	SOP-03 A.2 menuntut rekap menyebut "bukti yang ditemukan, deduksi yang
	selesai, kontradiksi yang ditandai" DAN menyebut apa yang belum terungkap
	tanpa menyebut jawabannya. Bentuk kembalian di bawah memenuhi keduanya
	secara struktural: seluruhnya angka, tidak ada satu pun id node, teks
	pernyataan, atau nilai field tuduhan. Tidak ada yang bisa dibaca sebagai
	jawaban karena tidak ada yang bisa dibaca sama sekali.

	Aturan yang dipegang seluruh angka di sini: PENYEBUTNYA harus identik di
	semua cabang kasus, karena penyebut yang berbeda antar cabang ("6 dari 7"
	versus "6 dari 6") sudah menyebut cabang mana yang sedang berjalan --
	artinya menyebut pelakunya. Itu sebabnya bukti dihitung atas `common_ids`
	(hanya node yang aktif di SETIAP varian), dan progres deduksi dilaporkan
	sebagai Deduksi Kunci -- penyebutnya N milik kasus, bukan milik cabang.

	Deduksi bonus TIDAK dilaporkan di sini: node deduksi di `gallery_01` semuanya
	khas satu cabang, jadi jumlahnya selalu nol kalau dihitung atas
	`common_ids` -- dan melaporkan "0 deduksi selesai" saat tim sudah
	menyelesaikan empat adalah informasi yang salah, bukan informasi yang aman.
]]
function AccusationGate.recap(session: Session, input: RecapInput): { [string]: number }
	local evidenceFound = 0
	local evidenceTotal = 0

	for _, node in input.active_nodes do
		if input.common_ids[node.id] == true and node.type == "evidence" then
			evidenceTotal += 1
			if input.revealed[node.id] == true then
				evidenceFound += 1
			end
		end
	end

	return {
		evidence_found = evidenceFound,
		evidence_total = evidenceTotal,
		key_deductions_done = input.key_deductions_done,
		key_deductions_required = input.key_deductions_required,
		contradictions_marked = session.contradictionsMarked,
		attempts_used = input.attempts_used,
	}
end

return AccusationGate
