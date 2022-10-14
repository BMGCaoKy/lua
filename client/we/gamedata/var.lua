local Module = require "we.gamedata.module.module"
local Trigger = require "we.gamedata.trigger"

local M = {}

function M:init()
	self._page = ""
end

function M:page()
	return self._page
end

function M:set_page(page)
	self._page = page
end

function M:get_vars(page, type)
	local i = Module:module("game"):item("0")
	assert(i)
	local p = i:obj().vars[page]
	assert(p, page)
	local ret = {}
	for _, var in ipairs(p) do
		if not type or type == var.type then	--TODO 类型兼容
			if not var.run_type or Trigger:get_run_type() == var.run_type then
				table.insert(ret, var.key)
			end
		end
	end
	return ret
end	

function M:var_type(page, var_key)
	local i = Module:module("game"):item("0")
	assert(i)
	local p = i:obj().vars[page]
	assert(p, page)
	for _, v in ipairs(p) do
		if v.key == var_key then
			return v.type
		end
	end
end

function M:var_struct_type(page, var_key)
	local i = Module:module("game"):item("0")
	assert(i)
	local p = i:obj().vars[page]
	assert(p, page)
	for _, v in ipairs(p) do
		if v.key == var_key then
			return v.struct_type
		end
	end
end

M:init()

return M
