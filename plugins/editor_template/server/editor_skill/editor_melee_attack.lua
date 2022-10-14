
local SkillBase = Skill.GetType("Base")
local MeleeAttack = Skill.GetType("MeleeAttack")

MeleeAttack.isClick = true
MeleeAttack.range = 3.5
MeleeAttack.hurtDistance = 0.1
MeleeAttack.hurtYDistance = 0.02

function MeleeAttack:canCast(packet, from)
	if from:cfg().canAttackObject == false then
		return false
	end
	if not packet.targetID or not from then
		return false
	end
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	local target = World.CurWorld:getEntity(packet.targetID)
	if not target then
		return false
	end
	if from:distance(target)>self.range then
		return false
	end
	return true
end

function MeleeAttack:cast(packet, from)
	local target = World.CurWorld:getEntity(packet.targetID)
	if not target then
		print("MeleeAttack wrong target!", packet.targetID)
		return
	end
	if not from:canAttack(target) then
        return false
	end

	from:doAttack({target = target, skill = self, originalSkillName = packet.name or self.fullName, cause = "ENGINE_MELEE_ATTACK"})

	packet.targetCurHp = target.curHp
    local v = Lib.v3(0,0,0)
    if self.hurtDistance ~= 0 and target:isControl() then
		v = target:getPosition() - Lib.tov3(from:getPosition())
		v.y = 0
		v:normalize()
		v = v * self.hurtDistance
		v.y = self.hurtDistance * self.hurtYDistance + 0.15
	end
	if target:cfg().maxRepelInterVar then
		local lastRepelTime = target:data("main").lastRepelTime
		if not lastRepelTime or World.Now() - lastRepelTime > target:cfg().maxRepelInterVar then
			target:doHurt(v)
			target:data("main").lastRepelTime = World.Now()
		end
	else
		target:doHurt(v)
	end
	
	if target.ft then
		target.ft()
	end
	local count = self.hurtDistance // 3
	target.ft = target:timer(1, function()
		if count <= 0 then
			target.ft = nil
			return false
		end
		count = count - 1
		v.y = 0.1
		target:doHurt(v)
		return true
	end)
	SkillBase.cast(self, packet, from)
end
