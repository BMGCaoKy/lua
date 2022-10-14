local self = AsyncProcess
local cjson = require("cjson")
local gameId = World.GameName
local strfmt = string.format
local debugPort = require "common.debugport"

function AsyncProcess.CreateParty(userId, language, partyName, likeNum, maxPlayerNum, reachPlayerNum, lowerRate, partyImage, mapKey)
    -- local url = "CreateParty" -- strfmt("%s/gameaide/api/v1/inner/party/create", self.ServerHttpHost)
    local params = {
        {"gameId", gameId},
        {"userId", tostring(userId)},
        {"language", tostring(language)},
        {"mapKey", cjson.encode(mapKey or {})},--no more use?
        {"partyName", tostring(partyName)},
        {"likeNum", tostring(likeNum)},
        {"engineVersion", tostring(debugPort.engineVersion)},
        {"maxPlayerNum", tostring(maxPlayerNum)},
        {"reachPlayerNum", tostring(reachPlayerNum)},
        {"lowerRate", tostring(lowerRate)},
        {"partyImage", tostring(partyImage)},
    }
    -- self.HttpRequest("POST", url, params, function (response)
    self.HttpRequestByKey("POST", "CreateParty", {}, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.CreateParty response error", cjson.encode(params), cjson.encode(response))
            PartyManager.SendPartyTip(userId, response.code)
            return
        end
        print("AsyncProcess.CreateParty>>>", cjson.encode(response))
        PartyManager.OnCreateParty(userId, response.data, mapKey)
    end)
end

function AsyncProcess.CloseParty(userId)
    -- local url = "CloseParty" -- strfmt("%s/gameaide/api/v1/inner/party/close", self.ServerHttpHost)
    local params = {
        {"gameId", gameId},
        {"userId", tostring(userId)},
    }
    -- self.HttpRequest("POST", url, params, function (response)
    self.HttpRequestByKey("POST", "CloseParty", {}, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.CloseParty response error", cjson.encode(params), cjson.encode(response))
            PartyManager.SendPartyTip(userId, response.code)
            return
        end
        print("AsyncProcess.CloseParty>>>", cjson.encode(response))
        PartyManager.OnCloseParty(userId)
    end)
end

function AsyncProcess.GetPartyInfo(userId, callback)
    -- local url = "GetPartyInfo" -- strfmt("%s/gameaide/api/v1/inner/party/info", self.ServerHttpHost)
    local params = {
        {"gameId", gameId},
        {"userId", tostring(userId)},
    }
    -- self.HttpRequest("GET", url, params, function (response)
    self.HttpRequestByKey("GET", "GetPartyInfo", {}, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.GetPartyInfo response error", cjson.encode(params), cjson.encode(response))
            if callback then
                callback({})
            end
            return
        end
        print("AsyncProcess.GetPartyInfo>>>", cjson.encode(response))
        if callback then
            callback(response.data)
        else
            PartyManager.OnGetPartyInfo(userId, response.data)
        end
    end)
end

function AsyncProcess.GetPartyList(userId, language, count)
    -- local url = "GetPartyList" -- strfmt("%s/gameaide/api/v1/inner/party/info/list", self.ServerHttpHost)
    local params = {
        {"gameId", gameId},
        {"userId", tostring(userId)},
        {"language", tostring(language)},
        {"count", tostring(count)},
        {"engineVersion", tostring(debugPort.engineVersion)},
    }
    self.HttpRequestByKey("GET", "GetPartyList", {}, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.GetPartyList response error", cjson.encode(params), cjson.encode(response))
            return
        end
        print("AsyncProcess.GetPartyList>>>", cjson.encode(response))
        PartyManager.OnGetPartyList(userId, response.data)
    end)
end

function AsyncProcess.JoinParty(userId, targetUserId)
    -- local url = "JoinParty" -- strfmt("%s/gameaide/api/v1/inner/party/join", self.ServerHttpHost)
    local params = {
        {"gameId", gameId},
        {"targetUserId", tostring(targetUserId)},
        {"userId", tostring(userId)},
    }
    -- self.HttpRequest("POST", url, params, function (response)
    self.HttpRequestByKey("POST", "JoinParty", {}, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.JoinParty response error", cjson.encode(params), cjson.encode(response))
            PartyManager.JoinPartyResult(userId, targetUserId, response.code)
            return
        end
        print("AsyncProcess.JoinParty>>>", cjson.encode(response))
        PartyManager.JoinPartyResult(userId, targetUserId)
    end)
end

function AsyncProcess.LeaveParty(userId, targetUserId)
    -- local url = "LeaveParty" -- strfmt("%s/gameaide/api/v1/inner/party/leave", self.ServerHttpHost)
    local params = {
        {"gameId", gameId},
        {"targetUserId", tostring(targetUserId)},
        {"userId", tostring(userId)},
    }
    self.HttpRequestByKey("POST", "LeaveParty", {}, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.LeaveParty response error", cjson.encode(params), cjson.encode(response))
            return
        end
        print("AsyncProcess.LeaveParty>>>", cjson.encode(response))
        PartyManager.OnLeaveParty(userId, targetUserId)
    end)
end

function AsyncProcess.LikeParty(userId, targetUserId)
    -- local url = "LikeParty" -- strfmt("%s/gameaide/api/v1/inner/party/like", self.ServerHttpHost)
    local params = {
        {"gameId", gameId},
        {"userId", tostring(userId)},
        {"targetUserId", tostring(targetUserId)},
    }
    -- self.HttpRequest("POST", url, params, function (response)
    self.HttpRequestByKey("POST", "LikeParty", {}, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.LikeParty response error", cjson.encode(params), cjson.encode(response))
            PartyManager.SendPartyTip(userId, response.code)
            return
        end
        print("AsyncProcess.LikeParty>>>", cjson.encode(response))
        PartyManager.OnLikeParty(userId, targetUserId, response.data)
    end)
end

function AsyncProcess.UpdateParty(userId, updateData)
    -- local url = "UpdateParty" -- strfmt("%s/gameaide/api/v1/inner/party/update", self.ServerHttpHost)
    local params = {
        {"userId", tostring(userId)},
    }
    local body = {
        gameId = gameId,
        isGood = updateData.isGood,--optional
        maxPlayerNum = updateData.maxPlayerNum,--optional
        partyImage = updateData.partyImage,--optional
    }
    -- self.HttpRequest("POST", url, params, function (response)
    self.HttpRequestByKey("POST", "UpdateParty", {}, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.UpdateParty response error", cjson.encode(params), cjson.encode(body), cjson.encode(response))
            return
        end
        print("AsyncProcess.UpdateParty>>>", cjson.encode(response))
    end, body)
end