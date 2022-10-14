local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/StaticImage"

local function isImage(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetShowImage(data, params, context)
	local instance = params.instance
	local image = params.image
	if not isImage(instance) or Actions.IsInvalidStr(image) then
		return
	end
	instance:getWindow():setImage(image)
end

function Actions.IsImage(data, params, context)
	local instance = params.instance
	if (instance and instance.__windowType == windowType) then
		return true
	else
		return false
	end
end