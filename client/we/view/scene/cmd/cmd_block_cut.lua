local Placer = require "we.view.scene.placer.placer"
local Receptor = require "we.view.scene.receptor.receptor"
local IBlock = require "we.engine.engine_block"
local Base = require "we.cmd.cmd_base"
local Mapping = require "we.gamedata.module.mapping"
local M = Lib.derive(Base)

function M:init(pos, id)
	Base.init(self)

	self._id = id
	self._pos = pos
end

function M:redo()
	Base.redo(self)

	local placer = Placer:bind("block")
	placer:select(Mapping:id2name("block", self._id))
	IBlock:set_block(self._pos, nil)
	Receptor:unbind()
end

function M:undo()
	Base.undo(self)

	IBlock:set_block(self._pos, self._id)
	Placer:unbind()
end

return M
