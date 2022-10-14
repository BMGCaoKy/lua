local tray_class_base = require "common.tray.class.tray_class_base"
local item_manager = require "item.item_manager"

local M = Lib.derive(tray_class_base)
local strfmt = string.format

function M:on_modify()
	if self._monitor then
		pcall(self._monitor)
	end
end

function M:seri()
	local data = {}

	data.capacity = self._capacity
    data.attributes = self._attributes
	return data
end

function M:deseri(data)
	if not data then
		return
	end

	self._capacity = data.capacity or self._capacity
    self._attributes = data.attributes or self._attributes
	assert(self._capacity >= 0)

	self:on_modify()
end

function M:seri_item(save)
	local item_data = {}
	for slot, item in pairs(self._slots) do
		if not save or item:need_save() then
			item_data[slot] = item_manager:seri_item(item, save)
		end
	end
	return item_data
end

function M:deseri_item(packet)
	if not packet then
		return
	end

	for slot, item_data in pairs(packet) do
        local item = item_manager:deseri_item(item_data)
        if not item then
            goto continue
        end
        if self._slots[slot] then
            slot = self:find_free()
        end
        if not slot then
            perror(strfmt("%s(%s) can't find free slot to add item", tostring(self._class), tostring(self._type)))
            goto continue
        end
        self:settle_item(slot, item)
        ::continue::
	end
end

function M:set_capacity(capacity)
	tray_class_base.set_capacity(self, capacity)
	self:on_modify()
end

function M:system()
	return self._system
end

function M:settle_item(slot, item)
	assert(slot > 0, slot)
	assert(not self._slots[slot], tostring(slot))
	assert(item)

	self._slots[slot] = item
	item:set_monitor(function()
		if self._monitor then
			pcall(self._monitor, slot)
		end
	end)
    local entity = self:owner()
    if entity then
        Trigger.CheckTriggers(entity:cfg(), "SETTLE_ITEM", {obj1 = entity, item = item, slot = slot, tray = self})
        Trigger.CheckTriggers(item:cfg(), "ITEM_SETTLED", {obj1 = entity, item = item, slot = slot, tray = self})
        entity:EmitEvent("OnItemAdded", self, item)
    end
    self:checkHandler('TRAY_ADD_ITEM', { obj1 = entity, tray = self, item = item,slot = slot})
	self:on_drop(slot, item)
end
M.settleItem = M.settle_item

function M:move_item(slot_d, slot_s)
	self._slots[slot_d], self._slots[slot_s] = self._slots[slot_s], self._slots[slot_d]
end

function M:on_pick(slot, item)
	if not self._owner then
		return
	end
	Trigger.CheckTriggers(self._owner and self._owner:cfg(), "TRAY_PICK_ITEM", {obj1 = self._owner, item = item})
	self._owner:checkClearIsHandItem(slot, item)	-- todo
	self._owner:checkClearHandItem()	-- todo
end

function M:on_upgrade(item, tid, slot)
    if not item:canUpgrade() then
        return false, "can_not_upgrade"
    end
    local curLevel = item:getValue("curLevel")
    local maxLevel = item:maxLevel()
    if curLevel >= maxLevel then
        return false, "max_level"
    end
    local nextLevelCfg = item:levelCfg(curLevel + 1)
    local cost = nextLevelCfg.cost or {}
    local successRate = nextLevelCfg.successRate or 1
    local entity = self:owner()
    local player = entity:owner()
    if next(cost) and not player.isPlayer then
        return false, "not_player"
    end
    for _, v in ipairs(cost) do
        local typ = v.typ
        local name = v.name
        local count = v.count or 1
        if typ == "Coin" then
            local result = player:payCurrency(name, count, false, true, "itemUpgrade")--todo
            if not result then
                return false, "coin_not_enough", name
            end
        elseif typ == "Item" then
            local sloter = player:tray():find_item(name)
	        if not sloter then
		        return false, "item_not_enough", name
	        end
            local result = player:tray():remove_item(sloter:cfg().fullName, count, true)
            if not result then
                return false, "item_not_enough", name
            end
        end
    end
    for _, v in ipairs(cost) do
        local typ = v.typ
        local name = v.name
        local count = v.count or 1
        if typ == "Coin" then
            player:payCurrency(name, count, false, false, "itemUpgrade")
        elseif typ == "Item" then
            player:consumeItem(name, count, "itemUpgrade")
        end
    end
    --成功率
    local point = successRate * 1000000
    math.randomseed(tostring(os.time()):reverse():sub(1, 7))
    local random = math.random(1000000)
    if point < random then
        Trigger.CheckTriggers(player:cfg(), "ITEM_UPGRADE_FAIL", {obj1 = player, item = item, tid = tid, slot = slot})
        return false, "upgrade_fail"
    end
    item:setValue("curLevel", curLevel + 1)
    --如果该装备在身上，脱下再穿，以便buff跟外观同步到客户端
    if item:buff_data() or (#item:buff_datas() > 0) then
        self:on_pick(slot, item)
        self:on_drop(slot, item)
    end
    Trigger.CheckTriggers(player:cfg(), "ITEM_UPGRADE_SUCCESS", {obj1 = player, item = item, tid = tid, slot = slot})
    return true
end

function M:setCapacity(capacity)
    local oldCapacity = self:getCapacity()
    self:set_capacity(capacity)
    self:checkHandler('CAPACITY_BE_CHANGE', { obj1 = self:owner(), tray = self, oldCapacity = oldCapacity, newCapacity = capacity })
end
function M:findFreeSlot(force)
    local slot = self:find_free(force)
    local capaticy = self:getCapacity()
    if slot > capaticy then
        self:setCapacity(capaticy + 1)
    end
    return slot
end

local function getItemPacket(self, func)
    local item_data = self:seri_item()
    for slot, itemData in pairs(item_data) do
        if func(slot, itemData) then
            item_data[slot] = nil
        end
    end
    return item_data
end

function M:seriItem(l_slot)
    local packet = getItemPacket(self, function(slot, itemData)
        return l_slot ~= slot
    end)

    return packet
end

function M:seriAllItem(fullNames)
    local fullNameTb = {}
    for _, v in pairs(fullNames or {}) do
        fullNameTb[v] = 1
    end

    local packet = getItemPacket(self, function(slot, itemData)
        return fullNameTb[itemData.fullname]
    end)

    return packet
end

return M
