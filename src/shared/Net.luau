--!strict
-- Kontrak data server <-> client (PRD §15).
--
-- Mekanisme yang menjamin solusi tidak pernah sampai ke client ada dua lapis,
-- dan keduanya harus tetap benar:
--
--   1. STRUKTURAL. Data kasus hidup di `ServerStorage.Cases` (lihat
--      `default.project.json`). Dokumentasi Roblox: "Objects descending from
--      ServerStorage will not replicate to the client and will not be
--      accessible from LocalScripts."
--      -> https://create.roblox.com/docs/reference/engine/classes/ServerStorage
--      Jadi tabel solusi tidak punya jalur jaringan sama sekali. Modul ini
--      hanya menyaring apa yang MEMANG dikirim lewat RemoteEvent.
--
--   2. PROYEKSI WHITELIST. Setiap payload yang menyeberang ke client dilewatkan
--      `Net.project` dengan daftar field yang diizinkan untuk role penerimanya.
--      Fungsi ini MENYALIN field yang disebut, bukan menghapus yang dilarang.
--      Konsekuensinya: field baru yang ditambahkan ke data kasus tidak pernah
--      bocor secara default -- penulis kasus harus secara sadar menambahkannya
--      ke sebuah view. Ini kebalikan dari pendekatan blacklist, yang bocor
--      begitu seseorang menambah field sensitif baru.
--
-- Modul ini murni: tidak menyentuh global Roblox, sehingga bisa diuji dari CLI
-- (lihat `tests/net.spec.luau`). Jangan menambahkan referensi `game`/`script`
-- di sini.

local SECRET_FIELDS: { string } = {
	"solution",
	"variants",
	"culprit",
	"motive",
	"method",
	"key_deductions",
	"lie",
	"contradicted_by",
	"draft",
}

local REMOTE_NAMES: { string } = {
	-- PRD §8: lobby adalah fase SEBELUM sesi. `LobbyState` adalah payload
	-- pertama yang menyeberang ke client, dan tiga remote lobby di ujung daftar
	-- satu-satunya yang boleh dikirim client selama fase itu.
	"LobbyState",
	"SessionState",
	"ClueCard",
	"TargetMarker",
	"Pinpoint",
	"ReportCard",
	"AccusationResult",
	"DeductionResult",
	"PuzzleState",
	"PiecePlaced",
	"Report",
	"SubmitDeduction",
	"Accuse",
	"Ping",
	"PingRelay",
	"SetTarget",
	"RequestHint",
	"ConfirmAccusation",
	"PlacePiece",
	"MarkContradiction",
	"ContradictionResult",
	"TablePreview",
	"Inspect",
	"SubmitPreferences",
	"SetReady",
	"RequestSwap",
}

-- Remote yang arahnya server -> client.
--
-- `PingRelay` terpisah dari `Ping` karena arahnya berlawanan: `Ping` membawa
-- frasa dari client ke server (PRD §7), sedangkan `PingRelay` membawa frasa itu
-- kembali ke role lain. Menggabungkan keduanya jadi satu remote dua arah akan
-- melanggar pemisahan arah yang diuji `tests/net.spec.luau` -- dan pemisahan itu
-- yang membuat tiap kanal bisa punya validasi sendiri.
local SERVER_TO_CLIENT: { [string]: boolean } = {
	LobbyState = true,
	SessionState = true,
	ClueCard = true,
	TargetMarker = true,
	Pinpoint = true,
	ReportCard = true,
	AccusationResult = true,
	DeductionResult = true,
	PuzzleState = true,
	PiecePlaced = true,
	PingRelay = true,
	ContradictionResult = true,
	TablePreview = true,
}

-- Remote yang arahnya client -> server. Setiap handler-nya wajib memvalidasi
-- ulang argumen; client tidak dipercaya. Dokumentasi Roblox: "Every piece of
-- data sent from a client must be validated by the server before it's used."
-- -> https://create.roblox.com/docs/scripting/security/client-server-boundary
local CLIENT_TO_SERVER: { [string]: boolean } = {
	Report = true,
	SubmitDeduction = true,
	Accuse = true,
	Ping = true,
	-- PRD §7: "Target Marker: Handler menaruh ikon target." Marker dipasang
	-- Handler, jadi arahnya client -> server, dan server yang meneruskannya ke
	-- Searcher lewat `TargetMarker` (server -> client). `docs/arsitektur.md`
	-- menggambar panah `H->>Srv: TargetMarker`; panah itu memang salah nama,
	-- dan remote ini yang benar.
	SetTarget = true,
	RequestHint = true,
	ConfirmAccusation = true,
	PlacePiece = true,
	MarkContradiction = true,
	-- PRD §6: mini-aksi Searcher (senter UV, buka laci, lockpick). Client
	-- melaporkan "saya mulai/selesai/batal memeriksa objek X", server yang
	-- memutuskan apakah itu sah dan kunci apa yang diberikan.
	Inspect = true,
	-- PRD §3: pemain memilih 2 preferensi role SEBELUM matchmaking.
	SubmitPreferences = true,
	-- PRD §8: ready check 10 detik sebelum mulai; pemain yang tidak siap
	-- diganti NPC.
	SetReady = true,
	-- PRD §8: "Pemain boleh tukar role di lobby (saling setuju)." Client hanya
	-- MENGIRIM permintaan; penukaran terjadi saat pihak lain meminta arah
	-- sebaliknya, dan itu diputuskan `LobbyFlow.requestSwap` di server.
	RequestSwap = true,
}

-- Field yang boleh dilihat tiap role, per jenis payload.
--
-- `briefing` sengaja berbeda per role: PRD §4 dan §9 menyatakan tiap role
-- memegang informasi berbeda. Searcher tidak boleh tahu isi meja Handler,
-- dan tidak ada role yang boleh tahu field solusi.
local CLIENT_VIEWS: { [string]: { [string]: { string } } } = {
	-- PRD §3, §8: layar lobby -- pemilihan 2 preferensi, tombol siap, dan
	-- hitungan pemain. Ketiga role menerima bentuk yang sama; yang membedakan
	-- hanya isinya, karena `preferences`/`ready` diisi `LobbyFlow.snapshot`
	-- hanya untuk pemain yang benar-benar ada di lobby.
	--
	-- Yang sengaja TIDAK ada di sini: penugasan role. Penugasan baru ada setelah
	-- sesi dimulai (PRD §8: matchmaking menetapkan role SETELAH preferensi
	-- terkumpul), dan menaruhnya di payload lobby akan memberi tiap pemain
	-- daftar role pemain lain sebelum waktunya.
	lobby_state = {
		Searcher = {
			"phase",
			"seconds_left",
			"player_count",
			"ready_count",
			"max_players",
			"preferences",
			"ready",
		},
		Handler = {
			"phase",
			"seconds_left",
			"player_count",
			"ready_count",
			"max_players",
			"preferences",
			"ready",
		},
		Director = {
			"phase",
			"seconds_left",
			"player_count",
			"ready_count",
			"max_players",
			"preferences",
			"ready",
		},
	},

	-- PRD §9: Role Card berisi "Kamu tahu apa / Tidak tahu apa / Tugas pertamamu".
	--
	-- `briefing.statements` (Director) adalah satu-satunya jalur pernyataan
	-- saksi ke client: `CaseLoader.projectForRole` yang menyaringnya per varian
	-- dan membuang `lie`/`contradicted_by`/`variants` sebelum proyeksi ini,
	-- karena `Net.project` menyalin nilai apa adanya. `id` adalah indeks
	-- 1-based di `case.statements` dan itulah identitas pernyataan -- `who`
	-- tidak unik (`gallery_01.json` punya dua pernyataan `guard`).
	briefing = {
		Searcher = { "case_id", "location", "objective", "knowns", "unknowns", "target" },
		Handler = { "case_id", "location", "objective", "knowns", "unknowns", "target" },
		Director = { "case_id", "location", "objective", "knowns", "unknowns", "statements" },
	},

	-- PRD §4: Clue Card adalah fakta yang dikirim dari bukti ke clue board.
	clue_card = {
		Searcher = { "id", "title", "summary" },
		Handler = { "id", "title", "summary" },
		Director = { "id", "title", "summary", "source" },
	},

	-- PRD §4: Deduksi menaruh pinpoint baru dan membuka target baru.
	--
	-- `reason` dibawa HANYA untuk kombinasi yang ditolak. Berbeda dengan
	-- tuduhan (PRD §5: "hanya 'X dari 3 benar', tidak menyebutkan field mana"),
	-- kombinasi Clue Card bukan tebakan terhadap solusi -- ia pemeriksaan
	-- resep, dan `DeductionEngine` sudah mengembalikan alasan berbahasa
	-- Indonesia yang tidak menyebut resep mana pun. Tanpa alasan, Director
	-- tidak bisa membedakan "kartu belum lengkap" dari "kombinasi salah".
	--
	-- `pinpoint_label` adalah label node yang dibuka (teks yang sudah ada di
	-- data kasus), bukan informasi baru tentang solusi.
	deduction = {
		Searcher = { "id", "pinpoint", "pinpoint_label", "unlocks", "reason" },
		Handler = { "id", "pinpoint", "pinpoint_label", "unlocks", "reason" },
		Director = { "id", "pinpoint", "pinpoint_label", "unlocks", "clue_ids", "reason" },
	},

	-- PRD §4, §7: pinpoint baru hasil Deduksi. PRD §7: "Pinpoint: Director
	-- menaruh marker yang terlihat di dunia Searcher." Handler tidak menerimanya
	-- -- ia bekerja di meja, bukan di lokasi (PRD §3).
	pinpoint = {
		Searcher = { "id", "label" },
		Director = { "id", "label" },
	},

	-- PRD §4, §5: hasil penandaan Kontradiksi. `reason` di sini memang
	-- player-readable -- issue memintanya -- tapi sengaja TIDAK membedakan
	-- "pernyataan ini jujur" dari "bukti pembantahnya belum ada", supaya tidak
	-- jadi oracle pembohong. Lihat `AccusationGate.REJECT_REASON`.
	--
	-- `statement_id` dikirim sebagai ANGKA: itu `id` yang sudah dipakai papan
	-- Director di `session_state.statements`, jadi papan tidak perlu
	-- menerjemahkan apa pun untuk mencocokkan balasan dengan tombolnya.
	--
	-- `gate_open` dan angka-angkanya ikut supaya clue board bisa memperbarui
	-- status form tuduhan tanpa menunggu `session_state` berikutnya.
	contradiction_result = {
		Director = {
			"accepted",
			"statement_id",
			"reason",
			"marked_count",
			"contradictions_required",
			"deductions_done",
			"key_deductions_required",
			"gate_open",
		},
	},

	-- PRD §6: timer cleanup dan progres rantai. PRD §5: progres gerbang dan
	-- rekap Cold Case.
	--
	-- `key_deductions_required` adalah ANGKA ambang gerbang (N), bukan daftar
	-- deduksi mana yang kunci. Nama `key_deductions` sengaja tidak dipakai di
	-- sini: ia ada di SECRET_FIELDS dan berarti daftar identitasnya. Memakai
	-- nama yang sama untuk dua arti berbeda akan membuat `validateViews` gagal
	-- -- dan memang seharusnya begitu, karena proyeksi whitelist bekerja per
	-- nama field.
	--
	-- `gate_open` adalah hasil gerbang yang sudah dihitung server. Ia boleh
	-- sampai ke client karena client MEMANG perlu tahu kapan tombolnya hidup;
	-- yang tidak boleh sampai adalah komponen pembentuknya selain angka
	-- progres. Form di client karena itu hanya menyembunyikan/menonaktifkan
	-- tombol -- penegakannya tetap di server (`AccusationGate.admit` dipanggil
	-- `init.server.luau` sebelum tuduhan dinilai).
	--
	-- `cold_case_recap` hanya berisi angka (lihat `AccusationGate.recap`), jadi
	-- ia tidak bisa dibaca sebagai jawaban.
	session_state = {
		Searcher = {
			"case_id",
			"role",
			"phase",
			"seconds_left",
			"chains",
			"cleanup_seconds_left",
			"cold_case_recap",
		},
		Handler = {
			"case_id",
			"role",
			"phase",
			"seconds_left",
			"chains",
			"cleanup_seconds_left",
			"cold_case_recap",
		},
		Director = {
			"case_id",
			"role",
			"phase",
			"seconds_left",
			"chains",
			"deductions_done",
			"key_deductions_required",
			"key_deductions_done",
			"contradictions_marked",
			"contradictions_required",
			"gate_open",
			"cleanup_seconds_left",
			"cold_case_recap",
		},
	},

	-- PRD §7: Report Card = foto objek + tag lokasi otomatis.
	--
	-- `label` ikut karena `image` masih placeholder (`rbxassetid://0`, lihat
	-- `docs/mvp-notes.md`): tanpa label, kartu laporan tidak bisa dibaca sama
	-- sekali. Saat aset foto nyata ada, label tetap berguna sebagai alt text.
	report_card = {
		Searcher = { "id", "object_id", "label", "location", "image" },
		Handler = { "id", "object_id", "label", "location", "image", "gives_key" },
		Director = { "id", "object_id", "label", "location", "image" },
	},

	-- PRD §7: "Target Marker: Handler menaruh ikon target yang muncul di HUD
	-- Searcher dan arah kompas."
	--
	-- `bearing` adalah arah marker pada bidang lokasi dalam derajat (0 = utara
	-- = -Z, searah jarum jam), dihitung server dari `LocationMap` -- client
	-- tidak perlu tahu koordinat dunia mana pun. Handler menerima `target_id`
	-- dan `label` saja: ia yang memasang marker, jadi ia tidak butuh arahnya
	-- sendiri.
	target_marker = {
		Searcher = { "target_id", "label", "bearing" },
		Handler = { "target_id", "label" },
	},

	-- PRD §7: ping wheel. Yang menyeberang hanya ID frasa dan labelnya dari
	-- `PingPhrases` -- client tidak pernah mengirim atau menerima teks bebas.
	-- `from_role` dipakai penerima untuk menampilkan siapa yang meming.
	ping = {
		Searcher = { "from_role", "phrase_id", "label" },
		Handler = { "from_role", "phrase_id", "label" },
		Director = { "from_role", "phrase_id", "label" },
	},

	-- PRD §5: feedback salah hanya "X dari 3 benar", tanpa menyebut field mana.
	accusation_result = {
		Searcher = { "correct_count", "attempts_left" },
		Handler = { "correct_count", "attempts_left" },
		Director = {
			"correct_count",
			"attempts_left",
			"resolved",
			"won",
			"pending_confirmation",
			"rank",
		},
	},

	-- PRD §5: ruang pilihan untuk form tuduhan. Ini kandidat, bukan jawaban --
	-- solusinya tetap hanya ada di server.
	accusation_options = {
		Searcher = { "suspects", "motives", "methods" },
		Handler = { "suspects", "motives", "methods" },
		Director = { "suspects", "motives", "methods" },
	},

	-- PRD §4, §15: meja puzzle Handler. Searcher tidak memegang meja sama
	-- sekali; Director boleh melihatnya karena PRD §8 memberi Director hak
	-- mengambil alih puzzle manual saat Handler diisi NPC (mode 2 pemain).
	--
	-- Field `region` adalah indeks potongan pada gambar sumber. Sel tujuan
	-- (`target`) dan flag `correct` TIDAK ada di daftar ini -- keduanya
	-- server-only, lihat `src/shared/PuzzleTable.luau`.
	puzzle_state = {
		Handler = { "puzzle_id", "cols", "rows", "pieces" },
		Director = { "puzzle_id", "cols", "rows", "pieces" },
	},

	-- PRD §7: "Table Preview: Director melihat thumbnail meja Handler
	-- (read-only) supaya tahu progres tanpa bertanya."
	--
	-- Hanya angka progres dan identitas meja -- bukan potongan, bukan posisi,
	-- bukan sel tujuan. Thumbnail-nya sendiri digambar client dari progres itu;
	-- mengirim potongan penuh hanya akan menduplikasi `puzzle_state` dan
	-- memberi Director kendali meja yang bukan miliknya.
	table_preview = {
		Director = { "entries" },
	},

	-- PRD §15: hasil penempatan otoritatif. Client memakainya untuk
	-- menginterpolasi posisi potongan ke nilai server; `accepted` false berarti
	-- drop ditolak dan client harus menarik potongan kembali.
	piece_placed = {
		Handler = { "piece_id", "x", "y", "placed", "accepted" },
		Director = { "piece_id", "x", "y", "placed", "accepted" },
	},
}

local Net = {
	SECRET_FIELDS = SECRET_FIELDS,
	REMOTE_NAMES = REMOTE_NAMES,
	SERVER_TO_CLIENT = SERVER_TO_CLIENT,
	CLIENT_TO_SERVER = CLIENT_TO_SERVER,
	CLIENT_VIEWS = CLIENT_VIEWS,
}

-- Menyalin hanya field yang diizinkan.
--
-- `allowed` adalah himpunan nama field, bukan daftar bersarang: sebuah field
-- yang lolos akan disalin apa adanya. Ini disengaja -- kedalaman struktur bukan
-- tempat menyembunyikan rahasia, dan field bersarang yang sensitif harus punya
-- namanya sendiri di `SECRET_FIELDS` supaya uji bisa menangkapnya.
function Net.project(source: { [string]: any }, allowed: { string }): { [string]: any }
	local allowedSet: { [string]: boolean } = {}
	for _, name in allowed do
		allowedSet[name] = true
	end

	local out: { [string]: any } = {}
	for key, value in source do
		if allowedSet[key] then
			out[key] = value
		end
	end
	return out
end

-- Proyeksi satu payload untuk satu role. Mengembalikan `nil` bila view atau
-- role tidak dikenal -- pemanggil harus memperlakukan `nil` sebagai "jangan
-- kirim", bukan sebagai "kirim kosong".
function Net.forRole(view: string, role: string, source: { [string]: any }): { [string]: any }?
	local byRole = CLIENT_VIEWS[view]
	if byRole == nil then
		return nil
	end

	local allowed = byRole[role]
	if allowed == nil then
		return nil
	end

	return Net.project(source, allowed)
end

-- Melaporkan field rahasia yang muncul di sebuah tabel, termasuk di dalam tabel
-- bersarang. Dipakai uji, dan boleh dipakai sebagai assertion murah saat server
-- start.
function Net.findSecrets(value: any, path: string?): { string }
	local found: { string } = {}
	local here = path or ""

	if type(value) ~= "table" then
		return found
	end

	local secretSet: { [string]: boolean } = {}
	for _, name in SECRET_FIELDS do
		secretSet[name] = true
	end

	local asTable = value :: { [any]: any }
	for key, child in asTable do
		local childPath = here .. "." .. tostring(key)
		if type(key) == "string" and secretSet[key] then
			table.insert(found, childPath)
		end
		for _, nested in Net.findSecrets(child, childPath) do
			table.insert(found, nested)
		end
	end

	return found
end

-- Benar hanya bila tidak ada view yang mengizinkan field rahasia. Dipanggil uji
-- dan saat server start.
function Net.validateViews(): (boolean, { string })
	local problems: { string } = {}

	for viewName, byRole in CLIENT_VIEWS do
		for roleName, allowed in byRole do
			for _, field in allowed do
				for _, secret in SECRET_FIELDS do
					if field == secret then
						table.insert(
							problems,
							string.format(
								"%s.%s mengizinkan field rahasia '%s'",
								viewName,
								roleName,
								secret
							)
						)
					end
				end
			end
		end
	end

	return #problems == 0, problems
end

return Net
