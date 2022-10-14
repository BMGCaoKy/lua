local SkillBase = Skill.GetType("Base")
local Charge = Skill.GetType("Charge")

Charge.chargeType = "Bow"
Charge.minSustainTime = 10
Charge.maxSustainTime = 50
Charge.isTouch = true
Charge.startAction = ""
Charge.sustainAction = "aim2"
Charge.castAction = "aim3"

local chargeType = {}

local startTime = 0
local sustainTime = 0
local timer = nil
local orig_handModel = nil
local cur_nSeg = 0

local function skillReset(from)
    if timer then
        timer()
    end
    if orig_handModel and from then
        local sloter = from:getHandItem()
        if not sloter then
            return
        end
        from:updateHoldModel(orig_handModel and orig_handModel:model())
    end
    timer = nil
    orig_handModel = nil
    startTime = 0
    sustainTime = 0
    cur_nSeg = 0
end

function chargeType:Bow(packet, from)
    local sloter = from:getHandItem()
    if self.handItem and not (sloter and sloter:cfg().fullName == self.handItem) then
        return false
    end
    return true
end

function Charge:getTouchTime(packet, from)
    if not SkillBase.canCast(self, packet, from) then
        return false
    end
    local func = assert(chargeType[self.chargeType], self.chargeType)
    if not func(self, packet, from) then
        return false
    end
    return self.maxSustainTime or 50
end

function Charge:start(packet, from)
    startTime = World.Now()
    timer = from:timer(1, self.sustain, self, packet, from)
    SkillBase.sustain(self, packet, from)
end

function Charge:sustain(packet, from)
    local sloter = from:getHandItem()
    if not orig_handModel then
        orig_handModel = sloter
    end
    sustainTime = math.min(World.Now() - startTime, packet.touchTime)
    local iconArray = sloter and sloter:icon_array()
    if not iconArray then
        return false
    end
    if not (type(iconArray) == "table" and #iconArray > 0) then
        return false
    end
    local nSeg = math.ceil(sustainTime / (packet.touchTime / #iconArray))
    if cur_nSeg == nSeg then
        return true
    end
    cur_nSeg = nSeg
    local itemName = iconArray[cur_nSeg]
    assert(itemName)
    local modId = ResLoader:loadModel(sloter:cfg(), itemName)
    if modId then
        from:updateHoldModel(modId)
    end
    if sustainTime >= packet.touchTime then
        return false
    end
    return true
end

function Charge:stop(packet, from)
    if self.aimTarget then
        packet.aimPos = Lib.getRayTarget() --计算瞄准方向
    end
    SkillBase.stop(self, packet, from)
    packet.sustainTime = math.min(World.Now() - startTime, self.maxSustainTime)
    local minTime = self.minSustainTime
    if minTime and packet.sustainTime < minTime then
        --todo 中途停止技能
        --SkillBase.stop(self, packet, from)
        --return
    end
    skillReset(from)
    if Blockman.instance.singleGame then
        Skill.DoCast(self, packet, from)
    end
end

function Charge:cast(packet, from)
    SkillBase.preCast(self, packet, from)
    skillReset(from)
end