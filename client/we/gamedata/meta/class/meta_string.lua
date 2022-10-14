local Def = require "we.def"
local MetaBase = require "we.gamedata.meta.class.meta_base"
local Attr = require "we.gamedata.attr"

local M = Lib.derive(MetaBase)

function M:init(conf, meta_set)
	MetaBase.init(self, conf, meta_set)
end

function M:ctor(val, arg, attrs)
	attrs = attrs or {}

	local ret = val or arg

	if not ret then
		local uuid = Attr.to_bool(attrs[Def.ATTR_KEY_STRING_UUID], false)
		if uuid then
			ret = GenUuid()
		else
			ret = ""
		end
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

	if _G.type(val) ~= "string" then
		errmsg = string.format("string val is invalid: %s", _G.type(val))
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
