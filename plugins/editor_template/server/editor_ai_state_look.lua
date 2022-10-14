local AIStateBase = require("entity.ai.ai_state_base")

local AIStateLook = L("AIStateLook", Lib.derive(AIStateBase))
AIStateLook.NAME = "AIStateLook"
local stateIndex = 1
function AIStateLook:enter()
    self.control:setAiData("lookPlayerTime", World.Now() + 40)
    local entity = self:getEntity()
    self.lookID = entity:data("aiData").lookID
    stateIndex = 1
end

function AIStateLook:update()
    local lookTarget = World.CurWorld:getObject(self.lookID)
    if not lookTarget then
        return
    end
    local entity = self:getEntity()
    self.control:face2Pos(lookTarget:getPosition())
end

function AIStateLook:exit()
end

RETURN(AIStateLook)
