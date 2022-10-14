local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local nor_image = node["NormalImage"]
	gui_window:setProperty("NormalImage",Converter(nor_image,"ImageKey"))
	Signal:subscribe(nor_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("NormalImage",Converter(nor_image,"ImageKey"))
	end)
	
	local dis_image = node["DisabledImage"]
	gui_window:setProperty("DisabledImage",Converter(dis_image,"ImageKey"))
	Signal:subscribe(dis_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("DisabledImage",Converter(dis_image,"ImageKey"))
	end)

	local pus_image = node["PushedImage"]
	gui_window:setProperty("PushedImage",Converter(pus_image,"ImageKey"))
	Signal:subscribe(pus_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("PushedImage",Converter(pus_image,"ImageKey"))
	end)

	local normal_text_colour = node["NormalTextColour"]
	gui_window:setProperty("NormalTextColour",Converter(normal_text_colour,"Colours"))
	Signal:subscribe(normal_text_colour, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("NormalTextColour",Converter(normal_text_colour,"Colours"))
	end)

	local disabled_text_colour = node["DisabledTextColour"]
	gui_window:setProperty("DisabledTextColour",Converter(disabled_text_colour,"Colours"))
	Signal:subscribe(disabled_text_colour, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("DisabledTextColour",Converter(disabled_text_colour,"Colours"))
	end)

	local pushed_text_colour = node["PushedTextColour"]
	gui_window:setProperty("PushedTextColour",Converter(pushed_text_colour,"Colours"))
	Signal:subscribe(pushed_text_colour, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("PushedTextColour",Converter(pushed_text_colour,"Colours"))
	end)
	
	local nor_stretch = node["NormalStretch"]
	gui_window:setProperty("NormalStretch",Converter(nor_stretch,"Stretch"))
	Signal:subscribe(nor_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("NormalStretch",Converter(nor_stretch,"Stretch"))
	end)

	local dis_stretch = node["DisabledStretch"]
	gui_window:setProperty("DisabledStretch",Converter(dis_stretch,"Stretch"))
	Signal:subscribe(dis_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("DisabledStretch",Converter(dis_stretch,"Stretch"))
	end)

	local pus_stretch = node["PushedStretch"]
	gui_window:setProperty("PushedStretch",Converter(pus_stretch,"Stretch"))
	Signal:subscribe(pus_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("PushedStretch",Converter(pus_stretch,"Stretch"))
	end)

	local border_colours = node["BorderColor"]
	gui_window:setProperty("BorderColor",Converter(border_colours,"Colours"))
	Signal:subscribe(border_colours, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BorderColor",Converter(border_colours,"Colours"))
	end)

	local text_offset = node["TextOffset"]
	gui_window:setProperty("TextOffset",Converter(text_offset,"Vector2"))
	Signal:subscribe(text_offset, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("TextOffset",Converter(text_offset,"Vector2"))
	end)
end

return M