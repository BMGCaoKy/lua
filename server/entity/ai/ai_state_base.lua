
local AIStateBase = L("AIStateBase", {})

AIStateBase.updateInterval = -1

function AIStateBase:init(control)
	self.control = control
end

function AIStateBase:enter()
end

function AIStateBase:update()
end

function AIStateBase:exit()
end

function AIStateBase:onEvent(event, ...)
end

function AIStateBase:getEntity()
	return self.control:getEntity()
end

RETURN(AIStateBase)
