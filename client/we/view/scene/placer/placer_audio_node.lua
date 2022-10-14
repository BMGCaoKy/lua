local Meta = require "we.gamedata.meta.meta"

local Map = require "we.view.scene.map"
local IWorld = require "we.engine.engine_world"

local IInstance = require "we.engine.engine_instance"
local IScene = require "we.engine.engine_scene"

local Receptor = require "we.view.scene.receptor.receptor"
local Placer = require "we.view.scene.placer.placer"
local Module = require "we.gamedata.module.module"

local Base = require "we.view.scene.placer.placer_base"
local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self, mode)

	self._item = nil
end

function M:on_bind()
end

function M:on_unbind()
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
end

function M:place(x, y)
	local ins = Map:new_instance(
		Meta:meta("Instance_AudioNode"):ctor({
			name = "Sound",
			sound = {selector = self._item,asset = self._item},
			is_relative = false
		})
	)
	local node = ins:node()
	local bool = self:on_Terrain(x, y) -- check is on terrain
	IScene:drag_parts({ node }, x, y) -- drag to scene set pos
	if bool == false then
		local pos = IInstance:position(node) -- get ins pos
		pos["x"] = 0.0
		pos["y"] = 1.50
		pos["z"] = 0.0
		node:setPosition(pos)
	end
	-- update relative position
	--node:setLocalPosition({x = 0, y = 0, z = 0})
	--local position = node:getPosition()
	--ins:vnode()["position"] = position
	-- update size
	local size = node:getSize()
	ins:vnode()["size"] = size
	-- select obj
	Receptor:select("instance", {node})
	Placer:unbind()
end

return M
