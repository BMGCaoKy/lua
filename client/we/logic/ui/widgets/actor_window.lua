local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local actor_name = node["ActorName"]
	gui_window:setProperty("ActorName",actor_name.asset)
	Signal:subscribe(actor_name, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ActorName",actor_name.asset)
	end)
end

return M