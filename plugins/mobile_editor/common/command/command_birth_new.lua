--- command_new.lua

local class = require "common.3rd.middleclass.middleclass"
---@type CommandNew
local CommandNew = require "common.command.command_new"
---@class CommandBirthNew : CommandNew
local CommandBirthNew = class("CommandBirthNew", CommandNew)
---@type GameManager
local GameManager = T(MobileEditor, "GameManager")
---@type Vector3[]
local LastBirthPosList = {}

function CommandBirthNew:initialize(targets, config, snapPos, normal, modCfgId)
    CommandNew.initialize(self, targets, config, snapPos, normal, modCfgId)
end

function CommandBirthNew:execute()
    local curBirthNode = GameManager:instance():getNode(GameManager:instance():getBirthId())
    if curBirthNode then
        table.insert(LastBirthPosList, curBirthNode:getPosition())
        Lib.emitEvent(Event.EVENT_DELETE_NODE, curBirthNode:getId())
    end
    local node = CommandNew.execute(self)
    if node then
        GameManager:instance():setBirthId(node:getId())
    end
end

function CommandBirthNew:undo()
    self.createId = GameManager:instance():getBirthId()
    CommandNew.undo(self)
    if #LastBirthPosList == 0 then
        return
    end
    local lastBirthPos = table.remove(LastBirthPosList)
    if lastBirthPos then
        Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
        Lib.emitEvent(Event.EVENT_RESET_TARGET)
        local node = GameManager:instance():createNode(self.config)
        node:setPosition(lastBirthPos)
        GameManager:instance():setBirthId(node:getId())
        Lib.emitEvent(Event.EVENT_ADD_TARGET, GameManager:instance():getBirthId())
        if GameManager:instance():getCurrentState() ~= "Create" then
            Lib.emitEvent(Event.EVENT_SELECT_TARGET)
        end
    end
end

function CommandBirthNew:redo()
    local curBirthNode = GameManager:instance():getNode(GameManager:instance():getBirthId())
    if curBirthNode then
        table.insert(LastBirthPosList, curBirthNode:getPosition())
        Lib.emitEvent(Event.EVENT_DELETE_NODE, curBirthNode:getId())
    end
    local node = CommandNew.redo(self)
    if node then
        GameManager:instance():setBirthId(node:getId())
        self.createId = GameManager:instance():getBirthId()
    end
end

return CommandBirthNew