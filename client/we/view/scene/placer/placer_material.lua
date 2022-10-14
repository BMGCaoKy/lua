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

local BM = Blockman.Instance()
local M = Lib.derive(Base)

function M:init(mode)
	Base.init(self,mode)
	self._item=nil
	self._node=nil
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
end

function M:place(x, y)
	local m = Module:module("game")	
	local useNewMaterial = m:item("0"):val().useNewMaterial
	if useNewMaterial==false then
			Placer:unbind()
			return
	end
	local node, type = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.OBJECT)
	local Map=require ("we.view.scene.map")
	if type then
		if node then
			if node.className=="MeshPartClient" then
				local inst=Map:query_instance(node.id)
				inst:set_material_by_drag(self._item)
			end
		end
	end
	Placer:unbind()
end

return M
