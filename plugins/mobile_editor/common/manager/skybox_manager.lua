--- skybox_manager.lua
--- 天空盒的管理器
---
---@class SkyboxManager : singleton
local SkyboxManager = T(MobileEditor, "SkyboxManager")
---@type ConfigManager
local ConfigManager = T(MobileEditor, "ConfigManager")
---@type setting
local setting = require "common.setting"

local PixelFormatMap = {
    RGB8 = 10,
    RGBA8 = 15
}

function SkyboxManager:initialize()
    self.skyboxId = nil
    self:subscribeEvents()
end

function SkyboxManager:load()
    local filePath = "map/" .. "map001" .. "/setting.json"
    local obj = Lib.readGameJson(filePath)
    self:updateSkybox(obj.skyBox[1].id)
end

function SkyboxManager:finalize()

end

function SkyboxManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_UPDATE_SKYBOX, function(skyboxId)
        self:updateSkybox(skyboxId)
    end)
end

function SkyboxManager:updateSkybox(skyboxId)
    if self.skyboxId == skyboxId then
        return
    end
    local config = ConfigManager:instance().skyboxConfig:getConfig(skyboxId)
    if not config then
        return
    end
    self.skyboxId = skyboxId
    local SkyboxCfg = setting:mod("sky")
    local cfg = SkyboxCfg:get("myplugin/" .. config.cfgName)
    if cfg then
        Blockman.Instance().gameSettings:clearSky()
        Blockman.Instance().gameSettings:addSky(cfg.texture[1], cfg.texture[2], cfg.texture[3], cfg.texture[4], cfg.texture[5], cfg.texture[6], cfg.time, cfg.transition, cfg.heightOffset)
        Blockman.Instance().gameSettings:setSkyRotate(cfg.skyBoxRotate)
        Blockman.Instance().gameSettings:setSkyBoxTexSize(cfg.skyBoxTexSize)
        Blockman.Instance().gameSettings:setSkyBoxTexPixFmt(PixelFormatMap[cfg.skyBoxTexPixFmt])
    end
end

return SkyboxManager