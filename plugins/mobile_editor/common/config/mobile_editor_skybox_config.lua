--- mobile_editor_skybox_config.lua
--- 天空盒的配置文件
local class = require "common.3rd.middleclass.middleclass"
---@class MobileEditorSkyboxConfig : middleclass
local MobileEditorSkyboxConfig = class('MobileEditorSkyboxConfig')

function MobileEditorSkyboxConfig:initialize()
    Lib.logDebug("MobileEditorSkyboxConfig:initialize")
    ---@type SkyboxData[]
    self.settings = {}
    self:load()
end

function MobileEditorSkyboxConfig:load()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/mobile_editor_skybox.csv", 2)
    for _, vConfig in pairs(config) do
        ---@class SkyboxData
        local data = {}
        data.id = tonumber(vConfig.n_id)
        data.icon = tostring(vConfig.s_icon)
        data.name = tostring(vConfig.s_name)
        data.cfgName = tostring(vConfig.s_cfg_name)
        table.insert(self.settings, data)
    end
end

---@return SkyboxData
function MobileEditorSkyboxConfig:getConfig(id)
    for index, data in ipairs(self.settings) do
        if data.id == id then
            return data
        end
    end
    return nil
end

function MobileEditorSkyboxConfig:getConfigs()
    return self.settings
end

return MobileEditorSkyboxConfig