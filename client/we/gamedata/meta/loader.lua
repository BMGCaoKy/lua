local Def = require "we.def"
local lpeg = require "lpeg"

local P = lpeg.P
local B = lpeg.B
local R = lpeg.R
local S = lpeg.S
local V = lpeg.V

local C = lpeg.C
local Carg = lpeg.Carg
local Cb = lpeg.Cb
local Cc = lpeg.Cc
local Cf = lpeg.Cf
local Cg = lpeg.Cg
local Cp = lpeg.Cp
local Cs = lpeg.Cs
local Ct = lpeg.Ct
local Cmt = lpeg.Cmt

local EOF           = P(-1)
local DIGIT         = R("09")
local ALPHA         = R("az") + R("AZ")
local PNAME         = ALPHA + P("_")
local NAME          = PNAME * (DIGIT + PNAME)^0

local BLANK         = S(" \t")
local BLANKS0       = BLANK^0
local BLANKS1       = BLANK^1
local NEWLINE       = P("\r")^-1 * P("\n") * Cmt(B("\n") * Carg(1), function(_, pos, state)
                        if pos > state.e_line_pos then
                            state.e_line_pos = pos
                            state.e_line = state.e_line + 1
                        end
                        return pos
                    end) * (Carg(1) / function(state)
						state.p_line = state.p_line + 1
					end)

local COMMENT       = P("#") * (1 - NEWLINE)^0
local SAPCE_LINE    = BLANKS0 * COMMENT^-1
local SAPCE_PARA    = (SAPCE_LINE * NEWLINE)^0 * SAPCE_LINE

local INTEGER_DEC	= P"-"^-1 * DIGIT^1
local INTEGER_HEX	= P"-"^-1 * "0" * S("xX") * (R("09") + R("af") + R("AF")) ^ 1
local INTEGER		= INTEGER_HEX + INTEGER_DEC
local DOUBLE		= P"-"^-1 * DIGIT^1 * "." * DIGIT^1
local BOOL			= P("true") + P("false")
local NIL			= P("nil")

local QUALIFIER		= P("const") + P("hide")

local DOC = P {
    "MAIN",

	LINE	= Cg(Carg(1) / function(state)
						return state.p_line
					end,
					"__line"
				),

	LITERAL = "\"" * C((1 - (NEWLINE + "\""))^0) * "\"",

	LUA_FUNC_ENDING = "end" * SAPCE_PARA * ")" * BLANKS0 * ";",

	LUA_FUNC = C(P"function" * ((1 - (NEWLINE + V("LUA_FUNC_ENDING")))^1 * (NEWLINE - V("LUA_FUNC_ENDING"))^0)^0 * #V("LUA_FUNC_ENDING") * P("end")) * Carg(1) / 
	function(v, state)
		local line = state.p_line
		for _ in string.gmatch(v, "\n") do
			line = line - 1
		end
		local func, errmsg = load("return " .. v)
		assert(func, string.format("error:\n%s\n%s\n at function: %d", errmsg, v, line))
		return string.dump(func())
	end,

	VALUE_ARRAY = Ct(
		"{" * SAPCE_PARA *
			(SAPCE_PARA * V("VALUE") * BLANKS0 * ",")^0 * (SAPCE_PARA * V("VALUE"))^-1 * SAPCE_PARA *
		"}"
	),

	VALUE_STRUCT = Ct(
		Cg(C(NAME), "type") * BLANKS0 *
		"(" * SAPCE_PARA *
			Cg(
				Ct(
					(SAPCE_PARA * V("VARIABLE") * BLANKS0 * ",")^0 * SAPCE_PARA * V("VARIABLE")^-1
				),
				"ctor_args"
			) * SAPCE_PARA *
		")"
	) /
	function(tb)
		for _, arg in ipairs(tb.ctor_args or {}) do
			assert(not tb.ctor_args[arg.identifier])
			tb.ctor_args[arg.identifier] = arg
		end
		return tb
	end,

	VALUE = V("LITERAL") + 
			C(DOUBLE) / function(v)
				return tonumber(v)
			end + 
			C(INTEGER) / function(v)
				return tonumber(v)
			end + 
			C(BOOL) / function(v)
				return v == "true" and true or false
			end + 
			C(NIL) / function()
				return nil
			end + 
			V("VALUE_ARRAY") + V("VALUE_STRUCT"),

	VARIABLE = Ct(
		Cg(C(NAME), "identifier") * BLANKS0 *
		("[" * BLANKS0 * 
			Cg(
				(C(INTEGER) + Cc("-1")), "array") * BLANKS0 * 
		"]")^-1 * BLANKS0 *
		(
			"=" * SAPCE_PARA * 
			Cg(V("VALUE"), "value")		
		)^-1
	) /
	function(var)
		if var.array then
			assert(var.array ~= 0)
			var.array = math.tointeger(var.array)
		end
		return var
	end,

	ATTRIBUTE = Ct(
		Cg(C(NAME), "key") * BLANKS0 * ":" * BLANKS0 * Cg(V("LITERAL"), "val")
	),

	ATTRIBUTES = Ct(
		"[" * SAPCE_PARA *
			(SAPCE_PARA * V("ATTRIBUTE") * BLANKS0 * ",")^0 * (SAPCE_PARA * V("ATTRIBUTE"))^-1 * SAPCE_PARA *
		"]"
	)^-1 / 
	function(attrs)
		local ret = {}
		for _, attr in ipairs(attrs) do
			assert(not ret[attr.key], string.format("attr '%s' is duplicate", attr.key))
			ret[attr.key] = attr.val
		end

		return next(ret) and ret
	end,

	ENUM_DEF_CONSTANT = V("LITERAL") + C(INTEGER),

	ENUM_DEF_ITEM = Ct(
		Cg(V("ATTRIBUTES"), "attribute") * SAPCE_PARA * 
		V("LINE") *
		Cg(V("ENUM_DEF_CONSTANT"), "value")
	),

	ENUM_DEF = Ct(
		Cg(Cc("enum"), "specifier") *
		Cg(V("ATTRIBUTES"), "attribute") * SAPCE_PARA *
		V("LINE") *
		"enum" * BLANKS1 * Cg(C(NAME), "name") * SAPCE_PARA * 
		"{" * SAPCE_PARA *
			P(
				P(
					"list" * SAPCE_PARA *
					"(" * SAPCE_PARA *
							Cg(V("LUA_FUNC"), "func_list") * SAPCE_PARA *
					")" * BLANKS0 *
					";" * SAPCE_PARA
				) +
				P(
					Cg(
						Ct(
							(SAPCE_PARA * V("ENUM_DEF_ITEM") * SAPCE_PARA * ",")^0 * SAPCE_PARA * (V("ENUM_DEF_ITEM") * P(",")^-1)^-1
						),
						"constant"
					)
				)
			) ^ -1 * SAPCE_PARA *
		"}" * BLANKS0 *	
		";"
	) / 
	function(tb)
		tb.attribute = tb.attribute or {}
		if tb.func_list then
			tb.attribute[Def.ATTR_KEY_ENUM_LIST] = "true"
		else
			tb.attribute[Def.ATTR_KEY_ENUM_LIST] = nil
		end

		return tb
	end,

	STRUCT_DEF_BASE_TYPE = Ct(
		Cg(P(":") * SAPCE_PARA * C(NAME), "type")
	) / 
	function(tb)
		return tb
	end,

	STRUCT_DEF_BASE_CONSTRUCT = Ct(
		P("base") * SAPCE_PARA *
		"(" * SAPCE_PARA *
			(
				(SAPCE_PARA * V("VARIABLE") * BLANKS0 * ",")^0 * SAPCE_PARA * V("VARIABLE")^-1
			) * SAPCE_PARA *
		")" * BLANKS0 * 
		";") * 
		Cb("base") / 
		function(value, base)
			base.ctor_args = value
			for _, arg in ipairs(base.ctor_args or {}) do
				assert(not base.ctor_args[arg.identifier], "identifier conflict")
				base.ctor_args[arg.identifier] = arg
			end
		end,
	
	STRUCT_DEF_MEMBER = Ct(
		Cg(V("ATTRIBUTES"), "attribute") * SAPCE_PARA *
		V("LINE") *
		Cg(
			Ct(
				(C(QUALIFIER) * BLANKS1)^0
			),
			"qualifier"
		) *
		Cg(C(NAME), "type") * BLANKS1 *
		Cg(V("VARIABLE"), "variable") * BLANKS0 *
		";"
	) / 
	function(tb)
		local member = {
			attribute = tb.attribute or {},
			type = tb.type,
			identifier = tb.variable.identifier,
			value = tb.variable.value,
			array = tb.variable.array,
			__line = tb.__line
		}
		for _, q in ipairs(tb.qualifier or {}) do
			member.attribute = member.attribute or {}
			member.attribute[string.upper(q)] = "true"
		end

		return member
	end,

	STRUCT_DEF_MONITOR = Ct(
		V("LINE") *
		"monitor" * SAPCE_PARA * 
		"(" * SAPCE_PARA *
			Cg(V("LITERAL"), "identifier") * BLANKS0 *
			"," * SAPCE_PARA *
			Cg(V("LUA_FUNC"), "func_monitor") * SAPCE_PARA *
		")" * BLANKS0 *
		";"
	),

	STRUCT_DEF_INIT = Ct(
		V("LINE") *
		"attrs_updater" * SAPCE_PARA *
		"(" * SAPCE_PARA *
			Cg(V("LUA_FUNC"), "func") * SAPCE_PARA *
		")" * BLANKS0 *
		";"
	),

	STRUCT_DEF = Ct(
		Carg(1) / function(state)
			state.tmp = state.tmp or {}
		end *
		Cg(Cc("struct"), "specifier") *
		Cg(
			Carg(1) / function(state)
				state.tmp.member = state.tmp.member or {}
				return state.tmp.member
			end,
			"member"
		) *
		Cg(
			Carg(1) / function(state)
				state.tmp.monitor = state.tmp.monitor or {}
				return state.tmp.monitor
			end,
			"monitor"
		) *
		Cg(
			Carg(1) / function(state)
				state.tmp.init = state.tmp.init or {}
				return state.tmp.init
			end,
			"init"
		) *
		Cg(V("ATTRIBUTES"), "attribute") * SAPCE_PARA *
		V("LINE") *
		"struct" * BLANKS1 * 
		Cg(C(NAME), "name") * SAPCE_PARA *
		Cg(
			V("STRUCT_DEF_BASE_TYPE") * Carg(1) / function(base, state)
				state.tmp.base = state.tmp.base or base
				return state.tmp.base
			end,
			"base"
		)^-1 * SAPCE_PARA *
		"{" * SAPCE_PARA *
			V("STRUCT_DEF_BASE_CONSTRUCT")^-1 * SAPCE_PARA *
			(Cb("init") * V("STRUCT_DEF_INIT") / function(list, item)
				table.insert(list, item.func)
			end)^-1 * SAPCE_PARA *
			(SAPCE_PARA *
				(
					Cb("member") * V("STRUCT_DEF_MEMBER") / function(list, item)
						table.insert(list, item)
						list[item.identifier] = item
					end +
					Cb("monitor") * V("STRUCT_DEF_MONITOR") / function(list, item)
						list[item.identifier] = item
					end
				)
			)^0 * SAPCE_PARA *
		"}" * BLANKS0 *
		";"
	) * Carg(1) /
	function(struct, state)
		state.tmp = nil
		return struct
	end,

	EXTEND_DEF = Ct(
		Carg(1) / function(state)
			state.tmp = state.tmp or {}
		end *
		Cg(Cc("extend"), "specifier") *
		Cg(
			Carg(1) / function(state)
				state.tmp.member = state.tmp.member or {}
				return state.tmp.member
			end,
			"member"
		) *
		Cg(
			Carg(1) / function(state)
				state.tmp.monitor = state.tmp.monitor or {}
				return state.tmp.monitor
			end,
			"monitor"
		) *
		"extend" * BLANKS1 * 
		Cg(C(NAME), "extend") * SAPCE_PARA *
		"{" * SAPCE_PARA *
			Cg(
				V("STRUCT_DEF_INIT") / function(item)
					return item.func
				end,
				"init"
			)^-1 * SAPCE_PARA *
			(SAPCE_PARA *
				(
					Cb("member") * V("STRUCT_DEF_MEMBER") / function(list, item)
						table.insert(list, item)
						list[item.identifier] = item
					end +
					Cb("monitor") * V("STRUCT_DEF_MONITOR") / function(list, item)
						list[item.identifier] = item
					end
				)
			)^0 * SAPCE_PARA *
		"}" * BLANKS0 *
		";"
	) * Carg(1) /
	function(extend, state)
		state.tmp = nil
		return extend
	end,

	MAIN = SAPCE_PARA * 
		Ct(
			(
				(SAPCE_PARA * V("ENUM_DEF")) + 
				(SAPCE_PARA * V("STRUCT_DEF")) + 
				(SAPCE_PARA * V("EXTEND_DEF"))
			)^0
		) * SAPCE_PARA *
		EOF,
}

local EXCEPTION = lpeg.Cmt(Carg(1), function(_, pos, state)
    error(string.format("%s parse error, at line:%s", state.file, state.e_line))
    return pos
end)


local BASE_TYPE_CONF = {
	{
		specifier = "bool",
		name = "bool"
	},
	{
		specifier = "number",
		name = "number",
	},
	{
		specifier = "string",
		name = "string",
	}
}


local types = {}
local dstack = {}
local ctypes = {}

local check_type

local function init()
	types = {}
	dstack = {}
	ctypes = {}
end

local function check_compatible(dtype, type)
	if dtype == type then
		return
	end

	local function check_heriship(from, to)
		local base_type = types[from].base and types[from].base.type
		if not base_type then
			return false
		end

		if base_type == to then
			return true
		end
		return check_heriship(base_type, to)
	end

	assert(check_heriship(dtype, type), string.format("%s is not heriship form %s", dtype, type))
end

local function check_value(val, type, array)
	if _G.type(val) == "nil" then
		return
	end

	if array then
		assert(_G.type(val) == "table", string.format("array value need table"))
		for i = 1, #val do
			check_value(val[i], type)
		end
		return
	end

	if type == "number" then
		assert(_G.type(val) == "number")
	elseif type == "string" then
		assert(_G.type(val) == "string")
	elseif type == "bool" then
		assert(_G.type(val) == "boolean")
	elseif _G.type(val) == "table" then
		check_type(assert(val.type))
		check_compatible(val.type, type)
		local conf = types[val.type]
		for _, arg in ipairs(val.ctor_args or {}) do
			local mb = conf.member[arg.identifier]
			if mb then
				check_value(arg.value, mb.type, mb.array)
			end
		end
	end
end

local function check_enum(type, conf)
	assert(conf.specifier == "enum")
end

local function check_member_identifier(type, ids)
	assert(_G.type(ids) == "table")

	local conf = types[type]
	assert(conf.specifier == "struct")

	if conf.base then
		check_member_identifier(conf.base.type, ids)
	end

	for _, mb in ipairs(conf.member or {}) do
		assert(
			not ids[mb.identifier], 
			string.format("struct member %s is alread declaration", mb.identifier)
		)
		ids[mb.identifier] = true
	end
end

local function check_struct(type, conf)
	local ids = {}

	assert(conf.specifier == "struct")
	
	if conf.base then
		assert(conf.base.type, string.format("type:%s miss base type", type))
		check_type(conf.base.type, "struct")
		check_value(conf.base, conf.base.type, false)
	end

	for _, mb in ipairs(conf.member or {}) do
		check_type(mb.type, nil, mb.array)
		check_value(mb.value, mb.type, mb.array)
	end

	local ids = {}
	check_member_identifier(type, ids)

	for _, m in ipairs(conf.monitor or {}) do
		assert(
			ids[m.identifier], 
			string.format("'%s' is not a member of struct %s", m.identifier, type)
		)
	end

	
end

check_type = function(type, specifier, array)
	if ctypes[type] then
		assert(not specifier or types[type].specifier == specifier, string.format(
			"[ERROR] expect specifier %s", specifier))
		return
	end

	local conf = types[type]
	assert(conf, string.format("type '%s' is not declare", type))
	
	if array == -1 then
		return
	end

	for _, t in ipairs(dstack) do
		if type == t then
			error("loop.....")
		end
	end

	assert(not specifier or conf.specifier == specifier, string.format(
		"[ERROR] expect specifier %s", specifier))
	table.insert(dstack, type)
	if conf.specifier == "enum" then
		check_enum(type, conf)
	elseif conf.specifier == "struct" then
		check_struct(type, conf)
	end
	table.remove(dstack)
	ctypes[type] = true
end

local function check_all(data)
	local extends = {}

	local i = 1
	repeat
		local conf = data[i]
		if not conf then
			break
		end
		if conf.name then
			local type = conf.name
			assert(not types[type], string.format(
				"[ERROR] type %s at line:%s is already define at line:%s", 
				type, conf.__line, types[type] and types[type].__line
				)
			)
			types[type] = conf

			i = i + 1
		else
			assert(conf.extend)
			assert(not extends[conf.extend], string.format("struct has many extend: %s", conf.extend))
			extends[conf.extend] = conf

			table.remove(data, i)
		end
	until(false)

	-- apply extend
	for name, extend in pairs(extends) do
		local conf = assert(types[name], string.format("extent struct is not exist? %s", name))
		for key, member in pairs(extend.member) do
			if type(key) == "string" then
				conf.member[key] = member
			else
				table.insert(conf.member, member)
			end
			
		end
		for name, func in pairs(extend.monitor) do
			conf.monitor[name] = func
		end

		if extend.init then
			table.insert(conf.init, extend.init)
		end
	end

	for type in pairs(types) do
		assert(not next(dstack))
		check_type(type)
	end
end

local function read_converter(path)
	local state = {
		file = path, 
		e_line_pos = 0, 
		e_line = 1,
		p_line = 1,
	}
	local file = io.open(state.file)
	if not file then
		return {}
	end

	local text = file:read("a")
	file:close()

	local c1, c2, c3 = string.byte(text, 1, 3)
	if (c1 == 0xEF and c2 == 0xBB and c3 == 0xBF) then
	    text = string.sub(text, 4)
	end

	local ret = lpeg.match(DOC + EXCEPTION, text, 1, state)
	assert(type(ret) == "table")
	return ret
end


return function(path,custom_meta_dir)
	init()

	local ret = read_converter(path)
	assert(type(ret) == "table")

	for _, conf in ipairs(BASE_TYPE_CONF) do
		table.insert(ret, 1, conf)
	end

	assert(type(custom_meta_dir) == "string")
	local Lfs = require "lfs"
	local json_attr = Lfs.attributes(custom_meta_dir)
	if json_attr then
		for name in lfs.dir(custom_meta_dir) do
			local tb = Lib.splitString(name,".")
			if tb[#tb] == "meta" then
				local additional_ret = read_converter(Lib.combinePath(custom_meta_dir,name))
				for k,v in ipairs(additional_ret) do
					table.insert(ret, v)
				end
			end
		end
	end

	check_all(ret)

	return ret
end
