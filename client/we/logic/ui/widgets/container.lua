local Signal = require "we.signal"
local Def = require "we.def"
local Converter = require "we.gamedata.export.data_converter"

local M = {}

function M:init(node,gui_window,window)
	local childrenSize = node["ChildrenSize"]
	gui_window:setProperty("ChildrenSize",Converter(childrenSize,"Vector2"))
	Signal:subscribe(childrenSize, Def.NODE_EVENT.ON_ASSIGN, function()
		gui_window:setProperty("ChildrenSize",Converter(childrenSize,"Vector2"))
		window:layout_update()
	end)

	local space = node["Space"]
	if space then
		gui_window:setProperty("Space",Converter(space,"Vector2"))
		Signal:subscribe(space, Def.NODE_EVENT.ON_ASSIGN, function()
			gui_window:setProperty("Space",Converter(space,"Vector2"))
			window:layout_update()
		end)	
	end
	

end

return M