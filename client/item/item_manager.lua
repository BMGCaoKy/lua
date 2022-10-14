local setting = require "common.setting"
local item_data = require "item.item_data"
local item_class = require "common.item_class"

local M = {}

function M:new_item(fullname, stack_count)
	local cfg = setting:fetch("item", fullname)
	assert(cfg, tostring(fullname))
	local obj = Lib.derive(item_data)
	obj:init(cfg, stack_count)
	return obj
end

function M:seri_item(item)
	return {
		fullname = item:full_name(),
		rawdata = item:seri()
	}
end

function M:deseri_item(data)
	local obj = self:new_item(data.fullname)
	obj:deseri(data.rawdata)
	return obj
end


return M
