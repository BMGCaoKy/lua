local RedisHandler = require "redishandler"
local cjson = require "cjson"
local misc = require "misc"

local rankDataHelper = {}  ---@class rankDataHelper
local dataList = { timeIndex = 1, data = {}, expiration = {} }

local function readFile(path)
    local file = io.open(path, "rb")
    if file then
        local data = file:read("a")
        file:close()
        local text = misc.read_text(data)
        local line, pos
        while true do
            line, pos = misc.csv_decode(text, pos)
            if line then
                dataList[line[1]] = cjson.decode(line[2])
            end
            if not pos then
                break
            end
        end
    end
end

local function writeFile(path)
    local lines = {}
    for k, v in pairs(dataList) do
        lines[#lines + 1] = misc.csv_encode({ k, cjson.encode(v) })
    end
    lines[#lines + 1] = ""
    misc.write_utf16(path, table.concat(lines, "\r\n"))
end

local function initRankData(self)
    local baseUrl = Server.CurServer:getDataServiceURL()
    self.subKey = 1
    self.gameName = World.GameName
    self.enable = baseUrl ~= ""
    if self.enable and baseUrl:sub(1, 6) == "local:" then
        self.localFile = "rankdata.csv"
        readFile(self.localFile)
    end
end

local function checkType(temp, typ)
    return type(temp) ~= typ
end

local function checkParameter(parameters)
    local txtError
    for key, temp in pairs(parameters) do
        if checkType(temp.value, temp.type or "string") then
            txtError = string.format("%s parameter error --- %s : %s \n", txtError or "", key, temp.value)
        end
    end
    return txtError
end

local function sortRank(rankList)
    table.sort(rankList, function(data1, data2)
        -- 按value降序
        -- 如果value相等，按index升序
        local v1, v2 = data1.value, data2.value
        if v1 == v2 then
            return data1.index < data2.index
        end
        return v1 > v2
    end)
end

local function updateTimeIndex()
    dataList.timeIndex = dataList.timeIndex + 1
    return dataList.timeIndex
end

local function getDataIndex(rankList, key)
    if not key then
        return
    end
    for i, data in ipairs(rankList) do
        if data.key == key then
            return i
        end
    end
end

local function getLocalRankList(rankName)
    local expireTime = tonumber(dataList.expiration[rankName])
    local list = dataList.data[rankName]
    if not list then
        list = {}
        dataList.data[rankName] = list
    end
    if expireTime and expireTime <= os.time() then
        list = {}
        dataList.data[rankName] = list
        dataList.expiration[rankName] = nil
    end
    return list
end

local function getRelevantData(self, name, key)
    local l_name = string.format("%s:%s", self.gameName, name)
    if self.localFile then
        local rankList = getLocalRankList(l_name)
        local index = getDataIndex(rankList, key)
        return l_name, rankList, index
    end
    return l_name
end

local function writeLocalData(self)
    writeFile(self.localFile)
end

local function addOrCoverData(self, index, rankList, key, value, isCover)
    local timeIndex = updateTimeIndex(self)
    if index then
        rankList[index].value = isCover and value or rankList[index].value + value
        rankList[index].index = timeIndex
    else
        table.insert(rankList, { key = key, value = value, index = timeIndex })
    end
    sortRank(rankList)
    writeLocalData(self)
end

function rankDataHelper:getData(rankName, key, callback)
    local res = checkParameter({ rankName = { value = rankName }, key = { value = key } })
    if res then
        perror(res, debug.traceback())
        return
    end

    local name, rankList, index = getRelevantData(self, rankName, key)
    if self.localFile then
        callback(index and true or false, index and rankList[index].value, index)
        return
    end

    RedisHandler:ZScore(name, key, callback)
end

function rankDataHelper:removeData(rankName, key)
    local res = checkParameter({ rankName = { value = rankName }, key = { value = key } })
    if res then
        perror(res, debug.traceback())
        return
    end

    local name, rankList, index = getRelevantData(self, rankName, key)
    if self.localFile then
        if index then
            table.remove(rankList, index)
            writeLocalData(self)
        end
        return
    end

    RedisHandler:ZRemove(name, key, true)
end

function rankDataHelper:incrementData(rankName, key, add)
    add = tonumber(add)
    local res = checkParameter({
        rankName = { value = rankName },
        key = { value = key },
        add = { value = add, type = "number" }
    })
    if res then
        perror(res, debug.traceback())
        return
    end

    local name, rankList, index = getRelevantData(self, rankName, key)
    if self.localFile then
        addOrCoverData(self, index, rankList, key, add)
        return
    end

    RedisHandler:ZIncrBy(name, key, add, true)
end

function rankDataHelper:setData(rankName, key, value)
    value = tonumber(value)
    local res = checkParameter({
        rankName = { value = rankName },
        key = { value = key },
        add = { value = value, type = "number" }
    })
    if res then
        perror(res, debug.traceback())
        return
    end

    local name, rankList, index = getRelevantData(self, rankName, key)
    if self.localFile then
        addOrCoverData(self, index, rankList, key, value, true)
        return
    end

    RedisHandler:ZAdd(name, key, value)
    RedisHandler:trySendZIncBy(true)
end

function rankDataHelper:getDataByRange(rankName, startIndex, endIndex, callback)
    startIndex, endIndex = tonumber(startIndex), tonumber(endIndex)
    local res = checkParameter({
        rankName = { value = rankName },
        startIndex = { value = startIndex, type = "number" },
        endIndex = { value = endIndex, type = "number" }
    })
    if res then
        perror(res, debug.traceback())
        return
    end

    if startIndex <= 0 then
        perror("startIndex can not be less than zero", debug.traceback())
        return
    end

    local name, rankList = getRelevantData(self, rankName)
    local rankTb = {}     --{    [1] = {key = key , value = value } ...  } 没有数据返回空表
    if self.localFile then
        for i = startIndex, endIndex do
            local data = rankList[i]
            if not data then
                break
            end
            table.insert(rankTb, { key = data.key, value = data.value })
        end
        callback(true, rankTb)
        return
    end
    startIndex, endIndex = startIndex - 1, endIndex - 1
    RedisHandler:ZRange(name, startIndex, endIndex, function(success, data)
        if not success then
            callback(success, rankTb)
            return
        end
        local totalData = Lib.splitString(data, "#", false)
        for _, line in pairs(totalData) do
            local lineData = Lib.splitString(line, ":", false)
            table.insert(rankTb, { key = lineData[1], value = tonumber(lineData[2]) })
        end
        callback(success, rankTb)
    end)
end

function rankDataHelper:getRankDataSum(rankName, callback)
    local res = checkParameter({ rankName = { value = rankName } })
    if res then
        perror(res, debug.traceback())
        return
    end

    local name, rankList = getRelevantData(self, rankName)
    if self.localFile then
        callback(true, #rankList)
        return
    end
    RedisHandler:ZCard(name, callback)
end

function rankDataHelper:setExpireTime(rankName, timeStamp)
    local name = getRelevantData(self, rankName)
    if self.localFile then
        dataList.expiration[name] = timeStamp
        writeLocalData(self)
        return
    end
    RedisHandler:ZExpireat(name, timeStamp, true)
end

initRankData(rankDataHelper)

return rankDataHelper