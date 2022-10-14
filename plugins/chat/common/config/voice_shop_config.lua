---@class VoiceShopConfig
local VoiceShopConfig = T(Config, "VoiceShopConfig")
local items = {}

function VoiceShopConfig:init()
    local csvData = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/voiceShop.csv", 2)
    if not csvData then
        print("cant find game config/voiceShop.csv,try use plugins defualt!")
        csvData = Lib.read_csv_file(Root.Instance():getRootPath() .. "lua/plugins/chat/csv/voiceShop.csv", 2) or {}
    end
    for _, config in pairs(csvData) do
        local data = {
            id = tonumber(config.id),
            cost = tonumber(config.cost),
            type = tonumber(config.type),
            num = tonumber(config.num)
        }
        table.insert(items, data)
    end

    table.sort(items, function(a, b )
        return a.id < b.id
    end)
end

function VoiceShopConfig:getItemById(id)
    local item = items[id]
    

    return item or {}
end
VoiceShopConfig:init()
return VoiceShopConfig