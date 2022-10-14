--- command_new.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandNew : Command
local CommandNew = class("CommandNew", Command)
---@type GameManager
local GameManager = T(MobileEditor, "GameManager")
---@type util
local util = require "common.util.util"
---@type ConfigManager
local ConfigManager = T(MobileEditor, "ConfigManager")
---@type TargetManager
local TargetManager = T(MobileEditor, "TargetManager")

function CommandNew:initialize(targets, config, snapPos, normal, modCfgId, colorId, textureId)
    Command.initialize(self, targets)
    self.config = Lib.copy(config)

    self.snapPos = snapPos
    self.normal = normal
    self.modCfgId = modCfgId
    self.createId = nil
    self.colorId = colorId
    self.textureId = textureId
end

local function setColorAndTexture(self)
    local targets = TargetManager:instance():getTargets()
    local data = ConfigManager:instance().materialColorConfig:getConfig(self.colorId)
    if data then
        local color = string.format("r:%s g:%s b:%s", data.rgba.r / 255, data.rgba.g / 255, data.rgba.b / 255)
        for i = 1, #targets do
            local node = GameManager:instance():getNode(targets[i])
            if node then
                node:setMaterialColor(color)
                node:setMaterialTextureIndex(self.textureId)
            end
        end
    end
end

function CommandNew:execute()
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_SELECT_VIEW)
    local node = GameManager:instance():createNode(self.config)
    if node then
        self.createId = node:getId()
        self.pos = util:getPlacePos(self.snapPos, self.normal, node:getSize())
        node:setPosition(self.pos)
        node:setModCfgId(self.modCfgId)
        Lib.emitEvent(Event.EVENT_ADD_TARGET, node:getId())
        if GameManager:instance():getCurrentState() ~= "Create" then
            Lib.emitEvent(Event.EVENT_SELECT_TARGET)
        end
        node:getObject():connect("on_downloaded", function()
            self.pos = util:getPlacePos(self.snapPos, self.normal, node:getSize())
            node:setPosition(self.pos)
        end)
        setColorAndTexture(self)
    end
    return node
end

function CommandNew:update(params)
    --Lib.logDebug("CommandNew:update params = ", params)
    if params then
        if params.pos then
            self.pos = params.pos
        end

        if params.cfg then
            self.config = params.cfg
        end

    end
end

function CommandNew:undo()
    Lib.logDebug("CommandNew:undo self.createId = ", self.createId)
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)
    Lib.emitEvent(Event.EVENT_DELETE_NODE, self.createId)
end

function CommandNew:redo()
    Lib.logDebug("CommandNew:redo")
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)

    self.config.properties.id = self.createId
    local node = GameManager:instance():createNode(self.config)
    if node then
        node:setPosition(self.pos)
        node:setModCfgId(self.modCfgId)
        Lib.emitEvent(Event.EVENT_ADD_TARGET, self.createId)

        if GameManager:instance():getCurrentState() ~= "Create" then
            Lib.emitEvent(Event.EVENT_SELECT_TARGET)
        end
        setColorAndTexture(self)
    end
    return node
end

return CommandNew