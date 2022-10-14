local Engine = require "we.engine.engine"
local Receptor = require "we.view.scene.receptor.receptor"

local Base = require "we.cmd.cmd_base"
local M = Lib.derive(Base)

function M:init(pos, chunk)

	self._pos = pos
	self._chunk = chunk
end

function M:redo()
	Base.redo(self)
	Engine:clr_chunk(self._pos, self._chunk)
	Receptor:unbind()
end

function M:undo()
	Base.undo(self)
	Engine:set_chunk(self._pos, self._chunk)
end

return M
