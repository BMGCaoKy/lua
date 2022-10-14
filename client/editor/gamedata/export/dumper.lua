local strfmt = string.format

local function is_action(object)
	return type(object) == "table" and object.__action
end

local function get_sorted_keys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function (a, b)
		local ta, tb = type(a), type(b)
		if ta == tb then
			return a < b
		end
		return ta < tb
	end)
	return keys
end

local function is_array(t)
	if type(t) ~= "table" then
		return false
	end
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	for i = 1, n do
		if not t[i] then
			return false
		end
	end
	return true
end

local function array2map(array)
	local map = {}
	for i, v in ipairs(array) do
		map[v] = i
	end
	return map
end

function dump_triggers(triggers)
	local list = {}
	for i, trigger in ipairs(triggers) do
		list[i] = dump_trigger(trigger)
	end
	return table.concat(list, "\n")
end

function dump_trigger(trigger)
	local params = {}
	for k, v in pairs(trigger) do
		if k ~= "type" and k ~= "actions" then
			params[k] = v
		end
	end
	local ret = trigger.type
	if tostring(tonumber(ret)) == ret then
		ret = strfmt("%q", ret)
	end
	if next(params) then
		ret = ret .. dump_params(params, {})
	end
	init_actions(trigger.actions, trigger)
	local actions = dump_actions(trigger.actions, 0)
	return strfmt("%s %s\n", ret, actions)
end

function dump_params(params, order, depth)
	local map = array2map(order)
	for _, k in ipairs(get_sorted_keys(params)) do
		if not map[k] then
			order[#order + 1] = k
		end
	end
	local list = {}
	for _, k in ipairs(order) do
		if type(k) == "number" then
			list[#list + 1] = dump_expr(params[k], depth)
		else
			list[#list + 1] = dump_pair(k, params[k], depth)
		end
	end
	local prefix = depth and "\n"..string.rep("\t", depth + 1) or ""
	return strfmt("(%s%s)", prefix..table.concat(list, depth and ","..prefix or ", "), prefix:sub(1, -2))
end

function dump_expr(expr, depth)
	if is_action(expr) then
		return dump_action(expr, depth)
	end
	return dump_value(expr, depth)
end

function dump_pair(k, v, depth)
	assert(type(k) == "string")
	return strfmt("%s = %s", k, dump_expr(v, depth))
end

function dump_value(value, depth)
	local t = type(value)
	if t ~= "table" then
		return t == "string" and strfmt("%q", value) or tostring(value)
	elseif not next(value) then
		return "[]"
	end
	return is_array(value) and dump_array(value, depth) or dump_object(value, depth)
end

function dump_array(array, depth)
	depth = depth and (depth + 1)
	local list = {}
	for _, v in ipairs(array) do
		list[#list + 1] = dump_expr(v, depth)
	end
	if not depth then
		return strfmt("[%s]", table.concat(list, ", "))
	end
	local prefix = "\n"..string.rep("\t", depth)
	return strfmt("[%s\t%s%s]", prefix, table.concat(list, ","..prefix.."\t"), prefix)
end

function dump_object(object, depth)
	local order = object.__order or {}
	local map = array2map(order)
	for _, k in ipairs(get_sorted_keys(object)) do
		if not map[k] then
			order[#order + 1] = k
		end
	end
	depth = depth and (depth + 1)
	local list = {}
	for _, k in ipairs(order) do
		list[#list + 1] = strfmt("%s = %s", k, dump_expr(object[k], depth))
	end
	if not depth then
		return strfmt("{ %s }", table.concat(list, ", "))
	end
	local prefix = "\n"..string.rep("\t", depth)
	return strfmt("{%s\t%s%s}", prefix, table.concat(list, ","..prefix.."\t"), prefix)
end

function init_actions(actions, parent)
	for _, action in pairs(actions or {}) do
		action.parent = parent
	end
end

function dump_actions(actions, depth)
	depth = (depth or 0) + 1
	local list = {""}
	for _, action in pairs(actions) do
		list[#list + 1] = dump_action(action, depth)
	end
	local prefix = "\n"..string.rep("\t", depth)
	return strfmt("{%s\n%s}", table.concat(list, prefix), string.rep("\t", depth - 1))
end

function dump_action(action, depth)
	local ok, ret = xpcall(do_dump_action, traceback, action, depth)
	if not ok then
		if  action then
			local parent = action.parent
			local list = {action.type}
			while parent do
				table.insert(list, 1, parent.type)
				parent = parent.parent
			end
			print(table.concat(list, " - "))
			print(ret)
		end
		error({})
	end
	return ret
end

function do_dump_action(action, depth)
	local type = action.type
	if type == "If" then
		return dump_if(action, depth)
	elseif type == "UnaryOper" then
		return dump_unoper(action, depth)
	elseif type == "BinaryOper" then
		return dump_binoper(action, depth)
	elseif type == "GetGlobalVar" or type == "SetGlobalVar"
		or type == "GetContextVar" or type == "SetContextVar"
		or type == "GetObjectVar" or type == "SetObjectVar" then
		return dump_sugar(action, depth)
	elseif type == "Sequence" or type == "Selector" or type == "Parallel" or type == "Loop" then
		init_actions(action.children, action)
		return strfmt("%s %s", type, dump_actions(action.children, depth))
	end
	local params = {}
	for k, v in pairs(action.params or {}) do
		params[k] = v
	end
	for k, v in pairs(action.funcs or {}) do
		params[k] = v
		if not v.__action then
			v.__action = true
		end
	end
	--[[if (type == "StartTimer2" or type == "StartTimer") and params.action then
		if not params.action.__action then
			params.action.__action  = true
		end
	end --]]
	if type == "Table" then
		return dump_value(params, depth)
	elseif type == "Value" then
		return dump_value(params[1], depth)
	end
	local ret = strfmt("%s%s", action.type, dump_params(params, action._argsorder or {}))
	if ret:gsub('.', {['\t'] = '    '}):len() > 120 then
		ret = strfmt("%s%s", action.type, dump_params(params, action._argsorder or {}, depth))
	end
	if next(action.children or {}) then
		init_actions(action.children, action)
		ret = strfmt("%s %s", ret, dump_actions(action.children, depth))
	end
	return ret
end

function dump_if(action, depth)
	local prefix = depth and string.rep("\t", depth) or ""
	local ret = ""
	local count = #action.children
	for i, child in ipairs(action.children) do
		local params, funcs = child.params or {}, child.funcs or {}
		local param = params[1]
		if param == nil then
			param = params.condition
		end
		if param == nil then
			param = funcs[1]
			if param and not param.__action then
				param.__action = true
			end
		end
		if param == nil then
			param = funcs.condition
			if param and not param.__action then
				param.__action = true
			end
		end
		if i == 1 then
			ret = strfmt("If %s", dump_params({param}, {})) -- depth
		elseif i ~= count or params[1] ~= true then
			ret = strfmt("%s%s ElseIf %s", prefix, ret, dump_params({param}, {})) -- depth
		else
			ret = ret..prefix.." Else"
		end
		init_actions(child.children or {}, action)
		ret = strfmt("%s %s", ret, dump_actions(child.children or {}, depth))
	end
	return ret
end

function dump_unoper(action, depth)
	depth = depth and (depth + 1)
	local op = action.params.op
	if op == "not" then
		op = op .. " "
	end
	local value = action.params.value
	if value == nil then
		value = action.funcs.value
		if not value.__action then
			value.__action = true
		end
	end
	if not is_action(value) or (value.type ~= "BinaryOper" and value.type ~= "UnaryOper") then
		return op..dump_expr(value, depth)
	end
	return strfmt("%s(%s)", op, dump_action(value, depth))
end

local BIN_OP_PRIOR = {
	['or']  = {1, 1},   ['and'] = {2, 2},   ['||'] = {1, 1},   ['&&'] = {2, 2},
	['==']  = {3, 3},   ['~=']  = {3, 3},   ['<']  = {3, 3},   ['<='] = {3, 3},
	['>']   = {3, 3},   ['>=']  = {3, 3},   ['|']  = {4, 4},   ['~']  = {5, 5},
	['&']   = {6, 6},   ['<<']  = {7, 7},   ['>>'] = {7, 7},
	['+']   = {10, 10}, ['-']   = {10, 10}, ['*']  = {11, 11}, ['/']  = {11, 11},
	['//']  = {11, 11}, ['%']   = {11, 11}, ['^']  = {14, 13}, -- right associative
}
local function op_left_prior(op) return BIN_OP_PRIOR[op][1] end
local function op_right_prior(op) return BIN_OP_PRIOR[op][2] end

function dump_binoper(action, depth)
	depth = depth and (depth + 1)
	local op = action.params.op
	local left, right
	if op == 'or' or op == 'and' or op == '||' or op == '&&' then
		left, right = action.children[1], action.children[2]
	else
		local params, funcs = action.params or {}, action.funcs or {}
		left = params.left
		if left == nil then
			left = funcs.left
			if left and not left.__action then
				left.__action = true
			end
		end
		right = params.right
		if right == nil then
			right = funcs.right
			if right and not right.__action then
				right.__action = true
			end
		end
	end
	local lstr, rstr = dump_expr(left, depth), dump_expr(right, depth)
	if is_action(left) and left.type == "BinaryOper" and op_right_prior(left.params.op) < op_left_prior(op)  then
		lstr = "("..lstr..")"
	end	
	if is_action(right) and right.type == "BinaryOper" then
		local rop = right.params.op
		local crp, rlp = op_right_prior(op), op_left_prior(rop)
		if crp >= rlp then
			rstr = "("..rstr..")"
		end
	end
	return strfmt("%s %s %s", lstr, op, rstr)
end

function dump_sugar(action, depth)
	local ret = ""
	local atype = action.type
	local prefix = ""
	--depth = depth and (depth + 1)
	local params, funcs = action.params, action.funcs
	if atype:find("Global") then	-- GLOBAL
		prefix = "@"
	elseif atype:find("Context") then
		prefix = "$"
	else
		prefix = dump_action(funcs.obj, depth)
	end
	local key = params and params.key
	if not key then
		ret = strfmt("%s[%s]", prefix, dump_action(funcs.key, depth))
	elseif type(key) == "string" then
		if prefix ~= "@" and prefix ~= "$" then
			prefix = prefix.."."
		end
		ret = strfmt("%s%s", prefix, params.key)
	else
		ret = strfmt("%s[%s]", prefix, tostring(params.key))
	end
	if atype:sub(1, 3) == "Get" then
		return ret
	end
	local value = params and params.value
	if value == nil then
		value = funcs and funcs.value
		if value and not value.__action then
			value.__action = true
		end
	end
	return strfmt("%s = %s", ret, dump_expr(value, depth))
end

return dump_triggers
------------------------------------------------
--[[
function dumpfile(filename, triggers)
	local fout = io.open(filename, "w")
	fout:write(dump_triggers(triggers))
	fout:close()
end

function loadbtsfile(filename)
	local file = io.open(filename, "r")
	if not file then
		print("文件不存在", filename)
		return
	end
	file:close()
	return require("trigger_parser").parse(filename)
end

function loadjson(filename)
	local file = io.open(filename, "r")
	if not file then
		print("文件不存在", filename)
		return
	end
	local content = file:read("*a")
	file:close()
	return require("json").decode(content).triggers
end

local input, output = ...
assert(input and output, "need input filename and output filename")
if input:sub(-5) == ".json" then
	dumpfile(output, loadjson(input))
else
	dumpfile(output, loadbtsfile(input))
end
--]]