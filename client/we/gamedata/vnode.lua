local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"
local Attr = require "we.gamedata.attr"
local Signal = require "we.signal"
local Recorder = require "we.gamedata.recorder"
local Log = require "we.log"

local NODE_MEMBER_ID_PARENT			= "__parent"
local NODE_MEMBER_ID_CHILDREN		= "__children"
local NODE_MEMBER_ID_ATTRS			= "__attrs"
local NODE_MEMBER_ID_META			= "__meta"
local NODE_MEMBER_ID_ARRAY			= "__array"
local NODE_MEMBER_ID_TREE			= "__tree"
local NODE_MEMBER_ID_UNDO_STACK		= "__undo_stack"
local NODE_MEMBER_ID_KEY			= "__key"

local ATTR_KEY_UNDO_STACK			= "UndoStack"
local ATTR_VALUE_UNDO_FORK			= "fork"
local ATTR_VALUE_UNDO_BARRIER		= "barrier"

local CTRL_BIT = {
	NONE		= 0,

	NOTIFY		= 1 << 0,
	SYNC		= 1 << 1,
	RECORDE		= 1 << 2,
}
CTRL_BIT.DEFAULT = CTRL_BIT.NOTIFY | CTRL_BIT.SYNC | CTRL_BIT.RECORDE

------------------------------------------------------------

--- meta的初始化/监控函数表，统一保存以便重用
local initializer_func_map = {}
local monitor_func_map = {}

local node_class = {}

local node_mt

local function check_node(node)
	return getmetatable(node) == node_mt
end

local function check_undo_stack(node)
	local stack_base = require "we.cmd.stack_base"
	
	if not rawget(node, NODE_MEMBER_ID_UNDO_STACK) then
		local value = node_class.attr(node, nil, ATTR_KEY_UNDO_STACK)
		if value == ATTR_VALUE_UNDO_FORK then
			local stack = Lib.derive(stack_base)
			stack:init()
			rawset(node, NODE_MEMBER_ID_UNDO_STACK, stack)
		elseif value == ATTR_VALUE_UNDO_BARRIER then
			rawset(node, NODE_MEMBER_ID_UNDO_STACK, 0)
		end
	end

	return rawget(node, NODE_MEMBER_ID_UNDO_STACK)
end

function node_class.join_undo_stack(node, stack)
	assert(not node_class.undo_stack(node))
	rawset(node, NODE_MEMBER_ID_UNDO_STACK, stack)
end

function node_class.parent(node)
	return rawget(node, NODE_MEMBER_ID_PARENT)
end

function node_class.set_parent(node, parent, key)
	rawset(node, NODE_MEMBER_ID_PARENT, parent)
	rawset(node, NODE_MEMBER_ID_KEY, key)
end

function node_class.children(node)
	return rawget(node, NODE_MEMBER_ID_CHILDREN)
end

function node_class.meta(node)
	return rawget(node, NODE_MEMBER_ID_META)
end

function node_class.type(node)
	return node_class.meta(node):name()
end

function node_class.array(node)
	return rawget(node, NODE_MEMBER_ID_ARRAY)
end

function node_class.dynamic_attrs(node)
	return rawget(node, NODE_MEMBER_ID_ATTRS)
end

function node_class.key(node)
	return rawget(node, NODE_MEMBER_ID_KEY)
end

function node_class.set_key(node, key)
	rawset(node, NODE_MEMBER_ID_KEY, key)
end

function node_class.root(node)
	local curr = node
	local root = curr

	repeat
		curr = node_class.parent(curr)
		root = curr or root
	until (not curr)
	
	return root
end

function node_class.tree(node)
	local root = node_class.root(node)
	return root[NODE_MEMBER_ID_TREE]
end

function node_class.undo_stack(node, index)
	if index then
		if node_class.attr(node, index, ATTR_KEY_UNDO_STACK) == ATTR_VALUE_UNDO_BARRIER then
			return
		end

		if check_node(node[index]) then
			node = node[index]
		end
	end

	repeat
		local stack = check_undo_stack(node)
		if stack == 0 then
			return
		elseif stack then
			return stack, node
		end

		node = node_class.parent(node)
	until(not node)
end

function node_class.value(node, index)
	if index then
		node = node[index]
	end
	return Lib.copy(node)
end

local init_env_funcs = {
	set_attr = function(node, index, key, value)
		return node_class.set_attr(node, index, key, value, CTRL_BIT.NONE)
	end,

	attr = function(node, index, key)
		return node_class.attr(node, index, key)
	end
}

local init_node = function(node)
	local function _init_node(meta, node)
		if (meta:base()) then
			local type = meta:base()
			local meta = assert(Meta:meta(type), type)
			_init_node(meta, node)
		end

		local meta_name = meta:name()
		for i, initializer in ipairs(meta:initializer()) do
			local func_id = meta_name .. i
			local func = initializer_func_map[func_id]
			if not func then
				Log("load initializer func", func_id)
				func = load(
						initializer,
						"",
						"bt",
						setmetatable(init_env_funcs, {__index = _G})
				)
				initializer_func_map[func_id] = func
			end
	
			local enable = Recorder:enable()
			Recorder:set_enable(false)
			local ok, errmsg = xpcall(func, function(errmsg)
				return string.format("meta <%s> 's initializer error:\n%s", meta:name(), errmsg)
			end, node)
			Recorder:set_enable(enable)
			assert(ok, errmsg)
		end
	end
	
	local meta = node_class.meta(node)
	_init_node(meta, node)
end

local function _new(val, type, array, tree)
	if _G.type(val) ~= "table" then
		return val
	end
	
	if not array then
		type = val[Def.OBJ_TYPE_MEMBER] or type
	end

	local meta = assert(Meta:meta(type), tostring(type))
	local children = {}
	local data = {
		[NODE_MEMBER_ID_TREE] = tree,
		[NODE_MEMBER_ID_PARENT] = false,
		[NODE_MEMBER_ID_META] = meta,
		[NODE_MEMBER_ID_ARRAY] = array,
		[NODE_MEMBER_ID_CHILDREN] = children,
		[NODE_MEMBER_ID_ATTRS] = {},
		[NODE_MEMBER_ID_UNDO_STACK] = false
	}

	local node = setmetatable(data, node_mt)

	if array then
		for k, v in ipairs(val) do
			local child = _new(v, type, false)
			children[k] = child
			if check_node(child) then
				node_class.set_parent(child, node, k)
			end
		end
	else
		for k, type, array in meta:next_member() do
			local v = val[k]
			local child = _new(v, type, array)
			children[k] = child
			if check_node(child) then
				node_class.set_parent(child, node, k)
			end
			val[k] = nil
		end

		for k, v in pairs(val) do
			children[k] = v
		end

		init_node(node)
	end

	return node
end

function node_class.new(rawval, type, array, tree)
	local meta = assert(Meta:meta(type), tostring(type))

	if meta:specifier() == "struct" and _G.type(rawval) == "table" then
		if rawval[Def.OBJ_TYPE_MEMBER] then
			type = rawval[Def.OBJ_TYPE_MEMBER]
			meta = assert(Meta:meta(type), tostring(type))
		end
	end

	return _new(meta:ctor(rawval), type, array, tree)
end

local exec_monitor
local monitor_env_funcs

local function set_env_funcs_env(extra)
	extra = extra or {}
	local f = monitor_env_funcs.baseline
	local name, env = debug.getupvalue(f, 1)
	assert(name == "_ENV", name)
	assert(type(env) == "table")
	assert(type(extra) == "table")

	debug.setupvalue(f, 1, setmetatable(extra, {__index = env}))

	return env
end

local function restor_env_funcs_env(env)
	local f = monitor_env_funcs.baseline
	local name = debug.getupvalue(f, 1)
	assert(name == "_ENV", name)

	debug.setupvalue(f, 1, env)
end

exec_monitor = function(type, key, ...)
	local meta = Meta:meta(type)
	local monitor, base = meta:monitor(key)
	if not monitor then
		return true
	end

	local env = set_env_funcs_env({__base = base, __key = key,  __args = {...}})
	local func_id = meta:name() .. "_" .. key
	local func = monitor_func_map[func_id]
	if not func then
		Log("load monitor func", func_id)
		func = load(
				monitor,
				string.format("%s:%s", type, key),
				"bt",
				setmetatable(monitor_env_funcs, {__index = _G})
		)
		monitor_func_map[func_id] = func
	end

	local forward = func(...)
	restor_env_funcs_env(env)
	return forward
end

monitor_env_funcs = {
	baseline = function()
		local _ = _ENV	-- take _ENV be first upvalue
	end,

	callbase = function()
		assert(__base, string.format("no base"))
		exec_monitor(__base, __key, table.unpack(__args))
	end,

	ctor = function(type, rawval)
		return node_class.new(rawval, type, false)
	end,

	set_attr = function(node, index, key, value)
		return node_class.set_attr(node, index, key, value)
	end,

	attr = function(node, index, key)
		return node_class.attr(node, index, key)
	end
}

local function trigger(node, key, oval, path, op)
	path = Lib.copy(path)
	local array = node_class.array(node)
	local meta = node_class.meta(node)

	local forward = true
	if not array then
		forward = exec_monitor(meta:name(), key, node, path, oval, op)
	end

	local parent = node_class.parent(node)
	if forward and parent then
		table.insert(path, 1, node_class.key(node))
		trigger(parent, node_class.key(node), oval, path, op)
	end
end

local function sync(node, event, ...)
	local tree = node_class.tree(node_class.root(node))
	if not tree then
		return
	end

	if event == Def.NODE_EVENT.ON_CTOR then
		tree:on_node_ctor(node, ...)
	elseif event == Def.NODE_EVENT.ON_ASSIGN then
		tree:on_node_assign(node, ...)
	elseif event == Def.NODE_EVENT.ON_INSERT then
		tree:on_node_insert(node, ...)
	elseif event == Def.NODE_EVENT.ON_REMOVE then
		tree:on_node_remove(node, ...)
	elseif event == Def.NODE_EVENT.ON_MOVE then
		tree:on_node_move(node, ...)
	elseif event == Def.NODE_EVENT.ON_ATTR_CHANGED then
		tree:on_node_attr_changed(node, ...)
	end
end

local function notify(node, event, ...)
	Signal:publish(node, event, ...)

	local e
	if event == Def.NODE_EVENT.ON_ATTR_CHANGED then
		e = Def.NODE_EVENT.ON_ATTR_MODIFY
	else
		e = Def.NODE_EVENT.ON_MODIFY
	end

	local function raise_modify_event(node, path, event, ...)
		Signal:publish(node, e, path, event, ...)

		local parent = node_class.parent(node)
		if parent then
			table.insert(path, 1, node_class.key(node))
			raise_modify_event(parent, path, event,  ...)
		end
	end
	raise_modify_event(node, {}, event, ...)
end

function node_class.ctor(node, index, child, cbs)
	cbs = cbs or CTRL_BIT.DEFAULT
	if node_class.array(node) then
		index = assert(math.tointeger(index))
	else
		assert(_G.type(index) == "string")
	end

	assert(check_node(child))
	assert(not node_class.parent(child))

	local children = node_class.children(node)
	local ochild = children[index]
	assert(ochild, string.format("%s is not member of %s", tostring(index), node_class.type(node)))
	assert(check_node(ochild))
	
	children[index] = child
	node_class.set_parent(child, node, index)

	if cbs & CTRL_BIT.RECORDE ~= 0 then
		Recorder:on_ctor(node, index, ochild)
	end
	if cbs & CTRL_BIT.SYNC ~= 0 then
		sync(node, Def.NODE_EVENT.ON_CTOR, index)
	end
	if cbs & CTRL_BIT.NOTIFY ~= 0 then
		notify(node, Def.NODE_EVENT.ON_CTOR, index)
		trigger(node, index, ochild, {index}, "CTOR")
	end
end

local function _assign(node, value)
	assert(node_class.type(node) == value[Def.OBJ_TYPE_MEMBER])

	local modify = false
	local children = node_class.children(node)
	if node_class.array(node) then
		assert(#value == #children)
		for k, v in ipairs(value) do
			local child = assert(children[k], tostring(k))
			if check_node(child) then	
				modify = _assign(child, v) or modify
			else
				if children[k] ~= v then
					children[k] = v
					modify = true
				end
			end
		end
	else 
		for k, v in pairs(value) do
			local child = children[k]
			assert(child ~= nil, tostring(k))
			if check_node(child) then
				modify = _assign(child, v) or modify
			else
				if children[k] ~= v then
					children[k] = v
					modify = true
				end
			end
		end
	end

	return modify
end

function node_class.assign(node, index, rawval, cbs)
	assert(_G.type(rawval) ~= "nil")
	cbs = cbs or CTRL_BIT.DEFAULT
	index = index or ""

	if node_class.array(node) then
		index = assert(math.tointeger(index))
	else
		assert(_G.type(index) == "string")
	end

	local need_old =  cbs ~= CTRL_BIT.NONE
	local oval
	local modify = false
	if index == "" then
		oval = need_old and node_class.value(node)
		local meta = node_class.meta(node)
		modify = _assign(node, meta:ctor(rawval))
	else
		local children = node_class.children(node)
		local child = children[index]
		assert(child ~= nil, tostring(index))
		if check_node(child) then
			oval = need_old and node_class.value(child)
			local meta = node_class.meta(child)
			modify = _assign(child, meta:ctor(rawval))
		else
			oval = child
			if child ~= rawval then
				children[index] = rawval
				modify = true
			end
		end
	end
	
	if not modify then
		return
	end

	if cbs & CTRL_BIT.RECORDE ~= 0 then
		Recorder:on_assign(node, index, oval, cbs)
	end
	if cbs & CTRL_BIT.SYNC ~= 0 then
		sync(node, Def.NODE_EVENT.ON_ASSIGN, index, oval)
	end
	if cbs & CTRL_BIT.NOTIFY ~= 0 then
		notify(node, Def.NODE_EVENT.ON_ASSIGN, index, oval)
		trigger(node, index, oval, {index}, "ASSIGN")
	end

	return true
end

function node_class.insert(node, index, child, type, cbs)
	assert(node_class.array(node))
	cbs = cbs or CTRL_BIT.DEFAULT

	local children = node_class.children(node)
	index = index or #children + 1
	assert(index <= #children + 1, tostring(index))

	if not check_node(child) then
		local rawval = child
		if not type then
			if _G.type(rawval) == "table" then
				type = rawval and rawval[Def.OBJ_TYPE_MEMBER]
			end
			type = type or node_class.type(node)
		end
		child = node_class.new(rawval, type, false)
	end

	table.insert(children, index, child)
	if check_node(child) then
		node_class.set_parent(child, node, index)
		for i = index + 1, #children do
			node_class.set_key(children[i], i)
		end
	end
	
	local dynamic_attrs = node_class.dynamic_attrs(node)
	local _tmp = {}
	local k, v
	repeat
		k, v = next(dynamic_attrs, k)
		if not k then
			break
		end
		if k >= index then
			_tmp[k+1] = v
		elseif k < index then
			_tmp[k] = v
		end
		dynamic_attrs[k] = nil
	until(false)
	
	for k, v in pairs(_tmp) do
		dynamic_attrs[k] = v
	end

	if cbs & CTRL_BIT.RECORDE ~= 0 then
		Recorder:on_insert(node, index, cbs)
	end
	if cbs & CTRL_BIT.SYNC ~= 0 then
		sync(node, Def.NODE_EVENT.ON_INSERT, index)
	end
	if cbs & CTRL_BIT.NOTIFY ~= 0 then
		notify(node, Def.NODE_EVENT.ON_INSERT, index)
		trigger(node, index, nil, {index}, "INSERT")
	end

	return index
end

function node_class.remove(node, index, cbs)
	assert(node_class.array(node))
	cbs = cbs or CTRL_BIT.DEFAULT

	local children = node_class.children(node)
	index = index or #children
	local child = table.remove(children, index)
	if check_node(child) then
		node_class.set_parent(child, nil)
		for i = index, #children do
			node_class.set_key(children[i], i)
		end
	end
	
	local dynamic_attrs = node_class.dynamic_attrs(node)
	local _tmp = {}
	local k, v
	repeat
		k, v = next(dynamic_attrs, k)
		if not k then
			break
		end
		if k > index then
			_tmp[k-1] = v
		elseif k < index then
			_tmp[k] = v
		end
		dynamic_attrs[k] = nil
	until(false)
	
	for k, v in pairs(_tmp) do
		dynamic_attrs[k] = v
	end

	if cbs & CTRL_BIT.RECORDE ~= 0 then
		Recorder:on_remove(node, index, child, cbs)
	end
	if cbs & CTRL_BIT.SYNC ~= 0 then
		sync(node, Def.NODE_EVENT.ON_REMOVE, index, child)
	end
	if cbs & CTRL_BIT.NOTIFY ~= 0 then
		notify(node, Def.NODE_EVENT.ON_REMOVE, index, child)
		trigger(node, index, child, {index}, "REMOVE")
	end

	return child
end

function node_class.move(node, from, to, cbs)
	assert(node_class.array(node))
	cbs = cbs or CTRL_BIT.DEFAULT

	if from == to then
		return
	end

	local children = node_class.children(node)
	assert(from <= #children and to <= #children)
	table.insert(children, to, table.remove(children, from))

	local step = from < to and 1 or -1
	if check_node(children[from]) then
		for i = from, to, step do
			node_class.set_key(children[i], i)
		end
	end

	local dynamic_attrs = node_class.dynamic_attrs(node)
	local attrs_from = dynamic_attrs[from]
	for i = from, to-step, step do
		dynamic_attrs[i] = dynamic_attrs[i+step]
	end
	dynamic_attrs[to] = attrs_from

	if cbs & CTRL_BIT.RECORDE ~= 0 then
		Recorder:on_move(node, from, to, cbs)
	end
	if cbs & CTRL_BIT.SYNC ~= 0 then
		sync(node, Def.NODE_EVENT.ON_MOVE, from, to)
	end
	if cbs & CTRL_BIT.NOTIFY ~= 0 then
		notify(node, Def.NODE_EVENT.ON_MOVE, from, to)
	end
end

function node_class.path(node, root)
	root = root or node_class.root(node)
	if node == root then
		return ""
	end

	local path = {}
	local curr = node
	repeat
		local key = node_class.key(curr)
		if key then
			table.insert(path, 1, key)			
		end

		local parent = assert(node_class.parent(curr))
		if parent == root then
			break
		end

		curr = parent
	until (false)

	return table.concat(path, "/")
end


function node_class.set_attr(node, index, key, val, cbs)
	assert(check_node(node))
	cbs = cbs or CTRL_BIT.DEFAULT

	assert(_G.type(key) == "string", _G.type(key))
	assert(_G.type(val) == "string" or val == nil, _G.type(val))

	if (node_class.array(node)) then
		index = math.tointeger(index)
	end

	local host = node
	local category = 0			-- self
	if index then
		local children = node_class.children(node)
		local child = children[index]
		assert(child ~= nil, tostring(index))
		if check_node(child) then
			host = child
		else
			category = index	-- child
		end
	end
	index = index or ""

	local dynamic_attrs = node_class.dynamic_attrs(host)
	local attrs = dynamic_attrs[category]
	local oval = attrs and attrs[key]
	if val == oval then
		return
	end

	dynamic_attrs[category] = dynamic_attrs[category] or {}
	dynamic_attrs[category][key] = val

	if cbs & CTRL_BIT.RECORDE ~= 0 then
		Recorder:on_attr_change(node, index, key, oval, val, cbs)
	end
	if cbs & CTRL_BIT.SYNC ~= 0 then
		sync(node, Def.NODE_EVENT.ON_ATTR_CHANGED, index, key, val)
	end
	if cbs & CTRL_BIT.NOTIFY ~= 0 then
		notify(node, Def.NODE_EVENT.ON_ATTR_CHANGED, index, key, val)
	end
end

-- if not index then return node self attr, else return node[index] attr
function node_class.attr(node, index, key)
	assert(check_node(node))

	if (node_class.array(node)) then
		index = math.tointeger(index)
	end

	local ret
	repeat
		local parent, child
		if index then
			parent = node
			local children = node_class.children(node)
			child = children[index]
		else
			parent = node_class.parent(node)		-- maybe nil
			index = parent and node_class.key(node)
			child = node
		end

		-- check dynamic attr
		do
			local host
			local category = 0
			if check_node(child) then
				host = child
			else
				host = assert(parent)
				category = index
			end
			local dynamic_attrs = node_class.dynamic_attrs(host)
			ret = dynamic_attrs[category] and dynamic_attrs[category][key]
			if ret then
				break
			end
		end

		-- check parent conf attr
		local ctype
		if parent and not node_class.array(parent) then
			local pmeta = node_class.meta(parent)
			local type, _, attrs = pmeta:member(index)
			ret = attrs[key]
			if ret then
				break
			end
			ctype = type
		end

		-- check self conf attr
		if check_node(child) then
			local meta = node_class.meta(child)
			ret = meta:attribute(key)
			break
		elseif ctype then
			local meta = Meta:meta(ctype)
			ret = meta:attribute(key)
			break
		end
	until(true)

::Exit::
	return ret
end

function node_class.attrs(node, index)
	assert(check_node(node))

	if (node_class.array(node)) then
		index = math.tointeger(index)
	end

	local ret = {}
	repeat
		local parent, child
		if index then
			parent = node
			local children = node_class.children(node)
			child = children[index]
		else
			parent = node_class.parent(node)		-- maybe nil
			index = parent and node_class.key(node)
			child = node
		end

		-- check dynamic attr
		do
			local host
			local category = 0
			if check_node(child) then
				host = child
			else
				host = assert(parent)
				category = index
			end
			local dynamic_attrs = node_class.dynamic_attrs(host)
			for k, v in pairs(dynamic_attrs and dynamic_attrs[category] or {}) do
				ret[k] = v
			end
		end

		-- check parent conf attr
		local ctype
		if parent and not node_class.array(parent) then
			local pmeta = node_class.meta(parent)
			local type, _, attrs = pmeta:member(index)
			for k, v in pairs(attrs) do
				ret[k] = ret[k] or v
			end

			ctype = type
		end

		-- check self conf attr
		if check_node(child) then
			local meta = node_class.meta(child)
			for k, v in pairs(meta:attrs() or {}) do
				ret[k] = ret[k] or v
			end
		elseif ctype then
			local meta = Meta:meta(ctype)
			for k, v in pairs(meta:attrs() or {}) do
				ret[k] = ret[k] or v
			end
		end
	until(true)

::Exit::
	return ret
end

function node_class.check_attr(node, index, key, value, upward)
	assert(check_node(node))
	if index then
		if node_class.attr(node, index, key) == value then
			return true
		end
		if upward then
			return node_class.check_attr(node, nil, key, value, upward)
		end
	else
		if node_class.attr(node, nil, key) == value then
			return true
		end
		if upward then
			local parent = node_class.parent(node)
			if parent then
				return node_class.check_attr(parent, nil, key, value, upward)
			end
		end

		return false
	end
end

function node_class.iter(node, filter, func)
	-- basic type
	if not check_node(node) then
		return
	end

	-- basic array
	local meta = node_class.meta(node)
	if meta:specifier() ~= "struct" then
		assert(node_class.array(node))
		return
	end

	local del
	-- self
	if not node_class.array(node) then
		if type(filter) == "string" then
			if meta:name() == filter or meta:inherit(filter) then
				del = func(node)
			end
		else
			assert(type(filter) == "function")
			if filter(node) then
				del = func(node)
			end
		end
	end

	if del then
		return true
	end

	-- children
	local children = node_class.children(node)
	if node_class.array(node) then
		local idx = 1
		repeat
			local child = children[idx]
			if not child then
				break
			end
			local del = node_class.iter(child, filter, func)
			if del then
				node_class.remove(node, idx)
			else
				idx = idx + 1
			end
		until(false)
	else
		for _, child in pairs(children) do
			local del = node_class.iter(child, filter, func)
			assert(not del)
		end
	end
end

node_mt = {
	__newindex = function(node, index, val)
		if check_node(val) then
			if not node_class.parent(val) then
				node_class.ctor(node, index, val)
				return
			end
			val = node_class.value(val)
		end

		node_class.assign(node, index, val)
	end,

	__index = function(node, index)
		assert(check_node(node))

		if node_class.array(node) then
			index = math.tointeger(index)
			if not index then
				return
			end
		end

		return node_class.children(node)[index]
	end,

	__pairs = function(node)
		local children = node_class.children(node)

		local function iter(_, index)
			return next(children, index)
		end
			
		return iter, children
	end,

	__len = function(node)
		return #node_class.children(node)
	end
}

-----------------------------------------------------
return {
	CTRL_BIT = CTRL_BIT,
	new = function(type, rawval, tree)
		return node_class.new(rawval, type, false, tree)
	end,

	assign = function(node, index, rawval, cbs)
		assert(check_node(node))
		return node_class.assign(node, index, rawval, cbs)
	end,

	ctor = function(node, index, child, cbs)
		assert(check_node(node))
		assert(check_node(child))
		return node_class.ctor(node, index, child, cbs)
	end,

	insert = function(node, index, rawval, type, cbs)
		assert(check_node(node))
		if check_node(rawval) then
			if node_class.parent(rawval) then
				type = type or node_class.type(rawval)
				rawval = node_class.value(rawval)
			end
		end
		return node_class.insert(node, index, rawval, type, cbs)
	end,

	remove = function(node, index, cbs)
		assert(check_node(node))
		return node_class.remove(node, index, cbs)
	end,

	move = function(node, from, to, cbs)
		assert(check_node(node))
		return node_class.move(node, from, to, cbs)
	end,

	set_attr = function(node, index, key, value, cbs)
		assert(check_node(node))
		return node_class.set_attr(node, index, key, value, cbs)
	end,

	attr = function(node, index, key)
		assert(check_node(node))
		if not key then
			index, key = key, index
		end

		return node_class.attr(node, index, key)
	end,

	dynamic_attrs = function(node, child)
		assert(check_node(node))

		if child then
			return node_class.dynamic_attrs(node) or {}
		else
			return node_class.dynamic_attrs(node)[0] or {}
		end
	end,

	check_attr = function(node, index, key, value, upward)
		assert(check_node(node))
		return node_class.check_attr(node, index, key, value, upward)
	end,

	path = function(node, root)
		assert(check_node(node))
		assert(not root or check_node(root))
		return node_class.path(node, root)
	end,

	value = function(node, index)
		assert(check_node(node))
		return node_class.value(node, index)
	end,

	parent = function(node)
		assert(check_node(node))
		return node_class.parent(node)
	end,

	meta = function(node)
		assert(check_node(node))
		return node_class.meta(node)
	end,

	join_undo_stack = function(node, stack)
		assert(check_node(node))
		return node_class.join_undo_stack(node, stack)
	end,

	check_type = function(node, type, array)
		assert(check_node(node))

		array = array or false

		repeat
			if node_class.type(node) == type then
				break
			end

			local meta = node_class.meta(node)
			if meta:specifier() == "struct" and meta:inherit(type) then
				break
			end			
			
			return false
		until(true)

		if node_class.array(node) ~= array then
			return false
		end

		return true
	end,

	undo_stack = function(node, key)
		assert(check_node(node))
		return node_class.undo_stack(node, key)
	end,

	tree = function(node)
		assert(check_node(node))
		return assert(node_class.tree(node_class.root(node)))
	end,

	key = function(node)
		assert(check_node(node))
		return node_class.key(node)
	end,

	attrs = function(node, index)
		assert(check_node(node))
		return node_class.attrs(node, index)
	end,

	iter = function(node, filter, func)
		assert(check_node(node))
		node_class.iter(node, filter, func)
	end
}
