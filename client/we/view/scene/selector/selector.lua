local Def = require "we.def"
local Signal = require "we.signal"
local Input = require "we.view.scene.input"
local State = require "we.view.scene.state"

local M = {}

M.SIGNAL = {
	ON_BIND_CHANGED = "ON_BIND_CHANGED"
}

function M:init()
	self._selector = nil
	self._list = {}
	self._cancel = nil

	self._vnode = State:selector()
	Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_ASSIGN, function(key)
		if key == "mode" then
			local mode = self._vnode.mode
			if mode == "" then
				self:unbind()
			else
				self:bind(mode)
			end
		elseif key == "data" then
			local data = self._vnode.data
			local selector = self:binding()
			if selector then
				local params = {}
				for param in string.gmatch(data, "[^,]+") do
					table.insert(params, param)
				end
				selector:select(table.unpack(params))
			end
		end
	end)
end

function M:bind(mode)
	if not self._list[mode] then
		local class = require(string.format("%s.selector_%s", "we.view.scene.selector", string.lower(mode)))
		assert(class, string.format("class %s is not exist", mode))

		local obj = Lib.derive(class)
		obj:init()

		self._list[mode] = obj
	end

	local selector = assert(self._list[mode])
	if self._selector == selector then
		return self._selector
	end

	if self._selector then
		self._selector:on_unbind()
		self._selector = nil
	end

	self._selector = selector
	self._selector:on_bind()

	self._vnode["mode"] = mode
	self._vnode["data"] = ""

	self._cancel = Signal:subscribe(self._selector, self._selector.SIGNAL.SELECT_FINISH, function()
		self:unbind()
	end)

	Signal:publish(self, M.SIGNAL.ON_BIND_CHANGED, self._selector)

	return self._selector
end

function M:unbind(clear)
	if not self._selector then
		return
	end

	self._selector:on_unbind(clear)
	self._selector = nil

	self._vnode["mode"] = ""
	self._vnode["data"] = ""

	if self._cancel then
		self._cancel()
		self._cancel = nil
	end
	Signal:publish(self, M.SIGNAL.ON_BIND_CHANGED, nil)
end

function M:binding()
	return self._selector
end

local function process_event(self, event, ...)
	if not self._selector then
		return false
	end

	local proc = assert(self._selector[event], string.format("%s", event))
	return proc(self._selector, ...)
end

function M:on_mouse_press(x, y, button)
	if not self._selector then
		return false
	end

	process_event(self, "on_mouse_press", x, y, button)
	return true
end

function M:on_mouse_move(x, y)
	if not self._selector then
		return false
	end

	process_event(self, "on_mouse_move", x, y)
	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if not self._selector then
		return false
	end

	if is_click then
		if button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT then
			self:unbind()
			return true
		end
	end

	process_event(self, "on_mouse_release", x, y, button, is_click)
	return true
end

function M:on_key_press(key)
	if not self._selector then
		return false
	end

	process_event(self, "on_key_press", key)
	return true
end

function M:on_key_release(key)
	if not self._selector then
		return false
	end

	if process_event(self, "on_key_release", key) then
		return true
	end

	if key == Input.KEY_CODE.Key_Esc then
		self:unbind()
		return true
	end

	return true
end

return M
