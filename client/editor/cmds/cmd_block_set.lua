local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local setting = require "common.setting"
local state = require "editor.state"
local editorUtils = require "editor.utils"
local def = require "editor.def"
local blockVector_obj = require "editor.blockVector_obj"

local M = Lib.derive(base)

function M:init(pos, id,b, cfg)
	base.init(self)
	self._cfg = cfg
	self._pos = pos
	self._id = id
	self._oid = engine:get_block(pos)
	self._focus_obj = state:focus_obj()
	self._focus_class = state:focus_class()
	self._b = b
end

function M:redo()
	base.redo(self)
	local cfg = self._cfg
	if not CombinationBlock:placeBlock(cfg, self._pos, World.CurMap) then
		engine:set_block(self._pos, self._id)
	end
	if self._b then
		state:set_focus({pos = self._pos},def.TBLOCK,false)
	end
	editorUtils:setPlaceObjChange("block", self._cfg)
	engine:set_bModify(true);
end

function M:undo()
	base.undo(self)	
	local cfg = self._cfg
	if not CombinationBlock:breakBlock(cfg, self._pos, World.CurMap) then
		engine:set_block(self._pos, self._oid)
	end
	engine:set_bModify(true)
	if self._b then
		state:set_focus(self._focus_obj,def.TBLOCK,false)
	end
end

return M
