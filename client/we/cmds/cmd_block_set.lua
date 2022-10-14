local engine = require "we.engine"
local base = require "we.cmds.cmd_base"
local setting = require "common.setting"
local state = require "we.state"
local def = require "we.def"

local M = Lib.derive(base)

function M:init(pos, id,b)
	base.init(self)

	self._pos = pos
	self._id = id
	self._oid = engine:get_block(pos)
	self._focus_obj = state:focus_obj()
	self._focus_class = state:focus_class()
	self._b = b
end

function M:redo()
	base.redo(self)

	engine:set_block(self._pos, self._id)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	engine:recently_block(setting:id2name("block", self._id))

	if self._b then
		state:set_focus({pos = self._pos},def.TBLOCK,false)
	end

	--[[
	local _table = 
	{
		old_min = self._pos,
		old_max = self._pos,
		min = self._pos,
		max = self._pos,
		id = self._id
	}
	state:set_focus(_table,def.TBLOCK_FILL,false)
	]]--
	state:set_editmode(def.EMOVE)
	
end

function M:undo()
	base.undo(self)
	
	engine:set_block(self._pos, self._oid)
	state:set_editmode(def.EMOVE)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)

	if self._b then
		state:set_focus(self._focus_obj,def.TBLOCK,false)
	end
	--state:set_focus(self._focus_obj,self._focus_class,false)
	
end

return M
