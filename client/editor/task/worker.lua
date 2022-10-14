local Lanes = require "lanes".configure()
local Task = require "editor.task.task"

local M = {}

local worker_class = {
	init = function(self)
		self._linda = Lanes.linda()
		self._status = {
			code = Task.STATUS_INIT,
			progress = 0
		}
	end,

	start = function(self, task, ...)
		local func = Lanes.gen("*", Task.entry)
		func(self._linda, task, ...)
	end,

	status = function(self)
		return self._status
	end,

	progress = function(self)
		return self._status.percent
	end,

	update = function(self)
		local key, status = self._linda:receive(0, "STATUS")
		if key then
			self._status = status
		end
	end
}

function M:init()
	self._workers = {}
end

function M:schedule(task, ...)
	local worker = Lib.derive(worker_class)
	worker:init()
	worker:start(task, ...)
	
	table.insert(self._workers, worker)
	return worker
end

function M:Tick()
	for _, worker in ipairs(self._workers) do
		worker:update()
	end
end

return M
