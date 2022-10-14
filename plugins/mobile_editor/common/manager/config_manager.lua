--- config_manager.lua
--- 相机的管理器
---
---@class ConfigManager : singleton
local ConfigManager = T(MobileEditor, "ConfigManager")

local csvConfig = {
    modConfig = {
        file = "mobile_editor_mod.csv",
        splitType = "modType",
        keyMap = {
            id = {key="id", func="tonumber"},
            type = {key="modType", func="tostring"},
            icon = {key="icon", func="tostring"},
            name = {key="name", func="tostring"},
            cfgName = {key="cfgName", func="tostring"}
        }
    }
}

local decodeFunc = {
    tonumber = tonumber,
    tostring = tostring
}

function ConfigManager:getConfig(tb, key, splitType)
    if not self[tb] then
        Lib.logError("no config ", tb)
    end
    if splitType then
        return self[tb][splitType][key]
    end
    if csvConfig[tb].splitType then
        for _, subs in pairs(self[tb]) do
            if subs[key] then
                return subs[key]
            end
        end
    end
    return self[tb][key]
end

function ConfigManager:initialize()
    Lib.logDebug("ConfigManager:initialize")
    local srcData = {}
    for tb, cfg in pairs(csvConfig) do
        self[tb] = {}
        srcData = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/" .. cfg.file, 2)
        for _, vConfig in pairs(srcData) do
            local info = {}
            for key, vInfo in pairs(cfg.keyMap) do
                info[key] = decodeFunc[vInfo.func](vConfig[vInfo.key])
            end
            if cfg.splitType then
                if not self[tb][vConfig[cfg.splitType]] then
                    self[tb][vConfig[cfg.splitType]] = {}
                end
                self[tb][vConfig[cfg.splitType]][info.id] = info
            else
                self[tb][info.id] = info
            end
        end
    end

    local MaterialColorConfig = require "common.config.material_color_config"
    self.materialColorConfig = MaterialColorConfig:new()

    local MaterialTextureConfig = require "common.config.material_texture_config"
    self.materialTextureConfig = MaterialTextureConfig:new()

    --local MaterialPresetConfig = require "common.config.material_preset_config"
    --self.materialPresetConfig = MaterialPresetConfig:new()

    local SkyBoxConfig = require "common.config.mobile_editor_skybox_config"
    self.skyboxConfig = SkyBoxConfig:new()

    local MusicConfig = require "common.config.mobile_editor_music_config"
    self.musicConfig = MusicConfig:new()

    local WeatherConfig = require "common.config.mobile_editor_weather_config"
    self.weatherConfig = WeatherConfig:new()

    local LightConfig = require "common.config.mobile_editor_light_config"
    self.lightConfig = LightConfig:new()

    local GroundMaterialColorConfig = require "common.config.ground_material_color_config"
    self.groundMaterialColorConfig = GroundMaterialColorConfig:new()

    local GroundMaterialTextureConfig = require "common.config.ground_material_texture_config"
    self.groundMaterialTextureConfig = GroundMaterialTextureConfig:new()
end

function ConfigManager:finalize()

end

return ConfigManager