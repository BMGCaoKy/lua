local base = require "editor.edit_record.base"
local eventTrackingMgr = L("eventTrackingMgr", {})

local recordInterval = 1200
local getFileContent = base.getFileContent
local saveFile = base.saveFile
local getEditRecordPath = base.getEditRecordPath

local function timeSendEventTracking(eventName, reportType)
    World.Timer(recordInterval, function()
        CGame.instance:onEditorDataReport(eventName, "60", reportType)
        return true
    end)
end

local function addEditDuration(time)
    local path = string.format("%seditInfo.json", getEditRecordPath())
    local record = getFileContent(path)
    record.editDuration = (record.editDuration or 0) + time * 0.05
    saveFile(path, record)
end

function eventTrackingMgr:clickTestWriteFile()
    if not base.enable then
        return
    end

    local path = string.format("%seditInfo.json", getEditRecordPath())
    local record = getFileContent(path)
    record.testTimes = (record.testTimes or 0) + 1
    saveFile(path, record)
end

function eventTrackingMgr:addStarGameDataReport(starGameId)
    -- 上报游戏游戏的进入次数和游戏时长
    print("addOnlineGameOrStartGame: " .. starGameId .. "=============================")
    -- reportType: 1:上报talkingData(默认) 2:上报广州后台这边 3:两边都上报
    CGame.instance:onEditorDataReport("gameEnterCount#" .. starGameId, "", 2)
    timeSendEventTracking("gameEnterTimes#" .. starGameId, 2)
end

function eventTrackingMgr:addOnlineGameDataReport()
    -- 上报联机游戏的进入次数和游戏时长
    CGame.instance:onEditorDataReport("count_all_multiplayer", "", 2)
    timeSendEventTracking("time_all_multiplayer", 2)
end

function eventTrackingMgr:addTestTimes()
    timeSendEventTracking("time_all_test", 3)
end

function eventTrackingMgr:addEditTimes()
    timeSendEventTracking("time_all_edit", 3)
end

function eventTrackingMgr:init()
    if base.enable then
        World.Timer(recordInterval, function()
            addEditDuration(recordInterval)
            return true
        end)
    end

    if base.localEditroEnvironment then
        -- 编辑场景统计时长
        print("is localEditroEnvironment===========================")
        self:addEditTimes()
    end

    if base.localTestEnvironment then
        -- 本地测试场景统计时长
        print("is localTestEnvironment===========================")
        self:addTestTimes()
    end
end

return eventTrackingMgr