local Mapping = require "editor.gamedata.module.mapping"
local Seri = require "editor.gamedata.seri"
local Def = require "editor.def"

local M = {}

local function pack_data()
	local data = {}
	for module_name, module in pairs(Mapping:data().mapping) do
		data[module_name] = {}
		for key, val in pairs(module) do
			if type(key) == "number" then
				data[module_name][tostring(key)] = string.format("%s/%s", Def.DEFAULT_PLUGIN, val)
			end
		end
	end
	for module_name, module in pairs(Mapping:data().user_mapping) do
		data[module_name] = data[module_name] or {}
		for key, val in pairs(module) do
			if type(key) == "number" then
				local id = tostring(key + Mapping.MAPPING_OFFSET)
				data[module_name][id] = string.format("%s/%s", Def.DEFAULT_PLUGIN, val)
			end
		end
	end
	return data
end

function M:init()
	Lib.subscribeEvent(Event.EVENT_EDITOR_MAPPING_LOADED, function()
		self:sync()
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_MAPPING_MODIFY, function()
		self:sync()
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_MAPPING_DUMP, function()
		local data = pack_data()
		Seri("json", data, Def.PATH_EXPORT_ID_MAPPING, true)
	end)
end

function M:sync()
	local data = pack_data()
	Seri("json", data, Def.PATH_EXPORT_ID_MAPPING, false)
end

return M
