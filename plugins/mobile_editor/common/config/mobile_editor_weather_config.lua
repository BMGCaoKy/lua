--- mobile_editor_weather_config.lua
--- 天气的配置文件
local class = require "common.3rd.middleclass.middleclass"
---@class MobileEditorWeatherConfig : middleclass
local MobileEditorWeatherConfig = class('MobileEditorWeatherConfig')

function MobileEditorWeatherConfig:initialize()
    Lib.logDebug("MobileEditorWeatherConfig:initialize")
    ---@type WeatherData[]
    self.settings = {}
    self:load()
end

function MobileEditorWeatherConfig:load()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/mobile_editor_weather.csv", 2)
    for _, vConfig in pairs(config) do
        ---@class WeatherData
        local data = {}
        data.id = tonumber(vConfig.n_id)
        data.icon = tostring(vConfig.s_icon)
        data.name = tostring(vConfig.s_name)
        data.fogParam = Lib.splitString(vConfig.s_fogParam or "", "#", true)
        assert(data.fogParam[3] ~= 0, "config/mobile_editor_weather.csv, fogParam3 can't be 0, id:" .. vConfig.n_id)
        data.fogColor = Lib.splitString(vConfig.s_fogColor or "", "#", true)
        data.rainEffect = vConfig.s_rainEffect or ""
        data.rainSound =  tostring(vConfig.s_rainSound) or ""
        data.lightEffect = vConfig.s_lightEffect or ""
        data.lightSound = tostring(vConfig.s_lightSound) or ""
        data.lightFrequency = tonumber(vConfig.n_lightFrequency) or 0
        data.lightRate = tonumber(vConfig.n_lightRate) or 0
        data.lightPos = Lib.splitString(vConfig.s_lightPos or "", ",", false)
        table.insert(self.settings, data)
    end
end

---@return WeatherData
function MobileEditorWeatherConfig:getConfig(id)
    for index, data in ipairs(self.settings) do
        if data.id == id then
            return data
        end
    end
    return nil
end

function MobileEditorWeatherConfig:getConfigs()
    return self.settings
end

return MobileEditorWeatherConfig