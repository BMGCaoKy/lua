local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local entity_obj = require "editor.entity_obj"
local def = require "editor.def"
local state = require "editor.state"
local editorUtils = require "editor.utils"


local M = Lib.derive(base)

local i = 0

function M:init(pos, _table)
	base.init(self)
	self._pos = pos
	self._cfg = _table.cfg
	self._data = Lib.copy(_table)
	local entityCfg = Entity.GetCfg(self._cfg)
	self.maxCount =  entityCfg.maxCount
	self.customCmd = entityCfg.customCmd
	self.id = nil
end

function M:redo()
	base.redo(self)
	local ret = self.customCmd and entity_obj:CmdRedoSet(self._pos, self._cfg, self)
	if ret then
		return
	end
	editorUtils:checkIsExistEndPoint(entity_obj, self._cfg)
	local id 
	if self.maxCount then
		id = entity_obj:rulerArithmeticAdd(self._cfg, self._pos, id, entity_obj)
	else
		id = entity_obj:addEntity(self._pos, self._data)
	end
	self.id = id
	if not entity_obj:getEntityById(id) then
		return
	end
	editorUtils:checkEndPointIsPlace(entity_obj, id, "set_entity_redo")
	editorUtils:setPlaceObjChange("entity", self._cfg)
	engine:set_bModify(true)
	state:set_focus({id = id}, def.TENTITY, false)
	engine:recently_entity(entity_obj:getCfgById(self.id))
    if self.derive then
        entity_obj:Cmd("replaceTable", self.id, self.derive)
    end
end

function M:undo()
	base.undo(self)
	editorUtils:checkIsExistEndPoint(entity_obj, self._cfg)
    self.derive = entity_obj:getDataById(self.id)
	local ret = self.customCmd and entity_obj:CmdUndoSet(self._cfg, self)
	if ret then
		return
	end
	editorUtils:setPlaceObjChange("entity", self._cfg, true)
	editorUtils:checkEndPointIsPlace(entity_obj, self.id, "set_entity_undo")
	if self.maxCount then
		entity_obj:rulerArithmeticSub(self._cfg, entity_obj)
	else
		entity_obj:delEntity(self.id)
	end
	state:set_focus(nil)
	engine:set_bModify(true);
end

function M:can_redo()
	if self.customCmd then
		return entity_obj:CmdCanRedoSet(self._cfg, {pos = self._pos})
	else
		return true
	end
end

function M:can_undo()
	if self.customCmd then
		return entity_obj:CmdCanUndoSet(self._cfg, {pos = self._pos})
	else
		return true
	end
end

return M