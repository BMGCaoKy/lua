--- data_manager.lua
--- 数据的管理器
---
---@class DataManager : singleton
local DataManager = T(MobileEditor, "DataManager")
---@type ConfigManager
local ConfigManager = T(MobileEditor, "ConfigManager")
---@type SkyboxManager
local SkyboxManager = T(MobileEditor, "SkyboxManager")
---@type engine_instance
local IInstance = require "common.engine.engine_instance"
---@type util
local util = require "common.util.util"
---@type setting
local setting = require "common.setting"

function DataManager:initialize()
    self:subscribeEvents()
end

function DataManager:finalize()

end

function DataManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_SAVE_ENVIRONMENT_DATA, function()
        if not World.cfg.needSave then
            return
        end
        local envData = {
            weather = World.cfg.weather,
            dirLightAmbient = World.cfg.dirLightAmbient,
            dirLightDiffuse = World.cfg.dirLightDiffuse,
            ambientStrength = World.cfg.ambientStrength,
            lightDirect = World.cfg.lightDirect,
            lightAngle = World.cfg.lightAngle,
            bgm = World.cfg.bgm,
            groundColor = World.cfg.groundColor,
            groundMaterial = World.cfg.groundMaterial,
        }
        util:updateSettings(envData)

        local skyboxConfig = ConfigManager:instance().skyboxConfig:getConfig(SkyboxManager:instance().skyboxId)
        if skyboxConfig then
            local SkyboxCfg = setting:mod("sky")
            local cfg = SkyboxCfg:get("myplugin/" .. skyboxConfig.cfgName)

            local filePath = "map/" .. "map001" .. "/setting.json"
            local obj = Lib.readGameJson(filePath)
            local data = {
                id = skyboxConfig.id,
                texture = cfg.texture,
                time = cfg.time,
                transition = cfg.transition,
                heightOffset = cfg.heightOffset,
                skyBoxRotate = cfg.skyBoxRotate,
                skyBoxTexPixFmt = cfg.skyBoxTexPixFmt,
                skyBoxTexSize = cfg.skyBoxTexSize
            }
            local skyTable = {}
            table.insert(skyTable, data)
            obj.skyBox = skyTable
            obj.skyBoxRotate = cfg.skyBoxRotate
            obj.editorSkyBox = skyTable
            Lib.logDebug("obj.skyBox = ", obj.skyBox)
            Lib.saveGameJson(filePath, obj)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_SAVE_MAP_CHANGE, function()
        if World.cfg.needSave == true then
            local filePath = "map/map001/setting.json"
            local obj = Lib.readGameJson(filePath)
            local manager = World.CurWorld:getSceneManager()
            local scene = manager:getCurScene()
            local partsNum = 0
            local modelNum = 0
            local configs = {}
            local count = scene:getRoot():getChildrenCount()
            for i = 1, count do
                local object = scene:getRoot():getChildAt(i - 1)
                if object and object:isValid() then
                    local className = IInstance:getClassName(object)
                    if className then
                        local config = util:getAllChildrenAsTable(object)
                        if className == "Model" then
                            modelNum = modelNum + 1
                        elseif className == "Part" or className == "PartOperation" then
                            partsNum = partsNum + 1
                        elseif className == "MeshPart" then
                            modelNum = modelNum + 1
                            if config.properties.name == "birth" then
                                local initPos = Lib.deserializerStrV3(config.properties.position)
                                util:updateSetting("initPos", initPos)
                            end
                        end
                        table.insert(configs, config)
                    end
                end
            end
            Lib.logDebug("partsNum and modelNum = ", partsNum, modelNum)
            obj.scene = configs
            Lib.saveGameJson(filePath, obj)
            self:saveEditRecord(partsNum, modelNum)
        end
        Lib.emitEvent(Event.EVENT_SAVE_ENVIRONMENT_DATA)
        Lib.emitEvent(Event.EVENT_SAVE_MAP_FINISH)
    end)
end

function DataManager:saveEditRecord(partsNum, modelNum)
    local dir = Root.Instance():getGamePath() .. "editRecord"
    Lib.mkPath(dir)
    local path = dir .. "/changed.json"
    local data = {
        parts_number = partsNum,
        model_number = modelNum,
    }
    util:saveFile(path, data)
end

return DataManager
