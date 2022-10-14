local item_manager = require "item.item_manager"
local traySortRules = L("traySortRules", World.cfg.traySortRules or {})

local M = L("M", {})

-------------------------------------------------------------------- local
local function isEnableSync(self)
	return self._enableSync
end

local function setEnableSync(self, enable)
	self._enableSync = enable
end
--------------------------------------------------------------------
function M:init(entity)
	self._entity = assert(entity)
	self._trays = {}
	self._gid = 0
	self._loadding = true
	self._enableSync = true

	local trayTypes = {}
	local function createSystemTray(type, capacity, maxCapacity)
		if trayTypes[type] then
			return
		end
		local tray_obj = Tray:new_tray(type, capacity, true)
		if maxCapacity then
			tray_obj:set_max_capacity(maxCapacity)
		end
		self:add_tray(tray_obj)
		trayTypes[type] = true
	end

	if self._entity.isPlayer then
		createSystemTray(Define.TRAY_TYPE.BAG, World.cfg.bagCap or 9)
		createSystemTray(Define.TRAY_TYPE.EXTRA_BAG, 10)
		createSystemTray(Define.TRAY_TYPE.HAND_BAG, World.cfg.handBagCap or 9)
	end
	local entityCfg = entity:cfg()
	for i, cfg in ipairs(entityCfg.trays or {}) do
		local type = assert(cfg.type, i)
		createSystemTray(type, cfg.cap or 0, cfg.maxCap)
	end
	for _, type in ipairs(entityCfg.equipTrays or {}) do
		createSystemTray(type, 1)
	end
	for _, type in ipairs(entityCfg.imprintTrays or {}) do
		createSystemTray(type, 0)
	end
	self._loadding = false
end

function M:load(data)
	assert(not self._loadding)
	self._loadding = true

	local EMPTY = {}
	-- system
	local systemTraysData = Lib.copy(data.system) or EMPTY
	local function loadSystemTray(type, loadData)
		local trayArray = self:query_trays(type)
		local tray = trayArray[1] and trayArray[1].tray
		if tray then
			local data = systemTraysData[type] or EMPTY
			if loadData then
				tray:deseri(data.tray_data)
			end
			tray:deseri_item(data.item_data)
			systemTraysData[type] = nil
		end
	end

	if self._entity.isPlayer then
		loadSystemTray(Define.TRAY_TYPE.BAG, World.cfg.loadBagData)
		loadSystemTray(Define.TRAY_TYPE.HAND_BAG, World.cfg.loadHandBagData)
	end
	for _, cfg in ipairs(self._entity:cfg().trays or EMPTY) do
		loadSystemTray(cfg.type, cfg.saveData)
	end

	-- settlement of homeless item
	do
		local owner = self._entity:owner()	-- NOTE: player 的 owner 是自己
		assert(owner.isPlayer)
		local owner_tray = owner:tray()
		local trayArray = owner_tray:query_trays(Define.TRAY_TYPE.BAG)
		local index, bagArray = next(trayArray)
		assert(bagArray, "owner does not have bag!")

		local index, trayElement = next(trayArray)
		local function find_home()
			if not trayElement then
				return bagArray.tray, bagArray.tray:find_free(true)
			end
			local slot = trayElement.tray:find_free()
			if slot then
				return trayElement.tray, slot
			end
			index, trayElement = next(trayArray, index)
			return find_home()
		end
		
		for type, data in pairs(systemTraysData) do
			local tempTrayArray = owner_tray:query_trays(type)
			local tempIndex, tempErayElement = next(tempTrayArray)
			local tempTray = tempErayElement and tempErayElement.tray
			for slot, item_data in pairs(data.item_data or EMPTY) do
				local tray, slot
				if tempTray then
					tray, slot = tempTray, tempTray:find_free(true)
				end
				if not slot or not slot then
					tray, slot = find_home()
				end
				assert(tray and slot)
				local item = item_manager:deseri_item(item_data)
				tray:settle_item(slot, item)
			end
		end
	end

	-- dynamic
	for _, packet in ipairs(data or EMPTY) do
		local create_data = packet.create_data
		local tray_obj = Tray:new_tray(create_data.type, create_data.capacity)
		self:add_tray(tray_obj)

		tray_obj:deseri(packet.tray_data)
		tray_obj:deseri_item(packet.item_data)
	end

	self:sync_on_load()
	self._loadding = false
end

function M:seri(save)
	local ret = {
		system = {},
	}

	for tid, tray in ipairs(self._trays) do
		local create_data, tray_data, item_data, system = Tray:seri_tray(tray, save)
		if system then
			local tray_type = tray:type()
			assert(not ret.system[tray_type])
			ret.system[tray_type] = {
				create_data = create_data,
				tray_data = tray_data,
				item_data = item_data
			}
		else
			table.insert(ret, {
				create_data = create_data,
				tray_data = tray_data,
				item_data = item_data
				}
			)
		end
	end
	
	return ret
end

--------------------------------------------------------------------
function M:add_tray(obj)
	assert(obj)	
	self._gid = self._gid + 1
	local tid = self._gid

	self._trays[tid] = obj
	obj:set_owner(self._entity)
	obj:set_monitor(function(slot)
		if slot then
			self:sync_slot_stat(tid, slot)
		else
			self:sync_tray_stat(tid)
		end
	end)

	obj:set_generator(function(slot)
		return Item.CreateSlotItem(self._entity, tid, slot)
	end)

	self:sync_new_tray(tid)
	return tid
end
M.addTray = M.add_tray

function M:new_tray(type, capacity)
	local tray_obj = Tray:new_tray(type, capacity)
	return self:add_tray(tray_obj)
end

function M:remove_tray(tid)
	local oldTray = self._trays[tid]
	self._trays[tid] = nil
	self:sync_del_tray(tid)
	return oldTray
end
M.removeTray = M.remove_tray

function M:fetch_tray(tid)
	return self._trays[tid]
end
M.getTrayByID = M.fetch_tray

function M:query_trays(filter)
	local ret = {}
	local function checkFunc(filterTray)
		local isFunction = type(filterTray) == "function"
		for tid, tray in pairs(self._trays) do
			if  tray:type() == filterTray or isFunction and filterTray(tray) then
				ret[#ret + 1] = {
					tid = tid,
					tray = tray
				}
			end
		end
	end

	if type(filter) == "table" then
		for _, filterTray in ipairs(filter) do
			checkFunc(filterTray)
		end
	else
		checkFunc(filter)
	end

	return ret
end

function M:query_class_trays(class)
	local ret = {}
	for tid, tray in pairs(self._trays) do
		if Define.TRAY_TYPE_CLASS[tray:type()] == class then
			ret[tid] = tray
		end
	end
	return ret
end

function M:find_item(item_name)
	for _, t in pairs(self._trays) do
		local items = t:query_items()
		for _, i in pairs(items) do
			if i:full_name() == item_name then
				return i
			end
		end
	end
end
M.findItem = M.find_item

function M:add_item_data(item_data, check)
    local trayType = check ~= true and Define.TRAY_TYPE.EXTRA_BAG or nil -- 给玩家加item时强制成功，暂时加载一个额外的背包容器里
	--if not check then
	--	assert(self:add_item_data(item_data, true))
	--end

	-- trap item
	if item_data:trap() then
		if check then
			return true
		end

		Trigger.CheckTriggers(
			item_data:cfg(),
			"ITEM_TRAP",
			{
				obj1 = self._entity,
				item = Item.DeseriItem(item_manager:seri_item(item_data))
			})

		return true
	end

	local cfg = item_data:cfg()
	local exclusiveTray = cfg.exclusiveTray
	return self:combineItem(item_data, exclusiveTray and {exclusiveTray, trayType} or {Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG, trayType}, check)
end

function M:combineItem(item_data, trays, check)
	local ret = false
	local firstSettleSlot = nil
	local firstSettleTid = nil
	
	local count = item_data:stack_count()
	local seri_data = item_manager:seri_item(item_data)
	local entity = self._entity
	local trayArray = self:query_trays(trays)

	for _, element in pairs(trayArray) do
		local tid, tray = element.tid, element.tray
		
		for i = 1, tray:capacity() do 
			local slot_item = tray:fetch_item(i)
			if slot_item then 
				local check_item = item_manager:deseri_item(seri_data)
				check_item:set_stack_count(0)

				if slot_item:check_combine(check_item) then
					local free_count = slot_item:stack_free()
					local add_count = math.min(free_count, count)
					if add_count > 0 then
						if not check then
							slot_item:set_stack_count(slot_item:stack_count() + add_count)
							if entity.isPlayer then
                                entity:addTarget("GatherItems", slot_item:full_name() == "/block" and slot_item:block_id() or slot_item:full_name(), add_count)
							end
						end
						if not firstSettleSlot then
							firstSettleSlot = i
							firstSettleTid = tid
						end
						count = count - add_count
						if count <= 0 then
							goto Exit1
						end
					end
				end
			end
		end

		for i = 1, tray:capacity() do
			local slot_item = tray:fetch_item(i)
			if not slot_item then
				local add_count = math.min(item_data:stack_count_max(), count)
				if not check then
					local item = item_manager:deseri_item(seri_data)
					item:set_stack_count(add_count)
					tray:settle_item(i, item)
					if entity.isPlayer then
                        entity:addTarget("GatherItems", item:full_name() == "/block" and item:block_id() or item:full_name(), add_count)
					end
				end
				if not firstSettleSlot then
					firstSettleSlot = i
					firstSettleTid = tid
				end
				count = count - add_count
				if count <= 0 then
					goto Exit1
				end
			else
				local check_item = item_manager:deseri_item(seri_data)
				check_item:set_stack_count(0)

				if slot_item:check_combine(check_item) then
					local free_count = slot_item:stack_free()
					local add_count = math.min(free_count, count)
					if add_count > 0 then
						if not check then
							slot_item:set_stack_count(slot_item:stack_count() + add_count)
							if entity.isPlayer then
                                entity:addTarget("GatherItems", slot_item:full_name() == "/block" and slot_item:block_id() or slot_item:full_name(), add_count)
							end
						end
						if not firstSettleSlot then
							firstSettleSlot = i
							firstSettleTid = tid
						end
						count = count - add_count
						if count <= 0 then
							goto Exit1
						end
					end
				end
			end
		end
	end

	goto Exit0

::Exit1::
	ret = true
::Exit0::
	return ret, firstSettleSlot, firstSettleTid
end

function M:add_item_in_slot(tid, slot, full_name, count, proc)
	count = count or 1

	local item_data = item_manager:new_item(full_name, count)
	assert(item_data, full_name)

	local tray_obj = self:fetch_tray(tid)
	local olditem = tray_obj:remove_item(slot)

	if proc then
		proc(item_data)
	end

	item_data:set_stack_count(count)
	tray_obj:settle_item(slot, item_data)

	Trigger.CheckTriggers(self._entity:cfg(), "ADD_ITEM_CALL_BACK", { obj1 = self._entity, fullName = full_name, count = count })

	return olditem
end

function M:add_item(full_name, count, proc, check, reason, related)
	count = count or 1

	local item_data = item_manager:new_item(full_name, count)
	assert(item_data, full_name)

	if proc then
		proc(item_data)
	end

    local succeed = self:add_item_data(item_data, check)
	if succeed and not check and self._entity.isPlayer then
		local args = {
			type = "item",
			name = full_name,
			reason = reason,
			count = count,
		}
		self._entity:resLog(args, related)
		Trigger.CheckTriggers(self._entity:cfg(), "ADD_ITEM_CALL_BACK", { obj1 = self._entity, item = item_data, fullName = full_name, count = count })
		GameAnalytics.ItemFlow(self._entity, "", full_name, count, true, reason, "")
	end
	return succeed
end

--mglichst: remove target items as many as possible
function M:remove_item(full_name, count, check, mglichst, proc, reason, related)
	local typeList = {
		Define.TRAY_TYPE.BAG,
        Define.TRAY_TYPE.EXTRA_BAG,
		Define.TRAY_TYPE.HAND_BAG,
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
	count = count or 1
	if count == 0 then return true , 0 end
	local ret = false
	local _sub = 0
	if not check and not mglichst then
		assert(self:remove_item(full_name, count, true, mglichst, proc))
	end
	local itemCfg
	local function check_tray (t)
		local tray = t.tray
		local slots = tray:query_items(function(item)
			if item:full_name() == full_name then
				if proc then
					return proc(item)
				end
				return true
			end
		end)
		for slot, item in pairs(slots) do
			local sub_count = math.min(count - _sub, item:stack_count())
			if not check then
				if item:stack_count() <= sub_count then
					tray:remove_item(slot, true)
				else
					item:set_stack_count(item:stack_count() - sub_count, self._entity)
				end
			end
			_sub = _sub + sub_count
			if count == _sub then
				ret = true
			end
			if not itemCfg then
				local temp = Item.CreateItem(full_name, 1)
				itemCfg = temp:cfg()
				if temp:is_block() then
					itemCfg = temp:block_cfg()
				end
			end
		end
		if mglichst and _sub > 0 then
			ret = true
		end
	end
	local trays= self:query_trays(typeList)
	for _, t in pairs(trays) do
		check_tray(t)
	end
	if ret and not check then
		if self._entity.isPlayer then
			local args = {
				type = "item",
				name = full_name,
				reason = reason,
				count = -count,
			}
			self._entity:resLog(args, related)
			GameAnalytics.ItemFlow(self._entity, "", full_name, count, false, reason, "")
		end
		self._entity:checkClearHandItem()
		Trigger.CheckTriggers(self._entity:cfg(), "REMOVE_ITEM_AT_COUNT", {obj1 = self._entity,	fullName = full_name, consumeCount = count, consumeSubCount = _sub})
		Trigger.CheckTriggers(itemCfg, "REMOVE_ITEM_AT_COUNT", {obj1 = self._entity,	fullName = full_name, consumeCount = count, consumeSubCount = _sub})
	end
	return ret, _sub
end

function M:check_available_capacity(trayType)
    local trayArray = self:query_trays(trayType or {Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG})
	local count = 0
	for _, element in pairs(trayArray) do
		local tray = element.tray
		for i = 1, tray:capacity() do
			local slot_item = tray:fetch_item(i)
			if not slot_item then
				count = count + 1
			end
		end
	end
	return count
end

function M:use_item(tid, slot)
	local obj_tray = self:fetch_tray(tid)
	if not obj_tray then
		return false
	end

	local ret, errmsg = obj_tray:on_use(slot)
	if not ret then
		return false, errmsg
	end
	self._entity:checkClearHandItem()
	return true
end

function M:update_extra_tray()
	local update = false
	local needTransfers = {}
	local tray_bag = self:query_trays({Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG})
	local extra_tray = self:query_trays(Define.TRAY_TYPE.EXTRA_BAG)
	for _, t in pairs(extra_tray) do
		local tray = t.tray
		for i = 1, tray:capacity() do
			local slot_item = tray:fetch_item(i)
			if slot_item then
				table.insert(needTransfers, {tray = tray, slot = i})
				update = true
			end
		end
	end
	if not update then
		return
	end
	for _, t in pairs(tray_bag) do
		local tray = t.tray
		for i = 1, tray:capacity() do
			local slot_item = tray:fetch_item(i)
			if not slot_item then
				for _, v in ipairs(needTransfers) do
					Tray:switch(v.tray, v.slot, tray, i)
				end
			end
		end
	end
end

local STATIC_TRAY_SORT_RULE = {
	[1] = "sortIndex"
}
--[[
	traySortRules = {
		defaultRule = {
			1 = xxx, -- item cfg prop
			x = xxx },
		X_Type_Tray_Rule = {xx},
		... = xxx
	}
]]
function M:integrate_tray_item(trayType)
	local t_type = trayType or Define.TRAY_TYPE.BAG
	local trays = self:query_trays(t_type)
	local trayTb = trays[1]
	if not trayTb then
		return
	end
	local traySortRule = traySortRules[t_type] or traySortRules.defaultRule or STATIC_TRAY_SORT_RULE

	setEnableSync(self, false)
	trayTb.tray:integrate_item(traySortRule)
	-- todo ex

	setEnableSync(self, true)
	self:sync_on_reload(trayTb.tid)
end

function M:sort_tray_item(trayType)
	local t_type = trayType or Define.TRAY_TYPE.BAG
	local trays = self:query_trays(t_type)
	local traySortRule = traySortRules[t_type] or traySortRules.defaultRule or STATIC_TRAY_SORT_RULE
	trays[1].tray:sort_item(traySortRule)
	-- todo ex

	self:sync_tray_stat(trays[1].tid)
end

-- sync
------------------------------------------------------------------------
function M:seri_all_tray()
	if not isEnableSync(self) then 
		return
	end
	
	local data = {}
	for tid, tray in pairs(self._trays) do
		local create_data, tray_data, item_data = Tray:seri_tray(tray)
		data[#data + 1] = {
			tid = tid,
			create_data = create_data,
			tray_data = tray_data,
			item_data = item_data
		}
	end
	return data
end

function M:sync_on_load(petOnly)
	if not isEnableSync(self) then 
		return
	end
	
	local entity = self._entity
	if not entity.isPlayer then
		return
	end

	local data = self:seri_all_tray()
	entity:sendPacket({
		pid = "tray_load",
		entity = self._entity.objID,
		data = data
	})
end

function M:sync_new_tray(tid)
	if not isEnableSync(self) then 
		return
	end

	if not self._entity.isPlayer then
		return
	end

	if self._loadding then
		return
	end

    local obj_tray = self:fetch_tray(tid)
	assert(obj_tray)

	local create_data, tray_data, item_data = Tray:seri_tray(obj_tray)

    self._entity:sendPacket({
        pid = "tray_new",
        tid = tid,
        data = {
			create_data = create_data,
			tray_data = tray_data,
			item_data = item_data
		}
    })
end

function M:sync_del_tray(tid)
	if not isEnableSync(self) then 
		return
	end
	
	if not self._entity.isPlayer then
		return
	end

	if self._loadding then
		return
	end

	local obj_tray = self:fetch_tray(tid)
	assert(not obj_tray)

	self._entity:sendPacket({
		pid = "tray_del",
		tid = tid
	})
end

function M:sync_tray_stat(tid)
	if not isEnableSync(self) then 
		return
	end
	
	if not self._entity.isPlayer then
		return
	end

	if self._loadding then
		return
	end

	local obj_tray = self:fetch_tray(tid)
	assert(obj_tray)
	self._entity:sendPacket({
		pid = "tray_stat",
		tid = tid,
		data = obj_tray:seri()
	})
end

function M:sync_slot_stat(tid, slot)
	if not isEnableSync(self) then 
		return
	end
	
	if not self._entity.isPlayer then
		return
	end

	if self._loadding then
		return
	end

    local obj_tray = self:fetch_tray(tid)
    assert(obj_tray)

    local item = obj_tray:fetch_item(slot)
    self._entity:sendPacket({
		pid = "slot_stat",
		tid = tid,
		slot = slot,
		data = item and item_manager:seri_item(item)
    })
	self:update_extra_tray()
	self._entity:traySlotChange(tid, slot, item)
end

function M:sync_on_reload(tid)
	if not isEnableSync(self) then 
		return
	end
	
	local entity = self._entity
	if not entity.isPlayer then
		return
	end

	local obj_tray = self:fetch_tray(tid)
	assert(obj_tray)

	local create_data, tray_data, item_data = Tray:seri_tray(obj_tray)
	entity:sendPacket({
		pid = "tray_reload",
		tid = tid,
		data = {
			tray_data = tray_data,
			item_data = item_data
		}
	})
end

function M:find_item_count(full_name, block_name)
	local setting = require "common.setting"
	local count = 0
	for _, tray in pairs(self._trays) do
		tray:query_items(function(item)
			if item:full_name() == full_name and full_name ~= "/block" then
				count = count + item:stack_count()
			elseif full_name == "/block" and block_name and item:block_id() == setting:name2id("block", block_name) then
				count = count + item:stack_count()
			end
		end)
	end
	return count
end

function M:removeItemByFullName(full_name, count, check, mglichst, proc, reason, related)
	return self:remove_item(full_name, count, check, false, nil, 'remove_item')
end

function M:getItemSum(fullName, isBlock)
	return self:find_item_count(isBlock and "/block" or fullName, fullName)
end

function M:getAllTray()
	local tempTrays = self:query_trays(function() return true end)
	local trays = {}
	for i, trayData in pairs(tempTrays) do
		trays[trayData.tid] = trayData.tray
	end
	return trays
end

function M:getTraySum()
	return Lib.getTableSize(self._trays)
end

RETURN(M)
