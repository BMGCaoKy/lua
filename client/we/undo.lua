local M = {}

function M:init()
	self._stack = {}
	self._iter = 0
end

function M:push(cmd)
	assert(cmd)

	for i = #self._stack, self._iter + 1, -1 do
		self._stack[i] = nil
	end
	table.insert(self._stack, cmd)

	self:redo()

	Lib.emitEvent(Event.EVENT_UNDO_REDO)
end

function M:can_redo()
	if self._iter >= #self._stack then
		return false
	end

	local cmd = assert(self._stack[self._iter + 1])
	return cmd:can_redo()
end

function M:can_undo()
	if self._iter <= 0 then
		return false
	end

	local cmd = assert(self._stack[self._iter], self._iter)
	return cmd:can_undo()
end

function M:redo()
	if not self:can_redo() then
		return
	end

	local cmd = assert(self._stack[self._iter + 1])
	cmd:redo()

	self._iter = self._iter + 1
end

function M:undo()
	if not self:can_undo() then
		return
	end

	local cmd = assert(self._stack[self._iter])
	cmd:undo()

	self._iter = self._iter - 1
end

M:init()

return M
