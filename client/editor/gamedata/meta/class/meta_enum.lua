local MetaBase = require "editor.gamedata.meta.class.meta_base"

local M = Lib.derive(MetaBase)

function M:init(conf, meta_set)
	MetaBase.init(self, conf, meta_set)
end

function M:ctor(val, arg, attrs)
	local ret = ""

	if type(val) == "string" then
		ret = val
	elseif type(arg) == "string" then
		ret = arg
	end

	assert(self:verify(ret, true))
	return ret
end

function M:verify(val, strict, info)
	info = info or {}
	local errmsg

	local ret = false

	if type(val) == "nil" then
		if strict then
			errmsg = string.format("string val is nil")
			goto Exit0
		else
			goto Exit1
		end
	end

	if _G.type(val) ~= "string" then
		errmsg = string.format("enum val is invalid: %s", _G.type(val))
		goto Exit0
	end

::Exit1::
	ret = true
::Exit0::
	if ret then
		return true
	else
		info.errmsg = errmsg

		return false
	end
end

function M:list()
	local constant = {}
	for _, c in ipairs(self._conf.constant or {}) do
		table.insert(constant, {
			v = c.value,
			attrs = c.attribute
		})
	end

	if self._conf.func_list then
		local func = load(
			self._conf.func_list,
			"",
			"bt"
		)
		for _, c in ipairs(func() or {}) do
			table.insert(constant, {
				v = c.value,
				attrs = c.attrs
			})
		end	
	end

	return constant
end

function M:info()
	return {
		attrs = self._conf.attribute,
		constant = self:list()
	}
end

return M
