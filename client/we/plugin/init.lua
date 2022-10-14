local Signal = require "we.signal"
local Plugin = require "we.plugin.plugin"

--[[
local action = Plugin:create_action("test")
Signal:subscribe(action, action.SIGNAL.ON_TRIGGERED, function()
	print("hello")
end)
]]
