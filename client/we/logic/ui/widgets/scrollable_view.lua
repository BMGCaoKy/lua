local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local background_image = node["BackGroundImage"]
	gui_window:setProperty("BackGroundImage",Converter(background_image,"ImageKey"))
	Signal:subscribe(background_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BackGroundImage",Converter(background_image,"ImageKey"))
	end)

	local bg_image_stretch = node["BgImageStretch"]
	gui_window:setProperty("BgImageStretch",Converter(bg_image_stretch,"Stretch"))
	Signal:subscribe(bg_image_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BgImageStretch",Converter(bg_image_stretch,"Stretch"))
	end)
end

return M