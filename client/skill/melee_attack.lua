---@type SkillBase
local SkillBase = Skill.GetType("Base")
---@class MeleeAttack
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

local function checkActionPriority(upperAction)
	if type(upperAction)~="string" then
		return true
	end
	if upperAction:find("idle") then
		return true
	end
	return false
end

function MeleeAttack:cast(packet, from)
	local target = World.CurWorld:getEntity(packet.targetID)
	if not target then
		return
	end
	if not from:canAttack(target) then
        return false
	end
	local v = Lib.v3(0, 0, 0)
	local self_useExpressionPropMap, from_useExpressionPropMap = self.useExpressionPropMap or {}, from:cfg().useExpressionPropMap or {}
	local hurtDistanceExpression = self_useExpressionPropMap.hurtDistanceExpression or from_useExpressionPropMap.hurtDistanceExpression
	local dis = hurtDistanceExpression and Lib.getExpressionResult(hurtDistanceExpression, {target = target, from = from, packet = packet}) or self.hurtDistance
	if dis ~= 0 and target:isControl() then
		v = target:getPosition() - Lib.tov3(from:getPosition())
		v.y = 0
		v:normalize()
		v = v * dis
		v.y = dis
		Skill.BreakSwingByMove(target,true)
	end
	local cfg = target:cfg()
	target:doHurt(v)
	target:playSound(cfg.hurtSound)
	local upperAction = target:getBaseAction()
	local hurtAction = cfg.hurtAction
	local action = hurtAction and hurtAction.action
	if action and action ~= "" and checkActionPriority(upperAction) then
		target:updateUpperAction(action, hurtAction.time, false)
	end
	SkillBase.cast(self, packet, from)
end