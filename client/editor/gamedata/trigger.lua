local Meta = require "editor.gamedata.meta.meta"

local M = {}

function M:list()
	local ret = {}

	local meta_set = Meta:meta_set()
	local list = meta_set:list()
	for type, meta in pairs(list) do
		if meta:specifier() == "struct" and meta:inherit("Trigger_Base") then
			table.insert(ret, {
				value = meta:name(),
				attrs = {}
			})
		end
	end

	return ret
end

return M
