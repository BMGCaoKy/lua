local Task = require "task"

local M = {}

function M:init(linda)
	self._linda = assert(linda)
	self._progress = 0
	self._status_code = Task.STATUS_INIT
end

function M:progress()
	return self._progress
end

function M:set_progress(p)
	assert(p <= 100)
	self._progress = p
	self:report()
end

function M:report(info)
	self._linda:send(nil, "STATUS", {
		code = self._status_code,
		progress = self._progress,
		info = info
	})
end

function M:exec(...)
	self._status_code = Task.STATUS_RUNNING
	self:report()

	self:exec_(...)
	
	self._status_code = Task.STATUS_FINISH
	self:report()
end

return M
