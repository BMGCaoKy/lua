local engine = require "we.engine"
local base = require "we.cmds.cmd_base"
local state = require "we.state"
local def = require "we.def"
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
		for i = 0, self._old_chunk.lx - 1 do 
			for j = 0, self._old_chunk.ly - 1 do
				for k = 0, self._old_chunk.lz - 1 do
					local x, y, z = self._pos_min.x + i, self._pos_min.y + j, self._pos_min.z + k
					engine:set_block({x = x, y = y, z = z}, self._tid)
				end
			end
		end

		self._new_chunk = engine:make_chunk(self._pos_min, self._pos_max, true)
	else
		engine:set_chunk(self._pos_min, self._new_chunk)
	end
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)
	engine:clr_chunk(self._pos_min, self._new_chunk)
	engine:set_chunk(self._pos_min, self._old_chunk)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)

	state:set_focus(self._focus_obj,def.TBLOCK_FILL,false)
end

return M