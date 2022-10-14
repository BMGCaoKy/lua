
local cjson = require("cjson")
local strfmt = string.format
local tconcat = table.concat
local tostring = tostring
local type = type
local traceback = traceback

local RedisHandler = L("RedisHandler", {})

function RedisHandler:init()
	local baseUrl       = Server.CurServer:getDataServiceURL()
	local secondBaseUrl = Server.CurServer:getDataServiceSecondURL()

	self.enable		    = baseUrl ~= ""
	self.getZScoreUrl   = baseUrl .. "/api/v1/game/rank"
	self.postZIncrByUrl = baseUrl .. "/api/v1/game/rank"
	self.setZExpireUrl  = baseUrl .. "/api/v1/game/rank/expire"
	self.getZRangeUrl   = baseUrl .. "/api/v1/game/rank/list"
	self.getZCardUrl	= baseUrl .. "/api/v1/game/rank/length"
	self.incCounterUrl  = baseUrl .. "/api/v1/game/rank/inc-counter"
	self.resetCounterUrl = baseUrl .. "/api/v1/game/rank/reset-counter"

	self.postZIncrBySecondUrl  = secondBaseUrl .. "/api/v1/game/rank"
	self.setZExpireSecondUrl  = secondBaseUrl .. "/api/v1/game/rank/expire"

	self.ZIncrByQueue = {}
	self.ZExpireQueue = {}
	self.sendingZIncrBy = false
	self.sendingZExpire = false
	self.sendZIncrByTime = 0
	self.sendZExpireTime = 0
	if self.enable then
		self.checkPostTimer = World.Timer(20 * 10, self.checkPostData, self)
	end
	print("RedisHandler init", self.enable)
end

function RedisHandler:checkPostData()
	self:trySendZIncBy()
	self:trySendZExpire()
	return true
end

function RedisHandler:trySendZIncBy(immediately)
	local cacheCount = #self.ZIncrByQueue
	local canSend = immediately or (not self.sendingZIncrBy and cacheCount > 0 and (cacheCount >= 3 or os.time() - self.sendZIncrByTime > 200))
	if canSend then
		local ok, msg = xpcall(self.sendZIncrByData, traceback, self)
		if not ok then
			perror("RedisHandler sendZIncrByData error", msg)
		end
	end
end


function RedisHandler:trySendZExpire(immediately)
	local cacheCount = #self.ZExpireQueue
	local canSend = immediately or (not self.sendingZExpire and cacheCount > 0 and (cacheCount >= 3 or os.time() - self.sendZExpireTime > 200))
	if canSend then
		local ok, msg = xpcall(self.sendZExpireData, traceback, self)
		if not ok then
			perror("RedisHandler sendZExpireData error", msg)
		end
	end
end


function RedisHandler:hasCachedData()
	return next(self.ZIncrByQueue) ~= nil or next(self.ZExpireQueue) ~= nil
end

function RedisHandler:ZExpireat(setName, timeStamp, immediately)
	if not self.enable then
		return
	end
	local queue = self.ZExpireQueue
	queue[#queue + 1] = { setName = setName, key = tostring(timeStamp), value = 0, rank = -1 }
	self:trySendZExpire(immediately)
end

function RedisHandler:ZIncrBy(setName, key, value, immediately)
	if not self.enable then
		return
	end
	local queue = self.ZIncrByQueue
	queue[#queue + 1] = { setName = setName, key = key, value = value, rank = 0 }
	self:trySendZIncBy(immediately)
end

function RedisHandler:ZAdd(setName, key, value)
	if not self.enable then
		return
	end
	local queue = self.ZIncrByQueue
	queue[#queue + 1] = { setName = setName, key = key, value = value, rank = 1 }
end

function RedisHandler:ZRemove(setName, key, immediately)
	if not self.enable then
		return
	end
	local queue = self.ZIncrByQueue
	queue[#queue + 1] = { setName = setName, key = key, value = 0, rank = 1 }
	self:trySendZIncBy(immediately)
end

function RedisHandler:IncCounter(key, callback)
	if not self.enable then
		callback(true, -1)
		return
	end

	local params = { { "key", key }, { "delta", 1 }, }
	AsyncProcess.HttpRequest("POST", self.incCounterUrl, params, function(response)
		local content = cjson.encode(response)
		print("RedisHandler IncCounter response", #content, content:sub(1, 100))

		if response.status_code then
			print("RedisHandler IncCounter response error", key, response.status_code)
			callback(false, response.status_code, -1)
			return
		end

		local success, count = false, -1
		local code, data, message = response.code, response.data, response.message
		if not code or not data or not message then
			print("RedisHandler IncCounter error, lack of field", key, cjson.encode(response))
		elseif code ~= 1 then	-- 1: SUCCESS; 2: FAILED; 3: PARAM ERROR; 4: INNER ERROR; 5: TIME OUT; 6: AUTH_FAILED
			print("RedisHandler IncCounter error code", key, cjson.encode(response))
		elseif type(data) ~= "number" then
			print("RedisHandler IncCounter error data", key, cjson.encode(response))
		else
			success, count = true, tonumber(data)
		end
		callback(success, count)

	end)

end

function RedisHandler:ResetCounter(keys, callback)
	if not self.enable then
		callback(true, -1)
		return
	end
	Lib.logDebug("RedisHandler:ResetCounter keys = ", keys)
	local params = { { "keys", keys }, }
	AsyncProcess.HttpRequest("POST", self.resetCounterUrl, params, function(response)
		local content = cjson.encode(response)
		print("RedisHandler ResetCounter response", #content, content:sub(1, 100))

		if response.status_code then
			print("RedisHandler ResetCounter response error", key, response.status_code)
			callback(false, -1)
			return
		end

		local success, count = false, -1
		local code, data, message = response.code, response.data, response.message
		if not code or not data or not message then
			print("RedisHandler ResetCounter error, lack of field", key, cjson.encode(response))
		elseif code ~= 1 then	-- 1: SUCCESS; 2: FAILED; 3: PARAM ERROR; 4: INNER ERROR; 5: TIME OUT; 6: AUTH_FAILED
			print("RedisHandler ResetCounter error code", key, cjson.encode(response))
		elseif type(data) ~= "number" then
			print("RedisHandler ResetCounter error data", key, cjson.encode(response))
		else
			success, count = true, tonumber(data)
		end
		callback(success, count)

	end)
end

function RedisHandler:ZCard(setName, callback)
	print("RedisHandler:ZCard setName = ", setName)
	if not self.enable then
		callback(true, -1, 0)
		return
	end

	local params = { { "key", setName }, { "isNew", "1" }, }
	AsyncProcess.HttpRequest("GET", self.getZCardUrl, params, function(response)
		--local content = cjson.encode(response)
		--print("RedisHandler ZCard response", #content, content:sub(1, 100))
		if response.status_code then
			print("RedisHandler ZCard response error", setName, response.status_code)
			callback(false, response.status_code, -1)
			return
		end

		local success, count = false, -1
		local code, data, message = response.code, response.data, response.message
		if not code or not data or not message then
			print("RedisHandler ZCard error, lack of field", setName, cjson.encode(response))
		elseif code ~= 1 then	-- 1: SUCCESS; 2: FAILED; 3: PARAM ERROR; 4: INNER ERROR; 5: TIME OUT; 6: AUTH_FAILED
			print("RedisHandler ZCard error code", setName, cjson.encode(response))
		elseif type(data) ~= "number" then
			print("RedisHandler ZCard error data", setName, key, cjson.encode(response))
		else
			success, count = true, tonumber(data)
		end
		callback(success, count)

	end)
	
end

function RedisHandler:ZScore(setName, key, callback)	-- callback(success, score, rank)
	--print("RedisHandler ZScore", setName, key)
	if not self.enable then
		callback(true, -1, 0)
		return
	end
	local params = { { "key", setName }, { "member", key }, { "isNew", "1" }, }
	AsyncProcess.HttpRequest("GET", self.getZScoreUrl, params, function(response)
		local content = cjson.encode(response)
		print("RedisHandler ZScore response", #content, content:sub(1, 100))
		if response.status_code then
			print("RedisHandler ZScore response error", setName, key, response.status_code)
			callback(false, response.status_code, -1)
			return
		end
		local success, score, rank = false, -1, 0
		local code, data, message = response.code, response.data, response.message
		if not code or not data or not message then
			print("RedisHandler ZScore error, lack of field", setName, key, cjson.encode(response))
		elseif code ~= 1 then	-- 1: SUCCESS; 2: FAILED; 3: PARAM ERROR; 4: INNER ERROR; 5: TIME OUT; 6: AUTH_FAILED
			print("RedisHandler ZScore error code", setName, key, cjson.encode(response))
		elseif not data or type(data) == "table" and not next(data) then
			success, score, rank = true, 0, 0
		elseif type(data) ~= "table" or not data.rank or not data.score then
			print("RedisHandler ZScore error data", setName, key, cjson.encode(response))
		else
			success, score, rank = true, tonumber(data.score), math.floor(tonumber(data.rank))
		end
		callback(success, score, rank)
	end)
end

function RedisHandler:ZRange(setName, start, _end, callback)	-- callback(success, data)
	--print("RedisHandler ZRange", setName, start, _end)
	if not self.enable then
		callback(true, "")
		return
	end
	local params = { { "key", setName }, { "start", start }, { "end", _end }, { "isNew", "1" }, }
	AsyncProcess.HttpRequest("GET", self.getZRangeUrl, params, function(response)
		--local content = cjson.encode(response)
		--print("RedisHandler ZRange response", setName, start, _end, #content, content:sub(1, 100))
		if response.status_code then
			print("RedisHandler ZRange response error", setName, start, _end, response.status_code)
			callback(false, cjson.encode(response))
			return
		end
		local success, ret = false, "has parse error"
		local code, data, message = response.code, response.data, response.message
		if not code or not data or not message then
			print("RedisHandler ZRange error, lack of field", setName, start, _end, cjson.encode(response))
		elseif code ~= 1 then	-- 1: SUCCESS; 2: FAILED; 3: PARAM ERROR; 4: INNER ERROR; 5: TIME OUT; 6: AUTH_FAILED
			print("RedisHandler ZRange error code", setName, start, _end, cjson.encode(response))
		elseif not data or type(data) == "table" and not next(data) then
			success, ret = true, ""
		elseif type(data) ~= "table" then
			print("RedisHandler ZRange error data", setName, start, _end, cjson.encode(response))
		else
			local list = {}
			for i, v in ipairs(data) do
				if not v.member or not v.score then
					success, list = false, nil
					break
				end
				list[#list + 1] = strfmt("%s:%s", tostring(v.member), tostring(v.score))
			end
			if list then
				success, ret = true, table.concat(list, "#")
			end
		end
		callback(success, ret)
	end)
end

function RedisHandler:sendZIncrByData()
	if not self.enable or not next(self.ZIncrByQueue) then
		return
	end
	local list = {}
	for i, data in pairs(self.ZIncrByQueue) do
		list[i] = { key = data.setName, member = data.key, count = data.value, add = data.rank == 0 }
	end
	self.ZIncrByQueue = {}

	self.sendingZIncrBy = true
	local params = { { "isNew", "1" } }
	local body = cjson.encode(list)
	local function sendRequest(tryTimes, url)
		if tryTimes >= 3 then
			if url == self.postZIncrByUrl then
				sendRequest(1, self.postZIncrBySecondUrl)
			else
				perror("RedisHandler sendZIncrByData failed", body)
				self.sendingZIncrBy = false
				self.sendZIncrByTime = os.time()
			end
			return
		end
		AsyncProcess.HttpRequest("POST", url, params, function(response)
			--print("RedisHandler sendZIncrByData response", cjson.encode(response))
			local code = response.status_code or 200
			if code ~= 200 then
				--print("RedisHandler sendZIncrByData response error", code, tryTimes)
				sendRequest(tryTimes + 1, url)
				return
			end
			self.sendingZIncrBy = false
			self.sendZIncrByTime = os.time()
		end, body)
	end
	sendRequest(1, self.postZIncrByUrl)
end

function RedisHandler:sendZExpireData()
	if not self.enable or not next(self.ZExpireQueue) then
		return
	end
	local list = {}
	for i, data in pairs(self.ZExpireQueue) do
		list[i] = { key = data.setName, expireTime = data.key }
	end
	self.ZExpireQueue = {}

	self.sendingZExpire = true
	local params = { { "isNew", "1" } }
	local body = cjson.encode(list)
	local function sendRequest(tryTimes, url)
		if tryTimes >= 3 then
			if url == self.setZExpireUrl then
				sendRequest(1, self.setZExpireSecondUrl)
			else
				perror("RedisHandler sendZExpireData failed", body)
				self.sendingZExpire = false
				self.sendZExpireTime = os.time()
			end
			return
		end
		AsyncProcess.HttpRequest("PUT", url, params, function(response)
			--print("RedisHandler sendZExpireData response", cjson.encode(response))
			local code = response.status_code or 200
			if code ~= 200 then
				--print("RedisHandler sendZExpireData response error", code, tryTimes)
				sendRequest(tryTimes + 1, url)
				return
			end
			self.sendingZExpire = false
			self.sendZExpireTime = os.time()
		end, body)
	end
	sendRequest(1, self.setZExpireUrl)
end

return RedisHandler