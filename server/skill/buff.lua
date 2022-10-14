---@type SkillBase
local SkillBase = Skill.GetType("Base")
---@type Buff
local Buff = Skill.GetType("Buff")

function Buff:cast(packet, from)
	local target = from
	if self.target~="self" then
		target = World.CurWorld:getEntity(packet.targetID)
	end
	if not target then
		print("Buff wrong target!", packet.targetID)
		return
	end
	local self_useExpressionPropMap, from_useExpressionPropMap = self.useExpressionPropMap or {}, from:cfg().useExpressionPropMap or {}
	local buffTimeExpression = self_useExpressionPropMap.buffTimeExpression or from_useExpressionPropMap.buffTimeExpression
	local buffTime = buffTimeExpression and Lib.getExpressionResult(buffTimeExpression, {target = target, from = from, packet = packet}) or self.buffTime
	target:addBuff(self.buffCfg, buffTime,from)
	SkillBase.cast(self, packet, from)
end
