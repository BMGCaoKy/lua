local Receptor = require "we.view.scene.receptor.receptor"
local IBlock = require "we.engine.engine_block"
local Base = require "we.cmd.cmd_base"
local M = Lib.derive(Base)

function M:init(list)
	Base.init(self)

	self._list = list
end

function M:redo()
	Base.redo(self)

	for i, v in pairs(self._list) do
		IBlock:set_block(v.pos, v.new_id)
	end
	Receptor:unbind()
end

function M:undo()
	Base.undo(self)
	for i, v in pairs(self._list) do
		IBlock:set_block(v.pos, v.id)
	end
end

return M
