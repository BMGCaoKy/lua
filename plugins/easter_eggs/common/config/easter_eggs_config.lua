---@class EasterEggsConfig
local EasterEggsConfig = T(Config, "EasterEggsConfig")
local settings = {}
local typeSettings = {}

function EasterEggsConfig:init()
    local gameType = World.GameName
    --local csvData = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/easter_eggs.csv", 2)
    local csvData = Lib.read_csv_file(Root.Instance():getRootPath() .. "lua/plugins/easter_eggs/csv/"..gameType.."/easter_eggs.csv", 2)
    if not csvData then
        print("cant find game config/easter_eggs.csv,try use plugins defualt!")
        csvData = Lib.read_csv_file(Root.Instance():getRootPath() .. "lua/plugins/easter_eggs/csv/easter_eggs.csv", 2) or {}
    end
    for _, config in pairs(csvData) do
        ---@class EasterEggsConfigData
        local data = {
            id = tonumber(config.id),
            eggType = tonumber(config.n_eggType),
            income = Lib.splitString(config.s_income, "#", true),
            actor = config.s_actor,
            actorBox = Lib.splitString(config.s_actorBox, "#", true),
            textHeight = tonumber(config.n_textHeight),
            incomeEffect = config.s_incomeEffect,
        }
        settings[data.id] = data

        typeSettings[data.eggType] = typeSettings[data.eggType] or {}
        table.insert(typeSettings[data.eggType], data)
    end
end

function EasterEggsConfig:getCfgById(id)
    return settings[id] or {}
end

function EasterEggsConfig:getAllCfg()
    return settings or {}
end

function EasterEggsConfig:getRandomEgg(eggType)
    local eggs = typeSettings[eggType]
    local index = math.floor(math.random() * #eggs) + 1
    return eggs[index].id
end

function EasterEggsConfig:getEggList(eggType)
    local eggs = typeSettings[eggType]
    return eggs
end

EasterEggsConfig:init()
return EasterEggsConfig