--- command_add_group.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandAddGroup : Command
local CommandAddGroup = class("CommandAddGroup", Command)
---@type GameManager
local GameManager = T(MobileEditor, "GameManager")
---@type util
local util = require "common.util.util"

function CommandAddGroup:initialize(targets, id)
    Command.initialize(self, targets)
    self.addId = id
    self.createId = nil
end

function CommandAddGroup:execute()
    local targets = Lib.copy(self.targets)
    table.insert(targets, self.addId)

    local center = GameManager:instance():getCenter(targets)
    local model = GameManager:instance():createNode({ class = "Model" })
    model:setPosition(center)
    self.createId = model:getId()
    --Lib.logDebug("CommandAddGroup:execute self.createId = ", self.createId)
    for i = 1, #targets do
        local node = GameManager:instance():getNode(targets[i])
        if node then
            node:setParent(model:getObject())
            node:gotoState('Place')
            Lib.emitEvent(Event.EVENT_UPDATE_NODE, node:getId(), nil)
            if self.addId == node:getId() then
                node:set("materialColor", "r:0.0 g:1.0 b:0.0 a:1.0")
            end
        end
    end

    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)
    Lib.emitEvent(Event.EVENT_ADD_TARGET, self.createId)
    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
end

function CommandAddGroup:undo()
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)
    local model = Instance.getByInstanceId(self.createId)
    if model then
        local parent = model:getParent()
        if parent then
            local count = model:getChildrenCount()
            for i = 1, count do
                local child = model:getChildAt(i - 1)
                if child then
                    if child:getInstanceID() == self.addId then
                        child:setParent(parent)
                        Lib.emitEvent(Event.EVENT_UPDATE_NODE, self.addId, child, true)
                        break
                    end
                end
            end

            for i = 1, #self.targets do
                local id = self.targets[i]
                local object = Instance.getByInstanceId(id)
                if object then
                    object:setParent(parent)
                    Lib.emitEvent(Event.EVENT_UPDATE_NODE, id, object)
                    Lib.emitEvent(Event.EVENT_ADD_TARGET, id)
                else
                    Lib.logError("CommandAddGroup:undo not found id = ", id)
                end
            end

            Lib.emitEvent(Event.EVENT_DELETE_NODE, self.createId)
            Lib.emitEvent(Event.EVENT_REMOVE_TARGET, self.createId)
            Lib.emitEvent(Event.EVENT_SELECT_TARGET)
        end
    else
        Lib.logError("CommandAddGroup:undo self.createId is nil = ", self.createId)
    end

end

function CommandAddGroup:redo()
    local targets = Lib.copy(self.targets)
    table.insert(targets, self.addId)

    local center = GameManager:instance():getCenter(targets)
    local config = {}
    config.class = "Model"
    config.properties = {}
    config.properties.id = self.createId

    local node = GameManager:instance():createNode(config)
    node:setPosition(center)
    for i = 1, #targets do
        local child = GameManager:instance():getNode(targets[i])
        if child then
            child:setParent(node:getObject())
            child:gotoState('Place')
            Lib.emitEvent(Event.EVENT_UPDATE_NODE, child:getId(), nil)
        end
    end

    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)
    Lib.emitEvent(Event.EVENT_ADD_TARGET, self.createId)
    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
end

return CommandAddGroup