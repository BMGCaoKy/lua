local AIStateBase = require("entity.ai.ai_state_base")

local AIStateMoveTo = L("AIStateMoveTo", Lib.derive(AIStateBase))
AIStateMoveTo.NAME = "MOVETO"

function AIStateMoveTo:enter()
	self.endTime = World.Now() + (self.control:getEntityCfgValue("moveToFrequency") or 20)
end

function AIStateMoveTo:update()
	local targetPos = self.control:getTargetPos()
	if not targetPos then
		return
	end
	if Lib.getPosDistanceSqr(targetPos, self:getEntity():getPosition()) < 0.5 then
		self.control:setTargetPos(nil)
		return
	end
	return self.endTime - World.Now()
end

function AIStateMoveTo:exit()
	self.endTime = nil
end

RETURN(AIStateMoveTo)