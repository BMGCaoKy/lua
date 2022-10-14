local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local horizontal = "WindowsLook/HorizontalSlider"
local vertical = "WindowsLook/VerticalSlider"

local function isSlider(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if (instance.__windowType == horizontal) or (instance.__windowType == vertical) then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  horizontal, vertical)
		return false
	end
end

function Actions.SetSliderValue(data, params, context)
	local instance = params.instance
	local value = params.value
	if not isSlider(instance) or Actions.IsInvalidNum(value) or value < 0 then
		return
	end
	instance:getWindow():setCurrentValue(value or 0.0)
end

function Actions.AddOrSubSliderValue(data, params, context)
	local instance = params.instance
	local value = params.value
	if not isSlider(instance) or Actions.IsInvalidNum(value) then
		return
	end
	local oldValue = instance:getWindow():getCurrentValue()
	local maxValue = instance:getWindow():getMaxValue()
	local currentValue = oldValue + value
	if currentValue > maxValue then 
		instance:getWindow():setCurrentValue(maxValue)
	elseif currentValue < 0 then
		instance:getWindow():setCurrentValue(0.0)
	else
		instance:getWindow():setCurrentValue(currentValue or 0.01)
	end
end

function Actions.SetSliderMaxValue(data, params, context)
	local instance = params.instance
	local maxValue = params.maxValue
	if not isSlider(instance) or Actions.IsInvalidNum(maxValue) or maxValue < 0 then
		Lib.logError("Actions.SetSliderMaxValue: the maxValue less 0 !!!", maxValue)
		return
	end
	instance:getWindow():setMaxValue(maxValue or 0.0)
end

function Actions.GetSliderValue(data, params, context)
	local instance = params.instance
	if isSlider(instance) then
		return instance:getWindow():getCurrentValue()
	end
end

function Actions.GetSliderMaxValue(data, params, context)
	local instance = params.instance
	if isSlider(instance) then
		return instance:getWindow():getMaxValue()
	end
end

function Actions.IsSlider(data, params, context)
	local instance = params.instance
	if (instance and ((instance.__windowType == horizontal) or (instance.__windowType == vertical))) then
		return true
	else
		return false
	end
end