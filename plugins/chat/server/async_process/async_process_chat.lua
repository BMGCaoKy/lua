local self = AsyncProcess
local strfmt = string.format
function AsyncProcess.GetVoiceInfo(userId)
    -- local url = strfmt("%s/gameaide/api/v1/user/voice/profit", self.ServerHttpHost)
    self.HttpRequestByKey("GET", "GetVoiceInfo", {}, {{"userId",userId}}, function (response, isSuccess)
        if not isSuccess then
            print("GetVoiceInfo Error: " , response.code)
            return
        end
        --expiryDate	用户语音月卡过期时间	string(date-time)
        --expiryDateLong	用户语音月卡过期时间戳	integer(int64)
        --freeTimes	用户当天剩余免费语音次数	integer(int32)
        --times	用户剩余付费语音次数	integer(int32)
        --userId	用户id	integer(int64)
        local player = Game.GetPlayerByUserId(userId)
        if player then
            player:initVoiceInfo(response.data)
        end
    end, {}, true)
end
---@param player Entity
function AsyncProcess.SetVoiceInfo(player)
    -- local url = strfmt("%s/gameaide/api/v1/user/voice/profit/update", self.ServerHttpHost)
    local params = {{"userId", player.platformUserId}}
    local body = {
        userId = player.platformUserId,
        expireDateLong = player:getSoundMoonCardMac(),
        freeTimes = player:getFreeSoundTimes(),
        times = player:getSoundTimes()
    }
    --table.insert(params,{"expireDateLong",player:getSoundMoonCardMac()})
    --table.insert(params,{"freeTimes",player:getFreeSoundTimes()})
    --table.insert(params,{"times",player:getSoundTimes()})
    self.HttpRequestByKey("POST", "SetVoiceInfo", {}, params, function (response, isSuccess)
        if not isSuccess then
            print("SetVoiceInfo Error: " , response.code)
            return
        end
        --expiryDate	用户语音月卡过期时间	string(date-time)
        --expiryDateLong	用户语音月卡过期时间戳	integer(int64)
        --freeTimes	用户当天剩余免费语音次数	integer(int32)
        --times	用户剩余付费语音次数	integer(int32)
        --userId	用户id	integer(int64)
        print("SetVoiceInfo succ:",Lib.v2s(response,3))
    end, body, true)
end

