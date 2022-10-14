local Def = require "editor.def"
local Meta = require "editor.gamedata.meta.meta"
local Proto = require "editor.gamedata.proto"
local Attr = require "editor.gamedata.attr"
local Signal = require "editor.signal"
local Lang = require "editor.gamedata.lang"
local engine = require "editor.engine"

local M = {}

function M:init(name, item_type)
	self._name = name
	self._item_type = item_type
	self._items = {}

	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_MODIFY, function(module)
		if module == self._name then
			Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
		end
	end)
	
	assert(Meta:meta(item_type), item_type)
end

function M:list()
	return self._items
end

function M:name()
	return self._name
end

function M:item_type()
	return self._item_type
end

function M:item(id)
	return assert(self._items[id], string.format("item %s is not exist in module %s", id, self:name()))
end

-- 是否生成 mapping
function M:mapping()
	return false
end

-- 是否需要同步到引擎
function M:need_reload()
	return false
end

function M:load(version)
	assert(version)
	
	local ok, loader = pcall(require, string.format("editor.gamedata.module.class.module_%s.loader.%s", self._name, version))
	assert(ok, loader)
	
	local data = loader()
	local i = 0
	local tot = 0
	for _ in pairs(data.items) do
		tot = tot + 1
	end

	for id, v in pairs(data.items) do
		local path = v.path
		local item = v.data

		local item_version = assert(item.meta[Def.ITEM_META_VERSION])
		local type = self._item_type

		-- verify
		local meta_set = Meta:meta_set(item_version)
		local meta = meta_set:meta(type)
		local ok, errmsg = meta:verify(item.data)
		assert(ok, string.format("%s data error:\n %s", path, errmsg))

		-- upgrade
		local val, version = Meta:upgrade(item.data, item_version)
		assert(version == Meta:version())

		-- verify
		meta = Meta:meta(type)
		assert(meta:verify(val))

		self:create_item(val, id)
		i = i + 1
		engine:on_game_load_progress_changed("loading "..self._name,i/tot*100)
	end
	
	Lib.emitEvent(Event.EVENT_EDITOR_MODULE_LOADED, self:name())
end

function M:save()
	for id, item in pairs(self._items) do
		if item:modified() then
			item:save()
			Lib.emitEvent(Event.EVENT_EDITOR_ITEM_SAVE, self:name(), id)
		end
	end
	for _, item in pairs(self._to_del_items or {}) do
		print("del_item : " .. item:dir())
		Lib.rmdir(item:dir())
	end
end

function M:new_item(id, val)
	local meta = Meta:meta(self._item_type)
	local id = id or GenUuid()
	local item = self:create_item(meta:ctor(val, nil, nil, true), id)
	item:set_modified(true)

	self:on_new_item(id)
	return item
end

function M:copy_item(target_item_id)
	local meta = Meta:meta(self._item_type)
	local id = GenUuid()
	Meta:meta("Text"):set_processor(function(val)
		local target = val.value
		val.value = GenUuid()
		Lang:copy_text(val.value, target)
		return val
	end)
	local target_item = self:item(target_item_id)
	local val = meta:process(meta:ctor(target_item:user_data(), nil, nil, true))
	Meta:meta("Text"):set_processor(nil)
	local item = self:create_item(val, id)
	item:set_modified(true)

	self:on_new_item(id)
	return item
end

function M:del_item(id)
	local item = self._items[id]
	assert(item, id)

	self._to_del_items = self._to_del_items or {}
	self._to_del_items[id] = item

	self._items[id] = nil
	self:on_del_item(id)
end

function M:on_new_item(id)
	Proto:notify(Def.PROTO_ITEM_NEW, self:name(), id)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	Lib.emitEvent(Event.EVENT_EDITOR_ITEM_NEW, self:name(), id)
end

function M:on_del_item(id)
	Proto:notify(Def.PROTO_ITEM_DEL, self:name(), id)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	Lib.emitEvent(Event.EVENT_EDITOR_ITEM_DEL, self:name(), id)
end

function M:on_modify_item(id, op, path, ...)
	Proto:notify(op, self._name, id, path, ...)
end

local NODE_MEMBER_ID_PARENT = {}
local NODE_MEMBER_ID_ITEM = {}
local NODE_MEMBER_ID_TYPE = {}
local NODE_MEMBER_ID_META = {}
local NODE_MEMBER_ID_ARRAY = {}
local NODE_MEMBER_ID_CHILDREN = {}
local NODE_MEMBER_ID_CHANGED = {}

local raw_set = true
local set = function(node, index, val)
	raw_set = false
	node[index] = val
end

local function equal(new, old)
	if new == old then
		return true
	end

	if type(new) ~= type(old) then
		return false
	end

	if _G.type(new) == "table" then
		local e = true
		for k, v in pairs(old) do
			if not equal(v, new[k]) then
				e = false
				break
			end
		end
		return e
	end

	return false
end

local node_class
local node_mt = {
	__newindex = function(node, key, val)
		key = math.tointeger(key) or key
		local rs = raw_set
		raw_set = true

		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		local val = Lib.copy(val)
		local oval = _children[key]
		if equal(val, oval) then
			return
		end

		local is_ctor = false
		local mtype, array
		if _array then
			mtype = _type
			array = false	-- 数组不能嵌套数组
		else
			mtype, array = _meta:member(key)
		end
		assert(mtype, string.format("%s is not member of %s", key, _type))

		local type = _G.type(val) == "table" and val[Def.OBJ_TYPE_MEMBER]
		if not type then
			-- base type
			type = mtype
			local meta = assert(Meta:meta(type), type)
			assert(meta:verify(val))
			val = meta:ctor(val)
		else
			local meta = Meta:meta(type)
			assert(meta:verify(val))
			is_ctor = meta:specifier() == "struct"
		end

		_children[key] = node_class.new(_item, val, type, array, node)
		if _array then
			_changed[1] = #_children
		else
			_changed[key] = true
		end

		-- 通知父结点
		do
			if _parent then
				node_class.mark_up(_parent, node_class.key(node))
			end

			if _G.type(val) == "table" then
				node_class.mark_down(_children[key], val)
			end
		end

		-- 通知界面
		do
			local path = node_class.path(node)
			local full_path = table.concat(path, "/")

			if is_ctor then
				_item:on_modify(Def.PROTO_PROPERTY_CTOR, full_path, key, val)
			else
				_item:on_modify(Def.PROTO_PROPERTY_ASSIGN, full_path, key, val)
			end
		end

		-- 抛出修改
		Signal:publish(node, Def.SIGNAL.PROPERTY_MODIFY, key)

		-- 属性修改后处理
		do
			local func
			if _array then
				node_class.on_modify(_parent, key, Lib.copy(oval), {key}, rs)
			else
				node_class.on_modify(node, key, Lib.copy(oval), {key}, rs)
			end
		end
	end,

	__index = function(node, key)
		local _children = node[NODE_MEMBER_ID_CHILDREN]

		key = math.tointeger(key) or key
		return _children[key]
	end,

	__pairs = function(node)
		local _children = node[NODE_MEMBER_ID_CHILDREN]

		local function iter(_, key)
			return next(_children, key)
		end
			
		return iter, _children
	end,

	__len = function(node)
		local _children = node[NODE_MEMBER_ID_CHILDREN]

		return #_children
	end
}

local monitor_env_funcs = {
	ctor = function(type, rawval)
		local meta = assert(Meta:meta(type), type)
		return meta:ctor(rawval)
	end,

	set = set,

	insert = function(node, index, val)
		if not val then
			index, val = #node + 1, index
		end

		node_class.on_array_insert(
			node,
			index,
			val,
			_G.type(val) == "table" and val[Def.OBJ_TYPE_MEMBER]
		)
	end,

	remove = function(node, index)
		node_class.on_array_remove(node, index)
	end,

	move = function(node, from, to)
		node_class.on_array_move(node, from, to)
	end,
}

node_class = {
	new = function(item, val, type, array, parent)
		if _G.type(val) ~= "table" then
			return val
		end

		type = val[Def.OBJ_TYPE_MEMBER] or type
		local node = {
			[NODE_MEMBER_ID_PARENT] = parent,
			[NODE_MEMBER_ID_ITEM] = assert(item),
			[NODE_MEMBER_ID_TYPE] = type,
			[NODE_MEMBER_ID_META] = assert(Meta:meta(type), type),
			[NODE_MEMBER_ID_ARRAY] = array,
			[NODE_MEMBER_ID_CHILDREN] = {},
			[NODE_MEMBER_ID_CHANGED] = {}
		}

		do
			local _item = node[NODE_MEMBER_ID_ITEM]
			local _type = node[NODE_MEMBER_ID_TYPE]
			local _children = node[NODE_MEMBER_ID_CHILDREN]
			local _array = node[NODE_MEMBER_ID_ARRAY]
			local _meta = node[NODE_MEMBER_ID_META]

			for k, v in pairs(val) do
				if _array then
					_children[k] = node_class.new(_item, v, _type, false, node)
				else
					local mtype, array = _meta:member(k)	-- node: v 可能不是 member
					if not mtype then
						_children[k] = v
					else
						_children[k] = node_class.new(_item, v, mtype, array, node)
					end
				end
			end
		end

		return setmetatable(node, node_mt)
	end,

	key = function(node)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		assert(_parent)

		for k, v in pairs(_parent[NODE_MEMBER_ID_CHILDREN]) do
			if v == node then
				return k
			end
		end

		assert(false)
	end,

	path = function(node, path)
		local _parent = node[NODE_MEMBER_ID_PARENT]

		path = path or {}
		if not _parent then
			return path
		end

		table.insert(path, 1, node_class.key(node))
		return node_class.path(_parent, path)
	end,

	on_modify = function(node, key, oval, path, raw_set)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]

		path = Lib.copy(path)
	
		local forward = true	-- 是否向父结点传递
		if not raw_set and not _array then
			local monitor = _meta:monitor(key)

			if monitor then
				local func = load(
					monitor,
					table.concat(path, "/"),
					"bt",
					setmetatable(monitor_env_funcs, {__index = _G})
				)
				forward = func(node, path, oval)
			end
		end

		if forward and _parent then
			local key = node_class.key(node)
			table.insert(path, 1, key)
			
			node_class.on_modify(_parent, key, oval, path)
		end

		_item:set_modified(true)
	end,

	on_array_insert = function(node, index, rawval, type)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		assert(_array)

		type = type or _type
		local meta = assert(Meta:meta(type), type)
		local val = meta:ctor(rawval)
		index = index or #_children + 1
		local child = node_class.new(_item, val, type, false, node)
		node_class.mark_down(child, val)
		table.insert(_children, index, child)
		_changed[1] = #_children

		-- 通知父结点
		do
			node_class.mark_up(_parent, node_class.key(node))
		end

		-- 通知界面
		do
			local path = node_class.path(node)
			local full_path = table.concat(path, "/")

			_item:on_modify(Def.PROTO_PROPERTY_ARRAY_INSERT, full_path, index, val)
		end

		Signal:publish(node, Def.SIGNAL.PROPERTY_ARRAY_INSERT, index)

		_item:set_modified(true)
		return index
	end,

	on_array_remove = function(node, index)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		assert(_array)
		index = index or #_children

		-- 标记父结点
		do
			node_class.mark_up(_parent, node_class.key(node))
		end

		-- 通知界面
		do
			local path = node_class.path(node)
			local full_path = table.concat(path, "/")

			_item:on_modify(Def.PROTO_PROPERTY_ARRAY_REMOVE, full_path, index)
		end

		-- 通知
		Signal:publish(node, Def.SIGNAL.PROPERTY_ARRAY_REMOVE, index)

		table.remove(_children, index)
		_changed[1] = #_children
		_item:set_modified(true)
	end,

	on_array_move = function(node, from, to)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		assert(_array)

		table.insert(_children, to, table.remove(_children, from))
		_changed[1] = #_children

		-- 通知父结点
		do
			node_class.mark_up(_parent, node_class.key(node))
		end

		-- 通知界面
		do
			local path = node_class.path(node)
			local full_path = table.concat(path, "/")

			_item:on_modify(Def.PROTO_PROPERTY_ARRAY_MOVE, full_path, from, to)
		end

		Signal:publish(node, Def.SIGNAL.PROPERTY_ARRAY_MOVE, from, to)
		_item:set_modified(true)
	end,

	attr = function(node, index, key)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		if _array then
			return nil
		end

		local _, _, attrs = _meta:member(index)
		return attrs[key]
	end,

	check_reload_attr = function(node, index)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		local reload = false

		if index then
			local reload = node_class.attr(node, index, Def.ATTR_KEY_RELOAD)
			if reload then
				return Attr.to_bool(reload, false)
			end
		end

		if _parent then
			return node_class.check_reload_attr(_parent, node_class.key(node))
		end

		return false
	end,

	mark_down = function(node, data)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		if _G.type(data) ~= "table" then
			return
		end

		if _array then
			_changed[1] = #_children
		end

		for k, v in pairs(data) do
			if not _array then
				_changed[k] = true
			end

			local child = _children[k]
			if _G.type(child) == "table" then
				node_class.mark_down(child, v)
			end
		end
	end,

	mark_up = function(node, key)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		if _array then
			local count = _changed[1]
			if count and count >= #_children then
				return
			end

			_changed[1] = #_children
		else
			if _changed[key] then
				return
			end

			_changed[key] = true
		end
		
		if _parent then
			node_class.mark_up(_parent, node_class.key(node))
		end
	end,

	fetch_user_data = function(node)
		local _parent = node[NODE_MEMBER_ID_PARENT]
		local _item = node[NODE_MEMBER_ID_ITEM]
		local _type = node[NODE_MEMBER_ID_TYPE]
		local _meta = node[NODE_MEMBER_ID_META]
		local _array = node[NODE_MEMBER_ID_ARRAY]
		local _children = node[NODE_MEMBER_ID_CHILDREN]
		local _changed = node[NODE_MEMBER_ID_CHANGED]

		local ret = {}

		if _array then
			local count = _changed[1] or 0
			for i = 1, count do
				assert(_G.type(_children[i]) ~= "nil", i)
				local child = _children[i]
				if _G.type(child) == "table" then
					ret[i] = node_class.fetch_user_data(child)
				else
					ret[i] = child
				end
			end
		else
			for k in pairs(_changed) do
				assert(_G.type(_children[k]) ~= "nil", k)
				local child = _children[k]
				if _G.type(child) == "table" then
					ret[k] = node_class.fetch_user_data(child)
				else
					ret[k] = child
				end
			end
			ret[Def.OBJ_TYPE_MEMBER] = _type
		end

		return ret
	end
}

local item_class = {
	init = function(self, module, val, id)
		self._module = module
		self._id = id
		self._modified = false

		local type = self._module:item_type()
		local meta = Meta:meta(type)
		assert(meta:verify(val))

		self._root = node_class.new(self, meta:ctor(val), type, false)
		node_class.mark_down(self._root, val)
	end,

	on_modify = function(self, op, path, ...)
		self._module:on_modify_item(self._id, op, path, ...)

		local node = self._root
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		local index
		if op == Def.PROTO_PROPERTY_CTOR or op == Def.PROTO_PROPERTY_ASSIGN then
			index = ...
		end

		local reload = node_class.check_reload_attr(node, index)
		Lib.emitEvent(Event.EVENT_EDITOR_ITEM_MODIFY, self._module:name(), self._id, reload)
	end,

	modify = function(self, path, index, rawval)
		local node = self._root
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		set(node, index, rawval)
	end,

	insert = function(self, path, index, type, rawval)
		local node = self._root
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		return node_class.on_array_insert(node, index, rawval, type)
	end,

	remove = function(self, path, index)
		local node = self._root
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		node_class.on_array_remove(node, index)
	end,

	move = function(self, path, from, to)
		local node = self._root
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		node_class.on_array_move(node, from, to)
	end,

	id = function(self)
		return self._id
	end,

	set_modified = function(self, flag)
		if flag == self._modified then
			return
		end

		self._modified = flag
	end,

	modified = function(self)
		return self._modified
	end,

	val = function(self)
		return Lib.copy(self._root)
	end,

	user_data = function(self)
		return node_class.fetch_user_data(self._root)
	end,

	obj = function(self)
		return self._root
	end,

	dir = function(self)
		return Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self._module:name(), "item", self._id)
	end,

	save = function(self)
		local item = {
			meta = {
				[Def.ITEM_META_VERSION] = Meta:version()
			},
			data = self:user_data()
		}
		
		local dir = self:dir()
		Lib.mkPath(dir)
		local path = Lib.combinePath(dir, "setting.json")
		local file, errmsg = io.open(path, "w+b")
		assert(file, errmsg)
		file:write(Lib.toJson(item))
		file:close()	

		self:set_modified(false)
	end
}

function M:create_item(val, id)
	assert(not self._items[id], id)
	assert(type(val) == "table")

	local item = Lib.derive(item_class)
	item:init(self, val, id)
	self._items[id] = item
	return item
end

function M:dump()
	Lib.emitEvent(Event.EVENT_EDITOR_MODULE_DUMP, self:name())
end

return M
