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

function Actions.GetGlobalVar(node, params, context)
	return getvar(World.vars, params.key)
end

function Actions.SetGlobalVar(node, params, context)
	return setvar(World.vars, params.key, params.value)
end

function Actions.GetContextVar(node, params, context)
	return getvar(context, params.key)
end

function Actions.SetContextVar(node, params, context)
	return setvar(context, params.key, params.value)
end

function Actions.GetObjectVar(node, params, context)
	local obj = params.obj
	if ActionsLib.isNil(obj,"Object") then
		return nil
	end
	return getvar(obj.vars, params.key)
end

function Actions.SetObjectVar(node, params, context)
	local obj = params.obj
	if ActionsLib.isNil(obj,"Object") then
		return false
	end
	return setvar(obj.vars, params.key, params.value)
end
