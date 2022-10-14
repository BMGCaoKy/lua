local setting = require "common.setting"
local item_data = require "item.item_data"
local item_class = require "common.item_class"
local random = math.random
local item_manager = require "item.item_manager"	-- todo

local CfgMod = setting:mod("item")

local function init_obj(self, type, ...)
	self._type = type
	
	self._tid = nil
	self._slot = nil
	self._entity = nil
	self._item_data = nil

	if type == Define.ITEM_OBJ_TYPE_SETTLED then
		self._entity, self._tid, self._slot = ...
	else
		assert(type == Define.ITEM_OBJ_TYPE_ISOLATED)
		self._item_data = ...
	end

	self._init = true
end
local ValueDef = T(Item, "ValueDef")
				--				canSync,	init		saveDB
ValueDef.currentCapacity 	= {	true,		nil,		true}
ValueDef.extCapacity 		= {	true,		0,		    true}
ValueDef.curLevel			= {	true,		0,			true}

function Item:data()
	if self._type == Define.ITEM_OBJ_TYPE_SETTLED then
		local tray = self._entity:data("tray"):fetch_tray(self._tid)
		if not tray then
			return
		end

		local item_data = tray:fetch_item(self._slot)
		if not item_data then
			return
		end

		return item_data
	else
		assert(self._type == Define.ITEM_OBJ_TYPE_ISOLATED)
		return self._item_data
	end
end

function Item:null()
	return self:data() == nil
end

function Item:tid()
	assert(self._type == Define.ITEM_OBJ_TYPE_SETTLED)
	return self._tid
end

function Item:slot()
	assert(self._type == Define.ITEM_OBJ_TYPE_SETTLED)
	return self._slot
end

function Item:replace(fullName)
	if self._type == Define.ITEM_OBJ_TYPE_SETTLED then
		local tray = self._entity:data("tray"):fetch_tray(self._tid)
		if not tray then
			return false
		end
		local oitem = tray:remove_item(self._slot)
		local item_data = oitem and oitem:seri()
		local item = item_manager:new_item(fullName)
		if item_data then
			item:deseri(item_data)
		end
		tray:settle_item(self._slot, item)
	else
		assert(self._type == Define.ITEM_OBJ_TYPE_ISOLATED)
		local item_data = self._item_data
		local item = item_manager:new_item(fullName)
		item:deseri(item_data)
	end
end

function Item:checkConsume(count)
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

	--todo: check Trigger??
	return true
end

function Item:consume(count)
	count = count or 1
	assert(count > 0, count)

	local item_data = self:data()
	if not item_data then
		return false
	end

    if World.cfg.unlimitedRes then
        return true
    end

	local stack_count = item_data:stack_count()
	if stack_count < count then
		return false
	end

	item_data:set_stack_count(stack_count - count, self._entity)
	if item_data:stack_count() <= 0 then
		if self._type == Define.ITEM_OBJ_TYPE_SETTLED then
			local tray = self._entity:data("tray"):fetch_tray(self._tid)
			if not tray then
				return false
			end
			tray:remove_item(self._slot, true)
		end
	end

	return true
end

function Item:setVar(key, val)
	local item_data = self:data()
	if not item_data then
		return false
	end

	item_data:set_var(key, val)

	return true
end

function Item:getVar(key)
	local item_data = self:data()
	return item_data and item_data:var(key)
end

function Item:seri()
	local item_data = self:data()
	if not item_data then
		return false
	end

	return item_manager:seri_item(item_data)
end

function Item:getValue(key)
	local def = Item.ValueDef[key]
	local item_data = self:data() or {}
	local value = item_data._item_values[key]
	if value == nil then
		return def[2]
	else
		return value
	end
end

local function createObj()
	return setmetatable({}, {
		__index = function(obj, key)
			return Item[key] or obj:data() and obj:data()[key]
		end,
		__newindex = function(obj, key, val)
			if rawget(obj, "_init") then
				local data = obj:data()
				if not data then
					error(string.format("can't set nil item: %s", key))
				end
				data[key] = val
			else
				rawset(obj, key, val)
			end
		end
	})
end

-- 根据 fullName 创建一个 item
function Item.CreateItem(fullName, count, func)
	if type(count) == "table" then
		count = random(count[1], count[2])
	end
	local item_data = item_manager:new_item(fullName, count)
	assert(item_data, fullName)
	if func then
		func(item_data)
	end

	local obj = createObj()
	init_obj(obj, Define.ITEM_OBJ_TYPE_ISOLATED, item_data)

	return obj
end

-- 根据 fullName 创建一个 item ,仅用于settle_item
function Item.new(fullName, count)
	local obj = Item.CreateItem(fullName, count)
	return obj:data()
end

-- 根据 fullName 创建一个 blockItem ，仅用于settle_item
function Item.newBlock(fullName, count)
	local obj = Item.CreateBlockItem(fullName, count)
	return obj:data()
end

-- 根据 fullName 创建一个 blockItem
function Item.CreateBlockItem(fullName, count)
	assert(fullName, "fullName is null !")
	count = count or 1
	local item_data = item_manager:new_item("/block", count)
	assert(item_data, "block:".. fullName)
	item_data:set_block(fullName)
	local obj = createObj()
	init_obj(obj, Define.ITEM_OBJ_TYPE_ISOLATED, item_data)
	return obj
end

-- 根据背包位置创建 item
function Item.CreateSlotItem(entity, tid, slot)
	assert(entity and tid and slot)
	assert(tid > 0 and slot > 0)

	local obj = createObj()
	init_obj(obj, Define.ITEM_OBJ_TYPE_SETTLED, entity, tid, slot)

	return obj
end

-- 根据数据流创建 item
function Item.DeseriItem(data)
	assert(data)

	local item_data = item_manager:deseri_item(data)
	assert(item_data, Lib.v2s(data))

	local obj = createObj()
	init_obj(obj, Define.ITEM_OBJ_TYPE_ISOLATED, item_data)

	return obj
end

function CfgMod:onLoad(cfg, reload)
	if reload then
		for _, dropItem in ipairs(World.CurWorld:getAllDropItem()) do
			if dropItem:data("item"):cfg() == cfg then
				dropItem:onItemCfgChanged()
			end
		end
	end
end


local function init()
	local cfgBlock = {
		id = 1000,
		fullName = "/block",
		stack_count_max = 64,
		catalog = 1,
		canUse = false,
		isBlock = true,
	}
	CfgMod:set(cfgBlock)

	local cfgEmpty = {
		id = 0,
		fullName = "/empty",
		stack_count_max = 0,
	}
	CfgMod:set(cfgEmpty)
end

init()
