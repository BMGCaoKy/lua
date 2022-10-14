local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local unSelect_image = node["unselectableImage"]
	gui_window:setProperty("unselectableImage",Converter(unSelect_image,"ImageKey"))
	Signal:subscribe(unSelect_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("unselectableImage",Converter(unSelect_image,"ImageKey"))
	end)

	local unselectable_Stretch = node["UnselectableStretch"]
	gui_window:setProperty("UnselectableStretch",Converter(unselectable_Stretch,"Stretch"))
	Signal:subscribe(unselectable_Stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("UnselectableStretch",Converter(unselectable_Stretch,"Stretch"))
	end)
	
	local select_image = node["selectableImage"]
	gui_window:setProperty("selectableImage",Converter(select_image,"ImageKey"))
	Signal:subscribe(select_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("selectableImage",Converter(select_image,"ImageKey"))
	end)

	local selectable_Stretch = node["SelectableStretch"]
	gui_window:setProperty("SelectableStretch",Converter(selectable_Stretch,"Stretch"))
	Signal:subscribe(selectable_Stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("SelectableStretch",Converter(selectable_Stretch,"Stretch"))
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

	local border_colours = node["BorderColor"]
	gui_window:setProperty("BorderColor",Converter(border_colours,"Colours"))
	Signal:subscribe(border_colours, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BorderColor",Converter(border_colours,"Colours"))
	end)
end

return M