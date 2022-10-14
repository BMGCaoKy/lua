local base = require "editor.cmds.cmd_base"
local engine = require "editor.engine"
local state = require "editor.state"
local def = require "editor.def"
local Module = require "editor.gamedata.module.module"
local data_state = require "editor.data_state"
local Map = require "editor.map"

local M = Lib.derive(base)

function M:init(id,new_data)
	base.init(self)

	self._id = id

	self._old_data = {}
	self._new_data = new_data
	
	self._index = nil

end

function M:redo()
	base.redo(self)

	local m = Module:module("map")
	assert(m,"map")

	local item = m:item(Map:curr_map_name())

	local obj = item:obj()

	local entitys = obj.entitys
	

	for i=1, #entitys do
		if entitys[i].id == self._id then
			self._index = i
			self._old_data = {
				pos = entitys[i].pos,
				yaw = entitys[i].ry
			}
		end
	end
	
	local entity_obj = {
		id = entitys[self._index].id,
		cfg = entitys[self._index].cfg,
		pos = self._new_data.pos,
		ry = self._new_data.yaw
	}
	entitys[self._index] = entity_obj

	local obj = {id = self._id}
	state:set_focus(obj,def.TENTITY)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	local m = Module:module("map")
	assert(m,"map")

	local item = m:item(Map:curr_map_name())

	local obj = item:obj()

	local entitys = obj.entitys

	for i=1, #entitys do
		if entitys[i].id == self._id then
			self._index = i
		end
	end
	
	local entity_obj = {
		id = entitys[self._index].id,
		cfg = entitys[self._index].cfg,
		pos = self._old_data.pos,
		ry = self._old_data.yaw
	}

	item:modify("entitys",self._index,entity_obj)

	state:set_focus({id = self._id},def.TENTITY)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M