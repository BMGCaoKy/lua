---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2020/11/23 14:46
---
---@type LuaTimer
local LuaTimer = T(Lib, "LuaTimer")
---@type CommonActivity
local CommonActivity = T(Lib, "CommonActivity")
---@type CommonActivityType
local CommonActivityType = T(Config, "CommonActivityType")
---@type LuckyValueConfig
local LuckyValueConfig = T(Config, "LuckyValueConfig")
---@type CommonActivityConfig
local CommonActivityConfig = T(Config, "CommonActivityConfig")
---@type LuckyLotteryPriceConfig
local LuckyLotteryPriceConfig = T(Config, "LuckyLotteryPriceConfig")
---@type MustLotteryPriceConfig
local MustLotteryPriceConfig = T(Config, "MustLotteryPriceConfig")
---@type CommonActivityRewardConfig
local CommonActivityRewardConfig = T(Config, "CommonActivityRewardConfig")
---@type CommonActivityChestConfig
local CommonActivityChestConfig = T(Config, "CommonActivityChestConfig")
---@type ActivityLib
local ActivityLib = T(Lib, "ActivityLib")

-------------------------------------------------------------------------------
local CurrentActivityList = {}

function CommonActivity:initDataByType(type)
    local data = {
        getChest = "",
        lotteryTimes = 0,
        chestEndTime = 0,
    }
    if type == CommonActivityType.MustLottery then
        data.deleteSeq = ""
        data.getSeq = ""
    end
    if type == CommonActivityType.LuckyLottery then
        data.lastLotteryTime = 0
        data.luckyValue = 0
    end
    return data
end

local function isHasActivity(activityId)
    for _, activity in pairs(CurrentActivityList) do
        if activity.id == tonumber(activityId) then
            return true, activity
        end
    end
    return false, nil
end

local function LuckyTurntableCalculateWeights(rewardGroup, luckyValue)
    local luckyWeights = LuckyValueConfig:getWeightByLuckyValue(luckyValue)
    ---读取玩家幸运值，改变大奖权重
    local rewardMap = {}
    local weights = 0
    for index, item in pairs(rewardGroup) do
        if item.isGrandPrize == true then
            weights = weights + item.weights + luckyWeights
        else
            weights = weights + item.weights
        end
        local info = { rewardId = index, reward = item.reward, isGrandPrize = item.isGrandPrize, weights = weights }

        table.insert(rewardMap, info)
    end

    local randomResult = math.random(weights)
    local endResult = 0
    local result
    for _, reward in pairs(rewardMap) do
        endResult = endResult + reward.weights
        if randomResult <= endResult then
            result = reward
            break
        end
    end
    return result
end

local function initDBData(data)
    if not data.activity then
        data.activity = {}
    end
    if not data.receiveRecord then
        data.receiveRecord = {}
    end
end

local function checkAllPlayerDBData()
    local players = Game.GetAllPlayers()
    for _, player in pairs(players) do
        initDBData(player:data("common_activity"))
    end
end

function CommonActivity:payMoney(player, uniqueId, coinId, price, successCallback)
    Lib.payMoney(player, uniqueId, coinId, price, function(success)
        if success then
            successCallback()
        end
    end)
end

function CommonActivity:init()
    CurrentActivityList = {}
    local config = CommonActivityConfig:getConfigList()
    for _, activity in pairs(config) do
        if ActivityLib.isInTimeRange(activity.startTime, activity.endTime) then
            ---活动中
            self:addActivity(activity)
        else
            if activity.startTime ~= 0 and activity.startTime > os.time() then
                ---活动还没开始
                LuaTimer:schedule(function()
                    self:addActivity(activity)
                end, (activity.startTime - os.time() + 1) * 1000)
            end
        end
    end
end

function CommonActivity:addActivity(activity)
    table.insert(CurrentActivityList, activity)
    if activity.endTime ~= -1 then
        LuaTimer:schedule(function()
            self:removeActivity(activity)
        end, (activity.endTime - os.time()) * 1000)
    end
    local chestGroup = CommonActivityChestConfig:getChestGroupById(activity.chestGroupId)
    if chestGroup and chestGroup.refreshTime ~= -1 then
        local chestEndTime = ActivityLib.getCycleEndTime(activity.startTime, chestGroup.refreshTime)
        activity.chestTimer = LuaTimer:schedule(function()
            local players = Game.GetAllPlayers()
            for _, player in pairs(players) do
                local data = player:data("common_activity").activity[tostring(activity.id)]
                if data then
                    data.lotteryTimes = 0
                    data.getChest = ""
                end
            end
            WorldServer.BroadcastPacket({ pid = "CommonActivityRefreshChest", data = {
                activityId = activity.id,
                lotteryTimes = 0,
                getChest = "" }
            })
        end, (chestEndTime - os.time()) * 1000, chestGroup.refreshTime * 1000)
    end
    checkAllPlayerDBData()
    local data = { id = activity.id }
    if activity.endTime > 0 then
        data.lastTime = activity.endTime - os.time()
    else
        data.lastTime = activity.endTime or -1
    end
    local init = CommonActivity:initDataByType(activity.type)
    local players = Game.GetAllPlayers()
    for _, player in pairs(players) do
        player:data("common_activity").activity[tostring(activity.id)] = init
    end
    for key, value in pairs(init) do
        data[key] = value
    end
    WorldServer.BroadcastPacket({ pid = "AddCommonActivity", data = data })

    if activity.type == CommonActivityType.LuckyLottery then
        local priceGroup = LuckyLotteryPriceConfig:getPriceConfigByGroupId(activity.priceGroupId)
        if priceGroup and priceGroup[1] then
            if priceGroup[1].discountType == 1 then
                WorldServer.BroadcastPacket({ pid = "LuckyLotteryDiscountCd", data = { discountCd = 0 } })
            end
        end
    end
end

function CommonActivity:removeActivity(activity)
    LuaTimer:cancel(activity.chestTimer)
    Lib.tableRemove(CurrentActivityList, activity)
    local data = { activityId = activity.id }
    WorldServer.BroadcastPacket({ pid = "RemoveCommonActivity", data = data })
end

function CommonActivity:initPlayerData(player)
    local data = player:data("common_activity")
    initDBData(data)
    if #CurrentActivityList > 0 then
        local result = {}
        for _, activity in pairs(CurrentActivityList) do
            local item = { id = activity.id }
            if activity.endTime > 0 then
                item.lastTime = activity.endTime - os.time()
            else
                item.lastTime = activity.endTime or -1
            end
            local cache = data.activity[tostring(activity.id)]
            if not cache then
                local init = CommonActivity:initDataByType(activity.type)
                data.activity[tostring(activity.id)] = init
                cache = init
            else
                ---升级数据库数据
                local init = CommonActivity:initDataByType(activity.type)
                ---更新减少字段时
                for key, _ in pairs(cache) do
                    if not init[key] then
                        cache[key] = nil
                    end
                end
                ---更新增加字段时
                for key, value in pairs(init) do
                    if not cache[key] then
                        cache[key] = value
                    end
                end
            end
            local chestGroup = CommonActivityChestConfig:getChestGroupById(activity.chestGroupId)
            if chestGroup and chestGroup.refreshTime ~= -1 then
                local chestEndTime = ActivityLib.getCycleEndTime(activity.startTime, chestGroup.refreshTime)
                if chestEndTime ~= cache.chestEndTime then
                    cache.chestEndTime = chestEndTime
                    cache.lotteryTimes = 0
                    cache.getChest = ""
                end
            end
            for key, value in pairs(cache) do
                item[key] = value
            end
            table.insert(result, item)
        end
        player:sendPacket({ pid = "SyncCommonActivity", data = result })
    end
    ---清除过期活动的数据缓存
    for activityId, _ in pairs(data.activity) do
        if not isHasActivity(activityId) then
            data.activity[activityId] = nil
        else
            local activityInfo = CommonActivityConfig:getActivityById(tonumber(activityId))
            if activityInfo and activityInfo.type == CommonActivityType.LuckyLottery then
                local priceGroup = LuckyLotteryPriceConfig:getPriceConfigByGroupId(activityInfo.priceGroupId)
                if priceGroup then
                    local discountCd = priceGroup[1].discountCycle - (os.time() - data.activity[activityId].lastLotteryTime)
                    if discountCd < 0 then
                        discountCd = 0
                    end
                    player:sendPacket({ pid = "LuckyLotteryDiscountCd", data = { discountCd = discountCd } })
                end
            end
        end
    end
end

function CommonActivity:onPlayerReady(player)
    if #CurrentActivityList == 0 then
        return
    end
    CommonActivity:initPlayerData(player)
end

---删除必中活动2个奖励
function CommonActivity:onMustLotteryDelete(player, deleteData)
    local data = player:data("common_activity")
    local cache = data.activity[tostring(deleteData.activityId)]
    if not cache then
        return
    end
    cache.deleteSeq = deleteData.deleteSeq
    player:sendPacket({ pid = "MustLotteryDelete", data = deleteData })
end

---必中活动抽奖
function CommonActivity:onMustLotteryDoLottery(player, lotteryData)
    local data = player:data("common_activity")
    local cache = data.activity[tostring(lotteryData.activityId)]
    if not cache then
        return
    end
    local _, activity = isHasActivity(lotteryData.activityId)
    if not activity then
        return
    end
    local ignore = {}
    local deleteSeq = Lib.splitString(cache.deleteSeq, ",", true)
    Lib.tableRemove(deleteSeq, 0)
    if #deleteSeq < 2 then
        return
    end
    local getSeq = Lib.splitString(cache.getSeq, ",", true)
    Lib.tableRemove(getSeq, 0)
    Lib.mergeArray(deleteSeq, getSeq, ignore)
    local group = CommonActivityRewardConfig:getRewardGroupById(activity.rewardGroupId)
    if not group then
        return
    end
    local pool = {}
    local weightSum = 0
    for _, item in pairs(group) do
        if not Lib.tableContain(ignore, item.groupSeq) then
            weightSum = weightSum + item.weights
            table.insert(pool, item)
        end
    end
    if #pool == 0 then
        return
    end
    local config = MustLotteryPriceConfig:getPriceConfig(activity.priceGroupId, #getSeq + 1)
    if not config then
        return
    end
    CommonActivity:payMoney(player, config.id, config.moneyType, config.discountPrice, function()
        local random = math.random(1, weightSum)
        local weightTag = 0
        local itemTag
        for _, item in pairs(pool) do
            weightTag = weightTag + item.weights
            if weightTag >= random then
                itemTag = item
                break
            end
        end
        local reward = ActivityLib.activityReceiveReward(player, itemTag.reward)
        if not reward then
            return
        end
        table.insert(getSeq, itemTag.groupSeq)
        cache.getSeq = table.concat(getSeq, ",")
        cache.lotteryTimes = cache.lotteryTimes + 1
        lotteryData.rewardId = reward.rewardId
        lotteryData.groupSeq = itemTag.groupSeq
        lotteryData.lotteryTimes = cache.lotteryTimes
        player:sendPacket({ pid = "MustLotteryResult", data = lotteryData })
    end)
end

function CommonActivity:onLuckyLottery(player, lotteryInfo)
    local data = player:data("common_activity")

    local cache = data.activity[tostring(lotteryInfo.activityId)]
    if not cache then
        return
    end

    local _, activity = isHasActivity(lotteryInfo.activityId)
    if not activity then
        return
    end

    local priceGroup = LuckyLotteryPriceConfig:getPriceConfigByGroupId(activity.priceGroupId)
    local rewardGroup = CommonActivityRewardConfig:getRewardGroupById(activity.rewardGroupId)
    if not priceGroup or not rewardGroup then
        Lib.logWarning("[CommonActivity] [LuckyLottery] Lack Config")
        return
    end

    local priceConfig = priceGroup[lotteryInfo.type]
    local realPrice = priceConfig.price
    if priceConfig.discountPrice < priceConfig.price and (os.time() - cache.lastLotteryTime) > priceConfig.discountCycle then
        realPrice = priceConfig.discountPrice
        cache.lastLotteryTime = os.time()
    end

    ---抽奖
    CommonActivity:payMoney(player, priceConfig.id, priceConfig.moneyType, realPrice, function()
        local results = {}
        for _ = 1, (priceConfig.times) do
            local result = LuckyTurntableCalculateWeights(rewardGroup, cache.luckyValue)
            local realReward = ActivityLib.activityReceiveReward(player, result.reward)
            if not realReward then
                return
            end
            table.insert(results, { rewardId = realReward.rewardId, isGrandPrize = result.isGrandPrize })
            cache.lotteryTimes = cache.lotteryTimes + 1
            if result.isGrandPrize == true then
                cache.luckyValue = 0
            else
                cache.luckyValue = cache.luckyValue + 1
            end
        end
        local resultInfo = {}
        resultInfo.type = lotteryInfo.type
        resultInfo.results = results
        resultInfo.luckyValue = cache.luckyValue
        resultInfo.lotteryTimes = cache.lotteryTimes
        if priceConfig.discountCycle ~= 0 then
            if priceConfig.discountCycle - (os.time() - cache.lastLotteryTime) >= 0 then
                resultInfo.discountCd = priceConfig.discountCycle - (os.time() - cache.lastLotteryTime)
            else
                resultInfo.discountCd = 0
            end
        else
            resultInfo.discountCd = -1
        end
        player:sendPacket({ pid = "LuckyLotteryResult", data = resultInfo })
    end)
end

function CommonActivity:onOpenChest(player, openData)
    local data = player:data("common_activity")
    local cache = data.activity[tostring(openData.activityId)]
    if not cache then
        return
    end
    local _, activity = isHasActivity(openData.activityId)
    if not activity then
        return
    end
    local getChest = Lib.splitString(cache.getChest, ",", true)
    if Lib.tableContain(getChest, openData.chestId) then
        return
    end
    table.insert(getChest, openData.chestId)
    cache.getChest = table.concat(getChest, ",")
    local chest = CommonActivityChestConfig:getChestById(openData.chestId)
    ActivityLib.activityReceiveRewardByGroupId(player, chest.rewardGroupId)
    player:sendPacket({ pid = "CommonActivityOpenChestResult", data = openData })
end