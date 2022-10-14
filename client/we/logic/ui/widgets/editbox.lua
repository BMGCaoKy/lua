local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local bg_image = node["BackGroundImage"]
	gui_window:setProperty("BackGroundImage",Converter(bg_image,"ImageKey"))
	Signal:subscribe(bg_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BackGroundImage",Converter(bg_image,"ImageKey"))
	end)

	local backGround_stretch = node["BackGroundStretch"]
	gui_window:setProperty("BackGroundStretch",Converter(backGround_stretch,"Stretch"))
	Signal:subscribe(backGround_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BackGroundStretch",Converter(backGround_stretch,"Stretch"))
	end)

	local normal_text_colour = node["NormalTextColour"]
	gui_window:setProperty("NormalTextColour",Converter(normal_text_colour,"Colours"))
	Signal:subscribe(normal_text_colour, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("NormalTextColour",Converter(normal_text_colour,"Colours"))
	end)

	local selected_text_colour = node["SelectedTextColour"]
	gui_window:setProperty("SelectedTextColour",Converter(selected_text_colour,"Colours"))
	Signal:subscribe(selected_text_colour, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("SelectedTextColour",Converter(selected_text_colour,"Colours"))
	end)

	local read_only_bg_colour = node["ReadOnlyBGColour"]
	gui_window:setProperty("ReadOnlyBGColour",Converter(read_only_bg_colour,"Colours"))
	Signal:subscribe(read_only_bg_colour, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ReadOnlyBGColour",Converter(read_only_bg_colour,"Colours"))
	end)

	local active_selection_colour = node["ActiveSelectionColour"]
	gui_window:setProperty("ActiveSelectionColour",Converter(active_selection_colour,"Colours"))
	Signal:subscribe(active_selection_colour, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ActiveSelectionColour",Converter(active_selection_colour,"Colours"))
	end)
end

return M