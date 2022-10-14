local self = AsyncProcess
local gameName = World.GameName
local cjson = require "cjson"

local function getRewardInfo(userId, response)
    local player = Game.GetPlayerByUserId(userId)
    if not player or not player:isValid() then
        return false
    end
    if response.code == 13050 then
        --key无效
        player:sendTip(3, "tips_cdkey_invalid", 40)
    elseif response.code == 13051 then
        --key过期
        player:sendTip(3, "tips_cdkey_expired", 40)
    elseif response.code == 8022 then
        --找不到
        player:sendTip(3, "tips_cdkey_used", 40)
    elseif response.code == 8008 then
        --今日次数受限
        player:sendTip(3, "tips_cdkey_day_limit", 40)
    elseif response.code == 1 then
        --触发trigger，业务发奖
        local data = response.data
        local reward = cjson.decode(data.reward)
        local context = {obj1 = player, canReward = true, rewardList = reward}
        Trigger.CheckTriggers(nil, "CD_KEY_CAN_REWARD", context)
        if context.canReward then
            self.PutCDKeySuccess(data.cdKey, userId, reward)
        else
            player:sendTip(3, "compound.inventory.full", 40)
        end
    end
end

local function giveReward(response, userId, reward)
    local player = Game.GetPlayerByUserId(userId)
    if not player or not player:isValid() then
        return
    end
    if response.code ~= 1 then
        return
    end
    for _, v in pairs(reward or {}) do
        if v.rewardType == "gameProp" then
            local context = {obj1 = player, reward = v}
            Trigger.CheckTriggers(nil, "CD_KEY_REWARD", context)
        elseif v.rewardType == "gcubes" then
            player:addCurrency("gDiamonds", v.amount, "cd_key")
        end
    end
end

function AsyncProcess.PostCDKey(userId, cdKey)
    -- local url = "PostCDKey" -- string.format("%s/game/api/v1/inner/cdkey/receive", self.ServerHttpHost)
    local params = {
        {"userId", userId},
        {"cdKey", cdKey},
        {"gameId", World.GameName}
    }
    -- self.HttpRequest("POST", url, params, function (response)
    self.HttpRequestByKey("POST", "PostCDKey", {}, params, function (response)
        getRewardInfo(userId, response)
    end, {})
end

function AsyncProcess.PutCDKeySuccess(cdKey, userId, reward)
    -- local url = "PutCDKeySuccess" -- string.format("%s/game/api/v1/inner/cdkey/notify", self.ServerHttpHost)
    local params = {
        {"cdKey", cdKey}
    }
    -- self.HttpRequest("PUT", url, params, function (response)
    self.HttpRequestByKey("PUT", "PutCDKeySuccess", {}, params, function (response)
        giveReward(response, userId, reward)
    end, {})
end