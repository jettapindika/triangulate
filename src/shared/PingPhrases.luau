--!strict
-- Frasa ping wheel (PRD §7).
--
-- PRD §7: "Roda dengan 6-8 frasa yang berubah sesuai role dan situasi." Modul
-- ini adalah satu-satunya tempat frasa ditulis, dan sengaja murni supaya
-- pemilihan frasa bisa diuji dari CLI.
--
-- Yang dipilih client hanyalah FRASA yang ditampilkan. Mengirim ping tidak
-- memberi client wewenang apa pun: server tetap memutuskan efeknya.

local PingPhrases = {}

export type Phrase = {
	id: string,
	label: string,
}

-- PRD §7: "Semua: 'Setuju', 'Ragu', 'Tolong ulangi'" -- tersedia untuk tiap role.
local UNIVERSAL: { Phrase } = {
	{ id = "agree", label = "Setuju" },
	{ id = "unsure", label = "Ragu" },
	{ id = "repeat", label = "Tolong ulangi" },
}

local BY_ROLE: { [string]: { Phrase } } = {
	Searcher = {
		{ id = "found", label = "Nemu sesuatu!" },
		{ id = "locked", label = "Terkunci, butuh kode" },
		{ id = "danger", label = "Ada bahaya" },
		{ id = "checked", label = "Sudah dicek" },
	},
	Handler = {
		{ id = "target", label = "Cari benda bertanda ini" },
		{ id = "evidence_open", label = "Bukti terbuka" },
		{ id = "need_key", label = "Butuh kunci lain" },
	},
	Director = {
		{ id = "goto", label = "Ke pinpoint ini" },
		{ id = "recheck", label = "Periksa ulang" },
		{ id = "need_time", label = "Aku butuh waktu" },
	},
}

-- PRD §7: roda berisi 6-8 frasa. Bila gabungan role + universal melebihi 8,
-- yang dipotong adalah frasa universal dari belakang, bukan frasa role --
-- frasa role adalah yang paling kontekstual dan paling sering dipakai.
local MAX_PHRASES = 8

function PingPhrases.forRole(role: string): { Phrase }
	local out: { Phrase } = {}

	local rolePhrases = BY_ROLE[role]
	if rolePhrases ~= nil then
		for _, phrase in rolePhrases do
			table.insert(out, phrase)
		end
	end

	for _, phrase in UNIVERSAL do
		if #out >= MAX_PHRASES then
			break
		end
		table.insert(out, phrase)
	end

	return out
end

-- Memvalidasi satu frasa yang dikirim client. Server memakai ini supaya client
-- tidak bisa menyiarkan teks bebas lewat kanal ping.
function PingPhrases.isValid(role: string, phraseId: string): boolean
	for _, phrase in PingPhrases.forRole(role) do
		if phrase.id == phraseId then
			return true
		end
	end
	return false
end

--[[
	Label frasa untuk ditampilkan. Dipakai dua sisi:

	  - server, saat merelay ping ke role lain (penerima butuh teksnya),
	  - client, saat menampilkan toast atas ping yang ia kirim sendiri.

	Label sengaja TIDAK disimpan client. Kalau client menyimpan salinannya
	sendiri, dua daftar frasa bisa menyimpang dan teks yang dikirim ke pemain
	berhenti cocok dengan yang divalidasi server.

	Mengembalikan nil bila frasa tidak dikenal -- pemanggil memperlakukan nil
	sebagai "jangan kirim", bukan sebagai frasa kosong.
]]
function PingPhrases.labelFor(role: string, phraseId: string): string?
	if type(phraseId) ~= "string" then
		return nil
	end
	for _, phrase in PingPhrases.forRole(role) do
		if phrase.id == phraseId then
			return phrase.label
		end
	end
	return nil
end

return PingPhrases
