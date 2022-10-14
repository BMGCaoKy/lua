local IWorld = require "we.engine.engine_world"
local Meta = require "we.gamedata.meta.meta"
local Def = require "we.def"
local Module = require "we.gamedata.module.module"
local Constraint = require "we.view.scene.logic.constraint"
local Map = require "we.view.scene.map"
local Receptor = require "we.view.scene.receptor.receptor"
local PartTransform = require "we.view.scene.logic.part_transform"
local GameRequest = require "we.proto.request_game"

local M = {}

function M:init() 
	self._copy_list = {}
end 

local function replace_id(list)
	local ret = {}

	local ids = {}
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
				ret.id = mapping_id(val.id)
				ret.mergeShapesDataKey = val.mergeShapesDataKey--tostring(IWorld:gen_instance_id())
				ret.selected = false
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
	for _, val in ipairs(list) do
		local type = assert(val[Def.OBJ_TYPE_MEMBER])
		local meta = Meta:meta(type)
		val = meta:process(val)
		if type == "Instance_Light" then
			val.ID = Light.getLightID()
		end
		table.insert(ret, val)
	end
	unreg_proc()

	return ret, ids
end

local function copy_bts(val, module_name)
	local m = Module:module(module_name)
	assert(m, module_name)
	local old_key = val.btsKey
	if m:list()[old_key] then
		local new_key = GenUuid()
		m:copy_item(old_key, new_key)
		val.btsKey = new_key
	end
end

local function copy_region_bts(val)
	local module = "region"
	local m = Module:module(module)
	assert(m, module)
	local cfg_name = val.cfgName
	local index = string.find(cfg_name,"/")
	if index then
		local old_key = string.sub(cfg_name, index + 1)
		if m:list()[old_key] then
			local new_key = GenUuid()
			m:copy_item(old_key, new_key)
			val.cfgName = "myplugin/"..new_key
		end
	end
end

--[[
local check_model_child
check_model_child = function(model_val,model_obj)
	for index,val in ipairs(model_val.children) do
		if "Instance_Model" ==  val[Def.OBJ_TYPE_MEMBER] then
			check_model_child(val,model_obj:children()[index])
		end
		if  val._new_position then
			model_obj:children()[index]:vnode()["position"] = val._new_position
			val._new_position = nil
		end
		if val._new_massCenter then
			model_obj:children()[index]:vnode()["massCenter"] = val._new_massCenter
			val._new_massCenter = nil
		end
	end
end
]]--

function M:copy_list()
	return self._copy_list
end

function M:part_copy(list)
	self._copy_list = replace_id(list)
	local arr = {}
	for _, val in ipairs(self._copy_list) do 
		local cls = val["class"]
		if cls == "Light" then 
			cls = val["lightType"]
		end 
		table.insert(arr, cls)
	end 
	GameRequest.request_set_copy_list(arr)
	return self._copy_list
end

local get_op_pos
get_op_pos = function(obj, tb)
	local cls = obj["class"]
	if "PartOperation" ==  cls then
		tb[obj.id] = obj.position
	end
	for _,child in ipairs(obj.children) do
		get_op_pos(child, tb)
	end
end

local function part_paste_new(list, parents, current)
	local objs = {}
	local nodes = {}
	for _,val in ipairs(list) do
		local type = assert(val[Def.OBJ_TYPE_MEMBER])
		if type == "Instance_Part" then
			copy_bts(val, "part")
		elseif type == "Instance_MeshPart" then
			copy_bts(val, "meshpart")
		elseif type == "Instance_PartOperation" then
			copy_bts(val, "part_operation")
		elseif type == "Instance_RegionPart" then
			copy_region_bts(val)
		end
		-- clear temp value
		local _new_position = val._new_position
		val._new_position = nil
		local _new_massCenter = val._new_massCenter
		val._new_massCenter = nil

		local id_relocal_pos = {}
		get_op_pos(val, id_relocal_pos)

		local obj = nil
		if current then
			-- 指定对象下创建instance 
			obj = current:new_child(val)
		elseif parents and parents[val.id] then
			-- 在父类下创建instance
			obj = parents[val.id]:new_child(val)
		else
			obj = Map:new_instance(val)
		end

		for id, pos in pairs(id_relocal_pos) do
			local node = IWorld:get_instance(id)
			node:setPosition(pos)
		end

		if type == "Instance_PartOperation" then
			PartTransform:new_operation(
				obj:id(),
				obj:val()["position"],
				obj:val()["size"]
			)
			for _, child in ipairs(obj:children()) do
				local vnode = child:vnode()
				local node = child:node()
				if vnode[Def.OBJ_TYPE_MEMBER] == "Instance_EffectPart" then 
					node:setLocalPosition({x = 0, y = 0, z = 0})
					vnode["position"] = node:getPosition()
					vnode["size"] = node:getSize()
				end 
			end 
		end

		--if "Instance_Model" == type then
		--	check_model_child(val,obj)
		--end
		-- Ctrl+V need update child pos
		if _new_position then
			obj:vnode()["position"] = _new_position
		end
		if _new_massCenter then
			obj:vnode()["massCenter"] = _new_massCenter
		end

		table.insert(objs,obj)
		table.insert(nodes, obj:node())
	end

	for _,obj in ipairs(objs) do
		Constraint:check_constraint(obj, true)
	end
	Receptor:select("instance", nodes)
end

function M:part_paste(list, current)
	part_paste_new(replace_id(list), nil, current)
end 

function M:part_repetition(list, parents)
	local copy_list, ids = replace_id(list)
	--更新id和parents对应关系
	local copy_parents = {}
	for id,parent in pairs(parents) do
		if ids[id] then
			copy_parents[ids[id]] = parent
		end
	end
	part_paste_new(copy_list, copy_parents)
end

return M
