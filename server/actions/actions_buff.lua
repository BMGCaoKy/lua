local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"
local getTeamById = ActionsLib.getTeamById

function Actions.AddEntityBuff(data, params, context) -- old AddBuff(
    local entity = params.entity
    local buffCfg = params.cfg
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(buffCfg, "Buff")then
        return
    end
    return entity:addBuff(buffCfg, params.buffTime, params.from)
end

function Actions.AddTeamBuff(data, params, context)
    local buffCfg = params.cfg
    local teamId = params.teamId
    if ActionsLib.isEmptyString(buffCfg, "Buff") then
        return
    end
    local team = getTeamById(teamId)
    return team and team:addBuff(buffCfg, params.buffTime,params.from)
end

function Actions.GetBuffCfg(data, params, context)
    local buff = params.buff
    if not buff then
        return nil
    end
    if params.key then
        return buff.cfg and buff.cfg[params.key]
    end
    return buff.cfg
end

function Actions.RemoveEntityBuff(data, params, context)
    params.entity:removeBuff(params.buff)
end

function Actions.RemoveTeamBuff(data, params, context)
    local buffCfg = params.buff
    local teamId = params.teamId
    if ActionsLib.isEmptyString(buffCfg, "Buff") then
        return
    end
    local team = getTeamById(teamId)
    return team and team:removeBuff(buffCfg)
end

function Actions.RemoveBuffByFullName(data, params, context)
    local entity = params.entity
    local buffCfg = params.buff
    local teamId = params.teamId
    local team = teamId and getTeamById(teamId) or nil
    if (entity and ActionsLib.isInvalidEntity(entity))
    or  (not entity and not team) 
    or ActionsLib.isEmptyString(buffCfg, "Buff") then
        return
    end
    local target = entity 
    if params.toTeam then
        target = entity:getTeam() or entity
    end

    if not target then 
        target = team
    end

    target:removeTypeBuff("fullName", buffCfg)
end

function Actions.GetTeamTypeBuff(data, params, context)
    return Game.GetTeam(params.teamId):getTypeBuff(params.key, params.value)
end

function Actions.AddBuffToAllPlayers(data, params, context)
    for i, v in pairs(Game.GetAllPlayers()) do
        v:addBuff(params.cfg, params.buffTime)
    end
end

function Actions.GetEntityTypeBuff(data, params, context) -- old GetTypeBuff(
    return params.entity:getTypeBuff(params.key, params.value)
end

function Actions.RemoveEntityTypeBuff(data,params,context)
    return params.entity:removeTypeBuff(params.key, params.value)
end
