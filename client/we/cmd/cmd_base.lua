local M = {}

function M:init()
	self._redo = true
end

function M:can_redo()
	return true
end

function M:can_undo()
	return true
end

function M:exec()
	self._redo = false
	self:redo()
end

function M:redo()
	assert(self._redo == false)
	assert(self:can_redo())

	self._redo = true
end

function M:undo()
	assert(self._redo == true)
	assert(self:can_undo())

	self._redo = false
end

return M
