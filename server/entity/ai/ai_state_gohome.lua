local AIStateBase = require("entity.ai.ai_state_base")

local AIStateGoHome = L("AIStateGoHome", Lib.derive(AIStateBase))
AIStateGoHome.NAME = "GOHOME"

local CHECK_HATRED_INTERVAL = 10

function AIStateGoHome:checkForceGoHome(control, entity)
	if control:isInForceGoHomeState() then
		return
	end
	local forceGoHomeVariable = control:aiData("forceGoHomeVariable")
	if not forceGoHomeVariable then
		return
	end
	local time = forceGoHomeVariable.time
	if not time then
		return
	end
	entity.forceGoHomeTimeEnd = World.Now() + time
	local buffs = forceGoHomeVariable.buffs or {}
	for _, buff in pairs(buffs) do
		entity:addBuff(buff, time)
	end
end

function AIStateGoHome:enter()
	local entity = self:getEntity()
	Trigger.CheckTriggers(entity:cfg(), "ENTER_AI_STATUS_GO_HOME", {obj1 = entity})
	local control = self.control
	local pos
	if control:isGoHomePos() then
		pos = control:getHomePos()
	else
		pos = control:randPosInHomeArea()
	end
	control:setTargetPos(pos, true)
	self:checkForceGoHome(control, entity)
	self.endTime = World.Now() + (control:isGoHomePos() and 999 or 40)
end

function AIStateGoHome:update()
	local restTime = self.endTime - World.Now()
	local targetPos = self.control:getTargetPos()
	if not targetPos then
		return
	end
	if Lib.getPosDistanceSqr(targetPos, self:getEntity():getPosition()) < 0.5 then
		return
	end
	if restTime < CHECK_HATRED_INTERVAL then
		return restTime
	end
	if self.control:getMaxHatredEntity() then
		return 
	end
	return CHECK_HATRED_INTERVAL
end

function AIStateGoHome:exit()
	self.control:setTargetPos(nil)
end

RETURN(AIStateGoHome)
