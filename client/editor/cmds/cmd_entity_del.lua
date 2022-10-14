local entity_obj = require "editor.entity_obj"
local def = require "editor.def"
local state = require "editor.state"
local base = require "editor.cmds.cmd_base"
local engine = require "editor.engine"
local editorUtils = require "editor.utils"


local M = Lib.derive(base)

function M:init(id)
	base.init(self)
	self._cfg = entity_obj:getCfgById(id)
	self._pos = entity_obj:getPosById(id)
	self._data = entity_obj:Cmd("getBrushObj", id, self._cfg) or {
		cfg = self._cfg
	}
	self._id = id
	local entityCfg = Entity.GetCfg(self._cfg)
	self.maxCount =  entityCfg.maxCount
	self.customCmd = entityCfg.customCmd
end

function M:redo()
	base.redo(self)
    self.derive = entity_obj:getDataById(self._id)
	local ret = self.customCmd and entity_obj:CmdRedoDel(self._cfg, self)
	if ret then
		return
	end
	editorUtils:setPlaceObjChange("entity", self._cfg, true)
	editorUtils:checkEndPointIsPlace(entity_obj, self._id, "del_entity_redo")
	editorUtils:checkIsExistEndPoint(entity_obj, self._cfg)
	if self.maxCount then
		self.insertIndex = entity_obj:ruleExternDel(self._cfg, self._id, entity_obj)
	else
		entity_obj:delEntity(self._id)
	end
	state:set_focus(nil)
	engine:editor_obj_type("common")
	engine:set_bModify(true)
end

function M:undo()
	base.undo(self)
	local id
	local ret = self.customCmd and entity_obj:CmdUndoDel(self._cfg, self)
	if ret then
		return
	end
	if self.maxCount then
		self._id = entity_obj:ruleExternInsert(self._cfg, self._pos, self.insertIndex, entity_obj)
	else
		self._id = entity_obj:addEntity(self._pos, self._data)
	end
	editorUtils:setPlaceObjChange("entity", self._cfg)
	editorUtils:checkEndPointIsPlace(entity_obj, self._id, "del_entity_undo")
    entity_obj:Cmd("replaceTable", self._id, self.derive)
	state:set_focus({id = id},def.TENTITY)
	engine:set_bModify(true)
end

function M:can_redo()
	if self.customCmd then
		return entity_obj:CmdCanRedoDel(self._cfg, self._id)
	else
		return true
	end
end

function M:can_undo()
	if self.customCmd then
		return entity_obj:CmdCanUndoDel(self._cfg, self._id)
	else
		return true
	end
end

return M