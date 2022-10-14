
local RankRequestCDTime = 5

function Player:initRank()
	for _, cfg in pairs(World.cfg.ranks or {}) do
		if cfg.type ~= "local" and cfg.type ~="world" then
			self:requestRankInfo(cfg.type or 0)
		end
	end
end

function Player:getRankScore(rankType, subId)
    local key = Rank.getRankKey(rankType, subId)
	local scoreRecord = self:data("rankScoreRecord")
    return scoreRecord[key] or 0
end

function Player:addRankScore(rankType, subId, score)
	local old = self:getRankScore(rankType, subId)
	self:updateRankScore(rankType, subId, old + score)
end

function Player:updateRankScore(rankType, subId, score)
	local key = Rank.getRankKey(rankType, subId)
	local scoreRecord = self:data("rankScoreRecord")
	local old = scoreRecord[key]
	local add = score - (old or 0)
	local cfg = Rank.GetSubRankCfg(rankType, subId)
	local orderByDesc = cfg.orderByDesc
	if old and ((not orderByDesc and add <= 0) or (orderByDesc and add >= 0)) then
		return
	end
	scoreRecord[key] = score
	-- print("player:updateRankScore", self.platformUserId, rankType, subId, orderByDesc, add)
    Rank.UserAddScore(self.platformUserId, rankType, subId, orderByDesc and -add or add)
	local requestTimers = self:data("requestRankTimers")
	local timer = requestTimers[rankType]
	if timer then
		timer()
	end
	requestTimers[rankType] = self:timer(20 * 10, self.requestRankInfo, self, rankType)	
end

function Player:requestRankInfo(rankType)
	local curTime = os.time()
	local reqTime = self:data("rankReqTime")
	if curTime - (reqTime[rankType] or 0) < RankRequestCDTime then
		return
	end
	local cfgs = Rank.GetSubRankCfgs(rankType)
	assert(cfgs, rankType)
    self:data("rankRecord")[rankType] = #cfgs	-- need to wait sub rank data
	local userId = self.platformUserId
	for subId in pairs(cfgs) do
		Rank.RequestUserRankInfo(userId, rankType, subId)
	end
	reqTime[rankType] = curTime
end

function Player:receiveRankInfo(rankType, subId, rank, score)
	local key = Rank.getRankKey(rankType, subId)
	--print("Player:receiveRankInfo", rankType, subId, key, rank, score)
	local scoreRecord = self:data("rankScoreRecord")
	local record = scoreRecord[key] or 0
	local cfg = Rank.GetSubRankCfg(rankType, subId)
	local orderByDesc = cfg.orderByDesc
	if (not orderByDesc and score > record) or (orderByDesc and score < record) then
		scoreRecord[key] = orderByDesc and -score or score	-- TODO
	end

	local rankDatas = self:data("rankDatas")
	local rankData = rankDatas[rankType]
	if not rankData then
		rankData = {}
		rankDatas[rankType] = rankData
	end
	rankData[subId] = {
		type = rankType,
		subId = subId,
		rank = rank,
		score = score,
	}
	-- sync
	local rankRecord = self:data("rankRecord")
	local record = (rankRecord[rankType] or 0) - 1
	if record < 0 then
		return
	elseif record > 0 then
		rankRecord[rankType] = record
		return
	end
	rankRecord[rankType] = nil
	
	self:sendPacket({
        pid = "RankDataDirty",
        rankType = rankType
    })
end

function Player:syncRankData(rankType, retryTimes)
	if not rankType then
		for _, cfg in pairs(World.cfg.ranks or {}) do
			self:syncRankData(cfg.type or 0, retryTimes)
		end
		return
	end
	local syncTimers = self:data("syncRankTimers")
	local timer = syncTimers[rankType]
	if timer and not retryTimes then
		return
	end
	syncTimers[rankType] = nil
	if self:trySyncRankData(rankType) then
		return
	elseif (retryTimes or 0) > 5 then
		print("Player:syncRankData retry times too much", self.platformUserId, rankType)
		return
	end
	syncTimers[rankType] = self:timer(20 * 5, self.syncRankData, self, rankType, (retryTimes or 0) + 1)
end

function Player:trySyncRankData(rankType)
	local rankData = Rank.GetRankData(rankType)
	if not rankData then
		return false
	end
	local myDatas = self:data("rankDatas")
	local myData = myDatas[rankType]
	if not myData then
		self:requestRankInfo(rankType)
		return false
	end
	local cfgs = Rank.GetSubRankCfgs(rankType)
	if not cfgs then
		return false
	end
	local myRanks, myScores = {}, {}
	local myUserId = self.platformUserId
	for subId in pairs(cfgs) do
		if cfgs[subId].clientPush == false then 
			goto continue
		end
		local subRank = rankData[subId] or {}
		local subData = myData[subId]
		if not subData then
			return false
		end
		local rank = subData.rank
		local data = subRank[rank]
		if not data or data.userId ~= myUserId then
			rank = 0
		end
		myRanks[subId] = rank
		local orderByDesc = cfgs[subId].orderByDesc and cfgs[subId].orderByDesc or false
		local score = subData.score
		myScores[subId] = not orderByDesc and score or -score
		::continue::
	end
	self:sendPacket({
        pid = "RankData",
        rankType = rankType,
        rankData = rankData,
        myRanks = myRanks,
        myScores = myScores,
    })
	return true
end

function Player:getMyRank(rankType, subId)
	local rankData = Rank.GetRankData(rankType) or {}
	local subData = rankData[subId] or {}
	for _, data in pairs(subData) do
		if data.userId == self.platformUserId then
			return data.rank
		end
	end
	return 0
end
