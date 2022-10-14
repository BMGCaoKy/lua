local AIEvaluator = require("entity.ai.ai_evaluator")
local AIStateBase = require("entity.ai.ai_state_base")

local AIStateChase = L("AIStateChase", Lib.derive(AIStateBase))
AIStateChase.NAME = "CHASE"

function AIStateChase:enter()
	local control = self.control
	local entity = control:getEntity()
	local enemy = control:aiData("enemy")
	control:setChaseTarget(enemy)
	local chaseSkill = control:aiData("chaseSkill")
	if chaseSkill and chaseSkill.fullName then
		if chaseSkill.cdTime then
			local skill = Skill.Cfg(chaseSkill.fullName)
			if skill:canCast({}, entity) then
				Skill.Cast(chaseSkill.fullName, {cdTime=chaseSkill.cdTime,needPre = true}, entity)
			end
		else
			Skill.Cast(chaseSkill.fullName, {needPre = true}, entity)
		end
	end
	self.endTime = World.Now() + (control:aiData("chaseInterval") or 20)
end

function AIStateChase:update()
	if AIEvaluator.CanAttackEnemy(self.control) then
		return
	end
	return self.endTime - World.Now()
end

function AIStateChase:exit()
	self.control:setChaseTarget(nil)
	self.endTime = nil
end

RETURN(AIStateChase)