--local cjson = require("cjson")
---@class UserInfo
---@field userId number
---@field age number
---@field vip number
---@field name string
---@field nickName string
---@field colorfulNickName string
---@field picUrl string
---@field sex number
---@field country string 国家
---@field language string 语言
---@field tag string 部落id，值为0，表示未加入部落
---@field gameId string 当status=20时，该值有效，表示当前进入的游戏
---@field friend boolean 是否为好友
---@field status number 用户状态，10:表示在线；15:表示在Party中；20:表示游戏中；30:表示离线；
---@field level number 等级
---@field skins table 平台装扮
---@field region string 所在区
---@field isRobot boolean 是否是机器人
---@field clanName boolean 部落名
---@field clanId boolean 部落Id
---@field role boolean 部落职位，0:成员 10:长老 20:酋长

local self = UserInfoCache
UserInfoCache.EXPIRE_SECONDS = 60 * 30
UserInfoCache.REQUEST_TIMEOUT = 60
UserInfoCache.REQUEST_CHECK_INTERVAL = 20 * 60

local DUMMY = setmetatable({}, {__newindex = error})

function UserInfoCache.Init()
    self._session = 0
    ---@type table<string, UserInfo>
    self._caches = {}
    self._loadings = {} -- [userId] = { [session] = time }
    self._requests = {} -- [session] = { ids = {}, cb = func }
	self._requestCheckTimer = World.Timer(self.REQUEST_CHECK_INTERVAL, UserInfoCache.CheckTimeoutRequest)
	self._expireCheckTimer = World.Timer(self.EXPIRE_SECONDS * 20, UserInfoCache.CheckExpireCache)
end

function UserInfoCache.AllocSession()
	local session = self._session + 1
	self._session = session
	return session
end

function UserInfoCache.CheckExpireCache()
	local caches = self._caches
	local time = os.time()
	local expire = self.EXPIRE_SECONDS
	for id, data in pairs(caches) do
		if time - (data._time or 0) >= expire then
			caches[id] = nil
		end
	end
	return true
end

function UserInfoCache.FilterExistIds(userIds)
    local nonexists = {}
    local caches = self._caches
	local time = os.time()
    for _, id in pairs(userIds) do
		local data = caches[tostring(id)]
        if not data or (time - (data._time or 0) >= self.EXPIRE_SECONDS) then
            nonexists[#nonexists + 1] = id
        end
    end
    return nonexists
end

function UserInfoCache.LoadCacheByUserIds(userIds, callback)
    local func = callback
    if type(callback) == "string" then
        assert(Event[callback], "event not defined! " .. callback)
        func = function ()
            Lib.emitEvent(Event[callback])
        end
    end
    assert(type(func) == "function")

    local ids = self.FilterExistIds(userIds)
    if #ids == 0 then
        func()
        return
    end
    local loadings = self._loadings
    local session = self.AllocSession()
    local time = os.time()
    local need2loads = {}
    local waitings = {}
    for _, id in pairs(ids) do
        waitings[id] = true
        local map = loadings[id]
        if not map then
            map = {}
            loadings[id] = map
            need2loads[#need2loads + 1] = id
        end
        map[session] = time
    end
    self._requests[session] = { waitings = waitings, callback = func, time = os.time() }
    if #need2loads > 0 then
        AsyncProcess.LoadUsersInfo(need2loads)
	end
	return session
end

function UserInfoCache.CancelRequest(session)
	local requests = self._requests
    local request = requests[session]
	if not request then
		return
	end
	requests[session] = nil
	local loadings = self._loadings
	local ids = {}
    for id in pairs(request.waitings) do
		local map = loadings[id]
		if map then
			map[session] = nil
		end
		if not next(map) then
			loadings[id] = nil
		end
		ids[#ids + 1] = id
	end
	--print("UserInfoCache.CancelRequest", session, table.concat(ids))
end

function UserInfoCache.CheckTimeoutRequest()
	self._requestCheckTimer = World.Timer(self.REQUEST_CHECK_INTERVAL, UserInfoCache.CheckTimeoutRequest)
	local time = os.time() - self.REQUEST_TIMEOUT
	local list = {}
	for id, sessions in pairs(self._loadings) do
		for _, t in pairs(sessions) do
			if t <= time then	-- request is timeout
				list[#list + 1] = id
				break
			end
		end
	end
	--print("UserInfoCache.CheckTimeoutRequest", table.concat(list, ","))
    if #list > 0 then
        AsyncProcess.LoadUsersInfo(list)
	end
end

function UserInfoCache.GetCache(userId)
    return self._caches[tostring(userId)]
end

function UserInfoCache.SetCache(userId, info)
    local caches, key = self._caches, tostring(userId)
    local old = caches[key]
    caches[key] = info   -- userId, name, vip
    for k, v in pairs(old or DUMMY) do
        if not info[k] then
            info[k] = v
        end
    end

    local loadings = self._loadings
    local sessions = loadings[userId]
    if not sessions then
        return
    end
    loadings[userId] = nil

    local requests = self._requests
    for session in pairs(sessions) do
        local request = requests[session]
        local waitings = request.waitings
        waitings[userId] = nil
        if not next(waitings) then
            requests[session] = nil
            local ok, ret = xpcall(request.callback, traceback)
            if not ok then
                perror("UserInfoCache:SetCache reqeust callback error", userId, ret)
            end
        end
    end
end

function UserInfoCache.UpdateUserInfos(userInfos)
    Profiler:begin("UserInfoCache.UpdateUserInfos")
	local time = os.time()
    local ids = {}
   
    for _, info in pairs(userInfos) do
		info._time = time
        info.language = info.language or "en"
        if info.name then
            info.name = Lib.reconstructName(info.name, info.colorfulNickName)
            info.nickName = info.name
        end
        if info.nickName then
            info.nickName = Lib.reconstructName(info.nickName, info.colorfulNickName)
            info.name = info.nickName
        end
        local player = Game.GetPlayerByUserId(info.userId)
        local isDebug = Game.IsDebug()
        if not isDebug and player   then
            player.name = info.name or player.name
        end
        table.insert(ids, info.userId)
        self.SetCache(info.userId, info)
    end
	--print("UserInfoCache.UpdateUserInfos", table.concat(ids, ","))
    Profiler:finish("UserInfoCache.UpdateUserInfos")
end

function UserInfoCache.UpdateUserInfo(userId, userInfo)
    if userInfo.name then
        userInfo.name = Lib.reconstructName(userInfo.name, userInfo.colorfulNickName)
        userInfo.nickName = userInfo.name
    end
    if userInfo.nickName then
        userInfo.nickName = Lib.reconstructName(userInfo.nickName, userInfo.colorfulNickName)
        userInfo.name = userInfo.nickName
    end
	local info = self.GetCache(userId)
	if not info then
        self.SetCache(userId, userInfo)
		return
	end
	info.clanId = userInfo.clanId
	info.clanName = userInfo.clanName
	info.clanRole = userInfo.role
	info.propsId = userInfo.propsId
end

return UserInfoCache
