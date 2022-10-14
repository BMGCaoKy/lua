local AIStateBase = require("entity.ai.ai_state_base")

local AIStateEmergency = L("AIStateEmergency", Lib.derive(AIStateBase))
AIStateEmergency.NAME = "EMERGENCY"
local stateIndex = 0
local basePos
local startAngle
local dirList = {
    list = {{pos = {x=0, y=0, z=1}},
    {pos = {x=0, y=0, z=1}},
    {pos = {x=0, y=0, z=1}},
    {pos = {x=0, y=0, z=1}},
    {pos = {x=-1, y=0, z=1}},
    {pos = {x=-1, y=0, z=1}},
    {pos = {x=-1, y=0, z=1}},
    {pos = {x=-1, y=0, z=-0.0}},
    {pos = {x=-1, y=0, z=-0.0}},
    {pos = {x=-1, y=0, z=-0.0}},
    {pos = {x=-1, y=0, z=-1.0}},
    {pos = {x=-1, y=0, z=-1.0}},
    {pos = {x=0, y=0, z=-1}},
    {pos = {x=0, y=0, z=-1}},
    {pos = {x=1, y=0, z=0}},
    {pos = {x=1, y=0, z=0}},
    {pos = {x=1, y=0, z=0}}}
}
function AIStateEmergency:enter()
    local entity = self:getEntity()
    entity.isMoving = true
    self.endTime = World.Now() + 10
    stateIndex = 0
    self.buff = entity:addBuff("myplugin/ai_emergency")
    startAngle = entity:data("aiData").needEmergency
    self.control:setTargetPos(Lib.tov3(entity:getPosition()) + startAngle * 5, true)
    -- local angle = Lib.v3AngleXZ(startAngle)
    -- self.dirList = {list = {}}
    -- for index, obj in pairs(dirList.list) do
    --     local pos = obj.pos
    --     self.dirList.list[#]
    --     Lib.posAroundYaw(pos, angle)
    -- end
end

function AIStateEmergency:_update()
    stateIndex = stateIndex + 1
    if stateIndex == 1 then
        return self.endTime - World.Now()
    end
    local entity = self:getEntity()
    startAngle = entity:data("aiData").needEmergency
    local angle = 360 - Lib.v3AngleXZ(startAngle)
    print(stateIndex * 45 + angle)
    local z = 0.7 * math.sin(stateIndex * 45 + angle)
    local x = 0.7 * math.cos(stateIndex * 45 + angle)
    local pos = Lib.tov3({
        x = x,
        y = 0,
        z = z
    })
    if stateIndex == 2 then
        basePos = Lib.tov3(entity:getPosition())
        basePos = basePos - pos
    end
    pos = basePos + pos
    self.control:setTargetPos(pos, true)
    if stateIndex <= 9 then
        return 8
    end
    if stateIndex == 10 then
       self.control:setTargetPos(Lib.tov3(entity:getPosition()) + startAngle * 25, true)
       return 40
    end
    self.control:setAiData("needEmergency", nil)
    entity:removeBuff(self.buff)
    entity.isMoving = false
end

function AIStateEmergency:update()
    stateIndex = stateIndex + 1
    if stateIndex == 1 then
        return self.endTime - World.Now()
    end
    local entity = self:getEntity()
    if stateIndex == 2 then
        self.control:setTargetPosArray(dirList)
    end
    if stateIndex <= 6 then
        return 8
    end
    if stateIndex == 7 then
       self.control:setTargetPos(Lib.tov3(entity:getPosition()) + startAngle * 25, true)
       return 40
    end
    self.control:setAiData("needEmergency", nil)
    entity:removeBuff(self.buff)
    entity.isMoving = false
end
function AIStateEmergency:exit()
end
RETURN(AIStateEmergency)
