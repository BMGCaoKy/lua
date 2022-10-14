local Seri = require "editor.gamedata.seri"
local Def = require "editor.def"

local M = {}

local function pack_data()
	return {
		{
			coinName = "green_currency",
			type = 0,
			icon = "set:jail_break.json image:jail_break_currency",
			itemName = ""
		}
	}
end

function M:init()
	Seri("json",pack_data(),Def.PATH_EXPORT_COIN,false)
end

function M:sync()
	Seri("json",pack_data(),Def.PATH_EXPORT_COIN,false)
end

return M
