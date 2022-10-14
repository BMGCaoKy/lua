local M = {}

function M:init()
	self._sender = setmetatable({}, {
		__mode = "k"
	})

	self._wait = {}
	self._working = 0
end

function M:subscribe(sender, signal, func)
	assert(sender and signal)
    assert(type(func) == "function")

    local invalid = false
    local function call(...)
        if invalid then
            return 0
        end

        return func(...)
    end
    
    local function cancel()
        invalid = true
    end

	if self._working > 0 then
		table.insert(self._wait, { sender, signal, call })
		return cancel
	end

	self._sender[sender] = self._sender[sender] or {}
	self._sender[sender][signal] = self._sender[sender][signal] or {}
	table.insert(self._sender[sender][signal], call)

    return cancel
end

function M:publish(sender, signal, ...)
    assert(sender and signal)

	--print("SIGNAL", sender, signal, ...)
	self._working = self._working + 1
	
	local calls = self._sender[sender] and self._sender[sender][signal] or {}

	local idx, call
	repeat
		idx, call = next(calls, idx)
		if not idx then
			break
		end
		assert(type(call) == "function")

		if call(...) == 0 then
			table.remove(calls, idx)
		end
	until(false)

	self._working = self._working - 1

	if self._working == 0 then
		for _, val in ipairs(self._wait) do
			self:subscribe(table.unpack(val))
		end
		self._wait = {}
	end
end

return M
