local Def = require "we.def"
local Signal = require "we.signal"
local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local Meta = require "we.gamedata.meta.meta"
local Recorder = require "we.gamedata.recorder"

local M = {}

M.SIGNAL = {
	ON_TREE_CHANGED = "ON_TREE_CHANGED_UI",
	ON_TREE_NEED_SYNC = "ON_TREE_NEED_SYNC"
}

function M:init()
	self._node_set = {}
	self._sync_signal = nil
	self._item_path_list = nil
	self._items_path = {}

	self._tree = nil
	self._dirty = false
	
	self._type_for_rebuild = nil

	self._type = nil
	self._branch = nil				-- hold valid(same) data
	self._branch_dirty = {}

	self._actor = nil
	self._barrier_sync = false		-- lua2qt
	self._barrier_op = false		-- qt2lua
end

function M:attach_items(tree_id,item_path_list)
	local string_path_list = ""
	for _,path in ipairs(item_path_list) do
		string_path_list = string_path_list..path
	end
	if self:get_current_path_lsit() == string_path_list then
		return
	end

	if tree_id == "" then
		if not self:get_current_path_lsit() then
			return
		end

		self:clear()
		self:update()
		return
	end

	if not self:check_items_path(item_path_list) then
		return
	end
	self:clear()
	local tree = assert(TreeSet:tree(tree_id))
	local vnode_last
	for _,path in ipairs(item_path_list) do
		local vnode = tree:node(path)
		self:attach(vnode)
		vnode_last = vnode
	end
	self:bind_sync_signal(vnode_last)
	self:update()
	self:set_current_path_lsit(string_path_list)
	self:set_current_items_path(item_path_list)
end

-- Window 基本类型添加了音效; 有几个控件不显示这几个属性;属性面板不支持原本隐藏的控件后面再显示（需要后面reload）
-- 故添加check_rebuild 临时添加 Window not_show_sound 类型
local function check_rebuild(self)
	if self._type ~= "Window" then
		return self._type
	end

	for vnode in pairs(self._node_set) do
		local meta = VN.meta(vnode)
		local type_name = meta:name()
		if type_name == "DefaultWindow" or type_name == "HorizontalLayoutContainer" or type_name =="VerticalLayoutContainer" or type_name == "GridView" then
			return self._type.."not_show_sound"
		end
	end

	return self._type 
end


function M:check_items_path(items_path)
	if #items_path > 1 and #self._items_path == #items_path then
		return 
	end

	self._items_path = items_path
	return true
end

function M:set_current_items_path(items_path)
	self._items_path = items_path
end

function M:get_current_items_path()
	return self._items_path
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


local function set_mixed_attr(master, branch)
	if 1 then
		return
	end

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
					if set_mixed_attr(master[index], branch[index]) then
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
				if set_mixed_attr(master[identifier], branch[identifier]) then
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

local function set_sync_barrier(self, flag)
	assert(self._barrier_sync ~= flag)
	self._barrier_sync = flag
end

local function sync_barrier(self)
	return self._barrier_sync
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

		for identifier, type, array in meta:next_member() do
			local meta_member = Meta:meta(type)

			if array then
				if multi_node(self) then
					VN.set_attr(master, identifier, "Visible", "false", VN.CTRL_BIT.SYNC)
				else
					VN.set_attr(master, identifier, "Visible", "true", VN.CTRL_BIT.SYNC)

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
		end	
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

	local preset_ui_enable_attr = VN.attr(master,"preset_ui_enable","Visible")
	if preset_ui_enable_attr == "true" then
		return
	end

	local show_sound = true
	local count = 0
	for k,v in pairs(types) do
		count = count + 1
		if k == "DefaultWindow" or k == "HorizontalLayoutContainer" or k =="VerticalLayoutContainer" or k == "GridView" then
			show_sound = false
		end
	end

	local string_show_sound = show_sound and "true" or "false"
	VN.set_attr(master,"SoundTriggerRange","Visible",string_show_sound,VN.CTRL_BIT.SYNC)
	VN.set_attr(master,"Volume","Visible",string_show_sound,VN.CTRL_BIT.SYNC)
	VN.set_attr(master,"SoundFile","Visible",string_show_sound,VN.CTRL_BIT.SYNC)

	if count > 1 then
		VN.set_attr(master,"gui_type","HIDE","true",VN.CTRL_BIT.SYNC)
	else 
		
	end

	VN.set_attr(master,"name","Enabled","false",VN.CTRL_BIT.SYNC)
	VN.set_attr(master,"script","HIDE","true",VN.CTRL_BIT.SYNC)
	VN.set_attr(master,"triggers","HIDE","true",VN.CTRL_BIT.SYNC)
	VN.set_attr(master,"anchor","HIDE","true",VN.CTRL_BIT.SYNC)
end

local function find_node(vnode, path)
	for name in string.gmatch(path, "[^/]+") do
		vnode = vnode[name]
		if not vnode then
			return
		end
	end

	return vnode
end

local function update_tree(self)
	if not self._type then
		destory(self)
		return
	end

	--if not self._node_set[self._actor] then
	--	self._actor = assert(next(self._node_set))
	--end

	local type_for_rebuild = check_rebuild(self)
	if not self._type_for_rebuild or type_for_rebuild ~= self._type_for_rebuild then
		self._type_for_rebuild = type_for_rebuild
	else
		local State = require "we.view.scene.state"
		if self._tree and VN.meta(self._tree:root()):name() == self._type and State:pb_type() == self._type then
			set_op_barrier(self, true)
			update_struct(self, self._tree:root(), self._actor)
			update_attrs(self)
			set_op_barrier(self, false)

			--set_mixed_attr(self._tree:root(), self._branch)
			return
		end
	end


	destory(self)
	self._tree = TreeSet:create(self._type)
	set_op_barrier(self, true)
	update_struct(self, self._tree:root(), self._actor)
	update_attrs(self)
	set_op_barrier(self, false)
	set_mixed_attr(self._tree:root(), self._branch)

	Signal:publish(self, M.SIGNAL.ON_TREE_CHANGED, self._tree:id())

	local o_set_attr = self._tree.set_attr
	self._tree.set_attr = function(_, path, index, key, value)
		set_sync_barrier(self, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				if key ~= Def.ATTR_KEY_VALUE_MIXED then
					VN.set_attr(find_node(vnode, path), index, key, value, VN.CTRL_BIT.NONE)
				end
			end
		end
		set_sync_barrier(self, false)

		o_set_attr(self._tree, path, index, key, value)
	end

	local o_assign = self._tree.assign
	self._tree.assign = function(_, path, index, rawval)
		local modify = false
		set_sync_barrier(self, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				local node = find_node(vnode, path)
				local sync = VN.attr(node, index, "Sync") == "true"
				sync = 1
				modify = VN.assign(node, index, rawval, VN.CTRL_BIT.NOTIFY | VN.CTRL_BIT.RECORDE | (sync and VN.CTRL_BIT.SYNC or 0)) or modify
			end
		end
		set_sync_barrier(self, false)

		if modify then
			o_assign(self._tree, path, index, rawval)
			o_set_attr(self._tree, path, index, Def.ATTR_KEY_VALUE_MIXED, nil)
		end
	end

	local o_insert = self._tree.insert
	self._tree.insert = function(_, path, index, type, rawval)
		set_sync_barrier(self, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				VN.insert(find_node(vnode, path), index, rawval, type)
			end
		end
		set_sync_barrier(self, false)

		o_insert(self._tree, path, index, type, rawval)
	end

	local o_remove = self._tree.remove
	self._tree.remove = function(_, path, index)
		set_sync_barrier(self, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				VN.remove(find_node(vnode, path), index)
			end
		end
		set_sync_barrier(self, false)
		o_remove(self._tree, path, index)
	end

	local o_move = self._tree.move
	self._tree.move = function(_, path, from, to)
		set_sync_barrier(self, true)
		if not op_barrier(self) then
			for vnode in pairs(self._node_set) do
				VN.move(find_node(vnode, path), from, to)
			end
		end
		set_sync_barrier(self, false)
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

function M:bind_sync_signal(vnode)

	self._actor = vnode
	if self._sync_signal then
		return
	end

	self._sync_signal = Signal:subscribe(vnode, Def.NODE_EVENT.ON_MODIFY, function(path, event, index, ...)
		if sync_barrier(self) then
			return
		end

		path = table.concat(path, "/")

		-- children事件不需要同步
		if string.find(path,"children") then
			return
		end

		local node_notify = find_node(vnode,path)
		local rawval_curent = VN.value(node_notify,index)

		set_op_barrier(self,true)
		local node = find_node(self._tree:root(),path)
		if node then
			local modify = VN.assign(node, index, rawval_curent, VN.CTRL_BIT.NOTIFY  |  VN.CTRL_BIT.SYNC )
		end
		set_op_barrier(self,false)

	end)
end

function M:attach(vnode)
	if self._node_set[vnode] then
		return
	end
	
	self._node_set[vnode] = Signal:subscribe(vnode, Def.NODE_EVENT.ON_MODIFY, function(path, event, index, ...)
		if sync_barrier(self) then
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
		self._branch = node_to_value(vnode) --���
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



function M:get_current_path_lsit()
	return self._item_path_list
end

function M:set_current_path_lsit(_item_path_list)
	self._item_path_list = _item_path_list
end

function M:clear()
	for _, cancel in pairs(self._node_set) do
		cancel()
	end
	self._node_set = {}

	if self._sync_signal then
		self._sync_signal()
		self._sync_signal = nil
	end
	
	self._item_path_list = nil
	self._items_path = {}
	--self._type_for_rebuild = nil
	self._type = nil
	self._branch = nil
	self._branch_dirty = {}

	self._dirty = true
end

function M:mark_dirty(path, index)
	local cd = self._branch_dirty
	for filed in string.gmatch(path, "[^/]") do
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
