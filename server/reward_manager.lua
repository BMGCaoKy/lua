---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by work.
--- DateTime: 2019/6/5 11:20
---
RewardManager = {}
RewardManager.StandardNum = 10
RewardManager.StartPlayerCount = nil
RewardManager.StartPlayerTime = nil
RewardManager.WaitRewardCache = {}
RewardManager.RewardHistory = {}
local gameName = World.GameName

function RewardManager:startGame()
    self.StartPlayerCount = Game.GetGamingPlayerCount()
    self.StartGameTime = os.time()
    self.RewardHistory = {}
    AsyncProcess.initGameId()
    Game.resetUserExpCache()
    ReportManager:clearRoundIdLock()
end

function RewardManager:getStartPlayerCount()
    return self.StartPlayerCount or Game.GetGamingPlayerCount()
end

function RewardManager:getStartGameTime()
    return self.StartGameTime or (os.time() - 60)
end

function RewardManager:getGameRunningTime()
    return os.time() - self:getStartGameTime()
end

function RewardManager:isUserRewardFinish(userId)
    return self.RewardHistory[tostring(userId)]
end

function RewardManager:addRewardQueue(userId, rank)
    userId = tostring(userId)
    if self.RewardHistory[userId] then
        return
    end
    table.insert(self.WaitRewardCache, {
        userId = tonumber(userId),
        rank = rank
    })
    self.RewardHistory[userId] = true
end

function RewardManager:getQueueReward(func, ...)
    if #self.WaitRewardCache == 0 then
        func("", ...)
        return
    end
    local data = {}
    local startGameTime = RewardManager:getStartGameTime()
    local startPlayerCount = RewardManager:getStartPlayerCount()
    for _, cache in pairs(self.WaitRewardCache) do
        local item = {}
        item.userId = cache.userId
        item.gameId = gameName
        item.recordId = AsyncProcess.getGameId()
        item.rank = cache.rank or 10
        item.duration = os.time() - startGameTime
        item.standardNum = self.StandardNum
        item.totalNum = startPlayerCount
        item.startTime = os.date("%Y-%m-%d %H:%M:%S", startGameTime)
        table.insert(data, item)
    end
    self.WaitRewardCache = {}
    AsyncProcess.GetRewardList(func, data, ...)
end

function RewardManager:getUserReward(userId, rank, func, inGameTime, gameId)
    if self.RewardHistory[tostring(userId)] then
        func()
        return
    end
    local startGameTime = inGameTime or RewardManager:getStartGameTime()
    local startPlayerCount = RewardManager:getStartPlayerCount()
    local data = {}
    data.duration = os.time() - startGameTime
    data.rank = rank or 10
    data.recordId = gameId or AsyncProcess.getGameId()
    data.standardNum = self.StandardNum
    data.totalNum = startPlayerCount
    data.startTime = os.date("%Y-%m-%d %H:%M:%S", startGameTime)
    AsyncProcess.GetReward(func, userId, data)
    self.RewardHistory[tostring(userId)] = true
end

function RewardManager:getUserGoldReward(userId, golds, func)
    if self.RewardHistory[tostring(userId)] then
        func()
        return
    end
    AsyncProcess.GetGoldReward(func, userId, golds)
    self.RewardHistory[tostring(userId)] = true
end