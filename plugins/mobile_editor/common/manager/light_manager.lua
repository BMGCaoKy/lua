--- light_manager.lua
--- 光照的管理器
---
---@class LightManager : singleton
local LightManager = T(MobileEditor, "LightManager")
---@type ConfigManager
local ConfigManager = T(MobileEditor, "ConfigManager")

function LightManager:initialize()
    --Lib.logDebug("LightManager:initialize")
    self.ambientId = nil
    self.diffuseId = nil
    self.lightAngle = 45

    self:subscribeEvents()
end

function LightManager:load()
    World.cfg.ambientStrength = World.cfg.ambientStrength or 0.6
    World.cfg.maxAmbientStrength = World.cfg.maxAmbientStrength or 1.2
    World.cfg.lightDirect = World.cfg.lightDirect or 0
    World.cfg.lightAngle = World.cfg.lightAngle or 45
    self:setAmbientStrength(World.cfg.ambientStrength)
    self:setMainLightDir(World.cfg.lightDirect)
    if World.cfg.dirLightAmbient then
        self:setAmbientColor(World.cfg.dirLightAmbient.id, World.cfg.dirLightAmbient.color)
    end
    if World.cfg.dirLightDiffuse then
        self:setDiffuseColor(World.cfg.dirLightDiffuse.id, World.cfg.dirLightDiffuse.color)
    end
end

function LightManager:finalize()

end

function LightManager:resetLight()
    if not World.CurWorld:getEnableNewLighting() then
        return
    end
    EngineSceneManager.Instance():setBlinn(1)
    EngineSceneManager.Instance():setHdr(1)
    EngineSceneManager.Instance():setDirLightAmbient({ 1.0, 1.0, 1.0, 1.0 })
    EngineSceneManager.Instance():setDirLightDiffuse({ 1.0, 1.0, 1.0, 1.0 })
    EngineSceneManager.Instance():setDirLightSpecular({ 1.0, 1.0, 1.0, 1.0 })
end

function LightManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_RESET_LIGHT, function()
        self:resetLight()
    end)
    Lib.subscribeEvent(Event.EVENT_UPDATE_AMBIENT_STRENGTH, function(value)
        self:setAmbientStrength(value)
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_AMBIENT_COLOR, function(id)
        self:setAmbientColor(id)
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_DIFFUSE_COLOR, function(id)
        self:setDiffuseColor(id)
    end)
end

function LightManager:setAmbientColor(id, color)
    if not color then
        if self.ambientId == id then
            return
        end
        local config = ConfigManager:instance().lightConfig:getConfig(id)
        if not config then
            return
        end
        self.ambientId = id
        color = config.color
    end
    EngineSceneManager.Instance():setDirLightAmbient(color)
    World.cfg.dirLightAmbient = World.cfg.dirLightAmbient or {}
    World.cfg.dirLightAmbient.id = id
    World.cfg.dirLightAmbient.color = color
end

function LightManager:setDiffuseColor(id, color)
    if not color then
        if self.diffuseId == id then
            return
        end
        local config = ConfigManager:instance().lightConfig:getConfig(id)
        if not config then
            return
        end
        self.diffuseId = id
        color = config.color
    end
    local quality = Blockman.Instance().gameSettings:getCurQualityLevel()
    if quality == Define.GRAPHICS_QUALITY.LOW then
        EngineSceneManager.Instance():setMainLightColor(color)
    else
        EngineSceneManager.Instance():setDirLightDiffuse(color)
    end
    World.cfg.dirLightDiffuse = World.cfg.dirLightDiffuse or {}
    World.cfg.dirLightDiffuse.id = id
    World.cfg.dirLightDiffuse.color = color
end

function LightManager:setAmbientStrength(ambientStrength)
    World.cfg.ambientStrength = ambientStrength
    EngineSceneManager.Instance():setAmbientStrength(ambientStrength)
end

function LightManager:setMainLightDir(directValue)
    World.cfg.lightDirect = directValue
    local directAngle = directValue / 180 * math.pi
    EngineSceneManager.Instance():setMainLightDir(Lib.v3(math.cos(directAngle), World.cfg.lightAngle / 90, math.sin(directAngle)))
end

function LightManager:setLightAngle(lightAngle)
    World.cfg.lightAngle = math.min(math.max(30, lightAngle), 90)
    self:setMainLightDir(World.cfg.lightDirect)
end

return LightManager