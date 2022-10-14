local AIStateBase = require("entity.ai.ai_state_base")

local AIStateBehaviors = L("AIStateBehaviors", Lib.derive(AIStateBase))
AIStateBehaviors.NAME = "BVHTREE"

function AIStateBehaviors:enter()
	local entity = self:getEntity()
	local control = self.control
	self.context = { obj1 = entity, trigger = control:aiData("bhvRunning") }
	--Trigger.CheckTriggersOnly(entity:cfg(), control:aiData("bhvRunning"), self.context)	
end

function AIStateBehaviors:update()
	local entity = self:getEntity()
	local control = self.control
	local context = self.context
	control:setChaseTarget(nil)
	context.chaseLevel = nil
	local isFollow = context.isFollow
	context.isFollow = false
	Trigger.CheckTriggersOnly(entity:cfg(), context.trigger, context)
	if isFollow and not context.isFollow then
		control:setFollowTarget(nil)
	end
	return 2
end

function AIStateBehaviors:exit()
	self.endTime = nil
end

RETURN(AIStateBehaviors)
