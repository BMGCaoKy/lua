-- all logic async request should use interface define in this mode
-- requests will dispatch and callback by server in C++
-- environment maybe change in async callback, so must checkt it!!!

local cjson = require("cjson")
local type = type
local strfmt = string.format
local traceback = traceback

local self = AsyncProcess

function AsyncProcess.Init()
    self._session = 0
    self._requests = {}
    self.ClientHttpHost = string.gsub(Blockman.instance:getClientHttpHost(), "https", "http")
end

function AsyncProcess.AllocSession()
    local session = self._session + 1
    self._session = session
    return session
end

local function httpRequest(method, session, url, params, body, header)
    if method == "GET" then
        Blockman.instance:httpAsyncGet(session, url, params or {})
    elseif method == "POST" then
        Blockman.instance:httpAsyncPost(session, url, body, params or {})
    elseif method == "PUT" then
        Blockman.instance:httpAsyncPut(session, url, header or {}, body, params or {})
    elseif method == "DELETE" then
        Blockman.instance:httpAsyncDelete(session, url, params or {})
    elseif method == "MULTIPART_POST" then
        Blockman.instance:httpAsyncUpload(session, url, body, params or {})
    elseif method == "DOWNLOAD" then
        Blockman.instance:httpAsyncDownload(session, url, body, params or {})
    else
        self._requests[session] = nil
        assert(false, "unsupport HTTP request method" .. tostring(method))
    end
end

function AsyncProcess.HttpRequest(method, url, params, callback, body, canRetry, header)
    assert(type(callback) == "function", callback)
    if body and type(body) ~= "string" then
        body = cjson.encode(body)
    end
    local session = self.AllocSession()
    local function retryFunc()
        httpRequest(method, session, url, params, body, header)
    end
    self._requests[session] = {
        session = session,
        time = os.time(),
        url = url,
        header = header,
        params = params,
        callback = callback,
        retryTimes = 1,
        retryFunc = retryFunc,
        canRetry = canRetry,
    }
    retryFunc()
end

local function httpRequestByKey(method, session, key, urlFormatArgs, params, body, header)
    if method == "GET" then
        Blockman.instance:httpGetByKey(key, urlFormatArgs or {}, session, params or {})
    elseif method == "POST" then
        Blockman.instance:httpPostByKey(key, urlFormatArgs or {}, session, body, params or {})
    elseif method == "PUT" then
        Blockman.instance:httpPutByKey(key, urlFormatArgs or {}, session, header or {}, body, params or {})
    elseif method == "DELETE" then
        Blockman.instance:httpDeleteByKey(key, urlFormatArgs or {}, session, params or {})
    elseif method == "MULTIPART_POST" then
        Blockman.instance:httpUploadByKey(key, urlFormatArgs or {}, session, body, params or {})
    elseif method == "DOWNLOAD" then
        Blockman.instance:httpDownloadByKey(key, urlFormatArgs or {}, session, body, params or {})
    else
        self._requests[session] = nil
        assert(false, "unsupport HTTP request method" .. tostring(method))
    end
end

function AsyncProcess.HttpRequestByKey(method, key, urlFormatArgs, params, callback, body, canRetry, header)
    assert(type(callback) == "function", callback)
    if body and type(body) ~= "string" then
        body = cjson.encode(body)
    end
    local session = self.AllocSession()
    local function retryFunc()
        httpRequestByKey(method, session, key, urlFormatArgs, params, body, header)
    end
    self._requests[session] = {
        session = session,
        time = os.time(),
        url = key,
        header = header,
        params = params,
        callback = callback,
        retryTimes = 1,
        retryFunc = retryFunc,
        canRetry = canRetry,
    }
    retryFunc()
end

function AsyncProcess.GameAnalyticsRequest(url, callback, body, useGzip, clientIp)
    local session = self.AllocSession()
    if body and type(body) ~= "string" then
        body = cjson.encode(body)
    end
    Blockman.Instance():postGameAnalyticsRequest(session, url, body, useGzip, clientIp)
    self._requests[session] = {
        session = session,
        time = os.time(),
        url = url,
        body = body,
        callback = callback,
    }
end

local function checkSuccess(response)
    if response.status_code then
        return false
    end
    if response.code ~= 1 then
        return false
    end
    return true
end

-- when http request error, response content will like '{"status_code":404}'
-- otherwise, content will like '{"code":1,"data":...}' or '{"code":5006,"message":...}'
function AsyncProcess.HandleHttpResponse(session, response)
    local requests = self._requests
    local request = requests[session]
    if not request then
        print("AsyncProcess HandleHttpResponse cannot find request by session", session, response)
        return
    end
    local ok, data = pcall(cjson.decode, response)
    if not ok then
        --解析失败，打印超长字符串
        Lib.printSubString(response)
        Lib.logDebug(request)
        perror("AsyncProcess HandleHttpResponse decode response error", session, request.url, Lib.v2s(request), response)
        return
    end

    local isSuccess = checkSuccess(data)
    local retryTimes = request.retryTimes
    local canRetry = request.canRetry and not isSuccess and (retryTimes and retryTimes <= 3)

    if canRetry then
        print(strfmt("AsyncProcess.HttpRequest retry, url = %s, retry count = %s", request.url, retryTimes))
        print("error friend response", Lib.v2s(data))
        World.Timer(20 * 3 * retryTimes, request.retryFunc)
        request.retryTimes = retryTimes + 1
        return
    end

    requests[session] = nil

    local ok, ret = xpcall(request.callback, traceback, data, isSuccess)
    if not ok then
        perror("AsyncProcess HandleHttpResponse callback error", session, request.url, response:sub(1, 100), ret)
    end
end

function AsyncProcess.GetUserDetail(userId, func)
    local urlFormatArgs = { tostring(userId) } -- strfmt("%s/friend/api/v1/friends/%s", self.ClientHttpHost, tostring(userId))
    -- self.HttpRequest("GET", url, nil, function(response, isSuccess)
    self.HttpRequestByKey("GET", "GetUserDetail", urlFormatArgs, nil, function(response, isSuccess)
        if not isSuccess then
            func(nil)
            return
        end
        response.data.nickName = Lib.reconstructName(response.data.nickName, response.data.colorfulNickName)
        UserInfoCache.UpdateUserInfos({ response.data })
        func(response.data)
    end, {}, true)
end

-- {url}/decoration/api/v1/decorations/{otherId}/using
function AsyncProcess.GetUserDecoration(userId, func)
    local urlFormatArgs = { tostring(userId) } -- strfmt("%s/decoration/api/v1/decorations/%s/using", self.ClientHttpHost, userId)
    local params = {

    }
    -- self.HttpRequest("GET", url, params, function (response, isSuccess)
    self.HttpRequestByKey("GET", "GetUserDecoration", urlFormatArgs, params, function (response, isSuccess)
        if not isSuccess then
            print("AsyncProcess.GetUserDecoration response error", cjson.encode(params), cjson.encode(response))
            func({})
            return
        end
        local data = {}
        for _, item in pairs(response.data) do
            local resource = Lib.splitString(item.resourceId, ".")
            if resource[1] == "custom_suits" then
                data[resource[1]] = Lib.splitString(resource[2], "-", true)
            else
                data[resource[1]] = tonumber(resource[2]) or 0
            end
        end
        func(data)
	end, {}, true)
end

function AsyncProcess.GetPlayerActorInfo(userId, callback)
    AsyncProcess.GetUserDetail(userId, function(userInfo)
        local info = { sex = 1, nickName = "", skin = {} }
        if userInfo then
            info.sex = userInfo.sex
            info.nickName = userInfo.nickName
        end
        AsyncProcess.GetUserDecoration(userId, function(data)
            info.skin = data
            callback(info)
        end)
    end)
end

function AsyncProcess.LoadFriend()
    local urlFormatArgs = { Me.platformUserId } -- strfmt("%s/gameaide/api/v1/party/friends/%s", self.ClientHttpHost, Me.platformUserId)
    local player = Game.GetPlayerByUserId(Me.platformUserId)
    local language = "en_US"
    if player then
        local userCache = UserInfoCache.GetCache(Me.platformUserId)
        language = userCache and userCache.language or 'en_US'
    end
    local params = {
        {"pageNo", "0"},
        {"pageSize", "50"},
        {"language", language},
        {"gameId", World.GameName}
    }
    -- self.HttpRequest("GET", url, params, function (response, isSuccess)
    self.HttpRequestByKey("GET", "LoadFriend", urlFormatArgs, params, function (response, isSuccess)
        if not isSuccess then
            print("AsyncProcess.LoadFriend response error", cjson.encode(params), cjson.encode(response))
            return
        end
        FriendManager.ParseFriendData(response.data)
	end, {}, true)
end

function AsyncProcess.NewLoadFriend()
    local urlFormatArgs = {}-- strfmt("%s/friend/api/v1/friends", self.ClientHttpHost)
    local player = Game.GetPlayerByUserId(Me.platformUserId)
    local language = "en_US"
    if player then
        local userCache = UserInfoCache.GetCache(Me.platformUserId)
        language = userCache and userCache.language or 'en_US'
    end
    local params = {
        {"userId", Me.platformUserId},
        {"pageNo", "0"},
        {"pageSize", "50"},
        {"language", language},
    }
    -- self.HttpRequest("GET", url, params, function (response, isSuccess)
    self.HttpRequestByKey("GET", "NewLoadFriend", urlFormatArgs, params, function (response, isSuccess)
        if not isSuccess then
            print("AsyncProcess.LoadFriend response error", cjson.encode(params), cjson.encode(response))
            return
        end
        FriendManager.ParseFriendData(response.data)
    end, {}, true)
end

function AsyncProcess.LoadUsersInfo(userIds, callback)
    local urlFormatArgs = {} -- strfmt("%s/friend/api/v1/friends/by/userIds", self.ClientHttpHost)
    local params = { {"userIds", table.concat(userIds, ",")}, }
    -- self.HttpRequest("GET", url, params, function (response)
    self.HttpRequestByKey("GET", "LoadUsersInfo", urlFormatArgs, params, function (response)
        if response.code ~= 1 then
            print("AsyncProcess.LoadUsersInfo response error", cjson.encode(params), cjson.encode(response))
            return
        end
        UserInfoCache.UpdateUserInfos(response.data)
        if callback then
            callback(response.data)
        end
	end)
end

function AsyncProcess.LoadUserRequests()
	local urlFormatArgs = {} -- strfmt("%s/friend/api/v1/friends/requests", self.ClientHttpHost)
	local params = {
		{"pageNo", "0"},
		{"pageSize", "50"},
	}
    -- self.HttpRequest("GET", url, params, function (response, isSuccess)
    self.HttpRequestByKey("GET", "LoadUserRequests", urlFormatArgs, params, function (response, isSuccess)
        if not isSuccess then
            print("AsyncProcess.LoadUserRequests response error", cjson.encode(params), cjson.encode(response))
            return
        end
        FriendManager.ParseUserRequests(response.data)
	end, {}, true)
end

function AsyncProcess.FriendOperation(opType, userId)
    local operationType = FriendManager.operationType
    local cfg = {
        [operationType.AGREE] = {
            key = "FriendOperationAGREE",
            method = "PUT",
        },
        [operationType.REFUSE] = {
            key = "FriendOperationREFUSE",
            method = "PUT",
        },
        [operationType.DELETE] = {
            key = "FriendOperationDELETE",
            method = "DELETE",
        },
        [operationType.ADD_FRIEND] = {
            key = "FriendOperationADD_FRIEND",
            method = "POST",
        },
    }
    local params, body
    if opType == operationType.DELETE then
        params = {{"friendId", tostring(userId)}}
    elseif opType == operationType.ADD_FRIEND then
        body = {
            friendId = tostring(userId),
            msg = "",
            type = 4
        }
    end
    local urlFormatArgs = { tostring(userId) } -- strfmt(cfg[opType].url, self.ClientHttpHost, userId)
    -- self.HttpRequest(cfg[opType].method, url, params, function (response, isSuccess)
    self.HttpRequestByKey(cfg[opType].method, cfg[opType].key, urlFormatArgs, params, function (response, isSuccess)
        if not isSuccess then
            print("AsyncProcess.FriendOperation response error", urlFormatArgs, cjson.encode(params), cjson.encode(response))
            return
        end
        -- print("AsyncProcess.FriendOperation>>>", cjson.encode(params), url, cjson.encode(response))
        Lib.emitEvent(Event.EVENT_FRIEND_OPERATION_CLIENT, opType, userId)
	end, body)
end

--上传文件
function AsyncProcess.UploadFile(fileName, filePath, dir, callback)
    local urlFormatArgs = {} -- string.format("%s/user/api/v1/directory/file", self.ClientHttpHost)
    local args = {{"fileName", fileName}, {"directory", dir}}
    -- self.HttpRequest("MULTIPART_POST", url, args, callback, filePath)
    self.HttpRequestByKey("MULTIPART_POST", "UploadFile", urlFormatArgs, args, callback, filePath)
end
--下载文件
function AsyncProcess.DownloadFile(url, filePath, callback)
    self.HttpRequest("DOWNLOAD", url, {}, callback, filePath)
end