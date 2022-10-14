local IBlock = require "we.engine.engine_block"
local Receptor = require "we.view.scene.receptor.receptor"
local Base = require "we.cmd.cmd_base"
local M = Lib.derive(Base)

function M:init(list, offset)
	Base.init(self)

	self._l1, self._l2 = {}, {}
	for _, pos in ipairs(list) do
		local npos = {
			x = pos.x + offset.x,
			y = pos.y + offset.y,
			z = pos.z + offset.z
		}

		table.insert(self._l1, {
			pos = pos,
			id = IBlock:get_block(pos),
			nid = 0
		})

		table.insert(self._l2, {
			pos = npos,
			id = IBlock:get_block(npos),
			nid = IBlock:get_block(pos)
		})
	end
end

function M:redo()
	Base.redo(self)

	for _, v in ipairs(self._l1) do
		IBlock:set_block(v.pos, v.nid)
	end

	for _, v in ipairs(self._l2) do
		IBlock:set_block(v.pos, v.nid)
	end
end

function M:undo()
	Base.undo(self)

	for _, v in ipairs(self._l2) do
		IBlock:set_block(v.pos, v.id)
	end

	for _, v in ipairs(self._l1) do
		IBlock:set_block(v.pos, v.id)
	end
	Receptor:unbind()
end

return M
