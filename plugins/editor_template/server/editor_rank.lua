Rank.REQUEST_INTERVAL = 20 * 10	
local RedisHandler = require "redishandler"

function Rank.getRankKey(rankType, subId)
	-- print("Rank.getRankKey==============", rankType, subId)
	local cfg = Rank.GetSubRankCfgs(rankType)[subId]
	local curTime = os.time()
	local suffix = ""
	local sufType = cfg.keySufType
	if sufType == "LastDay" then
		suffix = ".day."..Lib.getDayStartTime(curTime - 86400)
	elseif sufType == "CurDay" then
		suffix = ".day."..Lib.getDayStartTime(curTime)
	elseif sufType == "LastWeek" then
		suffix = ".week."..Lib.getWeekStartTime(curTime - 86400 * 7)
	elseif sufType == "CurWeek" then
		suffix = ".week."..Lib.getWeekStartTime(curTime)
	elseif sufType == "LastMonth" then
		suffix = ".month."..Lib.getMonthStartTime(Lib.getMonthEndTime(curTime) + 1)
	elseif sufType == "CurMonth" then
		suffix = ".month."..Lib.getMonthStartTime(curTime)
	elseif sufType == "Hist" then
		suffix = ".hist"
	end
	local keyPrefix = World.GameName .. ".gameTime"
	return keyPrefix .. suffix
end