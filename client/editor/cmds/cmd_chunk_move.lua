local engine = require "editor.engine"
local base = require "editor.cmds.cmd_base"
local state = require "editor.state"
local def = require "editor.def"

local M = Lib.derive(base)

function M:init(pos_s, pos_d, chunk)
	base.init(self)

	self._pos_s = pos_s
	self._pos_d = pos_d

	self._chunk_s = chunk
	self._chunk_d = engine:make_chunk(pos_d, {
		x = pos_d.x + chunk.lx,
		y = pos_d.y + chunk.ly,
		z = pos_d.z + chunk.lz,
	})
end

function M:redo()
	base.redo(self)

	engine:clr_chunk(self._pos_s, self._chunk_s)
	engine:set_chunk(self._pos_d, self._chunk_s)
	state:set_focus({pos = self._pos_d, data = self._chunk_s}, def.TCHUNK,false)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:undo()
	base.undo(self)
	
	engine:clr_chunk(self._pos_d, self._chunk_s)
	engine:set_chunk(self._pos_d, self._chunk_d)	-- warring 重复设置会不会有问题, 如果单单是方块应该没有问题
	engine:set_chunk(self._pos_s, self._chunk_s)
	state:set_focus({pos = self._pos_s, data = self._chunk_s}, def.TCHUNK,false)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

return M
