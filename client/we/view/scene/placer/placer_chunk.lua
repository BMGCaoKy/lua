local Def = require "we.def"
local Input = require "we.view.scene.input"
local Cmd = require "we.view.scene.cmd.cmd"
local Utils = require "we.view.scene.utils"
local Receptor = require "we.view.scene.receptor.receptor"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"

local Base = require "we.view.scene.placer.placer_base"
local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._chunk = nil
	self._node = nil
end

function M:on_bind()

end

function M:on_unbind()
	if self._node then
		IWorld:remove_chunk_widget(self._node)
		self._node = nil
	end

	self._chunk = nil
end

function M:select(chunk)
	self._chunk = assert(chunk)
	if self._node then
		IWorld:remove_chunk_widget(self._node)
		self._node = nil
	end

	self._node = IWorld:create_chunk_widget(self._chunk)
end

function M:on_mouse_press(x, y, button)
	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end

	if not self._node then
		return
	end

	return true
end

function M:on_mouse_move(x, y)
	if not self._node then
		return
	end

	local node = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.BLOCK)
	if not node then
		return
	end
	local pos = Lib.v3add(node.pos, node.side or {x=0,y=1,z=0})
	self._node:set_pos(
		Utils.calc_min_pos(pos, self._node:get_size(),	node.side)
	)
end

function M:on_mouse_release(x, y, button, is_click)
	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end

	if not self._node then
		return
	end

	local min = self._node:get_pos()
	Cmd:chunk_set(min, self._chunk)
end

return M
