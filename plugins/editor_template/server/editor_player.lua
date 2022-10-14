local setting = require "common.setting"

local function filterTray(player, trayType)
    local result = {}
    local trays = 
    {
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
    local trayArray = player:tray():query_trays(trays[trayType])
    for _, element in pairs(trayArray) do
        local tray = element.tray
        local items = tray and tray:query_items(function(item)
            return true
        end)
        for _, item in pairs(items) do
            table.insert(result, item)
        end
    end
    return result
end

function Player:PlayerPutOn(item)
    local trayType = item:cfg().tray[1]
    if not trayType then
        return false
    end
    local items = filterTray(self, trayType)
    if not next(items) then
        if item:null() then
		    return false
	    end
	    if not self then
		    return false
	    end
        local tray_bag = self:tray():fetch_tray(item:tid())
        local slot_bag = item:slot()
        for type in pairs(item:tray_type()) do
            if type ~= Define.TRAY_TYPE.BAG then
                local trayArray = self:tray():query_trays(type)
                local tray_equip = trayArray[1] and trayArray[1].tray
                if tray_equip then
                    if (Tray:check_switch(tray_equip, 1, tray_bag, slot_bag)) then
                        Tray:switch(tray_equip, 1, tray_bag, slot_bag)
	    				return true
                    end
                end
            end
	    end
	    self:syncSkillMap()
        return true
    else
        if item:null() then
		    return false
	    end
	    if not self then
		    return false
        end
        
        if not item:cfg().quality then
            return false
        end
        local currQuality = item:cfg().quality
        for i,v in pairs(items)do
            if (v:cfg().tray[1] and v:cfg().tray[1] == trayType) and (v:cfg().quality and v:cfg().quality < currQuality) then
                local oldTid = v:tid()
                local oldSlot = v:slot()
                local newTid = item:tid()
                local newSlot = item:slot()
                local my_tray = self:data("tray")
	            local tray_1 = my_tray:fetch_tray(newTid)
                local tray_2 = my_tray:fetch_tray(oldTid)
	            if not Tray:check_switch(tray_1, newSlot, tray_2, oldSlot) then
	            	return false
	            end
	            Tray:switch(tray_1, newSlot, tray_2, oldSlot)
	            self:syncSkillMap()
	            return true
            end
        end
    end
end

function Player:dropOnDie()
    EntityServer.dropOnDie(self)
    local resourcesMod = World.cfg.resourcesMod or "basic"
    local itemDropMod = World.cfg.itemDropMod or "all"
    if resourcesMod == "unlimited" or itemDropMod == "none" then
        return
    end
    local keepItems = {}
    local cfg = resourcesMod == "basic" and (World.cfg.basicEquip or {}) or (World.cfg.richEquip or {})
    local teamID = self:getValue("teamId")
    local teamID = self:getValue("teamId")
    if teamID > 0 then
        local teamCfg = resourcesMod == "basic" and World.cfg.team and World.cfg.team[teamID] and World.cfg.team[teamID].basicEquip or {}
        if itemDropMod == "other" then
            for _, item in ipairs(teamCfg) do
                keepItems[item.name] = true
            end
        end
    end
    if itemDropMod == "other" then
        for _, item in ipairs(cfg) do
            keepItems[item.name] = true
        end
    end
    local pos = self:getPosition()
    local trayArray = self:tray():query_trays(function() return true end)
    for _, element in pairs(trayArray) do
        local tray_obj = element.tray
        local items = tray_obj:query_items(function(item)
            return true
        end)
        for slot in pairs(items) do
            local item = tray_obj:remove_item(slot)
            local fullName
            if item:is_block() then
                fullName = setting.id2name(setting, "block", item:block_id())
            else
                fullName = item:full_name()
            end
            if not keepItems[fullName] then
                local dropItem
                if not item:is_block() then
                    dropItem = Item.CreateItem(item:full_name(), item:stack_count())
                else
                    dropItem = Item.CreateItem("/block", item:stack_count(), function(dropItem)
                    dropItem:set_block_id(item:block_id())
                    end)
                end
                local item_pos = {
                    x = pos.x + 0.5 + (math.random()-0.5),
                    y = pos.y + 0.8,
                    z = pos.z + 0.5 + (math.random()-0.5)
                }
                DropItemServer.Create({map = self.map, pos = item_pos, item = dropItem, lifeTime = item:cfg().droplifetime})
            end
        end
    end
    if itemDropMod == "other" then
        Trigger.CheckTriggers(self:cfg(), "ADD_BASIC_ITEM", {obj1 = self})
    end
end

function Player:initPlayer()
    local attrInfo = self:getPlayerAttrInfo()
    local mainData = self:data("main")
    mainData.sex = attrInfo.sex == 2 and 2 or 1
    mainData.team = attrInfo.team
    if not self:cfg().ignorePlayerSkin then
        self:changeSkin(attrInfo.skin)
        mainData.actorName = mainData.sex==2 and "editor_girl.actor" or "editor_boy.actor"
    else
        mainData.actorName = self:cfg().actorName
    end
    self:setData("mainInfo", attrInfo.mainInfo)
    self:sendPacket({pid = "SendRoomOwnerId", roomOwnerId = self:data("mainInfo").roomOwnerId})
    self:initCurrency()
end


function Player:checkReplaceBuyItem(replaceItem)
    local teamID = self:getValue("teamId")
    if teamID == 0 then
        return false
    end

    --change block by color
    local blockName = replaceItem.blockName or ""
    if blockName == "myplugin/wool_0" or blockName == "myplugin/glass_0" then
        local cfg = Block.GetNameCfg(blockName)
        local colorBlocks = cfg.colorBlocks
        if colorBlocks then
            replaceItem.blockName = colorBlocks[Game.GetTeamColorName(teamID)]
            return true
        end
    end

    return false
end

local function isPosTouchCollision(map, pos)
    if not pos then
        return true
    end
    local collisionBoxes = Block.GetIdCfg(map:getBlockConfigId(pos)).collisionBoxes
    if collisionBoxes == nil or next(collisionBoxes) then
        return true
    end
    local entities = map:getTouchEntities(pos, Lib.v3add(pos, {x = 1, y = 1, z = 1}))
    for _, entity in pairs(entities) do
        if entity:cfg().collision then
            return true
        end
    end
    return false
end

local function sortMonsterSetDataByTime(monsterSetData)
    local sortData = {}
    local dayCount,nightCount = 0,0
    for index = 1, #monsterSetData do
        if not monsterSetData[index].monsterSpecies then
            goto sortContinue
        end
        local data = monsterSetData[index]
        local environment = data.monsterEnvironment or "day"
        data.refreshInterval = data.refreshInterval or 10
        sortData[data.refreshInterval] = sortData[data.refreshInterval] or {}
        table.insert(sortData[data.refreshInterval], 1, data)
        if environment == "day" or environment == "allday" then
            dayCount = dayCount + 1
        elseif environment == "night" or environment == "allday" then
            nightCount = nightCount + 1
        end
        ::sortContinue::
    end
    return sortData, dayCount, nightCount
end

local function getDayOrBightMansterData(monsterData)
    local tempData = {}
    local stage = World.CurWorld:getCurTimeMode()
    for index = 1, #monsterData do
        local data = monsterData[index]
        local environment = data.monsterEnvironment or "day"
        if not data.monsterSpecies or #data.monsterSpecies == 0 then
            return nil
        end
        if stage == "day" and (environment == "day" or environment == "allday") then
            tempData[#tempData + 1] = data
        elseif stage == "night" and (environment == "night" or environment == "allday") then
            tempData[#tempData + 1] = data
        end
    end
    return tempData
end

function Player:refreshAroundMonsters(objID)
    for _objID,_ in pairs(self.aroundMonsters) do
        if _objID == objID then
            self.aroundMonsters[_objID] = nil
            break
        end
    end
end

function Player:addMonsterAroundPlayer()
    local data = setting:fetch("add_monster", "myplugin/main" )
    local monsterSetData = data and data.addMonsters and data.addMonsters[1] or {}
    local monsterSettingData = data
    if not monsterSetData[1] or not World.cfg.isRandomAddMonster then
        return
    end
    self.addMonsterTimers = self.addMonsterTimers or {}
    local sortMonsterSetData, dayCount, nightCount = sortMonsterSetDataByTime(monsterSetData)
    local isFirstRefresh = true
    for k, v in pairs(sortMonsterSetData) do
        local monsterData = v
        local refreshInterval = monsterData.refreshInterval or monsterData[1].refreshInterval or 10
        local timer = World.Timer( 20 * refreshInterval, function()
            local tempData = getDayOrBightMansterData(monsterData)
            if tempData and next(tempData) then
                self.aroundMonsters = self.aroundMonsters or {}
                local count = self:checkArondMonsterIsRandom(monsterSettingData.monstersMaxCount or 10)
                if count > 0 and #monsterSetData ~= 1 or (dayCount > 1 and nightCount > 1 and not isFirstRefresh) then
                    count = math.random(math.ceil(count * 0.5), count)
                end
                for i = 1, count do
                    local rand1 = math.random(#tempData)
                    local data = tempData[rand1]
                    local environment = data.monsterEnvironment or "day"
                    local rand = math.random(#data.monsterSpecies)
                    local monsterCfg = data.monsterSpecies[rand]

                    local targetPos = self:choiceRandomPosWithMonsterRange(data, monsterSettingData.monstersOutRange or 24)
                    if not targetPos then
                        goto continue
                    end
                    local entity = EntityServer.Create({cfgName = monsterCfg.fullname or monsterCfg.fullName, pos = targetPos + Lib.v3(0,0.1,0), map = self.map})
                    if entity then
                        self.aroundMonsters[entity.objID] = true
                        entity.isRandomMonster = true
                        entity.appearEnvironment = environment
                        entity:checkPlayerDistance(self, monsterSettingData.monstersCheckInterval, monsterSettingData.monstersOutRange, monsterSettingData.monstersDieRange)
                    end
                    ::continue::
                end
                isFirstRefresh = false
            end
            return true
        end)
        table.insert( self.addMonsterTimers, timer )
    end
end

function Player:checkPlayerTimer()
    self.addMonsterTimers = self.addMonsterTimers or {}
    for i=1, #self.addMonsterTimers do
        self.addMonsterTimers[i]()
        self.addMonsterTimers[i] = nil
    end
end

function Player:choiceRandomPosWithMonsterRange(data, monstersOutRange)
    if not data.monsterRange or data.monsterRange == "all" then
        return self:getAroundRandomPos(monstersOutRange)
    elseif data.monsterRange == "set" then
        return self:getAroundRandomPosForSet(data, monstersOutRange)
    elseif data.monsterRange == "noset" then
        return self:getAroundRandomPosForNoSet(data, monstersOutRange)
    end
end

function Player:getAroundRandomPosForSet(data, monstersOutRange)
    local playerPosition = self:getPosition()
    local offset = Lib.v3(monstersOutRange,3,monstersOutRange)
    local maxDistance = (playerPosition + offset):blockPos()
    local minDistance = (playerPosition - offset):blockPos()
    local rangSet = {}
    local blockIds = {}
    for k,v in pairs(data.monsterRangeSetTable or {}) do
        local fullName = v.fullname or v.fullName
        blockIds[#blockIds + 1] = Block.GetNameCfgId(fullName)
    end
    rangSet = self.map:getPosArrayWithIdsInArea(minDistance, maxDistance, blockIds)
    if #rangSet < 1 then
        return
    end
    local rand = math.random(#rangSet)
    local targetPos = rangSet[rand]
    local block = self.map:getBlock(targetPos)
    local tryCount = 0
    while block and block.baseName ~= "/air" do
        targetPos.y = targetPos.y + 1
        block = self.map:getBlock(targetPos)

        tryCount = tryCount + 1
        if tryCount >= monstersOutRange then
            return
        end
    end
    return targetPos
end

function Player:getAroundRandomPosForNoSet(data, monstersOutRange)
    local excludeBlocks = {}
    for k,v in pairs(data.monsterRangeNoSetTable or {}) do
        excludeBlocks[#excludeBlocks + 1] = v.fullname or v.fullName
    end
    return self:getAroundRandomPos(monstersOutRange, excludeBlocks)
end

function Player:getAroundRandomPos(monstersOutRange, excludeBlocks)
    local playerPosition = self:getPosition()
    local targetPos = {}
    for k, v in pairs(playerPosition) do
        targetPos[k] = v
    end
    local tryCount = 0
    while true do
        local function getRandDistance()
            local dis = math.random(math.ceil(0.5 * monstersOutRange),monstersOutRange)
            if math.random(100) >= 50 then
                dis = 0 - dis
            end
            return dis
        end
        targetPos.x = math.ceil(targetPos.x + getRandDistance())
        targetPos.y = math.ceil(targetPos.y + math.random(math.ceil(0.5 * monstersOutRange), monstersOutRange))
        targetPos.z = math.ceil(targetPos.z + getRandDistance())
        local block = self.map:getBlock(targetPos)
        while block and block.baseName == "/air" and targetPos.y > 0 do
            targetPos.y = targetPos.y - 1
            block = self.map:getBlock(targetPos)
        end
        targetPos.y = targetPos.y + 1   --上升一个位置，怪物要在方块上面
        if not isPosTouchCollision(self.map, targetPos) and block.baseName ~= "/air" then
            for k, excludeBlocksFullName in pairs(excludeBlocks or {}) do
                if block.baseName == excludeBlocksFullName then
                    goto continueRandom
                end
            end
            break
        end
        ::continueRandom::
        tryCount = tryCount + 1
        if tryCount >= 3 then
            return
        end
    end
    return targetPos
end

function Player:checkArondMonsterIsRandom(monstersMaxCount)
    local canRefreshCount = monstersMaxCount
    local function checkRandomMonster(monster)
        local monsterHideBuff = monster:getTypeBuff("fullName", "myplugin/hide_entity")
        for objID,_ in pairs(self.aroundMonsters or {}) do
            if monsterHideBuff and objID == monster.objID then
                self.aroundMonsters[monster.objID] = false
            end

            if not monsterHideBuff and objID == monster.objID then
                self.aroundMonsters[monster.objID] = true
            end
            
            if self.aroundMonsters[monster.objID] and objID == monster.objID then
                canRefreshCount = canRefreshCount - 1
            end
        end
    end

    local mapList = T(World, "mapList")
    for _, map in pairs(mapList) do
        for _, obj in pairs(map.objects) do
            if obj.isPlayer or not obj.isEntity then
                goto continue
            end
            local merchantGroupName = obj:cfg().shopGroupName
            if merchantGroupName then
                goto continue
            end
            if obj.isRandomMonster then
                checkRandomMonster(obj)
                goto continue
            end
            ::continue::
        end
    end
    return canRefreshCount
end

function Player:getVar(key, defValue)
    if not key then
		return
    end
    if not self.vars[key] then
        self.vars[key] = defValue
    end
	return self.vars[key]
end

function Player:setVar(key, value)
	if not key then
		return
	end
	self.vars[key] = value
end