local item_class = require "common.item_class"
local setting = require "common.setting"

local M = Lib.derive(item_class)

function M:init(cfg, stack_count)
	item_class.init(self, cfg)

	self._stack_count = stack_count or 1
	self._block_id = nil

end

function M:deseri(data)
	self._stack_count = assert(data.stack_count)
	self._block_id = data.block_id
	if data.vars then
		self._vars = Lib.copy(data.vars)
	end

	if data.item_values then
		self._item_values = Lib.copy(data.item_values)
	end
end

function M:stack_count()
	return self._stack_count
end

function M:set_stack_count(count)
	self._stack_count = count
end

function M:block_id()
	return self._block_id
end

function M:block_cfg()
	if self:is_block() then
		local cfg = setting:fetch("block", setting:id2name("block", self:block_id()))
		return cfg
	end
	return
end

local blockItemUseCfgStackCountMax = World.cfg.blockItemUseCfgStackCountMax
function M:set_block_id(id)
	id = assert(tonumber(id))
	assert(id > 0, id)
	self._block_id = id
	if blockItemUseCfgStackCountMax then
		local stack_count_max = self:block_cfg().stack_count_max
		if stack_count_max and type(stack_count_max) == "number" and stack_count_max > 0 then
			self._cfg.stack_count_max = stack_count_max
		end
	end
end

function M:set_block(name)
	local id = setting:name2id("block", name)
	if id == nil then
		return
	end
	self:set_block_id(id)
end

function M:setValue(key, value)
	self._item_values[key] = value
end

function M:check_combine(item)
	if self:full_name() ~= item:full_name() then
		return false
	end

	if self:block_id() ~= item:block_id() then
		return false
	end

	return true
end

function M:model(act)
	local model = item_class.model(self, act)
	if not model and self:is_block() then
		model = item_class.block_model(self, self._block_id)
	end

	return model
end

function M:icon()
	if not self:is_block() then
		return item_class.icon(self)
	end

	return item_class.block_icon(self, self._block_id)
end

function M:var(key)
	if not self._vars then
		return nil
	end

	return self._vars[key]
end

return M
