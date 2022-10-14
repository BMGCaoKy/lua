require "common.game"
require "game.game_team"
local TeamList = T(Game, "TeamList")
local player_count = L("player_count", 0)
local players = L("players", {})
local leavePlayersData = L("leavePlayerData", {})
local rankCondition = require "editor_rankCondition"
local showKillCount, showScore = rankCondition.showKillCount, rankCondition.showScore

local teamCfg = World.cfg.team
if teamCfg and (not next(teamCfg)) then
    teamCfg = nil
end

function Game.AddLeavePlayersData(userId, data)
    leavePlayersData[userId] = data
end

function Game.GetAllLeavePlayersData()
    return leavePlayersData
end

local function sortByKillCount(tb)
    if not tb then
        perror(" sortByKillCount error. tb got nil!!")
        return
    end
    table.sort(tb, function(a, b)
        if a.killCount == b.killCount then
            if not a.score then
                return false
            else
                return a.score > b.score
            end
        else
            return a.killCount > b.killCount
        end
    end)
end

local function sortByScore(tb)
    if not tb then
        perror(" sortByScore error. tb got nil!!")
        return
    end
    table.sort(tb, function(a, b)
        if a.score == b.score then
            if not a.killCount then
                return false
            else
                return a.killCount > b.killCount
            end
        else
            return a.score > b.score
        end
    end)
end

local function sortByAlive(tb)
    local aliveData
    for i, v in ipairs(tb) do
        if v.isAlive then
            aliveData = table.remove(tb, i)
            break
        end
    end
    sortByScore(tb)
    if aliveData then
        table.insert(tb, 1, aliveData)
    end
end

local function refreshRankInfo(tb)
    if tb[2] and tb[2].rank == 1 then
        for i, data in ipairs(tb) do
            if i ~= 1 then
                data.rank = data.rank + 1
            end
        end
    end
end

local function rankNum(tb, isOnlyFirst)
    for i = 1, #tb do
        local ret1, ret2 = tb[i], tb[i + 1]
        if i == 1 then
            ret1.rank = 1
        end
        if ret2 then
            local s1, s2, k1, k2 = ret1.score or 0, ret2.score or 0, ret1.killCount or 0, ret2.killCount or 0
            if s1 == s2 and k1 == k2 then
                ret2.rank = ret1.rank
            else
                ret2.rank = i + 1
            end
        end
    end

    if isOnlyFirst then
        refreshRankInfo(tb)
    end
end

--for sorting in real time
function Game.GetPlayersRank()
    local rankDatas = {}

    for _, playerInfo in pairs(leavePlayersData) do
        local data = rankDatas[playerInfo.platformUserId]
        if data then
            if showKillCount then
                data.killCount = data.killCount + playerInfo.killCount
            end
            if showScore then
                data.score = data.score + playerInfo.score
            end
        else
            rankDatas[playerInfo.platformUserId] = {
                name = playerInfo.name,
                killCount = showKillCount and playerInfo.killCount,
                score = showScore and playerInfo.score,
                isLeave = true,
                objID = playerInfo.objID,
            }
        end
    end

    local players = Game.GetAllPlayers()
    for objID, playerInfo in pairs(players) do
        local curKillCount = playerInfo.vars.killPlayerCount or 0
        local curScore = playerInfo.vars.score or 0
        rankDatas[playerInfo.platformUserId] = {
            name = playerInfo.name,
            killCount = showKillCount and curKillCount,
            score = showScore and curScore,
            objID = playerInfo.objID,
        }
    end
    
    local arr = {}
    for _, data in pairs(rankDatas) do
        arr[#arr + 1] = data
    end

    if showScore then
        sortByScore(arr)
    else
        assert(showKillCount)
        sortByKillCount(arr)
    end

    rankNum(arr)
    return arr
end

local function getAllTeamGameData()
    local rankDatas = {}
    for teamID, teamInfo in pairs(TeamList) do
        local curKillCount = teamInfo.vars.killPlayerCount or 0
        local curScore = teamInfo.vars.score or 0
        rankDatas[#rankDatas + 1] = {
            teamID = teamID,
            killCount = showKillCount and curKillCount,
            score = showScore and curScore,
        }
    end
    return rankDatas
end

--for sorting in real time
function Game.GetTeamsRank()
    local rankDatas = getAllTeamGameData()

    if showScore then
        sortByScore(rankDatas)
    else
        assert(showKillCount)
        sortByKillCount(rankDatas)
    end

    rankNum(rankDatas)
    return rankDatas
end

local gameOverCondition = World.cfg.gameOverCondition or {}
local isAddKillCount, isAddScore

local function initCanAdd()
    local condition = gameOverCondition
    if condition.timeOver and condition.timeOver.enable then
        if condition.timeOver.value == "killCount" then
            isAddKillCount = true
        else
            isAddScore = true
        end
    end
    if condition.killCount and condition.killCount.enable then
        isAddKillCount = true
    end
    if condition.attainScore and condition.attainScore.enable then
        isAddScore = true

    end
    if condition.otherAllDie then
        isAddKillCount = true
        isAddScore = true
    end
end
initCanAdd()

local function getAllPlayerGameData()
    local allPlayers = {}
    for _, player in pairs(Game.GetAllPlayers()) do
        allPlayers[player.platformUserId] = {
            isAlive = true,
            killCount = player.vars.killPlayerCount or 0,
            score = player.vars.score or 0,
            objID = player.objID,
            teamId = player:getValue("teamId"),
            name = player.name or "test01",
        }
    end
	for _, data in pairs(Game.GetAllLeavePlayersData()) do
        allPlayers[data.platformUserId] = {
            isAlive = false,
            killCount = data.killCount,
            score = data.score,
            objID = data.objID,
            teamId = data.teamId,
            name = data.name,
        }
    end
    return allPlayers
end

local function sortByGameOverCondition(tb, reachCond)
    if reachCond == "killCount" then
        sortByKillCount(tb)
    elseif reachCond == "attainScore" then
        sortByScore(tb)
    elseif reachCond == "otherAllDie" then
        if teamCfg then
            sortByScore(tb)
        else
            sortByAlive(tb)
        end
    else -- timeUp
        if isAddKillCount then
            sortByKillCount(tb)
        else
            sortByScore(tb)
        end
    end
end

local function getRankItem(data)
    local item = Lib.copy(data)
    return item
end

local function getPlayerGameResult()
    local rankDatas = {}
    local allPlayers = getAllPlayerGameData()
    for _, data in pairs(allPlayers) do
        rankDatas[#rankDatas + 1] = getRankItem(data)
    end
    return rankDatas
end

local function getTeamGameResult()
    local rankDatas = {}
    local allTeams = getAllTeamGameData()
    for _, data in pairs(allTeams) do
        rankDatas[#rankDatas + 1] = getRankItem(data)
    end
    return rankDatas
end

local rankCondition = require "editor_rankCondition"
local showGameTimeRank = rankCondition.noCondition and rankCondition.showGameTimeRank


function Game.SendGameTimeRankResult(player)
    player:updateRankScore(2, 1, player:getPlayTime())
    local rankResult = { timeRank = true, uiType = "Time", myTime = player:getPlayTime()}
    player:sendPacket({pid = "SendGameResult", result = rankResult})
    player:lightTimer("requestRankInfo", 1, function ()
        if player:isValid() then
            player:requestRankInfo(2)
        end
    end)
end

function Game.GetGameResult(reachCond, player, isGameOVer)
    local rankResult
    rankResult = teamCfg and getTeamGameResult() or getPlayerGameResult()
	Lib.logError("GetGameResult",Lib.v2s(rankResult))
    sortByGameOverCondition(rankResult, reachCond)
    rankNum(rankResult, reachCond == "otherAllDie")

    return rankResult
end

function Game.TryJoinTeamBySystem(player)
	local worldCfg = World.cfg
    if not worldCfg.team or not worldCfg.automatch then
		local teamID = player:data("main").team
		if not teamID then
			return false
		end
		local team = Game.GetTeam(teamID, true)
		team:joinEntity(player)
		return true
	end
    local function changeTeamActor(teamInfo)
        if teamInfo.actorName then
            if not teamInfo.ignorePlayerSkin then
                local attrInfo = player:getPlayerAttrInfo()
                player:changeSkin(attrInfo.skin)
                player:changeActor(player:data("main").sex==2 and "editor_girl.actor" or "editor_boy.actor")
            else
                player:changeActor(teamInfo.actorName, true)
            end
        end
    end
    local userId = player.platformUserId
    for _, data in pairs(leavePlayersData) do
        if data.platformUserId == userId then
            Game.TryJoinTeamByPlayer(player, data.teamId)
            local info = worldCfg.team and worldCfg.team[data.teamId] or {}
            changeTeamActor(info)
            return
        end
    end
    local minTeam, memberLimit, teamInfo = nil, nil, nil
	for _, info in ipairs(worldCfg.team) do
        local team = Game.GetTeam(info.id, true)
        local limit = info.memberLimit
        if not limit then
            if not minTeam or team.playerCount < minTeam.playerCount then
                minTeam = team
                teamInfo = info
            end
        elseif limit > team.playerCount then
            if not minTeam or team.playerCount/limit < minTeam.playerCount/assert(memberLimit) then
                minTeam = team
                memberLimit = limit
                teamInfo = info
            end
        end
    end
    if not minTeam then
		return false
	end
    minTeam:joinEntity(player)
    if minTeam.initPos then
        player:setPos(minTeam.initPos)
    end
    changeTeamActor(teamInfo)
	return true
end

local playTime = World.cfg.playTime
local startTick
local updateTimer
function Game.UpdateLeftTime()
    if not startTick then
        startTick = World.CurWorld:getTickCount()
    end
    if updateTimer then
        return
    end
    updateTimer = World.Timer(20, function ()
        local leftTick = playTime - (World.CurWorld:getTickCount() - startTick)
        if leftTick < 20 then
            if updateTimer then
                updateTimer()
                updateTimer = nil
            end
            return false
        end
        local packet = {
            pid = "UpdateLeftTime",
            var = leftTick,
            nowTime = os.time(),
        }
        WorldServer.BroadcastPacket(packet)
        return true
    end)
end

function Game.ShowPlayerHeadPropCollectUI(objID)
    local Condition = World.cfg.gameOverCondition
    local propCondition = Condition.propsCollection
    if not propCondition or not propCondition.enable then
        return 
    end
    local data = {
        width = 1.1,
        height = 0.5,
        position = {x = 0, y = 3.1, z = 0},
        rotation = {x = 0, y = 3.1, z = 0},
        name = "propNumberTip",
    }
    local key = "propNumberTip_" .. objID
    SceneUIManager.AddEntitySceneUI(objID, key, data.name, data.width, data.height, data.position, data.rotation)
end

function Game.RemovePlayerHeadPropCollectUI(objID)
    local Condition = World.cfg.gameOverCondition
    if not Condition.propsCollection or not Condition.propsCollection.enable then
        return 
    end
    local key = "propNumberTip_" .. objID
    SceneUIManager.RemoveEntitySceneUI(objID, key)
end

local isTeam = World.cfg.team
local propsCollection = gameOverCondition.propsCollection and gameOverCondition.propsCollection.enable
function Game.OnPlayerLoginForEditor(player)
    if not propsCollection then
        return
    end
    local celloctID = isTeam and player:getValue("teamId") or player.objID
    Game.ShowPlayerHeadPropCollectUI(player.objID)
    Game.InitPlayerPropCollectInfo(celloctID, player.name, player:getValue("teamId"), player.objID)
end

function Game.OnPlayerLogoutForEditor(player)
    if not propsCollection then
        return
    end
    local celloctID = isTeam and player:getValue("teamId") or player.objID
    Game.RemovePlayerPropCollectInfo(celloctID, player.objID)
    Game.RemovePlayerHeadPropCollectUI(player.objID)
end
