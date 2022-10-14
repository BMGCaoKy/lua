local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/Button"

local function isButton(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetButtonNormalState(data, params, context)
	local instance = params.instance
	local image = params.image
	if not isButton(instance) or Actions.IsInvalidStr(image) then
		return
	end
	instance:getWindow():setNormalImage(image)
end

function Actions.SetButtonDisableState(data, params, context)
	local instance = params.instance
	local image = params.image
	if not isButton(instance) or Actions.IsInvalidStr(image) then
		return
	end
	instance:getWindow():setDisableImage(image)
end

function Actions.SetButtonPushedState(data, params, context)
	local instance = params.instance
	local image = params.image
	if not isButton(instance) or Actions.IsInvalidStr(image) then
		return
	end
	instance:getWindow():setPushedImage(image)
end

function Actions.IsButtonPushed(data, params, context)
	local instance = params.instance
	if isButton(instance) then
		return instance:getWindow():isPushed()
	end
	return false
end

function Actions.IsButton(data, params, context)
	local instance = params.instance
	if (instance and instance.__windowType == windowType) then
		return true
	else
		return false
	end
end