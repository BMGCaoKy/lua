local RedisHandler = require "redishandler"

local tunpack = table.unpack
local tonumber = tonumber
local pairs = pairs

local self = Rank
Rank.REQUEST_INTERVAL = 20 * 90	-- 90 seconds

local rank_sort = require "rank_class"
Rank.rankList = {}
Rank.rankNameMap = {}

function Rank.Init()
	local rankDatas = {}
	local rankTypes = {}
	for _, rankCfg in pairs(World.cfg.ranks or {}) do
		local rankType = rankCfg.type or 0
		local npc = rankCfg.npc
		if npc then
			local entity = EntityServer.Create(npc)
			entity:data("main").rankType = rankType
		end

		rankDatas[rankType] = {}
		for subId, cfg in pairs(rankCfg.subRanks) do
			if rankType == "local" or rankType == "world" then  --create new rank
				local rank = Lib.derive(rank_sort)
				rank:init(cfg.comparedata, {maxLen = cfg.size})
				rank.Local = rankType == "local"
				Rank.rankList[cfg.rankName] = rank
				Rank.rankNameMap[cfg.rankName] = {rankType, subId} 
				--TODO If type == World
			else
				local key = Rank.getRankKey(rankType, subId)
				--assert(not rankTypes[key], key)
				rankTypes[key] = {rankType, subId}

				local expireTime = Rank.getRankExpireTime(rankType, subId)
				if expireTime then
					RedisHandler:ZExpireat(key, expireTime)
				end
			end
		end
	end
	self.rankDatas = rankDatas		-- [type] = { rankdata1, rankdata2, ... }
	self.rankTypes = rankTypes		-- [key] = {rankType, subId}
	self.rankRecord = {}			-- [type] = wait count

	self.RequestRankData()
	self.requestRankTimer = World.Timer(self.REQUEST_INTERVAL, Rank.RequestRankData)

end

function Rank.UpdateRankData(params)
	local rank = params.rank or Rank.rankList[params.rankName]
	if rank and rank.Local and params.id then
		local tb = params.addList or {}
		if params.key then
			tb[params.key] = params.val
		end
		local upData = {}
		for key,score in pairs(tb) do
			upData[key] = score
		end
		rank:UpdataRanks(params.id, upData)
	elseif rank and not rank.Local and params.id then
		--TODO WORLD RANK
	end	
end

function Rank.getRankScore(rankName, id)
	return Rank.rankList[rankName].queryData(id)
end

function Rank.getRankKey(rankType, subId)
	local cfg = Rank.GetSubRankCfgs(rankType)[subId]
	--print("Rank.getRankKey", rankType, subId, cfg)
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
	return cfg.keyPrefix .. suffix
end

function Rank.getRankExpireTime(rankType, subId)
	local cfg = Rank.GetSubRankCfgs(rankType)[subId]
	local curTime = os.time()
	local expireTime = nil
	local expireType = cfg.expireType
	if expireType == "CurDay" then
		expireTime = Lib.getDayEndTime(curTime)
	elseif expireType == "NextDay" then
		expireTime = Lib.getDayEndTime(curTime + 86400)
	elseif expireType == "CurWeek" then
		expireTime = Lib.getWeekEndTime(curTime)
	elseif expireType == "NextWeek" then
		expireTime = Lib.getWeekEndTime(curTime + 86400 * 7)
	elseif expireType == "CurMonth" then
		expireTime = Lib.getMonthEndTime(curTime)
	elseif expireType == "NextMonth" then
		expireTime = Lib.getMonthEndTime(Lib.getMonthEndTime(curTime) + 1)
	elseif expireType == "Hist" then
		expireTime = false
	end
	return expireTime
end

function Rank.GetSubRankCfgs(rankType)
	for _, cfg in pairs(World.cfg.ranks or {}) do
		if (cfg.type or 0) == rankType then
			return cfg.subRanks
		end
	end
end

function Rank.GetSubRankCfg(rankType, subId)
	local cfgs = Rank.GetSubRankCfgs(rankType)
	return cfgs and cfgs[subId] or nil
end

function Rank.GetRankType(key)
	local typeInfo = self.rankTypes[key]
	if not typeInfo then
		return
	end
	return tunpack(typeInfo)
end

function Rank.RequestRankData(rankType)
	if not rankType then
		for _, cfg in pairs(World.cfg.ranks or {}) do
			if cfg.type ~= "local" and cfg.type ~="world" then
				Rank.RequestRankData(cfg.type or 0)
			end
		end
		local timer = self.requestRankTimer
		if timer then
			timer()
		end
		self.requestRankTimer = World.Timer(self.REQUEST_INTERVAL, Rank.RequestRankData)
		return
	end
    local cfgs = Rank.GetSubRankCfgs(rankType)
	if not cfgs then
		return
	end
	self.rankRecord[rankType] = #cfgs	-- need to wait sub rank data
	for subId, cfg in pairs(cfgs) do
		local key = Rank.getRankKey(rankType, subId)
		AsyncProcess.RequestRankRange(key, cfg.size or 10)
	end
end

function Rank.ReceiveRankData(key, rankDataStr)
	local rankType, subId = Rank.GetRankType(key)
    --print("Rank.ReceiveRankData", key, rankType, subId, rankDataStr)
	if not rankType then
		print("Rank.ReceiveRankData unknow data", key, rankDataStr)
		return
	end
	local checkKey = Rank.getRankKey(rankType, subId)
	if checkKey ~= key then
		print("Rank.ReceiveRankData key not match", key, checkKey, rankDataStr)
		return
	end
	local cfg = Rank.GetSubRankCfg(rankType, subId)
	local orderByDesc = cfg.orderByDesc
	local rankData = self.rankDatas[rankType]
    local ranks = {}
    local userIds = {}
	local split = Lib.splitString
    for i, data in pairs(split(rankDataStr, "#")) do
		local info = split(data, ":")
		if #info < 2 then
			goto continue
		end
		local userId = tonumber(info[1])
        local rank = {
            rank = i,
            userId = userId,
            score = tonumber(info[2]),
            vip = 0,
            name = "anonymous_"..info[1],
        }
		if orderByDesc then
			rank.score = -rank.score
		end
        local cache = UserInfoCache.GetCache(userId)
        if cache then
            rank.vip = cache.vip
            rank.name = cache.name
        else
            userIds[#userIds + 1] = userId
        end
        ranks[#ranks + 1] = rank
		::continue::
    end
	rankData[subId] = ranks
	AsyncProcess.RankLoadPlayersInfo(userIds, rankType, subId)
end

function Rank.UpdatePlayerInfo(playerInfos, rankType, subId)
    local rankData = self.rankDatas[rankType]
	local subRank = rankData[subId]
	if not subRank then
		print("Rank.UpdatePlayerInfo sub rank not exist", rankType, subId, rankType, subId)
		return
	end
	for _, rank in pairs(subRank) do
        local info = playerInfos[rank.userId]
        if info then
            rank.vip = info.vip
            rank.name = info.name
        end
    end
    -- sync
	local rankRecord = self.rankRecord
	local record = (rankRecord[rankType] or 0) - 1
	if record < 0 then
		return
	elseif record > 0 then
		rankRecord[rankType] = record
		return
	end
	rankRecord[rankType] = nil
end

function Rank.GetRankData(rankType)
    return self.rankDatas[rankType]
end

function Rank.UserUpdateScore(userId, rankType, subId, score)
	local key = Rank.getRankKey(rankType, subId)
	RedisHandler:ZAdd(key, tostring(userId), score)
end

function Rank.UserAddScore(userId, rankType, subId, score)
	local key = Rank.getRankKey(rankType, subId)
	RedisHandler:ZIncrBy(key, tostring(userId), score)
	--World.Timer(20 * 5, self.RequestRankData)
end

function Rank.RequestUserRankInfo(userId, rankType, subId)
	local key = Rank.getRankKey(rankType, subId)
	AsyncProcess.RequestPlayerRankInfo(userId, key)
end

function Rank.ReceiveUserRankInfo(userId, key, score, rank)
	local player = Game.GetPlayerByUserId(userId)
	if not player then
		print("Rank.ReceiveUserRankInfo cannot find player by userId", userId, key, score, rank)
		return
	end
	local rankType, subId = Rank.GetRankType(key)
	if not rankType then
		print("Rank.ReceiveUserRankInfo cannot find rank type by key", userId, key, score, rank)
		return
	end
	local checkKey = Rank.getRankKey(rankType, subId)
	if checkKey ~= key then
		print("Rank.ReceiveUserRankInfo key not match", userId, key, checkKey, score, rank)
		return
	end
	player:receiveRankInfo(rankType, subId, rank, score)
end

function Rank.RequestRankReward(userId, params)
	local rankType = params.rankType
	local subId = params.subId
	local rewardData
	for _, cfg in pairs(World.cfg.ranks or {}) do
		if (cfg.type or 0) == rankType then
			local sub = cfg.subRanks and cfg.subRanks[subId]
			assert(sub, subId)
			rewardData = sub.clearingReward or {}
		end
	end
	local player = Game.GetPlayerByUserId(userId)
	if not player then
		return
	end
	local reward = rewardData[params.index]
	if not reward then
		return { ok = false, msg = "rank.no.reward" }
	end
	local context = { obj1 = player, ranked = reward.rank, reward = reward.cfg, rankType = rankType, subId = subId, ok = true, msg = "rank.reward.get.success" }
	Trigger.CheckTriggers(player:cfg(), "REQUEST_REWARD", context)
	return {context.ok, context.msg}
end