local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local progress_lights_image = node["progress_lights_image"]
	gui_window:setProperty("progress_lights_image",Converter(progress_lights_image,"ImageKey"))
	Signal:subscribe(progress_lights_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("progress_lights_image",Converter(progress_lights_image,"ImageKey"))
	end)
		
	local progress_background_image = node["progress_background_image"]
	gui_window:setProperty("progress_background_image",Converter(progress_background_image,"ImageKey"))
	Signal:subscribe(progress_background_image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("progress_background_image",Converter(progress_background_image,"ImageKey"))
	end)

	local current_progress = node["CurrentProgress"]
	gui_window:setProperty("CurrentProgress",current_progress["value"])
	Signal:subscribe(current_progress, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("CurrentProgress",current_progress["value"])
	end)

	local progress_lights_stretch = node["ProgressLightsStretch"]
	gui_window:setProperty("ProgressLightsStretch",Converter(progress_lights_stretch,"Stretch"))
	Signal:subscribe(progress_lights_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ProgressLightsStretch",Converter(progress_lights_stretch,"Stretch"))
	end)

	local progress_bg_stretch = node["ProgressBgStretch"]
	gui_window:setProperty("ProgressBgStretch",Converter(progress_bg_stretch,"Stretch"))
	Signal:subscribe(progress_bg_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ProgressBgStretch",Converter(progress_bg_stretch,"Stretch"))
	end)
end

return M