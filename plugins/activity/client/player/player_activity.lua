---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2020/11/23 15:19
---
local CommonActivity = T(Lib, "CommonActivity") ---@type CommonActivity
local CommonActivityConfig = T(Config, "CommonActivityConfig") ---@type CommonActivityConfig
local handles = T(Player, "PackageHandlers")

function handles:SyncCommonActivity(packet)
    for _, item in pairs(packet.data) do
        local activity = CommonActivityConfig:getActivityById(item.id)
        if activity then
            for key, value in pairs(item) do
                activity[key] = value
            end
            CommonActivity:addActivity(activity)
        end
    end
end

function handles:AddCommonActivity(packet)
    local activity = CommonActivityConfig:getActivityById(packet.data.id)
    if activity then
        for key, value in pairs(packet.data) do
            activity[key] = value
        end
        CommonActivity:addActivity(activity)
    end
end

function handles:RemoveCommonActivity(packet)
    local activity = CommonActivityConfig:getActivityById(packet.data.activityId)
    if activity then
        CommonActivity:removeActivity(activity)
    end
end

function handles:MustLotteryDelete(packet)
    Lib.emitEvent(Event.EventMustLotteryDelete, packet.data)
end

function handles:MustLotteryResult(packet)
    Lib.emitEvent(Event.EventMustLotteryResult, packet.data)
end

function handles:LuckyLotteryResult(packet)
    Lib.emitEvent(Event.EventLuckyLotteryResult, packet.data)
end

function handles:LuckyLotteryDiscountCd(packet)
    Lib.emitEvent(Event.EventLuckyLotteryDiscountCd, packet.data)
end

function handles:CommonActivityOpenChestResult(packet)
    Lib.emitEvent(Event.EventCommonActivityOpenChestResult, packet.data)
end

function handles:CommonActivityRefreshChest(packet)
    Lib.emitEvent(Event.EventCommonActivityRefreshChest, packet.data)
end

function handles:BlindBoxInit(packet)
    Lib.emitEvent(Event.EventBlindBoxInit, packet.data)
end

function handles:BlindBoxOpenResult(packet)
    Lib.emitEvent(Event.EventBlindBoxOpenResult, packet.data)
end