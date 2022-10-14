local engine = require "we.engine"
local base = require "we.cmds.cmd_base"
local state = require "we.state"
local def = require "we.def"
local tran = require "we.Transform"
local M = Lib.derive(base)

function M:init(pos,side, chunk)
	base.init(self)

	local posside = Lib.v3add(pos, side)
	self._posd = tran.CenterAlign(posside,chunk,side)
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
	state:set_focus(obj,def.TCHUNK,false)
	state:set_editmode(def.EMOVE)
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
	state:set_focus(self._focus_obj,self._focus_class,false)
	state:set_editmode(def.EMOVE)
end

return M
