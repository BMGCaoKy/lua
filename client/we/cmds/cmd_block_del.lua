local engine = require "we.engine"
local base = require "we.cmds.cmd_base"
local state = require "we.state"
local def = require "we.def"

local M = Lib.derive(base)

function M:init(pos)
	base.init(self)

	self._pos = pos
	self._id = 0
	self._oid = engine:get_block(pos)
	self._focus_obj = state:focus_obj()
end

function M:redo()
	base.redo(self)
	
	engine:set_block(self._pos, self._id)
	state:set_focus(nil)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	engine:set_block(self._pos, self._oid)
	state:set_focus(self._focus_obj,def.TBLOCK)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M
