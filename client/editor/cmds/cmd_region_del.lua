local base = require "editor.cmds.cmd_base"
local def = require "editor.def"
local state = require "editor.state"
local engine = require "editor.engine"
local Module = require "editor.gamedata.module.module"
local data_state = require "editor.data_state"
local Map = require "editor.map"

local M = Lib.derive(base)

function M:init(id)
	base.init(self)

	self._id = id
	self._obj = {}
	self._item_region = nil
end

function M:redo()
	base.redo(self)
	
	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())

	local regions = item:obj().regions

	local index = nil

	for i = 1, #regions do
		if regions[i].id == self._id then
			self._obj = regions[i]
			index = i
			break
		end
	end

	item:remove("regions",index)

	-------------------------------------------------
	--[[
	local m_region = Module:module("region")
	assert(m_region,"region")
	self._item_region = m:item(self._obj.cfg)
	m_region:del_item(self._item_region)
	]]
	-------------------------------------------------

	state:set_focus(nil)
	engine:editor_obj_type("common")
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)

end

function M:undo()
	base.undo(self)

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())

	local index = item:insert("regions",nil,nil,self._obj)

	local regions = item:obj().regions
	self._id = regions[index].id

	state:set_focus({id = self._id},def.TREGION)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M
