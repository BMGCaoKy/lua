local engine = require "we.engine"
local base = require "we.cmds.cmd_base"
local def = require "we.def"
local state = require "we.state"
local Module = require "we.gamedata.module.module"
local data_state = require "we.data_state"
local Map = require "we.map"

local M = Lib.derive(base)

function M:init(pos, cfg, yaw)
	base.init(self)

	self._pos = {
		x = pos.x,
		y = pos.y+0.01,
		z = pos.z
	}
	self._yaw = yaw
	self._cfg = cfg
	self.index = nil
	self._id = nil
end

function M:redo()
	base.redo(self)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())
	local obj = {
		id = self._id,
		pos = self._pos,
		cfg = self._cfg,
		entity = { cfg = self._cfg },
		ry = self._yaw
	}
	self.index = item:data():insert("entitys",nil,nil,obj)
	local id = item:obj().entitys[self.index].id
	local _table = {id = id}
	state:set_focus(_table,def.TENTITY,true)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())
	self._id = item:obj().entitys[self.index].id
	item:data():remove("entitys",self.index)
	state:set_focus(nil)
	local _table = {cfg = self._cfg, yaw = self._yaw}
	state:set_brush(_table,def.TENTITY)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M