local Def = require "we.def"
local Signal = require "we.signal"
local Input = require "we.view.scene.input"
local State = require "we.view.scene.state"
local User_data = require "we.user_data"

local M = {}

M.SIGNAL = {
	ON_BIND_CHANGED = "ON_BIND_CHANGED"
}

function M:init()
	self._placer = nil
	self._list = {}

	self._vnode = State:placer()
	
	local part_place_settings = User_data:get_value("part_place_settings")
	if part_place_settings then
		State:set_part_place_settings(part_place_settings)
	end
	Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_ASSIGN, function(key)
		if key == "mode" then
			local mode = self._vnode.mode
			if mode == "" then
				self:unbind()
			else
				local isEdittingCollision,id=State:get_custom_collision_editing()
				if isEdittingCollision and mode=="part" then
					self:bind(mode)
				elseif not isEdittingCollision then
					self:bind(mode)
				end
			end
		elseif key == "data" then
			local data = self._vnode.data
			if self._placer then
				local params = {}
				for param in string.gmatch(data, "[^,]+") do
					table.insert(params, param)
				end
				self._placer:select(table.unpack(params))
			end
		end
	end)
end

function M:bind(mode)
	if not self._list[mode] then
		local placer_path=string.format("%s.placer_%s", "we.view.scene.placer", string.lower(mode))
		local class = require(placer_path)
		assert(class, string.format("class %s is not exist", mode))

		local obj = Lib.derive(class)
		obj:init(mode)

		self._list[mode] = obj
	end

	local placer = assert(self._list[mode])
	if self._placer == placer then
		return self._placer
	end

	if self._placer then
		self._placer:on_unbind()
		self._placer = nil
	end

	self._placer = placer
	self._placer:on_bind()

	self._vnode["mode"] = mode
	self._vnode["data"] = ""
	
	Signal:publish(self, M.SIGNAL.ON_BIND_CHANGED, self._placer)

	return self._placer
end

function M:unbind()
	if not self._placer then
		return
	end

	self._placer:on_unbind()
	self._placer = nil

	self._vnode["mode"] = ""
	self._vnode["data"] = ""

	Signal:publish(self, M.SIGNAL.ON_BIND_CHANGED, nil)
end

function M:binding()
	return self._placer
end

local function process_event(self, event, ...)
	if not self._placer then
		return false
	end

	local proc = assert(self._placer[event], string.format("%s", event))
	return proc(self._placer, ...)
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

function M:on_mouse_release(x, y, button, is_click)
	if not self._placer then
		return false
	end

	if is_click then
		if button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT then
			self:unbind()
			return true
		end
	end
	
	if process_event(self, "on_mouse_release", x, y, button, is_click) then
		return true
	end
end

function M:on_key_press(key)
	if key == Input.KEY_CODE.Key_V and Input:check_key_press(Input.KEY_CODE.Key_Control) then
		local placer = self._list["instance"]
		if placer:check_select() then
			self:bind("instance")
			return true
		end
	end
	if process_event(self, "on_key_press", key) then
		return true
	end
end

function M:on_key_release(key)
	if not self._placer then
		return false
	end

	if process_event(self, "on_key_release", key) then
		return true
	end

	if key == Input.KEY_CODE.Key_Esc then
		self:unbind()
		return true
	end
end

return M
