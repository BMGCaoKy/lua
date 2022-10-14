local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local state = require "editor.state"
local def = require "editor.def"
local tran = require "editor.Transform"
local M = Lib.derive(base)

function M:init(pos, side, chunk)
	base.init(self)

	--local posside = Lib.v3add(pos, side)
	self._posd = pos --tran.CenterAlign(posside,chunk,side)
	self._chunk_d = chunk
	local undoMaxPos = {
		x = self._posd.x + chunk.lx - 1,
		y = self._posd.y + chunk.ly - 1,
		z = self._posd.z + chunk.lz - 1
	}
	self._chunk_s = engine:make_chunk(self._posd, undoMaxPos, true)

	self._focus_obj = state:focus_obj()
	self._focus_class = state:focus_class()
end

function M:redo()
	base.redo(self)

	engine:set_chunk(self._posd, self._chunk_d)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)

	local obj = {
		pos = self._posd,
		data = self._chunk_d
	}
	--state:set_focus(obj,def.TCHUNK,false)

end

function M:undo()
	base.undo(self)
	
	engine:set_chunk(self._posd, self._chunk_s)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)

	--[[
	local obj = {
		pos = self._posd,
		data = self._chunk_s
	}
	]]--
	--state:set_focus(self._focus_obj,self._focus_class,false)
end

return M
