local SkillBase = Skill.GetType("Base")
local BuildSchematic = Skill.GetType("BuildSchematic")

BuildSchematic.isClick = true

function BuildSchematic:canCast(packet, from)
    local ownerPlatformUserId = from.map.ownerPlatformUserId
    if ownerPlatformUserId ~= from.platformUserId then
        if not from:isFriendShip(ownerPlatformUserId) then
            return false
        end
    end

    if not packet.cfg then
        return false
    end

    if not packet.cfg.schematicFullName then
        return false
    end

    return true
end

function BuildSchematic:cast(packet, from)
    SkillBase.cast(self, packet, from)
end