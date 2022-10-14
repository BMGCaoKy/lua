local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/EffectWindow"

local function isEffectWindow(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetEffectName(data, params, context)
	local instance = params.instance
	local effect = params.effect
	if not isEffectWindow(instance) or Actions.IsInvalidStr(effect) then
		return
	end
	instance:getWindow():setEffectName(effect or nil)
end

function Actions.IsEffectWindow(data, params, context)
	local instance = params.instance
	if (instance and instance.__windowType == windowType) then
		return true
	else
		return false
	end
end