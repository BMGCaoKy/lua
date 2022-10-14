---
--- Generated by Luanalysis
--- Created by Administrator.
--- DateTime: 2020/12/22 17:27
---
local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer
local BlindBoxActivity = T(Lib, "BlindBoxActivity") ---@type BlindBoxActivity
local BlindBoxConfig = T(Config, "BlindBoxConfig") ---@type BlindBoxConfig
local BlindBoxRewardConfig = T(Config, "BlindBoxRewardConfig") ---@type BlindBoxRewardConfig
local ActivityLib = T(Lib, "ActivityLib") ---@type ActivityLib

---BlindBox
local BlindBoxInfo = {
    enable = false,
    startTime = 0,
    endTime = -1,
    blindBoxIds = {}
}

local function initDBData(data)
    if not data.blindBoxData then
        data.blindBoxData = {}
    end
    if not data.receiveRecord then
        data.receiveRecord = {}
    end
end

local function checkAllPlayerDBData()
    local players = Game.GetAllPlayers()
    for _, player in pairs(players) do
        initDBData(player:data("common_activity"))
    end
end

function BlindBoxActivity:onPlayerReady(player)
    if not BlindBoxInfo.enable then
        return
    end
    BlindBoxActivity:initPlayerData(player)
end

function BlindBoxActivity:initPlayerData(player)
    local data = player:data("common_activity")
    initDBData(data)
    if BlindBoxInfo.enable then
        local result = { enable = BlindBoxInfo.enable }
        if BlindBoxInfo.endTime == -1 then
            result.lastTime = -1
        else
            result.lastTime = BlindBoxInfo.endTime - os.time()
        end
        local dayEndTime = ActivityLib.getCycleEndTime(BlindBoxInfo.startTime, Lib.getDaySeconds())
        result.blindBoxIds = BlindBoxInfo.blindBoxIds
        result.dayLastTime = dayEndTime - os.time()
        if dayEndTime ~= data.blindBoxData.dayEndTime then
            data.blindBoxData.dayEndTime = dayEndTime
            data.blindBoxData.blindBoxList = {}
            for _, boxId in pairs(BlindBoxInfo.blindBoxIds) do
                table.insert(data.blindBoxData.blindBoxList, { boxId = boxId, openTimes = 0, dayOpenTimes = 0 })
            end
        end
        result.blindBoxList = data.blindBoxData.blindBoxList
        player:sendPacket({ pid = "BlindBoxInit", data = result })
    end
end

function BlindBoxActivity:init(setting)
    BlindBoxInfo.enable = false
    BlindBoxInfo.startTime = 0
    BlindBoxInfo.endTime = -1
    BlindBoxInfo.blindBoxIds = Lib.splitString(setting.blindBoxIds, ",", true)
    if setting.startDate and setting.startDate ~= "#" then
        local _, _, year, month, day, hour, min, sec = string.find(setting.startDate, "(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)")
        BlindBoxInfo.startTime = Lib.date2BeiJingTime({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
    end
    if setting.endDate and setting.endDate ~= "#" then
        local _, _, year, month, day, hour, min, sec = string.find(setting.endDate, "(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)")
        BlindBoxInfo.endTime = Lib.date2BeiJingTime({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
    end
    local function syncBlindBoxInit()
        local data = { enable = BlindBoxInfo.enable }
        if BlindBoxInfo.enable then
            checkAllPlayerDBData()
        end
        if BlindBoxInfo.endTime == -1 then
            data.lastTime = -1
        else
            data.lastTime = BlindBoxInfo.endTime - os.time()
        end
        data.blindBoxList = {}
        for _, boxId in pairs(BlindBoxInfo.blindBoxIds) do
            table.insert(data.blindBoxList, { boxId = boxId, openTimes = 0, dayOpenTimes = 0 })
        end
        local dayEndTime = ActivityLib.getCycleEndTime(BlindBoxInfo.startTime, Lib.getDaySeconds())
        local players = Game.GetAllPlayers()
        for _, player in pairs(players) do
            player:data("common_activity").blindBoxData.dayEndTime = dayEndTime
            player:data("common_activity").blindBoxData.blindBoxList = data.blindBoxList
        end
        data.dayLastTime = dayEndTime - os.time()
        WorldServer.BroadcastPacket({ pid = "BlindBoxInit", data = data })
    end
    if ActivityLib.isInTimeRange(BlindBoxInfo.startTime, BlindBoxInfo.endTime) then
        BlindBoxInfo.enable = true
        syncBlindBoxInit()
    else
        syncBlindBoxInit()
    end
    if BlindBoxInfo.startTime > os.time() then
        LuaTimer:schedule(function()
            BlindBoxInfo.enable = true
            syncBlindBoxInit()
        end, (BlindBoxInfo.startTime - os.time()) * 1000)
    end
    if BlindBoxInfo.enable and BlindBoxInfo.endTime ~= -1 then
        LuaTimer:schedule(function()
            if setting.nextStartDate and setting.nextEndDate and setting.nextBlindBoxIds then
                setting.startDate = setting.nextStartDate
                setting.endDate = setting.nextEndDate
                setting.blindBoxIds = setting.nextBlindBoxIds
                setting.nextStartDate = nil
                setting.nextEndDate = nil
                setting.nextBlindBoxIds = nil
            end
            CommonActivity:initBlindBox(setting)
        end, (BlindBoxInfo.endTime - os.time() + 1) * 1000)
    end
    LuaTimer:cancel(BlindBoxInfo.dayTimer)
    local dayEndTime = ActivityLib.getCycleEndTime(BlindBoxInfo.startTime, Lib.getDaySeconds())
    BlindBoxInfo.dayTimer = LuaTimer:schedule(function()
        local players = Game.GetAllPlayers()
        for _, player in pairs(players) do
            player:data("common_activity").blindBoxData.dayEndTime = ActivityLib.getCycleEndTime(BlindBoxInfo.startTime, Lib.getDaySeconds())
            for _, blindBox in pairs(player:data("common_activity").blindBoxData.blindBoxList) do
                blindBox.dayOpenTimes = 0
            end
        end
    end, (dayEndTime - os.time()) * 1000, Lib.getDaySeconds() * 1000)
end

function BlindBoxActivity:onBlindBoxOpen(player, openData)
    if not BlindBoxInfo.enable then
        return
    end
    local blindBox = BlindBoxConfig:getBlindBoxById(openData.boxId)
    if not blindBox then
        return
    end

    local cache = player:data("common_activity")
    if not cache or not next(cache.blindBoxData) then
        return
    end

    local boxTag
    for _, box in pairs(cache.blindBoxData.blindBoxList) do
        if box.boxId == openData.boxId then
            boxTag = box
            break
        end
    end
    if not boxTag then
        return
    end
    if boxTag.openTimes >= blindBox.totalTimes or boxTag.dayOpenTimes >= blindBox.dayTimes then
        return
    end
    local rewardList = BlindBoxRewardConfig:getRewardListByBlindBoxId(openData.boxId)
    if not rewardList then
        return
    end
    local lotteryCount = 0
    for _, group in pairs(rewardList) do
        lotteryCount = lotteryCount + group.lotteryCount
    end
    Lib.payMoney(player, blindBox.id, blindBox.moneyType, blindBox.price, function(success)
        if success then
            local results = {}
            for _, group in pairs(rewardList) do
                for _ = 1, group.lotteryCount do
                    local reward, isGrandPrize = ActivityLib.onOpenCommonRewardPool(player, group.groupId)
                    if reward then
                        table.insert(results, { rewardId = reward.rewardId, isGrandPrize = isGrandPrize })
                    end
                end
            end
            boxTag.openTimes = boxTag.openTimes + 1
            boxTag.dayOpenTimes = boxTag.dayOpenTimes + 1
            openData.results = results
            openData.openTimes = boxTag.openTimes
            openData.dayOpenTimes = boxTag.dayOpenTimes
            player:sendPacket({ pid = "BlindBoxOpenResult", data = openData })
        end
    end)
end