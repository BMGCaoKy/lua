---
--- 游戏数据上报服务
--- 提供给外部开发者使用的数据上报的相关接口
--- DateTime: 2022/1/6 18:18
---

local GameReport = {}
local ReportAgent = require "report.agent"

local EVENT_NAME = "ugc_user_custom_event"

local tostring = tostring
local function checkReportData(value)
    local typ = type(value)
    if typ == "nil" or typ == "table" or typ == "userdata" or typ == "function" or typ == "thread" then
        return false
    end
    return true
end

function GameReport:reportGameData(event, data, player)
    if not checkReportData(event) or not checkReportData(data) then
        Lib.log("The type of reported event/data cannot be these types : nil, table, userdata, function, thread", 3)
        return
    end
    ReportAgent:reportData(EVENT_NAME, { event_name = tostring(event), ugc_user_custom_event_params = tostring(data) }, player)
end
GameReport.ReportData = GameReport.reportGameData

local engine_module = require "common.engine_module"
engine_module.insertModule("GameAnalytics", GameReport)

RETURN(GameReport)