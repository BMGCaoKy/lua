require "common.skill.skill_missile"
local SkillBase = Skill.GetType("Base")
local SkillMissile = Skill.GetType("Missile")

local handleTarget = SkillMissile.handleTarget

function handleTarget.BodyYaw(skillMissileInstance,packet, from)
	if not from or not from:isValid() then
		return false
	end
	return skillMissileInstance.handleTarget.FromBodyYaw(skillMissileInstance,packet, from, packet.fromBodyYaw) -- server has not getBodyYaw, body need client gave.
end

handleTarget.FrontEntity = handleTarget.Entity	-- 服务器暂无自动找人需求，客户端找就可以了

function SkillMissile:getStartPos(from)
    if not from or not from:isValid() then
        return false
    end
	if self.startFrom=="foot" then
		return from:getPosition()
	end
	return from:getEyePos()
end

function SkillMissile:cast(packet, from)
	packet.targetPos = packet.aimPos or packet.targetPos
	if not packet.targetPos then
		local func = assert(handleTarget[self.targetType], self.targetType)
		if not func(self, packet, from) then
			return false
		end
	end
	if not packet.startPos then
		packet.startPos = self:getStartPos(from)
		if not packet.startPos then
			return false
		end
	end
	local cast = Missile.SkillCast(packet, from, self)
	from:data("main").lastMissiles = cast.missiles
	SkillBase.cast(self, packet, from)
end
