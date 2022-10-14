local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local item_obj = require "editor.item_obj"
local def = require "editor.def"
local state = require "editor.state"
local editorUtils = require "editor.utils"
local M = Lib.derive(base)

function M:init(id, item)
	base.init(self)
	item = item:data("item")
	if item:is_block() then
		self.blockID = item:block_id()
	end
	self._id = id
	self._cfg = item_obj:get_cfg_byid(id)
	self._pos = item_obj:get_pos_byid(id)
end

function M:redo()
	base.redo(self)
	editorUtils:setPlaceObjChange("item", self._cfg, true)
	item_obj:delete_item(self._id)
	state:set_focus(nil)
	engine:set_bModify(true)
end

function M:undo()
	base.undo(self)
	local id = item_obj:add_item(self._pos, self._cfg, self.blockID)
	editorUtils:setPlaceObjChange("item", self._cfg)
	self._id = tostring(id)
	engine:set_bModify(true)
end

return M