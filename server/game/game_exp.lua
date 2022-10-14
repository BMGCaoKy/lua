local UserExpCache = {}
local WaitSaveExpCache = {}
local QuitSaveExpCache = {}
local EnableCache = {}

local Enable = true
local ExpVersionCode = 1
local MaxLv = 0
local DayMaxExp = 1000
local ExpCoefficient = 1
local UpgradeExpTable = {}
local ExpCorrectTable = {}
local ExpTimeTable = {}
local ExpCampsAddTable = {}

local Status = {
    UNDONE = 0,
    DONE = 1,
    DAY_FULL = 2
}

local server = Server.CurServer

local function isEnable()
    return Enable
end

local function checkVersionCode(userId)
    if EnableCache[tostring(userId)] ~= nil then
        return EnableCache[tostring(userId)]
    end
    local player = userId and Game.GetPlayerByUserId(userId)
    if not player then
        return false
    end
    local version_code = player.clientInfo.version_code or 0
    EnableCache[tostring(userId)] = tonumber(version_code) >= tonumber(ExpVersionCode)
    return EnableCache[tostring(userId)]
end

local function isExpMaxToday(hasGet)
    return hasGet >= DayMaxExp
end

local function getAddExp(time, win, camps)
    if #ExpTimeTable == 0 then
        return 0
    end
    local minutes = math.min(#ExpTimeTable, math.max(1, math.floor((os.time() - time) / 60)))
    local addExp = ExpTimeTable[minutes]
    if win and #ExpCampsAddTable ~= 0 then
        camps = math.min(#ExpCampsAddTable, math.max(1, camps))
        addExp = addExp + addExp * ExpCampsAddTable[camps]
    end
    addExp = addExp * ExpCoefficient
    return addExp
end

local function correctAddExp(hasGet, addExp)
    local result = 0
    while addExp > 0 do
        local curCorrect
        local nextCorrect
        for index = 1, #ExpCorrectTable - 1 do
            curCorrect = ExpCorrectTable[index]
            nextCorrect = ExpCorrectTable[index + 1]
            if hasGet >= curCorrect[1] and hasGet < nextCorrect[1] then
                break
            end
        end
        if curCorrect == nil or nextCorrect == nil then
            break
        end
        local max = math.min(nextCorrect[1] - hasGet, addExp)
        local exp = max * curCorrect[2]
        addExp = addExp - max
        hasGet = hasGet + exp
        result = result + exp
    end
    return math.ceil(result)
end

local function checkTodayExpFull(hasGet, addExp)
    addExp = correctAddExp(hasGet, addExp)
    if hasGet + addExp >= DayMaxExp then
        return DayMaxExp - hasGet, Status.DAY_FULL
    else
        return addExp, Status.DONE
    end
end

local function checkLvUp(curLv, curExp, addExp)
    local upExp = UpgradeExpTable[tostring(curLv)]
    if upExp == nil then
        return curLv, curExp
    end
    local toLv, toExp = curLv, curExp
    while curExp + addExp >= upExp do
        toLv = toLv + 1
        addExp = addExp + curExp - upExp
        curExp = 0
        upExp = UpgradeExpTable[tostring(toLv)]
        if upExp == nil then
            toLv = toLv - 1
            addExp = 0
            break
        end
    end
    toExp = addExp
    return toLv, toExp
end

local function getAverageUpExp(curLv, toLv)
    local totalExp = 0
    for lv = curLv, toLv do
        local upExp = UpgradeExpTable[tostring(lv)]
        if upExp ~= nil then
            totalExp = totalExp + upExp
        end
    end
    return math.floor(totalExp / (toLv - curLv + 1))
end

local function sendExpResult(userId, status)
    if not isEnable() then
        return
    end
    local expInfo = UserExpCache[tostring(userId)]
    if expInfo == nil then
        return
    end
    if expInfo.addExp > 0 then
        local upExp = getAverageUpExp(expInfo.curLv, expInfo.toLv)
        server:sendAppExpResult(userId, expInfo.curLv, expInfo.toLv, expInfo.addExp, expInfo.curExp, expInfo.toExp, upExp, status)
    end
end

local function tryCalculationExp()
    if not isEnable() then
        --print("not isEnable")
        return
    end
    local curTime = os.time()
    for userId, cache in pairs(UserExpCache) do
        if (curTime - cache.time) % 60 == 0 then
            Game.addUserExp(userId, false, 0, true)
        end
    end
end

local function trySaveExpResult()
    if not isEnable() then
        return
    end
    if #WaitSaveExpCache == 0 then
        return
    end
    local data = {}
    for _, cache in pairs(WaitSaveExpCache) do
        table.insert(data, {
            userId = cache.userId,
            experienceGet = cache.addExp,
            gameId = World.GameName
        })
    end
    WaitSaveExpCache = {}
    AsyncProcess.SaveBlockymodsUsersExp(data)
end

function Game.initRole(data)
    ExpVersionCode = data.appVersion
    Enable = data.needSettle
    if isEnable() then
        DayMaxExp = data.maxExpPerDay
        UpgradeExpTable = data.upgradeRule
        ExpCoefficient = data.gameCoefficient / 100
        for _, _ in pairs(UpgradeExpTable) do
            MaxLv = MaxLv + 1
        end
        table.insert(ExpCorrectTable, { 0, 1 })
        local min = 1
        for exp, per in pairs(data.recessionRule) do
            local x = (100 - per) / 100
            if min >= x then
                min = x
            end
            table.insert(ExpCorrectTable, { tonumber(exp), x })
        end
        table.insert(ExpCorrectTable, { 10000000, min })
        table.sort(ExpCorrectTable, function(c1, c2)
            return c1[1] < c2[1]
        end)
        for minute, exp in pairs(data.timeExpRule) do
            table.insert(ExpTimeTable, exp)
        end
        table.sort(ExpTimeTable, function(exp1, exp2)
            return exp1 < exp2
        end)
        for camp, per in pairs(data.campBonusRule) do
            table.insert(ExpCampsAddTable, per / 100)
        end
        table.sort(ExpCampsAddTable, function(per1, per2)
            return per1 < per2
        end)
    end
end

function Game.disable()
    Enable = false
end

function Game.resetUserExpCache()
    for _, cache in pairs(UserExpCache) do
        cache.isAdd = false
    end
end

function Game.getUserExpCache(userId)
    if not isEnable() then
        return
    end
    AsyncProcess.GetBlockymodsUserExp(userId)
end

function Game.addExpCache(userId, curLv, curExp, hasGet)
    if not isEnable() or not checkVersionCode(userId) then
        return
    end
    UserExpCache[tostring(userId)] = {
        curLv = curLv,
        curExp = curExp,
        hasGet = hasGet,
        addExp = 0,
        toLv = curLv,
        toExp = curExp,
        time = os.time(),
        isAdd = false
    }
    local status = Status.UNDONE
    if isExpMaxToday(hasGet) then
        status = Status.DAY_FULL
    end
    local upExp = getAverageUpExp(curLv, curLv)
    server:sendAppExpResult(userId, curLv, curLv, 0, curExp, curExp, upExp, status)
end

function Game.removeExpCache(userId)
    if not isEnable() or not checkVersionCode(userId) then
        return
    end
    local expInfo = UserExpCache[tostring(userId)]
    if expInfo ~= nil and not expInfo.isAdd then
        local cache = QuitSaveExpCache[tostring(userId)]
        if cache ~= nil then
            local data = {}
            table.insert(data, {
                userId = cache.userId,
                experienceGet = cache.addExp,
                gameId = World.GameName
            })
            AsyncProcess.SaveBlockymodsUsersExp(data)
        end
    end
    QuitSaveExpCache[tostring(userId)] = nil
    UserExpCache[tostring(userId)] = nil
    EnableCache[tostring(userId)] = nil
end

function Game.addUserExp(userId, win, camps, global)
    if not isEnable() or not checkVersionCode(userId) then
        return
    end
    local expInfo = UserExpCache[tostring(userId)]
    if expInfo == nil then
        return
    end
    if expInfo.isAdd then
        return
    end
    if expInfo.curLv >= MaxLv then
        return
    end
    local status = Status.UNDONE
    local addExp = getAddExp(expInfo.time, win, camps)
    addExp, status = checkTodayExpFull(expInfo.hasGet, addExp)
    if addExp <= 0 then
        return
    end
    if not global then
        local cache = QuitSaveExpCache[tostring(userId)]
        if cache then
            --删除之前通过时间计算的经验值
            expInfo.addExp = math.max(expInfo.addExp - cache.addExp, 0)
            cache.addExp = 0
        end
        expInfo.hasGet = expInfo.hasGet + addExp
        expInfo.addExp = expInfo.addExp + addExp
        expInfo.time = os.time()
        expInfo.isAdd = true
        table.insert(WaitSaveExpCache, {
            userId = tonumber(tostring(userId)),
            addExp = addExp
        })
    else
        expInfo.addExp = addExp
        QuitSaveExpCache[tostring(userId)] = {
            userId = tonumber(tostring(userId)),
            addExp = addExp
        }
    end
    expInfo.toLv, expInfo.toExp = checkLvUp(expInfo.curLv, expInfo.curExp, expInfo.addExp)
    sendExpResult(userId, status)
end

function Game.tickTrySaveExpResult()
    tryCalculationExp()
    trySaveExpResult()
    return true
end