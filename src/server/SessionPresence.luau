--!strict
-- Kehadiran pemain: AFK dan rejoin (PRD §8, kriteria terima EXTA-58 b dan c).
--
-- Pembagian tanggung jawab yang dipegang berkas ini:
--   * `NPCController.luau` -- keputusan "apakah sudah waktunya" dalam bentuk
--     ambang murni (`shouldTakeOver`, `shouldReleaseSlot`).
--   * berkas ini -- siapa yang sudah melewati ambang itu, sekali saja, dan
--     kapan slot yang ditinggalkan dibuka atau dikembalikan.
--   * `init.server.luau` -- glue: menstempel input pemain, memanggil NPC, dan
--     mengirim telemetri.
--
-- Waktu masuk sebagai ARGUMEN (`now`), bukan dibaca dari jam dinding, sehingga
-- aturan waktunya bisa diuji dari CLI dengan waktu virtual
-- (`tests/session-presence.spec.luau`, `tests/lobby-gate-minggu-5.spec.luau`).
--
-- Dua aturan yang tidak kelihatan dari namanya dan disengaja:
--
--   * Pemain yang BELUM PERNAH memberi input bukan kandidat pengambilalihan.
--     "Belum pernah input" tidak bisa dibedakan dari "belum sempat bergabung",
--     dan glue menstempel input pertama saat pemain benar-benar masuk. Tanpa
--     aturan ini, pemain yang baru masuk ke lobby akan langsung "diambil alih".
--     `secondsSinceInput` tetap menghitung dari awal sesi untuk pemain seperti
--     itu -- pertanyaan berbeda, jawaban berbeda.
--
--   * Pengambilalihan dilaporkan SATU per panggilan, supaya handover NPC tidak
--     bertumpuk dalam satu tick server. Penanda "sudah dilaporkan" hanya
--     dipasang pada kandidat yang benar-benar dikembalikan, sehingga kandidat
--     lain dilaporkan pada panggilan berikutnya -- bukan hilang. Memasang
--     penanda itu untuk semua kandidat pernah dicoba dan salah: pemain yang
--     melewati ambang pada tick yang sama dengan pemain lain tidak akan pernah
--     dilaporkan lagi, karena pemain AFK tidak pernah memanggil `touch`. PRD §8
--     menuntut setiap pemain AFK diambil alih, jadi yang ditahan hanya
--     JUMLAHNYA per panggilan, bukan pemainnya.

local SessionPresence = {}

export type Disconnect = {
	userId: number,
	role: string,
	-- Saat disconnect terdeteksi.
	at: number,
	-- Sudah dilaporkan ke NPC.
	reported: boolean,
	-- Slot sudah dibuka untuk pemain pengganti (PRD §8: 3 menit).
	released: boolean,
}

export type Presence = {
	startedAt: number,
	lastInput: { [number]: number },
	disconnects: { [number]: Disconnect? },
	afkReported: { [number]: boolean? },
}

export type Takeover = {
	userId: number,
	role: string,
	-- `afk_60s` atau `disconnect`; sama dengan `trigger` di
	-- `docs/metrics/skema-event-telemetri.md`.
	reason: string,
}

export type ReleasedSlot = {
	userId: number,
	role: string,
}

type Candidate = {
	userId: number,
	role: string,
	reason: string,
	elapsed: number,
	disconnect: boolean,
}

function SessionPresence.new(startedAt: number): Presence
	return {
		startedAt = startedAt,
		lastInput = {},
		disconnects = {},
		afkReported = {},
	}
end

--[[
	Mencatat input bermakna seorang pemain.

	`touch` juga membatalkan penanda pengambilalihan: pemain yang kembali bermain
	memegang kendali role-nya lagi, dan episode AFK berikutnya harus bisa
	dilaporkan (PRD §8: "AFK 60 detik tanpa input").
]]
function SessionPresence.touch(presence: Presence, userId: number, now: number): ()
	presence.lastInput[userId] = now
	presence.afkReported[userId] = nil
end

function SessionPresence.secondsSinceInput(presence: Presence, userId: number, now: number): number
	local since = presence.lastInput[userId]
	if since == nil then
		return now - presence.startedAt
	end
	return now - since
end

--[[
	Mencatat pemain yang keluar (PRD §8: "Disconnect -> slot ditahan 3 menit
	untuk rejoin, NPC mengisi sementara").

	Slot TIDAK dilepas dari `roles` pemanggil: role tetap tercatat supaya rejoin
	mengembalikan pemain ke slot yang sama, bukan ke role baru.
]]
function SessionPresence.markDisconnected(
	presence: Presence,
	userId: number,
	role: string,
	now: number
): ()
	presence.disconnects[userId] = {
		userId = userId,
		role = role,
		at = now,
		reported = false,
		released = false,
	}
	presence.afkReported[userId] = nil
end

--[[
	Pengambilalihan yang jatuh tempo pada `now`.

	Disconnect didahulukan atas AFK: slot yang ditinggalkan harus segera diisi,
	tanpa menunggu 60 detik. Di antara sesama kandidat, AFK dengan waktu menganggur
	TERPANJANG yang dikembalikan -- pemain yang paling lama tidak menyentuh apa
	pun adalah yang paling merugikan tim. Seri diputus oleh id terkecil supaya
	hasilnya tidak bergantung pada urutan iterasi tabel.
]]
function SessionPresence.takeovers(
	presence: Presence,
	roles: { [number]: string },
	now: number,
	afkSeconds: number
): { Takeover }
	local candidates: { Candidate } = {}

	for userId, role in roles do
		local record = presence.disconnects[userId]
		if record ~= nil and not record.reported then
			table.insert(candidates, {
				userId = userId,
				role = role,
				reason = "disconnect",
				elapsed = now - record.at,
				disconnect = true,
			})
		elseif record == nil and not presence.afkReported[userId] then
			local since = presence.lastInput[userId]
			if since ~= nil then
				local elapsed = now - since
				if elapsed >= afkSeconds then
					table.insert(candidates, {
						userId = userId,
						role = role,
						reason = "afk_60s",
						elapsed = elapsed,
						disconnect = false,
					})
				end
			end
		end
	end

	local chosen: Candidate? = nil
	for _, candidate in candidates do
		local held = chosen
		if held == nil or (candidate.disconnect and not held.disconnect) then
			chosen = candidate
		elseif candidate.disconnect == held.disconnect then
			local better = if candidate.disconnect
				then candidate.elapsed < held.elapsed
				else candidate.elapsed > held.elapsed
			if better or (candidate.elapsed == held.elapsed and candidate.userId < held.userId) then
				chosen = candidate
			end
		end
	end

	if chosen == nil then
		return {}
	end

	-- Penanda dipasang SETELAH pilihan jatuh, bukan saat kandidat dikumpulkan:
	-- hanya pemain yang benar-benar diserahkan ke NPC yang dianggap sudah
	-- dilaporkan.
	local record = presence.disconnects[chosen.userId]
	if record ~= nil then
		record.reported = true
	else
		presence.afkReported[chosen.userId] = true
	end

	return { { userId = chosen.userId, role = chosen.role, reason = chosen.reason } }
end

--[[
	Slot yang masa tahanannya habis dan siap diisi pemain pengganti.

	PRD §8: "Setelah 3 menit slot dibuka untuk pemain pengganti (join-in-progress)
	atau tetap NPC." Syaratnya hanya "masa tahanan habis" -- bukan "belum
	diambil alih NPC". Kedua hal itu berbeda, dan yang pertama yang benar: slot
	yang sudah diisi NPC sementara tetap harus dibuka setelah 3 menit, kalau
	tidak role itu dipegang NPC selamanya dan tidak ada pemain pengganti yang
	bisa masuk.

	Diurutkan berdasarkan id pemain supaya hasilnya deterministik. Slot yang
	sudah dibuka tidak dilaporkan dua kali.
]]
function SessionPresence.releasedSlots(
	presence: Presence,
	now: number,
	holdSeconds: number
): { ReleasedSlot }
	local out: { ReleasedSlot } = {}

	for _, record in presence.disconnects do
		if record ~= nil and not record.released and now - record.at >= holdSeconds then
			record.released = true
			table.insert(out, { userId = record.userId, role = record.role })
		end
	end

	table.sort(out, function(a: ReleasedSlot, b: ReleasedSlot): boolean
		return a.userId < b.userId
	end)

	return out
end

--[[
	Rejoin ke slot yang sama (kriteria terima c).

	Hanya berlaku selama slot masih ditahan dan belum dibuka. Setelah kembali,
	jam input pemain disetel ulang supaya ia tidak langsung dianggap AFK lagi,
	dan catatan disconnect dibuang sehingga rejoin kedua ditolak.
]]
function SessionPresence.rejoin(
	presence: Presence,
	userId: number,
	now: number,
	holdSeconds: number
): (boolean, string?)
	local record = presence.disconnects[userId]
	if record == nil or record.released then
		return false, nil
	end
	if now - record.at >= holdSeconds then
		return false, nil
	end

	presence.disconnects[userId] = nil
	presence.afkReported[userId] = nil
	presence.lastInput[userId] = now
	return true, record.role
end

return SessionPresence
