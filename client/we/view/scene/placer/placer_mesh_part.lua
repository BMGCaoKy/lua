local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"

local Map = require "we.view.scene.map"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"

local Base = require "we.view.scene.placer.placer_base"
local Receptor = require "we.view.scene.receptor.receptor"
local IInstance = require "we.engine.engine_instance"
local Placer = require "we.view.scene.placer.placer"
local Part = require "we.view.scene.logic.part"
local Module = require "we.gamedata.module.module"
local GameSetting = require "we.gamesetting"

local BM = Blockman.Instance()
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
		self._node = assert(IWorld:create_instance({ class = "MeshPart", config = name }))
	end
	IInstance:set_selectable(self._node, false)
end

local function calcInstancePos(part)
	local pos = IInstance:position(part)
	local box = part:getWorldAABB(true)
	pos.y = pos.y + (box[3].y - box[2].y) / 2
	return pos
end

function M:place(x, y)
	local props = Part:material_property("part_suliao.tga")
	local density, restitution, friction = props[1], props[2], props[3]
	local btsKey = GenUuid()

	local file_name = ""
	if self._item then
		file_name = Lib.toFileName(self._item)
	end
	local ins = Map:new_instance(Meta:meta("Instance_MeshPart"):ctor({
		mesh_selector = {selector = self._item,asset = self._item},
		mesh = self._item,
		density = density,
		restitution = restitution,
		friction = friction,
		btsKey = btsKey,
		name = file_name,
		useAnchor = GameSetting:get_useAnchor(),
		batchType = GameSetting:get_batchType()
	}))
	local module_part = Module:module("meshpart")
	module_part:new_item(btsKey)

	IScene:drag_parts({ ins:node() }, x, y)
	local bool = self:on_Terrain(x, y)
	local pos = calcInstancePos(ins:node())
	if not bool then
		--pos.y = pos.y + 1 -- 如果是3D地形，则出错
		local rayLength = 25
		pos = BM:getScreenToScenePos({x=x , y=y}, rayLength)
	end
	ins:node():setPosition(pos)
	ins:vnode()["massCenter"] = pos
	local size = ins:node():getSize()
	ins:vnode()["size"] = size
	Receptor:select("instance", {ins:node()})
	Placer:unbind()
end

return M
