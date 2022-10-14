--- command_remove_group.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandRemoveGroup : Command
local CommandRemoveGroup = class("CommandRemoveGroup", Command)
---@type GameManager
local GameManager = T(MobileEditor, "GameManager")
---@type util
local util = require "common.util.util"
function CommandRemoveGroup:initialize(targets, id)
    Command.initialize(self, targets)
    self.removeId = id
    self.createId = nil
    self.childId = nil
end

function CommandRemoveGroup:execute()
    local object = Instance.getByInstanceId(self.removeId)
    if not object then
        return
    end
    local parent = object:getParent()
    if not parent then
        return
    end
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getCurScene()
    local sceneRoot = scene:getRoot()
    local grandParent = parent:getParent()
    if grandParent then
        object:setParent(sceneRoot)
        Lib.emitEvent(Event.EVENT_UPDATE_NODE, self.removeId, object, true)

        local count = parent:getChildrenCount()
        if count == 1 then
            local child = parent:getChildAt(0)
            if child then
                self.createId = parent:getInstanceID()
                self.childId = child:getInstanceID()
                child:setParent(grandParent)
                if grandParent == sceneRoot then
                    Lib.emitEvent(Event.EVENT_UPDATE_NODE, self.childId, child)
                    Lib.emitEvent(Event.EVENT_ADD_TARGET, self.childId)

                    Lib.emitEvent(Event.EVENT_DELETE_NODE, self.createId)
                    Lib.emitEvent(Event.EVENT_REMOVE_TARGET, self.createId)
                else
                    Lib.emitEvent(Event.EVENT_UPDATE_NODE, self.createId, nil)
                    parent:destroy()
                end
            end
        else
            self.childId = self.removeId
            self.createId = parent:getInstanceID()
        end

        Lib.emitEvent(Event.EVENT_SELECT_TARGET)
    end
end

function CommandRemoveGroup:undo()
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)

    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getCurScene()
    local sceneRoot = scene:getRoot()

    local child = Instance.getByInstanceId(self.childId)
    if child then
        local parent = child:getParent()
        if parent then
            local targets = {}
            if self.removeId ~= self.childId then
                table.insert(targets, self.removeId)
            end
            table.insert(targets, self.childId)
            local config = {}
            config.class = "Model"
            config.properties = {}
            config.properties.id = self.createId
            local model = GameManager:instance():createNode(config)
            local center = GameManager:instance():getCenter(targets)
            model:setPosition(center)
            for i = 1, #targets do
                local object = Instance.getByInstanceId(targets[i])
                if object then
                    object:setParent(model:getObject())
                end
            end

            model:setParent(parent)

            if parent == sceneRoot then
                Lib.emitEvent(Event.EVENT_UPDATE_NODE, self.childId, nil)
                Lib.emitEvent(Event.EVENT_UPDATE_NODE, self.createId, model:getObject(), true)
                Lib.emitEvent(Event.EVENT_ADD_TARGET, self.createId)
            else
                for i = 1, #self.targets do
                    Lib.emitEvent(Event.EVENT_ADD_TARGET, self.targets[i])
                end
            end

            Lib.emitEvent(Event.EVENT_SELECT_TARGET)
        end
    end
end

function CommandRemoveGroup:redo()
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)

    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getCurScene()
    local sceneRoot = scene:getRoot()

    local object = Instance.getByInstanceId(self.removeId)
    if object then
        local parent = object:getParent()
        if parent then
            local grandParent = parent:getParent()
            if grandParent then
                object:setParent(sceneRoot)
                Lib.emitEvent(Event.EVENT_UPDATE_NODE, self.removeId, object)

                local count = parent:getChildrenCount()
                if count == 1 then
                    local child = parent:getChildAt(0)
                    if child then
                        child:setParent(grandParent)
                        if grandParent == sceneRoot then
                            Lib.emitEvent(Event.EVENT_UPDATE_NODE, self.childId, child)
                            Lib.emitEvent(Event.EVENT_ADD_TARGET, self.childId)
                            Lib.emitEvent(Event.EVENT_DELETE_NODE, self.createId)
                            Lib.emitEvent(Event.EVENT_REMOVE_TARGET, self.createId)
                        else
                            parent:destroy()
                            local root = util:getRoot(child, sceneRoot)
                            Lib.emitEvent(Event.EVENT_ADD_TARGET, root:getInstanceID())
                        end
                    end
                end

                Lib.emitEvent(Event.EVENT_SELECT_TARGET)
            end
        end
    end

end

return CommandRemoveGroup