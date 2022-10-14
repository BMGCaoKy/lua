local Def = require "we.def"
local Map = require "we.view.scene.map"
local Receptor = require "we.view.scene.receptor.receptor"
local State = require "we.view.scene.state"
local IScene = require "we.engine.engine_scene"
local Utils = require "we.view.scene.utils"
local Signal = require "we.signal"
local debugDraw = DebugDraw.instance

local M = {}

local align_style = "align_style"
local align_coord = "align_coord"
local align_axis = "align_axis"
local align_target = "align_target"
local align_target_id = "align_target_id"
local show_effect = "show_effect"
local is_open_align = "is_open_align"
local activate_align = "activate_align"
local current_align_obj_count = "current_align_obj_count"

local ALIGN_STYLE = {
	None = 0,
	Left = 1,
	Center = 2,
	Right = 3,
}

local ALIGN_COORD = {
	None = 0,
	World = 1,
	Local = 2,
}

local ALIGN_COORDAXIS = {
	None = 0,
	X = 1,
	Y = 2,
	Z = 3,
}

local ALIGN_TARGET = {
	None = 0,
	Range = 1,
	Object = 2,
}

local ALIGN_IS_OPEN = {
	CLOSE = 0,
	OPEN = 1,
}

local ALIGN_IS_SHOW_EFFECT = {
	CLOSE = 0,
	OPEN = 1,
}

function M:init()
	local function show_align_target(index)
		local instance_align_setting = State:instance_align_setting()
		local target = instance_align_setting[align_target]

		if index == align_target then
			if target == ALIGN_TARGET.Object then
				self:show_object_to_align_target(self:get_align_target())
			else
				self:hide_object_to_align_target()
			end
		end
		if index == align_target_id then
			if target == ALIGN_TARGET.Object and instance_align_setting[is_open_align] == ALIGN_IS_OPEN.OPEN then
				self:show_object_to_align_target(self:get_align_target())
			end
		end
		if index == is_open_align then
			if instance_align_setting[is_open_align] == ALIGN_IS_OPEN.CLOSE then
				self:hide_object_to_align_target()
			else
				if target == ALIGN_TARGET.Object then
					self:show_object_to_align_target(self:get_align_target())
				end
			end
		end
	end

	local function do_show_effect(receptor, align_node)
		local nodes = receptor:nodes(
				function(obj)
					return obj:check_ability(obj.ABILITY.AABB)
				end
		)
		local instances = receptor:list(
				function(obj)
					return obj:check_ability(obj.ABILITY.AABB)
				end
		)
		if instances and #instances <= 1 then
			align_node:setShow(false)
			return
		end
		local instance_align_setting = State:instance_align_setting()
		local align_target_node = self:get_align_target(instances):node()
		local style = instance_align_setting[align_style]
		local coord = instance_align_setting[align_coord]
		local axis = instance_align_setting[align_axis]
		local target = instance_align_setting[align_target]

		align_node:setSelect(nodes)
		align_node:setAlignStyle(style)
		align_node:setAlignCoord(coord)
		align_node:setAlignAxis(Lib.v3(axis.x, axis.y, axis.z))
		align_node:setAlignObject(target)
		align_node:setAlignActive(align_target_node)
		align_node:setShow(true)
		
	end

	local node = State:instance_align_setting()
	local manager = World.CurWorld:getSceneManager()
	manager:setAlignGizmo(GizmoTransformAlign:create())

	Signal:subscribe(node, Def.NODE_EVENT.ON_ASSIGN, function(index)
		local Receptor = require "we.view.scene.receptor.receptor"
		local receptor = Receptor:binding()
		if not receptor then
			return
		end
		local manager = World.CurWorld:getSceneManager()
		local align_node = manager:getAlignGizmo()
		if not align_node then
			return
		end
		local nodes = receptor:nodes(
				function(obj)
					return obj:vnode()["class"] == "Part"
				end
		)
		if Lib.getTableSize(nodes) > 1 then
			local instance_align_setting = State:instance_align_setting()
			if index == align_style or index == align_coord or index == align_axis or index == align_target or index == align_target_id or index == current_align_obj_count then
				if instance_align_setting[current_align_obj_count] > 1 then
					instance_align_setting[activate_align] = true
				end
			end
		end
		if index == show_effect then
			local value = node[index]
			if value == ALIGN_IS_SHOW_EFFECT.OPEN then
				--进入
				do_show_effect(receptor, align_node)
			else
				--离开
				align_node:setShow(false)
			end
		else
			if node[show_effect] == ALIGN_IS_SHOW_EFFECT.OPEN then
				--数值改变
				do_show_effect(receptor, align_node)
			end
		end
		show_align_target(index)
	end)
	local align_axis_node = node[align_axis]
	Signal:subscribe(align_axis_node, Def.NODE_EVENT.ON_ASSIGN, function(index)
		local Receptor = require "we.view.scene.receptor.receptor"
		local receptor = Receptor:binding()
		if not receptor then
			return
		end
		local align_node = manager:getAlignGizmo()
		if not align_node then
			return
		end
		if node[show_effect] == ALIGN_IS_SHOW_EFFECT.OPEN then
			--数值改变
			do_show_effect(receptor, align_node)
			local instance_align_setting = State:instance_align_setting()
			if instance_align_setting[current_align_obj_count] > 1 then
				instance_align_setting[activate_align] = true
			end
		end
	end)
end

function M:align(receptor)
	local style = State:instance_align_setting()[align_style]
	local coord = State:instance_align_setting()[align_coord]
	local axis = State:instance_align_setting()[align_axis]
	local target = State:instance_align_setting()[align_target]
	print("align_style:" .. style)
	print("align_coord:" .. coord)
	print("align_axis:" .. Utils.seri_prop("Vector3", axis))
	print("align_target:" .. target)
	
	local nodes = receptor:nodes(
			function(obj)
				return obj:check_ability(obj.ABILITY.AABB)
			end
	)
	local instances = receptor:list(
			function(obj)
				return obj:check_ability(obj.ABILITY.AABB)
			end
	)
	local function get_range_bound(temp_nodes, act_part)
		if coord == ALIGN_COORD.World then
			return IScene:parts_bound(temp_nodes)
		else
			return IScene:parts_obb_bound(temp_nodes, act_part)
		end
	end

	local align_target_ins = self:get_align_target(instances)
	local align_target_node = align_target_ins:node()
	local align_target_vnode = align_target_ins:vnode()
	local temp_box = get_range_bound(nodes, align_target_node)
	local range_min = temp_box.min
	local range_max = temp_box.max
	local range_center = IScene:parts_center(nodes)
	temp_box = get_range_bound({ align_target_node }, align_target_node)
	local align_target_ins_min = temp_box.min
	local align_target_ins_max = temp_box.max

	local function get_align_pos(vnode, is_align_target, nodeAABB)
		local function get_world_range_align_pos(reference_pos)
			local current_world_pos = vnode["position"]
			local value = { x = current_world_pos.x, y = current_world_pos.y, z = current_world_pos.z }
			local offset = { x = 0, y = 0, z = 0 }
			local offset = { x = 0, y = 0, z = 0 }
			local size = nodeAABB
			offset	= { x = (size.max.x - size.min.x) / 2, y = (size.max.y - size.min.y) / 2, z = (size.max.z - size.min.z) / 2 } 
			if style == ALIGN_STYLE.Center then
				offset = { x = 0, y = 0, z = 0 }
			elseif style == ALIGN_STYLE.Right then
				offset.x = -1 * offset.x
				offset.y = -1 * offset.y
				offset.z = -1 * offset.z
			end
			if axis.x == 1 then
				value.x = reference_pos.x + offset.x
			end
			if axis.y == 1 then
				value.y = reference_pos.y + offset.y
			end
			if axis.z == 1 then
				value.z = reference_pos.z + offset.z
			end
			return value
		end

		local function get_local_range_align_pos(reference_pos)
			local local_pos = align_target_ins:node():toLocalPosition(reference_pos, false)
			local local_node_pos = align_target_ins:node():toLocalPosition(vnode["position"], false)
			local offset = { x = 0, y = 0, z = 0 }
			local size = nodeAABB
			offset = { x = (size.max.x - size.min.x) / 2, y = (size.max.y - size.min.y) / 2, z = (size.max.z - size.min.z) / 2 }

			if style == ALIGN_STYLE.Center then
				offset = { x = 0, y = 0, z = 0 }
			elseif style == ALIGN_STYLE.Right then
				offset.x = -1 * offset.x
				offset.y = -1 * offset.y
				offset.z = -1 * offset.z	
			end

			if axis.x == 1 then
				local_pos.x = local_pos.x + offset.x
			else
				local_pos.x = local_node_pos.x
			end

			if axis.y == 1 then
				local_pos.y = local_pos.y + offset.y
			else
				local_pos.y = local_node_pos.y
			end

			if axis.z == 1 then
				local_pos.z = local_pos.z + offset.z
			else
				local_pos.z = local_node_pos.z
			end

			local value = align_target_ins:node():toWorldPosition(local_pos, false)
			return value
		end

		local function get_world_object_align_pos(reference_pos)
			local current_world_pos = vnode["position"]
			local value = { x = current_world_pos.x, y = current_world_pos.y, z = current_world_pos.z }
			local offset = { x = 0, y = 0, z = 0 }
			local size = vnode["size"]
			if style == ALIGN_STYLE.Left then
				offset = { x = size["x"] / 2, y = size["y"] / 2, z = size["z"] / 2 }
			elseif style == ALIGN_STYLE.Right then
				offset = { x = -size["x"] / 2, y = -size["y"] / 2, z = -size["z"] / 2 }
			end
			if axis.x == 1 then
				value.x = reference_pos.x + offset.x
			end
			if axis.y == 1 then
				value.y = reference_pos.y + offset.y
			end
			if axis.z == 1 then
				value.z = reference_pos.z + offset.z
			end
			return value
		end

		local function get_local_object_align_pos()
			local local_pos = align_target_ins:node():toLocalPosition(vnode["position"], false)
			local size = vnode["size"]
			local offset
			--offset等于自身的size的一半加上对齐物size的一半
			if style == ALIGN_STYLE.Left then
				offset = { x = -align_target_vnode["size"]["x"] / 2 + size["x"] / 2, y = -align_target_vnode["size"]["y"] / 2 + size["y"] / 2, z = -align_target_vnode["size"]["z"] / 2 + size["z"] / 2 }
			elseif style == ALIGN_STYLE.Right then
				offset = { x = align_target_vnode["size"]["x"] / 2 - size["x"] / 2, y = align_target_vnode["size"]["y"] / 2 - size["y"] / 2, z = align_target_vnode["size"]["z"] / 2 - size["z"] / 2 }
			end
			if axis.x == 1 then
				if offset then
					local_pos.x = offset.x 
				else
					local_pos.x = 0
				end
			end
			if axis.y == 1 then
				if offset then
					local_pos.y = offset.y 
				else
					local_pos.y = 0
				end
			end
			if axis.z == 1 then
				if offset then
					local_pos.z = offset.z 
				else
					local_pos.z = 0
				end
			end
			local value = align_target_ins:node():toWorldPosition(local_pos, false)
			return value
		end
		-----------------------------------------------------------------------------1
		
		if style == ALIGN_STYLE.Left and coord == ALIGN_COORD.World and target == ALIGN_TARGET.Range then   --最小，世界坐标，范围对齐
			return get_world_range_align_pos(range_min)
		end
		if style == ALIGN_STYLE.Left and coord == ALIGN_COORD.Local and target == ALIGN_TARGET.Range then	--最小，本地坐标，范围对齐
			return get_local_range_align_pos(range_min)
		end
		if style == ALIGN_STYLE.Left and coord == ALIGN_COORD.World and target == ALIGN_TARGET.Object then 	--最小，世界坐标，对象对齐
			if is_align_target then
				return false
			end
			return get_world_object_align_pos(align_target_ins_min)
		end
		if style == ALIGN_STYLE.Left and coord == ALIGN_COORD.Local and target == ALIGN_TARGET.Object then	--最小，本地坐标，对象对齐
			if is_align_target then
				return false
			end
			return get_local_object_align_pos()
		end
		-----------------------------------------------------------------------------2
		
		if style == ALIGN_STYLE.Center and coord == ALIGN_COORD.World and target == ALIGN_TARGET.Range then  --中间，世界坐标，范围对齐
			return get_world_range_align_pos(range_center)
		end
		if style == ALIGN_STYLE.Center and coord == ALIGN_COORD.Local and target == ALIGN_TARGET.Range then  --中间，本地坐标，范围对齐
			return get_local_range_align_pos(range_center)
		end
		if style == ALIGN_STYLE.Center and coord == ALIGN_COORD.World and target == ALIGN_TARGET.Object then  --中间，世界坐标，对象对齐
			if is_align_target then
				return false
			end
			return get_world_object_align_pos(align_target_ins:vnode()["position"])
		end
		if style == ALIGN_STYLE.Center and coord == ALIGN_COORD.Local and target == ALIGN_TARGET.Object then  --中间，本地坐标，对象对齐
			if is_align_target then
				return false
			end
			return get_local_object_align_pos()
		end
		-----------------------------------------------------------------------------3
		
		if style == ALIGN_STYLE.Right and coord == ALIGN_COORD.World and target == ALIGN_TARGET.Range then  --最大，世界坐标，范围对齐
			return get_world_range_align_pos(range_max)
		end
		if style == ALIGN_STYLE.Right and coord == ALIGN_COORD.Local and target == ALIGN_TARGET.Range then  --最大，本地坐标，范围对齐
			return get_local_range_align_pos(range_max)
		end
		if style == ALIGN_STYLE.Right and coord == ALIGN_COORD.World and target == ALIGN_TARGET.Object then  --最大，世界坐标，对象对齐
			if is_align_target then
				return false
			end
			return get_world_object_align_pos(align_target_ins_max)
		end
		if style == ALIGN_STYLE.Right and coord == ALIGN_COORD.Local and target == ALIGN_TARGET.Object then  --最大，本地坐标，对象对齐
			if is_align_target then
				return false
			end
			return get_local_object_align_pos()
		end
	end

	for i, obj in pairs(instances) do
		local node1 = obj:node()
		local vnode = obj:vnode()
		local nodeAABB = IScene:parts_bound({ node1 })
		local is_align_target = obj:vnode()["id"] == State:instance_align_setting()[align_target_id]
		local alignPos = get_align_pos(obj:vnode(), is_align_target, nodeAABB)
		if alignPos then
			vnode["position"] = alignPos
		end
	end
	State:instance_align_setting()[activate_align] = false
end

function M:show_object_to_align_target(ins)
	debugDraw:clearActiveObject()
	if ins then
		debugDraw:setActiveObject(ins:node())
	end
end

function M:hide_object_to_align_target()
	debugDraw:clearActiveObject()
end

function M:set_object_to_align_target(select_obj)
	State:instance_align_setting()[align_target_id] = select_obj:vnode()["id"]
end

function M:reset_object_to_align_target(select_obj)
	local instance_align_setting = State:instance_align_setting()
	if instance_align_setting[align_target_id] == select_obj:vnode()["id"] then
		instance_align_setting[align_target_id] = ""
	end
end

function M:set_current_align_obj_count(up)
	local instance_align_setting = State:instance_align_setting()
	if up then
		instance_align_setting[current_align_obj_count] = instance_align_setting[current_align_obj_count] + 1
	else
		local temp_count = State:instance_align_setting()[current_align_obj_count] - 1
		if temp_count < 0 then
			instance_align_setting[current_align_obj_count] = 0
		else
			instance_align_setting[current_align_obj_count] = temp_count
		end
	end
	instance_align_setting[activate_align] = State:instance_align_setting()[current_align_obj_count] > 1
end

function M:get_align_target()
	if State:instance_align_setting()[align_target_id] ~= "" then
		return Map:query_instance(State:instance_align_setting()[align_target_id])
	end
end

return M