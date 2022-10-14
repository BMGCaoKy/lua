local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local text_colours = node["TextColours"]
	gui_window:setProperty("TextColours",Converter(text_colours,"Colours"))
	Signal:subscribe(text_colours, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("TextColours",Converter(text_colours,"Colours"))
	end)

	local background_colours = node["BackgroundColours"]
	gui_window:setProperty("BackgroundColours",Converter(background_colours,"Colours"))
	Signal:subscribe(background_colours, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BackgroundColours",Converter(background_colours,"Colours"))
	end)

	local frame_colours = node["FrameColours"]
	gui_window:setProperty("FrameColours",Converter(frame_colours,"Colours"))
	Signal:subscribe(frame_colours, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("FrameColours",Converter(frame_colours,"Colours"))
	end)

	local border_colours = node["BorderColor"]
	gui_window:setProperty("BorderColor",Converter(border_colours,"Colours"))
	Signal:subscribe(border_colours, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("BorderColor",Converter(border_colours,"Colours"))
	end)
end

return M