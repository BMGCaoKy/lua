local item_manager = require "item.item_manager"

local M = L("M", {})

function M:init(pos)
	self._pos = assert(pos)
    self._trays = {}
	self._gid = 0
    local tray_obj = Tray:new_tray(Define.TRAY_TYPE.BAG, 54, true)
    self:add_tray(tray_obj)
end

function M:add_tray(obj)
	assert(obj)
	local tid = self._gid + 1
	self._gid = tid
	self._trays[tid] = obj
	return tid
end

function M:fetch_tray(tid)
	return self._trays[tid]
end

function M:add_item_data(item_data, just_check)
	local ret = false

	if not just_check then
		assert(self:add_item_data(item_data, true))
	end

	local max_count = item_data:stack_count_max()
	local left_count = item_data:stack_count()
	local seri_data = item_manager:seri_item(item_data)

	local tray = self:fetch_tray(1)

	for i = 1,tray:capacity() do 
		local slot_item = tray:fetch_item(i)
		if slot_item then 
			local check_item = item_manager:deseri_item(seri_data)
			check_item:set_stack_count(1)
			if not slot_item:check_combine(check_item) then
				goto continue
			end
			local free_count = slot_item:stack_free()
			local add_count = math.min(free_count, left_count)
			if not just_check then -- settle as much item as possible
				slot_item:set_stack_count(slot_item:stack_count() + add_count)
			end
			left_count = left_count - add_count
			if left_count <= 0 then
				return true
			end
		end
	end

	for i = 1, tray:capacity() do
		local slot_item = tray:fetch_item(i)
		if not slot_item then -- found a free slot
			local add_count = math.min(max_count, left_count)
			if not just_check then -- settle as much item as possible
				local item = item_manager:deseri_item(seri_data)
				item:set_stack_count(add_count)
				tray:settle_item(i, item)
			end
			left_count = left_count - add_count
			if left_count <= 0 then
				return true
			end
		else -- check if current slot can combine
			local check_item = item_manager:deseri_item(seri_data)
			check_item:set_stack_count(1)
			if not slot_item:check_combine(check_item) then
				goto continue
			end
			local free_count = slot_item:stack_free()
			local add_count = math.min(free_count, left_count)
			if not just_check then -- settle as much item as possible
				slot_item:set_stack_count(slot_item:stack_count() + add_count)
			end
			left_count = left_count - add_count
			if left_count <= 0 then
				return true
			end
			::continue::
		end
	end

	return false
end

function M:add_item(full_name, count, just_check)
	count = count or 1

	local item_data = item_manager:new_item(full_name, count)
	assert(item_data, full_name)

	return self:add_item_data(item_data, just_check)
end

RETURN(M)
