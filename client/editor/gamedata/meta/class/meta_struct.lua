local Def = require "editor.def"
local MetaBase = require "editor.gamedata.meta.class.meta_base"

local M = Lib.derive(MetaBase)

function M:init(conf, meta_set)
	MetaBase.init(self, conf, meta_set)
end

-- args 是上层传入的构造参数，attrs 是上层传入的特性, uncompleting 表示不补全，默认是补全
function M:ctor(val, args, attrs, uncompleting)
	local ret = {}

	val = val or {}
	assert(self:verify(val))

	args = args or {}
	assert(type(args) == "table")

	attrs = attrs or {}
	assert(type(attrs) == "table")

	if self._conf.base then
		local meta = assert(self._meta_set:meta(self._conf.base.type), self._conf.base.type)

		local mix_args = {}
		for _, arg in ipairs(self._conf.base.ctor_args or {}) do
			mix_args[arg.identifier] = arg
		end
		
		for identifier, arg in pairs(args) do
			mix_args[identifier] = arg
		end

		ret = meta:ctor(val, mix_args, attrs, uncompleting)
	end

	local function ctor_member(self, type, val, arg, attrs)
		local meta = assert(self._meta_set:meta(type), type)
		if meta:specifier() == "struct" then
			type = arg and arg.type or type
		end

		if _G.type(val) == "table" then
			type = val[Def.OBJ_TYPE_MEMBER] or type
		end

		local vmeta = assert(self._meta_set:meta(type), type)
		if vmeta:specifier() == "struct" then
			return vmeta:ctor(val, arg and arg.ctor_args, attrs, uncompleting)
		else
			return vmeta:ctor(val, arg, attrs, uncompleting)
		end
	end

	for _, mc in ipairs(self._conf.member or {}) do
		local _args = args[mc.identifier] and args[mc.identifier].value or mc.value
		local _val = val[mc.identifier]

		if _val or (not uncompleting) then
			if mc.array then
				ret[mc.identifier] = ret[mc.identifier] or {}
				local count = math.max(mc.array, (_val and #_val) or (_args and #_args) or 0)
				for i = 1, count do
					if _val and _val[i] or (not uncompleting) then
						ret[mc.identifier][i] = ctor_member(self, mc.type, _val and _val[i], _args and _args[i], mc.attribute)
					end
				end
			else
				ret[mc.identifier] = ctor_member(self, mc.type, _val, _args, mc.attribute)
			end
		end
	end

	ret[Def.OBJ_TYPE_MEMBER] = self._conf.name

	assert(self:verify(ret, not uncompleting))
	return ret
end

function M:process_(val, info)
	local ret = {}

	if self._conf.base then
		local meta = assert(self._meta_set:meta(self._conf.base.type), self._conf.base.type)
		ret = meta:process(val, info)
	end
	
	local function process_member(type, val, info)
		if _G.type(val) == "table" then
			type = val[Def.OBJ_TYPE_MEMBER] or type
		end

		local meta = assert(self._meta_set:meta(type), type)
		return meta:process(val, info)
	end

	for _, mc in ipairs(self._conf.member or {}) do
		local _val = val and val[mc.identifier]
		if type(_val) ~= "nil" then
			if mc.array then
				assert(type(_val) == "table")
				ret[mc.identifier] = {}
				for i = 1, #_val do
					ret[mc.identifier][i] = process_member(mc.type, _val[i], info)
				end
			else
				ret[mc.identifier] = process_member(mc.type, _val, info)
			end
		end
	end

	ret[Def.OBJ_TYPE_MEMBER] = self._conf.name
	return ret
end

function M:verify(val, strict, info)
	info = info or {errmsg = ""}

	local function verify_member(type, val, strict, info)
		if _G.type(val) == "nil" then
			if strict then
				info.errmsg = string.format("struct val is nil")
				return false
			else
				return true
			end
		end

		if _G.type(val) == "table" then
			type = val[Def.OBJ_TYPE_MEMBER] or type
		end

		local meta = self._meta_set:meta(type)
		if not meta then
			info.errmsg = string.format("type is invalid : %s", type)
			return false
		end

		return meta:verify(val, strict, info)
	end

	local ret = false

	if not val then
		if strict then
			info.errmsg = string.format("struct val is nil")
			goto Exit0
		else
			goto Exit1
		end
	end

	if _G.type(val) ~= "table" then
		info.errmsg = string.format("struct val is invalid %s", _G.type(val))
		goto Exit0
	end

	if self._conf.base then
		local meta = assert(self._meta_set:meta(self._conf.base.type), self._conf.base.type)
		if not meta:verify(val, strict, info) then
			goto Exit0
		end
	end

	for _, mc in ipairs(self._conf.member or {}) do
		local _val = val and val[mc.identifier]
		if mc.array then
			local count = math.max(mc.array, _val and #_val or 0)
			for i = 1, count do
				if not verify_member(mc.type, _val and _val[i], strict, info) then
					table.insert(info, 1, mc.identifier)
					table.insert(info, 1, i)
					goto Exit0
				end
			end
		else
			if not verify_member(mc.type, _val, strict, info) then
				table.insert(info, 1, mc.identifier)
				goto Exit0
			end
		end
	end

::Exit1::
	ret = true
::Exit0::
	if ret then
		return true
	else
		return false, string.format("%s:%s", table.concat(info, "/"), info.errmsg)
	end
end

function M:monitor(key)
	return self._conf.monitor[key] and self._conf.monitor[key].func_monitor
end

function M:member(key)
	local type = nil
	local array = false
	local attrs = nil

	if self._conf.base then
		local meta = self._meta_set:meta(self._conf.base.type)
		type, array, attrs = meta:member(key)
	end

	for _, mc in ipairs(self._conf.member or {}) do
		if key == mc.identifier then
			type = mc.type
			array = mc.array
			attrs = mc.attribute
			break
		end
	end

	return type, array, attrs or {}
end

function M:info()
	if not self._value then
		self._value = self:ctor()
	end

	local member = {}
	for _, mc in ipairs(self._conf.member or {}) do
		table.insert(member, {
			type = mc.type,
			identifier = mc.identifier,
			array = mc.array,
			attrs = mc.attribute
		})
	end

	return {
		base = self._conf.base and self._conf.base.type,
		attrs = self._conf.attribute,
		member = member,
		value = self._value
	}
end

function M:inherit(base)
	assert(base)

	if not self._conf.base then
		return false
	end

	if self._conf.base.type == base then
		return true
	end

	return self._meta_set:meta(self._conf.base.type):inherit(base)
end

return M
