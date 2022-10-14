local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local image = node["MaskImage"]
	gui_window:setProperty("MaskImage",Converter(image,"ImageKey"))
	Signal:subscribe(image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("MaskImage",Converter(image,"ImageKey"))
	end)
	

end

return M