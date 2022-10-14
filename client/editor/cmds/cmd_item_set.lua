local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local item_obj = require "editor.item_obj"
local def = require "editor.def"
local state = require "editor.state"
local editorUtils = require "editor.utils"
local M = Lib.derive(base)

function M:init(pos, cfg, blockID)
	base.init(self)
	self.blockID = blockID
	self._pos = pos
	self._cfg = cfg
	self.id = nil
end

function M:redo()
	base.redo(self)
	local id
	if self.blockID then
		id = item_obj:add_item(Lib.copy(self._pos), self._cfg, self.blockID)
	else
		id = item_obj:add_item(Lib.copy(self._pos), self._cfg)
	end
	self.id = tostring(id)
	editorUtils:setPlaceObjChange("item", self._cfg)
	engine:set_bModify(true);
end

function M:undo()
	base.undo(self)

	editorUtils:setPlaceObjChange("item", self._cfg, true)
	item_obj:delete_item(self.id)
	state:set_focus(nil)
	local _table = {cfg = self._cfg}
	--state:set_brush(_table,def.TITEM)
	engine:set_bModify(true)
end

return M