local Module = require "we.gamedata.module.module"
local Meta = require "we.gamedata.meta.meta"
local Lang = require "we.gamedata.lang"

local M = {}

function M:init()
	local i = Module:module("game"):item("0")
	local maxIndex = 0
	for _, v in ipairs(i:obj()["commoditys"]) do
		if v.index.val > maxIndex then
			maxIndex = v.index.val
		end
	end

	Meta:meta("CommodityPageIndex"):set_processor(function()
		maxIndex = maxIndex + 1
		return { val = maxIndex }
	end)
end

function M:has_id(id)
	local i = Module:module("game"):item("0")
	local maxIndex = 0
	if i:data() then
		for _, v in ipairs(i:obj()["commoditys"]) do
			if v.index.val == id then
				return true
			end
		end
	end
end

function M:add_page(insert_index)
	local item = Module:module("game"):item("0")
	local i = item:data():insert("commoditys", insert_index)
	local meta = Meta:meta("CommodityPageIndex")
	local index = meta:process(item:obj()["commoditys"][i]["index"])
	local path = Lib.combinePath("commoditys", i)
	item:data():assign(path, "index", index)
end

function M:copy_page(index)
	local item = Module:module("game"):item("0")
	Meta:meta("Text"):set_processor(function(val)
		local id = Lang:copy_text(val.value)
		return { value = id }
	end)
	local meta = Meta:meta("CommodityPage")
	local val = meta:process(item:obj()["commoditys"][index])
	item:data():insert("commoditys", index + 1, nil, val)
	Meta:meta("Text"):set_processor(nil)
end

function M:copy_commodity(pageIndex, commodityIndex)
	local item = Module:module("game"):item("0")
	Meta:meta("Text"):set_processor(function(val)
		local id = Lang:copy_text(val.value)
		return { value = id }
	end)
	local meta = Meta:meta("CommodityItem")
	local val = meta:process(item:obj()["commoditys"][pageIndex]["items"][commodityIndex])
	local path = Lib.combinePath("commoditys", pageIndex, "items")
	item:data():insert(path, commodityIndex + 1, nil, val)
	Meta:meta("Text"):set_processor(nil)
end

M:init()

return M
