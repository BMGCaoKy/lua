local Def = require "we.def"
local Signal = require "we.signal"
local Cmd = require "we.view.scene.cmd.cmd"
local Engine = require "we.engine.engine"
local IWorld = require "we.engine.engine_world"
local IBlock = require "we.engine.engine_block"
local Input = require "we.view.scene.input"
local Setting = require "common.setting"
local VN = require "we.gamedata.vnode"
local Bunch = require "we.view.scene.bunch"
local SceneRegion = require "we.view.scene.logic.scene_region"

local Base = require "we.view.scene.receptor.receptor_base"

local M = Lib.derive(Base)

local block_class = {
	init = function(self, pos)
		self._orig = Lib.copy(pos)
		self._pos = Lib.copy(pos)

		self._id = IBlock:get_block(pos)
		self._box = nil
		self._block = nil
		self._vnode = VN.new("Instance_Block", {config = self:cfg(), position = self._pos})
	end,

	update = function(self)
		self._box:set_bound(self._pos, self._pos)
		self._block:set_pos(self._pos)
	end,

	move = function(self, dx, dy, dz)
		self:set_pos({x = self._pos.x + dx, y = self._pos.y + dy, z = self._pos.z + dz})
		self:update()
	end,

	set_pos = function(self, pos)
		self._pos = pos
		self:update()

		self._vnode.position = self._pos
	end,

	pos = function(self)
		return self._pos
	end,

	original = function(self)
		return self._orig
	end,

	show = function(self)
		self._block = IWorld:create_block_widget(self._id, self._pos)
		self._box = IWorld:create_box_widget(self._pos, self._pos)
	end,

	hide = function(self)
		IWorld:remove_block_widget(self._block)
		self._block = nil

		IWorld:remove_box_widget(self._box)
		self._box = nil
	end,

	adjust = function(self, forward)
		if forward then
			self._orig = Lib.copy(self._pos)
		else
			self:set_pos(Lib.copy(self._orig))
		end
	end,

	cfg = function(self)
		return Setting:id2name("block", self._id)
	end,

	vnode = function(self)
		return self._vnode
	end
}

function M:init()
	Base.init(self, "block")

	self._set = {}
	self._offset = {x = 0, y = 0, z = 0}
	self._moving = false
end

function M:ephemerid()
	return true
end

function M:accept(type)
	return type == Def.SCENE_NODE_TYPE.BLOCK
end

local function remove(self, obj, clear)
	if not self._set[obj] then
		return
	end

	obj:hide()
	self._set[obj] = nil

	if not clear then
		Bunch:detach(obj:vnode())
	end

	Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
	Signal:publish(self, M.SIGNAL.ABILITY_CHANGE)
end

local function insert(self, obj)
	if self._set[obj] then
		return
	end

	self._set[obj] = true
	obj:show()

	Bunch:attach(obj:vnode())
	Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
	Signal:publish(self, M.SIGNAL.ABILITY_CHANGE)
end

function M:on_bind()
	self:clear()
end

function M:on_unbind()
	self:clear()
	SceneRegion:cancel()
end

function M:bound()
	if not next(self._set) then
		return
	end

	local max_x, max_y, max_z, min_x, min_y, min_z
	for obj in pairs(self._set) do
		local pos = obj:pos()
		max_x = max_x and math.max(max_x, pos.x) or pos.x
		max_y = max_y and math.max(max_y, pos.y) or pos.y
		max_z = max_z and math.max(max_z, pos.z) or pos.z
		min_x = min_x and math.min(min_x, pos.x) or pos.x
		min_y = min_y and math.min(min_y, pos.y) or pos.y
		min_z = min_z and math.min(min_z, pos.z) or pos.z
	end

	return {
		min = {
			x = min_x,
			y = min_y,
			z = min_z
		},
		max = {
			x = max_x + 1,
			y = max_y + 1,
			z = max_z + 1
		}
	}
end


-- 中点
function M:center()
	local bound = self:bound()
	if not bound then
		return
	end

	return {
		x = (bound.max.x + bound.min.x) / 2,
		y = (bound.max.y + bound.min.y) / 2,
		z = (bound.max.z + bound.min.z) / 2,
	}
end

function M:gizmo_center()
	return self:center()
end

function M:on_key_release(key)
	
end

local op_checker = {
	MOVE = function(self)
		return next(self._set) ~= nil
	end,

	CONFIRM = function(self)
		return self._moving
	end,

	GET_CFG = function(self)
		return Lib.getTableSize(self._set) == 1
	end,

	COPY = function(self)
		return Lib.getTableSize(self._set) == 1
	end,

	CUT = function(self)
		return Lib.getTableSize(self._set) == 1
	end,
	
	DELETE = function(self)
		return next(self._set) ~= nil
	end,

	FILL = function(self)
		return next(self._set) ~= nil
	end,
}

local op_executer = {	
	MOVE = function(self, offset, pos_d)
		local pos_s = self:center()
		local dx = math.floor(pos_d.x - pos_s.x)
		local dy = math.floor(pos_d.y - pos_s.y)
		local dz = math.floor(pos_d.z - pos_s.z)
		if dx == 0 and dy == 0 and dz == 0 then
			return
		end
		
		self._offset.x = self._offset.x + dx
		self._offset.y = self._offset.y + dy
		self._offset.z = self._offset.z + dz

		for obj in pairs(self._set) do
			obj:move(dx, dy, dz)
		end

		self._moving = true
	end,

	CONFIRM = function(self, ok)
		if ok then
			local original = {}
			for obj in pairs(self._set) do
				table.insert(original, obj:original())
			end

			Cmd:block_move(original, self._offset)
		end

		for obj in pairs(self._set) do
			obj:adjust(ok)
		end

		Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
		self._moving = false
		self._offset = { x = 0, y = 0, z = 0 }
	end,


	GET_CFG = function(self)
		local block_obj = next(self._set)
		local cfg = { cfg = Setting:id2name("block", block_obj._id), type = "block" }
		return cfg
	end,

	COPY = function(self)
		local block_obj = next(self._set)
		Cmd:block_copy(block_obj:pos(), block_obj._id)
	end,

	CUT = function(self)
		local block_obj = next(self._set)
		Cmd:block_cut(block_obj:pos(), block_obj._id)
	end,

	DELETE = function(self)
		local list = {}
		for obj in pairs(self._set) do
			table.insert(list, { pos = obj:pos(), id = obj._id })
		end
		Cmd:block_dele(list)
	end,

	FILL = function(self, block_id)
		local list = {}
		for obj in pairs(self._set) do
			table.insert(list, { pos = obj:pos(), new_id = block_id, id = obj._id })
		end
		Cmd:block_fill(list)
	end,
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
	
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	return proc(self, ...)
end

local function get_obj(self, pos)
	for obj in pairs(self._set) do
		local op = obj:pos()
		if op.x == pos.x and op.y == pos.y and op.z == pos.z then
			return obj
		end
	end

	local obj = Lib.derive(block_class)
	obj:init(pos)

	return obj
end

function M:attach(pos, xor)
	local obj = get_obj(self, pos)
	if self._set[obj] then
		if xor then
			remove(self, obj)
		end
	else
		insert(self, obj)
	end
end

function M:detach(pos)
	local obj = get_obj(self, pos)
	remove(self, obj)
end

function M:clear()
	local obj = next(self._set)

	if not obj then
		return
	end

	repeat
		remove(self, obj)
		obj = next(self._set, obj)
	until(not obj)

	Bunch:clear()
end

function M:on_mouse_release(x, y, button, is_click)
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT then
		if not next(self._set) then
			return
		end
		for obj in pairs(self._set) do
			local pos = obj:pos()
			if Engine:detect_collision(pos, pos) then
				Engine:open_menu(self._type)
				return true
			end
		end
	end
end

function M:on_key_release(key)
	if Input:check_key_press(Input.KEY_CODE.Key_Control) then
		if key == Input.KEY_CODE.Key_C then
			self:exec_op("COPY")
			return true
		end
	end
	if key == Input.KEY_CODE.Key_Delete then
		self:exec_op("DELETE")
		return true
	end
end

return M
