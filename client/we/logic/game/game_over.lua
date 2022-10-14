local Meta = require "we.gamedata.meta.meta"
local VN = require "we.gamedata.vnode"
local M = {}
function M.GameOverRank( self )
	if self.gameOverCondition == "TimeOut" then
		self.rankBase = VN.new("RankTimeOut", {}, false)
	elseif self.gameOverCondition == "KillAllEnemy" then	
		self.rankBase = VN.new("RankKillAllEnemy", {}, false)
	elseif self.gameOverCondition == "KillSomePlayers" then	
		self.rankBase = VN.new("RankKillSomePlayers", {}, false)
	elseif self.gameOverCondition == "ReachEndArea" then	
		self.rankBase = VN.new("RankReachEndArea", {}, false)
	elseif self.gameOverCondition == "CollectSomeItems" then	
		self.rankBase = VN.new("RankCollectSomeItems", {}, false)
	elseif self.gameOverCondition == "GetSomePoints" then
	    self.rankBase = VN.new("RankGetSomePoints", {}, false)	
	end
end
return M