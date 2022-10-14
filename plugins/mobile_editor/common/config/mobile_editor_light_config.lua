--- mobile_editor_light_config.lua
--- 光照的配置文件
local class = require "common.3rd.middleclass.middleclass"
---@class MobileEditorLightConfig : middleclass
local MobileEditorLightConfig = class('MobileEditorLightConfig')

function MobileEditorLightConfig:initialize()
    Lib.logDebug("MobileEditorLightConfig:initialize")
    ---@type LightConfigData[]
    self.settings = {}
    self:load()
end

function MobileEditorLightConfig:load()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/mobile_editor_light.csv", 2)
    for _, vConfig in pairs(config) do
        ---@class LightConfigData
        local data = {}
        data.id = tonumber(vConfig.n_id)
        data.name = tostring(vConfig.s_name)
        data.type = tonumber(vConfig.n_type)
        data.icon = tostring(vConfig.s_icon)
        local str = Lib.splitString(tostring(vConfig.s_color), "#", true)
        data.color = str
        table.insert(self.settings, data)
    end
end

---@return LightConfigData
function MobileEditorLightConfig:getConfig(id)
    for index, data in ipairs(self.settings) do
        if data.id == id then
            return data
        end
    end
    return nil
end

function MobileEditorLightConfig:getConfigs()
    return self.settings
end

return MobileEditorLightConfig