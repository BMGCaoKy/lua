local M = require "entity.entity_tray"
local item_manager = require "item.item_manager"

function M:combineItem2(item_data, trays, check, targetSlot)
    local ret = false
    local firstSettleSlot = nil
    local firstSettleTid = nil
    
    local count = item_data:stack_count()
    local seri_data = item_manager:seri_item(item_data)
    local entity = self._entity
    local trayArray = self:query_trays(trays)

    for _, element in pairs(trayArray) do
        local tid, tray = element.tid, element.tray
        for i = 1, tray:capacity() do --优先合并
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
        if count <= 0 then
            goto Exit1
        end
        local func = function(setSlot)
            local add_count = math.min(item_data:stack_count_max(), count)
            if not check then
                local item = item_manager:deseri_item(seri_data)
                item:set_stack_count(add_count)
                tray:settle_item(setSlot, item)
                if entity.isPlayer then
                    entity:addTarget("GatherItems", item:full_name() == "/block" and item:block_id() or item:full_name(), add_count)
                end
            end
            if not firstSettleSlot then
                firstSettleSlot = setSlot
                firstSettleTid = tid
            end
            count = count - add_count
        end
        if targetSlot and not tray:fetch_item(targetSlot) then
            func(targetSlot)
        end
        for i = 1, tray:capacity() do
            if count <= 0 then
                goto Exit1
            end
            local slot_item = tray:fetch_item(i)
            if not slot_item then
                func(i)
            end
        end
    end

    goto Exit0

::Exit1::
    ret = true
::Exit0::
    return ret, firstSettleSlot, firstSettleTid
end

function M:remove_item2(full_name, count, check, mglichst, proc, reason, related)
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
	local ret = false
	local removeItem = {}
	local _sub = 0
	if not check and not mglichst then
		assert(self:remove_item(full_name, count, true, mglichst, proc))
	end
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
				local v = { slot = slot}
				if item:stack_count() <= sub_count then
					v.count = item:stack_count()
					v.sloter = tray:remove_item(slot)
				else
					v.count = sub_count
					v.fullName = item:full_name()
					item:set_stack_count(item:stack_count() - sub_count)
				end
				removeItem[#removeItem + 1] = v
			end
			_sub = _sub + sub_count
			if count == _sub then
				ret = true
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
	end
	return ret, _sub, removeItem
end

function M:add_item2(full_name, count, proc, check, reason, related)
    count = count or 1
    local item_data = item_manager:new_item(full_name, count)
    assert(item_data, full_name)
    if proc then
        proc(item_data)
    end
    local succeed = self:add_item_data2(item_data, check)
    if succeed and not check and self._entity.isPlayer then
        local args = {
            type = "item",
            name = full_name,
            reason = reason,
            count = count,
        }
        self._entity:resLog(args, related)
        GameAnalytics.ItemFlow(self._entity, "", full_name, count, true, reason, "")
    end
    return succeed
end

function M:add_item_data2(item_data, check)
    local trayType = nil
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
    return self:combineItem(item_data, exclusiveTray and {exclusiveTray, trayType} or {Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG , trayType}, check)
end