local setting = require "common.setting"
local PluginTrigger = T(Trigger, "PluginTrigger") 
local M = L("player1", Lib.derive(PluginTrigger))


local function removeWearBuff(player, wearBuff, attachVar)
    local idList = attachVar["wearBuffId"]
    -- 如果之前有Buff, 先给去掉
    if idList then
        for _, id in pairs(idList) do
            local buff = wearBuff[id]
            if buff then
                player:removeBuff(buff)
                wearBuff[id] = nil
            end
        end
    end
end

local function addBuffByWear(player, buffName, wearBuff, buffIdList, buffContinueTime)
    local buff = player:addBuff(buffName, buffContinueTime)
    local buffId = player:getVar("wearAttachId", 0) + 1
    player:setVar("wearAttachId", buffId)
    wearBuff[buffId] = buff
    buffIdList[#buffIdList + 1] = buffId
end

-- 通过item加buff
function M:ADD_BUFF_BY_ITEM(context)
    local itemCfg = setting:fetch("item", context.itemName)
    local addBuff = itemCfg["itembuff"]
    local forTeam = itemCfg["forTeam"]
    self:PLAYER_ADD_BUFF({addBuff = addBuff, forTeam = forTeam, obj1 = context.obj1})
end

-- 给玩家添加buff
function M:PLAYER_ADD_BUFF(context)
    local addBuff = context.addBuff
    if not addBuff then
        return
    end
    local buffCfg = setting:fetch("buff", addBuff)
    local player = context.obj1
    local teamId = player:getValue("teamId")
    local forTeam = context.forTeam or buffCfg["forTeam"]
    local buffType = buffCfg["type"] or buffCfg["attachType"]

    local function replaceBuff(entity, dictName, isTeam)
        local buffList = entity:getVar(dictName, {})
        local oldBuff = buffList[buffType]
        if oldBuff then
            if isTeam then
                Game.GetTeam(teamId):removeBuff(oldBuff)
            else
                entity:removeBuff(oldBuff)
            end
        end
        local newBuff
        local buffContinueTime = player:getVar("buffContinueTime")
        if isTeam then
            newBuff = Game.GetTeam(teamId):addBuff(addBuff, buffContinueTime)
        else
            newBuff = entity:addBuff(addBuff, buffContinueTime)
        end
        buffList[buffType] = newBuff
    end

    if not forTeam or (forTeam and teamId == 0 and buffType ~= "hot_spring" and buffType ~= "create") then
        replaceBuff(player, "gbuffDict", false)
    elseif teamId > 0 then
        if buffType == "hot_spring" then
            self:CallTrigger({event = "BUY_HOT_SPRING_BUFF", obj1 = player, addBuff = addBuff, teamId = teamId})
        elseif buffType == "create" then
            self:CallTrigger({event = "TEAM_BOOST_CREATE", obj1 = player, addBuff = addBuff, teamId = teamId})
        else
            local entityList = self:GetTeamEntityList({teamId = teamId})
            for _, object in pairs(entityList) do
                if self:IsPlayer({entity = object}) then
                    replaceBuff(object, "teambuff", true)
                end
            end
        end
    end
end

-- 更新附魔数据
function M:PLAYER_UPDATE_ATTACH_BUFF_DATA(context)
    local itemCfg = setting:fetch("item", context.itemName)
    local attachBuff = itemCfg[context.attachKey] or itemCfg["attachBuff"]
    local buffCfg = setting:fetch("buff", attachBuff)
    if not attachBuff then
        return 
    end
    local forTeam = itemCfg["forTeam"] or buffCfg["forTeam"]
    self:PLAYER_ADD_ATTACH_BUFF({obj1 = context.obj1, forTeam = forTeam, attachBuff = attachBuff})
end

-- 给玩家添加附魔buff
function M:PLAYER_ADD_ATTACH_BUFF(context)
    local buffCfg = setting:fetch("buff", context.attachBuff)
    local attachType = buffCfg and (buffCfg["attachType"] or buffCfg["type"])
    local player = context.obj1

    local function updateAttachBuff(selfBuffTbName, object)
        local atTable = object:getVar(selfBuffTbName, {})
        atTable[attachType] = context.attachBuff
        if selfBuffTbName == "atTeamTable" then
            object:sendPacket({pid = "UpdatePlayerEquipAdditionalBuffList", teamBuffTb = atTable})
        else
            object:sendPacket({pid = "UpdatePlayerEquipAdditionalBuffList", selfBuffTb = atTable})
        end
        self:PLAYER_UPDATE_ATTACH_BUFF({obj1 = object}) -- 更新玩家背包所有物品的附魔
    end

    if context.forTeam then
        local teamId = player:getValue("teamId")
        local playerList = self:GetTeamEntityList({teamId = teamId})
        for _, object in pairs(playerList) do
            if self:IsPlayer({entity = object}) then
                updateAttachBuff("atTeamTable", object)
            end
        end
    else
        updateAttachBuff("atSelfTable", player)
    end
    
end

-- 附魔，玩家所有的道具更新附魔 既 记录vars
function M:PLAYER_UPDATE_ATTACH_BUFF(context)
    local player = context.obj1
    local itemList = self:SearchBag({entity = player})
    --设置item的var值， 附魔记录，看玩家有哪些附魔然后给道具附魔。
    for _, item in pairs(itemList) do
        self:ITEM_ATTACH_BUFF({obj1 = player, item = item})
    end
    --装备中的item, 更新附魔 buff。
    itemList = self:SearchBag({entity = player, trayType = {1,2,3,4,5,6}})
    for _, item in pairs(itemList) do
        self:UPDATE_WEAR_ITEM({obj1 = player, item = item, isUpdateWearItem = true})
    end
end

-- 单独道具进来就行附魔/修改var值
function M:ITEM_ATTACH_BUFF(context)
    local item = context.item
    local itemCfg = item:cfg()
    local player = context.obj1
    local types = itemCfg["attachType"]
    if not types then
        return
    end
	local atSelfTable = player:getVar("atSelfTable", {})
    local atTeamTable = player:getVar("atTeamTable", {})
    local attachVar = item:getVar("attachVar") or {}
    local function setBuff(buffKey, buffName) 
        if not buffName then
            return
        end
        attachVar["isAttach"] = true
        attachVar[buffName .. "_buffContinueTime"] = player:getVar("buffContinueTime")
        attachVar[buffName .. "_buffStartTime"] = World.Now()
        attachVar[buffKey] = buffName
    end
    for _, type in pairs(types) do
        local selfBuffName = atSelfTable[type]
        local teamBuffName = atTeamTable[type]
        setBuff("selfBuff" .. type, selfBuffName)
        setBuff("teamBuff" .. type, teamBuffName)
    end
    self:SetItemVar({entity = player, item = item, key = "attachVar", value = attachVar})
    self:ITEM_BUFF_FINISH({obj1 = player, item = item, attachVar = attachVar, atSelfTable = atSelfTable, atTeamTable = atTeamTable})
end

-- 吃道具增加的附魔BUff，在道具的持续时间结束后，buff也要被移除
function M:ITEM_BUFF_FINISH(context)
    local item = context.item
    local itemCfg = item:cfg()
    local player = context.obj1
    local attachVar = context.attachVar
    local atSelfTable = context.atSelfTable
    local atTeamTable = context.atTeamTable

    local buffContinueTime = player:getVar("buffContinueTime")
    if not buffContinueTime then
        return
    end

    -- 吃相同的食物，要把之前的定时器给关闭掉
    local function checkTimer(timer)
        local buffTimer = item:getVar("buffTimer") or {}
        if buffTimer.itemFullName == item:cfg().fullName then
            buffTimer.timer()
            buffTimer.timer = nil
        end
        item:set_var("buffTimer", {itemFullName = item:cfg().fullName, timer = timer})
    end

    local timer = World.Timer(buffContinueTime, function ()
        local function isHasAttachInit(attachType)
            for _, buffName in pairs(itemCfg.attachInit) do
                -- 截取武器附魔配置的buff类型字符串
                local type = string.match(buffName, "%[(%a+)")
                if type == attachType then
                    return true
                end 
            end
            return false
        end

        local function removeTbVar(isAttachInit, key, attachBuffName)
            -- 截取武器附魔配置的buff类型字符串
            local attachType = string.match(attachBuffName, "%[(%a+)")
            if not isAttachInit or not isHasAttachInit(attachType) then
                attachVar[key] = nil
                atSelfTable[attachType] = nil 
                atTeamTable[attachType] = nil 
            end
        end
    
        local function removeAttachVar()
            if not itemCfg.attachInit then
                for key, attachBuffName in pairs(attachVar) do
                    if type(attachBuffName) == "boolean" then
                        attachVar[key] = false 
                    elseif type(attachBuffName) == "string" then
                        removeTbVar(false, key, attachBuffName)
                    end
                end
            else
                for key, attachBuffName in pairs(attachVar) do
                    if type(attachBuffName) == "string" then
                        removeTbVar(true, key, attachBuffName)
                    end
                end
            end
        end
        local function addWearBuff()
            if not itemCfg.attachInit then
                return
            end
            local wearBuff = player:getVar("wearBuffList", {})
            --去掉之前的装备附魔buff
            removeWearBuff(player, wearBuff, attachVar)
            local buffIdList = {}
            for _, buff in pairs(wearBuff) do
                local attachType = buff.cfg["attachType"]
                for _, buffName in pairs(itemCfg.attachInit) do
                    -- 截取武器附魔配置的buff类型字符串
                    local type = string.match(buffName, "%[(%a+)")
                    local isHasBuff = player:getTypeBuff("fullName", buffName)
                    if type == attachType and not isHasBuff then
                        addBuffByWear(player, buffName, wearBuff, buffIdList)
                        attachVar["isAttach"] = true
                    end 
                end
            end
            attachVar["wearBuffId"] = buffIdList
            self:SetItemVar({entity = player, item = item, key = "wearBuff", value = wearBuff})
        end
        removeAttachVar()
        addWearBuff()
        self:SetItemVar({entity = player, item = item, key = "attachVar", value = attachVar})
        player:setVar("atSelfTable", atSelfTable)
        player:setVar("atTeamTable", atTeamTable)
        player:setVar("buffContinueTime", nil)
    end)
    checkTimer(timer)
end

-- 玩家换手持物
function M:HAND_ITEM_CHANGED(context)
    local player = context.obj1
    -- 去掉火焰附魔
    player:setVar("selfFireAttach", nil)
    player:setVar("teamFireAttach", nil)
    player:removeTypeBuff("showFire", true)

    -- 其他附魔
    local selfBuffHand = player:getVar("selfBuffHand", {})
    local teamBuffHand = player:getVar("teamBuffHand", {})
    for _, selfBuff in pairs(selfBuffHand) do
        player:removeBuff(selfBuff)
    end
    for _, teamBuff in pairs(teamBuffHand) do
        player:removeBuff(teamBuff)
    end
    selfBuffHand = {}
    teamBuffHand = {}
    player:setVar("selfBuffHand", selfBuffHand)
    player:setVar("teamBuffHand", teamBuffHand)

    local item = context.item
    if not item then
        return
    end
    local itemCfg = item:cfg()
    local noAttackBuff = itemCfg["noAttackBuff"]
    player:setVar("noAttackBuff", noAttackBuff)

    local itemBase = itemCfg["base"]
    local canHandBuff = itemBase ~= "equip_base"
    if item and canHandBuff then
        local newTypes = itemCfg["attachType"]
        if newTypes then

            local function calcBuffContinueTime(attachVar, buffName)
                if not buffName then
                    return
                end
                local buffContinueTime = attachVar[buffName .. "_buffContinueTime"]
                local buffStartTime = attachVar[buffName .. "_buffStartTime"]
                if buffContinueTime and buffStartTime then
                    local buffCurTime = World.Now() - buffStartTime
                    return buffContinueTime - buffCurTime
                end
                return
            end

            local function addBuff(buffHand, buffName, attachVar) 
                if not buffName then
                    return
                end
                local buffContinueTime = calcBuffContinueTime(attachVar, buffName)
                local buff = player:addBuff(buffName, buffContinueTime)
                buffHand[#buffHand + 1] = buff
            end
            for _, type in pairs(newTypes) do
                local attachVar = item:getVar("attachVar") or {}
                local selfBuffName = attachVar["selfBuff" .. type]
                local teamBuffName = attachVar["teamBuff" .. type]
                -- 火焰附魔
                if type == "fire" then
                    local buffName = selfBuffName or teamBuffName
                    if buffName then
                        local buffContinueTime = calcBuffContinueTime(attachVar, buffName)
                        player:addBuff("myplugin/showFire", buffContinueTime)
                    end
                    player:setVar("selfFireAttach", selfBuffName)
                    player:setVar("teamFireAttach", teamBuffName)
                    goto continue
                end
                addBuff(selfBuffHand, selfBuffName, attachVar)
                addBuff(teamBuffHand, teamBuffName, attachVar)
                ::continue::
            end
        end
    end
    
end

-- 穿上道具进行附魔/更新装备中的附魔buff
function M:UPDATE_WEAR_ITEM(context)
    local item = context.item
    local itemCfg = item:cfg()
    local newTypes = itemCfg["attachType"]
    local player = context.obj1
    if not newTypes then
        return
    end
    -- isUpdateWearItem表示为更新装备的附魔，没有传这个参数则为穿上道具进行附魔
    local isUpdateWearItem = context.isUpdateWearItem
    local attachVar = item:getVar("attachVar") or {}
    -- 玩家装备的buff记录
    local wearBuff = player:getVar("wearBuffList", {})
    -- 移除穿戴装备的附魔buff
    removeWearBuff(player, wearBuff, attachVar)
    -- 重新设置itemBuffId记录
    local buffIdList = {}
    local buffContinueTime = player:getVar("buffContinueTime")
    local function addBuff(buffName)
        if not buffName then
            return
        end
        addBuffByWear(player, buffName, wearBuff, buffIdList, buffContinueTime)
        if isUpdateWearItem then
            attachVar["isAttach"] = true
        end
    end
    for _, Atype in pairs(newTypes) do
        local selfBuffName = attachVar["selfBuff" .. Atype]
        local teamBuffName = attachVar["teamBuff" .. Atype]
        addBuff(selfBuffName)
        addBuff(teamBuffName)
    end
    attachVar["wearBuffId"] = buffIdList
    if isUpdateWearItem then
        self:SetItemVar({entity = player, item = item, key = "wearBuff", value = wearBuff})
    else
        self:SetItemVar({entity = player, item = item, key = "isWearing", value = true})
    end
    
    self:SetItemVar({entity = player, item = item, key = "attachVar", value = attachVar})
end

-- 脱下道具进行附魔buff移除
function M:TAKEOFF_ITEM_ATTACH_BUFF(context)
    local player = context.obj1
    local item = context.item
    -- 玩家装备的buff
    local wearBuff = player:getVar("wearBuffList", {})
    local attachVar = item:var("attachVar") or {}
    removeWearBuff(player, wearBuff, attachVar)
    attachVar["wearBuffId"] = nil
    item:set_var("attachVar", attachVar)
end

function M:PLAYER_ADD_BUFF_ATTACH_ITEM(context)
    local itemCfg = setting:fetch("item", context.itemName)
    local isBuff = itemCfg and itemCfg["isBuff"] or itemCfg["itembuff"]
    local isAttach = itemCfg and itemCfg["isAttach"] or itemCfg["attachBuff"]
    if isBuff then
        self:ADD_BUFF_BY_ITEM({obj1 = context.obj1, itemName = context.itemName})
    elseif isAttach then
        self:PLAYER_UPDATE_ATTACH_BUFF_DATA({obj1 = context.obj1, itemName = context.itemName})
    end
end

-- 穿上道具
function M:WEAR_EQUIPMEN(context)
    local player = context.obj1
    --穿上进行加上附魔buff
    self:UPDATE_WEAR_ITEM({obj1 = player, item = context.item})
    -- 触发计算护盾
    if not player:cfg().disableTemporaryShieldBar then
        player:sendPacket({
            pid = "ClacTemporaryShieldBar",
            objId = player.objID
        })
    end
end

-- 脱下道具
function M:TAKEOFF_EQUIPMEN(context)
    local player = context.obj1
    -- 脱下移去附魔buff
    self:TAKEOFF_ITEM_ATTACH_BUFF({obj1 = player, item = context.item, itemData = context.itemData})
    -- 触发计算护盾
    if not player:cfg().disableTemporaryShieldBar then
        player:sendPacket({
            pid = "ClacTemporaryShieldBar",
            objId = player.objID
        })
    end
end

-- 添加附魔或者buff
function M:PLAYER_ADD_BUFF_OR_ATTACH(context)
    local buffCfg = setting:fetch("buff", context.buffName)
    local attachType = buffCfg and buffCfg["attachType"]
    if attachType then
        self:PLAYER_ADD_ATTACH_BUFF({obj1= context.obj1, attachBuff = context.buffName})
    else
        self:PLAYER_ADD_BUFF({obj1= context.obj1, addBuff = context.buffName})
    end
end

-- 道具自己配置的初始附魔
function M:ITEM_CFG_ATTACH_BUFF(context)
    local item = context.item
    local itemCfg = item:cfg()
    local useAttach = itemCfg["useAttach"]
    if useAttach then
        return 
    end
    local attachVar = item:getVar("attachVar")
    if not attachVar then
        attachVar = {}
    else
        return
    end
    local attachInit = itemCfg["attachInit"]
    local ok
    if attachInit then
        for _, buffName in pairs(attachInit) do
            local type = setting:fetch("buff", buffName)["attachType"]
            attachVar["selfBuff" .. type] = buffName
            attachVar["isAttach"] = true
            ok = true
        end
    end
    if ok then
        self:SetItemVar({entity = context.obj1, item = item, key = "attachVar", value = attachVar})
    end
end

-- 火焰附魔攻击特效与持续伤害
function M:FIRE_ATTACH_BUFF(context)
    local player = context.obj1
    local target = context.obj2
    local selfFireAttach = player:getVar("selfFireAttach")
    local teamFireAttach = player:getVar("teamFireAttach")
    if not selfFireAttach and not teamFireAttach then
        return
    end
    --新的buff替换旧的,名字相同的buff已做时间重置处理
    local function replaceFireBuff(buffName, targetBuff)
         -- 被攻击的人obj2添加火焰特效，
        local targetBuffName = self:getVar(target, targetBuff)
        if targetBuffName ~= buffName then
            target:removeTypeBuff("fullName", targetBuffName)
        end
        self:setVar(target, targetBuff, buffName)
        local buffCfg = setting:fetch("buff", buffName)
        local buffTime = buffCfg["continueTime"]
        target:addBuff(buffName, buffTime, player)
    end
    if selfFireAttach then
        replaceFireBuff(selfFireAttach, "_selfFireBuffName")
    elseif teamFireAttach then
        replaceFireBuff(teamFireAttach, "_teamFireBuffName")
    end
end

function M:CHECK_PLAYER_DIE_FROM_FIRE(context)
    local from = context.from
    if not from or not from.isPlayer or from.removed then
        return
    end
    self:CallTrigger({event = "KILL_PLAYER", obj1 = from})
end

function M:ADD_BASIC_ITEM(context)
    if Game.GetState() ~= "GAME_GO" then
        return
    end
    local entity = context.obj1
    local function addEquipItem(equipItemDatas, teamID, isInitInfinityList)
        for _, equipItemData in pairs(equipItemDatas or {}) do
            local name = equipItemData.name
            local count = equipItemData.count
            local type = equipItemData.type
            local name = equipItemData.name
            local isInfinity = equipItemData.isInfinity
            local isInfinityList = entity:data("main").isInfinityList
            local finityBagList = entity:data("main").finityBagList

            if not isInfinityList then
                isInfinityList = {}
                entity:data("main").isInfinityList = isInfinityList
            end

            
            if not finityBagList then
                finityBagList = {}
                entity:data("main").finityBagList = finityBagList
            end

            if isInitInfinityList then
                isInfinityList[name] = isInfinity or isInfinityList[name]
                entity:data("main").isInfinityList = isInfinityList
                goto continue
            end

            if isInfinityList[name] then
                if finityBagList[name] then
                    goto continue
                end
                --finityBagList[name] = true
                count = 64
                if type == "item" then
                    count = self:GetItemCfg({fullName = name, key = "stack_count_max"})
                end
            end
            if type == "item" then
                if self:GetItemCfg({fullName = name, key = "auto_equip_by_bts"}) then
                    entity:setVar("currAutoEquipItem", true)
                end
                self:AddItem({entity = entity, cfg = name, count = count})
            else
                self:AddBlockItem({entity = entity, block = name, count = count})
            end
            ::continue::
        end
    end

    local function addAllEquipItem(isInitInfinityList)
        local team = World.cfg.team
        for id, teamData in pairs(team or {}) do
            local teamID = teamData.id or id 
            local entityTeamID = entity:getValue("teamId")
            local basicEquip = teamID == entityTeamID and teamData.basicEquip or {}
            addEquipItem(basicEquip, teamID, isInitInfinityList)
    
        end
        local personEquip = World.cfg.basicEquip
        addEquipItem(personEquip, 0, isInitInfinityList)
    end
    
    addAllEquipItem(true)
    addAllEquipItem()
end

function M:IS_CAN_REMOVE_ITEM(context)
    local isCanRemove = context.isCanRemove
    local entity = context.obj1
    local item = context.item
    local name = item and item:cfg().fullName or "myplugin/" .. context.iconName
    local max_count = item and item:cfg().stack_count_max
    if item and item:is_block() then
        local cfg = Block.GetIdCfg(item:block_id())
        name = cfg.fullName
    end
    local isInfinityList = entity:data("main").isInfinityList
    if isInfinityList and isInfinityList[name] then
        isCanRemove.result = false
        if item then
            item:set_stack_count(max_count)
        end
    else
        local finityBagList = entity:data("main").finityBagList
        if finityBagList and finityBagList[name] then
            finityBagList[name] = nil
        end
    end
end


function M:IS_CAN_ITEM_COUNT(context)
    local isCanSet = context.isCanSet
    local entity = context.obj1
    local item = context.item
    local name = item and item:cfg().fullName or "myplugin/" .. context.iconName
    local max_count = item and item:cfg().stack_count_max
    if item and item:is_block() then
        local cfg = Block.GetIdCfg(item:block_id())
        name = cfg.fullName
    end
    local isInfinityList = entity:data("main").isInfinityList
    if isInfinityList and isInfinityList[name] then
        isCanSet.result = false
        if item and item:stack_count() >= max_count / 2 then
            item:set_stack_count(max_count)
        end
    end
    self:OpenPropCollect({obj1 = context.obj1, item = context.item, useItem = true, setCount = context.setCount})
end

function M:ADD_ITEM_CALL_BACK(context)
    self:OpenPropCollect({obj1 = context.obj1, item = context.item, fullName = context.fullName, count = context.count})
end

local function checkIsInfinityRes(entity, itemName)
    local isInfinityList = Lib.copy(entity:data("main").isInfinityList)
    if not isInfinityList then
        return
    end
    for k, v in pairs(isInfinityList) do
        if k == itemName then
            entity:data("main").isInfinityList[k] = nil
        end
    end
end

function M:REMOVE_ITEM(context)
    checkIsInfinityRes(context.obj1, context.item:full_name())
    if not context.isSwitchTray then
        self:OpenPropCollect({obj1 = context.obj1, item = context.item, isRemove = true})
    end
end

-- 检查是否是资源点掉落的物品
local function checkResPointDropItem(self, dropItem, opCount)
    if not (dropItem and (dropItem.dropItemType == "resPointItem")) then
        return
    end
    local fromId = dropItem.fromId
    local resPointEntity = fromId and World.CurWorld:getEntity(fromId)
    if not resPointEntity then
        return
    end
    local count = self:GetObjectVar({obj = resPointEntity, key = "maxSpawCount"})
    count = (count or 0) - opCount
    self:SetObjectVar({obj = resPointEntity, key = "maxSpawCount", value = (count > 0 and count or 0)})
end

function M:PICK_DROPITEM(context)
    checkResPointDropItem(self, context.dropItem, context.item:stack_count())
    self:OpenPropCollect({obj1 = context.obj1, item = context.item})
end

return RETURN(M)