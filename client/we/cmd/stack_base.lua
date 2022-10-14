local M = {}

function M:init()
	self._stack = {}
	self._iter = 0
end

function M:push(cmd, exec)
	assert(cmd)

	for i = #self._stack, self._iter + 1, -1 do
		self._stack[i] = nil
	end
	table.insert(self._stack, cmd)
	if exec then
		cmd:exec()
	end

	self._iter = self._iter + 1
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

	World.CurWorld.opType = 2
	local cmd = assert(self._stack[self._iter + 1])
	cmd:redo()
	World.CurWorld.opType = 0
	self._iter = self._iter + 1
end

function M:undo()
	if not self:can_undo() then
		return
	end

	World.CurWorld.opType = 1
	local cmd = assert(self._stack[self._iter])
	cmd:undo()
	World.CurWorld.opType = 0

	self._iter = self._iter - 1
end

function M:clear()
	self._stack = {}
	self._iter = 0
end

M:init()

return M
