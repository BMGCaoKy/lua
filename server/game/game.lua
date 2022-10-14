require "common.game"
require "game.game_exp"
require "game.game_team"
require "game.game_home"
require "game.game_stats"
require "game.game_exchange"
require "game.game_service"
require "game.game_over"

local PlayerDBMgr = T(Lib, "PlayerDBMgr") ---@type PlayerDBMgr
local debugport = require "common.debugport"

local follower_count = L("follower_count", 0) --好友跟随的人��
local player_count = L("player_count", 0)
local players = L("players", {})
local allPlayerInfos = L("allPlayerInfos", {})
local userId2ObjIdMap = L("userId2ObjIdMap", {})
local stateTimer = L("stateTimer")
local inited = L("inited", false)
local stateChangeCount = L("stateChangeCount", 0)
local _timer = L("_timer", {})
local gameTimer = L("gameTimer", 0)
local startGameTime = L("startGameTime", os.time())
local startGamePlayer = L("startGamePlayer", 0)
local isCloseServer = L("isCloseServer", false)
local audioDir = L("audioDir", "")
local isKeepAhead = L("isKeepAhead", false)
local gameName = World.GameName
local waitStopServerTimer = L("waitStopServerTimer")
local gameTimerTs = L("gameTimerTs", {})

local ActionPriceList = L("ActionPriceList", {})
local PlayerAuthList = L("PlayerAuthList", {})

function Game.GetGameMode()
    local gameMode = World.cfg.gameMode
    local serverTags =  World.CurWorld:getServerTags()
    if serverTags and serverTags.gameMode then
        gameMode = serverTags.gameMode
    end
    return gameMode
end

function Game.GetGamingPlayerCount()
    return player_count - follower_count
end

function Game.GetDiyConfig()
    if not World.cfg.gameModeConfig then
        return {}
    end
    local gameMode = Game.GetGameMode()
    if gameMode and not World.cfg.gameModeConfig[gameMode] then
        Lib.logInfo("can not find gameMode", gameMode)
        return {}
    end
    return World.cfg.gameModeConfig[gameMode]
end

function Game.GetGameTimerTs()
    return gameTimerTs
end

local function getMinPlayers()
    local diyConfig = Game.GetDiyConfig()
    local minPlayers = 0
    if diyConfig.team then
        for _, v in pairs(diyConfig.team) do
            if v.minPlayers then
                minPlayers = minPlayers + v.minPlayers
            end
        end
    end
    if minPlayers <= 0 then
        if not World.CurWorld.isEditorEnvironment then
            minPlayers = math.min(World.cfg.minPlayers or 8, World.cfg.maxPlayers or 8)
        else
            minPlayers = 1
        end
    end
    return minPlayers
end

function Game.TriggersAll(name)
    local allEntity = World.CurWorld:getAllEntity()
    for i, v in pairs(allEntity) do
        Trigger.CheckTriggersOnly(v:cfg(), name, { obj1 = v })
    end
    Trigger.CheckTriggers(nil, name)
end

local function SetStateAndTimer(state, time, func)
    gameTimerTs.stateChangeTs = os.time()
    if Game.GetState() ~= state then
        Game.SetState(state, gameTimerTs.stateChangeTs)
        WorldServer.BroadcastPacket({pid = "SetGameState", state = state, startTs=gameTimerTs.stateChangeTs})
    end
    stateChangeCount = stateChangeCount + 1
    print("Game set state", state, time, stateChangeCount)
    local stateCount = stateChangeCount
    if stateTimer then
        stateTimer()
        stateTimer = nil
    end
    Game.TriggersAll(state)
	collectgarbage()

    --trigger被业务定制，触发器有可能会调用Game.Ready或者其他状态，导致定时器更新
    --如果再注册定时器，会导致同时有两个状态定时器执行，游戏状态机就乱掉了  by (chen shuai .)
    if stateChangeCount ~= stateCount then
        return false
    end
    if func and time >= 0 then
        gameTimerTs.second = time / 20
        --帧计时会受卡顿影响，用秒计时更准
        stateTimer = World.Timer(10, function()
            if os.time() - gameTimerTs.stateChangeTs > gameTimerTs.second then
                func()
            else
                return true
            end
        end)
    end
    return true
end

function Game.SetStateAndTimer(state, time, func)
    SetStateAndTimer(state, time, func)
end

function Game.GetStartGamePlayerCount()
    return startGamePlayer
end

function Game.Full()
    local maxPlayer = World.cfg.maxPlayers or 8
    if Game.GetGamingPlayerCount() >= maxPlayer + (World.cfg.jumpPlayers or 0) then
        return true
    end
    return false
end

function Game.GetAudioDir()
    if string.len(audioDir) == 0 then
        audioDir = 'voice/' .. World.GameName .. '_' .. os.date("%Y%m%d%H%M%S", os.time()) .. '_' .. Lib.randomLetter(5)
    end
    return audioDir
end

local function sortPlayerRank(Condition, m_players)
    Condition = Condition or "score"
    local s_players = {}
    for _, player in pairs(m_players and m_players or players) do
        if not player:isWatch() then
            s_players[#s_players + 1] = player
        end
    end
    table.sort(s_players, function(a, b)
        if a:data("main")[tostring(Condition)] ~= b:data("main")[tostring(Condition)] then
            return (a:data("main")[tostring(Condition)] or 0) > (b:data("main")[tostring(Condition)] or 0)
        end
        return a.objID > b.objID
    end)
    return s_players
end

function Game.doReward(info)
    local _players = sortPlayerRank(info.condition, Game.GetAllPlayers())
    for r, p in pairs(_players) do
        RewardManager:addRewardQueue(p.platformUserId, r)
    end
    RewardManager:getQueueReward(function(data)
        Game.sendGameSettlement(info)
    end)
end

function Game.doReport(condition)
    local _players = sortPlayerRank(condition, Game.GetAllPlayers())
    for rank, player in pairs(_players) do
        ReportManager:reportUserData(player.platformUserId, player:data("main").kills, rank, 1)
    end
end

function Game.doRewardToPlayer(player, condition, isNextServer)
    local mainData = player:data("main")
    local time = mainData.inGameTime
    if not time then
        return
    end
    local userId = player.platformUserId
    RewardManager:getUserReward(userId, Game.GetPlayerRank(player, condition), function()
        local m_player = Game.GetPlayerByUserId(userId)
        if m_player then
            Game.sendPlayerSettlement(m_player, condition, isNextServer)
        end
    end, time, mainData.gameId)
end

function Game.doGoldRewardToPlay(player, golds, condition, isNextServer)
    local userId = player.platformUserId
    RewardManager:getUserGoldReward(userId, math.ceil(golds), function()
        local player = Game.GetPlayerByUserId(userId)
        if player then
            Game.sendPlayerSettlement(player, condition, isNextServer)
        end
    end)
end

function Game.doReportToPlayer(player, condition, iscount)
    local mainData = player:data("main")
    local isCount = Game.GetState() == "GAME_OVER" and 1 or 0
    ReportManager:reportUserData(player.platformUserId, mainData.kills, Game.GetPlayerRank(player, condition), iscount or isCount)
end

local function sendSettlement(player, result, isNextServer)
    Trigger.CheckTriggers(player:cfg(), "ENTITY_SENDSETTLEMENT", { obj1 = player })
    player:sendPacket({
        pid = "ShowSettlement",
        result = result,
        isNextServer = isNextServer
    })
end

local function sendTipToPlayers(tipType, textKey, keepTime, vars)
    WorldServer.BroadcastPacket({
        pid = "ShowTip",
        tipType = tipType,
        keepTime = keepTime,
        textKey = textKey,
        vars = vars,
        textArgs = {},
    })
end

local function ShowTipTimer(tTime, tipType, GameState, state)
    if tTime <= 20 then
        return
    end
    local time = tTime
    local vars = {
        var = time,
        nowTime = os.time(),
        nowWorldTime = World.CurWorld:getWorldTime()
    }
    sendTipToPlayers(tipType, GameState, nil, vars)
    if _timer[state] then
        _timer[state]()
        _timer[state] = nil
    end
    local function tick()
        time = time - 1
        _timer[state..".time"] = time
        if time <= 0 then
            _timer[state] = nil
            _timer[state..".time"] = 0
            _timer[state..".key"] = ""
            return false
        end
        return true
    end
    _timer[state..".key"] = GameState
    _timer[state] = World.Timer(1, tick)
end

function Game.sendTipToPlayers(tTime, tipType, GameState, state)
    ShowTipTimer(tTime, tipType, GameState, state)
end

local function trySendGameTipToPlayer(player, g_state)
    if _timer[g_state..".time"] and _timer[g_state..".time"] > 0 then
        local vars = {
            var = _timer[g_state..".time"],
            nowTime = os.time(),
        }
        player:sendTip(3, _timer[g_state..".key"], nil, vars)
    end
end

local function GetWaitPlayerTime()
	return math.max(World.cfg.waitPlayerTime or 0, 60)
end

--[[
    对超过多久没ping过来的客户端认定为断开连接但是踢出失败，强制踢掉。
    暂定为5分钟。即：20*60*5
]]
local maxLosePingTick = World.cfg.maxLosePingTick or 20*60*5
local function checkAllPlayerOnline()
    if Game.GetState() ~= "GAME_GO" then
        return true
    end
    local now = World.Now()
    local c_server = Server.CurServer
    for i, player in pairs(Game.GetAllPlayers() or {}) do
        if ((player.clientPingTick or 0) + maxLosePingTick) < now then
            if players[player.objID] then
                players[player.objID] = nil
                player_count = player_count - 1
                if player:isWatch() then
                    follower_count = follower_count - 1
                end
            end
            Lib.logInfo("[checkAllPlayerOnline - player ping lose !]", "PlayerCount=" .. player_count, "FollowerCount=" .. follower_count, 
                "dispatchReqId=" .. player.dispatchReqId, "UserId=" .. tostring(player.platformUserId))
            c_server:sendUserOut2Room(player.platformUserId, player.dispatchReqId)
            Game.KickOutPlayer(player, "player ping lose !")
            player:destroy()
        end
    end
    if player_count <= 0 then
        local waitStopServerTime = World.cfg.waitStopServerTime
        if waitStopServerTime then
            waitStopServerTimer = World.Timer(waitStopServerTime, Game.StopServer)
        else
            Game.StopServer()
        end
    end
    return true
end

function Game.Init()
	math.randomseed(os.time())
    Rank.Init()
    gameTimer = 0
    stateChangeCount = 0
	if not World.isGameServer then
		return
	end
    AsyncProcess.GetBlockmodsExpRule()
    AsyncProcess.GetGamePlayerAuthList()
    AsyncProcess.GetSensitiveWordConfig()
    World.Timer(20, Game.updatePlayerGameTime)
    World.Timer(20, Game.tickTrySaveExpResult)
    World.Timer(20, ReportManager.tryReportGameData, ReportManager)
    local waitPlayerTime = GetWaitPlayerTime()
    if not SetStateAndTimer("GAME_INIT", waitPlayerTime, Game.WaitPlayerOnTick) then
        return
    end
    if not World.cfg.noShowWaitPlayerTip then
        ShowTipTimer(waitPlayerTime, 3, "game.init", "GAME_INIT")
    end
    World.Timer(20*60, checkAllPlayerOnline)


    Game.InitPacketStat()
end

function Game.InitPacketStat()
    if World.cfg.enablePacketStat then
        World.EnablePacketCount(true)
    else
        World.EnablePacketCount(false)
    end
end

function Game.LogPacketStatIfEnable()
    if World.cfg.enablePacketStat then
         World.ShowPacketCount()
         Server.CurServer:printPacketStat()
    end
end

function Game.WaitPlayerOnTick()
    if Game.GetGamingPlayerCount() < getMinPlayers() then
        Game.ReWaitPlayerOnTick()
    else
        Game.Ready()
    end
end

function Game.ReWaitPlayerOnTick()
    local waitPlayerTime = GetWaitPlayerTime()
    stateChangeCount = stateChangeCount - 1
    if not SetStateAndTimer("GAME_REWAIT", waitPlayerTime, Game.WaitPlayerOnTick) then
        return
    end
    if not World.cfg.noShowRewaitPlayerTip then
        ShowTipTimer(waitPlayerTime, 3, "game.init", "GAME_REWAIT")
    end
end

--自动分配阵营
function Game.AutoAssignTeam()
    local diyConfig = Game.GetDiyConfig()
    local teamCfg = diyConfig.team or World.cfg.team
    local minTeamNum, teamId, memberLimit = nil, nil, nil
    for _, player in pairs(players) do
        local team = Game.GetTeam(player:getValue("teamId"))
        if team then
            team:leaveEntity(player)
        end
    end
    for _, player in pairs(players) do
        if not player:isWatch() then
            Game.TryJoinTeamByPlayer(player)
        end
    end
end

--选阵营按理说紧接着选职业，但是职业可以通过valueFunc实现
--业务自己决定要不要选职业，同时调整等待时间即可
function Game.AssignTeam()
    if World.cfg.needWaitPlayerReady then
        local kickOutList = {}
        for _, player in pairs(Game.GetAllPlayers()) do
            if not player:data("main").isReadyForAssignTeam then
                table.insert(kickOutList, player)
            end
        end
        if next(kickOutList) then
            for _, player in pairs(kickOutList) do
                Game.KickOutPlayer(player, "not_ready_for_assign_team")
            end
            Game.WaitPlayerOnTick()
            return
        end
    end

    if World.cfg.needAssignTeam then
        ----倒计时x秒后启动游戏，这期间给玩家选择职业...在ValueFunc:teamId()中打开职业选择UI...
        local waitTeamTime = World.cfg.waitTeamTime or 40
        SetStateAndTimer("GAME_AUTO_ASSIGN_TEAM", waitTeamTime, Game.Start)
        ShowTipTimer(waitTeamTime, 3, "game.auto.start", "GAME_AUTO_ASSIGN_TEAM")
        Game.AutoAssignTeam()
    else
        SetStateAndTimer("GAME_AUTO_ASSIGN_TEAM", 0, Game.Start)
    end
end

function Game.WaitPlayerReady()
    if World.cfg.needWaitPlayerReady then
        local waitPlayerReadyTime = World.cfg.waitPlayerReadyTime or 40
        SetStateAndTimer("GAME_WAIT_PLAYER_READY", waitPlayerReadyTime, Game.AssignTeam)
        ShowTipTimer(waitPlayerReadyTime, 3, "game.wait.player.ready", "GAME_WAIT_PLAYER_READY")
    else
        SetStateAndTimer("GAME_WAIT_PLAYER_READY", 0, Game.AssignTeam)
    end
end

function Game.Ready()
    --todo stopLogin
    local waitStartTime = World.cfg.waitStartTime or 40
    if not SetStateAndTimer("GAME_READY", waitStartTime, Game.WaitPlayerReady) then
        return
    end
    if waitStartTime >= 20 and not World.cfg.noReadyTip then
        ShowTipTimer(waitStartTime, 3, "game.ready", "GAME_READY")
    end
end

function Game.Start()
    RewardManager:startGame()
    local cfg = World.cfg
    if not Game.CheckCanJoinMidway() then
        Game.SendStartGame()
    end
    local waitGoTime = cfg.waitGoTime or 40
    local isEditorEnvironment = World.CurWorld.isEditorEnvironment
    if isEditorEnvironment then
        waitGoTime = 0
    end
    for i, v in pairs(players) do
        if v:isWatch() then goto NextPlayer end
        local pos = v:getStartPos(not (World.cfg.ignoreEmptyStartPos == false))
        if pos then
            if pos.map then
                v:setMapPos(pos.map, pos)
            else
                v:setPos(pos)
            end
        end
        local waitStartBuff = v:data("main").waitStartBuff
        if waitStartBuff then
            v:removeBuff(waitStartBuff)
        end
        ::NextPlayer::
    end
    ShowTipTimer(waitGoTime, 3, "game.waitGo", "GAME_START")
    SetStateAndTimer("GAME_START", waitGoTime, Game.Go)
    MapPatchMgr.ForceUpdateObjectChangeTimer()
end

function Game.Go()
    startGameTime = os.time()
    startGamePlayer = Game.GetGamingPlayerCount()
    local playTime = World.cfg.playTime or -1
    for i, v in pairs(players) do
        v:timer(20, v.secondTimer, v)
    end
    SetStateAndTimer("GAME_GO", playTime, Game.TimeEnd)
    ShowTipTimer(playTime, 5, "game.playTime", "GAME_GO")
    World.Timer(20, Game.Update)
end

function Game.Update()
    local playTime = World.cfg.playTime or 200
    gameTimer = gameTimer + 1
    if (playTime >= 0 and gameTimer * 20 >= playTime) or Game.GetState() == "GAME_OVER" then
        return false
    end
    Game.SpawnItem()
    Trigger.CheckTriggers(nil, "GAME_UPDATE")
    -- todo 正式游戏开始�?�时.......
    return true
end

function Game.GetGameTime()
    return gameTimer * 20
end

local function getPlaySettlementInfo(player, Condition, iswin)
    local item = {}
    item.userId = player.platformUserId
    item.name = player.name
    item.rank = Game.GetPlayerRank(player, Condition)
    if item.rank == 1 then
        item.iswin = 1
    else
        item.iswin = 0
    end
    if iswin then
        item.iswin = 1
    end
    item.gold = player:data("main").gold or 0
    item.hasGet = player:data("main").hasGet or 0
    item.available = player:data("main").available or 0
    item.vip = player:data("mainInfo").vip or 0
    return item
end

function Game.sendGameSettlement(info)
    local result = {}
    result.own = {}
    result.players = {}
    local condition = info.condition
    local m_players = sortPlayerRank(condition)
    if #m_players == 0 then
        return
    end
    local winTeamID = Game.GetPlayerInfo(m_players[1]).teamID
    for i, player in pairs(m_players) do
        local teamID = Game.GetPlayerInfo(player).teamID
        local isWin = winTeamID ~= 0 and teamID ~= 0 and winTeamID == teamID
        local item = getPlaySettlementInfo(player, condition, isWin)
        result.players[#result.players + 1] = item
    end
    for i, player in pairs(m_players) do
        local teamID = Game.GetPlayerInfo(player).teamID
        local isWin = winTeamID ~= 0 and teamID ~= 0 and winTeamID == teamID
        local item = getPlaySettlementInfo(player, condition, isWin)
        result.own = item
        sendSettlement(player, result, info.isNextServer)
    end
end

function Game.sendPlayerSettlement(m_player, Condition, isNextServer)
    local rankInfo = getPlaySettlementInfo(m_player, Condition)
    Trigger.CheckTriggers(m_player:cfg(), "ENTITY_DEAD_SUMMARY", {obj1 = m_player, condition = Condition, isNextServer = isNextServer, rankInfo = rankInfo})
end

function Game.GameOverToPlayer(player)
    Trigger.CheckTriggers(player:cfg(), "ENTITY_GAMEOVER", { obj1 = player })
end

function Game.GetPlayerRank(player, Condition)
    local m_players = sortPlayerRank(Condition)
    local rank = 0
    for i, v in ipairs(m_players) do
        rank = rank + 1
        if v.platformUserId == player.platformUserId then
            return rank
        end
    end
    return rank
end

function Game.TimeEnd()
    Game.GameOverConditionAtGameOver()
    Game.Over()
end

function Game.Over()
    local reportTime = World.cfg.reportTime or 60
    local ret
    if World.cfg.replay then
        ret = SetStateAndTimer("GAME_OVER", reportTime, Game.Replay)
        ShowTipTimer(reportTime, 3, "", "GAME_OVER")
    else
        ret = SetStateAndTimer("GAME_OVER", reportTime, Game.QuitServer)
        ShowTipTimer(reportTime, 3, "game.closeServer", "GAME_OVER")
    end
    if not ret then
        return
    end
end

function Game.Replay()
    for _, player in pairs(players) do
        if not player:isWatch() then
            player:data("main").rebirthPos = nil
            player:serverRebirth()
        end
    end
    local gamingCount = Game.GetGamingPlayerCount()
    if gamingCount >= getMinPlayers() or (World.cfg.replayInitHadPlayer and gamingCount > 0) then
        if not Game.CheckCanJoinMidway() then
            Game.SendResetGame()
        end
        Game.Init()
    else
        Game.QuitServer()
    end
end

---@param player EntityServerPlayer
function Game.ShowInfoPanel(player, tipID, isKick)
    player:sendPacket({
        pid = "ShowInfoPanel",
        tipID = tipID,
        isKick = isKick,
    })
end

---@param player EntityServerPlayer
function Game.CheckCanJoin(player)
    local state = Game.GetState()
    local message = "game.startAlready"
    if not state or state == "GAME_OVER" or state == "GAME_EXIT" or Game.Full() then
        message = "game.full"
    elseif state == "GAME_INIT" or state == "GAME_REWAIT" or state == "GAME_READY" then
        return true
    elseif Game.CheckCanJoinMidway() then	-- GAME_START or GAME_GO
        return true
    end
    Lib.logInfo("Game.CheckCanJoin game status is " .. tostring(state) .. ", kick player:" .. message)
    Game.KickOutPlayer(player, message)
    return false
end

---@param player EntityServerPlayer
function Game.SendGameInfo(player)
	local world = World.CurWorld
	local map = assert(player.map, player.objID)
    local regId = player:regCallBack("uiNavigation", {key = "UI_NAVIGATION"}, false, true )

    player:sendPacket({ pid = "SyncPlayerName", name = player.name })
	local packet = {
        pid = "GameInfo",
		cfgName = player:cfg().fullName,
		objID = player.objID,
		map = {
			id = map.id,
			name = map.name,
			static = map.static,
		},
		mapChunkData = MapChunkMgr.getMapChunkWithLocal(map),
		pos = player:getPosition(),
		isTimeStopped = world:isTimeStopped(),
		worldTime = world:getWorldTime(),
		maxPlayer = 8,
		actorName = player:data("main").actorName,
		skin = player:data("skin"),
		debugport = debugport.port,
		gameState = Game.GetState(),
        startTs = Game.GetStateStartTs(),
        playersInfo = Game.GetAllPlayerInfos(),
        teamsInfo = Game.GetAllTeamsInfo(),
        navRegId = regId,
        audioDir = Game.GetAudioDir(),
        targetId = player:getTargetId(),
        mode = player:getMode(),
        isGameParty = Server.CurServer:isGameParty(),
        gameMode = Game.GetGameMode(),
        isEditorServerEnvironment = World.isEditorServer,
        isShowErrorLog = Game.HasShowErrorPermission(player.platformUserId),
        raknetID = player:getRaknetID(),
	    instanceId = player:getInstanceID()
	}
    packet.pos.yaw = player:getRotationYaw()
    packet.pos.pitch = player:getRotationPitch()
	player:sendPacket(packet)
end

function Game.OnPlayerLoginForEditor(player)
end

local function setLoginPlayerPos(player)
    if World.CurWorld.isEditorEnvironment or player:isWatch() then
        return
    end
    local World_cfg = World.cfg
    local pos
    if World_cfg.waitAtInitPos then
        pos = player:getInitPos()
    elseif World_cfg.waitAtStartPos then
        pos = player:getStartPos(not (World_cfg.ignoreEmptyStartPos == false))
    end
    if pos then
        player:setMapPos(pos.map or player.map or World_cfg.defaultMap, pos)
    end
end

---@param player EntityServerPlayer
function Game.OnPlayerLogin(player)
    player.logicPingCount=0
	if not Game.CheckCanJoin(player) then
		return	-- double check
	end
    trySendGameTipToPlayer(player, Game.GetState())
    players[player.objID] = player
    userId2ObjIdMap[player.platformUserId] = player.objID
    player_count = player_count + 1
    table.insert(Game.savingList, player.objID)
    player.clientPingTick = World.Now()

    if player:isWatch() then
        follower_count = follower_count + 1
    end
    Lib.logInfo("[Game.OnPlayerLogin]",
            "PlayerCount=" .. player_count,
            "FollowerCount=" .. follower_count,
            "UserId=" .. tostring(player.platformUserId))
    Game.TryJoinTeamBySystem(player)

    setLoginPlayerPos(player)

	local waitStartBuff = World.cfg.waitStartBuff
	if waitStartBuff and Game.IsWaitingState() then
		player:data("main").waitStartBuff = player:addBuff(waitStartBuff)
	end
    if waitStopServerTimer then
        waitStopServerTimer()
        waitStopServerTimer = nil
    end
    if Game.Full() and Game.GetState() == "GAME_INIT" then
        Game.Ready()
    end
	-------------------------------------------
	local userId = player.platformUserId
	Game.getUserExpCache(userId)

    GameAnalytics.OnPlayerLogin(player, player.clientInfo)
    Trigger.CheckTriggers(player:cfg(), "ENTITY_ENTER", {obj1=player})
    Event:EmitEvent("OnEntityAdded", player)
    local playerInfo = Game.GetPlayerInfo(player)

	WorldServer.BroadcastPacket({pid = "OnPlayerLogin", playerInfo = playerInfo})

    local followEnterType = player:getPlayerAttrInfo().mainInfo.followEnterType
    if followEnterType == 1 then --加入游戏成功
        GameAnalytics.Design(player.platformUserId , nil, {"follow_game_enter_suc"})
    end

    if ATProxy.isReady then
        ATProxy.Instance():sendToCenter({
            pid = "PlayerEnter",
            id = player.platformUserId,
            name = player.name,
            data = player:viewEntityInfo("centerInfo"),
        })
    end

    local packet = {
        pid = "SyncActionPriceList",
        actionList = ActionPriceList,
    }
    player:sendPacket(packet)

	player:bhvLog("login", string.format("%s login from %s", player.name, player.clientAddr))

    Plugins.CallPluginFunc("OnPlayerLogin", player)
    Game.OnPlayerLoginForEditor(player)
    Game.GameOverConditionAtLogin(player)

    Lib.XPcall(function()
        Lib.emitEvent(Event.EVENT_PLAYER_LOGIN, player)
        Event:EmitEvent("OnPlayerLogin", player)
    end, "Game.OnPlayerLogin->Event:EVENT_PLAYER_LOGIN")
end

function Game.OnPlayerLogoutForEditor(playerId)
end

function Game.KickOutTargetPlayerWatcher(target)
    local objID = target.objID
    for _, v in pairs(players) do
        if v:getTargetId() == objID and v:isWatch() then
            Game.ShowInfoPanel(v, "user_follow_target_logout")
            Server.CurServer:kickOut(v.platformUserId)
        end
    end
end

---@param player EntityServerPlayer
function Game.OnPlayerLogout(player)
    print("debug monitor  on player logout", player.platformUserId)
    Game.OnPlayerLogoutForEditor(player)
    Game.GameOverConditionAtLogout(player)
	if player.home then
		player.home:saveData()
		player.home:free()
	end

    if player.saveDataTimer then
        player.saveDataTimer()
    end
    
	local team = player:getTeam()
	if team then
		team:leaveEntity(player)
    end

	Trade.playerLogout(player)
	local objID = player.objID
	if players[objID] then
        print("debug monitor  find players ", player.platformUserId)
		local userId = player.platformUserId

		WorldServer.BroadcastPacket({ pid = "OnPlayerLogout", objID = objID })
        if ATProxy.isReady then
            ATProxy.Instance():sendToCenter({ pid = "PlayerLeave", id = userId })
        end
        Lib.XPcall(function()
            print("debug monitor  on player logout", objID)
            Trigger.CheckTriggers(player:cfg(), "ENTITY_LEAVE", {obj1=player, oldTeam = team and team.id or 0})
            Event:EmitEvent("OnEntityRemoved", player)
        end, "Game.OnPlayerLogout->Trigger:ENTITY_LEAVE")
        GameAnalytics.PlayerPerformanceReport(player)
		GameAnalytics.OnPlayerLogout(userId)
		Game.removeExpCache(userId)

        Lib.XPcall(function()
            print("debug event  on player logout", objID)
            Lib.emitEvent(Event.EVENT_PLAYER_LOGOUT, userId)
            Event:EmitEvent("OnPlayerLogout", player)
        end, "Game.OnPlayerLogout->Event:EVENT_PLAYER_LOGOUT")

		player:bhvLog("logout", string.format("%s logout", player.name))
    else
        print("debug monitor can't find player", objID, Lib.v2s(players, 1))
	end

    for _, cancelFunc in pairs(player:data("logoutDestroyTimer") or {}) do
        if cancelFunc then
            cancelFunc()
        end
    end

    Game.KickOutTargetPlayerWatcher(player)
end

---@param player EntityServerPlayer
function Game.RemoveLogoutPlayer(player)
    if not player:isValid() then
        return
    end
    local objID = player.objID
    Game.RemovePlayerInfo(objID)
    local avgLogicPingTime = 0
    if  player.logicPingCount and player.logicPingCount > 0   then
        avgLogicPingTime = math.floor(player.logicPingTotalTime / player.logicPingCount)
    end
    if not players[objID] then
        Server.CurServer:sendUserOut2Room(player.platformUserId, player.dispatchReqId, player.clientAddr or "", avgLogicPingTime, player.packetLoss or 0)
        player:destroy()
        return
    end
    userId2ObjIdMap[player.platformUserId] = nil
    players[objID] = nil
    player_count = player_count - 1
    if player:isWatch() then
        follower_count = follower_count - 1
    end
    Lib.logInfo("[Game.RemoveLogoutPlayer]",
            "PlayerCount=" .. player_count,
            "FollowerCount=" .. follower_count,
            "dispatchReqId=" .. player.dispatchReqId,
            "UserId=" .. tostring(player.platformUserId))
    Server.CurServer:sendUserOut2Room(player.platformUserId, player.dispatchReqId, player.clientAddr or "", avgLogicPingTime, player.packetLoss or 0)
    player:destroy()
	if player_count <= 0 then
        local waitStopServerTime = World.cfg.waitStopServerTime
        if waitStopServerTime then
            waitStopServerTimer = World.Timer(waitStopServerTime, Game.StopServer)
        else
            Game.StopServer()
        end
	end
end

---@param player EntityServerPlayer
function Game.OnPlayerReconnect(player)
	trySendGameTipToPlayer(player, Game.GetState())

	local objID = player.objID
	if players[objID] then
		WorldServer.BroadcastPacket({ pid = "OnPlayerReconnect", objID = objID })
		Trigger.CheckTriggers(player:cfg(), "ENTITY_RECONNECT", {obj1=player})
        Event:EmitEvent("OnPlayerReconnect", player)
	end
end

local function init()
    if not inited then
        inited = true
        World.Timer(1, Game.Init)
        if not World.cfg.notAutoSave then
            World.Timer(4, function()
                Game.AutoSavePlayer()
                return true
            end)
        end
    end
end

Game.savingList = Game.savingList or {}
Game.saveIndex = Game.saveIndex or 0
function Game.AutoSavePlayer()
    local total = #Game.savingList
    if total <= 0 then
        return
    end

    Game.saveIndex = Game.saveIndex % total + 1
    local objId = Game.savingList[Game.saveIndex]
    local player = players[objId]

    if not player then
        table.remove(Game.savingList, Game.saveIndex)
        Game.saveIndex = Game.saveIndex - 1
        return
    end

    local now = os.time()
    if now - (player.nLastSaveTime or 0) < (World.cfg.savePlayerDataInterval or 1200) / 20 then
        return
    end
    player.nLastSaveTime = now

    PlayerDBMgr.SaveImmediate(player)
end

---@return table<number, EntityServerPlayer>
function Game.GetAllPlayers()
    return players
end

function Game.GetPlayerInfo(player)
    return allPlayerInfos[player.objID] or Game.UpdatePlayerInfo(player)
end

function Game.UpdatePlayerInfo(player)
    local objId = player.objID
    allPlayerInfos[objId] = {
        objID = objId,
        name = player.name,
        userId = player.platformUserId,
        teamID = player:getValue("teamId"),
        joinTeamTime = player:getValue("joinTeamTime"),
        isFollowMode = player:isWatch(),
    }
    return allPlayerInfos[objId]
end

function Game.RemovePlayerInfo(playerObjId)
    allPlayerInfos[playerObjId] = nil
end

function Game.GetAllPlayerInfos()
    return allPlayerInfos
end

---@return EntityServerPlayer | nil
function Game.GetPlayerByUserId(userId)
    local objId = userId2ObjIdMap[userId] or -1
    return players[objId]
end

function Game.GetAllPlayersCount()
    return player_count
end

function Game.GetSurvivePlayers()
    local tb = {}
    for i, v in pairs(players) do
        if v:isDead() ~= true and not v:isWatch() then
            tb[i] = v
        end
    end
    return tb
end

function Game.GetSurvivePlayersCount()
    local count = 0
    for i, v in pairs(players) do
        if v:isDead() ~= true and not v:isWatch() then
            count = count + 1
        end
    end
    return count
end

function Game.RandomTable(_table, num, isrepeat)
    num = num or 0
    local res = {}
    local t = {}
    assert(type(_table) == "table")
    for i, v in pairs(_table) do
        t[#t + 1] = v
    end
    if num >= 1 then
        for i = 1, num do
            local index = math.random(1, #t)
            res[#res + 1] = t[index]
            if not isrepeat then
                table.remove(t, index)
            end
        end
        return res
    end
    res = nil
    local index = math.random(1, #t)
    res = t[index]
    assert(res)
    return res
end

function Game.RandomSurvivePlayer()
    local tb = Game.GetSurvivePlayers()
    local res = nil
    local t = {}
    assert(type(tb) == "table")
    for i, v in pairs(tb) do
        t[#t + 1] = v
    end
    local index = math.random(1, #t)
    res = t[index]
    assert(res)
    return res
end

function Game.SpawnItem()
    local spawnItems = World.cfg.RespawnItemToWorld
    if not spawnItems then
        return
    end
    if #spawnItems <= 0 then
        return
    end
    for i, v in pairs(spawnItems) do
        if v.fullName and v.interval then
            if Game.GetGameTime() % v.interval ~= 0 then
                return
            end
            for j, p in pairs(v.pos) do
                local item = Item.CreateItem(v.fullName, v.count or 20)
                DropItemServer.Create({
                    map = v.map, pos = p, item = item, lifeTime = v.time
                })
            end
        end
    end
end

function Game.StopServer(message)
    if World.CurWorld.isEditorEnvironment then
        for _, player in pairs(players) do
            player:sendPacket({pid = "EnterEditorMode"})
        end
        return
    end

    Game.LogPacketStatIfEnable()

    local server = Server.CurServer
    SetStateAndTimer("GAME_EXIT", 20 * 10, function ()
        isCloseServer = true
        World.Timer(20, function()
            if not os.getenv("startFromWorldEditor") and player_count > 0 then -- os.getenv("startFromWorldEditor"): 编辑器打开的测试环境的服务器，不需要判断玩家数量，关了就直接关。
                return true
            end
            server:disconnectRoom()
            server:stop()
        end)
    end)
    for i, v in pairs(players) do
		if message then
			Game.ShowInfoPanel(v, message)
		end
        server:kickOut(v.platformUserId)
    end
	server:setServerQuitSign(true)
    server:sendStartGame(0)
    MapPatchMgr.ForceUpdateObjectChange()
end

function Game.QuitServer(message)
    local server = Server.CurServer
    server:setServerQuitSign(true)
    server:sendQuitGame(Game.GetGamingPlayerCount())

    Game.ServerQuitting()
end

local STATIC_TIP_TIMESTAMP = {
    {time = 1, tipType = 1, msg = "system.message.close.server.tip.1s", keepTime = 60},
    {time = 30, tipType = 1, msg = "system.message.close.server.tip.30s", keepTime = 60},
    {time = 50, tipType = 1, msg = "system.message.close.server.tip.50s", keepTime = 60}
}
local isServerQuitting = false
function Game.ServerQuitting()
    if isServerQuitting then
        return
    end
    isServerQuitting = true
    -- send tip
    local l_tts = World.cfg.serverQuittingTipTimestamp or STATIC_TIP_TIMESTAMP
    for _, msgTb in pairs(l_tts) do
        World.Timer(tonumber(msgTb.time) * 20, function() sendTipToPlayers(msgTb.tipType, msgTb.msg, msgTb.keepTime, msgTb.vars) end)
    end

    -- stop server , room will close server after x second (server stop)
    World.Timer((World.cfg.serverQuittingTime or 60) * 20, function()
        Game.StopServer()
    end)

    -- todo ex
	Trigger.CheckTriggers(nil, "GAME_QUITTING", {})
end

function Game.IsCloseServer()
    return isCloseServer
end

function Game.Pause(player, state)
    World.CurWorld:setGamePause(state)
    local packet = {
        pid = "PauseGame",
        state = state
    }
    player:sendPacket(packet)
end

function Game.KickOutPlayer(entity, message)
    local server = Server.CurServer
    if entity then
        Game.ShowInfoPanel(entity, message or "gui.message.network.connection.kick.out", true)
        World.Timer(1, server.kickOut, server, entity.platformUserId)
    end
end

function Game.SendStartGame()
    Server.CurServer:sendStartGame(Game.GetGamingPlayerCount())
end

function Game.SendResetGame()
    Server.CurServer:sendResetGame(Game.GetGamingPlayerCount())
end

function Game.GetWinnerPlayer(condition)
    local winner = nil
    local _players = sortPlayerRank(condition)
    if #_players > 0 then
        winner = _players[1]
    end
    return winner
end

function Game.ReqNextGame(player)
    player:setValue("reqNextGame", true)

    for _, p in pairs(Game.GetAllPlayers()) do
        if p:getValue("reqNextGame") == false then 
            return
        end
    end
    Game.TriggersAll("NEXT_GAME")
end

function Game.OnStop()
	if not World.gameCfg.disableSave and World.cfg.needSave then
		for _, player in pairs(players) do
			print("save player", player.platformUserId, player.name)
            PlayerDBMgr.SaveImmediate(player)
		end
    end
    AsyncProcess.DeleteAudioDir()
end

function Game.OnSyncActionPriceList(actionId, price, currency, buyId)
    if not actionId then
        return
    end

    local ActionInfo = {}
    ActionInfo.actionId = actionId
    ActionInfo.price = price
    ActionInfo.currency = currency
    ActionInfo.buyId = buyId
    ActionPriceList[actionId] = ActionInfo
end

function Game.Exit(player)
    if player and player.isPlayer and player:isValid() then
        player:sendPacket({
            pid = "ExitGame"
        })
    return
    end
    perror("No player found", traceback())
end

function Game.SetPlayerAuthList(data)
    PlayerAuthList = data or {}
end

function Game.HasGMPermission(userId)
    for _ ,v in ipairs(PlayerAuthList.gm_ids or {}) do
        if v == userId then
            return true
        end
    end
    return false
end

function Game.HasShowErrorPermission(userId)

    if World.CurWorld and World.CurWorld:getNeedShowLuaErrorMessage() then
        return true
    end

    for _, v in ipairs(PlayerAuthList.error_log_ids or {}) do
        if v == userId then
            return true
        end
    end

    return false
end

function Game.IsDebug()
    local roomGameConfig = Server.CurServer:getConfig()
    return RoomGameConfig.isDebug
end




init()

RETURN()
