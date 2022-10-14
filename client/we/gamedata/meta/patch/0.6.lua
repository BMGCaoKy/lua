local meta = {
	{
		type = "EntityCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.AI_home = {
				homeSize = oval.homeSize
			}
			ret.AI_attack = {
				attackMode = oval.autoAttack and "autoAttack" or "hitBack",
				targetType = oval.attackNpc and "player" or "any",
				chaseDistance = oval.chaseDistance,
				skillList = oval.skillList
			}
			ret.AI_patrol = {
				patrolDistance = oval.patrolDistance,
				idle = {
					prob = oval.idleProb,
					idleTime = oval.idleTime
				}
			}
			return ret
		end
	}
}

for _, patch in ipairs(meta) do
	patch.value = string.dump(patch.value)
end

return {
	meta = meta
}
