--!strict
-- Runner uji: memuat seluruh spec lalu melaporkan hasilnya.
--
-- Dipakai di CLI:
--   $HOME/.local/roboxtools/lune.d/lune run tests/run.luau
--
-- Keluar dengan kode non-nol bila ada assertion gagal, sehingga seam CI
-- (EXTA-34) bisa memakainya apa adanya.
--
-- Satu pintu untuk dua jalur kerja yang bertemu di EXTA-54:
--   * spec EXTA-33 (`case-schema.spec.luau`) menguji skema, validator, dan
--     loader data kasus di `src/shared/case/`;
--   * spec EXTA-32 menguji kontrak data dan modul gameplay di `src/server/`
--     dan `src/shared/`.

local Harness = require("./harness")

-- Modul murni yang diuji di sini tidak menyentuh global Roblox, jadi seluruh
-- suite berjalan tanpa Studio. Itu alasan modul-modul ini dipisahkan dari glue
-- di `init.server.luau` / `init.client.luau`.
require("./case-schema.spec")
require("./leak-sweep.spec")
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
require("./puzzle-table.spec")
require("./puzzle-table-service.spec")

Harness.report()

return nil
