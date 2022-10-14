--- ground_manager.lua
--- 地面的管理器
---
---@class GroundManager : singleton
local GroundManager = T(MobileEditor, "GroundManager")
---@type ConfigManager
local ConfigManager = T(MobileEditor,"ConfigManager")
---@type util
local util = require "common.util.util"

function GroundManager:initialize()
    self:subscribeEvents()
end

function GroundManager:load()
    World.cfg.groundColor = World.cfg.groundColor or {}
    World.cfg.groundMaterial = World.cfg.groundMaterial or {}
    if World.cfg.groundColor.id and World.cfg.groundColor.color then
        self:updateGroundColor(World.cfg.groundColor.id)
    end
    if World.cfg.groundMaterial.id and World.cfg.groundMaterial.materialTexture then
        self:updateGroundMaterial(World.cfg.groundMaterial.id)
    end
end

function GroundManager:finalize()

end

function GroundManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_UPDATE_GROUND_COLOR, function(groundColorId)
        self:updateGroundColor(groundColorId)
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_GROUND_MATERIAL, function(groundMaterialId)
        self:updateGroundMaterial(groundMaterialId)
    end)
end

function GroundManager:updateGroundColor(groundColorId)
    if World.cfg.groundColor.id == groundColorId then
        return
    end
    local floor = self:getSceneFloor()
    if not floor then
        return
    end
    local config = ConfigManager:instance().groundMaterialColorConfig:getConfig(groundColorId)
    if config then
        World.cfg.groundColor.id = config.id
        World.cfg.groundColor.color = config.color
        local color_temp = string.format("r:%s g:%s b:%s", config.color[1] / 255, config.color[2] / 255, config.color[3] / 255)
        util:setProperty(floor, "materialColor", color_temp)
    end
end

function GroundManager:updateGroundMaterial(groundMaterialId)
    if World.cfg.groundMaterial.id == groundMaterialId then
        return
    end
    local floor = self:getSceneFloor()
    if not floor then
        return
    end
    local config = ConfigManager:instance().groundMaterialTextureConfig:getConfig(groundMaterialId)
    if config then
        World.cfg.groundMaterial.id = config.id
        World.cfg.groundMaterial.path = config.path
        util:setProperty(floor, "materialTexture", config.path)
    end
end

function GroundManager:getSceneFloor()
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(World.CurWorld.CurMap.obj)
    local floor = scene:getRoot():findFirstChild("floor")
    return floor
end

return GroundManager