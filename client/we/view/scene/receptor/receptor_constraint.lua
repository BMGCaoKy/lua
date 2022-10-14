local Def = require "we.def"
local Input = require "we.view.scene.input"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local Signal = require "we.signal"
local State = require "we.view.scene.state"
local Constraint = require "we.view.scene.logic.constraint"
local Base = require "we.view.scene.receptor.receptor_base"
local Map = require "we.view.scene.map"

local M = Lib.derive(Base)

M.PIVOTCOLOR = {
	NORMAL	= {78 / 255, 185 / 255, 204 / 255, 0.7},
	HOVER	= {0, 234 / 255, 0, 0.7}
}

function M:init()
	Base.init(self, "constraint")

	self._set = {}
	self._current_pivot = nil
end

function M:ephemerid()
	return true
end

function M:accept(type)
	return type == Def.SCENE_NODE_TYPE.INSTANCE
end

local function update_focus(self)
	local obj = next(self._set)
	if not obj then
		State:focus()
	else
		if next(self._set, obj) then
			State:focus()
		else
			State:focus(obj:constraint():vnode())
		end
	end
end

local function remove(self, obj, destory)
	if not self._set[obj] then
		return
	end

	local watcher = self._set[obj].watcher
	self._set[obj] = nil
	for _,cancel in ipairs(watcher) do
		cancel()
	end

	self._current_pivot = nil
	if not destory then
		obj:set_select(false, State:constraint_normally_on())
	end

	if self._cuurent_obj == obj then
		Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
		Signal:publish(self, M.SIGNAL.ABILITY_CHANGE)
	end
	update_focus(self)
end

local function insert(self, obj)
	if self._set[obj] then
		return
	end

	local watcher = {}
	table.insert(watcher, Signal:subscribe(obj, obj.SIGNAL.CONSTRAINTDESTROY, function()
		remove(self, obj, true)
	end))
	table.insert(watcher, Signal:subscribe(obj, obj.SIGNAL.SLAVEPARTSET, function()
		Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
	end))
	table.insert(watcher, Signal:subscribe(obj, obj.SIGNAL.MASTERPIVOTPOSCHANGED, function()
		Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
	end))
	table.insert(watcher, Signal:subscribe(obj, obj.SIGNAL.SLAVEPIVOTPOSCHANGED, function()
		Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
	end))
	self._set[obj] = {watcher = watcher}
	obj:set_select(true)
	self._cuurent_obj = obj
	if obj:constraint():class() ~= "FixedConstraint" then
		self._current_pivot = obj:master_pivot()
	end
	Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
	Signal:publish(self, M.SIGNAL.ABILITY_CHANGE)
	update_focus(self)
end

function M:on_bind()
	
end

function M:on_unbind()
	local obj = next(self._set)

	if not obj then
		return
	end

	repeat
		remove(self, obj)
		obj = next(self._set, obj)
	until(not obj)
end

function M:center()
	if self._current_pivot then
		local id = IInstance:id(self._current_pivot)
		return Constraint:query_pivot_position(id)
	end
end

local op_checker = {
	MOVE = function(self)
		return next(self._set) ~= nil
	end
}

local op_executer = {
	MOVE = function(self, offset)
		IScene:move_parts({self._current_pivot}, offset)
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

function M:gizmo_center()
	return self:center()
end

function M:on_mouse_move(x, y)
	local node = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.INSTANCE)
	if node then
		self._hover_node = node
		node:setColor(M.PIVOTCOLOR.HOVER)
		return
	end
	if not node and self._hover_node then
		self._hover_node:setColor(M.PIVOTCOLOR.NORMAL)
		self._hover_node = nil
		return
	end
	
end

function M:on_mouse_press(x, y, button)
	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end
	local node = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.INSTANCE)
	if not node then
		return
	end

	self._current_pivot = Constraint:query_pivot(IInstance:id(node))
	if not self._current_pivot then
		return
	end

	Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)

	return true
end

function M:attach(node, xor)
	local id = tostring(IInstance:id(node))
	local obj = Constraint:query_constraint_by_constraint_id(id)
	if not obj then
		local obj_instance = Map:query_instance(node)
		assert(obj_instance)
		Constraint:relevance_constraint(obj_instance)
		obj = Constraint:query_constraint_by_constraint_id(id)
		assert(obj)
	end

	if self._set[obj] then
		if xor then
			remove(self, obj)
		end
	else
		insert(self, obj)
	end
end

function M:detach(node)
	local id = tostring(IInstance:id(node))
	local obj = Constraint:query_constraint_by_constraint_id(id)
	assert(obj)
	remove(self, obj)
end

return M