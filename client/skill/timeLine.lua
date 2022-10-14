local SkillBase = Skill.GetType("Base")
local SkillTimeLine = Skill.GetType("TimeLine")
SkillTimeLine.castAction = ""

require "common.skill.timeLine"
local handleTarget = SkillTimeLine.handleTarget or {}
local behavior = SkillTimeLine.behavior or {}
local bm = Blockman.Instance()
local lastControl = L("lastControl", {})

local function hasPos(self, time)
    for _, line in pairs(self.timerLine) do
        if line.time > time and line.behavior == "Pos" then
            return line
        end
    end
end

function handleTarget:AddValue(packet, from)
    packet.targetDir = Lib.v3add(from:getPosition(), packet.linePos.value)
    return true
end

function handleTarget:None(packet, from)
    local yaw = (360 - from:getBodyYaw() + 90) % 360
    local pos = Lib.tov3(Lib.copy(packet.linePos.value))
    local new_off_x, new_off_y = pos.x, pos.z
    local arc1 = math.atan(new_off_y, -new_off_x)
    local deg1 = math.deg(arc1)
    local deg2 = yaw - (360 - deg1 + 90) % 360
    local arc2 = math.rad(deg2)
    local len = (new_off_x ^ 2 + new_off_y ^ 2) ^ 0.5
    local offx = len * math.cos(arc2)
    local offy = len * math.sin(arc2)
    pos.x = -offx
    pos.z = offy
    packet.targetDir = from:getPosition() + pos
    return true
end

function handleTarget:Target(packet, from)
    local vals = Lib.copy(packet.linePos)
    local targetId = from:data("targetId")
    if not tonumber(targetId) then
        return false
    end
    local target = World.CurWorld:getEntity(targetId)
    if not target then
        return false
    end
    local distance = from:distance(target)
    if vals.range < distance then
        return false
    end
    local d = Lib.tov3(target:getPosition()) - from:getPosition()
    local yaw = math.atan(d.z, d.x)
    from:setBodyYaw(math.deg(yaw) - 90)
    from:setRotationYaw(math.deg(yaw) - 90) 
    return false
end

local function resetControl(obj)
    local nowControl = bm:control()
    if not nowControl or lastControl.entity ~= nowControl.entity then 
        -- 玩家有了新的control 不再受原有timeLine的影响
        return
    end
    if not obj.isEntity then 
        nowControl.enable = false
        return
    end
    local target = World.CurWorld:getEntity(obj.rideOnId)
    if not target then 
        nowControl.enable = true
        return
    end
    PlayerControl.UpdateControlInfo(target)
end

function behavior:Pos(packet, from, vals)
    local timerLineData = from:data("skill").timerLineData
    if not packet.linePos then
        resetControl(from)
        packet.linePos = hasPos(self, timerLineData.time)
        return
    end
    local func = assert(handleTarget[self.targetType], self.targetType)
    if not func(self, packet, from) then
        handleTarget.None(self, packet, from)
    end
    if not from:isControl() then
        return
    end
    --todo 进行位移控制
    lastControl = bm:control()
    bm:control().enable = false
    local forceDelayTime = vals.forceDelayTime or 0
    local forceTime = vals.time - (packet.lastLinePos and packet.lastLinePos.time or 0) - forceDelayTime
    World.Timer(forceDelayTime, function()
		from:setForceMove(packet.targetDir, forceTime, self.isSimpleMove)
    end)
    packet.lastLinePos = vals
end

function behavior:Skill(packet, from, vals)
    if vals.value and from:isControl() and (vals.serverCast == nil or vals.serverCast == false) then
        Skill.Cast(vals.value, { }, from)
    end
end

function SkillTimeLine:endRun(packet, from)
    if not from:isControl() then
        return
    end
    resetControl(from)
end