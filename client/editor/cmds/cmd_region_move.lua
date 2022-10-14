local base = require "editor.cmds.cmd_base"
local state = require "editor.state"
local def = require "editor.def"
local engine = require "editor.engine"
local Module = require "editor.gamedata.module.module"
local data_state = require "editor.data_state"
local Map = require "editor.map"

local M = Lib.derive(base)

function M:init(id,jsonobj)
	base.init(self)

	self._id = id
	self._old_obj = {}
	
	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())

	local regions = item:obj().regions

	for i = 1, #regions do
		if regions[i].id == self._id then
			self._old_obj = regions[i]
			if jsonobj.name == nil or jsonobj.name == "" then
				jsonobj.name = regions[i].name
			end
			break
		end
	end

	self._new_obj = 
	{
		id = id,
		name = jsonobj.name,
		cfg = jsonobj.cfg,
		min = jsonobj.box.min,
		max = jsonobj.box.max
	}

end

function M:redo()
	base.redo(self)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())

	local regions = item:obj().regions

	for i = 1, #regions do
		if regions[i].id == self._id then
			regions[i] = self._new_obj
			break
		end
	end

	state:set_focus({id = self._id}, def.TREGION)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())

	local regions = item:obj().regions
	
	local obj = {
		id = self._id,
		name = self._old_obj.name,
		cfg = self._old_obj.cfg,
		min = {
			x = self._old_obj.min.x,
			y = self._old_obj.min.y,
			z = self._old_obj.min.z
		},
		max = {
			x = self._old_obj.max.x,
			y = self._old_obj.max.y,
			z = self._old_obj.max.z
		}
	}
	for i = 1, #regions do
		if regions[i].id == self._id then
			regions[i] = obj
			break
		end
	end
	state:set_focus({id = self._id}, def.TREGION)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M