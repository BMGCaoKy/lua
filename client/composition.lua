require "common.composition"

-- �õ��̶����䷽
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

-- ��ʼ�ϳɣ�
--todo tick�ϳ�ʱ�� ������ɺϳ��¼�
function Composition:startCompound(player, class, recipeName)
    local recipe = Composition:getRecipe(recipeName)
    local time = 0  --recipe.time or 0
    player:timer(time, Composition.finishCompound, Composition, player, class)
    return true
end

--��ʼʹ��ƽ̨���Ҳ�����ߺϳ�
function Composition:supStartCompound(player, class)
    player:sendPacket({
        pid = "SupStartCompound",
        class = class
    })
end

--todo ��ֹ�ϳ�
function Composition:stopCompound(player, class)
    player:sendPacket({
        pid = "StopCompound",
        class = class
    })
end

-- ���ݶ��ϳ�ʱ�䴥������¼���������ʾ/��ʾ��������ɺϳ�
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