local Engine = require "we.engine.engine"
local Placer = require "we.view.scene.placer.placer"
local Receptor = require "we.view.scene.receptor.receptor"
local Base = require "we.cmd.cmd_base"
local M = Lib.derive(Base)

function M:init(pos, size)
	Base.init(self)
	
	self._pos_d = pos
	self._chunk_d = Engine:make_chunk(pos, {
		x = pos.x + size.x - 1,
		y = pos.y + size.y - 1,
		z = pos.z + size.z - 1,
	})
end

function M:redo()
	Base.redo(self)
	local placer = Placer:bind("chunk")
	placer:select(self._chunk_d, self._pos_d)
	Receptor:unbind()
end

function M:undo()
	Base.undo(self)
	Placer:unbind()
end

return M
