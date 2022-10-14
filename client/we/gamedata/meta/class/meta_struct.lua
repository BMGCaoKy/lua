local Def = require "we.def"
local MetaBase = require "we.gamedata.meta.class.meta_base"

local M = Lib.derive(MetaBase)

function M:init(conf, meta_set)
	MetaBase.init(self, conf, meta_set)
	self._default = nil
end

-- args 是上层传入的构造参数
function M:ctor(val, args, attrs, no_copy)
	val = val or {}
	if not no_copy then
		val = Lib.copy(val)
	end
	
	local ret = val	-- 保留原来的值

	args = args or {}
	assert(type(args) == "table")

	attrs = attrs or {}
	assert(type(attrs) == "table")

	if self._conf.base then
		for _, arg in ipairs(self._conf.base.ctor_args or {}) do
			args[arg.identifier] = args[arg.identifier] or arg
		end

		local meta = assert(self._meta_set:meta(self._conf.base.type), self._conf.base.type)
		ret = meta:ctor(val, args, attrs, true)
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
			assert(not arg or _G.type(arg) == "table", tostring(type))
			return vmeta:ctor(val, arg and arg.ctor_args, attrs, true)
		else
			return vmeta:ctor(val, arg, attrs, true)
		end
	end

	for _, mc in ipairs(self._conf.member or {}) do
		local _args
		if args[mc.identifier] and _G.type(args[mc.identifier].value) ~= "nil" then
			_args = args[mc.identifier].value
		else
			_args = mc.value
		end

		local _val = val[mc.identifier]
		if mc.array then
			ret[mc.identifier] = ret[mc.identifier] or {}
			local count = math.max(mc.array, (_val and #_val) or (_args and #_args) or 0)
			for i = 1, count do
				ret[mc.identifier][i] = ctor_member(self, mc.type, _val and _val[i], _args and _args[i], mc.attribute)
			end
		else
			ret[mc.identifier] = ctor_member(self, mc.type, _val, _args, mc.attribute)
		end
	end

	ret[Def.OBJ_TYPE_MEMBER] = self._conf.name

	return ret
end

function M:process_(val, info)
	if self._conf.base then
		local meta = assert(self._meta_set:meta(self._conf.base.type), self._conf.base.type)
		val = meta:process(val, info)
	end

	local function process_member(type, val, info)
		if _G.type(val) == "nil" then
			return
		end

		if _G.type(val) == "table" then
			type = val[Def.OBJ_TYPE_MEMBER] or type
		end

		local meta = self._meta_set:meta(type)
		if meta then
			return meta:process(val, info)
		else
			return val
		end
	end

	for _, mc in ipairs(self._conf.member or {}) do
		local _val = val and val[mc.identifier]
		if mc.array then
			if _G.type(_val) == "table" then
				for i = 1, #_val do
					val[mc.identifier][i] = process_member(mc.type, _val[i], info)
				end
			end
		else
			val[mc.identifier] = process_member(mc.type, _val, info)
		end
	end

	return val
end


function M:verify(val, strict, info)
	if self:name() == "T_TipType" then
		return true
	end
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
					table.insert(info, 1, i)
					table.insert(info, 1, mc.identifier)
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
		return false, string.format("%s:%s|name:%s", table.concat(info, "/"), info.errmsg, self:name())
	end
end

function M:monitor(key)
	if self._conf.monitor[key] then
		return self._conf.monitor[key].func_monitor, self:base()
	end

	if self._conf.base then
		local meta = self._meta_set:meta(self._conf.base.type)
		return meta:monitor(key)
	end
end

function M:initializer()
	return self._conf.init
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
		value = self:default()
	}
end

-- inherit from
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

function M:is(type)
	if _G.type(type) == "table" then
		type = type:name()
	end

	if self:name() == type then
		return true
	end

	return self:inherit(type)
end

function M:default()
	if not self._default then
		self._default = self:ctor()
	end

	return self._default
end

function M:diff(val_d, val_s, store)
	if not val_d then
		return
	end
	assert(_G.type(val_d) == "table")

	repeat
		if val_s then
			local meta = self._meta_set:meta(val_s[Def.OBJ_TYPE_MEMBER])
			if meta:name() == self:name() then
				break
			end
			if meta:inherit(self:name()) then
				break
			end
		end

		val_s = self:default()
	until(true)
	local ret = {}

	if self._conf.base then
		local meta = self._meta_set:meta(self._conf.base.type)
		ret = meta:diff(val_d, val_s, store) or {}
	end

	for _, mc in ipairs(self._conf.member or {}) do
		local _val_d = val_d and val_d[mc.identifier]
		local _val_s = val_s[mc.identifier]

		assert(_G.type(_val_s) ~= "nil", mc.identifier)

		if _val_d == nil then
			goto CONTINUE
		end

		if store and mc.attribute[Def.ATTR_KEY_STORE] == "0" then
			goto CONTINUE
		end

		if mc.array then
			assert(_G.type(_val_d) == "table")
			assert(_G.type(_val_s) == "table")

			local array = {}
			local changed = #_val_d ~= #_val_s
			for i = 1, #_val_d do
				local type = mc.type
				if _G.type(_val_d[i]) == "table" then
					type = _val_d[i][Def.OBJ_TYPE_MEMBER] or type
				end
				local meta = self._meta_set:meta(type)
				local diff = meta:diff(_val_d[i], _val_s[i], store)
				if not diff then
					if meta:specifier() == "struct" then
						array[i] = {}
					else
						array[i] = mc.value
					end
				else
					array[i] = diff
					changed = true
				end

				if type ~= mc.type then
					assert(meta:specifier() == "struct")
					array[i][Def.OBJ_TYPE_MEMBER] = type
					changed = true
				end
			end

			if changed then
				ret[mc.identifier] = array
			end
		else
			local type = mc.type
			if _G.type(_val_d) == "table" then
				type = _val_d[Def.OBJ_TYPE_MEMBER] or type
			end
			local meta = self._meta_set:meta(type)
			ret[mc.identifier] = meta:diff(_val_d, _val_s, store)
			if type ~= mc.type then
				ret[mc.identifier] = ret[mc.identifier] or {}
				ret[mc.identifier][Def.OBJ_TYPE_MEMBER] = type
			end
		end
		::CONTINUE::
	end

	return next(ret) and ret
end

function M:next_member()
	local iter_base
	if self._conf.base then
		local meta = self._meta_set:meta(self._conf.base.type)
		iter_base = meta:next_member()
	end

	local i = 0
	return function()
		if iter_base then
			local name, type, array, attrs = iter_base()
			if name then
				return name, type, array, attrs
			end
		end

		i = i + 1
		local mc = self._conf.member[i]
		if mc then
			return mc.identifier, mc.type, mc.array, mc.attribute
		end
	end
end

function M:base()
	return self._conf.base and self._conf.base.type
end

function M:attribute(name, member)
	if not member then
		return MetaBase.attribute(self, name)
	end

	for identifier, _, _, attrs in self:next_member() do
		if identifier == member then
			return attrs and attrs[name]
		end
	end
end

return M
