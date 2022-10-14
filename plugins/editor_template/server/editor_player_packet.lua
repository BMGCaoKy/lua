local setting = require "common.setting"
local item_manager = require "item.item_manager"

local handles = Player.PackageHandlers

function handles:ClientReady(packet)
    self.clientReady = true
    if Game.GetState() == "GAME_GO" then
        self:startPlayTime()
    end
    self:setPlayerControl(self)
    self:incCtrlVer()
end

function handles:BCUpdateEntityHeadUI(packet)
    local objID = packet.objID
    if not objID then
        return
    end
    local player = World.CurWorld:getObject(objID)
    if not player or not player.isPlayer then
        return
    end
    player:sendPacketToTracking({
        pid = "UpdateEntityHeadUI",
        objID = objID,
        updateStatus = packet.updateStatus,
        params = packet.params,
    }, false)
end

function handles:combineItem(packet)--重写
    local my_tray = self:data("tray")
    local handTray = my_tray:fetch_tray(packet.handTid)
    local bagTray = my_tray:fetch_tray(packet.bagTid)
    local handItem = handTray:fetch_item(packet.handSlot)
    local bagItem = packet.bagSlot and bagTray:fetch_item(packet.bagSlot)
    if not bagItem and not handItem then
        return
    end
    local hand_item_data = handItem and handTray:remove_item(packet.handSlot)
    local bag_item_data = bagItem and bagTray:remove_item(packet.bagSlot)
    if not bagItem and hand_item_data then
        my_tray:combineItem2(hand_item_data, {Define.TRAY_TYPE.BAG},false, packet.bagSlot)
        return
    end

    if hand_item_data then
        my_tray:combineItem2(hand_item_data, {Define.TRAY_TYPE.BAG},false, packet.bagSlot)
    end
    my_tray:combineItem2(bag_item_data, {Define.TRAY_TYPE.HAND_BAG},false, packet.handSlot)

end

function handles:AddUnmilitRes(packet)
    if not World.cfg.unlimitedRes then
        return
    end
    local name = packet.name
    local type = packet.type
    local targetTid = packet.targetTid
    local targetSlot = packet.targetSlot
    local itemName = type == "block" and "/block" or name
    local cfg = setting:fetch(type, name)
    local count = cfg and cfg.stack_count_max or 1
    local addItem = function()
        local item = Item.CreateItem(itemName, 1, function(itemData)
            if type == "block" then
                itemData:set_block_id(assert(setting:name2id("block", name)), name)
            end
        end)
        local itemData = item_manager:new_item(itemName, item:stack_count_max())
        assert(itemData, itemName)
        if type == "block" then
            itemData:set_block_id(assert(setting:name2id("block", name)), name)
        end
        local tray = self:data("tray"):fetch_tray(targetTid)
        tray:remove_item(targetSlot)
        tray:settle_item(targetSlot, itemData)
    end
    if targetTid and targetSlot then
        addItem()
        return
    end
    self:addItem(itemName, count, function(item)
        if type == "block" then
            item:set_block_id(assert(setting:name2id("block", name)), name)
        end
    end, "addUnmilit")
end

local nameMap = {}

local function findItemCount(self, type, name)
    local count = 0
    type = string.lower(type)
    local trayArray = self:tray():query_trays({Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG})
    for _, element in pairs(trayArray) do
        local tid, tray = element.tid, element.tray
        tray:query_items(function(item)
            if item:full_name() == name and type ~= "block" then
                count = count + item:stack_count()
            elseif type == "block" and name and item:block_id() == setting:name2id("block", name) then
                count = count + item:stack_count()
            end
        end)
    end
    return count
end

local function CreateItem(type, fullName, count)
    if not type or not fullName then
        return nil
    end
    type = string.lower(type)
    if type == "block" then
        local item = Item.CreateItem("/block", count or 1, function(_item)
            _item:set_block(fullName)
        end)
        return item
    end
    return Item.CreateItem(fullName, count or 1)
end

local maxStack = {}
local function GetItemMaxStack(type, name)
    if maxStack[name] then
        return maxStack[name]
    end
    local item = CreateItem(type, name)
    local max = item:stack_count_max()
    maxStack[name] = max
    return max
end

local function calculateMaterial(self, recipe)
    local increment = {}
    if not recipe then
        local comData = self:data("compositionItem")
        for type, names in pairs(comData) do
            if not increment[type] then
                increment[type] = {}
            end
            for name, count in pairs(names) do
                increment[type][name] = -(count == 128 and 0 or count)
            end
        end
        return increment
    end

    local materials = recipe.materials
    local needCount = {}
    local number = {}
    for i, v in pairs(materials) do
        local type, name = v.type, v.name
        nameMap[name] = string.lower(type)
        local maxStackCount = GetItemMaxStack(type, name)
        needCount[name] = (needCount[name] or 0) + maxStackCount
        number[name] = (number[name] or 0) + 1
    end

    local comData = self:data("compositionItem") --合成台上面的物品
    local itemCount = {}
    for type, names in pairs(comData) do
        for name, count in pairs(names) do
            itemCount[name] = count
        end
    end

    local bagCount = {}
    for i, v in pairs(materials) do
        local name, type = v.name, string.lower(v.type)
        bagCount[name] = findItemCount(self, type, name)
    end

    local realityCount = {}
    local aver = {}
    for name, count in pairs(needCount) do
        realityCount[name] = math.min(count, (bagCount[name] or 0 ) + (itemCount[name] or 0))
        aver[name] = math.floor(realityCount[name] / number[name])

        local type = nameMap[name]
        if not increment[type] then
            increment[type] = {}
        end
        increment[type][name] = (realityCount[name] or 0) - (itemCount[name] or 0)
    end

    --不是本次规则的材料要取下来
    for name, v in pairs(itemCount) do
        if not aver[name] then
            local type = nameMap[name]
            if not increment[type] then
                increment[type] = {}
            end
            increment[type][name] = -(v == 128 and 0 or v)
        end
    end

    return increment
end

function handles:TakeOffComposition(packet)
    local comRecipe = self:data("recipeData")
    local comData = self:data("compositionItem") --compositionItem服务器上面的合成栏
    local recipeName = packet.recipeName

    comRecipe.recipeName = recipeName
    local recipe = recipeName and Composition:getRecipe(recipeName)
    local increment = calculateMaterial(self, recipe)

    local sortArray = {}
    for type, vs in pairs(increment) do
        for name, add in pairs(vs) do
            sortArray[#sortArray + 1] = {name = name, add = add, type = type}
        end
    end
    table.sort(sortArray, function(A, B)
        return A.name < B.name
    end)

    for _, v in pairs(sortArray) do
        local name = v.name
        local count = v.add
        local type = string.lower(v.type)
        if not comData[type] then
            comData[type] = {}
        end
        local fullName = type == "block" and "/block" or name
        if count > 0 then --加到合成栏
            local ret = self:data("tray"):remove_item(fullName, count, false, true,function(itemData)
                if type == "block" then
                   return itemData:block_id() == setting:name2id("block", name)
                end
                return true
            end, "compsiton")
            if ret then
                comData[type][name] = (comData[type][name] or 0) + count
            end
        end
    end

    for _, v in pairs(sortArray) do
        local name = v.name
        local count = v.add
        local type = string.lower(v.type)
        local fullName = type == "block" and "/block" or name
        if count < 0 then --从合成栏移走
            --自定义脚本additem2
            local ret = self:addItem2(fullName, - count, function(itemData)
                if type == "block" then
                    itemData:set_block_id(setting:name2id("block", name))
                end
            end, "compsiton")
            if ret then
                comData[type][name] = (comData[type][name] or 0) + count
            else--放不下就生成掉落物
                local maxCount = 1
                if type == "block" then
                    maxCount = 64
                else
                    local cfg = setting:fetch(type, name)
                    maxCount = cfg.stack_count_max or 1
                end
                local sum = -count
                while sum > 0 and maxCount > 0 do
                    local num = math.min(maxCount, sum)
                    sum = sum - num
                    local item = Item.CreateItem(fullName, num,  type == "block" and function(itemData)
                        itemData:set_block_id(assert(setting:name2id("block", name)), name)
                    end)
                    local pos = self:getFrontPos(0.6, false, false)
                    DropItemServer.Create({
                        map = self.map, pos = pos, item = item, guardTime =  120,
                        lifeTime = 1000
                    })
                end
                comData[type][name] = (comData[type][name] or 0) + count
            end
        end
    end
    return true, Lib.copy(comData)
end

function handles:DoCompund(packet)
    local comData = self:data("compositionItem")

    local recipeName = packet.recipeName
    local recipe = Composition:getRecipe(recipeName)
    local composition = recipe.composition[1]
    local materials = recipe.materials

    local types = {}
    local needCount = {}
    for i, material in pairs(materials) do
        local name = material.name
        types[name] = string.lower(material.type)
        needCount[name] = (needCount[name] or 0) + 1
    end
    for name, need in pairs(needCount) do
        local type = types[name]
        if not comData[type] then
            return false, Lib.copy(comData), "not.material"
        end
        if not comData[type][name] then
            return false, Lib.copy(comData), "not.material"
        end
        if need > comData[type][name] then
            return false, Lib.copy(comData), "not.material"
        end
    end
    local name = composition.name
    local type = string.lower(composition.type)
    local fullName = type == "block" and "/block" or name
    local ret = self:addItem2(fullName, 1, function(itemData)
        if type == "block" then
            itemData:set_block_id(setting:name2id("block", name))
        end
    end, "compsiton")
    if ret then
        for name, need in pairs(needCount) do
            local type = types[name]
            comData[type][name] = comData[type][name] - need
        end
    end
    local msg = ret and "succeed" or "compound.inventory.full"
    return ret, Lib.copy(comData), msg
end

--尝试新的写法
function handles:SwapComposition(packet)
    local comData = self:data("compositionItem") --服务器上面的合成栏数据
    local clientData = packet.clientData --客户端合成栏的数据
    local checkFunc = function()
        if not next(comData) then --没有东西在合成栏上
            return true
        end
        for type, names in pairs(comData) do
            for name, count in pairs(names) do
                if count ~=0 and (not clientData[type] or not clientData[type][name] or clientData[type][name] ~= count) then
                    return false
                end
            end
        end
        return true
    end
    if not checkFunc() then --如果服务器和客户端的合成栏数据不一样
        return false
    end
    local comTray = self:data("compositionTray")
    local index = self:data("compositionIndex")
    local stackCount = self:data("compositionStack")

    local increment = packet.increment
    --加到合成栏
    for type, names in pairs(increment) do
        type = string.lower(type)
        if not comData[type] then
            comData[type] = {}
        end
        for name, count in pairs(names) do
            local fullName = type == "block" and "/block" or name
            if count > 0 then 
                local ret, sub, removeItem = self:data("tray"):remove_item(fullName, count, false, true,function(itemData)
                    if type == "block" then
                       return itemData:block_id() == setting:name2id("block", name)
                    end
                    return true
                end, "compsiton")
                if ret then
                    local arr = comTray[name]
                    if not arr then
                        arr = {}
                        comTray[name] = arr
                    end
                    for _, v in pairs(removeItem) do
                        stackCount[name] = (stackCount[name] or 0 ) + 1
                        local r = stackCount[name]
                        arr[r] = v
                    end
                    comData[type][name] = (comData[type][name] or 0) + count
                end
            end
        end
    end

    local trayType = {Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG}
    --从合成栏移走
    for type, names in pairs(increment) do
        type = string.lower(type)
        if not comData[type] then
            comData[type] = {}
        end
        for name, count in pairs(names) do
            if count < 0 then
                if not index[name] then
                    index[name] = 1
                end
                local val = -count
                local sum = val
                local i = index[name]
                local data = comTray[name] and comTray[name][i]
                Lib.pv(data)
                while(sum > 0 and data and data.count >0)
                do
                    local add = math.min(sum, data.count)
                    local sloter = data.sloter
                    if sloter and add >0 then
                        local itemData = Item.DeseriItem(item_manager:seri_item(sloter))
                        itemData:set_stack_count(add)
                        local ret = self:addItemObj(itemData, "composition")
                        print("---ret1", ret)
                        if not ret then
                            break
                        end
                    end
                    local fullName = data.fullName
                    if not sloter and fullName and add> 0 then
                        local ret = self:addItem(fullName, add, function(itemData)
                            if type == "block" then
                                itemData:set_block_id(setting:name2id("block", name))
                            end
                        end, "composition")
                        print("---ret2", ret)
                        if not ret then
                            break
                        end
                    end
                    sum = sum - add
                    data.count = data.count - add
                    if data.count <= 0 then
                        comTray[name][i] = nil
                        i = i + 1
                    end
                    if add <= 0 then
                        break
                    end
                    data = comTray[name][i]
                end
                index[name] = i
                if sum <= 0 then
                    comData[type][name] = (comData[type][name] or 0) - val
                else--放不下就生成掉落物
                    print("--------------------------------", name)
                    local itemName = type == "block" and "/block" or name
                    local item = Item.CreateItem(itemName, sum, function(itemData)
                        if type == "block" then
                            itemData:set_block_id(assert(setting:name2id("block", name)), name)
                        end
                    end)
                    local pos = self:getFrontPos(1, false, false)
                    pos.y = pos.y + 0.4
                    DropItemServer.Create({
                        map = self.map, pos = pos, item = item, guardTime =  60
                    })
                    comData[type][name] = (comData[type][name] or 0) - val
                end
            end
        end
    end
    return true
end