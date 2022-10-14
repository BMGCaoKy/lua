
function Item:consumeForce(count)
	count = count or 1
	assert(count > 0, count)

	local item_data = self:data()
	if not item_data then
		return false
	end

	local stack_count = item_data:stack_count()
	if stack_count < count then
		return false
	end

	item_data:set_stack_count(stack_count - count)
	if item_data:stack_count() <= 0 then
		if self._type == Define.ITEM_OBJ_TYPE_SETTLED then
			local tray = self._entity:data("tray"):fetch_tray(self._tid)
			if not tray then
				return false
			end
			tray:remove_item(self._slot)
		end
	end

	return true
end