--- command_translate.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandTranslate : Command
local CommandTranslate = class("CommandTranslate", Command)
---@type GameManager
local GameManager = T(MobileEditor,"GameManager")

function CommandTranslate:initialize(targets, prevPos)
    Command.initialize(self, targets)
    self.prevPos = prevPos
    self.curPos = {}
    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)

    for _, object in pairs(self.objects) do
        self.curPos[object:getInstanceID()] = object:getPosition()
    end
end

function CommandTranslate:execute()

end

function CommandTranslate:undo()
    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)

    for _, object in pairs(self.objects) do
        object:setPosition(self.prevPos[object:getInstanceID()])
    end


    Lib.emitEvent(Event.EVENT_MOVE_GIZMO)
end

function CommandTranslate:redo()
    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)
    for _, object in pairs(self.objects) do
        object:setPosition(self.curPos[object:getInstanceID()])
    end

    Lib.emitEvent(Event.EVENT_MOVE_GIZMO)
end



return CommandTranslate