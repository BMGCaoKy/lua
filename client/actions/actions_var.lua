local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local function getvar(data, key)
	if not key or not data then
		return nil
	end
	return data[key]
end

local function setvar(data, key, value)
	if not key then
		return false
	end
	data[key] = value
	return true
end

function Actions.GetUIVar(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	instance.vars = instance.vars or {}
	return getvar(instance.vars, params.key)
end

function Actions.SetUIVar(data, params, context)
	local instance = params.instance
	local key = params.key
	local value = params.value
	if Actions.IsInvalidWindow(instance) or not key or value == nil then
		Lib.logError("Actions.SetUIVar:there is a invalid key or value !!!", key,  value)
		return
	end
	instance.vars = instance.vars or {}
	setvar(instance.vars,key,value)
end