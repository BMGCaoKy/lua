local def = require "we.def"
local state = require "we.state"
local base = require "we.cmds.cmd_base"
local engine = require "we.engine"
local Module = require "we.gamedata.module.module"
local data_state = require "we.data_state"
local Map = require "we.map"

local M = Lib.derive(base)

function M:init(id)
	base.init(self)

	self._id = id
	self._obj = {}
end

function M:redo()
	base.redo(self)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())

	local entitys = item:obj().entitys

	local index = nil

	for i = 1, #entitys do
		if entitys[i].id == self._id then
			self._obj = entitys[i]
			index = i
			break
		end
	end
	assert(index)
	item:data():remove("entitys",index)
	Lib.emitEvent(Event.EVENT_EDITOR_DEL_ENTITY,self._id)

	state:set_focus(nil)
	engine:editor_obj_type("common")
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())

	local index = item:data():insert("entitys",nil,nil,self._obj)

	local entitys = item:obj().entitys

	self._id = entitys[index].id
	state:set_focus({id = self._id},def.TENTITY)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M