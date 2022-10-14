local Undo = require "we.undo"
local Signal = require "we.signal"
local Module = require "we.gamedata.module.module"
local Def = require "we.def"
local lfs = require "lfs"
local user_data = require "we.user_data"
local engine = require "we.engine"
local Cmdr = require "we.cmd.cmdr"
local Log = require "we.log"

local M = {}

local entity_class = {
	init = function(self, entity)
		self._obj = nil
		self._yaw = 0
		self._pos = {}
		self._cfg = nil

		do
			self._obj = EntityClient.CreateClientEntity({cfgName=entity.cfg,pos=entity.pos,ry=entity.ry})
			self._yaw = entity.ry
			self._pos = entity.pos
			self._cfg = entity.cfg
		end
	end,

	set_obj = function(self,obj)
		self._obj = obj
	end,

	set_pos_ry = function(self,pos,ry)
		self._pos = pos
		self._yaw = ry
		self._obj:setPos(pos,ry)
		self._obj:setBodyYaw(ry)
	end,

	obj = function(self)
		return self._obj
	end,

	yaw = function(self)
		return self._yaw
	end,

	pos = function(self)
		return self._pos
	end,

	cfg = function(self)
		return self._cfg
	end,
}

local region_class = {
	init = function(self, map)

	end
}

local map_class = {
	init = function(self, fileName, id)
		Log("Load map begin", fileName .. "(" .. id .. ")")
		self._fileName = fileName
		self._id = id
		self._entitys = {}

		--pos
		--local map_pos = user_data:get_map_data(fileName)
		local map_pos = user_data:get_value("map_pos")[fileName]
		if map_pos then
			map_pos.y = math.max(map_pos.y,0)
			map_pos.y = math.min(map_pos.y,255)
			self._pos = {
				x = map_pos.x,
				y = map_pos.y,
				z = map_pos.z
			}
		else
			self._pos = {
				x = 0,
				y = 0,
				z = 0
			}
		end
		

		self._undo = Lib.derive(Undo)
		self._undo:init()

		local data = Module:module("map"):item(fileName):obj()
		assert(data, fileName)

		self._entity_array = data["entitys"]
		-- entity
		do
			Signal:subscribe(self._entity_array, Def.NODE_EVENT.ON_INSERT, function(index)
				local entity_obj = Lib.derive(entity_class)
				entity_obj:init(self._entity_array[index])
				self._entitys[self._entity_array[index].id] = entity_obj
			end)

			Signal:subscribe(self._entity_array, Def.NODE_EVENT.ON_REMOVE, function(index, child)
				local _id = child.id
				self._entitys[_id]:obj():destroy()
				self._entitys[_id]:set_obj(nil)
				self._entitys[_id] = nil
			end)

			Signal:subscribe(self._entity_array, Def.NODE_EVENT.ON_MOVE, function(index)
				assert(false)
			end)

			Signal:subscribe(self._entity_array, Def.NODE_EVENT.ON_MODIFY, function(path, event, key)
				if event == Def.NODE_EVENT.ON_ASSIGN then
					-- temp
					local index
					if path[1] then
						index = math.tointeger(path[1])
					else
						index = key
					end

					assert(type(index) == "number")
					local entity_class = self._entitys[self._entity_array[index].id]
					entity_class:set_pos_ry(self._entity_array[index].pos,self._entity_array[index].ry)
					Lib.emitEvent(Event.EVENT_EDITOR_STATE_CHANGE_FOCUS)
				end
			end)
		end

		self._region_array = data["regions"]
		-- region
		do
			Signal:subscribe(self._region_array, Def.NODE_EVENT.ON_MODIFY, function(path, event, key)
				if event == Def.NODE_EVENT.ON_ASSIGN then
					-- temp
					local index
					if path[1] then
						index = math.tointeger(path[1])
					else
						index = key
					end

					assert(type(index) == "number")
					Lib.emitEvent(Event.EVENT_EDITOR_STATE_CHANGE_FOCUS)
				end
			end)
		end

		Log("Load map end", fileName .. "(" .. id .. ")")
	end,

	op_stack = function(self)
		return self._undo
	end,

	entity = function(self, id)
		return self._entitys[id]
	end,

	region = function(id)

	end,

	reload_map = function(self)
		--Module:module("map"):item(self._fileName):save()
		--World.Map.Reload({})

		World.CurWorld:loadCurMap({
			id = self._id,
			name = self._fileName,
			static = true
		},self._pos)
	end,

	active = function(self)
		World.CurWorld:loadCurMap({
			id = self._id,
			name = self._fileName,
			static = true
		},self._pos)

		for i = 1,#self._entity_array do
			local entity_obj = Lib.derive(entity_class)
			entity_obj:init(self._entity_array[i])
			self._entitys[self._entity_array[i].id] = entity_obj
		end

		Blockman.Instance():setViewerPos(self._pos,Blockman.Instance():getViewerYaw(),Blockman.Instance():getViewerPitch(),1)
		engine:sync_camera_pos(self._pos)

		Cmdr:bind(self:op_stack())
	end,

	inactive = function(self)
		if next(self._entitys) ~= nil then
			for _, entity_obj in pairs(self._entitys) do
				if entity_obj:obj() ~= nil then
					entity_obj:obj():destroy()
					entity_obj:set_obj(nil)
					entity_obj = nil
				end
			end
		end
	end,

	get_cfg_byid = function(self,id)
		return self._entitys[id]:cfg()
	end,

	get_pos_byid = function(self,id)
		return self._entitys[id]:pos()
	end,

	get_id_by_entityobj = function(self,entity)
		for k,v in pairs(self._entitys) do
			if v:obj() and entity.objID == v:obj().objID then
				return k
			end
		end
		return nil
	end,

	get_yaw_byid = function(self,id)
		return self._entitys[id]:yaw()
	end,

	set_pos = function(self,pos)
		self._pos = pos
		local map_pos = user_data:get_value("map_pos")
		map_pos[self._fileName] = self._pos
		user_data:set_value("map_pos",map_pos)
	end,

	get_pos = function(self)
		return self._pos
	end,
}

--fileName：地图文件夹名
local function insert(self, fileName)
	if self._id_acc == nil then self._id_acc = 0 end
	self._id_acc = self._id_acc + 1

	local map = Lib.derive(map_class)
	map:init(fileName, self._id_acc)

	self._maps[fileName] = map
end

local function remove(self, item)
	local map = self._maps[item]
	if self._active == item then
		map:inactive()
		self._active = nil
	end
end

local function active(self, fileName)
	if self._active == fileName then
		return
	end

	-- close prev
	local old = self._maps[self._active]
	if old then
		old:inactive()
		self._active = nil
	end

	-- open
	local map = self._maps[fileName]
	assert(map, fileName)
	map:active()
	self._active = fileName
end

function M:reload_map(fileName)
	local map = self._maps[fileName]
	assert(map, fileName)
	map:reload_map()
end

function M:init()
	self._id_acc = 0

	self._maps = {}

	local data = Module:module("game"):item("0"):obj()
	self._active = nil

	self._map_pos = user_data:get_value("map_pos")


	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_NEW, function(module, fileName)
		if module ~= "map" then
			return
		end
		
		insert(self, fileName)
		local map = self._maps[fileName]
		assert(map, fileName)
		map:set_pos({x = 30, y = 68, z = 30})
		user_data:save()
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_DEL, function(module, item)
		if module ~= "map" then
			return
		end

		remove(self, item)
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_CHANGE_MAP, function(fileName)
		active(self, fileName)
	end)
end

function M:load()
	local module = Module:module("map")
	for fileName in pairs(module:list()) do
		insert(self, fileName)
	end
end

function M:curr_map()
	return self._maps[self._active]
end

function M:curr_map_name()
	return self._active
end

function M:update(nextPos)
	--实时同步场景摄像机坐标
	--同步到属性面板，修改内存数据
	local m = self._maps[self._active]
	m:set_pos(nextPos)
	user_data:save()

	engine:sync_camera_pos(nextPos)
end

function M:update_by_name(map_name,nextPos)
	local m = self._maps[map_name]
	m:set_pos(nextPos)
	user_data:save()
end

function M:clear_map_mca(item_id)
	local item = Module:module("map"):item(item_id)
	for mca in lfs.dir(item:dir() .. "/mca") do
		if mca ~= '.' and mca ~= '..' then
			os.remove(item:dir() .. "/mca/" .. mca)
		end
	end
end

return M
