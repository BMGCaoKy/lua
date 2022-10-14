local item_manager = require "item.item_manager"

function Tray:switch(tray_1, slot_1, tray_2, slot_2)
	assert(self:check_switch(tray_1, slot_1, tray_2, slot_2))

	if tray_1 == tray_2 and slot_1 == slot_2 then
		return
	end

	local item_1 = tray_1:remove_item(slot_1, nil, true)
	local item_2 = tray_2:remove_item(slot_2, nil, true)

	if item_1 then
		tray_2:settle_item(slot_2, item_1)
	end

	if item_2 then
		tray_1:settle_item(slot_1, item_2)
	end

	local entity = tray_1:owner()
	if entity then
		entity:checkClearHandItem()
	end
	local entity = tray_2:owner()
	if entity then
		entity:checkClearHandItem()
	end
end

function Tray:check_drop(dropTid, dropTray, dropSlot, settleEntity, settleTrays, count)
	assert(dropTray and dropSlot)

	local dropItem = dropTray:fetch_item(dropSlot)
	if not count then
		count = dropItem:stack_count()
	end

	if not Item.CreateSlotItem(dropTray:owner(), dropTid, dropSlot):checkConsume(count) then
		return false
	end
	local item
	if not dropItem:is_block() then
		item = Item.CreateItem(dropItem:full_name(), count)
	else
		item = Item.CreateItem("/block", count, function(item)
			item:set_block_id(dropItem:block_id())
		end)
	end

	local canSellte = settleEntity:tray():combineItem(item:data(), settleTrays, true)
	if not canSellte then
		return false
	end

	return true
end

function Tray:drop(dropTid, dropTray, dropSlot, settleEntity, settleTrays, count)
	assert(dropTray and dropSlot)

	local dropItem = dropTray:fetch_item(dropSlot)
	if not count then
		count = dropItem:stack_count()
	end

	Item.CreateSlotItem(dropTray:owner(), dropTid, dropSlot):consume(count)
	local item
	if not dropItem:is_block() then
		item = Item.CreateItem(dropItem:full_name(), count)
	else
		item = Item.CreateItem("/block", count, function(item)
			item:set_block_id(dropItem:block_id())
		end)
	end
	local ok, firstSettleSlot, firstSettleTid = settleEntity:tray():combineItem(item:data(), settleTrays)

	return ok, firstSettleSlot, firstSettleTid
end

function Tray:check_move(tray_d, slot_d, tray_s, slot_s, count)
	assert(tray_d and slot_d and tray_s and slot_s and count >= 0)

	if count == 0 then
		return true
	end

	if tray_d == tray_s and slot_d == slot_s then
		return true
	end

	local item_s = tray_s:fetch_item(slot_s)
	local item_d = tray_d:fetch_item(slot_d)

	if not item_s then
		return true
	end

	if not tray_s:check_pick(slot_s) then
		return false
	end

	if not tray_d:check_drop(item_s) then
		return false
	end

	if item_s:stack_count() < count then
		return false
	end

	if item_d and not item_d:check_combine(item_s) then
		return false
	end

	local curr_stack_count = item_d and item_d:stack_count() or 0
	if curr_stack_count + count > item_s:stack_count_max() then
		return false
	end

	return true
end

function Tray:move(tray_d, slot_d, tray_s, slot_s, count)
	assert(self:check_move(tray_d, slot_d, tray_s, slot_s, tostring(count)))

	if count == 0 then
		return
	end

	if tray_d == tray_s and slot_d == slot_s then
		return
	end

	local item_s = tray_s:fetch_item(slot_s)
	local item_d = tray_d:fetch_item(slot_d)

	if not item_s then
		return
	end

	item_s:set_stack_count(item_s:stack_count() - count)
	if item_s:stack_count() == 0 then
		assert(tray_s:remove_item(slot_s) == item_s)
	end

	if not item_d then
		item_s:set_stack_count(count)
		tray_d:settle_item(slot_d, item_s)
	else
		item_d:set_stack_count(item_d:stack_count() + count)
	end

	local entity = tray_d:owner()
	if entity then
		entity:checkClearHandItem()
	end
	local entity = tray_s:owner()
	if entity then
		entity:checkClearHandItem()
	end
end
