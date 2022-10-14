local Recorder = require "we.gamedata.recorder"
local BM = Blockman.Instance()

local M = {}

local CLICK_DIST = 4

M.EVENT_TYPE = {

	-- mouse
	MOUSE_PRESS				= "EVENT_MOUSE_PRESS",
	MOUSE_RELEASE			= "EVENT_MOUSE_RELEASE",
	MOUSE_MOVE				= "EVENT_MOUSE_MOVE",
	MOUSE_DOUBLE_CLICK		= "EVENT_MOUSE_DOUBLE_CLICK",

	-- keybord
	KEY_PRESS				= "EVENT_KEY_PRESS",
	KEY_RELEASE				= "EVENT_KEY_RELEASE"

}

M.MOUSE_BUTTON_TYPE = {
	BUTTON_NONE				= 0,
	BUTTON_LEFT				= 1,
	BUTTON_RIGHT			= 2,
	BUTTON_MIDDLE			= 4
}

M.KEY_MODIFIER = {
	KEY_MODIFIER_SHIFT		= 1,
	KEY_MODIFIER_CTRL		= 2,
	KEY_MODIFIER_ALT		= 4
}

M.KEY_CODE = {
	["Key_A"] = 65,
	["Key_B"] = 66,
	["Key_C"] = 67,
	["Key_D"] = 68,
	["Key_E"] = 69,
	["Key_F"] = 70,
	["Key_G"] = 71,
	["Key_H"] = 72,
	["Key_I"] = 73,
	["Key_J"] = 74,
	["Key_K"] = 75,
	["Key_L"] = 76,
	["Key_M"] = 77,
	["Key_N"] = 78,
	["Key_O"] = 79,
	["Key_P"] = 80,
	["Key_Q"] = 81,
	["Key_R"] = 82,
	["Key_S"] = 83,
	["Key_T"] = 84,
	["Key_U"] = 85,
	["Key_V"] = 86,
	["Key_W"] = 87,
	["Key_X"] = 88,
	["Key_Y"] = 89,
	["Key_Z"] = 90,
	["Key_0"] = 48,
	["Key_1"] = 49,
	["Key_2"] = 50,
	["Key_3"] = 51,
	["Key_4"] = 52,
	["Key_5"] = 53,
	["Key_6"] = 54,
	["Key_7"] = 55,
	["Key_8"] = 56,
	["Key_9"] = 57,
	["Key_F1"] = 112,
	["Key_F2"] = 113,
	["Key_F3"] = 114,
	["Key_F4"] = 115,
	["Key_F5"] = 116,
	["Key_F6"] = 117,
	["Key_F7"] = 118,
	["Key_F8"] = 119,
	["Key_F9"] = 120,
	["Key_F10"] = 121,
	["Key_F11"] = 122,
	["Key_F12"] = 123,
	["Key_BackSpace"] = 8,
	["Key_Tab"] = 9,				-- 收不到消息
	["Key_Clear"] = 12,
	["Key_Enter"] = 13,
	["Key_Shift"] = 16,
	["Key_Control"] = 17,
	["Key_Alt"] = 18,				-- 一次只有press，下次只有 release
	["Key_Cape_Lock"] = 20,
	["Key_Esc"] = 27,				-- 只有 release 没有press
	["Key_Spacebar"] = 32,
	["Key_Page_Up"] = 33,
	["Key_Page_Down"] = 34,
	["Key_End"] = 35,
	["Key_Home"] = 36,
	["Key_Left_Arrow"] = 37,
	["Key_Up_Arrow"] = 38,
	["Key_Right_Arrow"] = 39,
	["Key_Down_Arrow"] = 40,
	["Key_Insert"] = 45,
	["Key_Delete"] = 46,
	["Key_Num_Lock"] = 144,
	["Key_Colon"] = 186,
	["Key_Plus"] = 187,
	["Key_Comma"] = 188,
	["Key_Minus"] = 189,
	["Key_Period"] = 190,
	["Key_Slash"] = 191,
	["Key_Backquote"] = 192,
	["Key_BracketLeft"] = 219,
	["Key_Backslash"] = 220,
	["Key_BracketRight"] = 221
}

function M:init()
	for k, v in pairs(M.KEY_CODE) do
		M.KEY_CODE[v] = k
	end

	self._key_state = {}
	self._mouse_state = {
		last_pos = {x = 0, y = 0},
		is_click = nil
	}
	self._recording = 0
	self._wheel_step = 0
end


local function process_event(self, event, ...)
	local modules = {
	    {require "we.view.scene.camera_indicator"},
		{require "we.view.scene.selector.selector", true},
		{require "we.view.scene.gizmo", true},
		{require "we.view.scene.placer.placer", true},
		{require "we.view.scene.receptor.receptor"},
		{require "we.view.scene.picker.picker"},
		{require "we.view.scene.camera", true},
	}

	local State = require "we.view.scene.state"
	local enable = State:enable()

	for i, module in ipairs(modules) do
		if enable or module[2] then
			local rcvr = module[1]
			local proc = rcvr[event]
			if proc then
				local ok, ret = xpcall(proc, debug.traceback, rcvr, ...)
				if not ok then
					print(string.format("process %s error:\n %s", event, ret))
					return false
				elseif ret then
					return true,ret
				end
			end
		end
	end
end

function M:on_mouse_press(x, y, button)
	if self._recording == 0 then
		Recorder:start()
	end

	if (self._mouse_state[1] and button == 2) then  -- 过滤情况： 拖拽物体时，同时右键按下
	    return
	end 

	self._recording = self._recording + 1
	
	self._mouse_state[button] = true
	self._mouse_state["last_pos"] = {x = x, y = y}
	self._mouse_state["is_click"] = true
	BM:resetPrevMousePos()	-- RenderWorld 中记录了 m_preMousePos，重新点击应该清除它，否则可能造成镜头跳动，比如编辑器卡住了，这个时候确拖动了鼠标
	return process_event(self, "on_mouse_press", x, y, button)
end

function M:on_mouse_move(x, y)
	if self._mouse_state["is_click"] then
		if (self._mouse_state["last_pos"].x - x) ^ 2 + (self._mouse_state["last_pos"].y - y) ^ 2 > CLICK_DIST then
			self._mouse_state["is_click"] = false
		end
	end

	if not self._mouse_state["is_click"] then
		local offx, offy = x - self._mouse_state["last_pos"].x, y - self._mouse_state["last_pos"].y
		self._mouse_state["last_pos"] = {x = x, y = y}
		return process_event(self, "on_mouse_move", x, y, offx, offy)
	end
end

function M:on_hover_remain(x,y)
	return process_event(self,"on_hover_remain",x,y)
end

function M:on_hover_unlock(x,y)
	local ret= process_event(self,"on_hover_unlock",x,y)
	BM:resetPrevMousePos()
	return ret
end 


local function process_record(self)
	Recorder:stop()
end

function M:on_mouse_release(x, y, button)
	if not self._mouse_state[button] then
		return
	end

	local is_click = self._mouse_state["is_click"]
	self._mouse_state[button] = nil
	self._mouse_state["is_click"] = nil
	self._mouse_state["last_pos"] = {x = x, y = y}

	if self._recording > 0 then
		local ret = process_event(self, "on_mouse_release", x, y, button, is_click)	-- may be open menu
		if self._recording > 0 then	-- 如果 on_mouse_release 弹出了菜单，会造成 on_lost_focus，从而 self._recording 变成 0
			self._recording = self._recording - 1
			if self._recording == 0 then
				process_record(self)
			end
		end
		return ret
	end
end

function M:on_mouse_wheel(wheelValue)
	self._wheel_step = wheelValue
	return process_event(self, "on_mouse_wheel",wheelValue)
end

function M:on_key_press(key)
	Recorder:start()
	self._key_state[key] = true
	local ret = process_event(self, "on_key_press", key)
	Recorder:stop()
	return ret
end

function M:on_key_release(key)
	Recorder:start()
	self._key_state[key] = nil
	local ret = process_event(self, "on_key_release", key)
	Recorder:stop()
	return ret
end

function M:on_lost_focus()
	self._key_state = {}
	self._mouse_state = {last_pos = self._mouse_state.last_pos}
	process_event(self, "on_lost_focus")
	if self._recording > 0 then
		self._recording = 0
		process_record(self)
	end
end

function M:check_mouse_press(button)
	return self._mouse_state[button]
end

function M:check_key_press(key)
	return self._key_state[key]
end

function M:mouse_pos()
	return self._mouse_state.pos
end

function M:get_wheel_step() 
	return self._wheel_step
end

function M:clean_wheel_step()
	self._wheel_step = 0
end

return M
