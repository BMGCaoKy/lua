local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local state = require "editor.state"
local def = require "editor.def"

local M = Lib.derive(base)

function M:init(pos, chunk, is_scale)
	base.init(self)

	self._pos = pos
	self._chunk = chunk
	self._is_scale = is_scale
end

function M:redo()
	base.redo(self)

	engine:clr_chunk(self._pos, self._chunk)
	state:set_focus(nil)
	--[[
	local obj = Lib.boxOne()
	state:set_brush(obj,def.TFRAME)
	if	self._is_scale then
		state:set_editmode(def.ESCALE)
	end
	engine:editor_obj_type("TFRAME")
	]]--
	engine:set_bModify(true)
end

function M:undo()
	base.undo(self)
	
	engine:set_chunk(self._pos, self._chunk)
	local obj = {
		min = self._pos,
		max = {
			x = self._pos.x + self._chunk.lx-1,
			y = self._pos.y + self._chunk.ly-1,
			z = self._pos.z + self._chunk.lz-1
		}
	}
	--state:set_focus(obj,def.TFRAME)
	engine:set_bModify(true)
end

return M
