require "common.game"
require "game_service"
local misc = require "misc"
local playerCount = L("playerCount", 0)
local playersInfo = L("playersInfo", {})
local teamsInfo = L("teamsInfo", {})
local appState = L("appState", {})
local audioDir = L("audioDir", "")
local gameMode = L("gameMode", "")

local Game = Game ---@class Game

function Game.OnPlayerLogin(playerInfo)
    if not playersInfo[playerInfo.objID] then
        playerCount = playerCount + 1
    end
    playersInfo[playerInfo.objID] = playerInfo
    local teamID = playerInfo.teamID
    if teamID and teamID ~= 0 then
        Game.JoinTeam(teamID, playerInfo.objID)
    end
    local callBack = function()
        Lib.emitEvent(Event.EVENT_PLAYER_STATUS_2, 0, playerInfo.userId, playerInfo.name)
    end
    AsyncProcess.LoadUsersInfo({playerInfo.userId}, callBack)
    Lib.emitEvent(Event.EVENT_PLAYER_LOGIN, playerInfo)
    Lib.emitEvent(Event.EVENT_PLAYER_STATUS, 0, playerInfo.userId, playerInfo.name)

    --local player = World.CurWorld:getEntity(playerInfo.objID)
    --Event:EmitEvent("OnPlayerLogin", player)
end

function Game.OnPlayerLogout(objID)
    local playerInfo = playersInfo[objID]
    playerCount = playerCount - 1
    playersInfo[objID] = nil
    if playerInfo then
        Lib.emitEvent(Event.EVENT_PLAYER_LOGOUT, playerInfo)
        Lib.emitEvent(Event.EVENT_PLAYER_STATUS, 1, playerInfo.userId, playerInfo.name)

        --local player = World.CurWorld:getEntity(playerInfo.objID)
        --Event:EmitEvent("OnPlayerLogout", player)
    end
end

function Game.OnPlayerReconnect(objID)
    local playerInfo = playersInfo[objID]
    if playerInfo then
        Lib.emitEvent(Event.EVENT_UPDATE_TEAM_INFO, playerInfo.teamID)
        Lib.emitEvent(Event.EVENT_PLAYER_RECONNECT)

        --local player = World.CurWorld:getEntity(playerInfo.objID)
        --Event:EmitEvent("OnPlayerReconnect", player)
    end
end

function Game.InitPlayersInfo(curPlayers, state, stateStartTs)
    Profiler:begin("Game.InitPlayersInfo")
    Game.SetState(state, stateStartTs)
    if curPlayers then
        playersInfo = curPlayers
    end
    local userIds = {}
    for _, player in pairs(playersInfo) do
        playerCount = playerCount + 1
        table.insert(userIds, player.userId)
    end
    if #userIds > 0 then
        AsyncProcess.LoadUsersInfo(userIds)
    end

    if not World.CurWorld.isEditor then
        Profiler:begin("Lib.emitEvent(Event.EVENT_PLAYER_BEGIN)")
        Lib.emitEvent(Event.EVENT_PLAYER_BEGIN)
        Profiler:finish("Lib.emitEvent(Event.EVENT_PLAYER_BEGIN)")
    end
    Profiler:finish("Game.InitPlayersInfo")
end

function Game.InitTeamsInfo(infos)
    teamsInfo = infos
end

function Game.GetPlayerByUserId(userId)
    for _, info in pairs(playersInfo) do
        if info.userId == userId then
            return info
        end
    end
    return nil
end

function Game.GetAllPlayersInfo()
    return playersInfo
end

function Game.GetAllPlayersCount()
    return playerCount
end

function Game.GetAllTeamsInfo()
    return teamsInfo
end

function Game.RefreshTeamsUI(teamID)
    Lib.emitEvent(Event.EVENT_REFRESH_TEAMS_UI, {teamID = teamID})
end

function Game.UpdateTeamInfo(teamID, info)
    local teamInfo = teamsInfo[teamID] or {}
    for i,v in pairs(info) do
        teamInfo[i] = v
    end
    Lib.emitEvent(Event.EVENT_UPDATE_TEAM_INFO, teamID)
end

function Game.RequestCreateTeam(player, additionalInfo, func)
    player:sendPacket({pid = "RequestCreateTeam", additionalInfo = additionalInfo}, func)
end

function Game.GetTeamAdditionalInfo(teamID)
    local team = Game.GetTeam(teamID)
    return team and team.additionalInfo
end

function Game.RequestJoinTeam(player, teamID, func)
    player:sendPacket({pid = "RequestJoinTeam", teamID = teamID}, func)
end

function Game.RequestLeaveTeam(player)
    player:sendPacket({pid = "RequestLeaveTeam"})
end

function Game.RequestQuitTeamMember(player, memberId)
    player:sendPacket({pid = "RequestQuitTeamMember", memberId = memberId})
end

function Game.JoinTeam(teamID, objID)
    local teamInfo = teamsInfo[teamID]
    assert(teamInfo, teamID)
    teamInfo.playerCount = teamInfo.playerCount + 1
    teamInfo.playerList[objID] = true
    Game.RefreshTeamsUI(teamID)
    if Me.objID == objID then
        Me:EmitEvent("OnJoinTeam", teamID)
    end
end

function Game.LeaveTeam(teamID, objID)
    local teamInfo = teamsInfo[teamID]
    assert(teamInfo, teamID)
    teamInfo.playerCount = teamInfo.playerCount - 1
    teamInfo.playerList[objID] = nil
    Game.RefreshTeamsUI(teamID)
    if Me.objID == objID then
        Me:EmitEvent("OnLeaveTeam", teamID)
    end
end

function Game.RequestUpdateTeamAdditionalInfo(player, additionalInfo)
    player:sendPacket({pid = "RequestUpdateTeamAdditionalInfo", additionalInfo = additionalInfo})
end

function Game.UpdateTeamAdditionalInfo(teamID, createTime, additionalInfo)
    local teamInfo = teamsInfo[teamID]
    teamInfo.additionalInfo = additionalInfo
    teamInfo.createTime = createTime
    Game.RefreshTeamsUI(teamID)
end

function Game.CreateTeam(teamID, status, createTime, additionalInfo)
    local teamInfo = {
        id = teamID,
        playerCount = 0,
        playerList = {},
        state = status,
        createTime = createTime,
        additionalInfo = additionalInfo,
    }
    teamsInfo[teamID] = teamInfo
end

function Game.GetTeam(teamID)
    return teamsInfo[teamID]
end

function Game.DismissTeam(teamID)
    teamsInfo[teamID] = nil
    Game.RefreshTeamsUI(teamID)
end

function Game.SetPlayerTeam(objID, teamID, leaderId, joinTeamTime, oldTeamLeaderId)
    local player = playersInfo[objID]
    if not player then--player just login
        return
    end
    local old = player.teamID or 0
    local new = teamID or 0
    if old == new then
        return
    end
    player.teamID = new
    if old ~= 0 then
        player.joinTeamTime = 0
        Game.LeaveTeam(old, objID)
    end
    if new ~= 0 then
        player.joinTeamTime = joinTeamTime
        Game.JoinTeam(new, objID)
    end
    if not World.cfg.hideTeamStatusBar then
        Lib.emitEvent(Event.EVENT_UPDATE_TEAM_STATUS_BAR, {objID = objID, oldTeamID = old, newTeamID = new})
    end
    if old ~= 0 then
        local teamInfo = teamsInfo[old]
        teamInfo.leaderId = oldTeamLeaderId
    end
    if new ~= 0 then
        local teamInfo = teamsInfo[new]
        teamInfo.leaderId = leaderId
    end
end

function Game.RunTelnet(index, port)
    local handle = appState[index]
	print("runTelnet", index, port, handle)
	if handle then
		if not misc.win_waitobject(handle) then
			misc.win_exitapp(handle)
			port = nil
		end
		misc.win_closehandle(handle)
		appState[index] = nil
	end
	if port then
        Me:doGM("telnetDebugInfo", port)
		appState[index] = misc.win_exec("telnet.exe", "127.0.0.1 "..port, nil, nil, true)
	end
end

function Game.modifyWindowSize(w,h,x,y)
    CGame.instance:getShellInterface():modifyWindowSize(x or 0, y or 0, w, h)
end

function Game.Pause(state)
    World.CurWorld:setGamePause(state)
    local packet = {
        pid = "PauseGame",
        state = state
    }
    Me:sendPacket(packet)
end

function Game.ReqNextGame()
    local packet = {
        pid = "NextGame"
        
    }
    Me:sendPacket(packet)
end

function Game.SetGameMode(mode)
    gameMode = mode
end

function Game.GetGameMode()
    return gameMode or "lobby"
end

function Game.SetAudioDir(dir)
    audioDir = dir
end

function Game.GetAudioDir()
    return audioDir or "voice/other"
end

local World_setHpIntoBar = World.cfg.setHpIntoBar
function Game.EntitySpawn(self, params, callBack)
    local world = World.CurWorld
    local old = world:getObject(params.objID)
    if old then
        Lib.logInfo("Client EntitySpawn old = ", old)
        print("entity double spawn", World.GameName, params.objID, World.CurMap and World.CurMap.id)
        old:destroy()
    end
    local entity = EntityClient.CreateEntity(Entity.GetCfg(params.cfgName).id, world, params.objID, params.actorName or "")
    if callBack then
        callBack(entity)
    end
    --Lib.logInfo("Game.EntitySpawn", params.cfgName)
    entity:data("main").actorName = params.actorName
    -- print(" ----------------- EntitySpawn params.name ", params.name, "d", Lang:toText(params.name))
    -- entity.name = Lang:toText(params.name)
    entity:setName(Lang:toText(params.name))
    entity.platformUserId = params.uid
    entity:resetData()
    if params.isInsteance then
        for key, value in pairs(params.properties or {}) do
            entity:setProperty(key, value)
        end
    end
    entity:setMap(params.map or World.CurMap)
    if params.scale then
        entity:setEntityScale(params.scale)
    end
    entity:setPosition(params.pos)
    entity.movingStyle = params.movingStyle
    entity:setRotationYaw(params.rotationYaw)
    entity:setRotationPitch(params.rotationPitch)
    entity:setRotationRoll(params.rotationRoll)
    entity:setBodyYaw(params.rotationYaw)
    entity.curHp = params.curHp
    entity.curVp = params.curVp
    entity:setDead(params.curHp <= 0)
    entity:applySkin(params.skin)
    if params.handItem then
        local item = Item.DeseriItem(params.handItem)
        if item then
            entity:saveHandItem(item)
        end
    end
    entity.isPlayer = params.isPlayer
    entity:data("headText").svrAry = params.headText

    self:invokeCfgPropsCallback()
    for key, value in pairs(params.values or {}) do
        if type(value) == "table" and value["segments"] then
            value = BigInteger.Recover(value)
        end
        entity:doSetValue(key, value)
    end
    for id, name in pairs(params.buffList or {}) do
        entity:addClientBuff(name, id)
    end
    entity:updatePropShow(true)
    if params.rideOnId and (params.rideOnId > 0) then
        local mount = world:getEntity(params.rideOnId)
        if mount then
            entity:rideOn(mount, params.rideOnIdx)
        end
    end
    for index, passengerId in pairs(params.passengers or {}) do
        if passengerId then
            local passenger = world:getEntity(passengerId)
            if passenger then
                passenger:rideOn(entity, index - 1)
            end
        end
    end
    entity:setShowHpMode(World_setHpIntoBar and 1 or 0)
    entity:setShowHpTextColor(World_setHpIntoBar and 0xff000000 or 0x00000000) -- alpha 255 black
    if params.entityToBlock then
        entity:SetEntityToBlock(params.entityToBlock)
    end

    local headInfo = entity:cfg().showHeadInfo
    if headInfo and next(headInfo) then
        local packet = {
            objID = entity.objID,
            headInfo = headInfo
        }
        Lib.emitEvent(Event.EVENT_SHOW_ENTITY_HEADINFO, packet)
    end
    if entity.isPlayer then
        entity:setActorHide(self.excludingDisplay)
        self.displayAmount = self.displayAmount + (self.excludingDisplay and 0 or 1)
        entity:checkDisposeCulling()
    end
    self:updateEntityTaskSign(entity)
    entity:setEntityMode(params.mode, params.targetId)
    entity:setFlyMode(params.flyMode)
    local entityUI = params.entityUI
    if entityUI and next(entityUI) then
        SceneUIManager.InitEntityUI(entity.objID, entityUI)
    end

    entity:createInteractionSphere()
    --小地图的图标
    entity:updateMiniMapIcon("miniMapIcon")
    entity:setProps(params.props)

    Lib.emitEvent(Event.EVENT_ENTITY_SPAWN, params.objID)
    Event:EmitEvent("OnEntityAdded", entity)
    entity:onCreate()
    return entity
end

function Game.IsGameParty()
    return Lib.getBoolProperty("isGameParty") or false
end

function Game.IsDebug()
    return CGame.instance:isDebuging()
end

function Game.Exit()
    CGame.instance:exitGame()
end

RETURN()
