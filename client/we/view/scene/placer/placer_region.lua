local Meta = require "we.gamedata.meta.meta"

local Map = require "we.view.scene.map"
local Input = require "we.view.scene.input"
local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"

local Base = require "we.view.scene.placer.placer_base"
local State = require "we.view.scene.state"
local Receptor = require "we.view.scene.receptor.receptor"
local Gizmo = require "we.view.scene.gizmo"
local Placer = require "we.view.scene.placer.placer"
local Module = require "we.gamedata.module.module"

local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._item = nil
	self._node = nil
	self._parent = nil
end

function M:on_bind()

end

function M:on_unbind()
	if self._node then
		IWorld:remove_instance(self._node)
		self._node = nil
	end
end

function M:select(name)
	if not self._node then
		self._node = assert(IWorld:create_instance({ class = "RegionPart" }))
	end
end

function M:on_mouse_move(x, y)
	if not self._node then
		return
	end
	IScene:drag_parts({ self._node }, x, y)

	return true
end

local function create_region(node, parent)
	local region_cfg = GenUuid()
	local meta_cfg = Meta:meta("Instance_RegionPart"):ctor({
		position = IInstance:position(node),
		cfgName = "myplugin/"..region_cfg
	}) 
	local region = not parent and Map:new_instance(meta_cfg) or parent:new_child(meta_cfg)
	local module_region = Module:module("region")
	module_region:new_item(region_cfg)
	return region
end

function M:on_mouse_release(x, y, button, is_click)
	if not self._node then
		return
	end
	if button == Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		local region = create_region(self._node, self._parent)
		self._parent = nil
		local receptor = Receptor:binding()
		if receptor then
			Receptor:unbind()
		end
		Receptor:select("instance", {region:node()})
		State:gizmo()["type"] = Gizmo.TYPE.SCALE
		Placer:unbind()
	end

	return true
end

function M:set_parent(instance)
	self._parent = instance
end


return M
