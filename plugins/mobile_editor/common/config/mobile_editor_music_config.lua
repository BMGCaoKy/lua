--- mobile_editor_music_config.lua
--- 音乐的配置文件
local class = require "common.3rd.middleclass.middleclass"
---@class MobileEditorMusicConfig : middleclass
local MobileEditorMusicConfig = class('MobileEditorMusicConfig')

function MobileEditorMusicConfig:initialize()
    Lib.logDebug("MobileEditorMusicConfig:initialize")
    ---@type MusicConfigData[]
    self.settings = {}
    self:load()
end

function MobileEditorMusicConfig:load()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/mobile_editor_music.csv", 2)
    for _, vConfig in pairs(config) do
        ---@class MusicConfigData
        local data = {}
        data.id = tonumber(vConfig.n_id)
        data.icon = tostring(vConfig.s_icon)
        data.name = tostring(vConfig.s_name)
        data.author = tostring(vConfig.s_author)
        data.path = tostring(vConfig.s_path)
        table.insert(self.settings, data)
    end
end

---@return MusicConfigData
function MobileEditorMusicConfig:getConfig(id)
    for index, data in ipairs(self.settings) do
        if data.id == id then
            return data
        end
    end
    return nil
end

function MobileEditorMusicConfig:getConfigs()
    return self.settings
end

return MobileEditorMusicConfig