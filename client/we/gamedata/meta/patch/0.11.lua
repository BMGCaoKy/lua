local meta = {
	{
		type = "EntityCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.deadSound = ctor("CastSound", ret.deadSound)
			return ret
		end
	}
}

return {
	meta = meta
}
