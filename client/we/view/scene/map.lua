local Def = require "we.def"
local Signal = require "we.signal"
local Meta = require "we.gamedata.meta.meta"
local VN = require "we.gamedata.vnode"
local Module = require "we.gamedata.module.module"
local Utils = require "we.view.scene.utils"
local Object = require "we.view.scene.object.object"
local Camera = require "we.view.scene.camera"

local IWorld = require "we.engine.engine_world"
local IInstance = require "we.engine.engine_instance"
local Receptor = require "we.view.scene.receptor.receptor"

local Constraint = require "we.view.scene.logic.constraint"
local Recorder = require "we.gamedata.recorder"
local GameConfig = require "we.gameconfig"
local PartTransform = require "we.view.scene.logic.part_transform"
local GameRequest = require "we.proto.request_game"
local IScene = require "we.engine.engine_scene"

local RAY_LENGTH=28
local FROM_VIEW=15

local M = {}

local class2module = {
	["Entity"] = "entity",
	["DropItem"] = "item"
}

local instances_class = {
	init = function(self, vnode)
		self._vnode = vnode
		self._list = {}
		self._set = {}

		Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_INSERT, function(index)
			local obj = Object:create("instance", self._vnode[index])
			table.insert(self._list, index, obj)
			self._set[obj:id()] = obj
		end)

		Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_REMOVE, function(index)
			local obj = table.remove(self._list, index)
			assert(obj, index)
			self._set[obj:id()] = nil
			obj:dtor()
		end)

		Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_MOVE, function(from, to)
			assert(false)
		end)
	end,

	load = function(self)
		for _, vnode in ipairs(self._vnode) do
			local obj = Object:create("instance", vnode)
			table.insert(self._list, obj)
			self._set[obj:id()] = obj
		end
	end,

	unload = function(self)
		for _, obj in ipairs(self._list) do
			obj:dtor()
		end

		self._list = {}
		self._set = {}
	end,

	query = function(self, id)
		if not math.tointeger(id) then
			local obj = self._set[tostring(IInstance:id(id))]
			if obj then
				return obj
			end
		end

		for _, obj in ipairs(self._list) do
			if obj:check(id) then
				return obj
			else
				local child = obj:query_child(id)
				if child then
					return child
				end
			end
		end
	end,

	new = function(self, val)
		VN.insert(self._vnode, nil, val)
	end,

	remove = function(self, obj)
		local index
		for idx, o in ipairs(self._list) do
			if o == obj then
				index = idx
				break
			end
		end
		assert(index)

		local val = VN.remove(self._vnode, index)
		return val
	end,

	list = function(self, filter)
		local function list_children(obj, objs)
			for _, child in ipairs(obj:children()) do
				if not filter or filter(child) then
					table.insert(objs, child)
				end
				list_children(child, objs)
			end
		end

		local objs = {}
		for _, obj in ipairs(self._list) do
			if not filter or filter(obj) then
				table.insert(objs,obj)
			end
			list_children(obj,objs)
		end

		return objs
	end,

	cond_remove = function(self, cond)
		local i = 1
		repeat
			local vnode = self._vnode[i]
			if not vnode then
				break
			end

			if cond(vnode) then
				VN.remove(self._vnode, i, ~VN.CTRL_BIT.RECORDE)
			else
				i = i + 1
			end
		until(false)
	end,

	use_cfg = function(self)
		local set = {}
		for _, vnode in ipairs(self._vnode) do
			if VN.check_type(vnode, "Instance_Object") then
				local module = assert(class2module[vnode["class"]])
				local item = vnode["config"]
				local cfg = string.lower(string.format("%s:%s", module, item))
				set[cfg] = true
			end
		end
		return set
	end
}

local map_class = {
	init = function(self, name, id, parent)
		self._name = name
		self._id = id
		self._parent = parent

		self._item = Module:module("map"):item(name)
		self._vnode = self._item:obj()

		if nil ~= name and "" ~= name then
			VN.assign(self._vnode,"mapId", name, VN.CTRL_BIT.NONE)
			VN.set_attr(self._vnode, "mapId", "Visible", "true", VN.CTRL_BIT.NONE)
		end

		self._instances = Lib.derive(instances_class)
		self._instances:init(self._vnode["instances"])

		self._constraints = {}
		self._used_cfg = self._instances:use_cfg()

		Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_DEL, function(module, item)
			self:on_del_cfg(module, item)
		end)
	end,

	open = function(self)
		local pos
		if GameConfig:disable_block() then
			pos= {x = 0, y = 30, z = 20}
		else
			pos= {x = 21, y = 58, z = 20}
		end
		IWorld:enter_map(self._name, self._id, pos)
		Camera:set_pos(pos)
		Camera:set_active_camera_pos(pos)

		self._instances:load()
		local constraints = self._instances:list(
			function(obj)
				return obj:check_base("Instance_ConstraintBase")
			end
		)
		Constraint:relevance_constraints(self, constraints)

		local operations = self._instances:list(
			function(obj)
				return obj:class() == "PartOperation"
			end
		)
		PartTransform:relevance_operations(self._parent, operations)

		if GameConfig:disable_block() then
			local terrains = self._instances:list(
					function(obj)
						return obj:class() == ("VoxelTerrain")
					end
			)
			if next(terrains) == nil then
				TerrainLuaHelper:Instance():GetController():CreateTerrain({ x = 0, y = 0, z = 0 }, { x = 128, y = 30, z = 128 })
				TerrainLuaHelper:Instance():GetController():CreateTerrainEnd()
				TerrainLuaHelper:Instance():GetController():SaveTerrain()
				local enable = Recorder:enable()
				Recorder:set_enable(false)
				local meta = Meta:meta("Instance_VoxelTerrain"):ctor({ })
				if not meta.id or meta.id == "" then
					meta.id = tostring(IWorld:gen_instance_id())
				end
				self:new_instance(meta)
				local terrain = self:query_instance(meta.id)
				table.insert(terrains, terrain)
				Recorder:set_enable(enable)
			end

			local terrain = terrains[1]
			local index = VN.key(terrain:vnode())
			self:create_light("GlobalLight",index)
			self:create_light("DirectionalLight",index)
		end
	end,

	close = function(self)
		IWorld:leave_map(self._id)
		self._instances:unload()
		Constraint:disrelevance_constraints()
	end,

	unbind = function(self)
		self._instances:unload()
		Constraint:disrelevance_constraints()
		IWorld:close_map(self._name)
	end,

	new_instance = function(self, val)
		return self._instances:new(val)
	end,

	remove_instance = function(self, obj)
		return self._instances:remove(obj)
	end,

	query_instance = function(self, id)
		return self._instances:query(id)
	end,

	stack = function(self)
		return VN.undo_stack(self._vnode)
	end,

	name = function(self)
		return self._name
	end,
	
	get_instances = function(self)
		return self._instances
	end,

	set_modified = function(self)
		if not self._item:modified() then
			self._item:set_modified(true)
			Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
		end
	end,

	on_use_cfg = function(self, module, item)
		local cfg = string.lower(string.format("%s:%s", module, item))
		if cfg then
			self._used_cfg[cfg] = true
		end
	end,

	on_del_cfg = function(self, module, item)
		item = "myplugin/"..item
		local cfg = string.lower(string.format("%s:%s", module, item))
		if not self._used_cfg[cfg] then
			return
		end
		
		self._instances:cond_remove(function(vnode)
			if not VN.check_type(vnode, "Instance_Object") then
				return false
			end
			return class2module[vnode["class"]] == module and vnode["config"] == item
		end)

		local stack = self:stack()
		stack:clear()
		self._used_cfg[cfg] = nil
	end,

	check_use_cfg = function(self, module, item)
		item = "myplugin/"..item
		local cfg = string.lower(string.format("%s:%s", module, item))
		return self._used_cfg[cfg]
	end,

	get_node = function(self)
		return self._vnode
	end,

	create_light = function(self,type,index)
		local lightList = self._instances:list(
				function(obj)
					if obj:class() == "Light" then
						return obj:node().lightType == type
					end
				end
		)

		if next(lightList) == nil then
			local enable = Recorder:enable()
			Recorder:set_enable(false)
			local cfg = Meta:meta("Instance_Light"):ctor(
			{
				ID = Light.getLightID(),
				lightType = type,
				name = type
			})
			if not cfg.id or cfg.id == "" then
				cfg.id = tostring(IWorld:gen_instance_id())
			end

			if type == "GlobalLight" then
				cfg.name = "EnvironmentLight"
				VN.insert(self._instances._vnode, index + 1, cfg)
			else
				cfg.rotation = {x = 0, y = -90, z = 0}
				cfg.position = {x = 0, y = 5, z = 0}
				VN.insert(self._instances._vnode, index + 2, cfg)
			end
			Recorder:set_enable(enable)
		end
	end,
}

local function insert_map(self, name)
	assert(not self._list[name])

	self._next_id = self._next_id + 1

	local map = Lib.derive(map_class)
	map:init(name, self._next_id, self)

	self._list[name] = map
end

local function dele_map_terrain(map)
	local terrains = map._instances:list(
			function(obj)
				return obj:class() == ("VoxelTerrain")
			end
	)
	if next(terrains) ~= nil then
		local enable = Recorder:enable()
		Recorder:set_enable(false)
		terrains[1]:node():clearStorage()
		Recorder:set_enable(enable)
	end
end

local function remove_map(self, name)
	local map = assert(self._list[name], name)
	dele_map_terrain(map)
	map:close()
	self._list[name] = nil
end

local function check_folders(self)
	if self._curr then
		local instances = self._curr:get_instances()
		local objs = instances:list(
			function(obj)
				return obj:class() == ("Folder")
			end
		)
		self._folders = #objs
	end
end

function M:init()
	self._next_id = 0
	self._list = {}
	self._curr = nil
	self._currEditFolder = nil

	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_NEW, function(module, item)
		if module ~= "map" then
			return
		end

		insert_map(self,item)
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_DEL, function(module, item)
		if module ~= "map" then
			return
		end

		remove_map(self,item)
	end)

	self:load()
end

function M:load()
	local module = Module:module("map")
	for name in pairs(module:list()) do
		insert_map(self, name)
	end
end

function M:change_map(name)
	if self._curr and self._curr:name() == name then
		return
	end

	--切换地图前，更新当前地图vnode的静态合批批次号
	self:update_staticBatchNo()

	if self._curr then
		self._curr:close()
		self._curr = nil
	end

	if name and name ~= "" then
		self._curr = assert(self._list[name], name)
		self._curr:open()
		check_folders(self)
		local Cmdr = require "we.cmd.cmdr"
		Cmdr:bind(self._curr:stack())
	end
end

function M:change_edit_folder(id)
	self._currEditFolder = self:query_instance(id)
end

function M:clear_edit_folder()
	self._currEditFolder = nil
end

function M:new_instance(val)
	assert(self._curr)
	if not val.id or val.id == "" then
		val.id = tostring(IWorld:gen_instance_id())
	end

	-- new folder child or new map child
	if self._currEditFolder then
		self._currEditFolder:new_child(val)
	else
		self._curr:new_instance(val)
	end

	local obj = assert(self:query_instance(val.id), tostring(val.id))
	self._curr:on_use_cfg(obj:module(), obj:config())
	return obj
end

function M:remove_instance(obj)
	assert(self._curr)
	return self._curr:remove_instance(obj)
end

function M:query_instance(id)
	assert(self._curr)
	return self._curr:query_instance(id)
end

function M:curr()
	return self._curr
end

function M:maps()
	return self._list
end

function M:save()
	if GameConfig:disable_block() then
		for _, map in pairs(self._list) do
			local instances = map:get_instances()
			local terrains = instances:list(
				function(obj)
					return obj:class() == ("VoxelTerrain")
				end
			)
			for _, terrain in pairs(terrains) do
				terrain:node():saveTerrain()
			end
		end
	end
	--self:CreateEngineImageset()	// OB不自动打图集
end

--TODO：后期可以继续优化，现在每次保存都重新获取引擎的值设置，还是会耗时
--更新当前地图vnode的静态合批批次号
function M:update_staticBatchNo()
	if not GameConfig:disable_block() then
		return
	end
	if not self._curr or not self._curr._item:modified() then --地图没有修改时不更新
		return
	end
	--获取地形node
	local instances = self._curr:get_instances()
	local terrains = instances:list(
		function(obj)
			return obj:class() == ("VoxelTerrain")
		end
	)
	if not terrains[1] then
		return
	end
	--调用引擎接口获取静态合批staticBatchNo数据（TODO：引擎接口写在terrain中）
	local list = terrains[1]:node():engineSaveCallback()
	if not list or not next(list) then
		return
	end
	--转换成键值对（TODO：引擎返回数据）
	local batchNo = {}
	for _, val in ipairs(list) do
		assert(val.key == "staticBatchNo")
		batchNo[tostring(val.instanceID)] = val.value
	end
	--更新vnode
	local root = self._curr:get_node()
	VN.iter(root, "Instance_BasePart", function(vnode)
		local id = vnode["id"]
		if batchNo[id] then
			VN.assign(vnode, "staticBatchNo", batchNo[id], VN.CTRL_BIT.NONE)
		end
	end)
end

function M:CreateEngineImageset()
	local instances = GenAtlas.generateAtlas()
	local results = {}

	--[[if type(instances)~="table" then
		return
	end]]

	for _,instance in ipairs(instances) do
		local paths = instance.pathList
		local max_width = instance.maxHeight
		local max_height = instance.maxWidth
		local atlas_name = instance.atlasName
		local fill_length = instance.fillPixel
		local out_path = instance.dirPath

		if type(paths)~= "table" or #paths == 0 or atlas_name == "" or max_width <= 0 or max_height <= 0 then
		else
			local ret = GameRequest.request_packaging_image(paths, max_width, max_height, out_path, atlas_name, fill_length)
			table.insert(results, ret)
		end
		
	end
	--Lib.pv(results)
end

function M:check_use_cfg(module, item)
	for _, map in pairs(self._list) do
		if map:check_use_cfg(module, item) then
			return true
		end
	end
	return false
end

function M:set_modify()
	if self._curr then
		self._curr:set_modified()
	end
end

function M:check_constraint(val_table, parent)
	local children = {}
	for _,val in ipairs(val_table) do
		local child = parent:new_child(val)
		table.insert(children, child)
	end

	for _,part in ipairs(children) do
		Constraint:check_constraint(part)
	end
end

function M:create_folder(bIsDataSet)
	check_folders(self)
	local cfg = Meta:meta("Instance_Folder"):ctor(
	{
		name = "Folder"..self._folders,
		isDataSet = bIsDataSet
	})
	self:new_instance(cfg)
	self._folders = self._folders + 1
end

function M:get_view_to_target(distance,rayLength)
	local direction=Camera:get_active_camera_direction()
	local viewPos=Camera:get_view_pos()
	local position={x=viewPos.x+direction.x*distance,y=viewPos.y+direction.y*distance,z=viewPos.z+direction.z*distance}
	local screenSize=CGame.instance:getWndSize()
	local screenPos=Blockman.Instance():getScreenPos(position)
	local screenx=screenSize.x*screenPos.x
	local screeny=screenSize.y*screenPos.y
	local hitResult=Blockman.Instance():rayTest({x=screenx , y=screeny}, rayLength)
	if hitResult.isHit then
		local distance2=-0.5
		position={
			x=hitResult.hitPos.x+direction.x*distance2,
			y=hitResult.hitPos.y+direction.y*distance2,
			z=hitResult.hitPos.z+direction.z*distance2
		}
	end
	return position
end

function M:create_sceneui()
	local position=self:get_view_to_target(FROM_VIEW,RAY_LENGTH)
	local cfg = Meta:meta("Instance_SceneUI"):ctor(
	{
		name = "SceneUI",
		position=position
	})
	self:new_instance(cfg)
end

function M:add_folder(id, bIsDataSet)
	check_folders(self)
	local cfg = Meta:meta("Instance_Folder"):ctor(
	{
		name = "Folder"..self._folders,
		id	 = tostring(IWorld:gen_instance_id()),
		isDataSet = bIsDataSet
	})
	self._folders = self._folders + 1
	
	local parent = self:query_instance(id)
	local val_table = {}
	table.insert(val_table,cfg)
	self:check_constraint(val_table, parent)
end

-- update obj position by parent
local function update_obj_position(obj)
	if "AudioNode" == obj:class() then
		local node = obj:node()
		local vnode = obj:vnode()
		local parent = obj:parent()
		if not parent or "Folder" == parent:class() then
			-- 世界坐标
			vnode["is_relative"] = false
			-- 1.更新坐标值
			VN.assign(
				vnode,
				"position", 
				Utils.deseri_prop("Vector3", IInstance:get(node, "position")),
				VN.CTRL_BIT.NONE
			)
			-- 2.更新相对坐标
			VN.assign(
				vnode,
				"relative_pos", 
				Utils.deseri_prop("Vector3", IInstance:get(node, "localPosition")),
				VN.CTRL_BIT.NONE
			)
		else
			-- 相对坐标
			vnode["is_relative"] = true
			-- 1.设置父类坐标
			local parent_pos = IInstance:position(parent:node())
			node:setPosition(parent_pos)
			-- 2.设置在父类坐标上的偏移坐标
			local pos = vnode["relative_pos"]
			node:setLocalPosition({x = pos.x, y = pos.y, z = pos.z})
			-- 3.刷新坐标值
			vnode["position"] = Utils.deseri_prop("Vector3", IInstance:get(node, "position"))
		end
	end
end

function M:tier_changed(...)
	local items = {...}
	local id_datum = items[1]
	local pos_drop = items[2]
	local tb_obj = {}

	local ENUM = {}
	ENUM.OnItem = 0
	ENUM.AboveItem = 1
	ENUM.BelowItem = 2
	ENUM.OnViewport = 3

	for index, id in ipairs(items) do
		if index > 2 then
			local obj_moved = self:query_instance(id)  --获取需要移动的对象
			obj_moved:set_select(false)
			table.insert(tb_obj, id)
			local parent_moved = obj_moved:parent() --获取移动对象的当前父节点,一级节点的parent为nil
			local instances = self._curr:get_instances() --获取当前地图的实例表

			local tb_moved = {}
			if not parent_moved then
				tb_moved = self:remove_instance(obj_moved) --如果移除对象没有父节点说明它是一级节点，从地图移除，否则从父节点移除
			else
				tb_moved = parent_moved:remove_child(obj_moved)	
			end

			if obj_moved:class() == "Light" then
				tb_moved.ID = Light.getLightID()
			end

			local obj_datum  --基准节点
			if id_datum == "Root" then
				if pos_drop == ENUM.OnItem then
					self:new_instance(tb_moved)
				elseif pos_drop == ENUM.BelowItem then
					VN.insert(instances._vnode,1,tb_moved)
				end
				goto continue
			else
				obj_datum = self:query_instance(id_datum)
			end
			local parent_datum = obj_datum:parent() --获取基准节点的父节点

			if pos_drop == ENUM.OnItem then
				obj_datum:new_child(tb_moved)	--放置在item上直接创建子节点
			elseif pos_drop == ENUM.AboveItem then
				local index_datum = VN.key(obj_datum:vnode())
				if not parent_datum then
					VN.insert(instances._vnode,index_datum,tb_moved)	--没有父节点的话直接在地图上插入
				else
					VN.insert(parent_datum:vnode()["children"],index_datum,tb_moved)	--有父节点的话在父节点的children表插入
				end
			elseif pos_drop == ENUM.BelowItem then
				local index_datum = VN.key(obj_datum:vnode())
				if not parent_datum then
					VN.insert(instances._vnode,index_datum + 1, tb_moved)
				else
					VN.insert(parent_datum:vnode()["children"],index_datum + 1,tb_moved)
				end
			else
				self:new_instance(tb_moved)
			end

			-- 针对Effect改变层级后，需要同步信息
			if tb_moved["class"] == "EffectPart" then 
				local obj = self:query_instance(id)
				obj:node():setLocalPosition({x = 0, y = 0, z = 0})
				obj:vnode()["position"] = obj:node():getPosition()
				obj:vnode()["size"] = obj:node():getSize()
			end 

			::continue::
		end
	end

	for _,id in ipairs(tb_obj) do
		local obj = self:query_instance(id)
		Constraint:check_constraint(obj)
		update_obj_position(obj)
	end
end

function M:add_obj_child(table)
	local cfg = Meta:meta(table[2]):ctor(
	{
	    id = tostring(IWorld:gen_instance_id())
	})
	local obj = self:query_instance(table[1])
	local vnode = obj:vnode()
	if vnode.position then
		if not cfg.is_relative then
			if cfg.position then
				cfg.position.x = vnode.position.x
				cfg.position.y = vnode.position.y
				cfg.position.z = vnode.position.z
			elseif cfg.xform then
				cfg.xform.pos.x = vnode.position.x
				cfg.xform.pos.y = vnode.position.y
				cfg.xform.pos.z = vnode.position.z
			end
		end
	end
	obj:new_child(cfg)
end

function M:create_audio_node(table)
	local position=self:get_view_to_target(FROM_VIEW,RAY_LENGTH)
	local parentId = table[1]
	local cfg = Meta:meta("Instance_AudioNode"):ctor(
	{
		position=position,
		name = "Sound",
		is_relative = ("Root" ~= parentId)
	})
	local item
	local item_pos
	if "Root" == parentId then
		item = self:new_instance(cfg)
		item_pos = position
	else
		local parent = self:query_instance(parentId)
		if "Folder" == parent:class() then
			cfg.is_relative = false
			item_pos = {x = 0, y = 1.5, z = 0}
		else
			item_pos = IInstance:position(parent:node())
		end
		item = parent:new_child(cfg)
	end

	item:node():setLocalPosition({x = 0, y = 0, z = 0})
	item:node():setPosition(item_pos)

	VN.assign(
		item:vnode(),
		"position", 
		Utils.deseri_prop("Vector3", IInstance:get(item:node(), "position")),
		VN.CTRL_BIT.NONE
	)
end

function M:create_empty_node(table)	
	local parentId = table[1]
	local cfg = Meta:meta("Instance_EmptyNode"):ctor(
	{
		name = "EmptyNode"
	})
	local item
	local item_pos
	if "Root" == parentId then
		item = self:new_instance(cfg)
		local position=self:get_view_to_target(FROM_VIEW,RAY_LENGTH)
		item_pos = position
	else
		local parent = self:query_instance(parentId)
		if "Folder" == parent:class() then
			item_pos = self:get_view_to_target(FROM_VIEW,RAY_LENGTH)
		else
			item_pos = IInstance:position(parent:node())
		end
		item = parent:new_child(cfg)
	end

	item:node():setLocalPosition({x = 0, y = 0, z = 0})
	item:node():setPosition(item_pos)

	VN.assign(
		item:vnode(),
		"position", 
		Utils.deseri_prop("Vector3", IInstance:get(item:node(), "position")),
		VN.CTRL_BIT.NONE
	)
end

function M:create_fog_node(table)
	local parentId = table[1]
	local cfg = Meta:meta("Instance_Fog"):ctor(
	{
		name = "Fog"
	})
	local item
	local item_pos
	if "Root" == parentId then
		item = self:new_instance(cfg)
	else
		local parent = self:query_instance(parentId)
		item = parent:new_child(cfg)
		item_pos = IInstance:position(parent:node())
	end
end

function M:create_post_process(table)
	local parentId = table[1]
	local cfg = Meta:meta("Instance_PostProcess"):ctor(
	{
		name = "PostProcess"
	})
	local item
	local item_pos
	if "Root" == parentId then
		item = self:new_instance(cfg)
	else
		local parent = self:query_instance(parentId)
		item = parent:new_child(cfg)
		item_pos = IInstance:position(parent:node())
	end
end 

function M:add_light_child(table)
	local parentId = table[1]

	local cfg = Meta:meta(table[2]):ctor(
	{
		ID = Light.getLightID(),
		id = tostring(IWorld:gen_instance_id()),
		lightType = table[3],
		name = table[3],
		rotation = {x = 0, y = -90, z = 0}
	})
	
	local obj = nil
	if parentId == "" then
		if cfg.lightType == "DirectionalLight" then
			cfg.lightColor = {__OBJ_TYPE = "Color", r = 255, g = 244, b = 214, a = 255}		
		end
		local position=self:get_view_to_target(FROM_VIEW,RAY_LENGTH)
		cfg.position=position
		obj = self:new_instance(cfg)
	else
		local parent = self:query_instance(parentId)
		cfg.position = IInstance:position(parent:node())
		obj = parent:new_child(cfg)
	end
	
	Receptor:select("instance", {obj:node()})
end
function M:create_effect_part(table)
	local cfg = Meta:meta("Instance_EffectPart"):ctor(
	{
	    id = tostring(IWorld:gen_instance_id())
	})
	if "Root" == table[1] then
		local item = self:new_instance(cfg)
		local position=self:get_view_to_target(FROM_VIEW,RAY_LENGTH)
		local item_pos = position
		item:node():setLocalPosition(item_pos)
	else
		local parent = self:query_instance(table[1])
		local item = parent:new_child(cfg)
		-- update effect part transform
		item:node():setLocalPosition({x = 0, y = 0, z = 0})
		VN.assign(
			item:vnode(),
			"position", 
			Utils.deseri_prop("Vector3", IInstance:get(item:node(), "position")),
			VN.CTRL_BIT.NONE
		)
	end
end

function M:add_collision_child(parentId,id)
	if not id then
		id=tostring(IWorld:gen_instance_id())
	end
	local cfg=Meta:meta("Instance_Collision"):ctor(
		{
			id=id,
			useForCollision=true
		}
	)
	local obj
	if parentId ~=""then
		local parent=self:query_instance(parentId)
		local collision=self:query_instance(id)
		if collision then
			parent:remove_child(collision)
		end
		obj=parent:new_child(cfg)
	end
	return obj
end


--[[function M:create_effect_part(table)
	local cfg = Meta:meta("Instance_EffectPart"):ctor(
	{
	    id = tostring(IWorld:gen_instance_id())
	})
	local parent = self:query_instance(table[1])
	local item = parent:new_child(cfg)
	-- update effect part transform
	item:node():setLocalPosition({x = 0, y = 0, z = 0})
	VN.assign(
		item:vnode(),
		"position", 
		Utils.deseri_prop("Vector3", IInstance:get(item:node(), "position")),
		VN.CTRL_BIT.NONE
	)
end
--]]

function M:drop_obj_effect(table)
	local obj = self:query_instance(table[1])
	local childId = tostring(IWorld:gen_instance_id())

	local cfg = Meta:meta("Instance_EffectPart"):ctor(
	{
		id = childId,	
		csgShapeEffect = { selector = table[2], asset = table[3] }
	})
	obj:new_child(cfg)

	local childObj = self:query_instance(childId)
	childObj:node():setScale({x = 1, y = 1, z = 1})

	local position = obj:node():getPosition()
	childObj:vnode()["position"] = position

	local size = childObj:node():getSize()
	childObj:vnode()["size"] = size

	Receptor:select("instance", {childObj:node()})
end

return M
