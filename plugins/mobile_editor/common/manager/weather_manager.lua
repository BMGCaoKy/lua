--- weather_manager.lua
--- 天气的管理器
---
---@class WeatherManager : singleton
local WeatherManager = T(MobileEditor, "WeatherManager")
---@type ConfigManager
local ConfigManager = T(MobileEditor, "ConfigManager")

local BM = Blockman.Instance()
---@type LuaTimer
local LuaTimer = T(Lib, "LuaTimer")

function WeatherManager:initialize()
    Lib.logDebug("WeatherManager:initialize")
    self.rainEffect = nil
    self.lightEffect = nil
    self:subscribeEvents()
end

function WeatherManager:load()
    World.cfg.weather = World.cfg.weather or { id = 0 }
    self:initWeather(World.cfg.weather)
end

---@private
---@param weatherData CustomWeatherData
function WeatherManager:initWeather(weatherData)
    self.weatherId = weatherData.id
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(World.CurWorld.CurMap.obj)
    local pos = BM:getViewerPos()
    local rain = weatherData.rain
    if rain then
        if string.find(rain.effect, ".effect") then
            self.rainEffect = EffectNode.Load(rain.effect)
            self.rainEffect:start()
            self.rainEffect:setWorldPosition(pos)
            scene:getRoot():addChild(self.rainEffect)
        end
        if string.find(rain.sound, ".mp3") then
            Lib.emitEvent(Event.EVENT_PLAY_SOUND, rain.sound, true, 1.0)
        end
    end
    LuaTimer:cancel(self.lightEffectTimer)
    LuaTimer:cancel(self.lightSoundTimer)
    local lightning = weatherData.lightning
    if lightning then
        if string.find(lightning.effect, ".effect") then
            self.lightEffectTimer = LuaTimer:schedule(function()
                if self.lightEffect then
                    scene:getRoot():removeChild(self.lightEffect)
                    self.lightEffect:destroy()
                end
                self.lightEffect = EffectNode.Load(lightning.effect)
                self.lightEffect:start()
                local curPos = BM:getViewerPos() + Lib.v3(0, math.random(3, 10), 0)
                self.lightEffect:setWorldPosition(curPos)
                scene:getRoot():addChild(self.lightEffect)
            end, 0, lightning.frequency * 1000)
        end
        if string.find(lightning.sound, ".mp3") then
            self.lightSoundTimer = LuaTimer:schedule(function()
                Lib.emitEvent(Event.EVENT_PLAY_SOUND, lightning.sound, false, 1.0)
            end, 0, lightning.frequency * 1000)
        end
    end
    local fog = weatherData.fog
    if fog then
        BM.gameSettings.hideFog = false
        local color = { x = fog.color[1], y = fog.color[2], z = fog.color[3] }
        BM.gameSettings:setCustomFog(fog.fogStart, fog.fogEnd, fog.density, color, 1, 0.1)
    else
        BM.gameSettings.hideFog = true
    end
end

---@private
function WeatherManager:finalize()
    Lib.emitEvent(Event.EVENT_STOP_SOUND)
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(World.CurWorld.CurMap.obj)

    if self.rainEffect then
        scene:getRoot():removeChild(self.rainEffect)
        self.rainEffect:destroy()
        self.rainEffect = nil
    end

    if self.lightEffect then
        scene:getRoot():removeChild(self.lightEffect)
        self.lightEffect:destroy()
        self.lightEffect = nil
    end

    BM.gameSettings.hideFog = true
end

function WeatherManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_UPDATE_WEATHER, function(weatherId)
        Lib.logDebug("EVENT_UPDATE_WEATHER id = ", weatherId)
        self:updateWeather(weatherId)
    end)
end

function WeatherManager:tick()
    if self.rainEffect then
        local pos = BM:getViewerPos()
        self.rainEffect:setWorldPosition(pos)
    end
end

function WeatherManager:updateWeather(weatherId)
    if self.weatherId == weatherId then
        return
    end
    self:finalize()
    self.weatherId = weatherId
    local config = ConfigManager:instance().weatherConfig:getConfig(self.weatherId)
    if not config then
        return
    end
    ---@class CustomWeatherData
    local weatherData = {
        id = weatherId,
        rain = {
            effect = config.rainEffect,
            sound = config.rainSound
        },
        lightning = {
            effect = config.lightEffect,
            sound = config.lightSound,
            frequency = config.lightFrequency,
            rate = config.lightRate
        },
    }
    if config.fogParam and config.fogParam[1] ~= 0 and config.fogColor then
        weatherData.fog = {
            color = config.fogColor,
            density = config.fogParam[1],
            fogStart = config.fogParam[2],
            fogEnd = config.fogParam[3]
        }
    end
    self:initWeather(weatherData)
    World.cfg.weather = weatherData
    Lib.logDebug("weatherData = ", weatherData)
end

return WeatherManager