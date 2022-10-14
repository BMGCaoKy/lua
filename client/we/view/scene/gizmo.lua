local Vector3 = require "common.math.vector3"
local Quaternion = require "common.math.quaternion"

local Def = require "we.def"
local Signal = require "we.signal"
local State = require "we.view.scene.state"
local Receptor = require "we.view.scene.receptor.receptor"
local Operator = require "we.view.scene.operator.operator"
local Dialog = require "we.view.scene.dialog"
local Input = require "we.view.scene.input"
local Map = require "we.view.scene.map"
local CW = World.CurWorld

local M = {}

M.TYPE = {
	NONE		= 0,
	TRANSLATE	= 1,
	ROTATE		= 2,
	SCALE		= 3,
	RANGE       = 4
}

M.MODE = {
	LOCAL		= 0,
	GLOBAL		= 1
}


local function set_enable(self, enable)
	if self._node then
		self._node:setVisible(enable)
	end
end

--处理器及gizmo类型检查
local function check_receptor(self)
	if not self._receptor then
		return false
	end
	if self._type == M.TYPE.NONE then
		return false
	end

	local type = self._type == M.TYPE.TRANSLATE and "MOVE"
	or self._type == M.TYPE.ROTATE and "ROTATE" or "SCALE"

	local op = Operator:operator(type)
	if not op:check(self._receptor) then
		return false
	end
	
	return true
end

--坐标轴
local function offsetedCenter(self)
	local offset = self:getOffset()
	local center = self._receptor:gizmo_center()

	if offset ~= nil and center ~= nil then
		center.x = center.x + offset.x
		center.y = center.y + offset.y
		center.z = center.z + offset.z
	end
	return center
end

local function update(self)
	if self._hold then
		return
	end

	if check_receptor(self) then
		set_enable(self, true)
	else
		set_enable(self, false)
	end

	if not self._node then
		return
	end

	if not self._receptor then
		return
	end

	if self._type == M.TYPE.ROTATE then
		if self._receptor:need_upright() then
			self._node:setShowAxis(2)
		else
			self._node:setShowAxis(0)
		end
	end

	self:set_postion(offsetedCenter(self))
	if self._mode == M.MODE.LOCAL then
		local rotation = self._receptor:rotation()
		if rotation then
			self:set_rotation(rotation)
		end
	else
		self:set_rotation({x=0,y=0,z=0})
	end
end

local function bind(self, receptor)
	if self._receptor == receptor then
		return
	end

	self._receptor = nil
	if self._receptor_monitor then
		self._receptor_monitor()
		self._receptor_monitor = nil
	end
	if self._receptor_anchor_monitor then
		self._receptor_anchor_monitor()
		self._receptor_anchor_monitor = nil
	end
	

	self._receptor = receptor
	if self._receptor then
		self._receptor_monitor = Signal:subscribe(self._receptor, receptor.SIGNAL.BOUND_BOX_CHANGED, function()
			update(self)
		end)

		self._receptor_anchor_monitor = Signal:subscribe(self._receptor, receptor.SIGNAL.ANCHOR_CHANGE, function()
			if next(self._receptor._set) and next(self._receptor._set, next(self._receptor._set)) == nil then 
				update(self)
			end
		end)
	end
	self._hold = self._receptor and  self._hold or false
	update(self)
end

function M:init()
	self._type = M.TYPE.NONE
	self._mode = M.MODE.LOCAL
	self._node = nil
	self._hold = false
	self._receptor = nil	-- target
	self._receptor_monitor = nil
	self._receptor_anchor_monitor = nil
	self._lightnode = nil
	-- 修改默认移动分度值为0.001
	self._step_move = 0.001
	self._step_rotate = 1
	self._step_scale = 0.001

	self._vnode = State:gizmo()
	Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_ASSIGN, function(key)
		if key == "type" then
			self:switch(self._vnode.type)
			update(self)
		elseif key == "step_move_enable" or key == "step_move" then
			if self._vnode.step_move_enable then
				self:set_move_step(self._vnode.step_move)
				self:set_scale_step(self._vnode.step_move)
				local manager = CW:getSceneManager()
				if manager ~= nil then
					manager:setMoveInterval(self._vnode.step_move)
					local scene = manager:getOrCreateScene(CW.CurMap.obj)
				end
			else
				self:set_move_step(0.01)
			end
		elseif key == "step_rotate_enable" or key == "step_rotate" then
			if self._vnode.step_rotate_enable then
				self:set_rotate_step(self._vnode.step_rotate)
			else
				self:set_rotate_step(1)
			end
		elseif key == "mode" then
			self:set_mode(self._vnode.mode)
		end
	end)

	Signal:subscribe(Receptor, Receptor.SIGNAL.ON_BIND_CHANGED, function(receptor)
		bind(self, receptor)
	end)

	bind(self, Receptor:binding())
end

function M:type()
	return self._type
end 
function M:switch(type)
	if self._type == type then
		return
	end

	self._type = type
	self._vnode["type"] = type
	local manager = CW:getSceneManager()
	if self._node then
		self._node:destroy()
		self._node = nil
	end
	
	if self._type == M.TYPE.TRANSLATE then
		self._node = GizmoTransformMove:create()
		self._node:setMoveInterval(self._step_move)
		manager:setGizmo(self._node)
	elseif self._type == M.TYPE.ROTATE then
		self._node = GizmoTransformRotate:create()
		self._node:setDegreeInterval(self._step_rotate)
		manager:setGizmo(self._node)
	elseif self._type == M.TYPE.SCALE then
		self._node = GizmoTransformScale:create()
		self._node:setScaleInterval(self._step_move)
		manager:setGizmo(self._node)
	else
		assert(self._type == M.TYPE.NONE)
		if self._node then
			self._node:destroy()
			self._node = nil
		end
	end

	if self._node and self._receptor then
		self._hold = false
		update(self)
	end
end

function M:set_move_step(step)
	if step <= 0 then
		step = 0.01
	end

	self._step_move = step
	if self._type == M.TYPE.TRANSLATE then
		self._node:setMoveInterval(step)
	end
end

function M:set_scale_step(step)
	if step <= 0 then
		step = 0.01
	end

	self._step_scale = step
	if self._type == M.TYPE.SCALE then
		self._node:setScaleInterval(step)
	end
end

function M:set_rotate_step(step)
	step = step % 360
	if step <= 0 then
		step = 1
	end

	self._step_rotate = step
	if self._type == M.TYPE.ROTATE then
		self._node:setDegreeInterval(step)
	end
end

function M:set_mode(mode)
	if self._mode == mode then
		return
	end
	self._mode = mode
	if self._node and self._receptor then
		update(self)
	end
end

function M:on_mouse_press(x, y, button, is_click)
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT or button == Input.MOUSE_BUTTON_TYPE.BUTTON_MIDDLE then
		return
	end

	if not self._receptor then
		return
	end

	assert(not self._hold)

	--从引擎获取被点击对象
	local manager = CW:getSceneManager()
	local light_id = manager:getTouchLightGizmo({x = x, y = y})
	local light = Map:query_instance(light_id)
	if light then
		self._lightnode = light:get_light_gizmo()
		self._hold = self._lightnode:touchBegin({x = x, y = y})
	else
		self._lightnode = nil
	end

	if self._node then
		self._hold = self._hold or self._node:touchBegin({ x = x, y = y })
	end

	return self._hold
end


function M:on_mouse_move(x, y)
	if not self._hold then
		return
	end

	if self._lightnode then
	   self._lightnode:touchMove({ x = x, y = y })
	end
	
	if self._node then
		self._node:touchMove({x = x, y = y})
	end

	return true
end


function M:on_mouse_release(x, y, button, is_click)
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT or button == Input.MOUSE_BUTTON_TYPE.BUTTON_MIDDLE then
		return
	end

	if not self._hold then
		return
	end

	self._hold = false

	if self._lightnode then
	   self._lightnode:touchEnded({ x = x, y = y })
	end

	if self._node then
		self._node:touchEnded({x = x, y = y})
	end

	if self._type == M.TYPE.ROTATE and self._mode == M.MODE.LOCAL then
		self:reset_rotation()
	end
	return true
end

function M:on_lost_focus()
	self._hold = false
end

function M:set_postion(pos)
	assert(self._node)
	self._node:setPosition(pos)
end

function M:getOffset()
	assert(self._node)
	return self._node:getOffset()
end

function M:position()
	assert(self._node)
	return self._node:getPosition()
end

function M:set_rotation(rotation)
	assert(self._node)
	self._node:setRotationXYZ(rotation)
end

function M:rotation()
	assert(self._node)
	return self._node:getRotationXYZ()
end

function M:reset_rotation()
	assert(self._node)
	local rotation = self._receptor:rotation()
	if rotation then
		self:set_rotation(rotation)
	end
	return rotation
end

---------------------------------------------------------------
local last = nil
local function diff(type, ...)
	if type == M.TYPE.TRANSLATE then
		local offset = ...
		last = last or { x = 0, y = 0, z = 0}
		local diff = {
			x = offset.x - last.x,
			y = offset.y - last.y,
			z = offset.z - last.z
		}
		return diff, offset
	elseif type == M.TYPE.SCALE then
		local offset = ...
		
		last = last or { x = 0, y = 0, z = 0}
		local diff = {
			x = offset.x - last.x,
			y = offset.y - last.y,
			z = offset.z - last.z
		}

		return diff, offset
	elseif type == M.TYPE.ROTATE then
		local degress = ...
		
		last = last or 0.0
		local diff = degress - last

		return diff, degress
	end
end

local function sign(number)
	return (number > 0 and 1) or (number == 0 and 0) or -1
end

gizmo_event_begin = function()
	local self = M
	last = nil
	if not self._receptor then
		return
	end

	if self._type == M.TYPE.TRANSLATE or self._type == M.TYPE.SCALE then
		local g_pos = self:position()
		local p_pos = offsetedCenter(self)
		if g_pos then
			if g_pos.x ~= p_pos.x or g_pos.y ~= p_pos.y or g_pos.z ~= p_pos.z then
				self:set_postion(p_pos) -- 处理鼠标按下瞬间的抖动
			end
		end
	end

	self._receptor:on_drag()
end

local modify_diff = function(self, diff)
	-- 移动的位移
	local diffX = diff.x;
	local diffY = diff.y;
	local diffZ = diff.z;

	-- print("diffX"..diff.x)
	-- print("diffY"..diff.y)
	-- print("diffZ"..diff.z)

	-- 和Gizmo关联的零件的位置
	local position = self._receptor:center();

	local x = position.x;
	local y = position.y;
	local z = position.z;

	local rotation = self:rotation();

	-- 当有旋转时不应用移动分度值
	if not (math.abs(rotation.x) > 0 or math.abs(rotation.y) > 0 or math.abs(rotation.z) > 0) then
		-- 当分度值为整数时，按照规则来进行移动
		if math.floor(self._step_move) >= self._step_move then
			if math.abs(diffX) > 0 then
				if math.floor(x) < x then
					-- 当移动分度值为整数时，比如1.0，则坐标的变化规则如下：
					-- 向X轴正方向移动1个单位，这时零件坐标为（X(A)=4，Y(A)=1.5，Z(A)=-15）
					-- X(A) = X +（1 - 小数部分）, Y(A)不变，Z(A) = Z - 小数部分
					local fracX = x - math.floor(x)
					local fracZ = z - math.floor(z)
					-- print("fracX:"..fracX)
					-- print("fracZ:"..fracZ)
					diff.x = self._step_move *  sign(diffX) - fracX;
					diff.z = fracZ * -sign(z);
					-- print("diff.x:"..diff.x)
					-- print("diff.z:"..diff.z)
					-- print("x:"..diffX)
				end
			end

			if math.abs(diffY) > 0 then
				if math.abs(y) < y then
					local fracX = x - math.floor(x)
					local fracY = y - math.floor(y)
					local fracZ = z - math.floor(z)
					-- print("fracX:"..fracX)
					-- print("fracZ:"..fracZ)
					diff.x = fracX * -sign(x);
					diff.z = fracZ * -sign(z);
					diff.y = self._step_move *  sign(diffY) - fracY;
				-- print("y:"..diffY)
				end 
			end

			if math.abs(diffZ) > 0 then
				if math.abs(z) < z then
					local fracX = x - math.floor(x)
					local fracZ = z - math.floor(z)
					-- print("fracX:"..fracX)
					-- print("fracZ:"..fracZ)
					diff.z = self._step_move *  sign(diffZ) - fracZ;
					diff.x = fracX * -sign(x);
				-- print("z:"..diffZ)
				end
			end
		end
	end

	return diff
end

--引擎设置光照节点时调用，进行类型检查
light_gizmo_event_move = function(attr, value, id)
	local self = M

	local op = Operator:operator("CHANGELIGHTANGLE")
	if op:check(self._receptor) then
		op:exec(self._receptor, attr, value, id)
	end
end


gizmo_event_move = function(...)
	local self = M

	if not self._receptor then
		return
	end

	if self._type == M.TYPE.TRANSLATE then
		local offset = ...
		local diff, curr = diff(self._type, offset)
		local op = Operator:operator("MOVE")

		-- diff = modify_diff(self, diff)
		-- for key, value in pairs (diff) do
		-- 	print (key, value)
		-- end

		if op:check(self._receptor) then
			op:exec(self._receptor, diff, self:position())
		end
		last = curr
		-- self:set_postion(self._receptor:center())-- 因为上层逻辑使其没法移动，所以需要同步
		self:set_postion(offsetedCenter(self))-- 因为上层逻辑使其没法移动，所以需要同步
	elseif self._type == M.TYPE.SCALE then
		local aix, scale, stretch = ...
		local diff, curr = diff(self._type, scale)
		local op = Operator:operator("SCALE")
		if op:check(self._receptor) then
			op:exec(self._receptor, aix, diff, stretch == 1, self:position())
			--local moveop = Operator:operator("MOVE")
			--moveop:exec(self._receptor, diff, self:position())
		end
		last = curr
		self:set_postion(self._receptor:gizmo_center())
	elseif self._type == M.TYPE.ROTATE then
		local aix_t, degress = ...
		local diff, curr = diff(self._type, degress)
		local op = Operator:operator("ROTATE")
		
		local aix = {
			x = aix_t == 1 and 1 or 0,
			y = aix_t == 2 and 1 or 0,
			z = aix_t == 3 and 1 or 0
		}
		if self._mode == M.MODE.LOCAL then
			local rotate = Quaternion.fromEulerAngleVector(self:rotation())
			local v3 = Vector3.fromTable(aix)
			aix = rotate * v3
		end
		if op:check(self._receptor) then
			op:exec(self._receptor, aix, diff)
		end
		last = curr
	end
end

gizmo_event_end = function()
	local self = M

	if not self._receptor then
		return
	end

	local op = Operator:operator("CONFIRM")
	if op:check(self._receptor) then
		Dialog:confirm(
			function()
				op:exec(self._receptor, true)
			end,
			function()
				op:exec(self._receptor, false)
			end
		)
	end

	update(self)

	self._receptor:on_drop()
end

return M
