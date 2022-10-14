local Def = require "we.def"
local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local Meta = require "we.gamedata.meta.meta"
local Map = require "we.view.scene.map"
local Picker = require "we.view.scene.picker.picker"
local Input = require "we.view.scene.input"
local Base = require "we.view.scene.placer.placer_base"
local Constraint = require "we.view.scene.logic.constraint"
local State = require "we.view.scene.state"
local Gizmo = require "we.view.scene.gizmo"
local Placer = require "we.view.scene.placer.placer"
local Recorder = require "we.gamedata.recorder"

---@class PlacerPart:PlacerBase
local M = Lib.derive(Base)

local click_step = {
    ["prep"] = 0,
    ["first_click"] = 1
}

local function set_slave(self,instance)
	local id = tostring(IInstance:id(instance))
	self._constraint:constraint():set_slave_part_id(id)
	local slave = Map:query_instance(instance)
	self._constraint:constraint():set_slave_part_name(slave:name())
	self._constraint:set_slave(slave)
end

local function new_constraint(type, instance)
	local constraint = Constraint:new_constraint()
	local master = Map:query_instance(instance)
	local meta = Meta:meta(type):ctor({
		id = tostring(IWorld:gen_instance_id()),
		masterPartName = master:name()
	})
	local cons = master:new_child(meta)
	constraint:set_master(master)
	constraint:set_constraint(cons)
	return constraint
end

local function remove_constraint(self)
	if self._constraint then
		self._constraint:remove()
		self._constraint = nil
		self._constraint_inst = nil
		self._pivot = nil
	end
end

local function set_constraint_inst(self,inst)
	self._constraint_inst = inst
	IInstance:set_select(inst,true)
end

local function remove_constraint_inst(self)
	if self._constraint_inst then
		IWorld:remove_instance(self._constraint_inst)
		self._constraint_inst = nil
	end
end

local function set_pivot(self, pivot)
	self._pivot = pivot
end

local function remove_pivot(self)
	if self._pivot then
		IWorld:remove_instance(self._pivot)
		self._pivot = nil
	end
end

local function clear(self,unbind)
	self._click_step = nil
	self._type = nil
	self._inst_id = nil
	self._constraint_inst = nil
	self._pivot = nil
	remove_constraint(self)
	if unbind then
		Placer:unbind()
	end
end

function M:init(mode)
	Base.init(self, mode)
	self._click_step = nil
	self._constraint_inst = nil
	self._pivot = nil
	self._type = nil
	self._start_inst_pos = nil
	self._start_mouse_pos = nil
	self._is_check = nil
	self._start_inst = nil
end

function M:on_bind()
	
end

function M:on_unbind()
	self._type = nil
	self._inst_id = nil
	self._start_inst_pos = nil
	self._start_mouse_pos = nil
	remove_constraint(self)
	remove_constraint_inst(self)
	remove_pivot(self)
	if self._click_step then
		Recorder:set_enable(true)
	end
end

function M:select(item)
	clear(self)
	self._type = item
	self._click_step = click_step.prep
	local inst = Instance.Create("FixedConstraint")
	local pivot = IWorld:get_instance(inst:getMasterPivotID())
	set_constraint_inst(self,inst)
	local s_pivot = IWorld:get_instance(inst:getSlavePivotID())
	s_pivot:setDebugGraphShow(false)
	set_pivot(self,pivot)
	State:gizmo()["type"] = Gizmo.TYPE.NONE
end

function M:on_mouse_move(x, y)
	if not self._constraint_inst or not self._pivot then
        return
    end
    IInstance:set_world_pos(self._pivot,IScene:point2scene({ x = x, y = y }))
	return true
end

function M:check_press(instance)
	if self._click_step == click_step.first_click then
		if not instance then
			clear(self, true)
			return false
		end
		if self._constraint:constraint():class() == "FixedConstraint" then
			local slave = Map:query_instance(instance)
			local ret = Constraint:check_fixed_constraint(self._constraint:master(),slave)
			if ret then
				clear(self, true)
				return false
			end
		end
	end
	if not instance then
		Placer:unbind()
		return false
	end
	local inst_id = tostring(IInstance:id(instance))
	if inst_id == self._inst_id then
		clear(self, true)
		return false
	end
	self._inst_id = inst_id
	return true
end

function M:check_constraint(instance,insts_pos,mouse_pos)
	self._constraint = new_constraint(self._type, instance)
	local constraint_inst = self._constraint:constraint():node()
	set_constraint_inst(self,constraint_inst)
	IInstance:set_parent(constraint_inst,instance)

	self._constraint:set_master_local_pos(insts_pos)
	self._click_step = click_step.first_click
	local slave_pivot = IWorld:get_instance(constraint_inst:getSlavePivotID())
	
	--length > 0
	local slave_pivot_pos = IScene:point2scene(mouse_pos)
	IInstance:set_world_pos(slave_pivot,slave_pivot_pos)
	set_pivot(self,slave_pivot)
end

function M:on_mouse_press(x, y, button)
	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end
	if not self._constraint_inst or not self._pivot then
        return
    end
	local mouse_pos = { x = x, y = y }
	local instance = IScene:pick_point(mouse_pos, Def.SCENE_NODE_TYPE.PART, {"ConstraintPivot"})
	if not self:check_press(instance) then
		return
	end

	local point2scene = IScene:point2scene(mouse_pos)
	local insts_pos = instance:toLocalPosition(point2scene)
	remove_constraint(self)
	remove_constraint_inst(self)
	remove_pivot(self)
	if self._click_step == click_step.prep then
		Recorder:set_enable(false)
		mouse_pos.y = mouse_pos.y + 0.1
		self._start_inst_pos = insts_pos
		self._start_mouse_pos = mouse_pos
		self._start_inst = instance
		self:check_constraint(instance,insts_pos,mouse_pos,true)
	elseif self._click_step == click_step.first_click then
		Recorder:set_enable(true)
		Recorder:start()
		self:check_constraint(self._start_inst,self._start_inst_pos,self._start_mouse_pos)
		set_slave(self,instance)
		self._constraint:set_slave_local_pos(insts_pos)
		self._constraint:set_anchor_space()
		self._constraint:set_length()
		self._constraint:set_select(true)
		self._constraint = nil
		self._constraint_inst = nil
		self._start_inst_pos = nil
		self._start_mouse_pos = nil
		self._pivot = nil
		self._inst_id = nil
		self._start_inst = nil
		Placer:unbind()
		Recorder:stop()
	end
	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if not self._constraint_inst or not self._pivot then
        return
    end
	
	return true
end

return M