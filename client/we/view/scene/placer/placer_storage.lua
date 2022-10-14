local Meta = require "we.gamedata.meta.meta"

local Map = require "we.view.scene.map"
local Storage = require "we.view.scene.storage"
local IWorld = require "we.engine.engine_world"

local IInstance = require "we.engine.engine_instance"
local IScene = require "we.engine.engine_scene"
local Utils = require "we.view.scene.utils"

local Receptor = require "we.view.scene.receptor.receptor"
local Placer = require "we.view.scene.placer.placer"
local Module = require "we.gamedata.module.module"
local Constraint = require "we.view.scene.logic.constraint"

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

function M:select(...)
	self._item = {...}
end

function M:place(x, y)
	if not self._item then
		return
	end
	--get args(use_src_pos,paths)
	local use_src_pos, item = nil, {}
	for i,v in pairs(self._item) do
		if 1 == i then
			use_src_pos = v
		else
			table.insert(item, v)
		end
	end
	if not use_src_pos or not next(item) then
		return
	end
	--get place data list
	local list = Storage:get_place_scene_list(item)
	if not next(list) then
		return
	end
	local objs = {}
	local nodes = {}
	for _,val in pairs(list) do
		--create instance
		local ins = Map:new_instance(val)
		local node = ins:node()
		table.insert(nodes, node)
		table.insert(objs, ins)
		--drag to pos
		if "true" == use_src_pos then
			local pos = IInstance:position(node)
			pos["x"] = val.position.x
			pos["y"] = val.position.y
			pos["z"] = val.position.z
			node:setPosition(pos) -- set new pos
		else
			local bool = self:on_Terrain(x, y) -- check is on terrain
			IScene:drag_parts({ node }, x, y) -- drag to scene set pos
			if bool == false then
				local pos = IInstance:position(node) -- get ins pos
				pos["x"] = 0.0
				pos["y"] = 1.50
				pos["z"] = 0.0
				node:setPosition(pos)
			end
		end
		if "Model" ~= val.class then 
			IInstance:set(ins:node(), "size", Utils.seri_prop("Vector3", ins:vnode()["size"]))
		end
	end
	for _,obj in ipairs(objs) do
		Constraint:check_constraint(obj, true)
	end
	Receptor:select("instance", nodes)
	Placer:unbind()
end

return M
