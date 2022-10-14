local GameRequest = require "we.proto.request_game"

local M = {}

function M:init()
	self._stack = nil
	Lib.subscribeEvent(Event.EVENT_UNDO_REDO, function()
		self:request_can_undo_redo();
	end)
end

function M:bind(stack)
	self._stack = stack
	self:request_can_undo_redo()
end

function M:undo()
	if not self._stack then
		return
	end
	
	local ret = self._stack:undo()
	self:request_can_undo_redo()

	return ret
end

function M:redo()
	if not self._stack then
		return
	end

	local ret = self._stack:redo()
	self:request_can_undo_redo()

	return ret
end

function M:request_can_undo_redo()
	if not self._stack then
		return
	end
	GameRequest.request_can_undo_redo(self._stack:can_undo(),self._stack:can_redo())
end

M:init()

return M
