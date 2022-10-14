local M = require "item.item_data"

local function check_var_modify(self)
	for key in pairs(self.vars) do
		if key ~= "cfg" and key ~= "attachVar" then
			return true
		end
	end

	return false
end

function M:check_combine(item)
	if self:full_name() ~= item:full_name() then
		return false
	end

	if self:stack_count() + item:stack_count() > self:stack_count_max() then
		return false
	end

	if self:block_id() ~= item:block_id() then
		return false
	end

	if self:buff_data() or item:buff_data() then
		return false
	end

	if check_var_modify(self) then
		return false
	end

	if not self:can_combine() or not item:can_combine() then
		return false
	end
	return true
end
