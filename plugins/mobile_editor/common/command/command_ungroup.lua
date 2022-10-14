--- command_ungroup.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandUngroup : Command
local CommandUngroup = class("CommandUngroup", Command)
---@type GameManager
local GameManager = T(MobileEditor,"GameManager")
---@type TargetManager
local TargetManager = T(MobileEditor,"TargetManager")


function CommandUngroup:initialize(targets)
    Command.initialize(self, targets)
    Lib.logDebug("CommandUngroup:initialize self.targets = ", self.targets)
    self.models = GameManager:instance():filter(self.targets, function(node)
        return node:isA("Model")
    end, false)

end

function CommandUngroup:execute()
    if #self.models <= 0 then
        return
    end

    for _, model in pairs(self.models) do
        local parent = model:getParent()
        if parent then
            local count = model:getChildrenCount()
            for i = 1, count do
                local index = 0
                local child = model:getChildAt(index)
                if child then
                    child:setParent(parent)
                    Lib.emitEvent(Event.EVENT_UPDATE_NODE, child:getInstanceID(), child)
                    Lib.emitEvent(Event.EVENT_ADD_TARGET, child:getInstanceID())
                end
            end
        end

        Lib.emitEvent(Event.EVENT_DELETE_NODE, model:getInstanceID())
    end

    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
end

function CommandUngroup:undo()
    Lib.logDebug("CommandUngroup:undo")

    local targets = TargetManager:instance():getTargets()
    if #targets <= 0 then
        return
    end

    local center = GameManager:instance():getCenter(targets)
    local node = GameManager:instance():createNode({class = "Model"})
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
    Lib.emitEvent(Event.EVENT_ADD_TARGET, node:getId())
    Lib.emitEvent(Event.EVENT_SELECT_TARGET)

end

function CommandUngroup:redo()
    Lib.logDebug("CommandUngroup:redo")
    local targets = TargetManager:instance():getTargets()
    if #targets <= 0 then
        return
    end

    local models = GameManager:instance():filter(targets, function(node)
        return node:isA("Model")
    end, false)


    for _, model in pairs(models) do
        local parent = model:getParent()
        if parent then
            local count = model:getChildrenCount()
            for i = 1, count do
                local index = 0
                local child = model:getChildAt(index)
                if child then
                    child:setParent(parent)
                    Lib.emitEvent(Event.EVENT_UPDATE_NODE, child:getInstanceID(), child)
                    Lib.emitEvent(Event.EVENT_ADD_TARGET, child:getInstanceID())
                end
            end
        end

        Lib.emitEvent(Event.EVENT_DELETE_NODE, model:getInstanceID())
    end

    Lib.emitEvent(Event.EVENT_SELECT_TARGET)


end


return CommandUngroup