require "common.composition"

-- 得到固定的配方
local matType = {}

function Composition:treatmentGroups(recipes, groups)
    groups = groups or {}
    for _, rec in ipairs(recipes) do
        local recipe = Composition:getRecipe(rec)
        local group = recipe.group
        groups[group] = groups[group] or {}
        table.insert(groups[group], rec)
        if group ~= "All" then
            groups.All = groups.All or {}
            table.insert(groups.All, rec)
        end
    end
    return groups
end

function Composition:getMatInfo(player, material, count)
    local ownCount, icon = 0
    local needCount = material.count or 1
    local type = material.type
    local func = assert(matType[type], type)
    ownCount, icon = func(player, material.name)
    return icon, ownCount, needCount * (count or 1)
end

function Composition:getComInfo(com, cfg)
    return ResLoader:rewardContent(com, cfg)
end

-- 开始合成，
--todo tick合成时间 触发完成合成事件
function Composition:startCompound(player, class, recipeName)
    local recipe = Composition:getRecipe(recipeName)
    local time = 0  --recipe.time or 0
    player:timer(time, Composition.finishCompound, Composition, player, class)
    return true
end

--开始使用平台货币补充道具合成
function Composition:supStartCompound(player, class)
    player:sendPacket({
        pid = "SupStartCompound",
        class = class
    })
end

--todo 中止合成
function Composition:stopCompound(player, class)
    player:sendPacket({
        pid = "StopCompound",
        class = class
    })
end

-- 根据而合成时间触发完成事件，更新显示/提示点提醒完成合成
function Composition:finishCompound(player, class)
    player:finishCompound(class, function(ret)
        Lib.emitEvent(Event.FINISH_COMPOUND, ret.ok, ret.msg, ret.times, ret.reward)
    end)
end

function matType:Item(itemName, blockName)
    local count, icon = 0
    local item = Item.CreateItem(itemName, 1, itemName == "/block" and function(_item)
        _item:set_block(blockName)
    end)
    icon = item:icon()
    count = self:tray():find_item_count(itemName, blockName)
    return count, icon
end

function matType:Block(itemName, blockName)
    local count, icon = 0
    local item = Item.CreateItem("/block", 1, function(_item)
        _item:set_block(itemName or blockName)
    end)
    icon = item:icon()
    count = self:tray():find_item_count("/block", itemName or blockName)
    return count, icon
end

function matType:Coin(coinName)
    return Coin:countByCoinName(self, coinName), Coin:iconByCoinName(coinName)
end