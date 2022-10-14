local Def = require "we.def"
local Signal = require "we.signal"
local Input = require "we.view.scene.input"
local State = require "we.view.scene.state"

local M = {}

M.SIGNAL = {
	ON_BIND_CHANGED = "ON_BIND_CHANGED"
}

M.MODE = {
	RECT		= "RECT",
	BOX			= "BOX"
}

M.MODE_ID = {
	NONE		= 0,
	RECT		= 1,
	BOX			= 2
}

local id2name = {
	[M.MODE_ID.RECT] = M.MODE.RECT,
	[M.MODE_ID.BOX] = M.MODE.BOX
}

local name2id = {
	[M.MODE.RECT] = M.MODE_ID.RECT,
	[M.MODE.BOX] = M.MODE_ID.BOX,
}

function M:init()
	self._picker = nil
	self._list = {}

	self._vnode = State:picker()
	local function bind(id)
		if id == M.MODE_ID.NONE then
			self:unbind()
		else
			local mode = assert(id2name[id], id)
			self:bind(mode)
		end	
	end

	-- monitor
	Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_ASSIGN, function(key)
		if key == "mode" then
			local id = self._vnode["mode"]
			bind(id)
		else
			assert(false)
		end
	end)

	bind(self._vnode["mode"])
end

function M:bind(mode)
	if not self._list[mode] then
		local class = require(string.format("%s.picker_%s", "we.view.scene.picker", string.lower(mode)))
		assert(class, string.format("class %s is not exist", mode))

		local obj = Lib.derive(class)
		obj:init(mode)

		self._list[mode] = obj
	end

	local picker = assert(self._list[mode])
	if self._picker == picker then
		return
	end
	
	if self._picker then
		self._picker:on_unbind()
		self._picker = nil
	end

	self._picker = picker
	self._picker:on_bind()

	self._vnode["mode"] = assert(name2id[mode], mode)

	Signal:publish(self, M.SIGNAL.ON_BIND_CHANGED, self._picker)

	return self._picker
end

function M:unbind()
	if not self._picker then
		return
	end

	self._picker:on_unbind()
	self._picker = nil

	self._vnode["mode"] = M.MODE_ID.NONE

	Signal:publish(self, M.SIGNAL.ON_BIND_CHANGED, nil)
end

function M:binding()
	return self._picker
end

local function process_event(self, event, ...)
	if not self._picker then
		return false
	end

	local proc = assert(self._picker[event], string.format("%s", event))
	return proc(self._picker, ...)
end

function M:on_mouse_press(x, y, button)
	if process_event(self, "on_mouse_press", x, y, button) then
		return true
	end
end

function M:on_mouse_move(x, y)
	if process_event(self, "on_mouse_move", x, y) then
		return true
	end
end

function M:on_hover_unlock(x,y,button)
	if process_event(self,"on_hover_unlock",x,y,button)then
		return true
	end
end

function M:on_mouse_release(x, y, button, is_click)
	if process_event(self, "on_mouse_release", x, y, button, is_click) then
		return true
	end
end  

function M:on_key_press(key)
	if process_event(self, "on_key_press", key) then
		return true
	end
end

function M:on_key_release(key)
	if not self._picker then
		return false
	end

	if process_event(self, "on_key_release", key) then
		return true
	end

	if key == Input.KEY_CODE.Key_Esc then
		if self._picker:ephemerid() then
			self:bind(M.MODE.RECT)
			return true
		end
	end
end

function M:on_lost_focus()
	if process_event(self, "on_lost_focus") then
		return true
	end
end

return M
