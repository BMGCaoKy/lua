local item_class = require "common.item_class"
local setting = require "common.setting"
local M = Lib.derive(item_class)

local blockModel = {}

function M:init(cfg, stack_count)
	item_class.init(self, cfg)

	self._stack_count = stack_count or 1
	self._block_id = nil
	self._equip_buff = nil
	self._equip_buffs = {} -- 此处新加一个不用原来的改的原因：是为了避免影响之前有重载/重写这个文件，导致参数对不上。
	self._item_values = {}

	self._monitor = nil
	self.vars = Vars.MakeVars("item", cfg)
end

function M:set_monitor(monitor)
	assert(not monitor or type(monitor) == "function")
	self._monitor = monitor
end

function M:on_modify()
	if self._monitor then
		pcall(self._monitor)
	end
end

function M:seri(save)
	local data = {}

	data.stack_count = self._stack_count
	data.block_id = self._block_id

	local vars = {}
	if save and self.vars then
		for k in pairs(self:save_vars() or {}) do
			vars[k] = self.vars[k]
		end
		data.vars = vars
	elseif self.vars then
		for k in pairs(self:sync_vars() or {}) do
			vars[k] = self.vars[k]
		end
		data.vars = vars
	end

	local values = {}
	if save and self._item_values then
		for k, v in pairs(self._item_values) do
			local def = Item.ValueDef[k]
			if def[3] then
				values[k] = v
			end
		end
		data.item_values = values
	elseif self._item_values then
		for k, v in pairs(self._item_values) do
			local def = Item.ValueDef[k]
			if def[1] then
				values[k] = v
			end
		end
		data.item_values = values
	end
	-- todo 验证是否可序列化， seri ?
	return data
end

local blockItemUseCfgStackCountMax = World.cfg.blockItemUseCfgStackCountMax
local function checkSetBlockItemMaxStackCount(self)
	if blockItemUseCfgStackCountMax then
		local stack_count_max = self:block_cfg().stack_count_max
		if stack_count_max and type(stack_count_max) == "number" and stack_count_max > 0 then
			self._cfg.stack_count_max = stack_count_max
		end
	end
end

function M:deseri(data)
	assert(data)
	self._stack_count = assert(data.stack_count)
	assert(self._stack_count >= 0)
	self._block_id = data.block_id
	if self._block_id and self._block_id > 0 then
		checkSetBlockItemMaxStackCount(self)
	end

	if data.vars then
		local vars = self.vars
		for k, v in pairs(data.vars) do
			vars[k] = v
		end
	end

	if data.item_values then
		self._item_values = Lib.copy(data.item_values)
	end

	self:on_modify()
end

function M:stack_count()
	return self._stack_count
end

function M:set_stack_count(count, player)
	if player then
		local isCanSet = {result = true}
		Trigger.CheckTriggers(player:cfg(), "IS_CAN_ITEM_COUNT", {obj1 = player, isCanSet = isCanSet, item = self, setCount = count})
		if not isCanSet.result then
			return
		end
	end

	assert(count <= self:stack_count_max() and count >= 0, count)
	self._stack_count = count

	self:on_modify()
end

function M:block_id()
	return self._block_id
end

function M:set_block_id(id)
	id = assert(tonumber(id))
	assert(id > 0, id)
	self._block_id = id
	-- 只有到这里才知道这个item到底是哪个block，才能拿到block的stack_count_max
	checkSetBlockItemMaxStackCount(self)

	self:on_modify()
end

function M:set_block(name)
	self:set_block_id(setting:name2id("block", name))
end

function M:setValue(key, value)
	local def = Item.ValueDef[key]
	self._item_values[key] = value
	if def[1] then
		self:on_modify()
	end
end

function M:getValue(key)
    local def = Item.ValueDef[key]
    local value = self._item_values[key]
    if value == nil then
        return def[2]
    else
        return value
    end
end

function M:set_buff_data(buff)
	assert(not self._equip_buff or not buff)
	self._equip_buff = buff
end

function M:add_buff_datas(buff)
	if not buff then
		print(" warning. add_buff_datas, the buff is nil. ")
		return
	end
	self._equip_buffs[#self._equip_buffs] = buff
end

function M:clear_buff_datas()
	self._equip_buffs = {}
end

function M:set_var(key, val)
	self.vars[key] = val
	self:on_modify()
end

function M:var(key)
	if not self.vars then
		return nil
	end
	return self.vars[key]
end

function M:buff_data()
	return self._equip_buff
end

function M:buff_datas()
	return self._equip_buffs
end

local function check_var_modify(self)
	for key in pairs(self.vars) do
		if key ~= "cfg" then
			return true
		end
	end

	return false
end

function M:check_same(item)
	if self:full_name() ~= item:full_name() then
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
	return true
end

function M:check_combine(item)
	if not self:check_same(item) then
		return false
	end

	if self:stack_count() + item:stack_count() > self:stack_count_max() then
		return false
	end

	if not self:can_combine() or not item:can_combine() then
		return false
	end
	return true
end

function M:combine(item)
	assert(self:check_combine(item))
	self:set_stack_count(self:stack_count() + item:stack_count())
end

function M:stack_free()
	return self:stack_count_max() - self:stack_count()
end

function M:levelBuff_data()
    return self._equip_levelBuff
end

function M:set_levelBuff_data(buff)
    assert(not self._equip_levelBuff or not buff)
	self._equip_levelBuff = buff
end

function M:block_cfg()
	if self:is_block() then
		return Block.GetIdCfg(self:block_id())
	end
	return
end

function M:add_stack_count(count, player)
	if player then
		local isCanSet = {result = true}
		Trigger.CheckTriggers(player:cfg(), "IS_CAN_ITEM_COUNT", {obj1 = player, isCanSet = isCanSet, item = self})
		if not isCanSet.result then
			return
		end
	end

	assert(count <= self:stack_free() and count >= 0, count)
	self._stack_count = self._stack_count + count

	self:on_modify()
end



return M
