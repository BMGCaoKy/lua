local M = {}

function M:init()
	self._redo = false
end

function M:can_redo()
	return true
end

function M:can_undo()
	return true
end

function M:redo()
	assert(self._redo == false)
	self._redo = true
end

function M:undo()
	assert(self._redo == true)
	self._redo = false
end

return M
