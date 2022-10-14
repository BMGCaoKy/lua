local M = {}

function M:init()
	self._sender = setmetatable({}, {
		__mode = "k"
	})
	self._inv_list = {}
end

function M:subscribe(sender, signal, func)
	assert(sender and signal, tostring(signal))
    assert(type(func) == "function")

    local invalid = false
    local function call(...)
        if invalid then
            return 0
        end

		if func(...) == 0 then
			invalid = true
			return 0
		end
    end
    
    local function cancel()
        invalid = true

		self._inv_list[sender] = self._inv_list[sender] or {}
		self._inv_list[sender][signal] = self._inv_list[sender][signal] or {}
		self._inv_list[sender][signal][call] = true
		
    end

	self._sender[sender] = self._sender[sender] or {}
	self._sender[sender][signal] = self._sender[sender][signal] or {}
	table.insert(self._sender[sender][signal], call)

    return cancel
end

function M:publish(sender, signal, ...)
    assert(sender and signal)
	
	local calls = self._sender[sender] and self._sender[sender][signal]
	if not calls then
		return
	end

	local _calls = {}
	for _, call in ipairs(calls) do
		table.insert(_calls, call)
	end

	local invalid_set = {}
	for _, call in ipairs(_calls) do
		if call(...) == 0 then
			invalid_set[call] = true
		end
	end

	local idx = 1
	repeat
		local call = calls[idx]
		if not call then
			break
		end
		if invalid_set[call] then
			table.remove(calls, idx)
		else
			idx = idx + 1
		end
	until(false)

	if #calls == 0 then
		self._sender[sender][signal] = nil
	end
end

function M:clean()
	for sender, signals in pairs(self._inv_list) do
		if self._sender[sender] then
			for signal, calls in pairs(signals) do
				if self._sender[sender][signal] then
					for i = #self._sender[sender][signal], 1, -1 do
						local call = self._sender[sender][signal][i]
						if calls[call] then
							table.remove(self._sender[sender][signal], i)
						end
					end
					if #self._sender[sender][signal] == 0 then
						self._sender[sender][signal] = nil
					end
				end
			end
		end
	end

	self._inv_list = {}
end

return M
