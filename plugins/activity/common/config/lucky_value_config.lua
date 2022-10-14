local LuckyValueConfig = T(Config, "LuckyValueConfig") ---@class LuckyValueConfig
local LuckyValue = {}

local function init()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/common/LuckyValue.csv", 3) or {}
    for _, item in pairs(config) do
        local data = {}
        data.luckyValue = tonumber(item.luckyValue)
        data.luckyStars = tonumber(item.luckyStars)
        data.grandPrizeWeights = tonumber(item.grandPrizeWeights)
        LuckyValue[tonumber(item.seq)] = data
    end
end

function LuckyValueConfig:getWeightByLuckyValue(luckyValue)
    local weight = 0
    for _, luckyLevel in pairs(LuckyValue) do
        if luckyValue >= luckyLevel.luckyValue then
            weight = luckyLevel.grandPrizeWeights
        else
            return weight
        end
    end
    return weight
end

function LuckyValueConfig:getStarsByLuckyValue(luckyValue)
    local luckyStar = 0
    for _, luckyLevel in pairs(LuckyValue) do
        if luckyValue >= luckyLevel.luckyValue then
            luckyStar = luckyLevel.luckyStars
        else
            return luckyStar
        end
    end
    return luckyStar
end

init()