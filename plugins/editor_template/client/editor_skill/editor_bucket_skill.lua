
local SkillBase = Skill.GetType("Base")
local Bucket = Skill.GetType("Bucket")

function Bucket:canCast(packet, from)
    if not packet.blockPos then
        return false
    end
    if Lib.getPosDistance(from:getPosition(), packet.blockPos) > 6 then
        return false
    end
    return SkillBase.canCast(self, packet, from)
end