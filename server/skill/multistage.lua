
local SkillBase = Skill.GetType("Base")
local MultiStageSkill = Skill.GetType("MultiStage")

require "common.skill.multistage"

MultiStageSkill.broadcast = false

function MultiStageSkill:cast(packet, from)
	if not self:canCast(packet, from) then
		return false
	end
	SkillBase.cast(self, packet, from)
	local cfg, index = self:getStageCfg(from)
	packet.needPre = not cfg.preCast
	Skill.Cast(cfg.skill, packet, from)

	local nextStage = index + 1
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
	if from.isPlayer then
		from:lightTimer("SendMultiStageSkillData", 1, function ()
			from:sendPacket({ pid = "MultiStageSkillData", data = data })
		end)
	end
end
