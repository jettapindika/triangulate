--!strict
-- Runner uji: memuat seluruh spec lalu melaporkan hasilnya.
--
-- Dipakai di CLI:
--   $HOME/.local/roboxtools/lune.d/lune run tests/run.luau
--
-- Keluar dengan kode non-nol bila ada assertion gagal, sehingga seam CI
-- (EXTA-34) bisa memakainya apa adanya.

local Harness = require("./harness")

-- Modul murni yang diuji di sini tidak menyentuh global Roblox, jadi seluruh
-- suite berjalan tanpa Studio. Itu alasan modul-modul ini dipisahkan dari glue
-- di `init.server.luau` / `init.client.luau`.
require("./net.spec")
require("./ping.spec")
require("./role-assignment.spec")
require("./matchmaking.spec")
require("./deduction.spec")
require("./clue-graph.spec")
require("./accusation.spec")
require("./telemetry.spec")
require("./case-loader.spec")
require("./npc.spec")

Harness.report()

return nil
