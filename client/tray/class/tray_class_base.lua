local tray_class_base = require "common.tray.class.tray_class_base"
local item_manager = require "item.item_manager"

local M = Lib.derive(tray_class_base)

function M:deseri_item(packet)
	if not packet then
		return
	end

	for slot, item_data in pairs(packet or {}) do
		local item = item_manager:deseri_item(item_data)
		self:settle_item(slot, item)
	end
end

function M:deseri_item_with_clean(packet)
	if not packet then
		return
	end
	self:deseri_item(packet)
	for slot = #packet + 1, self:capacity() do
		self:remove_item(slot)
	end
end

function M:settle_item(slot, item)
	self._slots[slot] = item
	local entity = self:owner()
	if entity then
		entity:EmitEvent("OnItemAdded", self, item)
	end
	self:on_drop(slot, item)
end

return M
