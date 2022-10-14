---@class ShortConfig
local ShortConfig = T(Config, "ShortConfig")
local items = {}

function ShortConfig:init()
    local csvData = Lib.read_csv_file(Root.Instance():getGamePath() .. "lua/plugins/platform_chat/csv/short.csv", 2)
    if not csvData then
        csvData = Lib.read_csv_file(Root.Instance():getRootPath() .. "lua/plugins/platform_chat/csv/short.csv", 2) or {}
    end
    for _, config in pairs(csvData) do
        local data = {
            id = tonumber(config.id),
            name = config.name,
            text = config.text,
            headText = config.headText,
            event = config.event,
            eventArgs = config.eventArgs
        }
        table.insert(items, data)
    end

    table.sort(items, function(a, b )
        return a.id < b.id
    end)
end

function ShortConfig:getItems()
    return items or {}
end

function ShortConfig:getItemByName(text)
    for i, v in pairs(items) do
        if v.text == text then
            return v
        end
    end
    return nil
end

ShortConfig:init()
return ShortConfig