---@type SkillBase
local SkillBase = Skill.GetType("Base")
---@class Buff
local Buff = Skill.GetType("Buff")
 
function Buff:canCast(packet, from)
	if not from then
		return false
	end
	if self.target~="self" and not packet.targetID then
		return false
	end
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	return true
end

function Buff:preCast(packet, from)
	local target = from
	if self.target~="self" then
		target = World.CurWorld:getEntity(packet.targetID)
	end
	if target and target:tryAddClientOnlyBuff(self.buffCfg, self.buffTime) then
		packet.clientAdded = true
	end
	SkillBase.preCast(self, packet, from)
end

function Buff:singleCast(packet, from)
	local target = from
	if self.target~="self" then
		target = World.CurWorld:getEntity(packet.targetID)
	end
	if target and not packet.clientAdded then
		local self_useExpressionPropMap, from_useExpressionPropMap = self.useExpressionPropMap or {}, from:cfg().useExpressionPropMap or {}
		local buffTimeExpression = self_useExpressionPropMap.buffTimeExpression or from_useExpressionPropMap.buffTimeExpression
		local buffTime = buffTimeExpression and Lib.getExpressionResult(buffTimeExpression, {target = target, from = from, packet = packet}) or self.buffTime
		target:addBuff(self.buffCfg, buffTime)
	end
	SkillBase.singleCast(self, packet, from)
end
