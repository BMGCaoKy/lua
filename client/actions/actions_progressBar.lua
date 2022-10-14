local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/ProgressBar"

local function isProgressBar(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetProgressBarValue(data, params, context)
	local instance = params.instance
	local value = params.value
	if not isProgressBar or Actions.IsInvalidNum(value) then
		return
	end
	instance:getWindow():setProgress(value or 0.0)
end

function Actions.AddOrSubProgressBarValue(data, params, context)
	local instance = params.instance
	local value = params.value
	if not isProgressBar(instance) or Actions.IsInvalidNum(value) then
		return
	end
	if value and (value > 0 or value < 0) then
		instance:getWindow():adjustProgress(value)
	end
end

function Actions.GetProgressBarValue(data, params, context)
	local instance = params.instance
	if isProgressBar(instance) then
		return instance:getWindow():getProgress()
	end
end

function Actions.IsProgressBar(data, params, context)
	local instance = params.instance
	if (instance and instance.__windowType == windowType) then
		return true
	else
		return false
	end
end