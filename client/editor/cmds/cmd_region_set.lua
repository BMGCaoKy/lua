local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local def = require "editor.def"
local state = require "editor.state"
local Module = require "editor.gamedata.module.module"
local data_state = require "editor.data_state"
local Map = require "editor.map"

local M = Lib.derive(base)

function M:init(pos)
	base.init(self)

	self._pos = pos
	self._id = nil
	self._index = nil
end

function M:redo()
	base.redo(self)

	--self._id = obj:add_region(self._pos,self._pos)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())
	assert(item)
	local obj = {
		id = self._id,
		name = "",
		cfg = "",
		min = self._pos,
		max = self._pos
	}

	self._index = item:insert("regions",nil,nil,obj)

	self._id = item:obj().regions[self._index].id

	local obj = {
		id = self._id
	}
	state:set_focus(obj,def.TREGION)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	--obj:del_region(self._name)
	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())
	self._id = item:obj().regions[self._index].id
	item:remove("regions",self._index)

	state:set_focus(nil)
	local obj = Lib.boxOne()
	state:set_brush(obj,def.TREGION)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M
