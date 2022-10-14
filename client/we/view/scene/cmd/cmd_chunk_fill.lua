local Engine = require "we.engine.engine"
local Receptor = require "we.view.scene.receptor.receptor"

local Base = require "we.cmd.cmd_base"
local M = Lib.derive(Base)

function M:init(pos_min, chunk, tid)
	Base.init(self)

	self._pos_min = pos_min
	self._tid = tid

	self._old_chunk = chunk
	self._new_chunk = nil
end

function M:redo()
	Base.redo(self)
	if not self._new_chunk then
		for i = 0, self._old_chunk.lx - 1 do
			for j = 0, self._old_chunk.ly - 1 do
				for k = 0, self._old_chunk.lz - 1 do
					local x, y, z = self._pos_min.x + i, self._pos_min.y + j, self._pos_min.z + k
					Engine:set_block({x = x, y = y, z = z}, self._tid)
					--IBlock:set_block({ x = x, y = y, z = z }, self._tid)
				end
			end
		end

		local pos_max = {
			x = self._pos_min.x + self._old_chunk.lx - 1,
			y = self._pos_min.y + self._old_chunk.ly - 1,
			z = self._pos_min.z + self._old_chunk.lz - 1 }
		self._new_chunk = Engine:make_chunk(self._pos_min, pos_max)
	else
		Engine:set_chunk(self._pos_min, self._new_chunk)
	end
	Receptor:unbind()
end

function M:undo()
	Base.undo(self)
	Engine:clr_chunk(self._pos_min, self._new_chunk)
	Engine:set_chunk(self._pos_min, self._old_chunk)
end

return M
