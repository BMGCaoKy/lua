--[[
"pcGameOverCondition":
{
    "enable" : bool, -- must 
    "conditionType" : "NONE/TIME_END/KILL_ALL_PLAYER/KILL_PLAYER_NUM/ENTER_REGION/COLLECT/SCORE" -> CONDITION_TYPE -- must, default NONE
    -------------------- ↓ 结束游戏判断配置, 可选，根据上面的conditionType去对应下面的config
    TIME_END -> "timeEndConfig" : { 游戏自然结束,结束后的排名条件判断依据
            "useModel" : "kill/score",
            "settlementType" : "player/team"
        }
        注：会返回杀人数+分数

    KILL_ALL_PLAYER -> "killAllPlayerConfig" : -- 杀掉所有敌人。
        {
            "settlementType" : "player/team"
        }
        注：此处的情况是指某个玩家死的那一刻判定的

    KILL_PLAYER_NUM -> "killPlayerNumConfig" : -- 击杀指定数量敌人。
        {
            "num" : int,
            "settlementType" : "player/team"
        }
        注：非本队伍的都是敌人

    ENTER_REGION -> "enterRegionConfig" : { -- 进入某个key为value的区域
        "allRegion" : bool -- 如果配置了此项true，那么所有的region都是目标region
        "key" : string, 
        "value" : all -- value 可为任意值
        "settlementType" : player/team/all -- 谁进入可以结束，当前玩家/当前玩家所在team/所有人
    }
        注：此处如果非个人的话那么到达过就记录即可
        注：没到的结算面板标注未完成即可。

    COLLECT -> "collectConfig" : { -- 团队/个人收集指定道具就游戏结束
        "collectType" : string, -- 收集道具类型 block/item
        "fullName" : string -- 收集道具 blockName/fullName
        "count" : int -- 收集数量
        "time" : int  -- 需要持续持有的时间, 单位 秒
        "settlementType" : player/team -- 个人收集/团队收集
    }
        注：需求：一个人数量达标之后，所有都会有个倒计时。这时候后面的人再收集满，也不会打断这个倒计时，直到达标的人被干掉。
                达标的人如果被干掉之后，并且没有别人收集齐道具，那么停止倒计时，如果有别人也已经满了时，那么所有人显示这个人的倒计时，如果有多个人有倒计时，显示时间最短的。
                倒计时结束才是真正的结束游戏

    SCORE -> "scoreConfig" : -- 到达指定分数游戏结束
        {
            "num" : int,
            "settlementType" : "player/team"
        }
}
--]]

local DEFINE_TYPE = {
    player = "player",
    team = "team",
    all = "all",
    block = "block",
    item = "item",
    kill = "kill",
    score = "score"
}

local CONDITION_TYPE = {
    NONE = "NONE",
    TIME_END = "TIME_END",
    KILL_ALL_PLAYER = "KILL_ALL_PLAYER",
    KILL_PLAYER_NUM = "KILL_PLAYER_NUM",
    ENTER_REGION = "ENTER_REGION",
    COLLECT = "COLLECT",
    SCORE = "SCORE",
}
Game.gameOverConditionTypeFunc = {}

local pcGameOverCondition = L("pcGameOverCondition", World.cfg.pcGameOverCondition or {})
-- TIME_END
-- return {killerKills = killerKills, playerScore = playerScore, useModel = timeEndConfig.useModel, settlementType = timeEndConfig.settlementType}
-- KILL_ALL_PLAYER/KILL_PLAYER_NUM
local killerKills = L("killerKills", {player = {}, team = {}})
--[[
    killerKills = {
        player = {
            userId = killCount
        }
        team = {
            teamId = {
                all = allKillCount,
                userId = killCount
            }
        }
    }
]]
-- ENTER_REGION
local enterRegionTime = L("enterRegionTime", {})
--[[
    enterRegionTime = {
        userId = {
            enterTime = enterTime
            obj = enterObj
        }
    }
]]
-- COLLECT
-- 注：收集的比较特殊，需要在某个人收集齐特殊东西并且持续多少秒后才结束游戏
local collectMap = L("collectMap", {player = {}, team = {}})
--[[
    collectMap = {
        countDownTimer = function xx
        countDownOwnerKey = userId / teamId
        player = {
            userId = {
                finishTime = finishTime, 
                collectCount = collectCount
            },
        }
        team = {
            teamId = {
                finishTime = finishTime,
                collectCount = collectCount,
                users = {
                    userId = collectCount
                }
            },
        }
    }
]]
-- SCORE
local playerScore = L("playerScore", {player = {}, team = {}})
--[[
    playerScore = {
        player = {
            userId = score
        }
        team = {
            all = xx,
            userId = score
        }
    }
]]

local BUILD_GAME_OVER_SEND_DATA_FUNC = {}
BUILD_GAME_OVER_SEND_DATA_FUNC.NONE = function()
    return {}
end
BUILD_GAME_OVER_SEND_DATA_FUNC.TIME_END = function()
    return {killerKills = killerKills, playerScore = playerScore, useModel = pcGameOverCondition.timeEndConfig.useModel, settlementType = pcGameOverCondition.timeEndConfig.settlementType or DEFINE_TYPE.player}
end
BUILD_GAME_OVER_SEND_DATA_FUNC.KILL_ALL_PLAYER = function()
    return {killerKills = killerKills, settlementType = pcGameOverCondition.killAllPlayerConfig.settlementType or DEFINE_TYPE.player}
end
BUILD_GAME_OVER_SEND_DATA_FUNC.KILL_PLAYER_NUM = function()
    return {killerKills = killerKills, settlementType = pcGameOverCondition.killPlayerNumConfig.settlementType or DEFINE_TYPE.player}
end
BUILD_GAME_OVER_SEND_DATA_FUNC.ENTER_REGION = function()
    local ret = {}
    for userId, info in pairs(enterRegionTime) do
        ret[userId] = info.enterTime
    end
    return {settlementType = pcGameOverCondition.enterRegionConfig.settlementType or DEFINE_TYPE.player, enterRegionTime = ret}
end
BUILD_GAME_OVER_SEND_DATA_FUNC.COLLECT = function()
    return {
        collectMap = {
            player = collectMap.player,
            team = collectMap.team,
        },
        settlementType = pcGameOverCondition.collectConfig.settlementType or DEFINE_TYPE.player
    }
end
BUILD_GAME_OVER_SEND_DATA_FUNC.SCORE = function()
    return {playerScore = playerScore, settlementType = pcGameOverCondition.scoreConfig.settlementType or DEFINE_TYPE.player}
end

--*******************************************************************************************************
--*******************************************************************************************************

local function checkEnableGameOverCondition()
    return pcGameOverCondition and pcGameOverCondition.enable
end

local function checkGameOver(typ, isOver, sendData)
    if sendData and BUILD_GAME_OVER_SEND_DATA_FUNC[typ] then
        -- Test Code
        -- print(" BUILD_GAME_OVER_SEND_DATA_FUNC[typ]() ", typ, Lib.v2s(BUILD_GAME_OVER_SEND_DATA_FUNC[typ](), 4))
        --
        WorldServer.BroadcastPacket({
            pid = "ServerGameOver",
            typ = typ,
            sendData = BUILD_GAME_OVER_SEND_DATA_FUNC[typ](),
        })
    end
    if isOver and Game.GetState()=="GAME_GO" then
        Game.Over()
    end
end

function Game.sendServerGameOver(player, data)
    player:sendPacket({
        pid = "ServerGameOver",
        sendData = data
    })
end

function Game.checkGameOverGlobal(packet) -- 结束游戏返回true，否则返回false
    if not checkEnableGameOverCondition() then
        return false
    end
    local typ = pcGameOverCondition.conditionType or CONDITION_TYPE.NONE
    if not Game.gameOverConditionTypeFunc[typ] then
        return false
    end
    local ret = Game.gameOverConditionTypeFunc[typ](packet)
    checkGameOver(typ, ret, ret)
    return ret
end

function Game.checkGameOverAtTimeEnd(packet)
    return pcGameOverCondition.conditionType == CONDITION_TYPE.TIME_END and Game.checkGameOverGlobal(packet) or false
end

function Game.checkGameOverWithPlayerDead(packet)
    local isThisCondition = (pcGameOverCondition.conditionType == CONDITION_TYPE.KILL_ALL_PLAYER) or (pcGameOverCondition.conditionType == CONDITION_TYPE.KILL_PLAYER_NUM)
    if isThisCondition then
        return Game.checkGameOverGlobal(packet)
    else
        return Game.checkGameOverAtTimeEnd(packet)
    end
end

function Game.checkGameOverWithEnterRegion(packet)
    return (pcGameOverCondition.conditionType == CONDITION_TYPE.ENTER_REGION) and Game.checkGameOverGlobal(packet) or false
end

function Game.checkGameOverWithItemChange(packet)
    return (pcGameOverCondition.conditionType == CONDITION_TYPE.COLLECT) and Game.checkGameOverGlobal(packet) or false
end

function Game.checkGameOverWithScoreChange(packet)
    if pcGameOverCondition.conditionType == CONDITION_TYPE.SCORE then
        return Game.checkGameOverGlobal(packet)
    else
        return Game.checkGameOverAtTimeEnd(packet)
    end
end

local LOGIN_FUNC = {}
LOGIN_FUNC.COLLECT = function(player)
    SceneUIManager.AddEntitySceneUI(player.objID, "propNumberTip_" .. player.objID, "propNumberTip", 1.1, 0.5, {x = 0, y = 3.1, z = 0}, {x = 0, y = 3.1, z = 0})
    Game.gameOverConditionTypeFunc.COLLECT({obj = player, force = true})
end

function Game.GameOverConditionAtLogin(player)
    if not checkEnableGameOverCondition() then
        return false
    end
    local func = LOGIN_FUNC[pcGameOverCondition.conditionType or CONDITION_TYPE.NONE]
    if func then
        func(player)
    end
end

local LOGOUT_FUNC = {}
LOGOUT_FUNC.COLLECT = function(player)
    Game.gameOverConditionTypeFunc.COLLECT({obj = player, force = true})
    SceneUIManager.RemoveEntitySceneUI(player.objID, "propNumberTip_" .. player.objID)
end

function Game.GameOverConditionAtLogout(player)
    if not checkEnableGameOverCondition() then
        return false
    end
    local func = LOGOUT_FUNC[pcGameOverCondition.conditionType or CONDITION_TYPE.NONE]
    if func then
        func(player)
    end
end

local GAME_OVER_FUNC = {}
GAME_OVER_FUNC.NONE = function()
    checkGameOver(CONDITION_TYPE.NONE, false, true)
end

GAME_OVER_FUNC.TIME_END = function()
    checkGameOver(CONDITION_TYPE.TIME_END, false, true)
end

function Game.GameOverConditionAtGameOver()
    if not checkEnableGameOverCondition() then
        return false
    end
    local func = GAME_OVER_FUNC[pcGameOverCondition.conditionType or CONDITION_TYPE.NONE]
    if func then
        func()
    end
end
--*******************************************************************************************************
--*******************************************************************************************************
function Game.gameOverConditionTypeFunc.NONE(packet)
    return false
end

local TIME_END_FUNC = {}
TIME_END_FUNC.kill = function(packet)
    Game.gameOverConditionTypeFunc.KILL_PLAYER_NUM(packet, true, pcGameOverCondition.timeEndConfig.settlementType == DEFINE_TYPE.player)
end
TIME_END_FUNC.score = function(packet)
    Game.gameOverConditionTypeFunc.SCORE(packet, true, pcGameOverCondition.timeEndConfig.settlementType == DEFINE_TYPE.player)
end
function Game.gameOverConditionTypeFunc.TIME_END(packet)
    if not pcGameOverCondition.timeEndConfig then
        return false
    end
    local func = TIME_END_FUNC[pcGameOverCondition.timeEndConfig.useModel or DEFINE_TYPE.kill]
    if func then
        func(packet)
    end
    return false
end

local function playersIsTeam(players)
    local tempTeamId
    for i, player in pairs(players) do
        if not tempTeamId then
            tempTeamId = player:getValue("teamId")
        elseif tempTeamId ~= player:getValue("teamId") then
            return false
        end
    end
    return tempTeamId ~= 0
end

function Game.gameOverConditionTypeFunc.KILL_ALL_PLAYER(packet)
    if not pcGameOverCondition.killAllPlayerConfig then
        return false
    end
    local playerModel = pcGameOverCondition.killAllPlayerConfig.settlementType == DEFINE_TYPE.player
    Game.gameOverConditionTypeFunc.KILL_PLAYER_NUM(packet, true, playerModel)
    if Game.GetSurvivePlayersCount() <= 1 then
        return true
    end
    if playerModel then
        return
    end
    return playersIsTeam(Game.GetSurvivePlayers())
end

function Game.gameOverConditionTypeFunc.KILL_PLAYER_NUM(packet, force, isGameOverWithPlayer)
    local killPlayerNumConfig = pcGameOverCondition.killPlayerNumConfig or {}
    if not force and not killPlayerNumConfig then
        return false
    end
    local from, target = packet.from, packet.target
    if not from or not target or not from.isPlayer or not target.isPlayer then -- from:killer,target:deader
        return false
    end
    local fTeamID, tTeamId = from:getValue("teamId"), target:getValue("teamId")
    if isGameOverWithPlayer or killPlayerNumConfig.settlementType==DEFINE_TYPE.player or fTeamID == 0 then
        local temp = killerKills.player
        temp[from.platformUserId] = (temp[from.platformUserId] or 0) + 1
        return temp[from.platformUserId] >= (killPlayerNumConfig.num or 0)
    end
    if fTeamID == tTeamId then
        return false
    end
    local temp = killerKills.team[fTeamID]
    if not temp then
        temp = {all = 0}
        killerKills.team[fTeamID] = temp
    end
    temp.all = temp.all + 1
    temp[from.platformUserId] = (temp[from.platformUserId] or 0) + 1
    return temp.all >= (killPlayerNumConfig.num or 0)
end

local RETION_ENTER_TYPE_FUNC = {}
RETION_ENTER_TYPE_FUNC.player = function(packet)
    return true
end
-- 注：此处不统计enterCount之类的是因为玩家有可能进入后又退出了，或者重进的。为避免代码逻辑遍布太广，故每次判断时都对所有的userId对应的玩家的有效性进行判断
-- 注：此处如果有非team队伍在team模式下到达终点，那么就算赢了
RETION_ENTER_TYPE_FUNC.team = function(packet)
    local teamId = packet.obj:getValue("teamId")
    if teamId == 0 then
        return true
    end
    local count = 0
    for userId, info in pairs(enterRegionTime) do
        if info.obj:isValid() and info.obj:getValue("teamId") == teamId then
            count = count + 1
        else
            enterRegionTime[userId] = nil
        end
    end
    local team = Game.GetTeam(teamId)
    return team.playerCount <= count 
end
RETION_ENTER_TYPE_FUNC.all = function(packet)
    local count = 0
    for userId, info in pairs(enterRegionTime) do
        if info.obj:isValid() then
            count = count + 1
        else
            enterRegionTime[userId] = nil
        end
    end
    return Game.GetAllPlayersCount() <= count 
end
function Game.gameOverConditionTypeFunc.ENTER_REGION(packet)
    local enterRegionConfig = pcGameOverCondition.enterRegionConfig
    if not enterRegionConfig then
        return false
    end
    local region, obj = packet.region, packet.obj
    if not region or not obj or not obj.isPlayer then
        return false
    end
    local key, value, allRegion = enterRegionConfig.key, enterRegionConfig.value, enterRegionConfig.allRegion
    if not allRegion then
        if not key or not value then
            return false
        end
        local regionCfg = region.cfg or {}
        local tempValue = regionCfg[key]
        if type(value) == "table" then
            if type(tempValue) ~= "table" then
                return false
            end
            if not Lib.isSameTable(value, tempValue) then
                return false
            end
        elseif value ~= tempValue then
            return false
        end
    end
    if not enterRegionTime[obj.platformUserId] then
        enterRegionTime[obj.platformUserId] = {enterTime = World.Now(), obj = obj}
    end
    local func = RETION_ENTER_TYPE_FUNC[enterRegionConfig.settlementType or DEFINE_TYPE.player]
    if not func then
        return false
    end
    return func(packet)
end

local HANDLER_COLLECT_COUNT_FUNC = {}
HANDLER_COLLECT_COUNT_FUNC.player = function(obj, key, collectMap_collectType, full_name, block_name)
    local count = obj:tray():find_item_count(full_name, block_name)
    collectMap_collectType[key] = {collectCount = count}
    return count
end
HANDLER_COLLECT_COUNT_FUNC.team = function(obj, key, collectMap_collectType, full_name, block_name)
    local allCollect = 0
    local users = {}
    for objId, player in pairs(Game.GetTeamPlayers(key) or {[obj.objID] = obj}) do
        local tempCount = player:tray():find_item_count(full_name, block_name)
        users[player.platformUserId] = tempCount
        allCollect = tempCount + allCollect
    end
    collectMap_collectType[key] = {users = users, collectCount = allCollect}
    return allCollect
end
local GET_COLLECT_KEY_FUNC = {}
GET_COLLECT_KEY_FUNC.player = function(obj)
    return obj.platformUserId
end
GET_COLLECT_KEY_FUNC.team = function(obj)
    local ret = obj:getValue("teamId")
    return ret == 0 and GET_COLLECT_KEY_FUNC.player(obj) or ret
end
local GET_COLLECT_COUNT_DOWN_NAME_FUNC = {}
GET_COLLECT_COUNT_DOWN_NAME_FUNC.player = function(userId)
    if not userId then
        return ""
    end
    local obj = Game.GetPlayerByUserId(userId)
    return obj and obj.name or ""
end
GET_COLLECT_COUNT_DOWN_NAME_FUNC.team = function(teamId)
    if not teamId then
        return ""
    end
    local team = Game.GetTeam(teamId)
    if not team then
        return GET_COLLECT_COUNT_DOWN_NAME_FUNC.player(teamId)
    end
    return team.name
end
local COLLECT_HEAD_UI_FUNC = {}
COLLECT_HEAD_UI_FUNC.player = function(obj, curCount)
    SceneUIManager.RefreshEntitySceneUI(obj.objID, "propNumberTip_" .. obj.objID, {propNumberText = curCount})
end
COLLECT_HEAD_UI_FUNC.team = function(obj, curCount)
    for objID, _ in pairs(Game.GetTeamPlayers(obj:getValue("teamId")) or {[obj.objID] = true}) do
        SceneUIManager.RefreshEntitySceneUI(objID, "propNumberTip_" .. objID, {propNumberText = curCount})
    end
end
local function handlerCheckCollect(packet, obj, full_name, block_name, needCount, time, collectType)
    local handlerCollectCountFunc, getCollectKeyFunc = HANDLER_COLLECT_COUNT_FUNC[collectType], GET_COLLECT_KEY_FUNC[collectType]
    if not handlerCollectCountFunc or not getCollectKeyFunc then
        return false
    end
    local collectMap_collectType = collectMap[collectType]
    if not collectMap_collectType then
        return false
    end
    local key = getCollectKeyFunc(obj)
    local collectCount = handlerCollectCountFunc(obj, key, collectMap_collectType, full_name, block_name)
    local closeCountDown, updateCountDown
    if collectCount >= needCount then
        if not collectMap.countDownTimer then
            updateCountDown = true
            collectMap.countDownOwnerKey = key
            collectMap.countDownTimer = World.Timer(time * 20, function()
                checkGameOver(CONDITION_TYPE.COLLECT, true, true)
            end)
        end
        if not collectMap_collectType[key].finishTime or collectMap_collectType[key].finishTime < 0 then
            collectMap_collectType[key].finishTime = World.Now()
        end
    else
        collectMap_collectType[key].finishTime = -1
        if collectMap.countDownTimer and (collectMap.countDownOwnerKey == key) then
            collectMap.countDownTimer()
            local temp
            for k, info in pairs(collectMap_collectType) do
                if ((info.finishTime or -1) > 0) and (not temp or ((temp.finishTime > info.finishTime) and (info.collectCount >= needCount))) then
                    temp = {k = k, finishTime = info.finishTime}
                end
            end
            if temp then
                collectMap.countDownOwnerKey = temp.k
                collectMap.countDownTimer = World.Timer(time * 20, function()
                    checkGameOver(CONDITION_TYPE.COLLECT, true, true)
                end)
                updateCountDown = true
            else
                collectMap.countDownTimer = nil
                collectMap.countDownOwnerKey = nil
                closeCountDown = true
            end
        end
    end
    -- 根据 closeCountDown/updateCountDown 处理客户端头顶UI倒计时
    local packet = {
        pid = "ShowPropCollectCountDown",
        collectorsName = "",
        CountdownTime = time,
        autoCountDown = true,
        fromPCGameOverCondition = true
    }
    local getNameFunc = GET_COLLECT_COUNT_DOWN_NAME_FUNC[collectType]
    if getNameFunc then
        packet.collectorsName = getNameFunc(collectMap.countDownOwnerKey)
    end
    if updateCountDown then
        packet.isCancel = false
        WorldServer.BroadcastPacket(packet)
    elseif closeCountDown then
        packet.isCancel = true
        WorldServer.BroadcastPacket(packet)
    end

    -- 处理头顶数量，游戏开始就有，背包变化对应道具就更新
    local collectHeadUIFunc = COLLECT_HEAD_UI_FUNC[collectType]
    if collectHeadUIFunc then
        collectHeadUIFunc(obj, collectCount)
    end
    return false
end
function Game.gameOverConditionTypeFunc.COLLECT(packet)
    local collectConfig = pcGameOverCondition.collectConfig
    if not collectConfig then
        return false
    end
    local collectType, fullName, needCount, time = collectConfig.collectType, collectConfig.fullName, collectConfig.count, collectConfig.time
    if not collectType or not fullName or not needCount or not time then
        return false
    end
    local obj, item, force = packet.obj, packet.item, packet.force
    if not obj or not obj.isPlayer or (not item and not force) then
        return false
    end

    if item then
        local isBlockItem = item:is_block()
        if isBlockItem then
            if collectType ~= DEFINE_TYPE.block then
                return false
            end
            if item:block_name() ~= fullName then
                return false
            end
        elseif collectType == DEFINE_TYPE.block or (item:full_name() ~= fullName) then
            return false
        end
    end
    local block_name = collectType == DEFINE_TYPE.block and fullName or ""
    local full_name = collectType == DEFINE_TYPE.block and "/block" or fullName
    handlerCheckCollect(packet, obj, full_name, block_name, needCount, time, collectConfig.settlementType)
    return false
end

function Game.gameOverConditionTypeFunc.SCORE(packet, force, isGameOverWithPlayer)
    local scoreConfig = pcGameOverCondition.scoreConfig or {}
    if not force and not scoreConfig then
        return false
    end
    local obj = packet.obj
    if not obj or not obj.isPlayer then
        return false
    end
    local teamId = obj:getValue("teamId")
    local score = obj:data("main").score
    if isGameOverWithPlayer or scoreConfig.settlementType==DEFINE_TYPE.player or teamId == 0 then
        playerScore.player[obj.platformUserId] = score
        return score >= (scoreConfig.num or 0)
    end
    local teamScore = 0
    local playerScore_team = playerScore.team[teamId]
    if not playerScore_team then
        playerScore_team = {all = 0}
        playerScore.team[teamId] = playerScore_team
    end
    playerScore_team[obj.platformUserId] = score
    playerScore_team.all = 0
    for _, tempScore in pairs(playerScore_team) do
        teamScore = tempScore + teamScore
    end
    playerScore_team.all = teamScore
    return teamScore >= (scoreConfig.num or 0)
end


