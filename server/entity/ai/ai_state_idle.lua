local AIStateBase = require("entity.ai.ai_state_base")

local AIStateIdle = L("AIStateIdle", Lib.derive(AIStateBase))
AIStateIdle.NAME = "IDLE"

local function sendPlayAction(entity, action, time)
	entity:sendPacketToTracking({
		pid = "EntityPlayAction",
		objID = entity.objID,
		action = action,
		time = time,
	})
end

function AIStateIdle:enter()
	local entity = self:getEntity()
	local control = self.control
	local timeRange = control:aiData("idleTime") or {10, 30}
	local min = math.ceil(timeRange[1])
	local max = math.ceil(timeRange[2])
	local idleTime = math.random(min, max)
	self.endTime = World.Now() + idleTime
	local idleAction = control:aiData("idleAction")
	if idleAction then
		sendPlayAction(entity, idleAction, idleTime)
		self.playAction = true
	end
	--control:setTargetPos(nil)
end

function AIStateIdle:update()
	return self.endTime - World.Now()
end

function AIStateIdle:exit()
	self.endTime = nil
	if self.playAction then
		sendPlayAction(self:getEntity(), "idle", 0)
		self.playAction = nil
	end
end

RETURN(AIStateIdle)
