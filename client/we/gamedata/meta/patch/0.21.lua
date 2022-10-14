local Def = require "we.def"
local Lang = require "we.gamedata.lang"
local lfs = require "lfs"

local meta = {
	{
		type = "Button",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.TextOffset = { x = ret.TextXOffset, y = ret.TextYOffset}
			return ret
		end
	},
	
		{
		type = "GridView",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.Space = { x = ret.hInterval, y = ret.vInterval}
			return ret
		end
	},
	
	{
		type = "Window_Base",
		value = function(oval)
			local ret = Lib.copy(oval)
			if ret.MousePassThroughEnabled == true then
				ret.WindowTouchThroughMode = "MousePassThroughOpen"
			end
			return ret
		end
	}
}

return {
	meta = meta
}