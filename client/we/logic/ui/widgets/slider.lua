local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local thumb = node["thumb"]
	if thumb then
		local gui_thumb = gui_window:getThumb()
		local thumb_image = thumb["thumb_image"]
		gui_thumb:setProperty("thumb_image",Converter(thumb_image,"ImageKey"))
		gui_window:setProperty("slider_thumb_image",Converter(thumb_image,"ImageKey"))
		Signal:subscribe(thumb_image, Def.NODE_EVENT.ON_ASSIGN, function()
			gui_thumb:setProperty("thumb_image",Converter(thumb_image,"ImageKey"))
			gui_window:setProperty("slider_thumb_image",Converter(thumb_image,"ImageKey"))
		end)

		local thumb_stretch = thumb["thumb_stretch"]
		gui_thumb:setProperty("thumb_stretch",Converter(thumb_stretch,"Stretch"))
		Signal:subscribe(thumb_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
			gui_thumb:setProperty("thumb_stretch",Converter(thumb_stretch,"Stretch"))
		end)
	end

	local slider_image = node["slider_top"]
	gui_window:setProperty("slider_top",Converter(slider_image,"ImageKey"))
	Signal:subscribe(slider_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("slider_top",Converter(slider_image,"ImageKey"))
	end)

	local top_Image_stretch = node["TopImageStretch"]
	gui_window:setProperty("TopImageStretch",Converter(top_Image_stretch,"Stretch"))
	Signal:subscribe(top_Image_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("TopImageStretch",Converter(top_Image_stretch,"Stretch"))
	end)

	local slider_bg = node["slider_bg"]
	gui_window:setProperty("slider_bg",Converter(slider_bg,"ImageKey"))
	Signal:subscribe(slider_bg, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("slider_bg",Converter(slider_bg,"ImageKey"))
	end)
	
	local bg_image_stretch = node["BgImageStretch"]
	gui_window:setProperty("BgImageStretch",Converter(bg_image_stretch,"Stretch"))
	Signal:subscribe(bg_image_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BgImageStretch",Converter(bg_image_stretch,"Stretch"))
	end)
end

return M