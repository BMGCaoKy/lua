local misc = require("misc")
local cjson = require("cjson")
local traceback = traceback

local DBHandler = L("DBHandler", {})---@class DBHandler
local LocalData = T(DBHandler, "LocalData")

function DBHandler:init()
	self.useCommonTable = World.isEditorServer or false
	self.gameId = World.GameName
	self.dataTableName = self.useCommonTable and "pocket_edition_game_data" or self.gameId
	self.isBetaGame = string.sub(self.gameId or "",-1) == "b"
	print("!!!!!!!!!!!!!!!!!!!!!!!!! ", self.isBetaGame, World.GameName)

	local baseUrl = Server.CurServer:getDataServiceURL()
	local secondBaseUrl = Server.CurServer:getDataServiceSecondURL()
	self.enable	= baseUrl ~= "" and not World.IsLibServer
	if self.enable then
		if baseUrl:sub(1, 6) == "local:" then
			self.localFile = baseUrl:sub(7)
			local file = io.open(self.localFile, "rb")
			if file then
				local data = file:read("a")
				file:close()
				local text = misc.read_text(data)
				local line, pos
				while true do
					line, pos = misc.csv_decode(text, pos)
					if line then
						LocalData[line[1]] = line[2]
					end
					if not pos then
						break
					end
				end
			end
		else
			self.getDataUrl   		= baseUrl .. "/api/v2/game/data"
			self.postDataUrl  		= baseUrl .. "/api/v2/game/data"
			self.postTableUrl 		= baseUrl .. "/api/v2/game/data/table"
		end
		if secondBaseUrl ~= baseUrl and secondBaseUrl ~= "" then
			self.getDataSecondUrl   = secondBaseUrl .. "/api/v2/game/data"
			self.postDataSecondUrl  = secondBaseUrl .. "/api/v2/game/data"
		end
	end

	self.dataMap = {}	-- [userId][dataKey] = {data = data, postCallbackList = { xx }, immediately = xx}
	self.sendingMap = {} -- [userId][dataKey] = { postCallbackList = {callBack[1], callBack[2]}}
	self.cacheCount = 0
	self.lastSendTime = 0
	self.sendingData = false

	if self.enable then
		self.checkPostTimer = World.Timer(20 * 60, self.checkPostData, self)
	end
	print("DBHandler init", self.dataTableName, baseUrl, secondBaseUrl, self.enable)
end

function DBHandler:checkPostData()
	if not self.sendingData and (self.cacheCount >= 10 or os.time() - self.lastSendTime > 180) then
		local ok, msg = xpcall(self.postData, traceback, self)
		if not ok then
			Lib.logError("DBHandler postData error", msg)
		end
	end
	return true
end

function DBHandler:hasCachedData()
	return next(self.dataMap) ~= nil
end

local function sendGetDataRequest(self, player, userId, url, dataKey, params, tryTimes, callback)
	if tryTimes >= 3 then
		Lib.logError("DBHandler getData failed. url:", url, "userId:", userId, "dataKey:", dataKey)
		if url == self.getDataUrl and self.getDataSecondUrl then
			sendGetDataRequest(self, player, userId, self.getDataSecondUrl, dataKey, params, 1, callback)
		else
			player:onGetDBFailed(dataKey)
		end
		return
	end
	AsyncProcess.HttpRequest("GET", url, params, function(response)
		-- local content = cjson.encode(response)
		-- print("DBHandler getData response", cjson.encode(params), #content, content:sub(1, 1000))
		if not player:isValid() then
			Lib.logError("DBHandler getData player not valid. url:", url, "userId:", userId)
			if url == self.getDataUrl and self.getDataSecondUrl and url ~= self.getDataSecondUrl then
				sendGetDataRequest(self, player, userId, self.getDataSecondUrl, dataKey, params, 1, callback)
			else
				player:onGetDBFailed(dataKey)
			end
			return
		end

		if response.status_code then
			Lib.logError("DBHandler getData response error. response.status_code:", response.status_code, "tryTimes:", tryTimes)
			sendGetDataRequest(self, player, userId, url, dataKey, params, tryTimes + 1, callback)
			return
		end

		local code, data, message = response.code, response.data, response.message
		if not code or not message then
			Lib.logError("DBHandler getData error, lack of field, params:", cjson.encode(params), "response:", cjson.encode(response))
			player:onGetDBFailed(dataKey)
		-- 1: SUCCESS; 3: PARAM ERROR; 4: INNER ERROR; 11: ITEM_NOT_FOUND; 7002: TABLE_EXISTED
		elseif code == 1 then
			callback(dataKey, data.data)
		elseif code == 11 then
			callback(dataKey, "") -- new player
		elseif code == 3 then
			Lib.logWarning("DBHandler getData params error, params:", cjson.encode(params), "response:", cjson.encode(response))
			callback(dataKey, "")
		else
			Lib.logError("DBHandler getData error code, params:", cjson.encode(params), "response:", cjson.encode(response))
			player:onGetDBFailed(dataKey)
		end
	end)
end

local function getLocalData(callBack, ...)
	local key = table.concat({...}, "/")
	local data = LocalData[key] or ""
	World.Timer(1, callBack, data)
end

local function setLocalData(data, callBack, ...)
	local key = table.concat({...}, "/")
	LocalData[key] = data
	World.Timer(1, callBack)
	local lines = {}
	for k, v in pairs(LocalData) do
		lines[#lines + 1] = misc.csv_encode({k, v})
	end
	lines[#lines + 1] = ""
	misc.write_utf16(DBHandler.localFile, table.concat(lines, "\r\n"))
end

function DBHandler:getData(player, dataKey, callback)
	-- print("DBHandler getData", player.name, player.platformUserId, dataKey)
	if not self.enable then
		callback(dataKey, "")
		return
	end
	local userId = player.platformUserId
	local subKey = self.useCommonTable and string.format("%s:%s", self.gameId, dataKey) or dataKey
	if self.isBetaGame then
		subKey = self.gameId
	end
	-- print(" ??????????????????????? getData ", self.isBetaGame, subKey)
	if self.localFile then
		getLocalData(function (data)
			callback(dataKey, data)
		end, self.dataTableName, subKey, userId)
		return
	end
	-- check cache first
	local map = self.dataMap[userId]
	if map and map[dataKey] then
		callback(dataKey, map[dataKey].data)
		return
	end
	local params = {
		{ "userId", userId },
		{ "gameId", self.gameId },
		{ "key", dataKey },
		{ "subKey", subKey },
		{ "tableName", self.dataTableName },
	}
	sendGetDataRequest(self, player, userId, self.getDataUrl, dataKey, params, 1, callback)
end

local function sendGetDataByUserIdRequest(self, url, userId, dataKey, params, callback, failback, tryTimes)
	if tryTimes >= 3 then
		Lib.logError("DBHandler getData failed, userId:", userId, 1, ", url: ", url)
		if url == self.getDataUrl and self.getDataSecondUrl then
			sendGetDataByUserIdRequest(self, self.getDataSecondUrl, userId, dataKey, params, callback, failback, 1)
		else
			if failback then
				failback(userId)
			end
		end
		return
	end
	AsyncProcess.HttpRequest("GET", url, params, function(response)
		if response.status_code then
			print("DBHandler getData response error, response.status_code:", response.status_code, "tryTimes:", tryTimes, "url:", url)
			sendGetDataByUserIdRequest(self, url, userId, dataKey, params, callback, failback, tryTimes + 1)
			return
		end
		--print("---response--" .. Lib.v2s(response))
		local code, data, message = response.code, response.data, response.message
		failback = failback or function() end
		if not code or not message then
			Lib.logError("DBHandler getData error, lack of field. response:", cjson.encode(response))
			failback(userId)
		-- 1: SUCCESS; 3: PARAM ERROR; 4: INNER ERROR; 11: ITEM_NOT_FOUND; 7002: TABLE_EXISTED
		elseif code == 1 then
			callback(userId, data.data)
		elseif code == 11 then
			Lib.logError("DBHandler getData error, not data, params:", cjson.encode(params), "response:", cjson.encode(response))
			failback(userId, true)
		elseif code == 3 then
			Lib.logWarning("DBHandler getData params error, params:", cjson.encode(params), "response:", cjson.encode(response))
			failback(userId)
		else
			Lib.logError("DBHandler getData error code, params:", cjson.encode(params), "response:", cjson.encode(response))
			failback(userId)
		end
	end)
end

function DBHandler:getDataByUserId(userId, dataKey, callback,failback)
    -- print("---getDataByUserId--" .. userId .. "datakey" .. dataKey)
	if not self.enable then
		return
	end
	local subKey = self.useCommonTable and string.format("%s:%s", self.gameId, dataKey) or dataKey
	if self.isBetaGame then
		subKey = self.gameId
	end
	-- print(" ??????????????????????? getDataByUserId ", self.isBetaGame, subKey)
	if self.localFile then
		getLocalData(function (data) callback(userId, data) end, self.dataTableName, subKey, userId)
		return
	end
    local params = {
        { "userId", userId },
        { "gameId", self.gameId },
        { "key", dataKey },
        { "subKey", subKey },
        { "tableName", self.dataTableName },
    }
    sendGetDataByUserIdRequest(self, self.getDataUrl, userId, dataKey, params, callback, failback, 1)
end

function DBHandler:setData(userId, dataKey, data, immediately, callback)
	-- print("DBHandler setData", userId, dataKey, data, immediately)
	if not self.enable then
		return
	end
	dataKey = self.useCommonTable and string.format("%s:%s", self.gameId, dataKey) or dataKey
	if self.isBetaGame then
		dataKey = self.gameId
	end
	-- print(" ??????????????????????? setData ", self.isBetaGame, subKey)
	if self.localFile then
		setLocalData(data, function ()
				if callback then
					callback(200, dataKey)
				end
			end,
			self.dataTableName, dataKey, userId)
		return
	end
	local map = self.dataMap[userId]
	if not map then
		map = {}
		self.dataMap[userId] = map
	end
	local dataKeyMap = map[dataKey]
	if not dataKeyMap then
		dataKeyMap = {}
		map[dataKey] = dataKeyMap
	end
	dataKeyMap.data = data
	if immediately then
		dataKeyMap.immediately = true
	end
	if callback then
		if not dataKeyMap.postCallbackList then
			dataKeyMap.postCallbackList = { [1] = callback }
		else
			dataKeyMap.postCallbackList[#dataKeyMap.postCallbackList + 1] = callback
		end
	end
	self.cacheCount = self.cacheCount + 1
	if immediately or self.cacheCount >= 10 or os.time() - self.lastSendTime > 180 then
		self:postData()
	end
end

local function buildSendDataBodyAndMarkSending(self, userId, subKey, data)
	local userSendingMap = self.sendingMap[userId]
	if not userSendingMap then
		userSendingMap = {}
		self.sendingMap[userId] = userSendingMap
	end
	if not userSendingMap[subKey] then
		userSendingMap[subKey] = { postCallbackList = data.postCallbackList or {}}
		return {
			userId = userId,
			subKey = subKey,
			key = subKey,
			gameId = self.gameId,
			data = data.data,
		}
	else
		return nil
	end
end

local function sendPostRequest(self, url, params, body, tryTimes, sendRequestCallback)
	if tryTimes >= 3 then
		Lib.logError("DBHandler postData failed, url:", url, "self.dataTableName:", self.dataTableName, "body:", body)
		if url == self.postDataUrl and self.postDataSecondUrl then
			sendPostRequest(self, self.postDataSecondUrl, params, body, 1, sendRequestCallback)
		else
			sendRequestCallback("failed")
		end
		return
	end
	AsyncProcess.HttpRequest("POST", url, params, function(response)
		if response.code ~= 1 then
			Lib.logError("DBHandler postData response error, url:", url, "params:", cjson.encode(params), "response:", cjson.encode(response))
			if url == self.postDataUrl and self.postDataSecondUrl then
				sendPostRequest(self, self.postDataSecondUrl, params, body, 1, sendRequestCallback)
			else
				sendRequestCallback("error")
			end
			return
		end
		local code = response.status_code or 200
		if code ~= 200 and code ~= 201 then
			Lib.logWarning("DBHandler postData response error, url:", url, cjson.encode(response), "tryTimes:", tryTimes)
			sendPostRequest(self, url, params, body, tryTimes + 1, sendRequestCallback)
			return
		end
		sendRequestCallback("success")
	end, body)
end

local function sendingMapCallback(self, userId, subKey, code)
	local sendingMap = self.sendingMap
	local userSendingMap = sendingMap[userId]
	if userSendingMap then
		for _, callbackFunc in ipairs(userSendingMap[subKey] and userSendingMap[subKey].postCallbackList or {}) do
			callbackFunc(code, subKey)
		end
		userSendingMap[subKey] = nil
		if not next(userSendingMap) then
			sendingMap[userId] = nil
		end
	end
	if not next(sendingMap) then
		self.sendingData = false
	end
end

local function dataMapCallback(self, userId, subKey, params, callback)
	local dataMap = self.dataMap
	if dataMap[userId] and dataMap[userId][subKey] and dataMap[userId][subKey].immediately then
		self.sendingData = true
		local body = cjson.encode({[1] = buildSendDataBodyAndMarkSending(self, userId, subKey, dataMap[userId][subKey])})
		dataMap[userId][subKey] = nil
		sendPostRequest(self, self.postDataUrl, params, body, 1, callback)
	end
end

function DBHandler:postData()
	local dataMap = self.dataMap
	if not self.enable or not next(dataMap) then
		return
	end
	local params = { { "tableName", self.dataTableName } }
	local list = {}
	for userId, map in pairs(dataMap) do
		for key, data in pairs(map) do
			local dataBody = buildSendDataBodyAndMarkSending(self, userId, key, data)
			if dataBody then
				list[#list + 1] = dataBody
				dataMap[userId][key] = nil
				self.cacheCount = self.cacheCount - 1
			end
		end
		if not next(dataMap[userId]) then
			dataMap[userId] = nil
		end
	end
	if #list > 0 then
		local sendRequestCallback
		sendRequestCallback = function(code)
			for _, map in ipairs(list) do
				local userId, subKey = map.userId, map.subKey
				sendingMapCallback(self, userId, subKey, code)
				self.lastSendTime = os.time()
				dataMapCallback(self, userId, subKey, params, sendRequestCallback)
			end
		end
		self.sendingData = true
		local body = cjson.encode(list)
		sendPostRequest(self, self.postDataUrl, params, body, 1, sendRequestCallback)
	end
end

function DBHandler:checkHadSending()
	return self.sendingMap and next(self.sendingMap)
end

RETURN(DBHandler)