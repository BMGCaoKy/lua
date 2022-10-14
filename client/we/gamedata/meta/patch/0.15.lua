local meta = {
	{
		type = "GameCfg",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.player_range = {min = ret.minPlayers, max = ret.maxPlayers}
			local time = oval.nowTime * 3600
			local time_h = math.floor(time / 3600)
			time = time - time_h * 3600
			local time_m = time > 0 and math.floor(time / 60) or 0
			time = time - time_m * 60
			local time_s = time > 0 and math.floor(time) or 0
			ret.nowTime ={h = time_h, m = time_m, s = time_s}

			ret.initPos = ctor("MapPos",ret.initPos)
			ret.startPos = ctor("MapPos",ret.startPos)
			return ret
		end
	},
	{
		type = "Region",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.pos = ctor("MapPos",ret.pos)
			return ret
		end
	},
	{
		type = "Team",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.initPos = ctor("MapPos",ret.initPos)
			ret.startPos = ctor("MapPos",ret.startPos)
			return ret
		end
	}
}

return {
	meta = meta
}
