
local SkillBase = Skill.GetType("Base")
local MultiStageSkill = Skill.GetType("MultiStage")

require "common.skill.multistage"

MultiStageSkill.startAction = ""
MultiStageSkill.sustainAction = ""
MultiStageSkill.castAction = ""

function MultiStageSkill:preCast(packet, from)
	local cfg = self:getStageCfg(from)
	if not cfg or not cfg.preCast then
		return
	end
	local skill = Skill.Cfg(cfg.skill)
	if skill then
		skill:preCast(packet, from)
	end
end

function MultiStageSkill:singleCast(packet, from)
	local cfg = self:getStageCfg(from)
	if not cfg then
		return
	end
	local skill = Skill.Cfg(cfg.skill)
	if skill then
		skill:cast(packet, from)
	end

	local nextStage = from:data("skill").multiStageData.nextStage + 1
	local data = nil
	local cdTime = self.cdTime
	if nextStage <= #self.stages then
		data = {
			skill = self.fullName,
			waitEnd = World.Now() + cfg.castTime + cfg.waitTime,
			nextStage = nextStage,
		}
		cdTime = cfg.castTime
	end
	if self.cdKey then
		packet.cdTime = cdTime
		from:setCD(self.cdKey, cdTime)
	end
	from:data("skill").multiStageData = data
end
