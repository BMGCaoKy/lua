local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"

local Input = require "we.view.scene.input"
local Map = require "we.view.scene.map"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local Receptor = require "we.view.scene.receptor.receptor"
local Placer = require "we.view.scene.placer.placer"

local Base = require "we.view.scene.placer.placer_base"

local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._item = nil
	self._node = nil
	self._cancel = nil
end

function M:on_bind()

end

function M:on_unbind()
	if self._node then
		IWorld:remove_instance(self._node)
		self._node = nil
	end
	self._item = nil
end

function M:select(name)
	if self._item == name then
		return
	end
	if not name or name == "" then
		return
	end
	self._item = name
	if self._node then
		IWorld:remove_instance(self._node)
		self._node = nil
	end
	if not self._node then
		self._node = assert(IWorld:create_instance({ class = "DropItem", config = name }))
	end
	IInstance:set_selectable(self._node, false)

	if self._cancel then
		self._cancel()
		self._cancel = nil
	end

	self._cancel = Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_DEL, function(module, item)
		if module ~= "item" then
			return
		end
		item = "myplugin/" .. item
		if item == name then
			local Placer = require "we.view.scene.placer.placer"
			Placer:unbind()
			if self._cancel then
				self._cancel()
				self._cancel = nil
			end
		end
	end)
end

function M:on_mouse_move(x, y)
	if not self._node then
		return
	end
	IScene:drag_parts({ self._node }, x, y)

	return true
end

function M:on_mouse_press(x, y, button)
	if not self._node then
		return
	end

	return true
end

function M:on_mouse_release(x, y, button, is_click)
	if not self._node then
		return
	end
	local point2scene = IScene:point2scene({ x = x, y = y })
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		local ins = Map:new_instance(
						Meta:meta("Instance_DropItem"):ctor({
							config = self._item,
							position = IInstance:position(self._node)
						}
						)
					)
		Receptor:select("instance", {ins:node()})
	end

	return true
end

function M:place(x, y)
	local ins = Map:new_instance(
					Meta:meta("Instance_DropItem"):ctor({
						config = self._item,
						position = IInstance:position(self._node)
					}
					)
				)
	local bool = self:on_Terrain(x, y)
	IScene:drag_parts({ ins:node() }, x, y)
	local pos = IInstance:position(ins:node())
	if bool == false then
		pos["x"] = 0.0
		pos["y"] = 1.0
		pos["z"] = 0.0
		ins:node():setPosition(pos)
	end
	local size = ins:node():getSize()
	ins:vnode()["size"] = size
	Receptor:select("instance", {ins:node()})
	Placer:unbind()
end

return M
