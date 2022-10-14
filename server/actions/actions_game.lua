local BehaviorTree = require("common.behaviortree")
local MapEffectMgr = require "server.world.map_effect_mgr"
local setting = require "common.setting"
local Actions = BehaviorTree.Actions
require "world.world"

function Actions.KillEntity(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    entity:kill(params.from, params.cause or "ACTIONS_KILL_ENTITY")
end

function Actions.IsEntityAlive(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    return entity.curHp > 0
end

local function startTimerRun(params)
    local obj = params.object
	-- todo:参数还原
    params.obj1 = obj
    Trigger.CheckTriggers(obj and obj:cfg(), params.event, params)
    return params.rep
end


function Actions.CallTrigger(data, params, context)
    local obj = params.object or params.obj1
    if obj then
        params.object = nil
        params.obj1 = obj
    end
    return Trigger.CheckTriggers(obj and obj:cfg(), params.event, params)
end

function Actions.WorldNow(data,params,context)
    return World.Now()
end

function Actions.CreateNpc(data, params, context)
    if ActionsLib.isEmptyString(params.cfgName, "Npc") then
        return nil
    end
    local entity = EntityServer.Create(params)
	return entity
end

function Actions.startAI(data, params, context)
    local entity = params.entity
    entity:startAI()
end

function Actions.CreateNpcInArea(data, params, context)
    local NpcCfg, region = params.cfgName, params.region
    if ActionsLib.isEmptyString(NpcCfg, "Npc") then
        return
    end
    local minNumber, maxNumber = params.minNumber, params.maxNumber
    if ActionsLib.isInvalidRange(minNumber, maxNumber) or ActionsLib.isInvalidRegion(region) then
        return
    end
    local mathrand,ceil = math.random,math.ceil
    local number = mathrand(minNumber,maxNumber)
    local minPos, maxPos = region.min, region.max
    local maxPosX, maxPosY, maxPosZ = maxPos.x, maxPos.y, maxPos.z
    local minPosX, minPosY, minPosZ = minPos.x, minPos.y, minPos.z
	for i = 1,number do
		params.pos = Lib.v3(mathrand(ceil(minPosX), ceil(maxPosX)), mathrand(ceil(minPosY), ceil(maxPosY)), mathrand(ceil(minPosZ), ceil(maxPosZ)))
		EntityServer.Create(params)
	end
end

function Actions.MoveAllPlayers(data, params, context)
    local entity, region = params.entity, params.region
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isInvalidRegion(region) then
        return
    end
    local minPos, maxPos = region.min, region.max
    local maxPosX, maxPosY, maxPosZ = maxPos.x, maxPos.y, maxPos.z
    local minPosX, minPosY, minPosZ = minPos.x, minPos.y, minPos.z
    local movetopos = Lib.v3(math.random(minPosX, maxPosX), math.random(minPosY, maxPosY), math.random(minPosZ, maxPosZ))
    entity:setPos(movetopos)
end

function Actions.GetBlockFromPos(data, params, context)
    local block = World.CurWorld:getMap(params.map):getBlock(params.pos)
    return block[params.key]
end

function Actions.RemoveBlock(data, params, context)
	World.CurWorld:getMap(params.map):removeBlock(params.block)
end

function Actions.ShowMerchantShop(data, params, content)
    params.entity:sendPacket({
        pid = "ShowMerchantShop",
        showType = params.showType,
        showTitle = params.showTitle
    })
end

function Actions.ShowShop(data, params, content)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    entity:sendPacket({
        pid = "ShowShop",
        showType = params.showType,
        showGroup = params.showGroup,
    })
end

function Actions.ShowUpgradeShop(data, params, context)
	params.entity:sendPacket({
        pid = "ShowUpgradeShop"
    })
end

function Actions.ShowPersonalInformations(data, params, context)
    if params.target then
        params.player:sendPacket({
            pid = "ShowPersonalInformations",
            objID = params.target.objID
        })
    end
end

function Actions.GameOver(data,params,context)
    Game.Over()
end

function Actions.RewardVersionOne(data, params, context)
    local use_reward = {}
    local weight = 0
    local filecfg = Lib.readGameJson("plugin/"..params.path..".json")
    for i, v in ipairs(filecfg.distribution) do
        local save_reward = {}
        if v.weight ~= 0 then
            local array = {}
            array[1] = v.name
            array[2] = v.weight
            array[3] = v.identity
            array[4] = weight -- min
            weight = weight + v.weight
            array[5] = weight -- max
            table.insert(use_reward, array)
        end
    end
    local reward_items = math.random(1,weight)
    for i,v in ipairs(use_reward) do
        if reward_items > v[4] and reward_items <= v[5] then
           return v
        end
    end
end

function Actions.RewardMechanism(data, params, context)
    local entity = params.entity
    local rewardCfg = params.path
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isEmptyString(rewardCfg, "Reward") then
        return false
    end
    local args = {
        tipType = params.tipType == nil and 4 or params.tipType,
        reward = rewardCfg,
        check = params.check,
        reason = params.reason or "action"
    }
    return entity:reward(args)
end

function Actions.GetAllPlayersCount(node, params, context)
    return Game.GetAllPlayersCount()
end

function Actions.GetAllPlayers(node, params, context)
    local allPlayers = Game.GetAllPlayers()
    local ret = {}
    for _,v in pairs(allPlayers) do
        ret[#ret + 1] = v
    end
    return ret
end

function Actions.GetAllEntities(node, params, context)
    return World.CurWorld:getAllEntity()
end

function Actions.GetEntitiesByFullName(node, params, context)
    local ret = {}
    for _, entity in ipairs(World.CurWorld:getAllEntity()) do
        if entity:cfg().fullName == params.fullName then
            table.insert(ret, entity)
        end
    end
    return ret
end

function Actions.GetSurvivePlayersCount(node, params, context)
    return Game.GetSurvivePlayersCount()
end

function Actions.GetEntityStartPos(node, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    return entity:getStartPos()
end

function Actions.TriggersToAll(data, params, context)
    Game.TriggersAll(params.event)
end

function Actions.GetRandomSurvivePlayer(node, params, context)
    return Game.RandomSurvivePlayer()
end

function Actions.GetGameTime(node, params, context)
    return Game.GetGameTime()
end

function Actions.GetGameState(node, params, context)
    return Game.GetState()
end

function Actions.SendPlaySoundProgressBarToAllPlayer(data, params, context)
    WorldServer.SystemPlaySoundProgressBar(params.timer)
end

function Actions.SendReward(node, params, context)
    Game.doReward(params)
end

function Actions.SendRewardToPlayer(node, params, context)
    Game.doRewardToPlayer(params.entity, params.condition, params.isNextServer)
end

function Actions.SendGoldRewardToPlayer(node, params, context)
    Game.doGoldRewardToPlay(params.player, params.golds, params.condition, params.isNextServer)
end

function Actions.SendReport(node, params, context)
    Game.doReport(params.condition)
end

function Actions.SendReportToPlayer(node, params, context)
    Game.doReportToPlayer(params.entity, params.condition, params.isCount)
end

function Actions.ReportWinner(node, params, context)
    local player = params.entity
    assert(player.isPlayer, "is no player: " .. player)
    ReportManager:reportUserWin(player.platformUserId)
end

function Actions.StopServer(data, params, context)
    Game.QuitServer(params.message)
end

function Actions.KickOutPlayer(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    Game.KickOutPlayer(entity)
end

function Actions.SendStartGame(data, params, context)
    Game.SendStartGame()
end

function Actions.GetWinnerPlayer(data, params, context)
    return Game.GetWinnerPlayer(params.condition)
end

function Actions.KeepAhead(data, params, context)
    if params.entity then 
        if params.delay then 
            World.Timer(params.delay, function()
                params.entity:setValue("isKeepAhead", params.ahead)
            end)
        else
            params.entity:setValue("isKeepAhead", params.ahead)
        end
    end
end

function Actions.CanSlideScreen(data, params, context)
    if params.entity then 
        if params.delay then 
            World.Timer(params.delay, function()
                params.entity:setValue("canSlide", params.flag)
            end)
        else
            params.entity:setValue("canSlide", params.flag)
        end
    end
end

function Actions.AddAppIntegral(data, params, context)
    params.entity:data("main").appIntegral = (params.entity:data("main").appIntegral or 0) + params.integral
end

function Actions.SetAppRankType(data, params, context)
    ReportManager:setRankType(ReportManager.RankType[params.type or "Max"])
end

function Actions.AddUserExp(data, params, context)
    Game.addUserExp(params.entity.platformUserId, params.win, params.camps, params.global)
end

function Actions.GetStartGamePlayCount(data, params, context)
    return Game.GetStartGamePlayerCount()
end

function Actions.GetRandomPosInArea(data, params, context)
	return Lib.randPosInRegion(params.region)
end

function Actions.SetRoutineContent(data, params, context)
    local routine = params.routine
    assert(routine or type(routine) ~= "table",routine)
    routine["content"] = params.value
end

function Actions.GameOverToPlayer(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    Game.GameOverToPlayer(entity)
end

function Actions.ConsumeDiamonds(data, params, context)
    return params.entity:consumeDiamonds(params.coinName, params.count, params.event)
end

function Actions.SendDeadSummary(data, params, context)
    local rankInfo = params.rankInfo
    local result = {}
    if rankInfo then
        result = {
            rank = params.rank or rankInfo.rank,
            name = rankInfo.name,
            gold = rankInfo.gold,
            available = rankInfo.available,
            hasGet = rankInfo.hasGet,
            vip = rankInfo.vip,
            score = params.score or rankInfo.score,
            kills = params.kills or rankInfo.kills
        }
    end
    params.entity:sendPacket({
        pid = "ShowDeadSummary",
        result = result,
        isNextServer = params.isNextServer,
        isWatcher = params.isWatcher,
        title = params.title
    })
end

function Actions.SendGameEnd(data, params, context)
    local result = {
        name = params.name,
        vip = params.vip,
        showPairs = {},
    }

    local i = 1
    while i < 6 do --while true 也行不过ui没那么大，也稍微预防死循环
        if params["disc"..i] and params["value"..i] then 
            result.showPairs[i] = {params["disc"..i], params["value"..i]}
        else
            break
        end
        i = i + 1
    end

    params.entity:sendPacket({
        pid = "SendGameEnd",
        result = result,
        title = params.title
    })
end

function Actions.SendGameSettlement(data, params, context)
    Game.sendGameSettlement(params)
end

function Actions.CreateChest(data, params, context)
    local pos = params.pos
    local id = Block.GetNameCfgId(params.block)
    local map = World.CurWorld:getMap(params.map)
    map:setBlockConfigId(pos, id)
    local block_tray = require "block.block_tray"
    local tray = Lib.derive(block_tray)
    tray:init(pos)
    map:getOrCreateBlockData(pos).tray = tray
end

function Actions.OpenChest(data, params, content)
    params.entity:sendPacket({
        pid = "OpenChest",
        pos = params.pos
    })
end

function Actions.SetPlayerGameId(data, params, content)
    local uuid = require "common.uuid"
    params.entity:data("main").gameId = uuid()
end

function Actions.CreateHome(data, params, context)
	return Game.AllocateHome(params.player, params.map)
end

function Actions.GetPlayerHome(data, params, context)
	return params.player.home
end

function Actions.EnterPlayerHome(data, params, context)
    local target = params.target or params.entity
    local home = assert(target and target.home)
    local targetMap = assert(home and home.region.map)
    params.entity:setMapPos(targetMap, params.pos or home.region.cfg.goHomePos, params.ry, params.rp)
end

function Actions.LeavePlayerHome(data, params, context)
    params.entity:setMapPos(params.map, params.pos, params.ry, params.rp)
end

function Actions.WhetherAtHome(data, params, context)
    local home = params.entity and params.entity.home
    return (home or false) and home.region.map == params.entity.map and Lib.isPosInRegion(home.region, params.entity:getPosition())
end

function Actions.AddRecipe(data, params, context)
    local ret = {}
    ret.ok, ret.msg = Composition:addRecipes(params.player, params.class, params.name)
    return ret
end

function Actions.SubmitRecipe(data, params, context)
    local player = params.entity
    params.entity:sendPacket({
        pid = "SubmitRecipe",
        class = params.class,
        recipeName = params.name or params.recipeName,
        info = params.info or {},
        title = params.title,
        button = params.button
    })
end

function Actions.OnWatchAd(data, params, context)
    params.entity:sendPacket({
        pid = "OnWatchAd",
        type = params.type or 1,
        param = params.param or "",
        adsId = params.adsId
    })
end

function Actions.GetConfigValue(data, params, context)
    local cfg = setting:fetch(params.type, params.fullName)
    if params.type == "block" and params.key == "itemname" then
        return cfg.itemname or cfg._name
    end
    return cfg and cfg[params.key]
end

function Actions.CameraContorlSwitch(data, params, context)
    local entity = params.entity
    if not entity or not entity.isPlayer then
        return
    end
    local packet ={
        pid = "CameraContorlSwitch",
        switch = params.switch,
	}
	entity:sendPacket(packet)
end

function Actions.PlayEffectByPos(data, params, context)
    local effectPath = params.effectPath
    local entity = params.entity
    if not entity or not effectPath then
        return
    end
    local packet ={
        pid = "PlayEffectByPos",
        pos = params.pos or entity:getPosition(),
        effectPath = effectPath,
        times = params.times or 1,
    }
    entity:sendPacket(packet)
end

function Actions.DropItemSpawnEffect(data, params, context)
    local player = params.player
    local item = Item.CreateItem(params.fullName, params.count or 1)
    player:sendPacketToTracking({
        pid = "DropItemSpawn",
		objID = 1000,
        pos = params.pos,
		item = item and item:seri(),
        time = params.time,
        moveSpeed = params.moveSpeed,
        moveTime = params.moveTime,
        instanceId = self:getInstanceID()
    }, true)
end

function Actions.VectorBlockSpaw(data, params, context)
    local cfg
    if params.type == "item" or params.type == "entity" then
        cfg = setting:fetch(params.type, params.fullName)
    end
    Trigger.CheckTriggers(cfg, "VECTOR_SPAW", params)
end

--标记目标
function Actions.MarkEntity(data, params, context)
    local entity = params.entity
    if entity.isPlayer then
        entity:sendPacket({pid = "MarkEntity", objID = params.objID, imagePath = params.imagePath, size = params.size})
    end
end

function Actions.UnMarkEntity(data, params, context)
    local entity = params.entity
    if entity.isPlayer then
        entity:sendPacket({pid = "UnMarkEntity", objID = params.objID})
    end
end

function Actions.ShowNumberEffect(data, params, context)
	local entity = params.player
	if entity and entity.isPlayer then
		params.player:sendPacket({
        pid = "ShowNumberEffect",
        pos = params.pos,
        number = params.number,
		style = params.style,
		distance = params.distance,
        imgset = params.imgset,
		imgfmt = params.imgfmt,
		imageWidth = params.imageWidth,
		imageHeight = params.imageHeight
    })
	end
end

function Actions.ShowNumberUIOnEntity(data, params, context)
	local entity = params.player
	if entity and entity.isPlayer then
		params.player:sendPacket({
		pid = "ShowNumberUIOnEntity",
		beginOffsetPos = params.beginOffsetPos,
		FollowObjID = params.FollowObjID,
		number = params.number,
		style = params.style,
		distance = params.distance,
		imgset = params.imgset,
		imgfmt = params.imgfmt,
		imageWidth = params.imageWidth,
		imageHeight = params.imageHeight
	})
	end
end

function Actions.ShowImagesEffect(data, params, context)
	params.player:sendPacket({
		pid = "ShowImagesEffect",
		pos = params.pos,
		images = params.images,
		style = params.style,
		distance = params.distance,
		imageWidth = params.imageWidth,
		imageHeight = params.imageHeight
	})
end

function Actions.GetGamePauseState(data, params, context)
    return World.CurWorld:isGamePause()
end

function Actions.SetGamePause(data, params, context)
    Game.Pause(params.entity, params.state)
end

-- 让产生某个物品然后播放动作、效果随后消失
function Actions.SpawItemEffect(data, params, context)
	if not params.player then
		return
	end
	params.player:sendPacket({
		pid = "SpawItemEffect",
		cfgName = params.cfgName,
		pos = params.pos
	})
end

--行为统计
function Actions.BehaviorLog(data, params, context)
    params.player:bhvLog(params.typ, params.desc, params.player.platformUserId, params.related)
end

function Actions.RequestCanBuy(data, params, context)
	if params.shopIndex then
		local index  = params.shopIndex
		assert(Shop.shops[index], index)
		Shop:requestCanBuy(index, params.player, params.count)
	end
end

function Actions.GetShopItem(data, params, context)
	local item = Shop.shops[params.shopIndex]
	return item and item[params.key]
end

function Actions.ReleaseManor(data, params, context)
    Server.CurServer:releaseUserManor(params.player.platformUserId)
end

function Actions.GameAnalyticsCustomEvent(data, params, context)
    GameAnalytics.Design(params.player.platformUserId, params.value or 0, params.parts or {})
end

function Actions.AddWaterSpreadPos(data, params, context)
    WaterMgr.AddChangedPos(params.map, params.pos, params.originPos)
end

function Actions.AddNoWaterArea(data, params, context)
    return WaterMgr.AddNoWaterArea(params.map, params.center, params.radius)
end

function Actions.DelNoWaterArea(data, params, context)
    WaterMgr.DelNoWaterArea(params.areaId)
end

function Actions.AddLavaSpreadPos(data, params, context)
    LavaMgr.AddChangedPos(params.map, params.pos, params.originPos)
end

function Actions.AddNoLavaArea(data, params, context)
    return LavaMgr.AddNoLavaArea(params.map, params.center, params.radius)
end

function Actions.DelNoLavaArea(data, params, context)
    LavaMgr.DelNoLavaArea(params.areaId)
end

function Actions.IsEditor(data, params, context)
    return World.CurWorld.isEditorEnvironment
end

function Actions.GameOverWithPerson(data, params, context)
    Game.sendServerGameOver(params.player, {
        showType = params.showType,
        showTitle = params.showTitle,
        showMsg = {
            langKey = params.langKey,
            value = params.showValue
        }
    })
end

function Actions.GameOverWithTeam(data, params, context)
    local team = Game.GetTeamPlayers(params.teamId)
    if not team then
        return
    end
    local data = {
        showType = params.showType,
        showTitle = params.showTitle or "",
        showMsg = {
            langKey = params.langKey or "",
            value = params.showValue or ""
        }
    }
    for objId, player in pairs(team) do
        Game.sendServerGameOver(player, data)
    end
end


function Actions.SetCanJoinMidway(data, params, context)
    Game.SetCanJoinMidway(params.value)
end


