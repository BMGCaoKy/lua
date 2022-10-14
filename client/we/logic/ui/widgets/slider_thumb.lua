local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local thumb_image = node["thumb_image"]
	gui_window:setProperty("thumb_image",Converter(thumb_image,"ImageKey"))
	Signal:subscribe(thumb_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("thumb_image",Converter(thumb_image,"ImageKey"))
	end)
	
	local thumb_stretch = node["thumb_stretch"]
	gui_window:setProperty("thumb_stretch",Converter(thumb_stretch,"Stretch"))
	Signal:subscribe(thumb_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("thumb_stretch",Converter(thumb_stretch,"Stretch"))
	end)
end

return M