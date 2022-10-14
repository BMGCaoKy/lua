local base = require "we.cmd.cmd_base"

local M = Lib.derive(base)

function M:init(uid)
	base.init(self)
	self._uid = uid
end

function M:redo()
	base.redo(self)
	UniUndoStack:Instance():redo(self._uid)
end

function M:undo()
	base.undo(self)
	UniUndoStack:Instance():undo(self._uid)
end

return M
