---@class GameReport
local GameReport = T(Game, "Report")
local ReportAttr = T(GameReport, "ReportAttr")
local ReportAttrCsv = T(Config, "ReportAttr")

local EventsConfig = L("EventsConfig", {
    -- event = keys
    Login = { "device", "os_version", "manufacturer", "platform", "android_id", "version_code", "package_name" },
    Logout = { "online_time" },
    recharge_buy = { "item_type", "item_id", "amount", "currency", "cart_type", "receipt_info" },
    cost_money = { "currency", "amount", "item_type", "item_id" },
    gain_money = { "currency", "amount", "item_type", "item_id" },
    update_progression = { "status", "progressions", "attempt_num", "score" },
    follow_game_enter_suc = {},
    follow_watch = {},
    follow_game = {},
})
GameReport.EventsConfig = EventsConfig
local KeysType = L("KeysType", {
    device = "string",
    os_version = "string",
    manufacturer = "string",
    platform = "string",
    android_id = "string",
    version_code = "string",
    package_name = "string",
    online_time = "int",
    item_type = "string",
    item_id = "string",
    amount = "int",
    currency = "string",
    cart_type = "string",
    receipt_info = "string",
    status = "string",
    progressions = "int",
    attempt_num = "int",
    score = "int",
})

function GameReport:loadConfig(eventsConfig, keysType, clear)
    if clear then
        EventsConfig = {}
        GameReport.EventsConfig = EventsConfig
        KeysType = {}
        GameReport.KeysType = KeysType
    end

    for _, config in pairs(eventsConfig) do
        local event = config.event
        local keys = {}
        for i = 1, 100 do
            local key = config["key"..i]
            if key and key ~= "" then
                keys[#keys + 1] = key
            end
        end
        EventsConfig[event] = keys
    end

    for _, config in pairs(keysType) do
        assert(config.key and config.type and config.type ~= "", "must have return type")
        KeysType[config.key] = config.type
    end
end

function GameReport:getEventKeys(event)
    return EventsConfig[event]
end

local function correctValue(key, val)
    local keyType = KeysType[key]
    if keyType == "int" then
        val = math.tointeger(val) or 0
    elseif keyType == "string" then
        val = tostring(val)
    elseif keyType == "bool" then
        if type(val) == "number" then
            val = val ~= 0
        elseif type(val) == "string" then
            val = string.lower(val) == "true"
        end
    else
        return
    end
    local checkType = "string"
    if keyType == "int" or keyType == "float" then
        checkType = "number"
    elseif keyType == "bool" then
        checkType = "boolean"
    end
    if type(val) ~= checkType then
        Lib.logError("key:", key, ", val:", val, "can't convert to", keyType, checkType)
    end
    return val
end

local function correctReportData(data)
    if not data then
        return data
    end
    local t = {}
    for k, v in pairs(data) do
        t[k] = correctValue(k, v)
    end
    return t
end

local function reportData(event, data, userId)
    local reportSetting = World.cfg.reportSetting
    if reportSetting and reportSetting.debug then
        Lib.logInfo("game report data", event, Lib.v2s(data), userId)
    end

    if World.isClient then
        GameAnalytics.NewDesign(event, correctReportData(data))
    else
        GameAnalytics.NewDesign(userId, event, correctReportData(data))
    end
end

local function checkReportArgs(event, data, userId)
    if not event or not data then
        Lib.logError("game report event or data ", event, data, userId)
        return false
    end
    if World.isGameServer and not userId then
        Lib.logError("game report userId is nil", event, data, userId)
        return false
    end

    local keys = GameReport:getEventKeys(event)
    if not keys then
        local reportSetting = World.cfg.reportSetting or {}
        local ignoreEvent = reportSetting.ignoreEvent
        if not ignoreEvent or not ignoreEvent[event] then
            Lib.logError("game report event cfg not find", event, debug.traceback("", 2))
        end
        return false
    end

    return true
end

function GameReport:reportByUserId(event, data, userId)
    if checkReportArgs(event, data, userId) then
        reportData(event, data, userId)
    end
end

--reportByUserId缺少自定义attr，report又不能报离线数据
--所以改造一下，report的第三个参数既可以是userId又可以是entity
--甚至要上报跟玩家不相关的数据，字符串也有可能，如某类物品在服务器的聚合统计上报
--但是业务的attr要保证传参可用
--实际上第三个参数是个任意table，只要包含platformUserId即可
function GameReport:report(event, data, params)
    if not params then
        if World.isClient then
            params = Me
        else
            Lib.logDebug("game report params not find", event)
            return
        end
    end
    if not data then
        data = {}
    end

    local userId = params.platformUserId or params.userId
    if not checkReportArgs(event, data, userId) then
        return
    end

    for i, key in ipairs(GameReport:getEventKeys(event)) do
        local func = ReportAttrCsv[key] or ReportAttr[key]
        if func then
            data[key] = func(params)
        elseif not data[key] then
            Lib.logDebug("game report no attr function", key, event, userId)
        end
    end
    reportData(event, data, userId)
end

--------------------------------------------------------------------------------
-- Report attribute
-------------------工具函数start-----------------------
local function getCurrency(player, coinName)
    return player:getCurrency(coinName, true) or {}
end
-----------------工具函数end------------------------------

function ReportAttr.coins_num(player)
    return getCurrency(player, "gold").count or 0
end

function ReportAttr.gcube_num(player)
    return getCurrency(player, "gDiamonds").count or 0
end

--function ReportAttr.online_time(player)
--    local loginTs = player:getLoginTs()
--    return os.time() - loginTs
--end

--------------------------------------------------------------------------------
return GameReport