local Module = require "we.gamedata.module.module"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"

local M = {}

function M:list()
	local ret = {}
	for name, item in pairs(Module:module("item"):list()) do
		local item2 = item:obj().item
		if item2.type == "InHand" and item2.base.isCoin then	
			table.insert(ret, name)
		end
	end
	return ret
end

function M:save()
	local data = {}
	for i, v in ipairs(self:list()) do
		table.insert(data, {
			coinName = v,
			item = {
				type = "Item",
				name = "myplugin/" .. v
			},
			showUi = false
		})
	end
	local path = Lib.combinePath(Def.PATH_GAME, "coin.json")
	Seri("json", data, path, true)
end

return M