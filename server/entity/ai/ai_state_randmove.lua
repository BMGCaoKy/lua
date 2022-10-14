
local AIStateBase = require("entity.ai.ai_state_base")

local AIStateRandMove = L("AIStateRandMove", Lib.derive(AIStateBase))
AIStateRandMove.NAME = "RANDMOVE"

function AIStateRandMove:enter()
	local control = self.control
	local target = control:randPosInHomeArea()
	if not target then
		target = control:randPosNearBy(control:aiData("patrolDistance") or 10)
	end
	if target then
		control:setTargetPos(target, true)
		self.endTime = World.Now() + 10
	else
		self.endTime = 1
	end
end

function AIStateRandMove:update()
	return self.endTime - World.Now()
end

function AIStateRandMove:exit()
	self.endTime = nil
end

RETURN(AIStateRandMove)
