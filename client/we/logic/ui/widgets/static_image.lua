local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window)
	local image = node["Image"]
	gui_window:setProperty("Image",Converter(image,"ImageKey"))
	Signal:subscribe(image, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("Image",Converter(image,"ImageKey"))
	end)

	local static_image_stretch = node["StaticImageStretch"]
	gui_window:setProperty("StaticImageStretch",Converter(static_image_stretch,"Stretch"))
	Signal:subscribe(static_image_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("StaticImageStretch",Converter(static_image_stretch,"Stretch"))
	end)

	local static_image_cut_stretch = node["StaticImageCutStretch"]
	gui_window:setProperty("StaticImageCutStretch",Converter(static_image_cut_stretch,"Stretch"))
	Signal:subscribe(static_image_cut_stretch, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("StaticImageCutStretch",Converter(static_image_cut_stretch,"Stretch"))
	end)

	local image_colours = node["ImageColours"]
	gui_window:setProperty("ImageColours",Converter(image_colours,"Colours"))
	Signal:subscribe(image_colours, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ImageColours",Converter(image_colours,"Colours"))
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

	local image_blend_mode = node["ImageBlendMode"]
	gui_window:setProperty("ImageBlendMode", image_blend_mode)
	Signal:subscribe(image_blend_mode, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ImageBlendMode", image_blend_mode)
	end)

	local image_src_blend = node["ImageSrcBlend"]
	gui_window:setProperty("ImageSrcBlend", image_src_blend)
	Signal:subscribe(image_src_blend, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ImageSrcBlend", image_src_blend)
	end)

	local image_dst_blend = node["ImageDstBlend"]
	gui_window:setProperty("ImageDstBlend", image_dst_blend)
	Signal:subscribe(image_dst_blend, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ImageDstBlend", image_dst_blend)
	end)

	local image_blend_op = node["ImageBlendOperation"]
	gui_window:setProperty("ImageBlendOperation", image_blend_op)
	Signal:subscribe(image_blend_op, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ImageBlendOperation", image_blend_op)
	end)
end

return M