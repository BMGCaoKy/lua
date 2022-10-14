local Def = require "we.def"
local Input = require "we.view.scene.input"
local Receptor = require "we.view.scene.receptor.receptor"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"

local Base = require "we.view.scene.picker.picker_base"

local LIMIT = 200

local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._from = nil
	self._to = nil
	self._node = nil
end

function M:on_bind()

end

function M:on_unbind()
	if self._node then
		IWorld:remove_box_widget(self._node)
		self._node = nil
	end
	self._from = nil
end

function M:on_mouse_press(x, y, button)

end

local function clamp(o, v, limit)
	if math.abs(v - o) <= limit then
		return v
	end

	return v > o and o + limit or o - limit
end

function M:on_mouse_move(x, y)
	if not self._from then
		return
	end
	assert(self._node)

	local node = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.BLOCK)
	if not node then
		return
	end

	self._to = {
		x = clamp(self._from.x, node.pos.x, LIMIT),
		y = clamp(self._from.y, node.pos.y, LIMIT),
		z = clamp(self._from.z, node.pos.z, LIMIT)
	}

	self._node:set_bound(Lib.boxBound(self._from, self._to))

	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end

	local node = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.BLOCK)
	if not node then
		return
	end

	if not self._from then
		self._from = Lib.copy(node.pos)
		self._to = Lib.copy(self._from)

		self._node = IWorld:create_box_widget(self._from, self._to)

		Receptor:unbind()

		return true
	end

	local receptor = Receptor:bind("chunk")
	receptor:attach(Lib.boxBound(self._from, self._to))

	self._from = nil
	self._to = nil

	IWorld:remove_box_widget(self._node)
	self._node = nil

	return true
end

function M:on_key_release(key)
	if key == Input.KEY_CODE.Key_Esc then
		if self._node then
			self:reset()
			return true	
		end
	end
end

function M:reset()
	if self._node then
		IWorld:remove_box_widget(self._node)
		self._node = nil
	end
	self._from = nil
	self._to = nil
end

function M:ephemerid()
	return true
end

return M
