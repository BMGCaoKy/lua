---@class EmojiConfig
local EmojiConfig = T(Config, "EmojiConfig")
local items = {}

function EmojiConfig:init()
    local csvData = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/emoji.csv", 2)
    if not csvData then
        print("cant find game config/voiceShop.csv,try use plugins defualt!")
        csvData = Lib.read_csv_file(Root.Instance():getRootPath() .. "lua/plugins/chat/csv/emoji.csv", 2) or {}
    end
    for _, config in pairs(csvData) do
        local data = {
            id = tonumber(config.id),
            icon = config.icon,
            text = config.text
        }
        table.insert(items, data)
    end

    table.sort(items, function(a, b )
        return a.id < b.id
    end)
end

function EmojiConfig:getItems()
    return items or {}
end

function EmojiConfig:getTextByIcon(icon)
    for i, v in pairs(items) do
        if v.icon == icon then
            return v.text
        end
    end
    return nil
end

EmojiConfig:init()
return EmojiConfig