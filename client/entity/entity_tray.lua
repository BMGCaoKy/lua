local M = {}

function M:init(entity)
	self._entity = entity
	self._trays = {}
end

--------------------------------------------------------------------
function M:add_tray(tid, obj)

--	assert(not self._trays[tid])

	self._trays[tid] = obj
	obj:set_owner(self._entity)
	obj:set_generator(function(slot) 
		return Item.CreateSlotItem(self._entity, tid, slot)
	end)
	return tid
end

function M:del_tray(tid)
	self._trays[tid] = nil
end

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
		for _, filterTray in pairs(filter) do
			checkFunc(filterTray)
		end
	else
		checkFunc(filter)
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

function M:set_item(tid, slot, obj_item)
	local obj_tray = assert(self:fetch_tray(tid), tid)
	if obj_item then
		obj_tray:settle_item(slot, obj_item)
		Lib.emitEvent(Event.EVENT_PLAYER_ITEM_MODIFY_GTA, tid, slot, obj_item, true) -- tid slot itemData isAdd
	else
		Lib.emitEvent(Event.EVENT_PLAYER_ITEM_REMOVE_GTA, tid, slot, obj_tray:fetch_item(slot), false)
		obj_tray:remove_item(slot)
	end
	Me:onTrayItemModify()
end

function M:getItemSum(fullName, isBlock)
	return self:find_item_count(isBlock and "/block" or fullName,fullName)
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

return M
