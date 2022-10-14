
local SkillBase = Skill.GetType("Base")
local MeleeAttack = Skill.GetType("MeleeAttack")

MeleeAttack.isClick = true
MeleeAttack.range = 4
MeleeAttack.hurtDistance = World.cfg.meleeAttackHurtDistance or 0.1

function MeleeAttack:canCast(packet, from)
	if not packet.targetID or not from then
		return false
	end
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	local target = World.CurWorld:getEntity(packet.targetID)
	if (not target) or (not target:isValid()) or from:distance(target)>self.range then
		return false
	end
	if target:cfg().cantHurtAtMeleeAttack then
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

	packet.damage = from:doAttack({target = target, skill = self, originalSkillName = packet.name or self.fullName,
								   cause = "ENGINE_MELEE_ATTACK"}) or 0

    local v = Lib.v3(0,0,0)
	local self_useExpressionPropMap, from_useExpressionPropMap = self.useExpressionPropMap or {}, from:cfg().useExpressionPropMap or {}
	local hurtDistanceExpression = self_useExpressionPropMap.hurtDistanceExpression or from_useExpressionPropMap.hurtDistanceExpression
	local dis = hurtDistanceExpression and Lib.getExpressionResult(hurtDistanceExpression, {target = target, from = from, packet = packet}) or self.hurtDistance
    if dis ~= 0 then
        v = target:getPosition() - Lib.tov3(from:getPosition())
        v.y = 0
        v:normalize()
        v = v * dis
        v.y = dis
    end
    target:doHurt(v)
	SkillBase.cast(self, packet, from)
end
