
local SkillBase = Skill.GetType("Base")
local RaySkill = Skill.GetType("Ray")

function RaySkill:triggerBlock(result, from)
    local map = World.CurWorld:getMapById(result.mapId)
    if not map or not map:isValid() then
        return
    end
    local cfg = map:getBlock(result.blockPos)
    Trigger.CheckTriggersOnly(cfg, "BLOCK_HITTED_BY_RAY", {pos = result.blockPos, obj1 = from})
    Trigger.CheckTriggersOnly(from:cfg(), "HIT_BLOCK_BY_RAY", {pos = result.blockPos, obj1 = from})
end

function RaySkill:triggerEntity(result, from)
    local target = from.world:getObject(result.objID)
    if not target then
        return
    end
    Trigger.CheckTriggersOnly(target:cfg(), "ENTITY_HITTED_BY_RAY", {obj1 = target, obj2 = from, hitHead = result.hitHead})
    Trigger.CheckTriggersOnly(from:cfg(), "HIT_ENTITY_BY_RAY", {obj1 = from, obj2 = target, hitHead = result.hitHead})
end

function RaySkill:cast(packet, from)
    SkillBase.cast(self, packet, from)
    local result = packet.result
    if not result then
        result = self:aiResult(packet, from)
    end
    
    local hitType = result.hitType
	local newPacket = {
		targetID = (hitType==1 and result.blockID) or (hitType==2 and result.objID),
		starPos = result.hitPos,
		autoCast = true,
		targetPos = result.hitPos
	}
	if hitType==1 then
        self:triggerBlock(packet.result, from)
		local hitBlockSkill = self.hitBlockSkill
		if hitBlockSkill then
			Skill.Cast(hitBlockSkill, newPacket, from)
		end
	elseif hitType==2 then
        self:triggerEntity(packet.result, from)
		local hitEntitySkill = self.hitEntitySkill
		local hitEntityHeadSkill = self.hitEntityHeadSkill
		if result.hitHead and hitEntityHeadSkill then
			Skill.Cast(hitEntityHeadSkill, newPacket, from)
		elseif hitEntitySkill then
			Skill.Cast(hitEntitySkill, newPacket, from)
		end
	end
end

function RaySkill:aiResult(packet, from)
    local result = {}
    result.hitType = 2
    result.hitHead = false
    local _hitPos = packet.targetPos
    local randomY = math.random(0, 1)
    if randomY >= 0.8 then
        result.hitHead = true
    end
    _hitPos.y = _hitPos.y + randomY
    result.hitPos = _hitPos
    result.objID = packet.targetID
    result.duration = 500
    result.yaw = from:getRotationYaw()
    result.aiRay = true
    result.trajectoryPos = packet.startPos
    return result
end