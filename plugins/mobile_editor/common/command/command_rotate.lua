--- command_rotate.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandRotate : Command
local CommandRotate = class("CommandRotate", Command)
---@type engine_scene
local IScene = require "common.engine.engine_scene"
---@type GameManager
local GameManager = T(MobileEditor,"GameManager")
---@type util
local util = require "common.util.util"

function CommandRotate:initialize(targets, prevAxis, prevDegree, interval)
    Command.initialize(self, targets)
    self.prevAxis = prevAxis
    self.prevDegree = prevDegree
    self.interval = interval
    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)

end

function CommandRotate:execute()
    for _, object in pairs(self.objects) do
        local prevRotation = object:getRotation()
        local curRotation = util:snap(prevRotation, self.interval)
        object:setRotation(curRotation)
    end
end

function CommandRotate:undo()
    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)
    IScene:rotate_parts(self.objects, self.prevAxis, -self.prevDegree)

    for _, object in pairs(self.objects) do
        local prevRotation = object:getRotation()
        local curRotation = util:snap(prevRotation, self.interval)
        object:setRotation(curRotation)
    end
    Lib.emitEvent(Event.EVENT_ROTATE_GIZMO)

end

function CommandRotate:redo()
    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)
    IScene:rotate_parts(self.objects, self.prevAxis, self.prevDegree)
    for _, object in pairs(self.objects) do
        local prevRotation = object:getRotation()
        local curRotation = util:snap(prevRotation, self.interval)
        object:setRotation(curRotation)
    end
    Lib.emitEvent(Event.EVENT_ROTATE_GIZMO)
end



return CommandRotate