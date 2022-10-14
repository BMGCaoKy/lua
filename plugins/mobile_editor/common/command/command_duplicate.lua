--- command_duplicate.lua
local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandDuplicate : Command
local CommandDuplicate = class("CommandDuplicate", Command)
---@type engine_instance
local IInstance = require "common.engine.engine_instance"
---@type GameManager
local GameManager = T(MobileEditor,"GameManager")
---@type TargetManager
local TargetManager = T(MobileEditor,"TargetManager")
---@type util
local util = require "common.util.util"

function CommandDuplicate:initialize(targets)
    Command.initialize(self, targets)
    self.configs = {}
end

function CommandDuplicate:parseConfigs()

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

function CommandDuplicate:execute()

    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)

    local configs = self:parseConfigs()

    for _, config in pairs(configs) do
        util:parseInstanceId(config)

        local node = GameManager:instance():createNode(config)
        if node then
            local id = node:getId()
            Lib.emitEvent(Event.EVENT_ADD_TARGET, id)
            self.configs[id] = config

        end
    end
    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
end

function CommandDuplicate:undo()

    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)

    for id, config in pairs(self.configs) do
        Lib.emitEvent(Event.EVENT_DELETE_NODE, id)
        Lib.emitEvent(Event.EVENT_REMOVE_TARGET, id)
    end


    for i = 1, #self.targets do
        Lib.emitEvent(Event.EVENT_ADD_TARGET, self.targets[i])
    end

    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
end

function CommandDuplicate:redo()
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)

    for id, config in pairs(self.configs) do
        local node = GameManager:instance():createNode(config)
        if node then
            Lib.emitEvent(Event.EVENT_ADD_TARGET, id)
        end
    end

    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
end

return CommandDuplicate