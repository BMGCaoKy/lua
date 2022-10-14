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

-- 创建语音聊天房间
function AsyncProcess.CreateRealTimeVoiceRoom(userId, callback)
    local urlKey =  "CreateRealTimeVoiceRoom"-- strfmt("%s/gameaide/api/v1/inner/game/voice/room/create/%s", self.ServerHttpHost, userId)
    local params = {}
    local body = {}

    self.HttpRequestByKey("POST", urlKey, {userId}, params, function (response, isSuccess)
        if not isSuccess then
            print("CreateRealTimeVoiceRoom Error: " , response.code)
            if callback then
                callback()
            end
            return
        end
        print("CreateRealTimeVoiceRoom success: " , Lib.v2s(response))
        if callback then
            callback(response.data)
        end
    end, body, true)
end

-- 删除语音聊天房间
function AsyncProcess.DeleteRealTimeVoiceRoom(userId, roomId, callback)
    local urlKey = "DeleteRealTimeVoiceRoom" -- strfmt("%s/gameaide/api/v1/inner/game/voice/room/delete/%s/%s", self.ServerHttpHost, userId, roomId)
    local params = {}
    local body = {}

    self.HttpRequestByKey("POST", urlKey, {userId, roomId}, params, function (response, isSuccess)
        if not isSuccess then
            print("DeleteRealTimeVoiceRoom Error: " , response.code)
            if callback then
                callback(false)
            end
            return
        end
        print("DeleteRealTimeVoiceRoom success: " , Lib.v2s(response))
        if callback then
            callback(true)
        end
    end, body, true)
end

-- 玩家对玩家的通知,邀请好友一起游戏，包括游戏内不同房间的邀请，以及游戏内邀请正在其他游戏的玩家
function AsyncProcess.InvitePlayerPlayGameWithMe(userId, targetId, msg, callback)
    local urlKey = "InvitePlayerPlayGameWithMe" -- strfmt("%s/gameaide/api/v1/inner/game/ron/notify/ptop", self.ServerHttpHost)
    local params = {
        {"msg", msg},
        {"targetId", targetId},
        {"type", 14},
        {"userId", userId}
    }
    local body = {}

    self.HttpRequestByKey("POST", urlKey, {}, params, function (response, isSuccess)
        if not isSuccess then
            print("InvitePlayerPlayGameWithMe Error: " , response.code)
            if callback then
                callback(false)
            end
            return
        end
        print("InvitePlayerPlayGameWithMe success: " , Lib.v2s(response))
        if callback then
            callback(true)
        end
    end, body, true)
end