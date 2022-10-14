
function  Missile:onHitBlock(pos)
	local cfg = self:cfg()
	local targetPos = self:lastHitBlock()
	self:castSkill(cfg.hitBlockSkill or cfg.hitSkill, {targetPos = targetPos})
	self:castEffect(cfg.hitEffect)
	self:playSound(cfg.hitBlockSound or cfg.hitSound, cfg, true)
	local hitBlockCount = self.hitBlockCount + 1
	self.hitBlockCount = hitBlockCount
	if (cfg.hitBlockCount and hitBlockCount >= cfg.hitBlockCount) or (cfg.hitCount and (hitBlockCount + self.hitEntityCount) >= cfg.hitCount)then
		self:vanish()
	end
    local blockcfg = self.map:getBlock(targetPos)
	if blockcfg.canHitBreak  then
		self.map:removeBlock(targetPos)
		if World.isClient and blockcfg.hitBreakEffect then
			Blockman.instance:playEffectByPos(blockcfg.hitBreakEffect.effect, targetPos, 0 ,500)
		end
	end
end