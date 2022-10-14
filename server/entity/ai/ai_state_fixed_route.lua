local AIEvaluator = require("entity.ai.ai_evaluator")
local AIStateBase = require("entity.ai.ai_state_base")

local AIStateFixedRoute = L("AIStateChase", Lib.derive(AIStateBase))
AIStateFixedRoute.NAME = "FIXEDROUTE"

function AIStateFixedRoute:enter()
    local control = self.control
    local entity = control:getEntity()
	self.aiData = entity:data("aiData")    
    local fixedRouteArray = self.aiData.route
    if not self.index then
        if self.aiData.randRouteStart then
            self.index = math.random(1, #fixedRouteArray)
        else
            self.index = 1
        end
    end
    control:setTargetPos(fixedRouteArray[self.index], true)
	self.aiData.homePos = entity:getPosition()
	self.endTime  = World.Now() + (entity:cfg().reactionTime or 10)
end

function AIStateFixedRoute:update()
	return self.endTime - World.Now()
end

function AIStateFixedRoute:onEvent(event, ...)
    if event == "arrived_target_pos" then
        local fixedRouteArray = self.aiData.route
        self.index = self.index % #fixedRouteArray + 1
        self.control:setTargetPos(fixedRouteArray[self.index], true)
        return true
    end
    return false
end

function AIStateFixedRoute:exit()
	self.endTime = nil
end

RETURN(AIStateFixedRoute)