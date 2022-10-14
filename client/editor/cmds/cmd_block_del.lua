local base = require "editor.cmds.cmd_base"
local state = require "editor.state"
local blockVector_obj = require "editor.blockVector_obj"
local engine = require "editor.engine"

local M = Lib.derive(base)

function M:init(pos)
	base.init(self)
	self._pos = pos
	self._id = 0
	self._cfg = World.CurMap:getBlock(pos)
	self._oid = engine:get_block(pos)
end

function M:redo()
	base.redo(self)
	local cfg = self._cfg
	local ok, placeInfo = CombinationBlock:breakBlock(cfg, self._pos, World.CurMap)
	if ok then
		self._cfg = placeInfo.cfg
		self._pos = placeInfo.pos
	else
		self.removeAttackBlockList = {}
		engine:set_block(self._pos, self._id, self.removeAttackBlockList)
	end
	state:set_focus(nil)
	engine:set_bModify(true)
end

function M:undo()
	base.undo(self)
	local cfg = self._cfg
	if not CombinationBlock:placeBlock(cfg, self._pos, World.CurMap) then
		engine:set_block(self._pos, self._oid)
	end
	for _, blockInfo in pairs(self.removeAttackBlockList.attachBlockList or {}) do
		engine:set_block(blockInfo.pos, blockInfo.id)
	end
	engine:set_bModify(true)
end

return M
