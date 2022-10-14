-- all logic async request should use interface define in this mode
-- requests will dispatch and callback by server in C++
-- environment maybe change in async callback, so must checkt it!!!

local cjson = require("cjson")
local strfmt = string.format
local tconcat = table.concat
local tostring = tostring
local type = type
local traceback = traceback
local debugPort = require "common.debugport"
local RedisHandler = require "redishandler"
local gameName = World.GameName

local self = AsyncProcess

function AsyncProcess.Init()
	self._gameId = 0
	self._session = 0
	self._requests = {}
	self.ServerHttpHost = Server.CurServer:getServerHttpHost()
	self.initGameId()
end

function AsyncProcess.AllocSession()
	local session = self._session + 1
	self._session = session
	return session
end

function AsyncProcess.initGameId()
	local uuid = require "common.uuid"
	uuid.randomseed(os.time())
	self._gameId = uuid()
end

function AsyncProcess.getGameId()
	return self._gameId
end

local function httpRequest(method, session, url, params, body)
	if method ==  "GET" then
		PlatformRequest.HttpGet(session, url, params or {})
	elseif method == "POST" then
		PlatformRequest.HttpPost(session, url, body, params or {})
	elseif method == "PUT" then
		PlatformRequest.HttpPut(session, url, body, params or {})
	elseif method == "DELETE" then
		PlatformRequest.HttpDelete(session, url, body, params or {})
	else
		self._requests[session] = nil
		assert(false, "unsupport HTTP request method"..tostring(method))
	end
end

function AsyncProcess.HttpRequest(method, url, params, callback, body, canRetry)
	assert(type(callback) == "function", callback)
	if body and type(body) ~= "string" then
		body = cjson.encode(body)
	end
	local session = self.AllocSession()
	local function retryFunc()
		httpRequest(method, session, url, params, body)
	end
	self._requests[session] = {
		session = session,
		time = os.time(),
		url = url,
		params = params,
		callback = callback,
		body = body,
		retryTimes = 1,
		retryFunc = retryFunc,
		canRetry = canRetry,
	}
	retryFunc()
end

local function httpRequestByKey(method, session, key, urlFormatArgs, params, body)
	if method ==  "GET" then
		PlatformRequest.HttpGetByKey(key, urlFormatArgs or {}, session, params or {})
	elseif method == "POST" then
		PlatformRequest.HttpPostByKey(key, urlFormatArgs or {}, session, body, params or {})
	elseif method == "PUT" then
		PlatformRequest.HttpPutByKey(key, urlFormatArgs or {}, session, body, params or {})
	elseif method == "DELETE" then
		PlatformRequest.HttpDeleteByKey(key, urlFormatArgs or {}, session, body, params or {})
	else
		self._requests[session] = nil
		assert(false, "unsupport HTTP request method"..tostring(method))
	end
end

function AsyncProcess.HttpRequestByKey(method, key, urlFormatArgs, params, callback, body, canRetry)
	assert(type(callback) == "function", callback)
	if body and type(body) ~= "string" then
		body = cjson.encode(body)
	end
	local session = self.AllocSession()
	local function retryFunc()
		httpRequestByKey(method, session, key, urlFormatArgs, params, body)
	end
	self._requests[session] = {
		session = session,
		time = os.time(),
		url = key,
		params = params,
		callback = callback,
		body = body,
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
	Server.CurServer:postGameAnalyticsRequest(session, url, body, useGzip, clientIp)
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
		perror("AsyncProcess HandleHttpResponse decode response error", session, request.url, response)
		return
	end

	local isSuccess = checkSuccess(data)
	local retryTimes = request.retryTimes
	local canRetry = request.canRetry and not isSuccess and (retryTimes and retryTimes <= 3)

	if canRetry then
		print(strfmt("AsyncProcess.HttpRequest retry, url = %s, retry count = %s", request.url, retryTimes))
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

function AsyncProcess.LoadUserMoney(userId)
	-- local url = strfmt("%s/pay/i/api/v1/wealth/users/%s", self.ServerHttpHost, tostring(userId))
	-- self.HttpRequest("GET", url, nil, function (response, isSuccess)
	self.HttpRequestByKey("GET", "LoadUserMoney", {tostring(userId)}, nil, function (response, isSuccess)
		if not isSuccess then
			print("LoadUserMoney Error: " , response.code)
			return
		end
		local player = Game.GetPlayerByUserId(userId)
		if player then
			player:setCurrency("golds", response.data.golds)
			player:setCurrency("gDiamonds", response.data.gDiamonds)
			Trigger.CheckTriggers(player:cfg(), "LOAD_USER_MONEY", {obj1 = player})
		end
	end, {}, true)
end

function AsyncProcess.CreateVoiceRoom(userId,callback)
	-- local url = strfmt("%s/gameaide/api/v1/inner/game/voice/room/create/%s", self.ServerHttpHost, tostring(userId))
	-- self.HttpRequest("POST", url, nil, function (response, isSuccess)
	self.HttpRequestByKey("POST", "CreateVoiceRoom", {tostring(userId)}, nil, function (response, isSuccess)
		print("create voice room", Lib.v2s(response))
		if not isSuccess then
			print("CreateVoiceRoom Error: " , response.code)
			return
		end
		if callback then
			callback(response.data.roomId)
		end

	end, {}, true)
end
function AsyncProcess.RemoveVoiceRoom(roomId)
	-- local url = strfmt("%s/gameaide/api/v1/inner/game/voice/room/delete/%s", self.ServerHttpHost,tostring(roomId))
	-- self.HttpRequest("POST", url, nil, function (response, isSuccess)
	self.HttpRequestByKey("POST", "RemoveVoiceRoom", {tostring(roomId)}, nil, function (response, isSuccess)
		print("remove voice room", Lib.v2s(response))
		if not isSuccess then
			print("RemoveVoiceRoom Error: " , response.code)
			return
		end
	end, {}, true)
end



function AsyncProcess.UploadPrivilege(userId)
	-- local url = strfmt("%s/gameaide/api/v1/inner/game/privilege/upload", self.ServerHttpHost)
	local params = {{"gameId", gameName}, {"userId", tostring(userId)}}
	-- self.HttpRequest("POST", url, params, function(response, isSuccess)
	self.HttpRequestByKey("POST", "UploadPrivilege", {}, params, function(response, isSuccess)
		if not isSuccess then
			print("UploadPrivilege Error:" .. userId .. Lib.v2s(response))
			return
		end
		local player = Game.GetPlayerByUserId(userId)
		if player then
			Trigger.CheckTriggers(player:cfg(), "UPLOAD_PRIVILEGE_SUCCEED", {obj1 = player})
		end
	end, {}, true)
end

---该接口只提供给Lib.payMoney方法使用，需要消耗平台货币请使用Lib.payMoney方法
---@param userId number 用户userId
---@param uniqueId number 物品唯一Id
---@param currency number 货币类型（0：金魔方 1：蓝魔方 2：金币）
---@param price number 价格
---@param callback function 回调方法
function AsyncProcess.BuyGoods(userId, uniqueId, currency, price, session, callback)
	-- local url = strfmt("%s/pay/api/v2/inner/pay/users/purchase/game/props", self.ServerHttpHost)
	local player = Game.GetPlayerByUserId(userId)
	if not player then
		return
	end
	local body = {
		gameId = gameName,
		engineVersion = tonumber(debugPort.engineVersion),
		appVersion = player.clientInfo and tonumber(player.clientInfo.version_code) or 0,
		packageName = player.clientInfo and player.clientInfo.package_name or 0,
		userId = userId,
		propsId = math.min(math.max(uniqueId, -2147483648), 2147483647),
		currency = currency,
		quantity = price
	}
	Lib.logInfo(string.format("[%s][PayDiamond]", gameName), "uniqueId=" .. tostring(uniqueId))
	-- self.HttpRequest("POST", url, nil, function(response, isSuccess)
	self.HttpRequestByKey("POST", "BuyGoods", {}, nil, function(response, isSuccess)
		local data = response.data
		if not player:isValid() then
			---玩家消费魔方后下线了，回滚订单，返还魔方
			if isSuccess then
				AsyncProcess:ProcessOrder(userId, data.orderId, false)
			end
			return
		end

		if not isSuccess then
			if callback then
				callback(userId, false, session)
			end
			return
		end

		---更新玩家的魔方数和金币数
		player:UpdateDiamondsAndGolds(data.gDiamonds, data.golds)

		if callback then
			---处理回调，发放购买到的物品
			local success, consume = xpcall(callback, debug.traceback, userId, true, session)
			if not success then
				---处理失败，回滚订单，打印Log
				print("-----------[SCRIPT_EXCEPTION]------------\n", consume)
				consume = false
			end
			if consume == nil then
				---没有返回值使用默认消耗订单
				---返回false可以回滚订单，可以用于处理消耗魔方后，但背包已满给不了道具等情况
				consume = true
			end
			AsyncProcess:ProcessOrder(userId, data.orderId, consume)
		else
			---默认消耗订单
			AsyncProcess:ProcessOrder(userId, data.orderId, true)
		end
	end, body)
end

function AsyncProcess.GetReward(func, userId, data)
	local urlKey = "GetReward" -- strfmt("%s/game/api/v1/users/games/settlement", self.ServerHttpHost)
	local params = {{"gameId", gameName}, {"userId", tostring(userId)}}
	-- self.HttpRequest("POST", url, params, function (response, isSuccess)
	self.HttpRequestByKey("POST", "GetReward", {}, params, function (response, isSuccess)
		print("AsyncProcess.GetReward", urlKey, userId, Lib.v2s(response))
		if not isSuccess then
			print("AsyncProcess.GetReward response error")
			return
		end
		local reward = response["data"]
		if reward ~= nil then
			local player = Game.GetPlayerByUserId(reward.userId)
			if player then
				local p_data = player:data("main")
				p_data.gold = reward.golds or 0
				p_data.hasGet = reward.hasGet or 0
				p_data.available = reward.available or 0
			end
		end
		if func then
			func()
		end
	end, data)
end

function AsyncProcess.Report(userId, time, kills, rank, isCount, integral, type)
	local urlKey = "Report" -- strfmt("%s/game/api/v2/inner/users/games/reporting", self.ServerHttpHost)
	local data = {
		gameId = gameName,
		kill = kills,
		meanTime = time,
		rank = rank,
		isCount = isCount,
		integral = integral,
		type = type
	}
	local params = {{"userId", tostring(userId)}}
	-- self.HttpRequest("POST", url, params, function (response)
	self.HttpRequestByKey("POST", "Report", {}, params, function (response)
		print("AsyncProcess.Report", urlKey, Lib.v2s(response))
	end, data)
end

function AsyncProcess.GetRewardList(func, data, ...)
	local arg = table.pack(...)
	local urlKey = "GetRewardList" --strfmt("%s/game/api/v1/users/inner/games/settlement/list", self.ServerHttpHost)
	-- self.HttpRequest("POST", url, nil, function (response, isSuccess)
	self.HttpRequestByKey("POST", "GetRewardList", {}, nil, function (response, isSuccess)
		print("AsyncProcess.GetRewardList", urlKey, Lib.v2s(response))
		if not isSuccess then
			print("AsyncProcess.GetRewardList response error")
			return
		end
		local rewards = response["data"]
		if rewards ~= nil then
			for i, reward in pairs(rewards) do
				local player = Game.GetPlayerByUserId(reward.userId)
				if player then
					local p_data = player:data("main")
                    p_data.gold = reward.golds or 0
                    p_data.hasGet = reward.hasGet or 0
                    p_data.available = reward.available or 0
				end
			end
		end
		if func then
			func(table.unpack(arg, 1, arg.n))
		end
	end, data)
end

function AsyncProcess.ReportList(func, data)
	local urlKey = "ReportList" -- strfmt("%s/game/api/v2/inner/users/games/reporting/list", self.ServerHttpHost)
	-- self.HttpRequest("POST", url, nil, function (response)
	self.HttpRequestByKey("POST", "ReportList", {}, nil, function (response)
		print("AsyncProcess.ReportList", urlKey, Lib.v2s(response))
		if func then
			func()
		end
	end, data)
end

function AsyncProcess.GetGoldReward(func, userId, golds)
	local urlKey = "GetGoldReward" --strfmt("%s/game/api/v1/users/games/settlement/golds", self.ServerHttpHost)
	local params = {{"gameId", gameName}, {"userId", tostring(userId)}, {"golds", tostring(golds)}}
	-- self.HttpRequest("POST", url, params, function (response, isSuccess)
	self.HttpRequestByKey("POST", "GetGoldReward", {}, params, function (response, isSuccess)
		print("AsyncProcess.GetGoldReward", urlKey, userId, Lib.v2s(response))
		local reward = response["data"]

		if not isSuccess then
			print("AsyncProcess.GetGoldReward response error")
			return
		end

		if reward ~= nil then
			local player = Game.GetPlayerByUserId(reward.userId)
			if player ~= nil then
				local data = player:data("main")
				data.gold = reward.golds or 0
				data.hasGet = reward.hasGet or 0
				data.available = reward.available or 0
			end
		end
		if func then
			func()
		end
	end, {})
end

function AsyncProcess.LoadUsersInfo(userIds)
	self.RequestUsersSimpleInfo(userIds)
end

function AsyncProcess.RequestUsersSimpleInfo(userIds)
	if not userIds or #userIds == 0 then
		return
	end
	-- local url = strfmt("%s/user/api/v1/inner/simple-info", self.ServerHttpHost)
    local params = { {"userIdList", tconcat(userIds, ",")}, }
	-- self.HttpRequest("GET", url, params, function(response, isSuccess)
	self.HttpRequestByKey("GET", "RequestUsersSimpleInfo", {}, params, function(response, isSuccess)
        if not isSuccess then
            print("AsyncProcess.RequestUsersSimpleInfo response error", tconcat(userIds), cjson.encode(response))
            -- TODO
            return
        end
		--Lib.logDebug("RequestUsersSimpleInfo response.data = ", Lib.v2s(response.data))
        UserInfoCache.UpdateUserInfos(response.data)
    end)
end

local function RequestPlayerDetailInfo(userId, callback)
	if not self.ServerHttpHost or self.ServerHttpHost == "" then
		print("AsyncProcess.RequestPlayerDetailInfo error, ServerHttpHost is nil !")
		callback(nil)
		return
	end
	-- local url = strfmt("%s/user/api/v1/inner/user/details", self.ServerHttpHost)
	local params = {{"userId", userId}, {"gameId", gameName}, }
	-- self.HttpRequest("GET", url, params, function (response, isSuccess)
	self.HttpRequestByKey("GET", "RequestPlayerDetailInfo", {}, params, function (response, isSuccess)
		if not isSuccess then
            print("AsyncProcess.RequestPlayerDetailInfo response error", cjson.encode(params), cjson.encode(response))
			callback(nil)
            return
        end
        callback(response.data)
	end, nil, true)
end

local function RequestPlayersSimpleInfo(userIds, callback, timeout)
	local timer
	local session = UserInfoCache.LoadCacheByUserIds(userIds, function ()
		if timer then
			timer()
		end
		callback()
	end)
	if session and timeout then
		timer = World.Timer(timeout, function ()
			--print("RequestPlayersSimpleInfo timeout", session, timeout, table.concat(userIds, ","))
			UserInfoCache.CancelRequest(session)
			callback()
		end)
	end
end

function AsyncProcess.PlayerLoadDetailInfo(player, callback)
	local userId = player.platformUserId
	RequestPlayerDetailInfo(userId, function (info)
		if not player:isValid() then
			return
		end
		if not info then
			callback(true)
			return
		end
		UserInfoCache.UpdateUserInfo(userId, info)
		-- player.name = info.nickName
		player:setName(info.nickName)
		player.vars.clanName = info.clanName or ""
		player.vars.vip = player:getPlayerAttrInfo().mainInfo.vip
		callback(true)
	end)
end

function AsyncProcess.RankLoadPlayersInfo(userIds, ...)
	local params = table.pack(...)
	RequestPlayersSimpleInfo(userIds, function ()
		local playerInfos = {}
        for _, userId in pairs(userIds) do
            playerInfos[userId] = UserInfoCache.GetCache(userId)
        end
        Rank.UpdatePlayerInfo(playerInfos, table.unpack(params))
	end, 20 * 5)
end

function AsyncProcess.RequestRankRange(name, count)
	RedisHandler:ZRange(name, 0, count - 1, function(success, data)
		if not success then
			print("AsyncProcess.RequestRankRange request error", name, data)
		else
			Rank.ReceiveRankData(name, data)
		end
	end)
end

-- 请求特定范围的排名数据,平台的排名范围是0~n-1
function AsyncProcess.RequestRankScope(name, startNum, endNum, totalSize)
	RedisHandler:ZRange(name, startNum-1, endNum -1, function(success, data)
		if not success then
			print("AsyncProcess.RequestRankRange request error", name, data)
		else
			Rank.RequestPlatformWeekRankData(name, endNum, totalSize)
			Rank.ReceiveRankScopeData(name, data, startNum, endNum, totalSize)
		end
	end)
end

function AsyncProcess.RequestPlayerRankInfo(userId, name)

    RedisHandler:ZScore(name, tostring(userId), function(success, score, rank)

		if not success then
			print("AsyncProcess.RequestPlayerRankInfo request error", name, userId, score, rank)
		else
			Rank.ReceiveUserRankInfo(tonumber(userId), name, score, rank)
		end
	end)
end

function AsyncProcess.RequestLastWeekPlayerRankInfo(userId, name)
	RedisHandler:ZScore(name, tostring(userId), function(success, score, rank)

		if not success then
			print("AsyncProcess.RequestLastWeekPlayerRankInfo request error", name, userId, score, rank)
		else
			Rank.ReceiveLastWeekUserRankInfo(tonumber(userId), name, score, rank)
		end
	end)
end

function AsyncProcess.RequestRankCounter(userId, name)
	RedisHandler:IncCounter(name, function(success, count)
		if not success then
			print("AsyncProcess.RequestRankCounter request error", name, userId, count)
		else
			print("AsyncProcess.RequestRankCounter request success", name, userId, count)

			Rank.ReceiveRankCounter(tonumber(userId), name, count)
		end
	end)
end

function AsyncProcess.ResetRankCounter(names)
	RedisHandler:ResetCounter(names, function(success, count)
		if not success then
			print("AsyncProcess.ResetRankCounter request error", name, count)
		else
			print("AsyncProcess.ResetRankCounter request success", name, count)
			--Rank.ReceiveResetRankCounter(name, count)

		end
	end)
end

function AsyncProcess.RequestRankDataCount(name)
	print("AsyncProcess.RequestRankDataCount name", name)
	RedisHandler:ZCard(name, function(success, count)
		if not success then
			print("AsyncProcess.RequestRankDataCount request error", name, count)
		else
			print("AsyncProcess.RequestRankDataCount request success",name, count)
		end
	end)
end

function AsyncProcess.GetBlockmodsExpRule()
	-- local url = strfmt("%s/activity/api/v2/inner/activity/games/settlement/rule", self.ServerHttpHost)
	local params = {
		{"gameId", gameName},
		{"engineVersion", debugPort.engineVersion}
	}
	-- self.HttpRequest("GET", url , params, function (response)
	self.HttpRequestByKey("GET", "GetBlockmodsExpRule", {} , params, function (response)
		print("AsyncProcess.GetBlockmodsExpRule", "GetBlockmodsExpRule") --url)

		local data = response["data"]
		if data ~= nil then
			Game.initRole(data)
		else
			Game.disable()
		end
	end)
end

function AsyncProcess.GetBlockymodsUserExp(userId)
	-- local url = strfmt("%s/activity/api/v1/inner/activity/games/user/exp", self.ServerHttpHost)
	local params = {{"userId", tostring(userId)}}

	-- self.HttpRequest("GET", url , params, function (response, isSuccess)
	self.HttpRequestByKey("GET", "GetBlockymodsUserExp", {} , params, function (response, isSuccess)
		print("AsyncProcess.GetBlockymodsUserExp", "GetBlockymodsUserExp")--url)
		if not isSuccess then
			print("AsyncProcess.GetBlockymodsUserExp response error")
			return
		end
		local expInfo = response["data"]
		if expInfo ~= nil then
			local player = Game.GetPlayerByUserId(expInfo.userId)
			if player ~= nil then
				Game.addExpCache(expInfo.userId, expInfo.level, expInfo.experience, expInfo.expGetToday)
			end
		end
	end)
end

function AsyncProcess.SaveBlockymodsUsersExp(data)
	-- local url = strfmt("%s/activity/api/v1/inner/activity/games/records", self.ServerHttpHost)
	-- self.HttpRequest("POST", url , nil, function (response)
	self.HttpRequestByKey("POST", "SaveBlockymodsUsersExp", {} , nil, function (response)
		print("AsyncProcess.SaveBlockymodsUsersExp", "SaveBlockymodsUsersExp")--url)
	end, data)
end

--限大区、限语言、限人数邀请，g2020专用，其他项目不要想pitch
function AsyncProcess.SendBroadcastMessage(targets, content, msgType, scope)
    local urlKey = "SendBroadcastMessage" -- strfmt("%s/gameaide/api/v1/inner/msg/invite-users", self.ServerHttpHost)
    content.engineVersion = debugPort.engineVersion
    content.gameType = gameName

    local body = {
        content = cjson.encode(content),
        gameType = gameName,
        msgType = msgType,
        scope = scope, -- 'all', 'game', 'user'
        targets = targets,
    }
    local params = {}
    -- self.HttpRequest("POST", url, params, function(response, isSuccess)
	self.HttpRequestByKey("POST", "SendBroadcastMessage", {}, params, function(response, isSuccess)
        if not isSuccess then
            print("AsyncProcess.SendBroadcastMessage response error", urlKey, cjson.encode(params), cjson.encode(response))
            return
        end
        print("AsyncProcess.SendBroadcastMessage>>>", cjson.encode(body), urlKey, cjson.encode(response))
    end, body)
end

function AsyncProcess.SendBroadcastMessageMsgSend(targets, content, msgType, scope)
	local urlKey = "SendBroadcastMessageMsgSend" -- strfmt("%s/gameaide/api/v1/inner/msg/send", self.ServerHttpHost)
	content.engineVersion = debugPort.engineVersion
	content.gameType = gameName

	local body = {
		content = cjson.encode(content),
		gameType = gameName,
		msgType = msgType,
		scope = scope, -- 'all', 'game', 'user'
		targets = targets,
	}
	local params = {}
	-- self.HttpRequest("POST", url, params, function(response, isSuccess)
	self.HttpRequestByKey("POST", "SendBroadcastMessageMsgSend", {}, params, function(response, isSuccess)
		if not isSuccess then
			print("AsyncProcess.SendBroadcastMessage1 response error", urlKey, cjson.encode(params), cjson.encode(response))
			return
		end
	end, body)
end

function AsyncProcess.GetSumRechargeGCube(userId, callback)
    local urlKey = "GetSumRechargeGCube" -- strfmt("%s/pay/api/v1/inner/user/game/recharge/sum/gDiamond", self.ServerHttpHost)
    local params = {
        { "userId", tostring(userId) },
        { "gameId", gameName }
    }
	-- self.HttpRequest("GET", url, params, function (response, isSuccess)
	self.HttpRequestByKey("GET", "GetSumRechargeGCube", {}, params, function (response, isSuccess)
		if not isSuccess then
			print("GetSumRechargeGCube Failed: " .. Lib.v2s(response))
			return
		end
		callback(response.data)
	end, {}, true)
end

function AsyncProcess.GetUserAnimoji(userId, callback)
	-- local url = strfmt("%s/decoration/api/v1/inner/decorations/actions", self.ServerHttpHost)
	local params = {
		{"userId", userId},
		{"engineVersion", debugPort.engineVersion}
	}
	-- self.HttpRequest("GET", url, params, function (response, isSuccess)
	self.HttpRequestByKey("GET", "GetUserAnimoji", {}, params, function (response, isSuccess)
		if not isSuccess then
			return
		end
		if callback then
			callback(response.data)
		end
	end, {}, true)
end

function AsyncProcess.DeleteAudioDir()
    -- local url = strfmt("%s/user/api/v1/inner/folder", self.ServerHttpHost)
	local params = {
		{"directory", Game.GetAudioDir()}
	}
    -- self.HttpRequest("DELETE", url, params, function (response, isSuccess)
	self.HttpRequestByKey("DELETE", "DeleteAudioDir", {}, params, function (response, isSuccess)

    end, {}, true)
end

function AsyncProcess.GetExchangeProp(userId, callback)
	-- local path = strfmt("%s/activity/api/v1/inner/collect/exchange/game/props", self.ServerHttpHost)
	local params = {
		{ "userId", tostring(userId) },
		{ "gameId", gameName }
	}
	-- self.HttpRequest("GET", path, params, function(response, isSuccess)
	self.HttpRequestByKey("GET", "GetExchangeProp", {}, params, function(response, isSuccess)
		if isSuccess then
			callback(response["data"], 1)
		end
	end)
end

function AsyncProcess.SetExchangeProp(userId, propsId, propsCount, expiryTime)
	-- local path = strfmt("%s/activity/api/v1/inner/collect/exchange/game/props", self.ServerHttpHost)
	local params = {
		{ "userId", tostring(userId) },
		{ "gameId", gameName },
		{ "gamePropsId", tostring(propsId) },
		{ "propsAmount", tostring(propsCount) },
		{ "expiryDate", tostring(expiryTime) }
	}
	-- self.HttpRequest("POST", path, params, function()
	self.HttpRequestByKey("POST", "SetExchangeProp", {}, params, function()

	end, {})
end

function AsyncProcess.ConsumeExchangeProp(userId, propsId, callback)
	-- local path = strfmt("%s/activity/api/v1/inner/collect/exchange/game/notify", self.ServerHttpHost)
	local params = {
		{ "userId", tostring(userId) },
		{ "gameId", gameName },
		{ "gamePropsId", propsId }
	}
	-- self.HttpRequest("POST", path, params, function(response, isSuccess)
	self.HttpRequestByKey("POST", "ConsumeExchangeProp", {}, params, function(response, isSuccess)
		if isSuccess then
			callback(response["data"], 1)
		end
	end, {})
end

function AsyncProcess.GetUserRelation(userId, users, func)
	-- local url = strfmt("%s/friend/api/v1/inner/friends/filter", self.ServerHttpHost)
	local params = {
		{"userId",userId},
		{"friendIds",table.concat(users, ",")},
	}
	-- self.HttpRequest("GET", url, params, function(response)
	self.HttpRequestByKey("GET", "GetUserRelation", {}, params, function(response)
		if response.code ~= 1 then
			print("GetUserRelation Error:" , response.code)
			return
		end
		if func then
			func(response.data)
		end
	end)
end

function AsyncProcess.GetSensitiveWordConfig()
	-- local url = strfmt("%s/config/files/%s", self.ServerHttpHost, "name-sensitive-word-config")
	-- self.HttpRequest("GET", url , {}, function (response)
	self.HttpRequestByKey("GET", "GetSensitiveWordConfig", {"name-sensitive-word-config"}, {}, function (response)
		local data = response["data"]
		if data ~= nil then
			FilterWord:unloadSetting()
			for _, word in pairs(data) do
				World.CurWorld:addSensitiveWord(word)
			end
		end
	end)
end

---分页获取对应key记录排行榜的数据
function AsyncProcess:GetGameRankList(key, pageNo, pageSize, callback)
	-- local path = strfmt("%s/gameaide/api/v1/inner/game/rank", self.ServerHttpHost)
	local params = {
		{ "key", tostring(key) },
		{ "pageNo", tostring(pageNo) },
		{ "pageSize", tostring(pageSize) }
	}
	-- self.HttpRequest("GET", path , params, function(response)
	self.HttpRequestByKey("GET", "GetGameRankList", {}, params, function(response)
		callback(response["data"] or {})
	end)
end

---分页获取对应key记录排行榜的数据
function AsyncProcess:ReportGameRank(key, member, scores, maxSize, expireTime)
	maxSize = maxSize or 10
	-- local path = strfmt("%s/gameaide/api/v1/inner/game/rank", self.ServerHttpHost)
	local data = {
		key = tostring(key),
		maxSize = maxSize,
		member = tostring(member),
		scores = tostring(scores),
		expireTime = expireTime
	}
	-- self.HttpRequest("POST", path, {}, function(response, isSuccess)
	self.HttpRequestByKey("POST", "ReportGameRank", {}, {}, function(response, isSuccess)
		if not isSuccess then
			Lib.logInfo("ReportGameRank fail ")
			Lib.logInfo(Lib.v2s(data))
			return
		end

		Lib.logInfo("ReportGameRank success ")
	end, data)
end

---删除排行榜数据
function AsyncProcess:DeleteGameRank(key)
	-- local path = strfmt("%s/gameaide/api/v1/inner/game/rank", self.ServerHttpHost)
	local params = {
		{ "key", tostring(key) },
	}
	-- self.HttpRequest("DELETE", path, params, function(_, _)
	self.HttpRequestByKey("DELETE", "DeleteGameRank", {}, params, function(_, _)

	end, {})
end

---删除排行榜member数据
function AsyncProcess:DeleteGameRankMember(key, member, callback)
	-- local path = strfmt("%s/gameaide/api/v1/inner/game/rank/member", self.ServerHttpHost)
	local params = {
		{ "key", tostring(key) },
		{ "member", tostring(member) },
	}
	-- self.HttpRequest("DELETE", path, params, function(response, isSuccess)
	self.HttpRequestByKey("DELETE", "DeleteGameRankMember", {}, params, function(response, isSuccess)
		if not isSuccess then
			Lib.logInfo("DeleteGameRank fail ")
			Lib.logInfo(Lib.v2s(params))
			return
		end

		Lib.logInfo("DeleteGameRank success ")

		if callback then
			callback()
		end
	end, {})
end

---处理订单，每一笔魔方支付都要处理订单，正常消耗订单，异常回滚订单
function AsyncProcess:ProcessOrder(userId, orderId, consume)
	if consume then
		---消耗订单
		-- local path = strfmt("%s/pay/api/v1/pay/users/game/props/billings", self.ServerHttpHost)
		local params = {
			{ "orderId", tostring(orderId) }
		}
		-- self.HttpRequest("PUT", path, params, function(_, _)
		self.HttpRequestByKey("PUT", "Billings", {}, params, function(_, _)
			Lib.logInfo(string.format("[%s][ConsumeOrder]", gameName), "orderId=" .. orderId)
		end, {})
	else
		---回滚订单
		-- local path = strfmt("%s/pay/api/v1/pay/inner/users/game/props/billings/refund", self.ServerHttpHost)
		local params = {
			{ "orderId", tostring(orderId) }
		}
		-- self.HttpRequest("PUT", path, params, function(_, _)
		self.HttpRequestByKey("PUT", "BillingsRefund", {}, params, function(_, _)
			Lib.logInfo(string.format("[%s][RefundOrder]", gameName), "orderId=" .. orderId)
			local player = Game.GetPlayerByUserId(userId)
			if player then
				AsyncProcess.LoadUserMoney(userId)
			end
		end, {})
	end
end

---获取Connector列表
function AsyncProcess.GetConnectorListApi(callback, retryTimes)
	-- local path = self.ServerHttpHost .. "/game/api/v1/inner/region/connector-cluster/{regionCode}/{gameId}"
	local roomGameConfig = Server.CurServer:getConfig()
	local serverRegionId = roomGameConfig:getRegionId()
	-- path = string.gsub(path, "{regionCode}", serverRegionId)
	-- path = string.gsub(path, "{gameId}", World.GameName)
	retryTimes = retryTimes or 3

	-- self.HttpRequest("GET", path, {}, function(data, code)
	self.HttpRequestByKey("GET", "GetConnectorListApi", {serverRegionId, World.GameName}, {}, function(data, code)
		if not data then
			if retryTimes > 0 then
				self.GetConnectorListApi(callback, retryTimes - 1)
				return
			end
		end
		callback(code, data)
	end, {})
end

---获取玩家权限列表
function AsyncProcess.GetGamePlayerAuthList()
	-- local path = self.ServerHttpHost .. "/config/files/game-player-auth-config"
	-- self.HttpRequest("GET", path, {}, function(response, _)
	self.HttpRequestByKey("GET", "GetGamePlayerAuthList", {}, {}, function(response, _)
		if response and response.data and response.code == 1 then
			Game.SetPlayerAuthList(response.data)
		end
	end, {})
end

---保存玩家游戏公共数据
---@param userId number  	用户id
---@param dataStr string 	要保存的数据
---@param callback function	结果回调函数
function AsyncProcess.SavePlayerGamePublicData(userId, dataStr, callback)
	local url = strfmt("%s/gameaide/api/v1/inner/game/user/data/save/%s", self.ServerHttpHost, userId)
	local params = {}
	local body = {
		gameId= World.GameName ,
		data = cjson.encode(dataStr)  ,
	}
	self.HttpRequest("POST", url, params, function (response, isSuccess)
		if not isSuccess then
			Lib.logDebug("SavePlayerGamePublicData Error: " , response.code)
			if callback then
				callback(false)
			end
			return
		end
		Lib.logDebug("SavePlayerGamePublicData success: " , Lib.v2s(response))
		if callback then
			callback(true)
		end
	end, body, true)
end

---获取玩家公共数据
---@param userIds number[] 	用户id数组
---@param callback function	结果回调函数
function AsyncProcess.GetPlayerGamePublicData(userIds, callback)
	local url = strfmt("%s/gameaide/api/v1/inner/game/user/data/list/%s", self.ServerHttpHost, World.GameName)
	local params = {}
	local body = userIds

	local function safeDecodeJSON(content, def)
		if content == "" then
			return def or false
		end
		local ok, ret = xpcall(cjson.decode, debug.traceback, content)
		if not ok then
			Lib.logDebug("json decode fail:",content)
			return def or false
		end
		return ret
	end

	self.HttpRequest("POST", url, params, function(response, isSuccess)
		if not isSuccess then
			Lib.logDebug("GetPlayerGamePublicData:Error parma:", response.code, Lib.v2s(userIds, 2))
			return
		end
		if callback then
			for _, val in pairs(response.data) do
				val.data = safeDecodeJSON(val.data, {})
			end
			callback(response.data)
		end
	end, body, true)
end