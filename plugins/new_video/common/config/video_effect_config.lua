---@class VideoEffectConfig
local VideoEffectConfig = T(Config, "VideoEffectConfig")

local settings = {}
function VideoEffectConfig:init()
    local csvData = Lib.read_csv_file(Root.Instance():getGamePath() .. "lua/plugins/new_video/csv/video_effect.csv", 2)
    if not csvData then
        print("cant find game config/voiceShop.csv,try use plugins defualt!")
        csvData = Lib.read_csv_file(Root.Instance():getRootPath() .. "lua/plugins/new_video/csv/video_effect.csv", 2) or {}
    end
    for _, vConfig in pairs(csvData) do
        ---@class VideoEffectConfigData
        local data = {
            tabId = tonumber(vConfig.n_tabId),
            sortIndex = tonumber(vConfig.n_sortIndex),
            icon = vConfig.s_icon or "",
            titleLang = vConfig.s_titleLang or "",
            eventType = vConfig.s_eventType,
            param = vConfig.s_param,
        }
        data.selectState = false
        if not settings[data.tabId] then
            settings[data.tabId] = {}
        end
        table.insert(settings[data.tabId], data)
    end

    for tabId, val in pairs(settings) do
        table.sort(settings[tabId], function (a, b)
            return a.sortIndex < b.sortIndex
        end)
    end
end

function VideoEffectConfig:getCfgByTabId(tabId)
    if not settings[tabId] then
        Lib.logError("can not find VideoEffectConfig, tabId:", tabId )
        return nil
    end
    return settings[tabId]
end

function VideoEffectConfig:getAllCfg()
    return settings
end
VideoEffectConfig:init()
return VideoEffectConfig

