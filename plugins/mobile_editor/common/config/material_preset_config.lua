--- material_preset_config.lua
--- 笔刷材质贴图配置
local class = require "common.3rd.middleclass.middleclass"

local MaterialPresetConfig = class('MaterialPresetConfig')

function MaterialPresetConfig:initialize()
    Lib.logDebug("MaterialPresetConfig:initialize")
    self.settings = {}
    self:load()
end

function MaterialPresetConfig:load()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/mobile_editor_material_preset.csv", 2)
    for _, vConfig in pairs(config) do
        local data = {}
        data.id = tonumber(vConfig.n_id)
        data.colorId = tonumber(vConfig.n_colorId)
        data.textureId = tonumber(vConfig.n_textureId)
        table.insert(self.settings, data)
    end
end

function MaterialPresetConfig:getConfig(index)
    for i, data in ipairs(self.settings) do
        if i == index then
            return data
        end
    end
    return nil
end

function MaterialPresetConfig:getConfigs()
    return self.settings
end

return MaterialPresetConfig