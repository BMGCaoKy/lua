local Input = require "we.view.scene.input"
local Receptor = require "we.view.scene.receptor.receptor"
local Camera = require "we.view.scene.camera"

local M = {}

local EXCLUDE_AREAS				= 0
local INDICATOR_BUTTON_LEFT		= 1
local INDICATOR_BUTTON_RIGHT	= 2

function M:init()
	self._press = EXCLUDE_AREAS
	self._is_rotate = 0
end

function M:update(frame_time)
	if self._is_rotate == 0 then
		return 
	end 

	-- 0 is stand for rotating 
	-- 1 is stand for rotated
	local state = CameraIndicator.Instance():isRotateOver()
	if state == 1 then 
		return 
	end 

	local receptor = Receptor:binding()
	if not receptor then
		return
	end
	local bound = receptor:bound()
	if not bound then
		return
	end
	Camera:focus(bound)
end 
function M:on_mouse_press(x, y, button)
	local b = CameraIndicator.Instance():onMouseDown({x = x, y = y})
	if b == 1 then 
		if button == Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT  then
			self._press = INDICATOR_BUTTON_LEFT
		else 
			self._press = INDICATOR_BUTTON_RIGHT
		end 
		return true -- 跳过执行
	else 
		self._press = EXCLUDE_AREAS
		return false 
	end 
end

function M:on_mouse_move(x, y, dx, dy)  -- note that process in engine, not lua 
	if self._press == EXCLUDE_AREAS then 
		return false 
	else 
		return true
	end 
end

function M:on_mouse_release(x, y, button, is_click)
	if self._press == INDICATOR_BUTTON_LEFT then
		self._is_rotate = CameraIndicator.Instance():onMouseUp({x = x, y = y})
		return true
	elseif self._press == INDICATOR_BUTTON_RIGHT then 
		return true
	else 
		return false
	end 
end

function M:show_camera_indicator(show_camera_indicator)
	CameraIndicator.Instance():setShowOrNot(show_camera_indicator)
end

return M