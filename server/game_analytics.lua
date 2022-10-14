-- Game Analytics 

local strfmt = string.format
local tconcat = table.concat
local tostring = tostring
local type = type
local traceback = traceback
local cjson = require("cjson")
local toJson = cjson.encode

local engineVersion = EngineVersionSetting.getEngineVersion()

local GameConfigs = {
    g2007 = { GameKey = "9eeb5392ef5ecf34cae3d3fb75f76485", SecretKey = "29dc627e3c441c06242a969e05752f71d8502890", Custom01 = "G2", Custom02 = "007" },
    g2020 = { GameKey = "9eeb5392ef5ecf34cae3d3fb75f76485", SecretKey = "29dc627e3c441c06242a969e05752f71d8502890", Custom01 = "G2", Custom02 = "020" }, --测试
    --g2020 = { GameKey = "4fffd8a37e9759b8c594245f5d228857", SecretKey = "09d350e3a01837fa44469593d532e668a11a29ea", Custom01 = "G2", Custom02 = "020" },--先锋
    --g2020 = { GameKey = "e2e52ee4f25a7419158001942d193631", SecretKey = "b205b40c80cacfa065be6246d5a1cfc0e7895b4b", Custom01 = "G2", Custom02 = "020" },--正式
    g2021 = { GameKey = "9eeb5392ef5ecf34cae3d3fb75f76485", SecretKey = "29dc627e3c441c06242a969e05752f71d8502890", Custom01 = "G2", Custom02 = "021" },
    g2030 = { GameKey = "91b17c35a5f14fff17a2203e7bc3f452", SecretKey = "28f5438c44797e8cfb15dca581f95cfa79185f4a", Custom01 = "G2", Custom02 = "030" },
    g2033 = { GameKey = "7b768a6b7da19d2d82dd5c3a363598c0", SecretKey = "ae4aafc48ecb3819972fccfae479e1aafe2b8432", Custom01 = "G2", Custom02 = "033" },
    g2034 = { GameKey = "eaa0f823240eca0974b9abd9cc0050a6", SecretKey = "334cfce694c8b438a374428f7014fa5d5025b104", Custom01 = "G2", Custom02 = "034" }, --测试
    --g2034 = { GameKey = "7c29002ec50504e65f0b9c06513abba7", SecretKey = "b6bca5a93ca050caa773067d232c7da5119bc8bd", Custom01 = "G2", Custom02 = "034" }, --先锋
    g2035 = { GameKey = "a70bd25943a79ca4bb04c01ca8749749", SecretKey = "8c1cf0ace9b0ae40ce8af8c0239766ec4f50d471", Custom01 = "G2", Custom02 = "035" }, --先锋
    g2036 = { GameKey = "ad0189bdd5c00d3ae0d9a604b415110d", SecretKey = "b0ad9fb48b1907c73d1d00e58ae1e7008e6f1024", Custom01 = "G2", Custom02 = "036" }, --测试
}
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
    print("GameAnalytics send init", World.GameName, url, body, retryTimes, os.time())
    AsyncProcess.GameAnalyticsRequest(url, function(response)
        print("GameAnalytics init response", toJson(response), os.time())
        if response.enabled then
            -- success
            self.inited = true
            self.timeDiff = response.server_ts - os.time()    -- TODO
            return
        end
        retryTimes = retryTimes or 0
        print("GameAnalytics init failed", retryTimes, toJson(response))
        assert(retryTimes < 3, "GameAnalytics init failed")
        World.Timer(1, sendInitRequest, url, body, retryTimes + 1)
    end, body, false)
end

function GameAnalytics.Init()
    self.playerDatas = {}
    self.inited = false
    self.timeDiff = 0
    self.ReportTimes = 0

    local path
    local fileName
    if PlatformUtil.isPlatformWindows() then
        path = "GameAnalytics"
        fileName = tostring(os.time()) .. ".log"
    else
        local serverConfig = Server.CurServer:getConfig()
        if serverConfig.gameEventLogDir and #serverConfig.gameEventLogDir > 0 then
            path = serverConfig.gameEventLogDir
        else
            path = "/home/app/bmg/log/game_event_log"
        end
        fileName = serverConfig.gameId .. ".log"
    end
    os.execute("mkdir " .. path)
    self.logFile = io.open(path .. "/" .. fileName, "a")

    local CurServer = Server.CurServer
    local gameType = World.GameName
    local config = World.cfg.analyticsData
    if not config then
        config = GameConfigs[gameType]
        if not config then
            self.enable = false
            print("GameAnalytics cannot find config, set disabled", gameType, os.time())
            return
        end
    end

    if config then
        self.enable = false
        return
    end

    self.enable = true

    local gameKey = config.GameKey
    self.initUrl = strfmt("http://api.gameanalytics.com/v2/%s/init", gameKey)
    self.eventsUrl = strfmt("http://api.gameanalytics.com/v2/%s/events", gameKey)
    self.custom01 = config.Custom01
    self.custom02 = config.Custom02
    CurServer:initGameAnalyticsSecretKey(config.SecretKey or "")
    self.enable = true
    local body = {
        platform = "server",
        os_version = EngineVersionSetting:getEngineVersion() or "unknow",
        sdk_version = "rest api v2",
    }
    World.Timer(1, sendInitRequest, self.initUrl, toJson(body))
end

local function getPlayerData(userId)
    return self.playerDatas[userId]
end

local function removePlayerData(userId)
    self.playerDatas[userId] = nil
    print("GameAnalytics remove user", userId)
end

function GameAnalytics.AppendPlayerEvent(userId, event)
    if not self.enable then
        return
    end
    local data = getPlayerData(userId)
    if not data or data.clientInfo.platform == "windows" then
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
        print(string.format("GameAnalytics AppendPlayerEvent, queue length = %s, userId = %s, category = %s, event_id = %s",
                #queue, userId, event.category, event.event_id))
    end
    if #queue >= 20 or os.time() - data.lastSendTime >= 20 then
        GameAnalytics.SendPlayerEvents(userId)
    elseif not data.sendTimer then
        data.sendTimer = World.Timer(20 * 20, GameAnalytics.SendPlayerEvents, userId)
    end
end

local function handleEventResponse(userId, sendCount, response)
    local data = assert(getPlayerData(userId), userId)
    assert(data.sending, userId)
    data.sending = false

    local logout = data.logout
    if response.status_code then
        -- failed
        local times = (data.failedTimes or 0) + 1
        data.failedTimes = times
        print("GameAnalytics SendPlayerEvents failed", userId, times, toJson(response))
        if logout then
            data.sendTimer = World.Timer(20 * 3, GameAnalytics.SendPlayerEvents, userId)
        elseif times <= 3 then
            data.sendTimer = World.Timer(20 * times * 2, GameAnalytics.SendPlayerEvents, userId)
        end
        return
    end
    data.failedTimes = 0
    local queue = data.eventQueue
    table.move(queue, sendCount + 1, #queue + sendCount, 1, queue)    -- remove sended events

    local remain = #queue
    if logout and remain == 0 then
        removePlayerData(userId)
        return
    end
    if logout or remain >= 20 or os.time() - data.lastSendTime >= 20 then
        GameAnalytics.SendPlayerEvents(userId)
    else
        data.sendTimer = World.Timer(20 * 20, GameAnalytics.SendPlayerEvents, userId)
    end
end

function GameAnalytics.SendPlayerEvents(userId)
    local data = getPlayerData(userId)
    if not data or data.sending then
        return
    end
    local sendTimer = data.sendTimer
    local queue = data.eventQueue
    local remain = #queue
    if remain == 0 then
        if data.logout then
            removePlayerData(userId)
        end
        return
    elseif not self.inited and not sendTimer then
        data.sendTimer = World.Timer(20 * 3, GameAnalytics.SendPlayerEvents, userId)
        return
    elseif sendTimer then
        sendTimer()
        data.sendTimer = nil
    end
    local count = math.min(remain, 20)
    local events = {}
    table.move(queue, 1, count, 1, events)
    local body = toJson(events)

    --print("GameAnalytics SendPlayerEvents", userId, count, remain, body:len())
    AsyncProcess.GameAnalyticsRequest(self.eventsUrl, function(response)
        --print("GameAnalytics SendPlayerEvents response", userId, toJson(response))
        handleEventResponse(userId, count, response)
    end, body, true, "67.220.91.30")
    data.sending = true
    data.lastSendTime = os.time()
end

function GameAnalytics.OnPlayerLogin(player, clientInfo)
    local playerDatas = self.playerDatas
    local userId = player.platformUserId
    assert(userId, tostring(userId))
    if not clientInfo then
        clientInfo = {
            device = "blockman", user_id = tostring(userId),
            os_version = "android 4.4.4",
            manufacturer = "sandbox", platform = "android",
            android_id = tostring(os.time()) .. tostring(userId),
            session_num = 1,
            version_code = "1",
            package_name = "com.sandboxol.blockymods",
        }
    end
    clientInfo.session_id = UUID.randomUUID():toString()

    local data = playerDatas[userId]
    if not data then
        data = {
            userId = userId,
            eventQueue = {},
            sending = false,
            failedTimes = 0,
            lastSendTime = 0,
            logout = nil,
        }
        playerDatas[userId] = data
    end
    data.loginTime = os.time()
    data.clientInfo = clientInfo
    print("GameAnalytics OnPlayerLogin", userId, toJson(clientInfo))
    GameAnalytics.AppendPlayerEvent(userId, { category = "user" })
    GameReport:reportByUserId("Login", clientInfo, userId)
end

function GameAnalytics.PlayerPerformanceReport(player)
    local data = getPlayerData(player.platformUserId)
    if not data or data.logout then
        return
    end

    if not player.performance or not player.performance.fps or
            not player.performance.netPing or not player.performance.logicPing then
        return
    end

    GameAnalytics.NewDesign(player.platformUserId, "battle_fps", player.performance.fps)
    GameAnalytics.NewDesign(player.platformUserId, "battle_net_ping", player.performance.netPing)
    GameAnalytics.NewDesign(player.platformUserId, "battle_logic_ping", player.performance.logicPing)
end

function GameAnalytics.OnPlayerLogout(userId)
    local data = getPlayerData(userId)
    if not data then
        return
    end

    if data.clientInfo.platform == "windows" then
        removePlayerData(userId)
        return
    end

    print("GameAnalytics OnPlayerLogout", userId, data.logout)
    if data.logout then
        return
    end
    local event = {
        category = "session_end",
        length = os.time() - data.loginTime,
    }
    GameAnalytics.AppendPlayerEvent(userId, event)

    data.logout = true
    GameReport:reportByUserId("Logout", { online_time = event.length }, userId)
    GameAnalytics.SendPlayerEvents(userId)
end

function GameAnalytics.OnPlayerRechargeBuy(userId, itemType, itemId, amount, currency, cartType, receiptInfo)
    GameReport:reportByUserId("recharge_buy", {
        item_type = itemType,
        item_id = itemId,
        amount = amount,
        currency = currency,
        cart_type = cartType,
        receipt_info = receiptInfo,
    }, userId)
    if not self.enable then
        return
    end
    local data = assert(getPlayerData(userId), userId)
    local transactions = (data.transactions or 0) + 1
    data.transactions = transactions
    print("GameAnalytics OnPlayerRechargeBuy", userId, transactions, itemType, itemId, amount, currency, cartType, receiptInfo)

    local event = {
        category = "business",
        event_id = strfmt("%s:%s", itemType, itemId),
        amount = assert(amount, "amount"),
        currency = assert(currency, "currency"),
        transaction_num = transactions,
        cart_type = cartType,
        receipt_info = receiptInfo,
    }
    GameAnalytics.AppendPlayerEvent(userId, event)
end

function GameAnalytics.OnPlayerCostMoney(userId, currency, amount, itemType, itemId)
    GameReport:reportByUserId("cost_money", {
        currency = currency,
        amount = amount,
        item_type = itemType,
        item_id = itemId,
    }, userId)
    if not self.enable then
        return
    end
    print("GameAnalytics OnPlayerCostMoney", userId, itemType, itemId, currency, amount)
    local event = {
        category = "resource",
        event_id = strfmt("Sink:%s:%s:%s", currency, itemType, itemId),
        amount = assert(amount, "amount"),
    }
    GameAnalytics.AppendPlayerEvent(userId, event)
end

function GameAnalytics.OnPlayerGainMoney(userId, currency, amount, itemType, itemId)
    GameReport:reportByUserId("gain_money", {
        currency = currency,
        amount = amount,
        item_type = itemType,
        item_id = itemId,
    }, userId)
    if not self.enable then
        return
    end
    print("GameAnalytics OnPlayerGainMoney", userId, itemType, itemId, currency, amount)
    local event = {
        category = "resource",
        event_id = strfmt("Source:%s:%s:%s", currency, itemType, itemId),
        amount = assert(amount, "amount"),
    }
    GameAnalytics.AppendPlayerEvent(userId, event)
end

function GameAnalytics.UpdatePlayerProgression(userId, status, progressions, attemptNum, score)
    GameReport:reportByUserId("update_progression", {
        status = status,
        progressions = progressions,
        attempt_num = attemptNum,
        score = score,
    }, userId)
    if not self.enable then
        return
    end
    print("GameAnalytics UpdatePlayerProgression", userId, status, toJson(progressions), attemptNum, score)
    assert(status == "Start" or status == "Fail" or status == "Complete", status)
    assert(0 < #progressions and #progressions <= 3, toJson(progressions))
    local eventId = status
    for _, p in ipairs(progressions) do
        eventId = strfmt("%s:%s", eventId, p)
    end
    local event = {
        category = "progression",
        event_id = eventId,
        amount = assert(amount, "amount"),
    }
    GameAnalytics.AppendPlayerEvent(userId, event)
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

local function NewReportByMap(userId, event, eventMap, parentId)
    if not checkEvent(event) then
        Lib.logError("event is illegal , event = ", event)
        return
    end
    eventMap.sdk = eventMap.sdk or "mods"
    eventMap.event = event
    eventMap.event_type = "game"
    eventMap.id = tostring(userId) .. tostring(os.time()) .. tostring(self.ReportTimes)
    eventMap.game_type = eventMap.game_type or World.GameName
    eventMap.engine_version = engineVersion
    eventMap.region_id = tostring(Server.CurServer:getConfig().regionId)
    eventMap.event_time = os.time()
    local data = getPlayerData(userId)
    if data and data.clientInfo then
        for key, value in pairs(data.clientInfo) do
            eventMap[key] = value
        end
    end
    if userId then
        eventMap.user_id = tostring(userId)
    end
    if parentId then
        eventMap.parent_id = tostring(parentId)
    end
    if self.logFile then
        Lib.logDebug("server report", self.ReportTimes, event)
        self.logFile:write(cjson.encode(eventMap) .. "\n")
        self.logFile:flush()
    else
        Lib.logError("new report file create fail")
    end

    self.ReportTimes = self.ReportTimes + 1
    return eventMap.id
end

local function NewReportByList(userId, value, list)
    local eventMap = { sdk = "ga", _value = value } --game_analytics
    local event = table.remove(list, 1)
    for keyIndex, key in pairs(list) do
        eventMap[tostring(keyIndex)] = key
    end
    return NewReportByMap(userId, event, eventMap)
end

---Every game is unique! Therefore it varies what information is needed to track
---for each game. Some needed events might not be covered by our other event types
---and the design event is available for creating a custom metric using an event id hierarchy.
---@param userId number userId [player userId]
---@param value number value [Optional value. float]
---@param parts table parts [eg {"BreakBlock", BlockId, ...}]
---eventId structure
---A 1-5 part event id.
---[part1]:[part2]:[part3]:[part4]:[part5]
---pattern:^[A-Za-z0-9\\s\\-_\\.\\(\\)\\!\\?]{1,64}(:[A-Za-z0-9\\s\\-_\\.\\(\\)\\!\\?]{1,64}){0,4}$
function GameAnalytics.Design(userId, value, parts)
    return
    --[[
    parts = parts or {}
    if #parts == 0 then
        return
    end
    value = value or 0
    local eventId = table.concat(parts, ":")
    GameReport:reportByUserId(eventId, {value = value}, userId)

    if not self.enable then
        return
    end

    local array = Lib.splitIncludeEmptyString(eventId, ":")
    for i, v in pairs(array) do
        if #v == 0 or #v > 64 or i > 5 or v ~= string.match(v, "^([%w%_%!%?%.]+)") then
            print(" assert ! v = ", v, ", #v = ", #v, ", i = ", i)
            assert(false, string.format("GameAnalytics Design event_id error: event_id=%s", eventId))
            return
        end
    end

    GameAnalytics.AppendPlayerEvent(userId, {
        category = "design",
        event_id = eventId,
        value = value
    })
    --return NewReportByList(userId, value, parts)
    ]]
end

---@param userId number userId [player userId]
---@param event number event [event name]
---@param event_map table event_map [eg {key1 = value1,key2 = value2, ...}]
function GameAnalytics.NewDesign(userId, event, event_map, parentId)
    if not event or type(event_map) ~= "table" then
        Lib.logError("client report params error", debug.traceback())
        return
    end
    return NewReportByMap(userId, event, event_map, parentId)
end

local sequence = 0
function GameAnalytics.NewSequence()
    sequence = sequence + 1
    return sequence
end

---@param player EntityServerPlayer
---@param uniqueId string|number 商品唯一ID
---@param coinId number 货币Id（0：金魔方 1：蓝魔方 2：金币 3~n:自定义coin.json）
---@param price number|BigInteger 价格
---@param goodsNum number|string 购买商品数量 没有默认1
---@param reason number 货币变化的原因，枚举，游戏定义 默认 Define.ExchangeItemsReason.BuyShop
function GameAnalytics.OnPlayerCostMoneyExchangeItems(player, uniqueId, coinId, price, goodsNum, reason)
    if not uniqueId then
        return
    end
    local userId = player.platformUserId
    local currency_balance_num = player:getCurrency(Coin:coinNameByCoinId(coinId)) and player:getCurrency(Coin:coinNameByCoinId(coinId)).count or 0
    if type(currency_balance_num) ~= "number" or type(price) ~= "number" then
        return
    end
    local event_map = {
        currency_balance_type = coinId,
        currency_balance_num = currency_balance_num,
        currency_change_type = coinId,
        currency_change_num = price,
        currency_is_add = false,
        item_change_item_id2 = tostring(uniqueId),
        item_change_item_num = goodsNum or 1,
        reason = reason or Define.ExchangeItemsReason.BuyShop,
    }
    GameAnalytics.NewDesign(userId, "ExchangeItems", event_map)

    local sequence = GameAnalytics.NewSequence()
    if price > 0 then
        GameAnalytics.MoneyFlow(player, coinId, price, false, reason, "", sequence)
    end
    if (goodsNum or 0) > 0 then
        GameAnalytics.ItemFlow(player, "", uniqueId, goodsNum or 1, true, reason, "", sequence)
    end
end

-- 货币流水
-- coinId: number 货币Id（0：金魔方 1：蓝魔方 2：金币 3~n:自定义coin.json）
-- count: number 变动的数量
-- isAdd: bool 是否是增加
-- reason: 主变化原因
-- subReason: 变化详细信息，用于区分同一主变化原因中的特定事件
-- sequence: 关联序号，用于关联多笔流水
function GameAnalytics.MoneyFlow(player, coinId, count, isAdd, reason, subReason, sequence)
    local after = (player:getCurrency(Coin:coinNameByCoinId(coinId)) or {}).count or 0
    local data = {
        currency_balance_type = coinId,
        currency_balance_num = after,
        currency_change_type = coinId,
        currency_change_num = count,
        currency_is_add = isAdd,
        reason = reason,
        subReason = subReason,
        sequence = sequence,
    }
    GameAnalytics.NewDesign(player.platformUserId, "ExchangeItems", data)
end

-- 道具流水
-- typeId: 道具类型
-- id: number 道具id
-- count: number 变动的数量
-- isAdd: bool 是否是增加
-- reason: 主变化原因
-- subReason: 变化详细信息，用于区分同一主变化原因中的特定事件
-- sequence: 关联序号，用于关联多笔流水
function GameAnalytics.ItemFlow(player, typeId, id, count, isAdd, reason, subReason, sequence)
    local data = {
        item_is_add = isAdd,
        item_change_item_type = typeId,
        item_change_item_id2 = id,
        item_change_item_num = count,
        reason = reason,
        subReason = subReason,
        sequence = sequence,
    }
    GameAnalytics.NewDesign(player.platformUserId, "ExchangeItems", data)
end
