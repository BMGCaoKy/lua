local Meta = require "we.gamedata.meta.meta"

local M = {}

function M:list()
	local ret = {}

	local meta_set = Meta:meta_set()
	local widget_sequence = meta_set:widget_sequence()
	for type,meta in pairs(widget_sequence) do
		table.insert(ret,{
			value = meta,
			attrs = {}
		})
	end

	return ret
end

return M