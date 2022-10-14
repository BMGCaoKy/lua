local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/ActorWindow"

local function isActorWindow(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if (instance.__windowType == windowType) then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetActorModel(data, params, context)
	local instance = params.instance
	local actor = params.actor
	if not isActorWindow(instance) or Actions.IsInvalidStr(actor) then
		return
	end
	instance:getWindow():setActorName(actor or nil)
end

function Actions.SetActorModelAction(data, params, context)
	local instance = params.instance
	local action = params.action
	if not isActorWindow(instance) or Actions.IsInvalidStr(action) then
		return
	end
	if instance:getWindow():isExistAction(action) then
		instance:getWindow():setSkillName(action)
	else
		local info = string.format("Action named %s was not found.", action)
		Lib.logError(info)
	end
end

function Actions.IsActorWindow(data, params, context)
	local instance = params.instance
	if (instance and instance.__windowType == windowType) then
		return true
	else
		return false
	end
end