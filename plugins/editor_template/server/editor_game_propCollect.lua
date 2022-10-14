local propCollectInfo = {collectInfo = {}}
local teamCollectInfo = {}
local isTeam = World.cfg.team
local countDownFun
local condition = World.cfg.gameOverCondition
local PropCfg = condition and condition.propsCollection and condition.propsCollection.propCfg or {}

-- 比较收集成功的时候的一个现后顺序，通过收集成功时的时间排序
local function updatePropCelloctInfo()
    local isSuccess, objID
    local isInitMinTime = false
    local minTime
    for id, info in pairs(propCollectInfo.collectInfo) do
        if not info.time then
            goto continue
        end
        if info.collectPropCount < (PropCfg.count or 0) then
            goto continue
        end
        if not isInitMinTime then
            minTime = info.time
        end
        if minTime >= info.time and info.isSuccess then
            minTime = info.time
            isSuccess = info.isSuccess
            objID = id
        end
        isInitMinTime = true
        ::continue::
    end
    propCollectInfo.isSuccess = isSuccess
    propCollectInfo.objID = objID
end

local function setPlayerCollectInfoForTeam(collectorsInfo, collectPropCount, playerCollectCount, playerId, teamId, playerName)
    collectorsInfo.collectPropCount = collectPropCount
    collectorsInfo.players = collectorsInfo.players or {}
    collectorsInfo.players[playerId] = collectorsInfo.players[playerId] or {}
    local playerInfo = collectorsInfo.players[playerId]
    collectorsInfo.teamId = teamId
    playerInfo.collectPropCount = playerCollectCount
    playerInfo.playerName = playerName
    playerInfo.celloctID = playerId
end

local function setPlayerCollectInfoForSingle(collectorsInfo, celloctID, collectPropCount, playerName)
    collectorsInfo.collectPropCount = collectPropCount
    collectorsInfo.playerName = playerName
    collectorsInfo.celloctID = celloctID
end

function Game.InitPlayerPropCollectInfo(celloctID, playerName, teamId, playerId, collectPropCount, playerCollectCount)
    collectPropCount = collectPropCount or 0
    playerCollectCount = playerCollectCount or 0
    Game.RefreshPropCollectData(celloctID, collectPropCount, playerCollectCount, playerName, playerId, teamId, true)
end

function Game.RemovePlayerPropCollectInfo(celloctID, playerId)
    if isTeam and propCollectInfo.collectInfo[celloctID] then
        -- 队伍中的玩家离开之后，总的收集数量需要减去离开玩家的数量
        local collectPropCount = propCollectInfo.collectInfo[celloctID].collectPropCount
        local logoutCollectCount = propCollectInfo.collectInfo[celloctID].players[playerId].collectPropCount
        local surplus = collectPropCount - logoutCollectCount
        propCollectInfo.collectInfo[celloctID].collectPropCount = surplus
        teamCollectInfo[celloctID].count = surplus
        propCollectInfo.collectInfo[celloctID].players[playerId] = nil
        Game.RefreshTeamAllPlayerHeadUi(celloctID, surplus)
    else
        propCollectInfo.collectInfo[celloctID] = nil
    end
    updatePropCelloctInfo()
    local isCancel = not propCollectInfo.isSuccess
    Game.ShowPropCollectCountDown(isCancel, not isCancel and Game.GetNewSuccessCollectName(propCollectInfo.objID))
end

--celloctID: 收集者ID(个人模式为个人的ID，团队模式为队伍ID)
--collectPropCount: 收集的数量(个人模式为个人的收集数量，团队模式为团队的收集数量)
--playerCollectCount: 玩家收集的数量
--playerName: 玩家名
--playerId: 玩家ID
--teamId: 队伍ID
function Game.RefreshPropCollectData(celloctID, collectPropCount, playerCollectCount, playerName, playerId, teamId, isInit)
    propCollectInfo.collectInfo[celloctID] = propCollectInfo.collectInfo[celloctID] or {}
    local collectorsInfo = propCollectInfo.collectInfo[celloctID]

    if isInit then
        collectorsInfo.isSuccess = false
        collectorsInfo.time = nil
    end

    if isTeam then
        teamCollectInfo[celloctID] = {}
        setPlayerCollectInfoForTeam(collectorsInfo, collectPropCount, playerCollectCount, playerId, teamId, playerName)
    else
        setPlayerCollectInfoForSingle(collectorsInfo, celloctID, collectPropCount, playerName)
    end
end

function Game.GetTeamCollectCount(player, defalut)
    local teamId = player:getValue("teamId")
    teamCollectInfo[teamId] = teamCollectInfo[teamId] or {}
    teamCollectInfo[teamId].count = teamCollectInfo[teamId].count or defalut
    return teamCollectInfo[teamId].count
end

function Game.SetTeamCollectCount(player, count)
    local teamId = player:getValue("teamId")
    teamCollectInfo[teamId].count = count
end

function Game.GetTeamAllPlayerInfo(teamID)
    local teams = Game.GetAllTeamsInfo()
    return teams[teamID] or {}
end

function Game.setPropCelloctSuccess(celloctID)
    propCollectInfo.collectInfo[celloctID].isSuccess = true
    propCollectInfo.collectInfo[celloctID].time = os.time()
    updatePropCelloctInfo()
end

function Game.setPropCelloctFail(celloctID, playerName, playerId, collectPropCount, playerCollectCount)
    Game.InitPlayerPropCollectInfo(celloctID, playerName, celloctID, playerId, collectPropCount, playerCollectCount)
    propCollectInfo.collectInfo[celloctID].isSuccess = false
    propCollectInfo.collectInfo[celloctID].time = nil
    updatePropCelloctInfo()
end

function Game.isCollectSuccess()
    return propCollectInfo.isSuccess
end

function Game.GetNewSuccessCollectName(celloctID)
    return isTeam and propCollectInfo.objID or propCollectInfo.collectInfo[celloctID].playerName
end

function Game.GetNewSuccessCollectID()
    return propCollectInfo.objID
end

function Game.GetPropCollectData()
    for id, info in pairs(propCollectInfo.collectInfo) do
        if id ~= propCollectInfo.objID then
            info.isSuccess = false
        end
    end
    return propCollectInfo.collectInfo
end

local function ShowPropCollectRank()
    local packet = {
        pid = "ShowPropCollectRank",
        rankData = Game.GetPropCollectData()
    }
    WorldServer.BroadcastPacket(packet)
end

function Game.ShowPropCollectCountDown(isCancel, Collectors)
    if countDownFun then
        countDownFun()
        countDownFun = false
    end
    local duration = condition.propsCollection.duration
    local packet = {
        pid = "ShowPropCollectCountDown",
        collectorsName = Collectors,
        isCancel = isCancel,
        CountdownTime = duration
    }
    WorldServer.BroadcastPacket(packet)

    if isCancel then
        return
    end
    local totleTime = (duration - 1) * 20
    countDownFun = World.Timer(20, function ()
        local timeText = math.ceil(totleTime / 20)
        if totleTime <= 0 then
            packet.isCancel = true
            WorldServer.BroadcastPacket(packet)
            ShowPropCollectRank()
            Game.Over()
            return false
        end
        packet.CountdownTime = timeText
        WorldServer.BroadcastPacket(packet)
        totleTime = totleTime - 20
        return true
    end)
end

function Game.RefreshTeamAllPlayerHeadUi(teamId, collectPropCount)
    local team = Game.GetTeamAllPlayerInfo(teamId)
    for objID, isDie in pairs(team.playerList) do
        SceneUIManager.RefreshEntitySceneUI(objID, "propNumberTip_" .. objID, {propNumberText = collectPropCount})
    end
end