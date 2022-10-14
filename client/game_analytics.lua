--- Client Game Analytics

local strfmt = string.format
local tostring = tostring
local cjson = require("cjson")
local toJson = cjson.encode

local DefaultAnnotations = {
    "device", "user_id", "os_version", "manufacturer", "platform",
    "session_id", "session_num", "limit_ad_tracking", "logon_gamecenter",
    "logon_gameplay", "jailbroken", "android_id", "googleplus_id",
    "facebook_id", "gender", "facebook_id", "birth_year", "custom_01",
    "custom_02", "custom_03", "build", "engine_version", "ios_idfv",
    "connection_type", "ios_idfa", "google_aid",
}
local EventSharedFields = {}
for _, field in pairs(DefaultAnnotations) do
    EventSharedFields[field] = true
end

local self = GameAnalytics

local function sendInitRequest(url, body, retryTimes)
    print("GameAnalytics（client） send init", World.GameName, url, body, retryTimes, os.time())
    AsyncProcess.GameAnalyticsRequest(url, function(response)
        print("GameAnalytics(client) init response", toJson(response), os.time())
        if response.enabled then
            -- success
            self.inited = true
            self.timeDiff = response.server_ts - os.time()    -- TODO
            --GameAnalytics.Design(0,{"ClickUI",'activityWin'}) --for test
            return
        end
        retryTimes = retryTimes or 0
        print("GameAnalytics(client) init failed", retryTimes, toJson(response))
        if retryTimes >= 3 then
            ---不用重新尝试了，玩家本地环境网络可能连接不上GameAnalytics的服务器
            return
        end
        World.Timer(1, sendInitRequest, url, body, retryTimes + 1)
    end, body, false)
end

function GameAnalytics.Init()
    self.playerDatas = {}
    self.inited = false
    self.timeDiff = 0
    self.ReportTimes = 0

    local gameType = World.GameName
    local config = World.cfg.analyticsData
    if not config then
        print("GameAnalytics（client） cannot find config, set disabled", gameType, os.time())
        return
    end

    if config then
        return
    end

    local gameKey = config.GameKey
    self.initUrl = strfmt("http://api.gameanalytics.com/v2/%s/init", gameKey)
    self.eventsUrl = strfmt("http://api.gameanalytics.com/v2/%s/events", gameKey)
    self.custom01 = config.Custom01
    self.custom02 = config.Custom02
    Blockman.Instance():initGameAnalyticsSecretKey(config.SecretKey or "")
    self.enable = true
    local body = {
        platform = "client",
        os_version = EngineVersionSetting:getEngineVersion() or "unknow",
        sdk_version = "rest api v2",
    }
    World.Timer(1, sendInitRequest, self.initUrl, toJson(body))
end

local function createPlayerData(userId)
    local data = Game.GetPlayerByUserId(userId)
    if not data then
        data = { userId = userId }
    end
    data.eventQueue = {}
    data.sending = false
    data.failedTimes = 0
    data.lastSendTime = 0
    data.logout = nil
    data.loginTime = os.time()

    local client_info = cjson.decode(CGame.instance:getShellInterface():getClientInfo())
    client_info.user_id = tostring(userId) -- key userId format must be string(Game Analytics require)
    client_info.session_id = UUID.randomUUID():toString() -- key session_id must be exist
    data.clientInfo = client_info
    self.playerDatas[userId] = data
    return data
end

local function getPlayerData()
    local userId = CGame.instance:getPlatformUserId()
    return self.playerDatas[userId] or createPlayerData(userId)
end

local function handleEventResponse(sendCount, response)
    local data = getPlayerData()
    assert(data.sending, 'should be sending')
    data.sending = false

    if response.status_code then
        -- failed
        local times = (data.failedTimes or 0) + 1
        data.failedTimes = times
        print("GameAnalytics SendPlayerEvents failed", times, toJson(response))
        if times <= 3 then
            data.sendTimer = World.Timer(20 * times * 2, GameAnalytics.SendPlayerEvents)
        end
        return
    end
    data.failedTimes = 0
    local queue = data.eventQueue
    table.move(queue, sendCount + 1, #queue + sendCount, 1, queue)    -- remove sended events

    local remain = #queue
    if remain == 0 then
        return
    end
    if remain >= 20 or os.time() - data.lastSendTime >= 20 then
        GameAnalytics.SendPlayerEvents()
    else
        data.sendTimer = World.Timer(20 * 20, GameAnalytics.SendPlayerEvents)
    end
end

function GameAnalytics.AppendPlayerEvent(event)
    if not self.enable then
        return
    end
    local data = getPlayerData()
    if not data then
        return
    end

    for k, v in pairs(data.clientInfo) do
        if EventSharedFields[k] then
            event[k] = v
        end
    end
    event.v = 2
    event.client_ts = os.time() + self.timeDiff
    event.sdk_version = "rest api v2"
    event.custom_01 = self.custom01
    event.custom_02 = self.custom02

    local queue = data.eventQueue
    queue[#queue + 1] = event
    if #queue >= 10000 then
        print(string.format("GameAnalytics AppendPlayerEvent, queue length = %s, category = %s, event_id = %s",
                #queue, event.category, event.event_id))
    end
    if #queue >= 20 or os.time() - data.lastSendTime >= 20 then
        GameAnalytics.SendPlayerEvents()
    elseif not data.sendTimer then
        data.sendTimer = World.Timer(20 * 20, GameAnalytics.SendPlayerEvents)
    end
end

function GameAnalytics.SendPlayerEvents()
    local data = getPlayerData()
    if not data or data.sending then
        return
    end
    local sendTimer = data.sendTimer
    local queue = data.eventQueue
    local remain = #queue
    if remain == 0 then
        return
    end
    if not self.inited and not sendTimer then
        data.sendTimer = World.Timer(20 * 3, GameAnalytics.SendPlayerEvents)
        return
    elseif sendTimer then
        sendTimer()
        data.sendTimer = nil
    end
    local count = math.min(remain, 20)
    local events = {}
    table.move(queue, 1, count, 1, events)
    local body = toJson(events)
    AsyncProcess.GameAnalyticsRequest(self.eventsUrl, function(response)
        --print("GameAnalytics SendPlayerEvents response", userId, toJson(response))
        handleEventResponse(count, response)
    end, body, true, "67.220.91.30")
    data.sending = true
    data.lastSendTime = os.time()
end

local function checkEvent(event)
    if type(event) ~= "string" then
        return false
    end
    if tonumber(event) ~= nil then
        return false
    end

    return true
end

local function NewReportByMap(event, eventMap, parentId)
    if not checkEvent(event) then
        Lib.logError("event is illegal , event = ", event)
        return
    end
    local userId = CGame.instance:getPlatformUserId()
    eventMap.sdk = eventMap.sdk or "mods"
    eventMap.event = event
    eventMap.id = tostring(userId) .. tostring(os.time()) .. tostring(self.ReportTimes)
    eventMap.game_type = eventMap.game_type or World.GameName
    eventMap.user_id = tostring(userId)
    eventMap.event_time = os.time()
    local info = getPlayerData(userId)
    if info then
        --eventMap.os_version = info.os_version or ""
        --eventMap.app_version = info.app_version or ""
        --eventMap.ram_memory = info.ram_memory or ""
        --eventMap.version_code = info.version_code or ""
        --eventMap.package_name = info.package_name or ""
        --eventMap.manufacturer = info.manufacturer or ""
    end
    if parentId then
        eventMap.parent_id = tostring(parentId)
    end
    if CGame.dataReportNotType then
        Lib.logDebug("client report", self.ReportTimes, event)
        CGame.instance:dataReportNotType(event, cjson.encode(eventMap), true)
    else
        Lib.logError("CGame.instance.dataReportNotType not REGISTER")
    end

    self.ReportTimes = self.ReportTimes + 1
    return eventMap.id
end

---Every game is unique! Therefore it varies what information is needed to track
---for each game. Some needed events might not be covered by our other event types
---and the design event is available for creating a custom metric using an event id hierarchy.
---@param value number value [Optional value. float]
---@param parts table parts [eg {"BreakBlock", BlockId, ...}]
---eventId structure
---A 1-5 part event id.
---[part1]:[part2]:[part3]:[part4]:[part5]
---pattern:^[A-Za-z0-9\\s\\-_\\.\\(\\)\\!\\?]{1,64}(:[A-Za-z0-9\\s\\-_\\.\\(\\)\\!\\?]{1,64}){0,4}$
function GameAnalytics.Design(value, parts)
    return
    --[[
    parts = parts or {}
    if #parts == 0 then
        return
    end
    value = value or 0
    local eventId = table.concat(parts, ":")
    GameReport:report(eventId, {value = value})

    if not self.enable or not self.inited then
        return
    end

    local array = Lib.splitIncludeEmptyString(eventId, ":")
    for i, v in pairs(array) do
        if #v == 0 or #v > 64 or i > 5 or v ~= string.match(v, "^([%w%_%!%?%.]+)") then
            assert(false, string.format("GameAnalytics Design event_id error: event_id=%s", eventId))
            return
        end
    end

    GameAnalytics.AppendPlayerEvent({
        category = "design",
        event_id = eventId,
        value = value
    })
    ]]
end

---@param event number event [event name]
---@param event_map table event_map [eg {key1 = value1,key2 = value2, ...}]
function GameAnalytics.NewDesign(event, event_map, parentId)
    if not event or type(event_map) ~= "table" then
        Lib.logError("client report params error", debug.traceback())
        return
    end
    return NewReportByMap(event, event_map, parentId)
end