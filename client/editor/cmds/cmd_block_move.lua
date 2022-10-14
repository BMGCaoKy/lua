local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local state = require "editor.state"
local def = require "editor.def"
local blockVector_obj = require "editor.blockVector_obj"
local M = Lib.derive(base)

function M:init(pos_s, pos_d)
	base.init(self)

	self._pos_s = pos_s
	self._pos_d = pos_d

	self._block_s = engine:get_block(pos_s)

	self._block_vector_s = blockVector_obj:get_block_vector(pos_s)
	self._block_d = engine:get_block(pos_d)
	self._block_vector_d = blockVector_obj:get_block_vector(pos_d)
end

function M:redo()
	base.redo(self)

	engine:clr_block(self._pos_s)
	engine:set_block(self._pos_d, self._block_s)

	blockVector_obj:set_block_vector_value(self._pos_d, self._block_vector_s)

	state:set_focus({pos = self._pos_d}, def.TBLOCK)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)

	engine:set_block(self._pos_d, self._block_d)
	engine:set_block(self._pos_s, self._block_s)
	blockVector_obj:set_block_vector_value(self._pos_d, self._block_vector_d)
	blockVector_obj:set_block_vector_value(self._pos_s, self._block_vector_s)

	state:set_focus({pos = self._pos_s}, def.TBLOCK)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M
