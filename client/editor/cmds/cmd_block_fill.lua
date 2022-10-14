local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local state = require "editor.state"
local def = require "editor.def"
local editorUtils = require "editor.utils"
local M = Lib.derive(base)

function M:init(focus_obj)
	base.init(self)

	self._pos_min = focus_obj.min
	self._pos_max = focus_obj.max
	self._tid = focus_obj.id

	self._old_chunk = engine:make_chunk(self._pos_min, self._pos_max, true)
	self._new_chunk = nil
	self._focus_obj = {
		old_min = focus_obj.old_min,
		old_max = focus_obj.old_max,
		min = focus_obj.old_min,
		max = focus_obj.old_max,
		id = focus_obj.id
	}
end

function M:redo()
	base.redo(self)
	if not self._new_chunk then
		self._new_chunk = engine:make_chunk_byid(self._pos_min, self._pos_max, true, self._tid)
		engine:set_chunk(self._pos_min, self._new_chunk)
	else
		engine:set_chunk(self._pos_min, self._new_chunk)
	end
	editorUtils:setPlaceObjChange("block", self._focus_obj.id)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)
	engine:set_chunk(self._pos_min, self._old_chunk)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	--state:set_focus(self._focus_obj,def.TBLOCK_FILL,false)
end

return M