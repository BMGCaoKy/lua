
local self = Rank
local needReq = {}

function Rank.Init()
	self.rankDatas = {}
	self.myRanks = {}
	self.myScores = {}
	self.newMyScores = {}
	self.RanksList = {}
end

function Rank.RequestRankData(requestType)
	local CurPlayer = Player.CurPlayer
	if not CurPlayer then
		return
	end
    for _, rankCfg in pairs(World.cfg.ranks or {}) do
		local rankType = rankCfg.type or 0
		if not requestType or rankType == requestType then
			CurPlayer:sendPacket({ pid = "RankData", rankType = rankType })

			if rankType then 
				needReq[rankType] = false
			else
				needReq = {}
			end
        end
    end
end

function Rank.ReceiveRankData(packet)
	local rankType = packet.rankType
    --print("Rank.ReceiveRankData", rankType)    
	self.rankDatas[rankType] = packet.rankData
	self.myRanks[rankType] = packet.myRanks
	self.myScores[rankType] = packet.myScores
	Lib.emitEvent(Event.EVENT_RECEIVE_RANK_DATA, rankType)
end

function Rank.GetRankData(rankType)
    return self.rankDatas[rankType] or {}
end

function Rank.GetMyRanks(rankType)
    return self.myRanks[rankType] or {}
end

function Rank.GetMyScores(rankType)
    return self.myScores[rankType] or {}
end

function Rank.GetRankReward(rankType, subId)
	for _, cfg in pairs(World.cfg.ranks or {}) do
		if (cfg.type or 0) == rankType then
			local sub = cfg.subRanks and cfg.subRanks[subId]
			assert(sub, subId)
			return sub.clearingReward
		end
	end
end

function Rank.RequestRankReward(rankType, subId, index, func)
	local CurPlayer = Player.CurPlayer
	if not CurPlayer then
		return
	end
	local packet = {
		pid = "RequestRankReward",
		rankType = rankType,
		subId = subId,
		index = index
	}
	CurPlayer:sendPacket(packet, func)
end

function Rank.RankDataDirty(rankType)
	needReq[rankType] = true
    Lib.emitEvent(Event.EVENT_RANK_DATA_DIRTY, rankType)
end

function Rank.NeedReq(rankType)
	return needReq[rankType] ~= false
end
