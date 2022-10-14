local CONDITION_TYPE = { -- sync at server
    NONE = "NONE",
    TIME_END = "TIME_END",
    KILL_ALL_PLAYER = "KILL_ALL_PLAYER",
    KILL_PLAYER_NUM = "KILL_PLAYER_NUM",
    ENTER_REGION = "ENTER_REGION",
    COLLECT = "COLLECT",
    SCORE = "SCORE",
}

local DEFINE_TYPE = { -- sync at server
    player = "player",
    team = "team",
    all = "all",
    block = "block",
    item = "item",
    kill = "kill",
    score = "score"
}

local function sortNumberTable(tb)
    table.sort(tb, function(a, b) 
        if a.number == b.number  then
            if a.obj then
                return a.obj.objID > b.obj.objID
            elseif a.users then
                return #a.users > #b.users
            else
                return false
            end
        end
        return a.number > b.number 
    end)
end

local function getAllPlayerAtUserId()
    local allPlayers = Game.GetAllPlayersInfo()
    local ret = {}
    for objId, info in pairs(allPlayers) do
        ret[info.userId] = objId
    end
    return ret
end
local NUMBER_DATE_HANDLER = {}
NUMBER_DATE_HANDLER.player = function(data)
    local ret = {}
    local userIdMap = getAllPlayerAtUserId()
    local curWorld = World.CurWorld
    for userId, number in pairs(data.player) do
        local playerInfo = Game.GetPlayerByUserId(userId)
        if playerInfo then
            local obj = curWorld:getObject(playerInfo.objID)
            if obj then
                ret[#ret + 1] = {obj = obj, number = number, userId = userId}
                userIdMap[userId] = nil
            end
        end
    end
    for userId, objId in pairs(userIdMap) do
        ret[#ret + 1] = {obj = curWorld:getObject(objId), number = 0, userId = userId}
    end
    sortNumberTable(ret)
    return ret
end
local function getLessPlayerTeamsInfo(userIdMap, numberText)
    local tempTeam = {}
    local curWorld = World.CurWorld
    for userId, objId in pairs(userIdMap) do
        local obj = curWorld:getObject(objId)
        local teamId = obj:getValue("teamId")
        if teamId <= 0 then
            tempTeam["PLAYER_"..userId] = {teamId = "PLAYER_"..userId, number = numberText or 0, users = {[1] = {obj = obj, number = 0, userId = userId}}}
        else
            local temp = tempTeam[teamId]
            if not temp then
                temp = {teamId = teamId, number = numberText or 0, users = {}}
                tempTeam[teamId] = temp
            end
            temp.users[#temp.users + 1] = {obj = obj, number = numberText or 0, userId = userId}
        end
    end
    return tempTeam
end
NUMBER_DATE_HANDLER.team = function(data)
    local teams = {}
    local curWorld = World.CurWorld
    local userIdMap = getAllPlayerAtUserId()
    for teamId, info in pairs(data.team) do
        local team = Game.GetTeam(teamId)
        if not team then
            goto CONTINUE
        end
        local playerList = team.playerList
        local users = {}
        local temp = {teamId = teamId, number = info.all, users = users}
        for objId, _ in pairs(playerList) do
            local obj = curWorld:getObject(objId)
            if obj and obj.isPlayer then
                local userId = obj.platformUserId
                users[#users + 1] = {obj = obj, number = info[userId] or 0, userId = userId}
                userIdMap[userId] = nil
            end
        end
        sortNumberTable(users)
        teams[#teams + 1] = temp
        ::CONTINUE::
    end
    for userId, number in pairs(data.player) do
        local playerInfo = Game.GetPlayerByUserId(userId)
        if playerInfo then
            local obj = curWorld:getObject(playerInfo.objID)
            if obj then
                teams[#teams + 1] = {teamId = "PLAYER_"..userId, number = number, users = {[1] = {obj = obj, number = number, userId = userId}}}
                userIdMap[userId] = nil
            end
        end
    end
    sortNumberTable(teams)
    for teamId, info in pairs(getLessPlayerTeamsInfo(userIdMap)) do
        teams[#teams + 1] = info
    end
    return teams
end
------
local HANDLER_GAME_OVER_FUNC = {}
HANDLER_GAME_OVER_FUNC.NONE = function(data)
    local win = UI:getWindow("gameOverPanel", true)
    if not win then
        --UI:openSystemWindowAsync(function(window) end,"gameOverPanel", nil, data)
        win = UI:openSystemWindow("gameOverPanel", nil, data)
    else
        win:refresh(data)
    end
end
HANDLER_GAME_OVER_FUNC.TIME_END = function(data)
    local temp = {}
    local useModel = data.useModel
    if useModel == DEFINE_TYPE.kill then
        HANDLER_GAME_OVER_FUNC.KILL_PLAYER_NUM(data)
    elseif useModel == DEFINE_TYPE.score then
        HANDLER_GAME_OVER_FUNC.SCORE(data)
    end
end
HANDLER_GAME_OVER_FUNC.KILL_ALL_PLAYER = function(data)
    HANDLER_GAME_OVER_FUNC.KILL_PLAYER_NUM(data)
end
local function openGameOverRank(data)
    local win = UI:getWindow("gameOverRank", true)
    if not win then
        --UI:openSystemWindowAsync(function(window) end,"gameOverRank", nil, data)
        win = UI:openSystemWindow("gameOverRank", nil, data)
    else
        win:refresh(data)
    end
end
HANDLER_GAME_OVER_FUNC.KILL_PLAYER_NUM = function(data)
    local settlementType, killerKills = data.settlementType, data.killerKills
    local func = settlementType and NUMBER_DATE_HANDLER[settlementType] or nil
    if func then
        openGameOverRank({settlementType = settlementType, teamRankingText = "pc.gameover.condition.all.kill", rankingText = "pc.gameover.condition.kill", data = func(killerKills)})
    end
end
HANDLER_GAME_OVER_FUNC.ENTER_REGION = function(data)
    local function sortNumberTable(tb)
        table.sort(tb, function(a, b) 
            if a.number == b.number  then
                if a.obj then
                    return a.obj.objID > b.obj.objID
                elseif a.users then
                    return #a.users > #b.users
                else
                    return false
                end
            end
            return b.number > a.number
        end)
    end
    local playerTimes = {}
    local tempTeamTimes = {}
    local userIdMap = getAllPlayerAtUserId()
    local curWorld = World.CurWorld
    local settlementType, enterRegionTime = data.settlementType, data.enterRegionTime
    for userId, time in pairs(enterRegionTime) do
        local playerInfo = Game.GetPlayerByUserId(userId)
        if playerInfo then
            local obj = curWorld:getObject(playerInfo.objID)
            if obj then
                playerTimes[#playerTimes + 1] = {obj = obj, number = time / 20, userId = userId}
                userIdMap[userId] = nil
                local teamId = obj:getValue("teamId")
                if not teamId or teamId <= 0 then
                    teamId = userId
                end
                local temp = tempTeamTimes[teamId]
                if not temp then
                    temp = {teamId = teamId, number = 0, users = {}}
                    tempTeamTimes[teamId] = temp
                end
                temp.users[#temp.users + 1] = {obj = obj, number = time / 20, userId = userId}
                temp.number = temp.number + time / 20
            end
        end
    end
    local teamTimes = {}
    for teamId, info in pairs(tempTeamTimes) do
        local team = Game.GetTeam(teamId)
        if not team or (#info.users >= team.playerCount) then
            teamTimes[#teamTimes + 1] = info
        elseif settlementType == DEFINE_TYPE.team then
            for objId, _ in pairs(team.playerList) do
                local obj = curWorld:getObject(objId)
                if obj and obj.isPlayer then
                    userIdMap[obj.platformUserId] = objId
                end
            end
        end
    end
    for _, info in pairs(teamTimes) do
        sortNumberTable(info.users, true)
    end
    sortNumberTable(playerTimes, true)
    sortNumberTable(teamTimes, true)
    for userId, objId in pairs(userIdMap) do
        playerTimes[#playerTimes + 1] = {obj = curWorld:getObject(objId), number = "pc.gameover.condition.enterRegion.loss", userId = userId}
    end
    for teamId, info in pairs(getLessPlayerTeamsInfo(userIdMap, "pc.gameover.condition.enterRegion.loss")) do
        teamTimes[#teamTimes + 1] = info
    end
    openGameOverRank({settlementType = settlementType, 
        teamRankingText = "pc.gameover.condition.all.enterRegion", 
        rankingText = "pc.gameover.condition.enterRegion", 
        data = (settlementType == DEFINE_TYPE.team) and teamTimes or playerTimes}) 
end

local function sortPersonCollect(tb)
    table.sort(tb, function(a, b) 
        local a_finishTime, b_finishTime = a.finishTime or -1, b.finishTime or -1
        if a_finishTime >= 0 and b_finishTime >= 0 then
            return a_finishTime < b_finishTime
        end
        if a_finishTime >= 0  then
            return true
        end
        if b_finishTime >= 0  then
            return false
        end
        if a.number == b.number  then
            if a.obj then
                return a.obj.objID > b.obj.objID
            elseif a.users then
                return #a.users > #b.users
            else
                return false
            end
        end
        return a.number > b.number 
    end)
end
local HANDLER_GAME_OVER_FUNC_COLLECT = {}
HANDLER_GAME_OVER_FUNC_COLLECT.player = function(data)
    local ret = {}
    local userIdMap = getAllPlayerAtUserId()
    local curWorld = World.CurWorld
    for userId, info in pairs(data.player) do
        local playerInfo = Game.GetPlayerByUserId(userId)
        if playerInfo then
            local obj = curWorld:getObject(playerInfo.objID)
            if obj then
                ret[#ret + 1] = {obj = obj, number = info.collectCount, userId = userId, finishTime = info.finishTime}
                userIdMap[userId] = nil
            end
        end
    end
    for userId, objId in pairs(userIdMap) do
        ret[#ret + 1] = {obj = curWorld:getObject(objId), number = 0, userId = userId}
    end
    sortPersonCollect(ret)
    return ret
end
HANDLER_GAME_OVER_FUNC_COLLECT.team = function(data)
    local teams = {}
    local userIdMap = getAllPlayerAtUserId()
    local curWorld = World.CurWorld
    for teamId, info in pairs(data.team) do
        local team = Game.GetTeam(teamId)
        local users = {}
        local temp = {teamId = teamId, number = info.collectCount, users = users, finishTime = info.finishTime}
        if not team or not team.playerList then
            local playerInfo = Game.GetPlayerByUserId(teamId)
            if playerInfo then
                local obj = curWorld:getObject(playerInfo.objID)
                if obj then
                    users[#users + 1] = {obj = obj, number = info.collectCount, userId = teamId}
                    userIdMap[teamId] = nil
                end
            end
        else
            for objId, _ in pairs(team.playerList) do
                local obj = curWorld:getObject(objId)
                if obj and obj.isPlayer then
                    local userId = obj.platformUserId
                    users[#users + 1] = {obj = obj, number = info.users[userId] or 0, userId = userId}
                    userIdMap[userId] = nil
                end
            end
        end
        sortPersonCollect(users)
        teams[#teams + 1] = temp
    end
    sortPersonCollect(teams)
    for teamId, info in pairs(getLessPlayerTeamsInfo(userIdMap)) do
        teams[#teams + 1] = info
    end
    return teams
end
HANDLER_GAME_OVER_FUNC.COLLECT = function(data)
    local settlementType, collectMap = data.settlementType, data.collectMap
    local func = settlementType and HANDLER_GAME_OVER_FUNC_COLLECT[settlementType] or nil
    if func then
        openGameOverRank({settlementType = settlementType, teamRankingText = "pc.gameover.condition.all.collect", rankingText = "pc.gameover.condition.collect", data = func(collectMap)})
    end
end
HANDLER_GAME_OVER_FUNC.SCORE = function(data)
    local settlementType, playerScore = data.settlementType, data.playerScore
    local func = settlementType and NUMBER_DATE_HANDLER[settlementType] or nil
    if func then
        openGameOverRank({settlementType = settlementType, teamRankingText = "pc.gameover.condition.all.score", rankingText = "pc.gameover.condition.score", data = func(playerScore)})
    end
end

Lib.subscribeEvent(Event.EVENT_SERVER_GAMEOVER, function(packet)
    local data, typ = packet.sendData, packet.typ
    if not typ or not CONDITION_TYPE[typ] then
        typ = CONDITION_TYPE.NONE
    end
    if not HANDLER_GAME_OVER_FUNC[typ] then
        return
    end
    HANDLER_GAME_OVER_FUNC[typ](data)
end)

RETURN(Game)