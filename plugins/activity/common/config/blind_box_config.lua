---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2020/11/30 15:05
---
local BlindBoxActivity = T(Lib, "BlindBoxActivity") ---@type BlindBoxActivity
local ConfigList = {}

local function init()
    ConfigList = {}
    local path = Root.Instance():getGamePath() .. "config/common/BlindBoxSetting.json"
    local file = io.open(path, "r")
    if not file then
        return
    end
    local content = file.read(file, "*a")
    io.close(file)
    local json = require("cjson")
    local success, setting = pcall(json.decode, content)
    if not success then
        Lib.log(setting, 4)
        return
    end
    path = Root.Instance():getGamePath() .. "config/common/BlindBox.csv"
    local settings = Lib.read_csv_file(path, 3)
    for _, item in pairs(settings) do
        ConfigList[item.id] = {
            id = tonumber(item.id),
            name = item.name,
            image = item.image,
            priceRange = item.priceRange,
            moneyType = tonumber(item.moneyType),
            price = tonumber(item.price),
            totalTimes = tonumber(item.totalTimes) or 5,
            dayTimes = tonumber(item.dayTimes) or 1,
            worthGroupId = tonumber(item.worthGroupId)
        }
    end
    BlindBoxActivity:init(setting)
end

local BlindBoxConfig = T(Config, "BlindBoxConfig") ---@class BlindBoxConfig

function BlindBoxConfig:getBlindBoxById(id)
    return ConfigList[tostring(id)]
end

function BlindBoxConfig:getBlindBoxByIds(ids)
    local result = {}
    ids = Lib.splitString(ids, ",")
    for _, id in pairs(ids) do
        table.insert(result, self:getBlindBoxById(id))
    end
    while #result > 3 do
        table.remove(result)
    end
    return result
end

init()