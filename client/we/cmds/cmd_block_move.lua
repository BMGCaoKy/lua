local engine = require "we.engine"
local base = require "we.cmds.cmd_base"
local state = require "we.state"
local def = require "we.def"

local M = Lib.derive(base)

function M:init(pos_s, pos_d)
	base.init(self)

	self._pos_s = pos_s
	self._pos_d = pos_d

	self._block_s = engine:get_block(pos_s)
	self._block_d = engine:get_block(pos_d)
end

function M:redo()
	base.redo(self)

	engine:clr_block(self._pos_s)
	engine:set_block(self._pos_d, self._block_s)
	state:set_focus({pos = self._pos_d}, def.TBLOCK)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	engine:set_block(self._pos_d, self._block_d)
	engine:set_block(self._pos_s, self._block_s)
	state:set_focus({pos = self._pos_s}, def.TBLOCK)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M
