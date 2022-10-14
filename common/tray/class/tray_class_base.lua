local item_manager = require "item.item_manager"
local M = {}

function M:init(type, capacity, class, system)
	self._owner = nil
	self._type = type
	self._capacity = capacity or 1
	self._class = class
	self._system = system
	self._slots = {}
	self._stols = {}
	self._monitor = nil
	self._generator = nil
	self._attributes = {}

	setmetatable(self._slots, {
		__newindex = function(_, key, val)
			self._stols[key] = val
			if self._monitor then
				pcall(self._monitor, key)
			end
		end,

		__index = function(_, key)
			return self._stols[key]
		end,

		__len = function()
			return #self._stols
		end,

		__pairs = function()
			local function iter(_, key)
				return next(self._stols, key)	
			end
			
			return iter, self._stols, nil
		end
    })
end

function M:seri()
	assert(false)
end

function M:deseri(data)
	assert(data)
    self._capacity = data.capacity or self._capacity
end

function M:seri_item(save)
	assert(false)
end

function M:deseri_item(packet)
	assert(false)
end

function M:set_attribute(key, value)
	self._attributes[key] = value
end

function M:get_attribute(key)
	return self._attributes[key]
end

function M:get_attributes()
	return self._attributes
end

function M:set_owner(owner)
	self._owner = owner
end

function M:owner()
	return self._owner
end

function M:set_monitor(monitor)
	assert(not monitor or type(monitor) == "function")
	self._monitor = monitor
end

function M:set_generator(generator)
	assert(not generator or type(generator) == "function")
	self._generator = generator
end

function M:capacity()
	return self._capacity
end
M.getCapacity = M.capacity

function M:set_capacity(capacity)
	assert(capacity >= 0, capacity)
	if self._max_capacity then
		assert(self._max_capacity >= capacity, capacity)
	end
	self._capacity = capacity
end

function M:add_capacity(capacity)
	self:set_capacity(capacity + self._capacity)
end

function M:max_capacity(capacity)
	return self._max_capacity or self._capacity
end

function M:set_max_capacity(capacity)
	assert(capacity >= self._capacity, capacity)
	self._max_capacity = capacity
end

function M:avail_capacity()
	local count = 0
	for i = 1, self._capacity do
		if not self._slots[i] then
			count = count + 1
		end
	end
	return count
end
M.getAvailCapacity = M.avail_capacity

function M:type()
	return self._type
end

function M:class()
	return self._class
end

function M:is_valid_slot(slot)
	return slot > 0 and slot <= self._capacity
end

function M:settle_item(slot, item)

end

function M:remove_item(slot, checkTrigger, isSwitchTray)
	local isCanRemove = {result = true}
	local entity = self:owner()
	local item = self._slots[slot]
	if not item then
		return
	end
	if entity and checkTrigger then
		Trigger.CheckTriggers(entity:cfg(), "IS_CAN_REMOVE_ITEM", {obj1 = entity, isCanRemove = isCanRemove, item = item})
		if not isCanRemove.result then
			return item
		end
	end
	self._slots[slot] = nil
	self:checkHandler('TRAY_REMOVE_ITEM', { obj1 = self:owner(), tray = self, item = item,slot = slot})
	if entity then
        local itemFullName = item:is_block() and item:block_name() or item:full_name()
		Trigger.CheckTriggers(entity:cfg(), "REMOVE_ITEM", {obj1 = entity, item = item, slot = slot, tray = self,isBlockItem = item:is_block(), itemFullName = itemFullName, isSwitchTray = isSwitchTray})
		Trigger.CheckTriggers(item:cfg(), "ITEM_REMOVED", {obj1 = entity, item = item, slot = slot, tray = self, isBlockItem = item:is_block(), itemFullName = itemFullName})
		entity:EmitEvent("OnItemRemoved", item)
	end
	self:on_pick(slot, item)
	return item
end
M.removeItem = M.remove_item

function M:move_item(slot_d, slot_s)
	assert(false)
end

function M:fetch_item(slot)
	assert(slot > 0 and slot <= self._capacity, slot)
	return self._slots[slot]
end
M.fetchItem = M.fetch_item

function M:fetch_item_generator(slot)
    return self._generator(slot)
end

function M:query_items(cmp)
	local ret = {}

	for slot = 1, self._capacity do
		local item = self._slots[slot]
		if item then
			if not cmp or cmp(item) then
				ret[slot] = self._generator(slot)
			end
		end
	end

	return ret
end
M.getAllItem = M.query_items

function M:find_free(force)
	for i = 1, self._capacity do
		if not self._slots[i] then
			return i
		end
	end

	if force then
		return #self._slots + 1
	end
end

function M:check_pick(slot)
	return self:is_valid_slot(slot)
end

function M:check_drop(item)
	return not item or item:tray_type()[self._type]
end

function M:on_use(slot)
	assert(false)
end

function M:on_drop(slot, item)
	
end

function M:on_pick(slot, item)
	
end

function M:remove_item_by_fullname(fullname)
	local entity = assert(self:owner())

	local sequence = GameAnalytics.NewSequence()
	for slot, item in pairs(self._slots or {}) do
		if fullname == item:full_name() then 
			local item_count = item:stack_count()
			if item:stack_count() >= 0 then
				self:remove_item(slot)
			end

			if entity.isPlayer then
				local reason = "use_item"
				local args = {
					type = "item",
					name = fullname,
					reason = reason,
					count = -item_count,
				}
				entity:resLog(args)
				GameAnalytics.ItemFlow(entity, "", fullname, item_count, false, reason, "", sequence)
			end
		end
	end
end

function M:count_item_num_by_fullname(fullname, needBlockFullName)
	local count = 0
	for slot, item in pairs(self._slots or {}) do
		local full_name = item:full_name()
		if needBlockFullName and item:is_block() then
			full_name = item:block_cfg().fullName
		end
		if fullname == nil or fullname == full_name then
			count = count + item:stack_count()
		end
	end
	return count
end
M.getItemSum = M.count_item_num_by_fullname

function M:count_item_num_by_fullname_and_key_val(fullname, key, val)
	local count = 0
	for slot, item in pairs(self._slots or {}) do
		if (fullname == nil or fullname == item:full_name()) and item.vars[key] and item.vars[key] == val then
			count = count + item:stack_count()
		end
	end
	return count
end

local function cleanArrEmptyChild(self)
	-- 清除断层，整理数组
	local top_ptr = 0
	for slot = self:max_capacity(), 1, -1 do
		local item = self._stols[slot]
		if top_ptr >= slot then
			break
		end
		if item then
			self._stols[slot] = nil
			local free_slot = self:find_free()
			self._stols[free_slot] = item
			top_ptr = free_slot
		end
	end
end

local baseMethSortRule = {
	[1] = "full_name",
	[2] = "block_id",
	[3] = "buff_data",
	[4] = "stack_count",
}
function M:sort_item(traySortRule)
	cleanArrEmptyChild(self)
	table.sort(self._slots, function(slot1, slot2) -- slot => item
		if not slot1 or not slot2 then
			return slot2 and true or false
		end
		local slot1_cfg = slot1:cfg()
		local slot2_cfg = slot2:cfg()
		for _, prop in ipairs(traySortRule) do
			local slot1_weight = slot1_cfg[prop] or 0
			local slot2_weight = slot2_cfg[prop] or 0
			if slot1_weight ~= slot2_weight then
				return slot1_weight < slot2_weight
			end
		end
		for _, meth in ipairs(baseMethSortRule) do
			local slot1_weight = slot1[meth](slot1) or 0
			local slot2_weight = slot2[meth](slot2) or 0
			if type(slot1_weight) == "table" or type(slot2_weight) == "table" then
				return false
			elseif slot1_weight ~= slot2_weight then
				return slot1_weight < slot2_weight
			end
		end
		-- ex sort

		return false
	end)

	for slot, item in pairs(self._slots) do
		item:set_monitor(function()
			if self._monitor then
				pcall(self._monitor, slot)
			end
		end)
	end
end

local function getItemCombineBorderSlot(self, slot, slot_item)
	local border_slot = slot + 1
	while(border_slot <= self:capacity())
	do
		local border_slot_item = self:fetch_item(border_slot)
		if not border_slot_item or not slot_item:check_same(border_slot_item) then
			goto CONTINUE
		end
		border_slot = border_slot + 1
	end
	::CONTINUE::
	return border_slot - 1
end

local combineRemoveIndex = L("combineRemoveIndex", {})
local function combine(self, slot, border_slot)
	local borrow_stack = 0
	local max_stack_count = nil
	for iter_slot = slot, border_slot do
		local iter_item = self:fetch_item(iter_slot)
		if not max_stack_count then
			max_stack_count = iter_item:stack_count_max()
		end
		local iter_stack_free = iter_item:stack_free()
		if iter_stack_free > 0 then
			iter_item:set_stack_count(max_stack_count)
			borrow_stack = borrow_stack + iter_stack_free
		end
	end
	if borrow_stack == 0 then
		return
	end
	for iter_slot = slot, border_slot do
		if borrow_stack < max_stack_count then
			self:fetch_item(iter_slot):set_stack_count(max_stack_count - borrow_stack)
			return
		end
		borrow_stack = borrow_stack - max_stack_count
		combineRemoveIndex[iter_slot] = true
	end
end

function M:combine_item() -- combine this tray all item, if use this combine meth ,tray must be sort !!!!!
	combineRemoveIndex = {}
	local comp_slot = 1
	while(comp_slot <= self:max_capacity()) 	-- comp_slot -> border_slot [xx -> xx], 前闭后闭
	do 
		local item = self:fetch_item(comp_slot)
		if not item then
			break
		end
		local border_slot = getItemCombineBorderSlot(self, comp_slot, item)
		if comp_slot < border_slot then
			combine(self, comp_slot, border_slot)
		end
		comp_slot = border_slot + 1
	end

	for slot = self:max_capacity(), 1, -1 do
		if combineRemoveIndex[slot] then
			self._stols[slot] = nil
		end
	end
end

function M:integrate_item(traySortRule) -- sort item -> combine item -> ex -> sort item
	self:sort_item(traySortRule)
	-- ex
	self:combine_item()

	self:sort_item(traySortRule)
end

local function _check_add_item(tray, item)
	local type = -1
	local freeSlot
	local freeStackCount = 0
	local itemStackCount = item:stack_count()
	for slot = 1 , tray:capacity() do
		local slotItem = tray:fetch_item(slot)
		if not slotItem then
			freeSlot = slot
			type = 1
			break
		end

		if slotItem:check_same(item) then
			freeStackCount = freeStackCount + slotItem:stack_free()
			if freeStackCount >= itemStackCount then
				type = 2
				break
			end
		end
	end
	return type, freeSlot
end

local function _add_item(tray, item, check)
	local type, freeSlot = _check_add_item(tray, item)
	if check then
		return type ~= -1
	end

	if type == -1 then
		return false
	elseif type == 1 then
		assert(freeSlot)
		tray:settle_item(freeSlot, item)
		return true
	elseif type == 2 then
		local remindCount = item:stack_count()
		for slot = 1 , tray:capacity() do
			if remindCount <= 0 then
				return true
			end
			local slotItem = tray:fetch_item(slot)
			if slotItem and slotItem:check_same(item) then
				local stackFree = slotItem:stack_free()
				if stackFree > 0 then
					local count = remindCount > stackFree and stackFree or remindCount
					slotItem:add_stack_count(count)
					remindCount = remindCount - count
				end
			end
		end
		return true
	end
	assert(false)
end

function M:add_item(full_name, count, proc, check)
	count = count or 1
	local item_data = item_manager:new_item(full_name, count)
	assert(item_data, full_name)

	if proc then
		proc(item_data)
	end
	return _add_item(self, item_data, check)
end

function M:registerHandler(name, handler)
	Trigger.RegisterHandler(self, name, handler)
end

function M:checkHandler(name,context)
	Trigger.CheckTriggers(self, name, context)
end

function M:deseriAllItem(packet)
	self:deseri_item(packet)
end

function M:deseItem(slot, packet)
	local _,itemData = next(packet)
	local l_packet = {}
	l_packet[slot] = itemData
	self:deseriAllItem(l_packet)
end

function M:cleanTray(fullNames)
	local fullNameTb = {}
	for _, v in pairs(fullNames or {}) do
		fullNameTb[v] = 1
	end

	for i = 1, self:getCapacity() do
		local item = self:fetchItem(i)
		if item and not fullNameTb[item:full_name()] then
			self:removeItem(i)
		end
	end
end

return M