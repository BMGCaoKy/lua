local tray_class_bag = require "common.tray.class.tray_class_bag"

local M = Lib.derive(tray_class_bag)

function M:on_use(slot)
	local entity = assert(self:owner())

	local item = self._slots[slot]
	if not item then
		return false
	end
	
	local item_count = item:stack_count()
	if item_count <= 0 then
		return false
	end

	local buff = item:use_buff()
	if buff then
		local target = entity
		if buff.toTeam then
			target = entity:getTeam() or entity
		end
		target:addBuff(buff.cfg, buff.time)
	end

    if World.cfg.unlimitedRes then
        return true
    end

	item:set_stack_count(item_count - 1, entity)

	if entity.isPlayer then
		local fullName = item:full_name()
		local reason = "use_item"
		local args = {
			type = "item",
			name = fullName,
			reason = reason,
			count = -1,
		}
		entity:resLog(args)
		GameAnalytics.ItemFlow(entity, "", fullName, 1, false, reason, "")
	end

	if item:stack_count() <= 0 then
		self:remove_item(slot, true)
	end

	return true	
end


function M:on_drop(slot, item)
	assert(item)
	local entity = self:owner()
	Trigger.CheckTriggers(entity and entity:cfg(), "ENTER_EQUIPMEN", {obj1 = entity, item = self._generator and self._generator(slot)})
end


return M
