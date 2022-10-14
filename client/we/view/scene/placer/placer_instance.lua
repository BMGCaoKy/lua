local Def = require "we.def"

local Meta = require "we.gamedata.meta.meta"

local Input = require "we.view.scene.input"
local Map = require "we.view.scene.map"
local Utils = require "we.view.scene.utils"
local PartOperation = require "we.view.scene.logic.part_operation"
local Receptor = require "we.view.scene.receptor.receptor"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"

local Base = require "we.view.scene.placer.placer_base"
local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._nodes = {}
	self._list = {}
end

function M:on_bind()

end

local function clear_nodes(self)
	for _, node in ipairs(self._nodes) do
		IWorld:remove_instance(node)
	end
	self._nodes = {}
end

function M:on_unbind()
	clear_nodes(self)
end

local function nodes(list)
	local function list_children(node, nodes)
		local count = node:getChildrenCount()
		for i = 1, count do
			local child = node:getChildAt(i-1)
			if child:isA("MovableNode") then
				table.insert(nodes, child)
			else
				IInstance:set_select(child, true)
			end
			list_children(child, nodes)
		end
	end
	
	local nodes = {}
	for _, node in ipairs(list) do
		list_children(node, nodes)
		if node:isA("MovableNode") then
			table.insert(nodes, node)
		end 
	end

	return nodes
end

local check_model_op
check_model_op =  function(obj)
	local cls =  obj["class"]
	if "PartOperation" ==  cls then
		local node = IWorld:get_instance(obj.id)
		node:setPosition(obj.position)
	end
	for _,child in ipairs(obj.children) do
		check_model_op(child)
	end
end

function M:check_select(list)
	if not self._list then
		return false
	end
	self:select(self._list)
	return true
end

function M:select(list)
	clear_nodes(self)

	if not list then
		return
	end

	self._list = list
	for _, val in ipairs(self._list) do
		local node = IWorld:create_instance(Utils.export_inst(val),false)
		check_model_op(val)

		if node.lightActived then
			node.lightActived = false
		end

		table.insert(self._nodes, node)
	end

	local list = nodes(self._nodes)
	for _, node in ipairs(list) do
		IInstance:set_selectable(node, false)
	end
end

function M:on_mouse_press(x, y, button)
	if not next(self._nodes) then
		return
	end

	return true
end

function M:on_mouse_move(x, y)
	if not next(self._nodes) then
		return
	end

	local nodes = nodes(self._nodes)
	IScene:drag_parts(nodes, x, y)

	return true
end

-- adjust position
local function adjust_position(list)
	local ret = {}

	local function reg_proc()
		do
			local meta = Meta:meta("Instance_Spatial")
			meta:set_processor(function(val)
				local ret = Lib.copy(val)
				local node = IWorld:get_instance(val.id)
				if not node then
					--return meta:process_(ret)
					return ret
				end
				local pos = IInstance:position(node)
				-- ret.position = {x = pos.x, y = pos.y, z = pos.z}
				ret._new_position = {x = pos.x, y = pos.y, z = pos.z}
				--return meta:process_(ret)
				return ret
			end)
		end

		do
			local meta = Meta:meta("Instance_CSGShape")
			meta:set_processor(function(val)
				local ret = Lib.copy(val)
				local node = IWorld:get_instance(val.id)
				if not node then
					--return meta:process_(ret)
					return ret
				end
				local pos = IInstance:position(node)
				-- ret.position = {x = pos.x, y = pos.y, z = pos.z}
				ret._new_massCenter = {x = pos.x, y = pos.y, z = pos.z}
				--return meta:process_(ret)
				return ret
			end)
		end
	end

	local function unreg_proc()
		local meta = Meta:meta("Instance_Spatial")
		meta:set_processor(nil)
		meta = Meta:meta("Instance_CSGShape")
		meta:set_processor(nil)
	end

	reg_proc()
	for _, val in ipairs(list) do
		local type = assert(val[Def.OBJ_TYPE_MEMBER])
		local meta = Meta:meta(type)
		val = meta:process(val)
		table.insert(ret, val)
	end
	unreg_proc()

	return ret
end

function M:on_mouse_release(x, y, button, is_click)
	if not next(self._nodes) then
		return
	end

	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end

	--update rotation
	for index, node in ipairs(self._nodes) do
		if node:isA("MovableNode") then
			local rot = IInstance:rotation(node)
			self._list[index].rotation.x = rot.x
			self._list[index].rotation.y = rot.y
			self._list[index].rotation.z = rot.z
		end 
	end

	PartOperation:part_paste(adjust_position(self._list))
	return true
end

return M
