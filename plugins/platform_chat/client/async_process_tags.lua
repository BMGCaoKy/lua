local self = AsyncProcess
local strfmt = string.format
local cjson = require("cjson")
local chatSetting = World.cfg.chatSetting or {}

--标签推荐接口(游戏用户使用)
function AsyncProcess.RecommendFriend(callback)
    if not chatSetting.isOpenTagFunction then
        callback({})
        return
    end
    local url = strfmt("%s/gameaide/api/v1/%s/user/info/find/recommend", self.ClientHttpHost, World.GameName)
    local params = {}
    self.HttpRequest("GET", url, params, function (response, isSuccess)
        if not isSuccess then
            print("AsyncProcess RecommendFriend Error: " , response.code)
            return
        end
        callback(response.data)
    end, {}, true)
end

--标签推荐玩家，划掉某些用户(划到后面)
function AsyncProcess.DisLikeUser(index)
    if not chatSetting.isOpenTagFunction then
        return
    end
    local url = strfmt("%s/gameaide/api/v1/%s/user/info/recommend/dislike/%s", self.ClientHttpHost, World.GameName, index)
    local params = {}
    self.HttpRequest("POST", url, params, function (response, isSuccess)
        if not isSuccess then
            print("DisLikeUser Error: " , response.code)
            return
        end
    end, {}, true)
end

-- 批量查玩家的房间信息和游戏状态,标签信息
function AsyncProcess.GetPlayerListTagData(userIds, callback)
    if not chatSetting.isOpenTagFunction then
        callback({})
        return
    end
    local url = strfmt("%s/gameaide/api/v1/%s/user/info/find/batch", self.ClientHttpHost, World.GameName)
    local params = {}
    local body = userIds
    self.HttpRequest("POST", url, params, function (response, isSuccess)
        if not isSuccess then
            print("GetPlayerListTagData Error: " , response.code)
            return
        end
        if callback then
            for key, val in pairs(response.data) do
                if response.data[key].labels == nil then
                    response.data[key].labels = {}
                end
            end
            callback(response.data)
        end
    end, body, true)
end

-- 获取单个好友（玩家）信息
---@field userId string
---@param callback function
function AsyncProcess.GetOnePlayerDetailData(userId,callback)
    local url = strfmt("%s/friend/api/v1/friends/%s", self.ClientHttpHost, userId)
    local params = {}
    self.HttpRequest("GET", url, params, function (response, isSuccess)
        if not isSuccess then
            print("GetOnePlayerDetailData error", response.code)
            return
        end
        if callback then
            callback(response.data)
        end
    end, {}, true)
end

-- 获取推荐好友和筛选好友
---@field searchTxt string
---@param callback function
function AsyncProcess.OperateSearchUser(searchTxt, callback)
    if not chatSetting.isOpenTagFunction then
        callback({})
        return
    end
    local url = strfmt("%s/friend/api/v1/friends/recommendation/new", self.ClientHttpHost)
    local params = {
        {"gameId", World.GameName},
        {"searchType", 1},
        {"searchText", tostring(searchTxt)}
    }
    self.HttpRequest("GET", url, params, function (response, isSuccess)
        if not isSuccess then
            print("OperateSearchUser error", response.code)
            callback()
            return
        end
        if callback then
            if response.data[1] then
                AsyncProcess.GetOnePlayerDetailData(response.data[1].userId,function(data)
                    callback(data)
                end)
            else
                callback()
            end
        end
    end, {}, true)
end