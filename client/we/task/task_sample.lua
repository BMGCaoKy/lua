local Task = require "task"

local M = {}

function M:exec_(...)
	self:set_precent(10)
	self:set_precent(50)
	self:set_precent(100)
	return Task.STATUS_FINISH
end

return M
