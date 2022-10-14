local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"
local IWorld = require "we.engine.engine_world"
local VN = require "we.gamedata.vnode"
local Module = require "we.gamedata.module.module"

local M = {}

local STORAGE_ROOT_NAME = "storage_tree" -- 必须和cpp同名

local has_collision_cls = {
	MeshPart = true,
	PartOperation = true
}

--实例class对应module名字
local CLASS_MODULE_NAME = {
	Part			= "part",
	MeshPart		= "meshpart",
	PartOperation	= "part_operation"
}

--可加入零件仓库类型
local STORAGE_TYPE = {
	Instance_Part			= "Instance_Part_Storage",
	Instance_MeshPart		= "Instance_MeshPart_Storage",
	Instance_Model			= "Instance_Model",
	Instance_PartOperation	= "Instance_PartOperation_Storage"
}

local function get_storage_type_key(type)
	for key,value in pairs(STORAGE_TYPE) do
		if type == value then
			return key
		end
	end
end

-- Instance_xxx to Instance_xxx_Storage
local function update_to_storage(val)
	local function reg_proc()
		for key,value in pairs(STORAGE_TYPE) do
			if key ~= value then
				local meta = Meta:meta(key)
				meta:set_processor(function(val)
					local type = assert(val[Def.OBJ_TYPE_MEMBER])
					local ret = Meta:meta(STORAGE_TYPE[type]):ctor(val)
					--return meta:process_(ret)
					return ret
				end)
			end
		end
	end

	local function unreg_proc()
		for key,value in pairs(STORAGE_TYPE) do
			if key ~= value then
				local meta = Meta:meta(key)
				meta:set_processor(nil)
			end
		end
	end

	reg_proc()

	local type = assert(val[Def.OBJ_TYPE_MEMBER])
	local meta = Meta:meta(type)
	val = meta:process(val)

	unreg_proc()

	return val
end

-- Instance_xxx_Storage to Instance_xxx
local function update_to_instance(val)
	local function reg_proc()
		for key,value in pairs(STORAGE_TYPE) do
			if key ~= value then
				local meta = Meta:meta(value)
				meta:set_processor(function(val)
					local type = assert(val[Def.OBJ_TYPE_MEMBER])
					local key_type = get_storage_type_key(type)
					assert(key_type)
					local ret = Meta:meta(key_type):ctor(val)
					--return meta:process_(ret)
					return ret
				end)
			end
		end
	end

	local function unreg_proc()
		for key,value in pairs(STORAGE_TYPE) do
			if key ~= value then
				local meta = Meta:meta(value)
				meta:set_processor(nil)
			end
		end
	end

	reg_proc()

	local type = assert(val[Def.OBJ_TYPE_MEMBER])
	local meta = Meta:meta(type)
	val = meta:process(val)

	unreg_proc()

	return val
end

--更换id/btsKey/mergeShapesDataKey/collisionKeys
local function replace_id(ids, val, ignore_collision_flag)
	local btsKeys = {}
	local mergeKeys = {}
	local collisionKeys = {}

	local function mapping_id(id)
		if not ids[id] then
			ids[id] = tostring(IWorld:gen_instance_id())
		end

		return ids[id]
	end

	local function reg_proc()
		do
			local meta = Meta:meta("Instance")
			meta:set_processor(function(val)
				local ret = Lib.copy(val)
				ret.selected = false
				ret.id = mapping_id(val.id)
				--set collisionUniqueKey
				if "PartOperation" == val.class or "MeshPart" == val.class then
					if ignore_collision_flag then
						collisionKeys[val.collisionUniqueKey] = val.collisionUniqueKey
					else
						--deal reuse collision file
						if val.collisionUniqueKey and "" ~= val.collisionUniqueKey then
							collisionKeys[ret.id] = val.collisionUniqueKey
						else
							collisionKeys[ret.id] = val.id
						end
						ret.collisionUniqueKey = ret.id
					end
				end
				if val.btsKey then
					local newKey = GenUuid()
					btsKeys[newKey] = val.btsKey
					ret.btsKey = newKey
				end
				if val.mergeShapesDataKey then
					local newKey = tostring(IWorld:gen_instance_id())
					mergeKeys[newKey] = val.mergeShapesDataKey
					ret.mergeShapesDataKey = newKey
				end
				--return meta:process_(ret)
				return ret
			end)
		end

		do
			local meta = Meta:meta("Instance_ConstraintBase")
			meta:set_processor(function(val)
				local ret = Lib.copy(val)
				ret.masterPartID = mapping_id(val.masterPartID)
				ret.slavePartID = mapping_id(val.slavePartID)
				--return meta:process_(ret)
				return ret
			end)
		end
	end

	local function unreg_proc()
		local meta = Meta:meta("Instance")
		meta:set_processor(nil)
		meta = Meta:meta("Instance_ConstraintBase")
		meta:set_processor(nil)
	end

	reg_proc()

	local type = assert(val[Def.OBJ_TYPE_MEMBER])
	local meta = Meta:meta(type)
	val = meta:process(val)

	unreg_proc()

	return val, btsKeys, mergeKeys, collisionKeys
end

local function inc_collision_ref_cnt(self_, collision_key_set)
	for new, old in pairs(collision_key_set) do
		local ref_cnt = self_.collision_file_ref_cnt[new]
		if _G.type(ref_cnt) == "number" then
			self_.collision_file_ref_cnt[new] = ref_cnt + 1
		else
			self_.collision_file_ref_cnt[new] = 1
		end
	end
end

local function dec_collision_ref_cnt(self_, collision_key_list)
	for idx, key in pairs(collision_key_list) do
		local ref_cnt = self_.collision_file_ref_cnt[key]
		if _G.type(ref_cnt) == "number" then
			self_.collision_file_ref_cnt[key] = ref_cnt - 1
		end
	end
end

local function clear_unref_collision_file(self_)
	local item = self_._root
	for key,cnt in pairs(self_.collision_file_ref_cnt) do
		if cnt and cnt <= 0 then
			item:del_storage_collision_files(key)
			self_.collision_file_ref_cnt[key] = nil
		end
	end
end

local function collect_collision_key(val)
	local collision_key_list = {}
	local function reg_proc()
		do
			local meta = Meta:meta("Instance")
			meta:set_processor(function(val)
				if has_collision_cls[val.class] then
					--deal reuse ollision file
					if val.collisionUniqueKey and "" ~= val.collisionUniqueKey then
						table.insert(collision_key_list, val.collisionUniqueKey)
					end
				end
				--return meta:process_(val)
				return val
			end)
		end
	end

	local function unreg_proc()
		local meta = Meta:meta("Instance")
		meta:set_processor(nil)
	end

	reg_proc()
	Meta:meta(assert(val[Def.OBJ_TYPE_MEMBER])):process(val)
	unreg_proc()

	return collision_key_list
end

local function init_collision_ref_cnt(self_)
	local function filter(node)
		return true
	end
	local function func(node)
		local node_class = node["class"]
		if has_collision_cls[node_class] then
			local key = node["collisionUniqueKey"]
			if key and 0<#key then
				local ref_cnt = self_.collision_file_ref_cnt[key]
				if _G.type(ref_cnt) == "number" then
					self_.collision_file_ref_cnt[key] = ref_cnt + 1
				else
					self_.collision_file_ref_cnt[key] = 1
				end
			end
		end
		return false
	end

	local tree = self_._root:data()
	local node = tree:root()
	VN.iter(node,filter,func)
end

function M:init()
	--创建根节点
	local m = Module:module("storage")
	assert(m)
	local name = STORAGE_ROOT_NAME
	if not m:list()[name] then
		local type = m:item_type()
		local obj = Meta:meta(m:item_type()):ctor({})
		--零件仓库：create_item即可
		m:create_item(name, obj)
	end
	self._root = m:item(name)
	--collision key - ref count
	self.collision_file_ref_cnt = {}
	init_collision_ref_cnt(self)
end

local function copy_trigger_item(val, btsKeys, dst, src)
	if val.btsKey and "" ~= val.btsKey then
		local class = CLASS_MODULE_NAME[val.class]
		if class then
			local module_src = Module:module(src .. class)
			assert(module_src)

			if module_src:list()[btsKeys[val.btsKey]] then
				local item = module_src:item(btsKeys[val.btsKey])
				local value = item:val()
				if next(value.triggers.list) then
					local module_dst = Module:module(dst .. class)
					assert(module_dst)
					module_dst:new_item(val.btsKey, value)
				end
			end
		end
	end
	for _,child in ipairs(val.children) do
		copy_trigger_item(child, btsKeys, dst, src)
	end
end

function M:add_storage(list)
	if not list or not next(list) then
		return
	end
	local item = self._root
	local tree = item:data()

	local ids = {} -- 为了约束使用新id
	for _,val in ipairs(list) do
		local type = assert(val[Def.OBJ_TYPE_MEMBER])
		if STORAGE_TYPE[type] then
			val = update_to_storage(val)
			--replace id、btsKey、mergeShapesDataKey
			local newVal, btsKeys, mergeKeys, collisionKeys = replace_id(ids, val)
			--add instances
			tree:insert("instances", nil, nil, newVal, nil)
			--save bts
			copy_trigger_item(newVal, btsKeys, "storage_", "")
			--copy mergeShapesDataKeFiles
			item:storage_copy_files(mergeKeys, collisionKeys)

			inc_collision_ref_cnt(self, collisionKeys)
		end
	end
	item:set_modified(true)
	item:save()
end

function M:repetition_item(paths)
	if not next(paths) then
		return
	end
	local function find_parent(node)
		local parent = VN.parent(node)
		while(parent) do
			local type = VN.value(parent)[Def.OBJ_TYPE_MEMBER]
			if type and "Instance_Folder" == type then
				return VN.path(parent) .. "/children"
			end
			parent = VN.parent(parent)
		end
		return "instances"
	end

	local item = self._root
	local tree = item:data()
	local ids = {} -- 为了约束使用新id
	for _,path in ipairs(paths) do
		--get value
		local node = tree:node(path)
		local val = VN.value(node)
		--replace id、btsKey、mergeShapesDataKey
		local newVal, btsKeys, mergeKeys, collisionKeys = replace_id(ids, val, true)
		inc_collision_ref_cnt(self, collisionKeys)
		--add instances
		tree:insert(find_parent(node), nil, nil, newVal, nil)
		--save bts
		copy_trigger_item(newVal, btsKeys, "storage_", "storage_")
		--copy btsFiles、mergeShapesDataKeFiles to engine
		item:repeat_merge_shapes_files(mergeKeys)
	end
	item:set_modified(true)
	item:save()
end

function M:create_folder()
	local cfg = Meta:meta("Instance_Folder"):ctor({
		id = tostring(IWorld:gen_instance_id()),
		name = "Folder"
	})
	local item = self._root
	item:data():insert("instances", nil, nil, cfg, nil)
	item:set_modified(true)
	item:save()
end

-- 零件拖拽到文件夹
function M:tier_changed(type, dstPath, movePaths)
	local item = self._root
	local tree = item:data()

	-- qt enum DropIndicatorPosition
	local ENUM = {}
	ENUM.OnItem = 0
	ENUM.AboveItem = 1
	ENUM.BelowItem = 2
	ENUM.OnViewport = 3

	--1.get vnode
	local dstNode
	if type ~= ENUM.OnViewport then
		dstNode = tree:node(dstPath)
	end
	local nodes = {}
	for _, path in ipairs(movePaths) do
		table.insert(nodes, tree:node(path))
	end
	--2.move vnode
	for _, node in ipairs(nodes) do
		--remove vnode
		local child = VN.remove(VN.parent(node), VN.key(node)) -- vnode delete need use parent
		--insert vnode
		if type == ENUM.OnViewport then -- root
			tree:insert("instances", nil, nil, child, nil)
		elseif type == ENUM.OnItem then -- folder
			local p = VN.path(dstNode) -- remove vnode nedd refresh root path
			tree:insert(p .. "/children", nil, nil, child, nil)
		elseif type == ENUM.AboveItem or type == ENUM.BelowItem then -- 移动到item上方/下方
			local p = VN.path(VN.parent(dstNode))
			local i = (type == ENUM.AboveItem) and VN.key(dstNode) or (VN.key(dstNode) + 1)
			tree:insert(p, i, nil, child, nil)
		end
	end

	item:set_modified(true)
	item:save()
end

function M:delete_item(paths)
	local function delete_storage_item(val)
		if val.btsKey and "" ~= val.btsKey then
			local class = CLASS_MODULE_NAME[val.class]
			if class then
				local m = Module:module("storage_" .. class)
				assert(m)
				if m:list()[val.btsKey] then
					m:del_item(val.btsKey)
				end
			end
		end
		for _,child in ipairs(val.children) do
			delete_storage_item(child)
		end
	end

	if not next(paths) then
		return
	end
	local item = self._root
	local tree = item:data()
	--1.get vnode
	local nodes = {}
	for _, path in ipairs(paths) do
		table.insert(nodes, tree:node(path))
	end
	--2.remove vnode and remove bts
	for _, node in ipairs(nodes) do
		local val = VN.value(node)
		--remove vnode
		VN.remove(VN.parent(node), VN.key(node)) -- vnode delete need use parent
		--delete bts
		delete_storage_item(val)
		--delete files
		item:del_storage_merge_shapes_files(val)
		dec_collision_ref_cnt(self, collect_collision_key(val))
	end

	clear_unref_collision_file(self)

	item:set_modified(true)
	item:save()
end

function M:get_place_scene_list(paths)
	local ret = {}

	local item = self._root
	local ids = {} -- 为了约束使用新id
	for _, path in ipairs(paths) do
		local node = item:data():node(path)
		assert(node)
		local val = VN.value(node)
		val = update_to_instance(val)
		--check place scene type
		local type = assert(val[Def.OBJ_TYPE_MEMBER])
		if STORAGE_TYPE[type] then
			--replace id、btsKey、mergeShapesDataKey
			local newVal, btsKeys, mergeKeys, collisionKeys = replace_id(ids, val)
			--copy bts
			copy_trigger_item(newVal, btsKeys, "", "storage_")
			--copy mergeShapesDataKeFiles
			item:place_scene_copy_files(mergeKeys, collisionKeys)
			table.insert(ret, newVal)
		end
	end
	return ret
end

return M
