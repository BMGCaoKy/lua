local Def = require "we.def"
local Signal = require "we.signal"
local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local Meta = require "we.gamedata.meta.meta"
local Recorder = require "we.gamedata.recorder"

local M = {}

M.SIGNAL = {
	ON_TREE_CHANGED = "ON_TREE_CHANGED"
}

local skip_update_tb = 
{
	--componentList中可能是part或partOperation，在比较过程中可能由于类型不一致导致assert失败
	componentList = true
}

function M:init()
	self._node_set = {}

	self._tree = nil
	self._dirty = false

	self._type = nil
	self._branch = nil				-- hold valid(same) data
	self._branch_dirty = {}

	self._actor = nil
	self._barrier_sync = {}		-- lua2qt
	self._barrier_op = false		-- qt2lua
end

local function node_to_value(value, include_children)
	if type(value) ~= "table" then
		return value
	end

	local ret = {}
	for k, v in pairs(value) do
		if (include_children or k ~= "children") then
			ret[k] = node_to_value(v, true)
		end
	end
	
	return ret
end

local ARRAY_MIX_ITEM = "__ARRAY_MIX_ITEM"
local function intersect(branch, vnode)
	assert(type(branch) == "table")

	local k, v = next(branch)
	local array = type(k) == "number"	-- branch is array
	repeat
		if not k then
			break
		end

		if vnode[k] ~= nil then
			if type(v) == "table" then
				if type(vnode[k]) ~= "table" then
					branch[k] = nil
				else
					intersect(v, vnode[k])
					if not next(v) then
						if not array then
							branch[k] = nil
						end
					end
				end
			else
				if v ~= vnode[k] then
					if array then
						branch[k] = ARRAY_MIX_ITEM
					else
						branch[k] = nil
					end
				end
			end
		else
			branch[k] = nil
		end
		k, v = next(branch, k)
	until(false)
end

local function union(branch, value)
	assert(type(branch) == "table")
	assert(type(value) == "table")

	for k, v in pairs(value) do
		if type(v) == "table" then
			if not branch[k] then
				branch[k] = v
			else
				assert(type(branch[k]) == "table")
				union(branch[k], v)
			end
		else
			branch[k] = v
		end
	end
end


local function set_mixed_attr(master, branch, bunch)
	branch = branch or {}
	local diff = false

	local meta = VN.meta(master)

	for identifier, type, array in meta:next_member() do
		local meta_member = Meta:meta(type)
		if array then
			if #branch < #master then
				for i = #master, #branch + 1, -1 do
					VN.remove(master, i, VN.CTRL_BIT.SYNC)
				end
			end

			for index, child in ipairs(master) do
				if meta_member:specifier() == "struct" then
					if set_mixed_attr(master[index], branch[index], bunch) then
						VN.set_attr(master, index, Def.ATTR_KEY_VALUE_MIXED, "true", VN.CTRL_BIT.SYNC)
						diff = true
					else
						VN.set_attr(master, index, Def.ATTR_KEY_VALUE_MIXED, nil, VN.CTRL_BIT.SYNC)
					end
				else
					if branch[index] == nil or branch[index] == ARRAY_MIX_ITEM then
						VN.set_attr(master, index, Def.ATTR_KEY_VALUE_MIXED, "true", VN.CTRL_BIT.SYNC)
						diff = true
					else
						VN.set_attr(master, index, Def.ATTR_KEY_VALUE_MIXED, nil, VN.CTRL_BIT.SYNC)
					end
				end
			end
		else
			if meta_member:specifier() == "struct" then
				if set_mixed_attr(master[identifier], branch[identifier], bunch) then
					VN.set_attr(master, identifier, Def.ATTR_KEY_VALUE_MIXED, "true", VN.CTRL_BIT.SYNC)
					diff = true
				else
					VN.set_attr(master, identifier, Def.ATTR_KEY_VALUE_MIXED, nil, VN.CTRL_BIT.SYNC)
				end
			else
				if branch[identifier] == nil or branch[identifier] == ARRAY_MIX_ITEM then
					VN.set_attr(master, identifier, Def.ATTR_KEY_VALUE_MIXED, "true", VN.CTRL_BIT.SYNC)
					diff = true
				else
					VN.set_attr(master, identifier, Def.ATTR_KEY_VALUE_MIXED, nil, VN.CTRL_BIT.SYNC)
				end
			end
		end
	end

	return diff
end

local function destory(self)
	if self._tree then
		TreeSet:delete(self._tree:id())
		Signal:publish(self, M.SIGNAL.ON_TREE_CHANGED, self._tree:id(), true)
		self._tree = nil
	end
end

local function set_sync_barrier(self, path, index, flag)
	if index then
		path = path .. "/" .. index
	end
	self._barrier_sync[path] = flag
end

local function sync_barrier(self, path, index)
	path = table.concat(path, "/")
	if index then
		path = path .. "/" .. index
	end
	return self._barrier_sync[path]
end

local function set_op_barrier(self, flag)
	assert(self._barrier_op ~= flag)
	self._barrier_op = flag
end

local function op_barrier(self)
	return self._barrier_op
end

local function multi_node(self)
	local count = 0
	for _ in pairs(self._node_set) do
		count = count + 1
		if count > 1 then
			return true
		end
	end
	return false
end

local function update_struct(self, master, slave)
	local function assign(master, slave, value)
		local meta = VN.meta(master)
		
		local attrs_slave = VN.dynamic_attrs(slave, true)
		local attrs_master = VN.dynamic_attrs(master, true)

		for identifier, type, array, attr in meta:next_member() do
			local meta_member = Meta:meta(type)
			if skip_update_tb[identifier] == nil then
				if array then
					if multi_node(self) then
						VN.set_attr(master, identifier, "Visible", "false", VN.CTRL_BIT.SYNC)
					else
						VN.set_attr(master, identifier, "Visible", VN.attr(self._actor, identifier, "Visible"), VN.CTRL_BIT.SYNC)
	
						local value = value[identifier]
						local master = master[identifier]
						local slave = slave[identifier]
	
						if #value > #master then
							for i = #master + 1, #value do
								VN.insert(master, i, value[i], nil, VN.CTRL_BIT.SYNC)
							end
						elseif #value < #master then
							for i = #master, #value + 1, -1 do
								VN.remove(master, i, VN.CTRL_BIT.SYNC)
							end
						end
	
						for i = 1, #value do
							if meta_member:specifier() == "struct" then
								assign(master[i], slave[i], value[i])
							else
								VN.assign(master, i, value[i], VN.CTRL_BIT.SYNC)
							end
						end
					end
				else
					if meta_member:specifier() == "struct" then
						if master[identifier][Def.OBJ_TYPE_MEMBER] ~= slave[identifier][Def.OBJ_TYPE_MEMBER] then
							VN.ctor(master, identifier, VN.new(slave[identifier][Def.OBJ_TYPE_MEMBER], value[identifier]), VN.CTRL_BIT.SYNC)
						else
							assign(master[identifier], slave[identifier], value[identifier])
						end
					else
						VN.assign(master, identifier, value[identifier], VN.CTRL_BIT.SYNC)
					end
				end
	
				local attrs_sm
				local attrs_mm
				if not array and meta_member:specifier() == "struct" then
					attrs_sm = VN.dynamic_attrs(slave[identifier])
					attrs_mm = VN.dynamic_attrs(master[identifier])
				else
					attrs_sm = attrs_slave[identifier] or {}
					attrs_mm = attrs_master[identifier] or {}				
				end
	
				for k, v in pairs(attrs_mm) do
					if attrs_sm[k] ~= v and k ~= Def.ATTR_KEY_VALUE_MIXED then
						VN.set_attr(master, identifier, k, attrs_sm[k], VN.CTRL_BIT.SYNC)
					end
				end
	
				for k, v in pairs(attrs_sm) do
					if attrs_mm[k] ~= v and k ~= Def.ATTR_KEY_VALUE_MIXED then
						VN.set_attr(master, identifier, k, v, VN.CTRL_BIT.SYNC)
					end
				end
			end--if not hide

		end--for meta_member
	end

	local meta = VN.meta(master)
	assign(master, slave, meta:ctor(node_to_value(slave)))
end

local function update_attrs(self)
	local types = {}
	for vnode in pairs(self._node_set) do
		local meta = VN.meta(vnode)
		types[meta:name()] = true
	end
	local master = self._tree:root()
	local meta = VN.meta(master)
	if meta:is("Instance_Spatial") and types["Instance_Entity"] then
		VN.set_attr(master.rotation, "x", "Enabled", "false", VN.CTRL_BIT.SYNC)
		VN.set_attr(master.rotation, "z", "Enabled", "false", VN.CTRL_BIT.SYNC)
	end

	if meta:is("Instance_Spatial") and types["Instance_DropItem"] then
		VN.set_attr(master.rotation, "x", "Enabled", "false", VN.CTRL_BIT.SYNC)
		VN.set_attr(master.rotation, "y", "Enabled", "false", VN.CTRL_BIT.SYNC)
		VN.set_attr(master.rotation, "z", "Enabled", "false", VN.CTRL_BIT.SYNC)
		VN.set_attr(master.size, "x", "Enabled", "false", VN.CTRL_BIT.SYNC)
		VN.set_attr(master.size, "y", "Enabled", "false", VN.CTRL_BIT.SYNC)
		VN.set_attr(master.size, "z", "Enabled", "false", VN.CTRL_BIT.SYNC)
	end
end

local function find_node(vnode, path)
	for name in string.gmatch(path, "[^/]+") do
		vnode = vnode[name]
	end

	return vnode
end

local function update_mixed_attr(master, bunch)
	local diff = set_mixed_attr(master, bunch._branch)

	local function check_child_prop(tgt_vnode, prop_name, val)
		local children = (tgt_vnode["children"] or {})["__children"]
		for idx,child in ipairs(children) do
			local valid_tb = Def.PROP_SUPPORT_TYPE[prop_name]
			if valid_tb == nil or valid_tb[tgt_vnode["class"]] then
				if child[prop_name] ~= val then
					return false
				end
			end
			if not check_child_prop(child, prop_name, val) then
				return false
			end
		end
		return true
	end

	local has_model = false
	for vnode in pairs(bunch._node_set) do
		if vnode["class"] == "Model" then
			has_model = true
			break
		end
	end
	if has_model then
		--Model的属性值受子节点的值的影响，当子节点的该属性值不一致的时候，model的该属性值显示为mixed
		for prop_name in pairs(Def.MODEL_PROPAGATABLE_PROP_TYPE) do
			local has_prop = (master[prop_name] ~= nil)
			local mix_attr = VN.attr(master, prop_name,Def.ATTR_KEY_VALUE_MIXED)
			if has_prop and mix_attr ~= "true" then
				for vnode in pairs(bunch._node_set) do
					local res = check_child_prop(vnode,prop_name,vnode[prop_name])
					if not res then
						VN.set_attr(master, prop_name, Def.ATTR_KEY_VALUE_MIXED, "true", VN.CTRL_BIT.SYNC)
						diff = true
						break
					end
				end --for (bunch._node_set)
			end
		end
	end --if has_model
	return diff
end

local function update_tree(self)
	if not self._type then
		destory(self)
		return
	end

	if not self._node_set[self._actor] then
		self._actor = assert(next(self._node_set))
	end

	local State = require "we.view.scene.state"
	if self._tree and VN.meta(self._tree:root()):name() == self._type and State:pb_type() == self._type then
		set_op_barrier(self, true)
		update_struct(self, self._tree:root(), self._actor)
		update_attrs(self)
		set_op_barrier(self, false)

		update_mixed_attr(self._tree:root(), self)
		return
	end

	destory(self)
	self._tree = TreeSet:create(self._type)
	set_op_barrier(self, true)
	update_struct(self, self._tree:root(), self._actor)
	update_attrs(self)
	set_op_barrier(self, false)
	update_mixed_attr(self._tree:root(), self)

	Signal:publish(self, M.SIGNAL.ON_TREE_CHANGED, self._tree:id())

	local o_set_attr = self._tree.set_attr
	self._tree.set_attr = function(_, path, index, key, value)
		set_sync_barrier(self, path, index, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				if key ~= Def.ATTR_KEY_VALUE_MIXED then
					VN.set_attr(find_node(vnode, path), index, key, value, VN.CTRL_BIT.NONE)
				end
			end
		end
		set_sync_barrier(self, path, index, false)

		o_set_attr(self._tree, path, index, key, value)
	end

	local o_assign = self._tree.assign
	self._tree.assign = function(_, path, index, rawval)
		local modify = false
		set_sync_barrier(self, path, index, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				local node = find_node(vnode, path)
				local sync = VN.attr(node, index, "Sync") == "true"
				modify = VN.assign(node, index, rawval, VN.CTRL_BIT.NOTIFY | VN.CTRL_BIT.RECORDE | (sync and VN.CTRL_BIT.SYNC or 0)) or modify
			end
		end
		set_sync_barrier(self, path, index, false)

		if modify then
			o_assign(self._tree, path, index, rawval)
			o_set_attr(self._tree, path, index, Def.ATTR_KEY_VALUE_MIXED, nil)

			-- TODO 因为没有 SYNC 所以 modify 没有设置，需要分开 SYNC 和 modify 的关系
			local Map = require "we.view.scene.map"
			Map:set_modify()
		end
	end

	local o_insert = self._tree.insert
	self._tree.insert = function(_, path, index, type, rawval)
		set_sync_barrier(self, path, index, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				VN.insert(find_node(vnode, path), index, rawval, type)
			end
		end
		set_sync_barrier(self, path, index, false)

		o_insert(self._tree, path, index, type, rawval)
	end

	local o_remove = self._tree.remove
	self._tree.remove = function(_, path, index)
		set_sync_barrier(self, path, index, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				VN.remove(find_node(vnode, path), index)
			end
		end
		set_sync_barrier(self, path, index, false)
		o_remove(self._tree, path, index)
	end

	local o_move = self._tree.move
	self._tree.move = function(_, path, from, to)
		set_sync_barrier(self, path, from, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				VN.move(find_node(vnode, path), from, to)
			end
		end
		set_sync_barrier(self, path, from, false)
		o_move(self._tree, path, from, to)
	end
end


local base_set_cache = {}
local function find_base_set(meta)
	local set = base_set_cache[meta:name()]
	if set then
		return set
	end

	local function list_base(meta, set)
		local base = meta:base()
		if not base then
			return
		end
		set[base] = true
		list_base(Meta:meta(base), set)
	end
	set = {}
	list_base(meta, set)

	base_set_cache[meta:name()] = set
	return set
end

local function common_base(meta_base, meta_curr)
	if meta_curr:is(meta_base) then
		return meta_base
	end
	if meta_base:is(meta_curr) then
		return meta_curr
	end

	local function find_meta(meta, set)
		local type = meta:name()
		if set[type] then
			return meta
		else
			local base = meta:base()
			if not base then
				return
			end
			return find_meta(Meta:meta(base), set)
		end
	end

	local set = find_base_set(meta_base)
	return find_meta(meta_curr, set)
end

function M:attach(vnode)
	if self._node_set[vnode] then
		return
	end
	
	self._node_set[vnode] = Signal:subscribe(vnode, Def.NODE_EVENT.ON_MODIFY, function(path, event, index, ...)
		if sync_barrier(self, path, index) then
			return
		end

		local cd = self._branch_dirty
		for i = 1, #path - 1 do
			local field = path[i]
			if cd[field] == true then
				return
			end
			cd[field] = cd[field] or {}
			cd = cd[field]
		end
		local field = path[#path]
		if event == Def.NODE_EVENT.ON_CTOR or event == Def.NODE_EVENT.ON_ASSIGN then
			if not field then
				cd[index] = true
				return
			end
			if cd[field] == true then
				return
			end
			cd[field] = cd[field] or {}
			cd[field][index] = true
		else
			-- array op
			assert(field)
			cd[field] = true
		end
	end)

	local function check_base_type()
		local meta_curr = VN.meta(vnode)
		if self._type then
			local meta_common = common_base(Meta:meta(self._type), meta_curr)
			return meta_common and meta_common:name()
		else
			return meta_curr:name()
		end
	end

	self._type = check_base_type()
	if not self._type then
		self._branch = nil
	elseif self._branch then
		intersect(self._branch, vnode)
	else
		self._branch = node_to_value(vnode) --深拷贝
	end

	self._dirty = true
end

function M:detach(vnode)
	if not self._node_set[vnode] then
		return
	end

	self._node_set[vnode]()
	self._node_set[vnode] = nil

	local function check_base_type()
		if not next(self._node_set) then
			return
		end

		local meta_curr = VN.meta(vnode)
		local meta_base = Meta:meta(self._type)
		if meta_base and meta_curr:inherit(meta_base) then
			return meta_base:name()
		else
			local meta_base = nil
			for vnode in pairs(self._node_set) do
				local meta_curr = VN.meta(vnode)
				if not meta_base then
					meta_base = meta_curr
				else
					if meta_base:inherit(meta_curr:name()) then
						meta_base = meta_curr
					else
						meta_base = common_base(meta_base, meta_curr)
						assert(meta_base)
					end
				end
			end

			return meta_base:name()
		end
	end

	self._type = check_base_type()
	if not self._type then
		self._branch = nil
	else
		local vnode = next(self._node_set)
		self._branch = node_to_value(vnode)

		repeat
			vnode = next(self._node_set, vnode)
			if not vnode then
				break
			end

			intersect(self._branch, vnode)
		until(false)
	end

	self._dirty = true
end

function M:clear()
	for _, cancel in pairs(self._node_set) do
		cancel()
	end
	self._node_set = {}

	self._type = nil
	self._branch = nil
	self._branch_dirty = {}

	self._dirty = true
end

function M:mark_dirty(path, index)
	local cd = self._branch_dirty
	for field in string.gmatch(path, "[^/]") do
		if cd[field] == true then
			return
		end
		cd[field] = cd[field] or {}
	end
	cd[index] = true
end

local function extract(value, branch)
	assert(type(value) == "table")

	local ret = {}
	for k, v in pairs(branch) do
		if value[k] then
			if type(v) == "table" then
				ret[k] = extract(value[k], v)
			else
				assert(v == true)
				ret[k] = value[k]
			end
		end
	end
	return ret
end

local function update_branch(self)
	if not next(self._branch_dirty) then
		return
	end

	local vnode = next(self._node_set)
	if not vnode then
		return
	end

	local value = node_to_value(vnode)
	value = extract(value, self._branch_dirty)
	union(self._branch, value)

	repeat
		vnode = next(self._node_set, vnode)
		if not vnode then
			break
		end

		intersect(self._branch, vnode)
	until(false)

	self._branch_dirty = {}
	self._dirty = true
end

function M:update()
	update_branch(self)

	if self._dirty then
		self._dirty = false
		update_tree(self)
	end
end

M:init()

return M
