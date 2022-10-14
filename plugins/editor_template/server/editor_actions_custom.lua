local BehaviorTree = require("common.behaviortree")
local setting = require "common.setting"
local Actions = BehaviorTree.Actions
local merchantGroup = World.cfg.merchantGroup

function Actions.GetTeamHeadText(data, params, context)
    local player = params.player
    local regId = player:regCallBack("GetTeamHeadText", {headText = "UPDATE_TEAM_INFO_HEAD_TEXT"}, true, true)
    player:sendPacket({
        pid = "GetTeamHeadText",
        regId = regId,
    })
end

function Actions.GetDefenceWallFullName(data, params, context)
    local teamID = params.teamID
    return Game.GetDefenceWallFullName(teamID)
end

function Actions.GetDefenceTowerFullName(data, params, context)
    local teamID = params.teamID
    return Game.GetDefenceTowerFullName(teamID)
end

function Actions.GetTeamBedFullName(data, params, context)
    local teamID = params.teamID
    return Game.GetTeamBedFullName(teamID)
end

function Actions.PlayerPutOn(data, params, context)
    local item = params.bagitem
    if not item then
        return false
    end
	return params.player:PlayerPutOn(item)
end

function Actions.GetItemByTrayTypeAndSlot(data, params, context)
    local trays = params.entity:tray():query_trays(params.type)
    for _, trayTb in pairs(trays) do
        local tray = trayTb.tray
        local item = tray:fetch_item_generator(params.slot)
        if item then
            return item
        end
    end
end

function Actions.RecordLeavePlayerData(data, params, context)
    local player = params.player
    local data = {
        name = player.name,
        killCount = player.vars.killPlayerCount or 0,
        score = player.vars.score or 0,
        teamId = player.vars.teamId,
        objID = player.objID,
        platformUserId = player.platformUserId
    }
    player.vars.killPlayerCount = 0
    player.vars.score = 0
    Game.AddLeavePlayersData(player.platformUserId, data)
end

function Actions.BroadcastPlayersRank(data, params, context)
    WorldServer.BroadcastPacket({pid = "UpdatePlayerRank", rankData = Game.GetPlayersRank()})
end

function Actions.BroadcastTeamsRank(data, params, context)
    WorldServer.BroadcastPacket({pid = "UpdateTeamRank", rankData = Game.GetTeamsRank()})
end

local function checkIsWin(rankResult, reachCond, winID)

    local function checkTeamWinId(teamID)
        local players = Game.GetTeam(teamID)
        local result = false
        for _, player in pairs(players.entityList or {}) do
            if player.objID == winID then
                result = true
                break
            end
        end
        return result
    end

    for i, data in ipairs(rankResult) do
        local result
        local win = "WIN"
        local lose = "LOSE"
        if data.rank ~= 1 then
            result = lose
        elseif not reachCond then
            result = lose
        elseif reachCond == "otherAllDie" then
            result = i == 1 and win or lose
        elseif reachCond == "endPointOver" then
            local isWin = data.teamID and checkTeamWinId(data.teamID) or (winID == data.objID)
            result = isWin and win or lose
        else
            result = win
        end
        if data.team then
            data.result = result
            for _, v in ipairs(data.team) do
                v.result = result
            end
        else
            data.result = result
        end
    end
end

local rankCondition = require "editor_rankCondition"
local showGameTimeRank = rankCondition.noCondition and rankCondition.showGameTimeRank

local RedisHandler = require "redishandler"

function Actions.SendGameResult(data, params, context)--platformUserId
    local reachCond = params.reachCond
    local player = params.player
    if showGameTimeRank and params.reachCond ~= "endPointOver" then
        if player then
            Game.SendGameTimeRankResult(player)
        else
            local players = Game.GetAllPlayers()
            for _, player in pairs(players) do
                Game.SendGameTimeRankResult(player)
            end
        end
        RedisHandler:trySendZIncBy(true)
        Rank.RequestRankData(2)
        return
    end

    local rankResult = Game.GetGameResult(reachCond, player)

    if params.isGameOver then
        checkIsWin(rankResult, reachCond, player and player.objID)
        -- print(Lib.v2s(rankResult), "==========================")
    end

    if player and params.reachCond ~= "endPointOver" then
        player:sendPacket({pid = "SendGameResult", result = rankResult})
    else
        WorldServer.BroadcastPacket({pid = "SendGameResult", result = rankResult})
    end
end

function Actions.ClacTemporaryShieldBar(data, params, context)
    if not params.player:cfg().disableTemporaryShieldBar then
        params.player:sendPacket({
            pid = "ClacTemporaryShieldBar",
            objId = params.player.objID
        })
    end
end

function Actions.KillTip(data, params, context)
    local packet = {
		pid = "KillTip",
		type = 0,
		key = "system.message.from.kill.target",
        fromObjID = params.from and params.from.objID,
        targetObjID = params.target and params.target.objID
	}
	WorldServer.BroadcastPacket(packet)
end

function Actions.SyncResPointHeadInfo(data, params, context)
	local entity = params.entity

	local curLevel = params.curLevel
	local upLevelTime = params.upLevelTime
    local productTime = params.productTime
    
	local mainData = entity:data("main")
	mainData.curLevel = curLevel or mainData.curLevel
	mainData.upLevelTime = upLevelTime or mainData.upLevelTime
    mainData.productTime = productTime or mainData.productTime
    productTime = mainData.productTime
	if mainData.updateHeadInfoTimer then
		mainData.updateHeadInfoTimer()
	end

    local function update()
        if not entity:isValid() then
            return false
        end
        local s1 = mainData.curLevel and string.format("[C=FFFFFF00]{respoint_level}%d[C=FFFFFF00]", mainData.curLevel) or " "	
		local s2 = mainData.upLevelTime and string.format( "[C=FF0000FF]{respoint_nextleveltime}%ds[C=FF0000FF]",math.floor(mainData.upLevelTime / 20)) or " "
        local text = s2 == " " and string.format("%s", s1) or string.format("%s\n%s", s1, s2)
        entity:setHeadText(0, 0, text,true)
        if productTime == 0 then
            productTime = mainData.productTime
        end
        return true
	end
	update()
	mainData.updateHeadInfoTimer = entity:timer(20, function()
        upLevelTime = mainData.upLevelTime
        mainData.upLevelTime = upLevelTime and (upLevelTime - 20) > 0 and upLevelTime - 20
        productTime = productTime and (productTime - 20) > 0 and productTime - 20 or 0
		return update()
	end)
end

function Actions.GetGameTime(node, params, context)
	return World.Now()
end

function Actions.GetGameGoTime(node, params, context)
    return Game.GetGameTime()
end

function Actions.SearchBag(node ,params, context)
    local Alltype = {}
    for key, v in pairs(Define.TRAY_TYPE) do
        Alltype[#Alltype + 1] = v
    end
    local type =  params.trayType or Alltype
    local player = params.entity
    local itemList = {}
    for _, element in pairs(player:tray():query_trays(type)) do
        local tray = element.tray
        local items = tray and tray:query_items(function(item)
			for k, v in pairs(params.itemFilters or {}) do
				if item:cfg()[k] ~= v then
					return false
				end
			end
			return true
        end)
        for _, item in pairs(items) do
            itemList[#itemList + 1] = item
        end
    end
	return itemList
end

function Actions.GetItemDataVar(data, params, context)
    if not params.item then
        return
    end
    return params.item:var(params.key)
end

function Actions.SetItemDataVar(data, params, context)
    if not params.item then
        return
    end
    params.item:set_var(params.key, params.value)
end

function Actions.GetProps(data, params, context)
    local entity = params.entity
    return entity:prop(params.key)
end

function Actions.SwitchItem(data, params, context)
    local tid_equip = params.tid
	local slot_equip = params.slot
    local entity = params.entity
	local my_tray = entity:data("tray")

	local tray_equip = my_tray:fetch_tray(tid_equip)
	if not tray_equip then
		return false
	end
	local sloter = Item.CreateSlotItem(entity, tid_equip, slot_equip)
	if sloter:null() then
		return false
	end
    local trayArray = my_tray:query_trays(
        {
            Define.TRAY_TYPE.BAG,
            Define.TRAY_TYPE.EQUIP_1,
            Define.TRAY_TYPE.EQUIP_2,
            Define.TRAY_TYPE.EQUIP_3,
            Define.TRAY_TYPE.EQUIP_4,
            Define.TRAY_TYPE.EQUIP_5,
            Define.TRAY_TYPE.EQUIP_6,
            Define.TRAY_TYPE.EQUIP_7,
            Define.TRAY_TYPE.EQUIP_8,
            Define.TRAY_TYPE.EQUIP_9
        }
    )

	for _, element in pairs(trayArray) do
		local tray_bag = element.tray
		local slot_bag = tray_bag:find_free()
		if slot_bag then
			if not Tray:check_switch(tray_bag, slot_bag, tray_equip, slot_equip) then
				return false
			end
			Tray:switch(tray_bag, slot_bag, tray_equip, slot_equip)
			return true
		end
	end
	return false
end

function Actions.UpdatePlayerEquipAdditionalBuffList(data, params, context)
    params.player:sendPacket({pid = "UpdatePlayerEquipAdditionalBuffList", selfBuffTb = params.selfBuffTb, teamBuffTb = params.teamBuffTb})
end


function Actions.IsWater(data, params, context)
    return WaterMgr.IsWater(params.map:getBlockConfigId(params.pos))
end


     
function Actions.GetHotSpringRegion(data, params, context)
    local point = params.point
    local diameter = params.diameter / 2
    local min = {x = point.x - diameter, z = point.z - diameter, y = point.y - 2}
    local max = {x = point.x + diameter, z = point.z + diameter, y = point.y + diameter}
    return { min = min , max = max}
end

function Actions.UpdateMovingStyle(data, params, content) -- 此action慎用
    params.entity:sendPacket({
        pid = "UpdateMovingStyle",
        movingStyle = params.movingStyle,
    })
end

function Actions.GetItemStackCount(data, params, content)
    return params.item:stack_count()
end

function Actions.GetTeamColor(data, params, content)
    return Game.GetTeamColor(params.teamId)
end

function Actions.GetNearbyPos(data, params, content)
    local entity = params.entity
    if not entity then
        return
    end
    local allEntity = entity.map:getNearbyEntities(params.pos, params.distance)
    local ret = {}
    for _, obj in pairs(allEntity) do
		if obj.objID ~= entity.objID then
			ret[#ret + 1] = obj
		end
    end
    return ret
end

function Actions.GetNextMapName(data, params, content)
    local main = setting:fetch("stage","myplugin/main")
    local chapter = main["chapters"] and main["chapters"][1]
    local player = params.player
    if not chapter or not player then
         return
    end
    local name = player.map.name
    local cfg = {}
    local i
    for k, v in ipairs(chapter.stages or {}) do
        local index = #cfg + 1
        cfg[index] = v.map
        if v.map == name then
            i = index
        end
    end
    return i and cfg[i+1] or nil
end


local function isMerchantGroupValid(entity)
    local merchantGroupName = entity:cfg().shopGroupName
    if not merchantGroupName then
        return false
    end
    return merchantGroup[merchantGroupName]
end

function Actions.ShowMerchantShop(data, params, content)
    if not merchantGroup[params.merchantGroupName] then
        return
    end
    params.entity:sendPacket({
        pid = "ShowMerchantShop",
        merchantGroupName = params.merchantGroupName,
    })
end

function Actions.SetMerchantHeadText(data, params, content)
    local entity = params.entity
    local showCfg = isMerchantGroupValid(entity)
    if not showCfg then
        return
    end
    entity:setHeadText(0,0,showCfg.showTitle or "")
end

function Actions.SetMerchantBehavior(data, params, content)
    local entity = params.entity
    if not isMerchantGroupValid(entity) then
        return
    end

    entity:addBuff("myplugin/merchantBuff") --隐藏hp,不能造成伤害
    entity:lightTimer("waitAndStopAI", 1, function ()
        if entity:isValid() then
            entity:stopAI()
        end
    end)
end

function Actions.MonstersDisappeardayDuringDay(data, params, content)
    local entity = params.entity
    if not entity then
        return
    end
    local stage = World.CurWorld:getCurTimeMode()
    local time = World.cfg.monsterMissDuringDayKillTime or 20
    if World.cfg.monsterMissDuringDay and stage == "day" then
        World.Timer(time, function()
            if not entity then
                return
            end
            entity:kill(entity.from, entity.cause or "ACTIONS_KILL_ENTITY")
        end)
    end
end

local function getNextMapPos(mapName, player)
    local team = player:getTeam()
    if team then
        for i, v in pairs(team.startPos or {}) do
            if v.map == mapName then
                return v
            end
        end
    end
    local pos = player:data("main").rebirthPos or {}
    if mapName == pos.map then
        return pos
    end
    return
end

function Actions.GoToNextMap(data, params, content)
    local player = params.player
    local map = World.CurWorld:getOrCreateStaticMap(params.mapName)
    local pos = getNextMapPos(params.mapName, player)
    player:setMapPos(map, pos or map.cfg.birthPos or map.cfg.pos)
end

function Actions.UpdateScaleWhenRebirth(data, params, context)
    local entity = params.entity
    if not entity then
        return false
    end
    local packet = {
        pid = "UpdateScaleWhenRebirth",
        objID = entity.objID
    }
     
    entity:sendPacketToTracking(packet, true)
    return true
end

function Actions.ComputeV3_SUB(data, params, context)
    return Lib.v3cut(params.first, params.second)
end

function Actions.SetForceMoveTimePos(data, params, context)
    local entity = params.entity
    if not entity then
        return false
    end
    local targetDir = Lib.v3add(entity:getPosition(), params.targetDir)
    local packet = {
        pid = "SetForceMoveTimePos",
        objID = entity.objID,
        targetDir = targetDir,
        time = params.time
    }
    entity.forceTargetPos = targetDir
    entity.forceTime = params.time
    entity:sendPacketToTracking(packet, true)
end

function Actions.UpdateAlivePlayerCount(data, params, context)
    local entity = params.entity
    local teamId = entity:getValue("teamId")
    local team = Game.GetTeam(teamId)
    if not team then
        local aliveCount = 0
        for _, player in pairs(Game.GetAllPlayers()) do
            if not player.vars.disRevive then
                aliveCount = aliveCount + 1
            end
        end
        WorldServer.BroadcastPacket({pid = "UpdateAliveCount", aliveCount = aliveCount})
        return
    end
    local entitys = team:getEntityList()
    local aliveCount = 0
    for _, entity in pairs(entitys) do
        if entity.isPlayer and not entity.vars.disRevive then
            aliveCount = aliveCount + 1
        end
    end
    local additionalInfo = Game.GetTeamAdditionalInfo(teamId) or {}
    additionalInfo.aliveCount = aliveCount
    Game.UpdateTeamAdditionalInfo(teamId, additionalInfo)
end

function Actions.GetTeamAlivePlayerCount(data, params, context)
    local team = Game.GetTeam(params.teamId)
    local entitys = team:getEntityList()
    local aliveCount = 0
    for _, entity in pairs(entitys) do
        if entity.isPlayer and entity.curHp > 0 then
            aliveCount = aliveCount + 1
        end
    end
    return aliveCount
end

function Actions.GetObjectIdUnderFoot(data, params, context)
    return params.entity:getCollidableUnderfootObjId()
end

local function canBreakBlock(map, pos)
    if World.cfg.blockCanBreak then
        return true
    end
    local data = map:getBlockData(pos)
    return data and data.isNotPartOfMap or false
end

function Actions.BlockCanBeReplace(data, params, context)
	local block = World.CurWorld:getMap(params.map):getBlock(params.pos)
	return block.canBeReplace
end

function Actions.CanBreakBlock(data, params, context)
    return canBreakBlock(params.map, params.pos)
end

function Actions.ExplodeAreaBlockHandle(data, params, context)
    local dist1 = params.blowDist
    local dist2 = params.combustionDist
    local pos = params.pos
    local entity = params.entity
    local map = entity.map
    local excludeBlocks = params.excludeBlocks
    for _, name in ipairs(params.excludeBlocks or {}) do
        excludeBlocks[name] = true
    end

    local function getBlockName(pos)
        return map:getBlock(pos).fullName
    end
    local function getBlockType(pos)
        return map:getBlock(pos).blockType
    end
    local function breakBlock(pos)
        local cfg = map:getBlock(pos)
        Trigger.CheckTriggers(nil, "BLOCK_BREAK_DROP_ITEM", {obj1 = entity, pos = pos, dropItemList = cfg.dropItemList or {}})
        local cfg = map:getBlock(pos)
        if map:removeBlock(pos, entity) then
            params.entity:sendPacket( {
                pid = "PlayBreakBlockSound",
                id = cfg.id,
                pos = pos,
            })
        end
        CombinationBlock:breakBlock(cfg, pos, map)
    end

    for x = math.floor(pos.x - dist1), math.floor(pos.x + dist1) do
        for y = math.floor(pos.y - dist1), math.floor(pos.y + dist1) do
            for z = math.floor(pos.z - dist1), math.floor(pos.z + dist1) do
                local blockPos = {x = x, y = y, z = z}
                local upBlockPos = {x = x, y = y + 1, z = z}
                local blockType = getBlockType(blockPos)
                local upBlockType = getBlockType(upBlockPos)
                local blockName = getBlockName(blockPos)
                if canBreakBlock(map, blockPos) and blockType ~= "water" and blockType ~= "lava" and not excludeBlocks[blockName] then
                    if blockType == "fire" then
                        map:removeBlock(blockPos, entity)
                    else
                        breakBlock(blockPos)
                    end
                    if upBlockType == "grass" then
                        breakBlock(upBlockPos)
                    elseif upBlockType == "fire" then
                        map:removeBlock(upBlockPos, entity)
                    end
                end
            end
        end
    end
    if not params.burnTime or not dist2 then
        return
    end
    local firBlocks = {}
    for x = math.floor(pos.x - dist2), math.floor(pos.x + dist2) do
        for y = math.floor(pos.y - dist2), math.floor(pos.y + dist2) do
            for z = math.floor(pos.z - dist2), math.floor(pos.z + dist2) do
                local blockPos = {x = x, y = y, z = z}
                local blockName = getBlockName(blockPos)
                local upBlockPos = {x = x, y = y + 1, z = z}
                local upBlockName = getBlockName(upBlockPos)
                if getBlockType(blockPos) == "wool" and upBlockName == "/air" then
                    map:createBlock(upBlockPos, "myplugin/fire")
                    local data = map:getOrCreateBlockData(upBlockPos)
                    data.burnTime = params.burnTime
                    firBlocks[#firBlocks + 1] = upBlockPos
                end
            end
        end
    end
    if #firBlocks == 0 then
        return
    end
    World.Timer(params.burnTime, function()
        for _, pos in ipairs(firBlocks) do
            if map:getBlockData(pos) then
                map:removeBlock(pos, entity)
            end
        end
    end)
end

function Actions.GetBlockData(data, params, context)
    local data = params.map:getOrCreateBlockData(params.pos)
    return data[params.key]
end

function Actions.ExitGame(data, params, context)
    params.player:sendPacket({pid = "ExitGame", canRevive = params.canRevive})
end

function Actions.GetEntityActorName(data, params, context)
    return params.entity:data("main").actorName
end

function Actions.IsMaryModel(data, params, context)
    local name = params.entity:data("main").actorName
    local maryModels = {
        ["character_new_blue_mario.actor"] = true,
        ["character_new_blue_mario_nohat.actor"] = true,
        ["character_new_red_mario.actor"] = true,
        ["character_new_red_mario_nohat.actor"] = true,
    }
    return maryModels[name] or false
end

function Actions.ShowOverPopView(data, params, context)
    local eventMap = {
        yes = params.eventYes or false,
        no = params.eventNo or false,
        sure = params.eventSure or false
    }
    local regKey = "OverPop"
    local regId = params.entity:regCallBack(regKey, eventMap, false, true, context)
    params.entity:sendPacket({
        pid = "ShowOverPopView",
        type = params.type,
        regId = regId,
        regKey = regKey,
        bedBreak = params.bedBreak,
        eventYes = params.eventYes,
        eventNo = params.eventNo,
        eventSure = params.eventSure
    })
end

function Actions.GetBlockTypeByPos(data, params, context)
    local pos = params.pos
    local newPos = {}
    newPos.x = math.floor(pos.x)
    newPos.y = math.floor(pos.y)
    newPos.z = math.floor(pos.z)
    local blockId = World.CurWorld:getMap(params.map):getBlockConfigId(newPos)
    local blockCfg = Block.GetIdCfg(blockId)
    return blockCfg.blockType or ""
end

function Actions.isUnlimitRes(data, params, context)
    return World.cfg.unlimitedRes
end

function Actions.CheckTeamID(data, params, context)
    local team = World.cfg.team or {}
    local oldID = params.teamID
    if not oldID or oldID == 0 or not team[oldID] then
        return 0
    end
    return oldID
end

function Actions.AddItemAsMore(data, params, context)
    local player = params.entity
    local fullName = params.fullName
    local count = params.count
    local type = params.type or "item"
    type = string.lower(type)
    local itemName = type == "block" and "/block" or fullName

    local cfg = setting:fetch(type, fullName)
    local maxStackCount = cfg.max_stack_count or 1
    
    local proc =  function(item)
        if type == "block" then
            item:set_block_id(assert(setting:name2id("block", fullName)), tostring(fullName))
        end
    end

    while count > 0 do
        local num = math.min(count, maxStackCount)
        count = count - num
        if player:data("tray"):add_item(itemName, num, proc, true, params.reason or "action") then
            player:data("tray"):add_item(itemName, num, proc, false, params.reason or "action")
        else
            break
        end
    end 
end

function Actions.ShowTipToAll(data, params, context)
    WorldServer.BroadcastPacket({pid = "ShowToastTip",
        textKey = {params.textKey, params.textP1, params.textP2, params.textP3}
    })
end

function Actions.BoomBlock(data, params, context)
    local entity = params.entity
    if entity.is_die then
        return
    end
    local boomDistance = entity:cfg().boomDistance
    local from = params.from
    
    local killMap = {}
    local boomBlockList = {entity}
    local curBoomBlock
    while true
    do
        if not curBoomBlock then
            curBoomBlock = boomBlockList[1] 
        end
        if not curBoomBlock then
            break
        else
            table.remove(boomBlockList, 1)
        end
        local allEntity = curBoomBlock.map:getNearbyEntities(curBoomBlock:getPosition(), boomDistance)
        curBoomBlock = nil
        for _, tentity in pairs(allEntity) do
            if tentity.is_die then
                goto continue
            end
            local cfg = tentity:cfg()
            local canKill = cfg.canKill
            if cfg.entityDerive == "vectorBlock" then
                tentity.is_die = true
                Trigger.CheckTriggers(cfg, "BOOM_BLOCK_BOOM", {object = tentity, obj2 = from, obj1 = tentity})
                if cfg.canBreak then
                    tentity:kill(from, "ENGINE_MELEE_ATTACK")
                end
            elseif canKill then
                tentity.is_die = true
                killMap[tentity.objID] = tentity
            elseif cfg.canBreak and cfg.actorName == "object_tnt.actor" then
                tentity.is_die = true
                killMap[tentity.objID] = tentity
                table.insert(boomBlockList, tentity)
            end
            ::continue::
        end
    end
    for _, entity in pairs(killMap) do
        entity:kill(from, "ENGINE_MELEE_ATTACK")
    end
end

function Actions.ReplaceHandItem(data, params, context)
    local entity = params.entity
    local handItem = entity:getHandItem()
    if handItem then
        handItem:replace(params.name)
    end
end

function Actions.AddWaterSpreadPos(data, params, context)
    WaterMgr.AddChangedPos(params.map, params.pos, params.originPos)
end

function Actions.GetBuffCfg(data, params, context)
    local buff = params.buff
    if not buff then
        return nil
    end
    local cfg = type(buff) == "string" and setting:fetch("buff", buff) or buff.cfg
    if params.key then
        return cfg[params.key]
    end
    return cfg
end

function Actions.KickOutPlayer(data, params, context)
    Game.KickOutPlayer(params.entity, params.msg)
end

local playerRebirthTimesRecord = {}
function Actions.RecordPlayerRebirthTimes(data, params, context)
    local entity = params.entity
    local oldTimes = playerRebirthTimesRecord[entity.platformUserId] or 0
    playerRebirthTimesRecord[entity.platformUserId] = oldTimes + 1
end

local function isBedBroken(teamId)
    local beds = World.vars.team_beds
    local bedKey = "teamId_" .. teamId
    local bedFullName = Game.GetTeamBedFullName(teamId)
    if beds and teamId > 0 and bedFullName and not beds.data[bedKey] then
        return true
    end
    return false
end

local function isRebirthTimesEnough(entity)
    local worldCfg = World.cfg
    local rebirth = worldCfg.rebirth or {}
    local times = rebirth.times or -1
    if times == -1 then
        return true
    end
    local rebirthTimes = playerRebirthTimesRecord[entity.platformUserId] or 0
    if rebirthTimes <= times then
        return true
    end
    return false
end

function Actions.IsBedBroken(data, params, context)
    return isBedBroken(params.teamId)
end

function Actions.IsUserCanPlay(data, params, context)
    
    local entity = params.entity
    local teamId = entity:getValue("teamId")
    if isBedBroken(teamId) then
        return false
    end
    return isRebirthTimesEnough(entity)
end

function Actions.IsRebirthTimesEnough(data, params, context)
    return isRebirthTimesEnough(params.entity)
end

function Actions.CheckSendToStartPos(data, params, context)
    local player = params.entity
    assert(player.isPlayer)
    local pos = player:getStartPos(not (World.cfg.ignoreEmptyStartPos == false))
    if pos then
        if pos.map then
            player:setMapPos(pos.map, pos)
        else
            player:setPos(pos)
        end
    end
end

function Actions.AddNoWaterArea(data, params, context)
    return WaterMgr.AddNoWaterArea(params.map, params.center, params.radius, params.waterType)
end

function Actions.AddWaterSource(data, params, context)
    WaterMgr.AddWaterSource(params.map, params.pos, params.waterType)
end

function Actions.ConsumeItemForce(data, params, context)
    params.item:consumeForce(params.num, params.reason or "action")
end

function Actions.AddMonsterAroundPlayer(data, params, context)
    local player = params.player
    player:addMonsterAroundPlayer()
end

function Actions.OnEntityDie(data, params, context)
    local entity = params.entity
    entity:onEntityDie()
end

function Actions.CheckPlayerTimer(data, params, context)
    local player = params.player
    player:checkPlayerTimer()
end

function Actions.RemoveAllAttachBuff(data, params, context)
    local player = params.player
    local buffList = player:data("buff")
    local itemDropMod = World.cfg.itemDropMod or "all"
    for _,buff in pairs(buffList) do
        local buffName = buff.cfg["fullName"]
        local isAttachBuff = string.match(buffName, "%[(%a+)")
        local isRetainEquipBuff = (itemDropMod == "none") and buffName:find("equip")
        if isAttachBuff and not isRetainEquipBuff then
            player:removeBuff(buff)
        end
    end
end

function Actions.AddAllEquipBuff(data, params, context)
    local entity = params.entity
    if not entity or not entity:isValid() then
        return
    end
    local equipTrays = entity:cfg().equipTrays
    if not equipTrays then
        return
    end
    for _, element in pairs(entity:tray():query_trays(type)) do
        local tray = element.tray
        local items = tray and tray:query_items(function(item)
            return item:cfg().equip_buff
        end)
        for _, item in pairs(items) do
            entity:addBuff(item:cfg().equip_buff)
        end
    end
    entity:saveHandItem(entity:getHandItem(), nil, true)
end

function Actions.IsOpenSpintSkill(data, params, context)
    local playerCfg = params.player:cfg()
    return playerCfg and playerCfg.canSprint
end

function Actions.IsOpenSquatSkill(data, params, context)
    local playerCfg = params.player:cfg()
    return playerCfg and playerCfg.canSquat
end

local function calcCollectPropsCount(itemInfo, count)
    if itemInfo.useItem then
        local diffValue = itemInfo.count - itemInfo.setCount
        count = count - diffValue
    else
        local flag = itemInfo.isRemove and -1 or 1
        count = count + (itemInfo.count * flag)
    end
    count = count < 0 and 0 or count
    return count
end
local isTeam = World.cfg.team
local function judgePropCollect(collectPropCount, propCfgCount, CollectorsID, player, playerName, playerCollectCount)
    local isSatisfyCount = collectPropCount >= propCfgCount
    Game.RefreshPropCollectData(CollectorsID, collectPropCount, playerCollectCount, playerName, player.objID, player:getValue("teamId"))

    if not Game.isCollectSuccess() and isSatisfyCount then
        Game.ShowPropCollectCountDown(false, isTeam and CollectorsID or playerName)
        Game.setPropCelloctSuccess(CollectorsID)
    end

    if Game.isCollectSuccess() and isSatisfyCount then
        Game.setPropCelloctSuccess(CollectorsID)
    end

    if Game.isCollectSuccess() and not isSatisfyCount then
        if Game.GetNewSuccessCollectID() == CollectorsID then
            Game.setPropCelloctFail(CollectorsID, playerName, player.objID, collectPropCount, playerCollectCount)
            local newCollectID = Game.GetNewSuccessCollectID()
            local isCancel = not newCollectID
            Game.ShowPropCollectCountDown(isCancel, not isCancel and Game.GetNewSuccessCollectName(newCollectID))
        else
            Game.setPropCelloctFail(CollectorsID, playerName, player.objID, collectPropCount, playerCollectCount)
        end
    end
end

local function propCollectForSingle(itemInfo, player, propCfg)
    local collectPropCount = player:getVar("collectPropCount", 0)
    local playerId = player.objID
    collectPropCount = calcCollectPropsCount(itemInfo, collectPropCount)
    SceneUIManager.RefreshEntitySceneUI(playerId, "propNumberTip_" .. playerId, {propNumberText = collectPropCount})
    player:setVar("collectPropCount", collectPropCount)

    judgePropCollect(collectPropCount, propCfg.count, playerId, player, player.name)
end

local function propCollectForTeam(itemInfo, player, propCfg)
    local playerCollectCount = player:getVar("playerCollectCount", 0)
    local collectPropCount = Game.GetTeamCollectCount(player, 0)
    local teamId = player:getValue("teamId")

    collectPropCount = calcCollectPropsCount(itemInfo, collectPropCount)
    playerCollectCount = calcCollectPropsCount(itemInfo, playerCollectCount)
    player:setVar("playerCollectCount", playerCollectCount)

    Game.RefreshTeamAllPlayerHeadUi(teamId, collectPropCount)

    judgePropCollect(collectPropCount, propCfg.count, teamId, player, player.name, playerCollectCount)

    Game.SetTeamCollectCount(player, collectPropCount)

end

local condition = World.cfg.gameOverCondition
local function isOpenPropCollect()
    local isOpenCollect = condition.propsCollection and condition.propsCollection.enable and condition.propsCollection.propCfg
    return isOpenCollect
end

local function getBlockName(blockId)
    local blockCfg = Block.GetNameCfg(setting:id2name("block", blockId))
    return blockCfg.fullName
end

function Actions.OpenPropCollect(data, params, context)
    if not isOpenPropCollect() then
        return
    end

    local player = params.obj1
    local item = params.item
    local propCfg = condition.propsCollection.propCfg
    local itemInfo = {
        fullName = item and item:cfg().fullName or params.fullName,
        count = item and item:stack_count() or params.count,
        setCount = params.setCount,
        useItem = params.useItem,
        isRemove = params.isRemove,
    }
    if item and item:block_id() then
        itemInfo.fullName = getBlockName(item:block_id())
    end

    if itemInfo.fullName ~= propCfg.name then
        return
    end

    if isTeam then
        propCollectForTeam(itemInfo, player, propCfg)
    else
        propCollectForSingle(itemInfo, player, propCfg)
    end
end

function Actions.GetPlayerDefense(data, params, context)
    local player = params.player
    local defenseProps = player:getDamageProps({target = player})
    return defenseProps.defense or 0
end