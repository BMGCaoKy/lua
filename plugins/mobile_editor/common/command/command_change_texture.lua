--- command_change_texture.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandChangeTexture : Command
local CommandChangeTexture = class("CommandChangeTexture", Command)
---@type GameManager
local GameManager = T(MobileEditor,"GameManager")
---@type ConfigManager
local ConfigManager = T(MobileEditor,"ConfigManager")
---@type util
local util = require "common.util.util"
---@type engine_instance
local IInstance = require "common.engine.engine_instance"

function CommandChangeTexture:initialize(targets, curTextureIndex)
    Command.initialize(self, targets)
    self.curTextureIndex = curTextureIndex
    self.prevTextureIndex = {}

    for i = 1, #self.targets do
        local id = self.targets[i]
        local node = GameManager:instance():getNode(id)
        if node then
            if node:isA("Model") then
                self.prevTextureIndex = node:getMaterialTextureIndex()
            else
                self.prevTextureIndex[id] = node:getMaterialTextureIndex()
            end
        end
    end
end

function CommandChangeTexture:execute()
    for i = 1, #self.targets do
        local node = GameManager:instance():getNode(self.targets[i])
        if node then
            node:setMaterialTextureIndex(self.curTextureIndex)
        end
    end
end

function CommandChangeTexture:undo()
    for i = 1, #self.targets do
        local id = self.targets[i]
        local node = GameManager:instance():getNode(id)
        if node then
            if node:isA("Model") then
                local textures = {}
                for id, textureIndex in pairs(self.prevTextureIndex) do
                    local object = Instance.getByInstanceId(id)
                    if object then
                        local data = ConfigManager:instance().materialTextureConfig:getConfig(textureIndex)
                        if data then
                            util:setAttribute(object, "textureIndex", textureIndex)
                            IInstance:set(object, "materialTexture", data.path)
                            if data.attribute == Define.MATERIAL_ATTRIBUTE.WATER then
                                IInstance:set(object, "name", "swimming_area")
                                IInstance:set(object,"materialAlpha", "0.43")
                                IInstance:set(object,"restitution", "0.3")
                                IInstance:set(object,"useCollide", "false")
                            elseif data.attribute == Define.MATERIAL_ATTRIBUTE.GLASS then
                                IInstance:set(object,"name", "")
                                IInstance:set(object,"materialAlpha", "0.5")
                                IInstance:set(object,"restitution", "0.0")
                                IInstance:set(object,"useCollide", "true")
                            else
                                IInstance:set(object,"name", "")
                                IInstance:set(object,"materialAlpha", "1.0")
                                IInstance:set(object,"restitution", "0.0")
                                IInstance:set(object,"useCollide", "true")
                            end

                            table.insert(textures, textureIndex)
                        end
                    end
                end

                if Lib.getTableSize(textures) > 1 then
                    if textures[1] == textures[2] then
                        Lib.emitEvent(Event.EVENT_UPDATE_MATERIAL_TEXTURE, textures[1])
                    else
                        Lib.emitEvent(Event.EVENT_UPDATE_MATERIAL_TEXTURE, -1)
                    end
                end
            else
                node:setMaterialTextureIndex(self.prevTextureIndex[id])
                Lib.emitEvent(Event.EVENT_UPDATE_MATERIAL_TEXTURE, self.prevTextureIndex[id])
            end
        end
    end


end

function CommandChangeTexture:redo()

    for i = 1, #self.targets do
        local id = self.targets[i]
        local node = GameManager:instance():getNode(id)
        if node then
            node:setMaterialTextureIndex(self.curTextureIndex)
        end
    end

    Lib.emitEvent(Event.EVENT_UPDATE_MATERIAL_TEXTURE, self.curTextureIndex)

end



return CommandChangeTexture