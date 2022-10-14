local SkillBase = Skill.GetType("Base")
local Charge = Skill.GetType("Charge")

Charge.chargeType = "Bow"
Charge.computeType = "Default"
Charge.minSustainTime = 10
Charge.maxSustainTime = 50
Charge.isTouch = true

local chargeType = {}
local computeType = {}

local startTime = 0

function chargeType:Bow(packet, from)
    local sloter = from:getHandItem()
    if self.handItem and not (sloter and sloter:cfg().fullName == self.handItem) then
        return false
    end
    return true
end

function computeType:Default(packet, from)
    local scale = packet.touchTime and packet.sustainTime / packet.touchTime or 0
    packet.moveSpeed = 0.8 + scale
    packet.gravity = math.max(0.12 - 0.02 * 9 * scale, 0.025)
end

function computeType:Compute(packet, from)
    --todo 自定义计算方式
end

function Charge:getTouchTime(packet, from)
    local func = assert(chargeType[self.chargeType], self.chargeType)
    if not func(self, packet, from) then
        return false
    end
    return self.maxSustainTime or 50
end

function Charge:canCast(packet, from)
    local func = assert(chargeType[self.chargeType], self.chargeType)
    if not func(self, packet, from) then
        return false
    end
    if not SkillBase.canCast(self, packet, from) then
        return false
    end
    return true
end

function Charge:cast(packet, from)
    local func = assert(computeType[self.computeType], self.computeType)
    if not packet.sustainTime then
        packet.sustainTime = math.min(World.Now() - startTime, self.maxSustainTime)
    end
    func(self, packet, from)
    if self.skillName then
         Skill.Cast(self.skillName, packet, from)
    end
    SkillBase.cast(self, packet, from)
end

function Charge:start(packet, from)
    startTime = World.Now()
end

function Charge:stop(packet, from)
    packet.sustainTime = math.min(World.Now() - startTime, self.maxSustainTime)
    local minTime = self.minSustainTime
    if minTime and packet.sustainTime < minTime then
        --todo 中途停止技能
        --return
    end
    if self:canCast(packet, from) then
        Skill.DoCast(self, packet, from)
    end
end