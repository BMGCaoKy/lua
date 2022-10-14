
local SkillBase = Skill.GetType("Base")
local MeleeAttack = Skill.GetType("MeleeAttack")

MeleeAttack.isClick = true
MeleeAttack.range = 3.5
MeleeAttack.hurtDistance = 0.1
MeleeAttack.hurtYDistance = 0.02
function MeleeAttack:canCast(packet, from)
	if not packet.targetID or not from then
		return false
	end
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	local target = World.CurWorld:getEntity(packet.targetID)
	if from:distance(target)>self.range then
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
	local v = Lib.v3(0, 0, 0)
	if self.hurtDistance ~= 0 and target:isControl() then
		v = target:getPosition() - Lib.tov3(from:getPosition())
		v.y = 0
		v:normalize()
		v = v * self.hurtDistance
		v.y = self.hurtDistance * self.hurtYDistance + 0.15
	end
	local cfg = target:cfg()
	target:doHurt(v)
	if packet.targetCurHp and packet.targetCurHp > 0 then
		target:playSound(self.hurtSound)
		target:playSound(cfg.hurtSound)
	end
	local upperAction = target:getBaseAction()
	local hurtAction = cfg.hurtAction
	local action = hurtAction and hurtAction.action
	if action and action ~= "" and checkActionPriority(upperAction) then
		target:updateUpperAction(action, hurtAction.time, false)
	end
	SkillBase.cast(self, packet, from)
end