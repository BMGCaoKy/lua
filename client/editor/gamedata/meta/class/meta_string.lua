local Def = require "editor.def"
local MetaBase = require "editor.gamedata.meta.class.meta_base"
local Attr = require "editor.gamedata.attr"

local M = Lib.derive(MetaBase)

function M:init(conf, meta_set)
	MetaBase.init(self, conf, meta_set)
end

function M:ctor(val, arg, attrs)
	attrs = attrs or {}

	local ret = ""

	if type(arg) == "string" then
		ret = arg
	end

	if not val then
		local uuid = Attr.to_bool(attrs[Def.ATTR_KEY_STRING_UUID], false)
		if uuid then
			ret = GenUuid()
		end
	else
		ret = val
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
