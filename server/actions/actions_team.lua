local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"
local getTeamById = ActionsLib.getTeamById

function Actions.ShowTipToTeam(data, params, context)
    local entities = Game.GetTeam(params.teamId):getEntityList()
    for _, entity in pairs(entities) do
        if entity.isPlayer then
            entity:sendTip(params.tipType, params.textKey, params.keepTime, params.vars, params.event, params.textP1, params.textP2, params.textP3)
        end
    end
end

function Actions.GetTeamEntityList(data, params, context)
    local team = Game.GetTeam(params.teamId)
    if not team then
        return nil
    end
    local entityList = team:getEntityList()
    return entityList
end

function Actions.UpdateCountDownTipToTeam(data, params, context)
    local packet = {
        pid = "UpdateCountDownTip",
        textKey = -1
    }
    if params.textP1 ~= 0 then
        packet.textKey = params.textKey
        packet.textP1 = params.textP1
        packet.textIcon = params.textIcon
    end
    Game.GetTeam(params.teamId):broadcastPacket(packet)
end

function Actions.GetEntityTeam(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    return entity:getValue("teamId")
end

function Actions.SetEntityTeam(data, params, context)
	local entity = params.entity
	if ActionsLib.isInvalidEntity(entity) then
		return
	end
	local teamId = params.teamId
	local oldTeamId = entity:getValue("teamId")
	if oldTeamId==teamId then
		return
	end
	if oldTeamId~=0 then
		Game.GetTeam(oldTeamId):leaveEntity(entity)
	end
	if teamId==0 then
		return
	end
	local team = Game.GetTeam(teamId, true)
    team:joinEntity(entity)
end

function Actions.GetTeamInfo(data, params, context)
    local team = Game.GetTeam(params.teamId, true)
    return team[params.key]
end

function Actions.ShowTeamInfo(data, params, context)
	local entityListId = {}
	local teamList = Game.GetTeam(params.teamId)

	for i,v in pairs(teamList.entityList)do
		entityListId[#entityListId + 1] = v.objID
	end
	local packet = {
        pid = "ShowTeamInfo",
		teamId = teamList.id,
		leaderId = teamList.leaderId,
		playerCount = teamList.playerCount,
		entityListId = entityListId,
		teamTittleKey = params.tittleKey,
		maxNum = params.maxNum
    }
	teamList:broadcastPacket(packet)
end

function Actions.GetTeamAdditionalInfo(data, params, context)
    local teamId = params.teamId
    local additionalInfo = Game.GetTeamAdditionalInfo(teamId)
    if additionalInfo and params.key then
        return additionalInfo[params.key]
    end
    return additionalInfo
end

function Actions.UpdateTeamAdditionalInfo(data, params, context)
    local teamId = params.teamId
	if params.reset then
		Game.UpdateTeamAdditionalInfo(teamId, params.additionalInfo or {})
	else
		local additionalInfo = Game.GetTeamAdditionalInfo(teamId) or {}
		for k, v in pairs(params.additionalInfo or {}) do
			additionalInfo[k] = v
		end
		Game.UpdateTeamAdditionalInfo(teamId, additionalInfo)
	end
end

function Actions.GetTeamLeader(data, params, context)
    local team = Game.GetTeam(params.teamID)
    if not team then
        return nil
    end
    return team.leaderId
end

function Actions.QuitTeamMember(data, params, context)
    local team = Game.GetTeam(params.teamID)
    local memberTeamId = params.entity:getValue("teamId")
    if team and team.id == memberTeamId then
        team:leaveEntity(params.entity)
    end
end

function Actions.IsEntityInTeam(data, params, context)
    local entity = params.entity
    local teamId = params.teamId
    if ActionsLib.isNil(teamId, "TeamId") or ActionsLib.isInvalidPlayer(entity) then
        return false
    end
    return (entity:getValue("teamId") or -1) == teamId
end

function Actions.GetTeamEntityArray(data, params, context)
    local team = getTeamById(params.teamId)
    if not team then
        return nil
    end
    local ret = {}
    for _, entity in pairs(team:getEntityList() or {}) do
        ret[#ret + 1] = entity
    end
    table.sort(ret, function(entity1, entity2)
        return entity1.objID < entity2.objID
    end)
    return ret
end

function Actions.GetTeamName(data, params, context)
    local team = getTeamById(params.teamID)
    return team and team.name or nil
end

function Actions.SetTeamName(data, params, context)
    local name = params.name
    if ActionsLib.isEmptyString(name) then
        return nil
    end
    local team = getTeamById(params.teamID)
    if not team then
        return nil
    end
    team.name = name
end