local Def = require "we.def"
local Mapping = require "we.gamedata.module.mapping"

local Input = require "we.view.scene.input"
local Cmd = require "we.view.scene.cmd.cmd"
local Receptor = require "we.view.scene.receptor.receptor"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IBlock = require "we.engine.engine_block"

local Base = require "we.view.scene.placer.placer_base"

local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._item = nil
	self._node = nil
end

function M:on_bind()

end

function M:on_unbind()
	if self._node then
		IWorld:remove_block_widget(self._node)
		self._node = nil
	end
	self._item = nil
end

function M:select(item)
	if not item or item == "" then
		return
	end
	if self._item == item then
		return
	end

	if self._node then
		IWorld:remove_block_widget(self._node)
		self._node = nil
	end

	local id = assert(Mapping:name2id("block", item), tostring(item))
	self._node = IWorld:create_block_widget(id)

	self._item = item
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

	self._node:set_pos(
		Lib.v3add(node.pos, node.side or {x = 0, y = 1, z = 0})
	)

	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if not self._node then
		return
	end

	if not is_click then
		return
	end

	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end

	Cmd:block_set({
		{pos = self._node:get_pos(), id = Mapping:name2id("block", self._item) }
	})
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	Receptor:select("block", {self._node:get_pos()})
	return true
end

return M
