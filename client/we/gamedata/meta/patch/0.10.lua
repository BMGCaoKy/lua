local meta = {
	{
		type = "EntityCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.moveSpeed = oval.moveSpeed * 20
			ret.jumpSpeed = oval.jumpSpeed * 20
			ret.gravity = oval.gravity * 20
			ret.dropDamageStart = oval.dropDamageStart * 20
			ret.swimSpeed = oval.swimSpeed * 20
			return ret
		end
	},
	{
		type = "BlockCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.maxFallSpeed = oval.maxFallSpeed * 20
			ret.climbSpeed = oval.climbSpeed * 20
			ret.maxSpeed = oval.maxSpeed ~= 10000 and oval.maxSpeed * 20 or 10000
			return ret
		end
	},
	{
		type = "BuffCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.moveSpeed = oval.moveSpeed * 20
			ret.jumpSpeed = oval.jumpSpeed * 20
			ret.moveAcc = oval.moveAcc * 20
			ret.gravity = oval.gravity * 20
			ret.antiGravity = oval.antiGravity * 20
			return ret
		end
	},
	{
		type = "MissileCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.moveSpeed = oval.moveSpeed * 20
			ret.moveAcc = oval.moveAcc * 20
			ret.gravity = oval.gravity * 20
			ret.rotateSpeed = oval.rotateSpeed * 20
			return ret
		end
	}
}

return {
	meta = meta
}