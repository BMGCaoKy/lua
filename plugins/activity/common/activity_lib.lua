---
--- Generated by Luanalysis
--- Created by Administrator.
--- DateTime: 2020/12/22 19:29
---
---@class ActivityLib
local ActivityLib = T(Lib, "ActivityLib")

function ActivityLib.setGUIBySetting(window, settings, functionName)
    for key, setting in pairs(settings) do
        local win = window[functionName](window, key)
        if win then
            for name, value in pairs(setting) do
                if name == "Text" then
                    win:SetText(Lang:getMessage(value))
                else
                    win:SetProperty(name, value)
                end
            end
        end
    end
end

function ActivityLib.isInTimeRange(startTime, endTime)
    if endTime == -1 then
        return true
    end
    local nowTime = os.time(os.date("*t"))
    if nowTime >= startTime and nowTime < endTime then
        return true
    end
    return false
end

---计算周期结束时间
function ActivityLib.getCycleEndTime(startTime, refreshTime)
    return (os.time() - ((os.time() - startTime) % refreshTime)) + refreshTime
end

-------------------------------------- 抽奖池 --------------------------------------
function ActivityLib.onOpenCommonRewardPool(player, rewardGroupId)
    local CommonActivityRewardConfig = T(Config, "CommonActivityRewardConfig")  ---@type CommonActivityRewardConfig
    local group = CommonActivityRewardConfig:getRewardGroupById(rewardGroupId)
    if not group then
        return nil
    end
    local pool = {}
    local weightSum = 0
    for _, item in pairs(group) do
        weightSum = weightSum + item.weights
        table.insert(pool, item)
    end
    if #pool == 0 then
        return nil
    end
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
    return ActivityLib.activityReceiveReward(player, itemTag.reward)
end

function ActivityLib.activityReceiveReward(player, reward)
    if reward.type == "CommonRewardPool" then
        return ActivityLib.onOpenCommonRewardPool(player, reward.realId)
    end
    if reward.compensate == 0 then
        player["onReceiveCommonReward"](player, reward.type, reward.realId, reward.num, 0)
        return reward
    end
    local receiveRecord = player:data("common_activity").receiveRecord
    if receiveRecord[tostring(reward.rewardId)] == nil then
        player["onReceiveCommonReward"](player, reward.type, reward.realId, reward.num, 0)
        receiveRecord[tostring(reward.rewardId)] = true
        return reward
    else
        local CommonActivityRewardConfig = T(Config, "CommonActivityRewardConfig")  ---@type CommonActivityRewardConfig
        local compensateReward = CommonActivityRewardConfig:getRewardById(reward.compensate)
        if not compensateReward then
            Lib.logWarning("[CommonActivity] [receiveReward] Not Compensate Reward, RewardId:", reward.rewardId)
            player["onReceiveCommonReward"](player, reward.type, reward.realId, reward.num, 0)
            return reward
        else
            return ActivityLib.activityReceiveReward(player, compensateReward)
        end
    end
end

function ActivityLib.activityReceiveRewardByGroupId(player, groupId)
    local CommonActivityRewardConfig = T(Config, "CommonActivityRewardConfig")  ---@type CommonActivityRewardConfig
    local group = CommonActivityRewardConfig:getRewardGroupById(groupId)
    local rewardIds = {}
    for _, item in pairs(group or {}) do
        local reward = ActivityLib.activityReceiveReward(player, item.reward)
        table.insert(rewardIds, reward.rewardId)
    end
    return rewardIds
end