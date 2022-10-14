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

local function incvar(data, key, value)
	if not key then
		return false
	end
	if type(data[key]) ~= "number" then
		print("incvar error type", type(data[key]))
		return false
	end
	data[key] = data[key] + value
	return true
end

function Actions.IncGlobalVar(node, params, context)
	return incvar(World.vars, params.key, params.value)
end

function Actions.GetFuncContextVar(node, params, context)
	local func = context.func
	if not func and not func.vars then
		return nil
	end
	return getvar(func.vars, params.key)
end

function Actions.SetFuncContextVar(node, params, context)
	if not context then return nil end
	context.func = context.func or {}
	context.func.vars = context.func.vars or {}
	return setvar(context.func.vars, params.key, params.value)
end

function Actions.GetContextVar(node, params, context)
	return getvar(context, params.key)
end
function Actions.SetContextVar(node, params, context)
	return setvar(context, params.key, params.value)
end

function Actions.IncContextVar(node, params, context)
	return incvar(context, params.key, params.value)
end

function Actions.GetEntityEditorVar(node, params, context)
	local entity = params.entity
	if not entity then
		return nil
	end
	return getvar(entity.vars.editor_data, params.key)
end

function Actions.SetEntityEditorVar(node, params, context)
	local entity = params.entity
	if not entity then
		return nil
	end
	return setvar(entity.vars.editor_data, params.key, params.value)
end

function Actions.IncObjectVar(node, params, context)
	local obj = params.obj
	if not obj then
		return false
	end
	return incvar(obj.vars, params.key, params.value)
end

function Actions.SyncEntityVarVal(node, params, context)
	local entity = params.entity
	if not entity then
		return nil
	end

    entity:sendPacket({
        pid = "SyncVarVal",
	    key = params.key,
	    val = getvar(entity.vars, params.key)
    })
end

function Actions.GetConfigVar(node, params, context)
	local obj = params.obj
	if not obj then
		return nil
	end
	return getvar(obj:cfg(), params.key)
end

function Actions.GetRegionConfig(node, params, context)
	local region = params.region
	if not region then
		return nil
	end
	return getvar(region.cfg, params.key)
end

function Actions.GetBlockConfig(node, params, context)
	local blockCfg = World.CurWorld:getMap(params.map):getBlock(params.pos)
	return getvar(blockCfg, params.key)
end

function Actions.GetPropVar(node, params, context)
	local entity = params.entity
	if not entity then
		return nil
	end
	return getvar(entity:prop(), params.key)
end

function Actions.GetBlockConfig(node, params, context)
	local blockCfg = World.CurWorld:getMap(params.map):getBlock(params.pos)
	return getvar(blockCfg, params.key)
  end

function Actions.GetBlockConfigByName(data, params, context)
	local cfg = Block.GetNameCfg(params.block)
	if params.key then
		return cfg[params.key]
	end
	return cfg
end

function Actions.GetWorldVar(node, params, context)
	return World.cfg[params.key]
end

function Actions.GetMapVar(node, params, context)
	return params.map:getVar(params.key)
end

function Actions.SetMapVar(node, params, context)
	params.map:setVar(params.key, params.value)
end

function Actions.GetBlockVar(node, params, context)
    local map = World.CurWorld:getMap(params.map)
    return getvar(map:getBlockData(params.pos), params.key or "value")
end

function Actions.SetBlockVar(node, params, context)
    
    local map = World.CurWorld:getMap(params.map)
    return setvar(map:getOrCreateBlockData(params.pos), params.key or "value", params.value)
end

function Actions.GetTeamVar(data, params, context)
	local team = Game.GetTeam(params.teamId, false)
	if not team then
		return
	end
	return team.vars[params.key]
end

function Actions.SetTeamVar(data, params, context)
	local team = Game.GetTeam(params.teamId, false)
	if not team then
		return
	end
	team.vars[params.key] = params.value
end

function Actions.IncTeamVar(node, params, context)
    local team = Game.GetTeam(params.teamId, true)
    local key = params.key
    local data = team.vars
    if type(data[key]) ~= "number" then
		print("IncTeamVar error type", type(data[key]))
		return false
	end
    data[key] = data[key] + params.value
    return true
end

function Actions.GetPosX(data, params, context)
    return params.pos and params.pos["x"]
end

function Actions.GetPosY(data, params, context)
    return params.pos and params.pos["y"]
end

function Actions.GetPosZ(data, params, context)
    return params.pos and params.pos["z"]
end

function Actions.GetRegionCfgVar(data, params, context)
	return getvar(params.region and params.region.cfg,params.key)
end

function Actions.SetRegionCfgVar(data, params, context)
	return setvar(params.region and params.region.cfg,params.key,params.value)
end

function Actions.GetSkillVar(data, params, context)
	if not params.fullName then
		return nil
	end
	local skill = Skill.Cfg(params.fullName)
	return skill and skill[params.key] or nil
end

function Actions.GetMissileVar(data, params, context)
	if not params.fullName then
		return nil
	end
	local missile = Missile.GetCfg(params.fullName)
	return missile and missile[params.key] or nil
end

function Actions.GetFuncsParamsVar(data, params, context)
	local key = params.key 
	if not key or not context then 
		return nil
	end 
	if type(context) ~= "table" then 
		return nil
	end 
	return context.params and context.params[params.key] or nil
end
