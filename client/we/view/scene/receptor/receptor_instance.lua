local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"
local Signal = require "we.signal"
local Input = require "we.view.scene.input"
local Map = require "we.view.scene.map"
local Storage = require "we.view.scene.storage"
local State = require "we.view.scene.state"
local Receptor = require "we.view.scene.receptor.receptor"
local Placer = require "we.view.scene.placer.placer"
local Operator = require "we.view.scene.operator.operator"
local PartOperation = require "we.view.scene.logic.part_operation"
local PartTransform = require "we.view.scene.logic.part_transform"
local PartAlignment = require "we.view.scene.logic.part_alignment"
local Bunch = require "we.view.scene.bunch"
local Gizmo = require "we.view.scene.gizmo"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local Dialog = require "we.view.scene.dialog"

local ObjInst = require "we.view.scene.object.object_instance"
local BindObject = require "we.view.scene.bind.bind_object"
local Base = require "we.view.scene.receptor.receptor_base"
local M = Lib.derive(Base)

function M:init()
	Base.init(self, "instance")

	self._set = {}
	self._current = nil
	self._order = 1
	self._geo_change = false
	self._set_change = false
	self._hold = false
	self._show_dialog = false
	PartAlignment:init()
	PartOperation:init()
end

function M:ephemerid()
	return true
end

function M:accept(type)
	return type & Def.SCENE_NODE_TYPE.OBJECT ~= 0
end

local function on_bound_box_changed(self)

end

local function remove(self, obj, clear)
	if not self._set[obj] then
		return
	end

	local watcher = self._set[obj].watcher
	self._set[obj] = nil

	for _, cancel in ipairs(watcher) do
		cancel()
	end

	obj:set_select(false)

	if obj:check_base("Instance_TickBase") then
		obj:parent():recover_translucence()
	end

	if not clear then
		Bunch:detach(obj:vnode())
	end
	PartAlignment:reset_object_to_align_target(obj)
	PartAlignment:set_current_align_obj_count(false)
	self._set_change = true
end

local function insert(self, obj)
	if self._set[obj] then
		return
	end
	
	local watcher = {}
	table.insert(watcher, Signal:subscribe(obj, obj.SIGNAL.GEOMETRIC_CHANGED, function()
		self._geo_change = true
	end))

	table.insert(watcher, Signal:subscribe(obj, obj.SIGNAL.DESTROY, function()
		remove(self, obj)
	end))

	self._order = self._order + 1
	self._set[obj] = { watcher = watcher, order = self._order}
	obj:set_select(true)

	if obj:check_base("Instance_TickBase") then
		obj:parent():set_translucence()
	end

	Bunch:attach(obj:vnode())
	PartAlignment:set_object_to_align_target(obj)
	PartAlignment:set_current_align_obj_count(true)
	self._set_change = true
end

function M:update()
	if self._set_change or self._geo_change then
		self._set_change = false
		Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED, IScene:parts_center(self:nodes(
			function(obj)
				return obj:check_ability(obj.ABILITY.AABB)
			end
		)))
		Signal:publish(self, M.SIGNAL.ABILITY_CHANGE)
	end

	if self._geo_change then
		self._geo_change = false
		Bunch:mark_dirty("", "position")
		Bunch:mark_dirty("", "size")
		Bunch:mark_dirty("", "rotation")
--		Bunch:mark_dirty("", "scale")
--		Bunch:mark_dirty("", "originSize")
		Bunch:mark_dirty("", "volume")
		Bunch:mark_dirty("", "mass")
		Bunch:mark_dirty("", "anchorPoint")

		Map:set_modify()
	end
end

function M:on_bind()
	self:clear()
end

function M:on_unbind()
	self:clear()
end

function M:nodes(filter, include_children)
	local function list_children(obj, nodes)
		for _, child in ipairs(obj:children()) do
			local vnode = child:vnode()
			if vnode.is_null_object then
				local bind_obj = BindObject:bind_object(vnode)
				if bind_obj then
					table.insert(nodes,bind_obj.engin_obj)
				end
			elseif not filter or filter(child) then
				table.insert(nodes, child:node())
			end
			list_children(child, nodes)
		end
	end

	local nodes = {}
	
	for o in pairs(self._set) do
		local vnode = o:vnode()
		if vnode.is_null_object then
			local bind_obj = BindObject:bind_object(vnode)
			if bind_obj then
				table.insert(nodes,bind_obj.engin_obj)
			end
		elseif not filter or filter(o) then
			table.insert(nodes, o:node())
		end
		
		if include_children then
			list_children(o, nodes)
		end
	end

	return nodes
end

--用支持的ability过滤children
function M:nodes_by_ability(ability, include_children)
	local filter = function (obj)
		return obj:check_ability(ability)
	end
	return self:nodes(filter,include_children)
end

function M:bound()
	return IScene:parts_bound_exclude_children(self:nodes(
		function(obj)
			return obj:check_ability(obj.ABILITY.AABB)
		end
	))
end

function M:gizmo_center()
	return IScene:parts_gizmo_center(self:nodes(
		function(obj)
			return obj:check_ability(obj.ABILITY.AABB)
		end
	))
end

function M:on_mouse_move(x, y)
	if not self._hold then
		return
	end

	if Gizmo:type() ~= Gizmo.TYPE.NONE then 
		return true
	end 

	IScene:drag_parts(self:nodes(
		function(obj)
			return obj:check_ability(obj.ABILITY.AABB)
		end, true
	), x, y)
	self._geo_change = true
	return true
end

local function set_select(self, flag)
	local list = self:nodes(function(obj)
			return obj:check_ability(obj.ABILITY.AABB)
	end, true)

	for _, node in ipairs(list) do
		node:setSelectable(flag)
	end
end

function M:hover_unlock(obj)
	assert(obj)
	local watcher = {}
	table.insert(watcher, Signal:subscribe(obj, obj.SIGNAL.GEOMETRIC_CHANGED, function()
		self._geo_change = true
	end))

	table.insert(watcher, Signal:subscribe(obj, obj.SIGNAL.DESTROY, function()
		remove(self, obj)
	end))
	self._order = self._order + 1
	self._set[obj] = { watcher = watcher, order = self._order}

	local root_obj = obj:find_toppest_model_ancestor() or obj
	root_obj:traverse_children(function(tgt_obj)
		tgt_obj:setLocked(false)
	end
	)

end

function M:hold()
	if Input:check_key_press(Input.KEY_CODE.Key_Control) then
		return
	end

	self._hold = true
	set_select(self, false)

	IScene:start_drag_parts(self:nodes(
		function(obj)
			return obj:check_ability(obj.ABILITY.AABB)
		end
	))

	self:on_drag()
end

function M:on_mouse_press(x, y, button)
	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end

	-- go through to picker
	if Input:check_key_press(Input.KEY_CODE.Key_Control) then
		return
	end

	local node = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.OBJECT)
	if not node then
		return
	end

	local obj = Map:query_instance(node)
	if obj then
		PartAlignment:set_object_to_align_target(obj)
	else
		return
	end

	local tgt_obj = obj:find_toppest_model_ancestor() or obj
	if not self._set[tgt_obj] then
		return
	end

	self:hold()

	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_MIDDLE then
		return
	end
	if is_click and button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT then
		local node = IScene:pick_point({ x = x, y = y }, Def.SCENE_NODE_TYPE.OBJECT)
		if not node or next(self._set) == nil or not self._show_dialog then
			return
		end
		Dialog:signal("DIALOG_MENU")
		return
	end

	if not self._hold then
		return
	end

	set_select(self, true)
	self._hold = false
	
	IScene:end_drag_parts()
	self:on_drop()

	return true
end

function M:on_lost_focus()
	if not self._hold then
		return
	end
	set_select(self, true)
	self._hold = false
	
	IScene:end_drag_parts()
end

function M:on_key_press(key)
	if Input:check_key_press(Input.KEY_CODE.Key_Control) then
		local is_scene = true
		if key == Input.KEY_CODE.Key_C then
			local op = assert(Operator:operator("COPY"))
			if op:check(self) then
				op:exec(self, is_scene)
			end
		end
		if key == Input.KEY_CODE.Key_X then
			local op = assert(Operator:operator("CUT"))
			if op:check(self) then
				op:exec(self, is_scene)
			end
		end
	end
end

function M:on_key_release(key)
	if key == Input.KEY_CODE.Key_Delete then
		local obj = next(self._set)
		if not obj then
			return
		end

		repeat
			local obj_parent = obj:parent()
			if not obj:isGlobalLight() and not obj:isShareFolder() then
				remove(self, obj)
				local data = obj_parent and obj_parent:remove_child(obj) or Map:remove_instance(obj)
			end
			obj = next(self._set, obj)
		until(not obj)

		return true
	end
end

local function check_count(list, min_count, compare_list)
	local count = Lib.getTableSize(list)
	return count > min_count and count == Lib.getTableSize(compare_list)
end

local op_checker = {
	MOVE = function(self)
		local list = self:list(function(obj)
			if obj:check_ability(obj.ABILITY.MOVE) and not obj:isGlobalLight() then
				return true
			end
		end)
		
		local ok = check_count(list, 0, self:list())
		BindObject:check_gizmo("move")
		return ok
	end,

	ROTATE = function(self)
		local list = self:list(function(obj)
			if obj:check_ability(obj.ABILITY.ROTATE) and not obj:isGlobalLight() then
				return true
			end
		end)
		local ok = check_count(list, 0, self:list())
		BindObject:check_gizmo("rotate")
		return ok
	end,

	SCALE = function(self)
		local list = self:list(function(obj)
			if obj:check_ability(obj.ABILITY.SCALE)then
				return true
			end
		end)
		local ok = check_count(list, 0, self:list())
		BindObject:check_gizmo("scale")
		return ok
	end,

	UNION = function(self)
		local list = self:list(function(obj)
			if obj:check_part_mix(obj,"UNION") then
				return true
			end
		end)
		return check_count(list, 1, self:list())
	end,

	INTERSECT = function(self)
		local list = self:list(function(obj)
			if obj:check_part_mix(obj,"INTERSECT") then
				return true
			end
		end)
		return check_count(list, 1, self:list())
	end,

	REVERSE = function(self)
		local list = self:list(function(obj)
			if obj:check_part_mix(obj,"REVERSE") then
				return true
			end
		end)
		return check_count(list, 1, self:list())
	end,

	SPLIT = function(self)
		local list = self:list(function(obj)
			if obj:class() == "PartOperation" then
				return true
			end
		end)
		return check_count(list, 0, self:list())
	end,

	GROUP = function(self)
		local list = self:list(function(obj)
			if obj:check_part_mix(obj,"MODEL") then
				return true
			end
		end)
		return check_count(list, 1, self:list())
	end,

	UNGROUP = function(self)
		local list = self:list(function(obj)
			if obj:class() == "Model" then
				return true
			end
		end)
		return check_count(list, 0, self:list())
	end,

	PASTE = function(self)
		local data = PartOperation:copy_list()
		return #data > 0
	end,

	PASTE_TO = function(self)
		local data = PartOperation:copy_list()
		return #data > 0
	end,

	REPETITION = function(self)
		return next(self._set) ~= nil
	end,

	COPY = function(self)
		if not next(self._set) then
			return false
		end

		return true
	end,

	CUT = function(self)
		if not next(self._set) then
			return false
		end

		return true
	end,
	
	GET_CFG = function(self)
		return Lib.getTableSize(self._set) == 1
	end,

	ALIGN = function(self)
		local list = self:list(function(obj)
			if obj:check_part_mix(obj,"MODEL") then
				return true
			end
		end)
		return check_count(list, 1, self:list())
	end,

	CHANGELIGHTANGLE = function(self)
		local list = self:list(function(obj)
			return obj:class() == "Light"
		end)
		return check_count(list, 0, self:list())
	end
}

local op_executer = {
	MOVE = function(self, offset)
		IScene:move_parts(self:nodes(
			function(obj)
				return obj:check_ability(obj.ABILITY.AABB)
			end, true
		), offset)
		self._geo_change = true
	end,

	ROTATE = function(self, aix, degress)
		--旋转中心点只算选中的零件
		local attach_nodes = self:nodes_by_ability(ObjInst.ABILITY.AABB,false)
		local point = IScene:parts_gizmo_center(attach_nodes)
		--旋转的时候子节点都要一起旋转
		IScene:rotate_parts_around_point(self:nodes_by_ability(ObjInst.ABILITY.AABB,true), aix,point, degress)
		self._geo_change = true
	end,

	SCALE = function(self, aix, offset, stretch)
		local nodes = self:nodes(
			function(obj)
				return obj:check_ability(obj.ABILITY.AABB) and obj:class() ~= "Light"
			end, true
		)

		if #nodes == 0 then
			return
		end

		local box = IScene:parts_aabb(nodes)
		if not box then
			return
		end
		
		local aix = aix == 1 and "x" or aix == 2 and "y" or "z"
		local dist = (offset.x ^ 2 + offset.y ^ 2 + offset.z ^ 2) ^ 0.5
		-- 疑问：这里乘以2是当时的需求吗?
		local diff = stretch and (1 * dist) or (- 1 * dist)
	
		if #nodes == 1 then
			local node = nodes[1]
			local size = IInstance:size(node)
			size[aix] = size[aix] + diff
			if size[aix] <= 0.1 then
				return
			end

			local pos = IScene:parts_gizmo_center(nodes)
			if aix == "x" then
				size = node:getValidSize(size, 0)
			elseif aix == "y" then
				size = node:getValidSize(size, 1)
			else
				size = node:getValidSize(size, 2)
			end
			local oldSize = node:getSize()
			local scale = {x = size.x / oldSize.x, y = size.y / oldSize.y, z = size.z / oldSize.z}
			IScene:scale_parts_base_point(nodes, scale, pos)
		else
			local size

			local oldMin = box[2][aix]

			local isAlign
			local eps = 1e-6
			--方向平行于某条坐标轴，则gizmo沿着aabb方向，否则gizmo沿着obb方向
			if (math.abs(offset.x * offset.y) < eps) and (math.abs(offset.x * offset.z) < eps)  and (math.abs(offset.z * offset.y) < eps) and dist >0 then
				isAlign = true
			else
				isAlign = false
			end

			if isAlign then
				size = math.abs(box[3][aix] - box[2][aix])
			else
				local obb = IScene:parts_obb(nodes)
				size = math.abs(obb[1][aix]) * 2
			end

			if size <= 0.1 and not stretch then
				return
			end

			local scale = (size + diff) / size
			if scale <= 0 then
				return
			end

			IScene:scale_parts(nodes, {x = scale, y = scale, z = scale})


			--model有旋转，但是gizmo沿着坐标轴方向时
			if isAlign then
				box = IScene:parts_aabb(nodes)
				local newMin = box[2][aix]
				local newDist = math.abs(newMin-oldMin)/dist
				offset.x = offset.x * newDist
				offset.y = offset.y * newDist
				offset.z = offset.z * newDist
			end

		end
		local move_nodes = self:nodes(
				function(obj)
					return obj:class() =="Part" or obj:class() =="RegionPart" or obj:class() == "Model"
				end, false
		)
		offset.x = offset.x * 0.5
		offset.y = offset.y * 0.5
		offset.z = offset.z * 0.5
		IScene:move_parts(move_nodes, offset)
		self._geo_change = true
	end,

	UNION = function(self)
		PartTransform:part_combine(self, 0)
	end,

	INTERSECT = function(self)
		PartTransform:part_combine(self, 1)
	end,

	REVERSE = function(self)
		PartTransform:part_combine(self, 2)
	end,

	SPLIT = function(self)
		PartTransform:part_split(self)
	end,
	
	COMBINED_FOLDER = function(self)
		PartTransform:part_combine_folder(self)
	end,

	GROUP = function(self)
		PartTransform:part_group(self)
	end,

	UNGROUP = function(self)
		PartTransform:part_ungroup(self)
	end,

	PASTE = function(self)
		local parent = self._current and self._current:parent() or nil
		PartOperation:part_paste(PartOperation:copy_list(), parent)
	end,

	PASTE_TO = function(self)
		PartOperation:part_paste(PartOperation:copy_list(), self._current)
	end,

	REPETITION = function(self)
		local list = {}
		local parents = {}
		local obj_list = self:list()
		obj_list = PartTransform:remove_list_child(obj_list, false)
		for _,obj in ipairs(obj_list) do
			local val = obj:value()
			if obj:parent() then
				parents[val.id] = obj:parent()
			end
			table.insert(list, val)
		end

		PartOperation:part_repetition(list, parents)
	end,

	STORAGE = function(self)
		local list = {}
		for obj in pairs(self._set) do
			table.insert(list, obj:value())
		end
		Storage:add_storage(list)
	end,

	COPY = function(self, is_scene)
		local list = {}
		local obj_list = self:list()
		obj_list = PartTransform:remove_list_child(obj_list, false)
		for _,obj in ipairs(obj_list) do
			table.insert(list, obj:value())
		end

		local copy_list = PartOperation:part_copy(list)
		if is_scene then 
			local placer = Placer:bind("instance")
			placer:select(copy_list)
			Receptor:unbind()
		else
			Placer:unbind()
		end 
	end,

	CUT = function(self, is_scene)
		local list = {}
		local obj_list = self:list()
		obj_list = PartTransform:remove_list_child(obj_list, false)
		for _,obj in ipairs(obj_list) do
			table.insert(list, obj:value())
		end

		for obj in pairs(self._set) do
			remove(self, obj)
			local parent = obj:parent()
			if not parent then
				Map:remove_instance(obj)
			else
				parent:remove_child(obj)	
			end
		end

		local copy_list = PartOperation:part_copy(list)
		if is_scene then 
			local placer = Placer:bind("instance")
			placer:select(copy_list)
			Receptor:unbind()
		else
			Placer:unbind()
		end 
	end,

	GET_CFG = function(self)
		for obj in pairs(self._set) do
			local type = obj:class()
			if type == "DropItem" then
				type = "item"
			end
			local cfg = { cfg = obj:vnode()["config"], type = string.lower(type) }
			return cfg
		end
	end,

	ALIGN = function(self)
		PartAlignment:align(self)
	end,

	CHANGELIGHTANGLE = function(self, attr, value, id)
		local light = Map:query_instance(id)
		light:vnode()[attr] = value
	end
}

function M:check_op(op, ...)
	local proc = op_checker[string.upper(op)]
	if proc then
		return proc(self, op, ...)
	end

	return op_executer[string.upper(op)] ~= nil
end

function M:exec_op(op, ...)
	local proc = op_executer[string.upper(op)]
	assert(proc, string.format("op [%s] is not support", op))

	return proc(self, ...)
end

function M:attach(node, xor, root, locked)
	local obj = Map:query_instance(node)
	assert(obj)
	
	if locked then
		return
	end

	if root then
		obj = obj:root()
	end
	self._current = obj

	if self._set[obj] then
		if xor then
			remove(self, obj)
		end
	else
		insert(self, obj)
	end
end

function M:detach(node)
	local obj = Map:query_instance(node)
	assert(obj)
	self._current = nil
	remove(self, obj)
end

function M:clear()
	local obj = next(self._set)

	if not obj then
		return
	end

	repeat
		remove(self, obj, true)
		obj = next(self._set, obj)
	until(not obj)

	Bunch:clear()
end

function M:rotation()
	local list = self:list(function(obj)
		return obj:check_ability(obj.ABILITY.AABB)
	end)
	local last = list[#list]
	return last and last:rotation()
end

function M:list(filter)
	local list = {}
	for obj, v in pairs(self._set) do
		if not filter or filter(obj) then
			table.insert(list, {obj = obj, order = v.order})
		end
	end

	table.sort(list, function(l, r)
		return l.order < r.order
	end)

	local ret = {}
	for _, v in ipairs(list) do
		table.insert(ret, v.obj)
	end

	return ret
end

function M:need_upright()
	local obj, val = next(self._set)
	if not obj then
		return false
	end

	if obj:class() ~= "Entity" then
		return false
	end

	if next(self._set, obj) then
		return false
	end

	return true
end

function M:on_drag()
	for obj in pairs(self._set) do
		obj:on_drag()
	end
end

function M:on_drop()
	for obj in pairs(self._set) do
		obj:on_drop()
	end
end

function M:show_dialog(showed)
	self._show_dialog = showed
end

function M:get_dialog_showed()
	return self._show_dialog
end

return M
