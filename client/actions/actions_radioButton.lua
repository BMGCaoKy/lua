local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/RadioButton"

local function isRadioButton(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetRadioButtonIsSelected(data, params, context)
	local instance = params.instance
	local isSelected = params.isSelected
	if not isRadioButton(instance) or Actions.IsInvalidBool(isSelected) then
		return
	end
	instance:getWindow():setSelected(isSelected or false)
end

function Actions.SetRadioButtonGroupID(data, params, context)
	local instance = params.instance
	local groupId = params.groupId
	if not isRadioButton(instance) or Actions.IsInvalidNum(groupId) then
		return
	end
	if groupId < 0 then
		Lib.logError("Actions.SetRadioButtonGroupID: radiobutton groupId less than 0")
	else
		instance:getWindow():setGroupID(groupId or 0)
	end
end

function Actions.GetRadioButtonIsSelected(data, params, context)
	local instance = params.instance
	if isRadioButton(instance) then
		return instance:getWindow():isSelected()
	end
end

function Actions.GetRadioButtonGroupID(data, params, context)
	local instance = params.instance
	if isRadioButton(instance) then
		return instance:getWindow():getGroupID()
	end
end

function Actions.IsRadioButton(data, params, context)
	local instance = params.instance
	if instance.__windowType == windowType then
		return true
	else
		return false
	end
end