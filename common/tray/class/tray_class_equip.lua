local tray_class_base = require "tray.class.tray_class_base"
local item_manager = require "item.item_manager"

local M = Lib.derive(tray_class_base)

function M:init(type, capacity, system)
	tray_class_base.init(self, type, capacity, Define.TRAY_CLASS_EQUIP, system)

	return true
end

local function check_prop_cond(entity, cond)
    cond = cond or {}
    if next(cond) then
        for _, val in ipairs(cond) do
            if entity:prop(val.key) < val.value then
                return false, val.key
            end
        end
    else
	    for key, val in pairs(cond) do
		    if entity:prop(key) < val then
			    return false, key
		    end
	    end
    end

	return true
end

function M:check_pick(slot)

	local item = self:fetch_item(slot)
	if not item then
		return true
	end

	local entity = self:owner()
	assert(entity)

	local ret, key = check_prop_cond(entity, item:equip_cond())
	if not ret then
		return false, key
	end

	return true
end

function M:check_drop(item)
	local entity = self:owner()
	assert(entity)

    if not tray_class_base.check_drop(self, item) then
        return false
    end

    local slot

    if item then
        local ret, key = check_prop_cond(entity, item:equip_cond())
        if not ret then
            return false, key
        end

        slot = self:find_free()
        if not slot then
            slot = self:check_replace()
            if not slot then
                return false, "not_slot"
            end
        end
    end

	return true, slot
end

function M:on_drop(slot, item)
	assert(item)

	local entity = self:owner()
	assert(entity)

	local buff_cfg = item:equip_buff()
	if buff_cfg then
		if not item:cfg().canEquipPlural then
			item:set_buff_data(entity:addBuff(buff_cfg))
		else
			for i = 1, item:stack_count() do
				item:add_buff_datas(entity:addBuff(buff_cfg))
			end
		end
	end

	local skin_cfg = item:equip_skin()
	if skin_cfg then
		entity:changeSkin(skin_cfg)
	end

    local curLevel = item:getValue("curLevel")
    local levelBuff = item:equip_levelBuff(curLevel)
    if levelBuff then
        local buff = entity:addBuff(levelBuff)
        item:set_levelBuff_data(buff)
    end

    local level_skin_cfg = item:equip_levelSkin(curLevel)
	if level_skin_cfg then
		entity:changeSkin(level_skin_cfg)
	end

	entity:syncSkillMap()

	local _item = self._generator(slot)
	Trigger.CheckTriggers(
		entity:cfg(),
		"WEAR_EQUIPMEN",
		{
			obj1 = entity,
			item = _item,
			type = self:type()
		})
	entity:EmitEvent("OnWearEquipment", _item)
end

function M:on_pick(slot, item)
	assert(item)

	local entity = self:owner()
	assert(entity)

	local buff = item:buff_data()
	if buff then
		item:set_buff_data(nil)
		entity:removeBuff(buff)
	end

	local buffs = item:buff_datas()
	if next(buffs) then
		item:clear_buff_datas()
		for _, buff in pairs(buffs) do
			entity:removeBuff(buff)
		end
	end

    local levelBuff = item:levelBuff_data()
    if levelBuff then
        item:set_levelBuff_data(nil)
		entity:removeBuff(levelBuff)
    end

	local skin_cfg = item:equip_skin()
	if skin_cfg then
		local tmp = {}
		for k, v in pairs(skin_cfg) do
			tmp[k] = ""
		end

		entity:changeSkin(tmp, "all")
	end

    local curLevel = item:getValue("curLevel")
    local levelSkin_cfg = item:equip_levelSkin(curLevel)
    if levelSkin_cfg then
        local tmp = {}
		for k, v in pairs(levelSkin_cfg) do
			tmp[k] = ""
		end

		entity:changeSkin(tmp, "all")
    end

	entity:syncSkillMap()

	Trigger.CheckTriggers(
		entity:cfg(),
		"TAKEOFF_EQUIPMEN",
		{
			obj1 = entity,
			itemData = item,
			item = Item.DeseriItem(item_manager:seri_item(item)),
			type = self:type()
		}
	)
end

function M:check_replace()
    return 1
end

return M