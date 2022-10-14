local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local effect_name = node["effectName"]
	gui_window:setProperty("effectName",effect_name.asset)
	Signal:subscribe(effect_name, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("effectName", effect_name.asset)
	end)
--[[
	local effect_position = node["EffectPosition"]
	Signal:subscribe(effect_position, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("EffectPosition", Converter(effect_position))
	end)

	local effect_rotation = node["EffectRotation"]
	Signal:subscribe(effect_rotation, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("EffectRotation", Converter(effect_rotation))
	end)
--]]
end

return M