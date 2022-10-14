local Input = require "we.view.scene.input"
local Receptor = require "we.view.scene.receptor.receptor"

local Vector3 = require "common.math.vector3"
local Quaternion = require "common.math.quaternion"
local User_data = require "we.user_data"
local Engine = require "we.engine"
local BM = Blockman.Instance()
local Map = require "we.map"
local nextPos = nil
local middle_button  = nil


local M = {}

function M:init()
	self._anchor = nil
end

local function wheel_step_move(wheel_step)
	local forward = wheel_step
	nextPos = BM:getViewerPos()
	if forward==0.0 then
		return false
	end
	local rotate = Quaternion.fromEulerAngle(BM:getViewerPitch(), BM:getViewerYaw(), 0)
	local diff = rotate * Vector3.fromTable({x = 0, y = 0, z = 1})


	local MOVE_SPEED = forward / 5 --slow down speed, slow down shaking

	nextPos.x = nextPos.x - diff.x * MOVE_SPEED
	nextPos.z = nextPos.z + diff.z * MOVE_SPEED
	nextPos.y = nextPos.y + diff.y * MOVE_SPEED
	Input:clean_wheel_step()
	return true
end

local function set_anchor(self, pos)
	self._anchor = pos
	if not pos then
		BM.gameSettings:setLockSlideScreen(false)
	else
		BM.gameSettings:setLockSlideScreen(true)
		BM:setViewerLookAt(self._anchor)
	end
end

function M:update(frame_time)
	local function check_step(forward, back)
		local step = 0
		if Input:check_key_press(forward) then
			step = step + 1
		end
		if Input:check_key_press(back) then
			step = step - 1
		end

		return step
	end

	local function axis_offset()
		local forward = check_step(Input.KEY_CODE.Key_W, Input.KEY_CODE.Key_S)
		local left = check_step(Input.KEY_CODE.Key_A, Input.KEY_CODE.Key_D)
		local up = check_step(Input.KEY_CODE.Key_E, Input.KEY_CODE.Key_Q)

		if forward == 0 and left == 0 and up == 0 then
			return 0.0, 0.0, 0.0
		end
		
		local yaw = math.rad(BM:getViewerYaw())
		local pitch = math.rad(BM:getViewerPitch())
		
		local orthogonality = math.abs(BM:getViewerPitch()) == 90 and forward ~= 0

		local f1 = orthogonality and 0 or math.sin(yaw)
		local f2 = orthogonality and 0 or math.cos(yaw)
		local f3 = math.sin(pitch)
		local off_x = left * f2 - forward * f1
		local off_z = forward * f2 + left * f1
		local off_y = up - forward * f3

		return off_x, off_y, off_z
	end

	local off_x, off_y, off_z = axis_offset()

	if off_x ~= 0.0 or off_y ~= 0.0 or off_z ~= 0.0 then
		local pos = BM:getViewerPos()
		local camera_move_speed = User_data:get_value("camera_move_speed") * frame_time / 33.333
		self:set_pos({
			x = pos.x + off_x * camera_move_speed,
			y = pos.y + off_y * camera_move_speed,
			z = pos.z + off_z * camera_move_speed
		})

		set_anchor(self, nil)	-- cancel anchor on move camera
	end

	local wheel_step = Input:get_wheel_step();
	local wheel_moved = false
	if wheel_step ~= 0 then
		wheel_moved = wheel_step_move(wheel_step)
		Engine:clear_wheel_value();
	end
	if wheel_moved then
		self:set_pos(nextPos)
		--同步到数据
		--Map:update(nextPos)
	end
end

function M:on_mouse_press(x, y, button)
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_MIDDLE  then
		middle_button = true
		set_anchor(self, nil)
	end
	return true
end

function M:on_mouse_release(x, y, button, is_click)
	middle_button = nil
	return true
end

function M:revolve(x, y, dx, dy)
	if not Input:check_mouse_press(Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT) then
		return
	end

	-- 绕 y 轴旋转
	if dx ~= 0 then
		local rotate = Quaternion.rotateAxis({x = 0, y = 1, z = 0}, -dx * 0.5)

		local pos = BM:getViewerPos()
		pos.x = pos.x - self._anchor.x
		pos.y = pos.y - self._anchor.y
		pos.z = pos.z - self._anchor.z

		if math.abs(pos.x) < 0.001 and math.abs(pos.z) < 0.001 then
			pos.x = pos.x + 0.002
			pos.z = pos.z + 0.002
		end

		local v3 = Vector3.fromTable(pos)
		pos = rotate * v3

		pos.x = pos.x + self._anchor.x
		pos.y = pos.y + self._anchor.y
		pos.z = pos.z + self._anchor.z

		self:set_pos(pos)
	end

	-- 绕水平轴旋转
	if dy ~= 0 then
		local pos = BM:getViewerPos()

		pos.x = pos.x - self._anchor.x
		pos.y = pos.y - self._anchor.y
		pos.z = pos.z - self._anchor.z

		local rotate = Quaternion.rotateAxis({
			x = -pos.z,
			y = 0,
			z = pos.x
			}, dy * 0.5)


		local npos = rotate * Vector3.fromTable(pos)
		if npos.x * pos.x > 0 and npos.z * pos.z > 0 then
			npos.x = npos.x + self._anchor.x
			npos.y = npos.y + self._anchor.y
			npos.z = npos.z + self._anchor.z

			self:set_pos(npos)
		end
	end

	BM:setViewerLookAt(self._anchor)
	return true
end

function M:translate(x, y, dx, dy)
	-- default angle viewer pitch 15 + 30
	local pitch = BM:getViewerPitch()
	local yaw =  -BM:getViewerYaw()
	local cw = 40 / User_data:get_value("viewport_width") 
	local ch = 20 / User_data:get_value("viewport_height")
	local rotate = Quaternion.fromEulerAngle(pitch,yaw,0)
	local offset = rotate * Vector3.fromTable({x = dx * cw, y = dy * ch, z = 0})
	local pos = BM:getViewerPos()
	
	self:set_pos({
		x = pos.x + offset.x,
		y = pos.y + offset.y,
		z = pos.z + offset.z
	})
end


function M:on_mouse_move(x, y, dx, dy)
	if self._anchor then
		return self:revolve(x, y, dx, dy)
	elseif middle_button then
		return self:translate(x, y, dx, dy)
	end
end

function M:on_key_press(key)

end

function M:on_key_release(key)
	if key == Input.KEY_CODE.Key_F then
		local receptor = Receptor:binding()
		if not receptor then
			return
		end

		local bound = receptor:bound()
		if not bound then
			return
		end

		self:focus(bound)

		return true
	end
end

function M:set_pos(pos, yaw, pitch)
	BM:setViewerPos(
		pos,
		yaw or BM:getViewerYaw(), 
		pitch or BM:getViewerPitch(),
	1)
end

function M:set_active_camera_pos(pos, yaw, pitch)
	Camera.getActiveCamera():setPosition(pos)
end

function M:get_active_camera_direction()
	return Camera.getActiveCamera():getDirection()
end

function M:get_view_pos()
	return BM:getViewerPos()
end

function M:focus(bound)
	local center = {
		x = bound.min.x + (bound.max.x - bound.min.x) / 2,
		y = bound.min.y + (bound.max.y - bound.min.y) / 2,
		z = bound.min.z + (bound.max.z - bound.min.z) / 2,
	}

	do
		local yaw, pitch = BM:getViewerYaw(), BM:getViewerPitch()
		local size = (bound.max.x - bound.min.x) ^ 2 + 
					 (bound.max.y - bound.min.y) ^ 2 +
					 (bound.max.z - bound.min.z) ^ 2

		local dist = size ^ 0.5
		local ryaw, rpitch = math.rad(yaw), math.rad(pitch)

		local hl = dist * math.cos(rpitch)
		self:set_pos({
			x = center.x + hl * math.sin(ryaw),
			y = center.y + dist * math.sin(rpitch),
			z = center.z - hl * math.cos(ryaw)
		})
	end

	set_anchor(self, center)
end

return M
