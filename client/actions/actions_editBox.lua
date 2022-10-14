local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/Editbox"

local function isEditBox(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetEditBoxContext(data, params, context)
	local instance = params.instance
	local text = params.text
	if not isEditBox(instance) or Actions.IsInvalidStr(text) then
		return false
	end
	instance:getWindow():setText(text)
end

function Actions.SetEditBoxIsReadOnly(data, params, context)
	local instance = params.instance
	local isReadOnly = params.isReadOnly
	if not isEditBox(instance) or Actions.IsInvalidBool(isReadOnly) then
		return
	end
	instance:getWindow():setReadOnly(isReadOnly)
end

function Actions.GetEditBoxContext(data, params, context)
	local instance = params.instance
	if isEditBox(instance) then
		return instance:getWindow():getText()
	end
end

function Actions.GetEditBoxIsFocus(data, params, context)
	local instance = params.instance
	if isEditBox(instance) then
		return instance:getWindow():hasInputFocus()
	end
end

function Actions.IsEditBox(data, params, context)
	local instance = params.instance
	if (instance and instance.__windowType == windowType) then
		return true
	else
		return false
	end
end