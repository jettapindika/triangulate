--!nocheck
--[[
	Compat.luau — jembatan require lintas runtime.

	Di dalam Roblox global `script` selalu tersedia, jadi modul tetangga diambil
	lewat `script.Parent[nama]`. Di luar Roblox (harness CLI) global `script`
	bernilai nil, sehingga dipakai require relatif terhadap file ini.

	Path require di sini selalu dinamis (nama modul baru diketahui saat runtime),
	sehingga file ini ditandai `--!nocheck`: luau-analyze tidak bisa memverifikasi
	require dinamis. Modul case lain tetap strict dan bebas global `script`.
]]

local Compat = {}

local robloxScript: any = (script :: any)

function Compat.requireSibling(name: string): any
	if robloxScript ~= nil then
		return require(robloxScript.Parent[name])
	end
	return require("./" .. name)
end

return Compat
