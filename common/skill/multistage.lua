
local SkillBase = Skill.GetType("Base")
local MultiStageSkill = Skill.GetType("MultiStage")

function MultiStageSkill:getStageCfg(from)
	local lastStage = from:data("skill").multiStageData
	local index = 1
	if lastStage and lastStage.skill == self.fullName and lastStage.waitEnd >= World.Now() then
		index = lastStage.nextStage
	end
	return self.stages[index], index
end

function MultiStageSkill:canCast(packet, from)
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	local cfg = self:getStageCfg(from)
	if not cfg then
		return
	end
	local skill = Skill.Cfg(cfg.skill)
	return skill and skill:canCast(packet, from) or false
end
