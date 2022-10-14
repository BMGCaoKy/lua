--- command_delete.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandDelete : Command
local CommandDelete = class("CommandDelete", Command)
---@type GameManager
local GameManager = T(MobileEditor,"GameManager")
---@type engine_instance
local IInstance = require "common.engine.engine_instance"
---@type util
local util = require "common.util.util"

function CommandDelete:initialize(targets)
    Command.initialize(self, targets)
    self.configs = nil
    self.objects = {}
end

function CommandDelete:parseConfigs()
    local configs = {}
    for i = 1, #self.targets do
        local id = self.targets[i]
        local node = GameManager:instance():getNode(id)
        if node then
            local object = node:getObject()
            if object and object:isValid() then
                local config = util:getAllChildrenAsTable(object)
                table.insert(configs, config)
            end
        end
    end

    return configs
end

function CommandDelete:execute()
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)
    self.configs = self:parseConfigs()


    for i = 1, #self.targets do
        Lib.logDebug("CommandDelete:execute id = ", self.targets[i])
        Lib.emitEvent(Event.EVENT_DELETE_NODE, self.targets[i])
    end
end

function CommandDelete:undo()
    for index, config in pairs(self.configs) do
        local node = GameManager:instance():createNode(config)
        if node then
            local id = node:getId()
            Lib.emitEvent(Event.EVENT_ADD_TARGET, id)
            Lib.logDebug("CommandDelete:undo create node id = ", id)
        end
    end

    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
end

function CommandDelete:redo()
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)
    for i = 1, #self.targets do
        Lib.logDebug("CommandDelete:redo id = ", self.targets[i])
        Lib.emitEvent(Event.EVENT_DELETE_NODE, self.targets[i])
    end
end



return CommandDelete