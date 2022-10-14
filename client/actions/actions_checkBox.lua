local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/Checkbox"

local function isCheckBox(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetCheckBoxIsSelected(data, params, context)
	local instance = params.instance
	local isSelected = params.isSelected
	if not isCheckBox(instance) or Actions.IsInvalidBool(isSelected) then
		return
	end
	instance:getWindow():setSelected(isSelected or false)
end

function Actions.GetCheckBoxIsSelected(data, params, context)
	local instance = params.instance
	if isCheckBox(instance) then
		return instance:getWindow():isSelected()
	end
end

function Actions.IsCheckBox(data, params, context)
	local instance = params.instance
	if instance.__windowType == windowType then
		return true
	else
		return false
	end
end