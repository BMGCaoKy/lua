local MetaBase = require "we.gamedata.meta.class.meta_base"

local M = Lib.derive(MetaBase)

function M:init(conf, meta_set)
	MetaBase.init(self, conf, meta_set)
end

function M:ctor(val, arg, attrs)
	local ret = 0

	if type(val) == "number" then
		ret = val
	elseif type(arg) == "number" then
		ret = arg
	end

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

	if _G.type(val) ~= "number" then
		errmsg = string.format("number val is invalid: %s", _G.type(val))
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

return M
