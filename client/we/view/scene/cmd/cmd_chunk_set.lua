local IBlock = require "we.engine.engine_block"
local Engine = require "we.engine.engine"

local Base = require "we.cmd.cmd_base"
local M = Lib.derive(Base)

function M:init(pos, chunk)
	Base.init(self)
	
	self._chunk_d = chunk
	self._pos_d = pos

	self._chunk_s = chunk

	self._chunk_d = Engine:make_chunk(self._pos_d, {
		x = self._pos_d.x + chunk["lx"],
		y = self._pos_d.y + chunk["ly"],
		z = self._pos_d.z + chunk["lz"]
	})
end

function M:redo()
	Base.redo(self)
	Engine:set_chunk(self._pos_d, self._chunk_s)
end

function M:undo()
	Base.undo(self)
	Engine:clr_chunk(self._pos_d, self._chunk_s)
	Engine:set_chunk(self._pos_d, self._chunk_d)
end

return M
