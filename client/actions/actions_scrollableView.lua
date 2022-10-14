local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/ScrollableView"

local function isScrollableView(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetScrollableViewHorizontalPos(data, params, context)
	local instance = params.instance
	local value = params.value
	if not isScrollableView(instance) or Actions.IsInvalidNum(value) then
		return
	end
	instance:getWindow():setHorizontalScrollPosition(value)
end

function Actions.SetScrollableViewVerticalPos(data, params, context)
	local instance = params.instance
	local value = params.value
	if not isScrollableView(instance) or Actions.IsInvalidNum(value) then
		return
	end
	instance:getWindow():setVerticalScrollPosition(value)
end

function Actions.GetScrollableViewHorizontalPos(data, params, context)
	local instance = params.instance
	if isScrollableView(instance) then
		return instance:getWindow():getHorizontalScrollPosition()
	end
end

function Actions.GetScrollableViewVerticalPos(data, params, context)
	local instance = params.instance
	if isScrollableView(instance) then
		return instance:getWindow():getVerticalScrollPosition()
	end
end

function Actions.IsScrollableView(data, params, context)
	local instance = params.instance
	if (instance and instance.__windowType == windowType) then
		return true
	else
		return false
	end
end