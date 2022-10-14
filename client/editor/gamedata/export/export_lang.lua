local Lang = require "editor.gamedata.lang"
local Seri = require "editor.gamedata.seri"
local Def = require "editor.def"

local M = {}

local function pack_data()
	local keys, texts = Lang:user_sheet()

	local sheet = {}
	for _, key in ipairs(keys) do
		local line = {}
		for locale, map in pairs(texts) do
			line[locale] = map[key]
		end
		line["KEY"] = key
		table.insert(sheet, line)
	end
	return sheet
end

function M:init()
	Lib.subscribeEvent(Event.EVENT_EDITOR_LANG_LOADED, function()
		Seri("csv", pack_data(), Def.PATH_EXPORT_TEXT, false, Lang:user_header())
	end)
	Lib.subscribeEvent(Event.EVENT_EDITOR_LANG_DUMP, function()
		Seri("csv", pack_data(), Def.PATH_EXPORT_TEXT, true, Lang:user_header())
	end)
	Lib.subscribeEvent(Event.EVENT_EDITOR_LANG_MODIFY,function()
		Seri("csv",pack_data(),Def.PATH_EXPORT_TEXT,false,Lang:user_header())
	end)
end

function M:sync()
	Lib.subscribeEvent(Event.EVENT_EDITOR_LANG_LOADED, function()
		Seri("csv", pack_data(), Def.PATH_EXPORT_TEXT, false, Lang:user_header())
	end)
end

return M
