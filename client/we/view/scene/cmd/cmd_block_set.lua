local IBlock = require "we.engine.engine_block"
local Receptor = require "we.view.scene.receptor.receptor"

local Base = require "we.cmd.cmd_base"
local M = Lib.derive(Base)

function M:init(list)
	Base.init(self)

	self._list = Lib.copy(list)
	for _, v in ipairs(self._list) do
		v.oid = IBlock:get_block(v.pos)
	end
end

function M:redo()
	Base.redo(self)

	for _, v in ipairs(self._list) do
		IBlock:set_block(v.pos, v.id)
	end
end

function M:undo()
	Base.undo(self)

	for _, v in ipairs(self._list) do
		IBlock:set_block(v.pos, v.oid)
	end
end

return M
