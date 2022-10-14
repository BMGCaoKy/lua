local Receptor = require "we.view.scene.receptor.receptor"

local Engine = require "we.engine.engine"

local Base = require "we.cmd.cmd_base"
local M = Lib.derive(Base)

function M:init(pos, size, offset)
	Base.init(self)

	self._pos_s = pos
	self._pos_d = { x = pos.x + offset.x,
					y = pos.y + offset.y,
					z = pos.z + offset.z }

	self._chunk_s = Engine:make_chunk(pos, {
		x = pos.x + size.x - 1,
		y = pos.y + size.y - 1,
		z = pos.z + size.z - 1,
	})

	self._chunk_d = Engine:make_chunk(self._pos_d, {
		x = self._pos_d.x + size.x,
		y = self._pos_d.y + size.y,
		z = self._pos_d.z + size.z,
	})
end

function M:redo()
	Base.redo(self)

	Engine:clr_chunk(self._pos_s, self._chunk_s)
	Engine:set_chunk(self._pos_d, self._chunk_s)
end

function M:undo()
	Base.undo(self)

	Engine:clr_chunk(self._pos_d, self._chunk_s)
	Engine:set_chunk(self._pos_d, self._chunk_d)
	Engine:set_chunk(self._pos_s, self._chunk_s)

	Receptor:unbind()
end

return M
