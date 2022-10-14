local Def = require "we.def"
local Mapping = require "we.gamedata.module.mapping"
local Cmd = require "we.view.scene.cmd.cmd"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IBlock = require "we.engine.engine_block"

local Base = require "we.view.scene.placer.placer_base"

local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)
	
	self._node = nil
end

function M:on_bind()
	self._node = IWorld:create_block_widget(0)
end

function M:on_unbind()
	if self._node then
		IWorld:remove_block_widget(self._node)
		self._node = nil
	end
end

function M:on_mouse_press(x, y, button)
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

	self._node:set_pos(node.pos)

	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if not self._node then
		return
	end

	Cmd:block_set({
		{ pos = self._node:get_pos() }
	})

	return true
end

return M
