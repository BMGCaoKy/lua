local engine = require "we.engine"
local base = require "we.cmds.cmd_base"
local state = require "we.state"
local def = require "we.def"

local M = Lib.derive(base)

function M:init(pos_min, chunk, tid)
	base.init(self)

	self._pos_min = pos_min
	self._tid = tid

	self._old_chunk = chunk
	self._new_chunk = nil
end

function M:redo()
	if not self._new_chunk then
		for i = 0, self._old_chunk.lx - 1 do 
			for j = 0, self._old_chunk.ly - 1 do
				for k = 0, self._old_chunk.lz - 1 do
					local x, y, z = self._pos_min.x + i, self._pos_min.y + j, self._pos_min.z + k
					engine:set_block({x = x, y = y, z = z}, self._tid)
				end
			end
		end

		local pos_max = {
			x = self._pos_min.x + self._old_chunk.lx - 1,
			y = self._pos_min.y + self._old_chunk.ly - 1,
			z = self._pos_min.z + self._old_chunk.lz - 1}
		self._new_chunk = engine:make_chunk(self._pos_min, pos_max, true)
	else
		engine:set_chunk(self._pos_min, self._new_chunk)
	end
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	local obj = { pos = self._pos_min, data = self._new_chunk }
	state:set_focus(obj,def.TCHUNK)
end

function M:undo()
	engine:clr_chunk(self._pos_min, self._new_chunk)
	engine:set_chunk(self._pos_min, self._old_chunk)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	local obj = { pos = self._pos_min, data = self._old_chunk }
	state:set_editmode(def.EMOVE)
	state:set_focus(obj,def.TCHUNK)
end

return M
