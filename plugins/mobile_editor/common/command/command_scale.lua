--- command_scale.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandScale : Command
local CommandScale = class("CommandScale", Command)
---@type PartTransformHelper
local PartTransformHelper = require "common.helper.part_transform_helper"
---@type GameManager
local GameManager = T(MobileEditor,"GameManager")

function CommandScale:initialize(targets, prevAxis, prevOffset, prevStretch)
    Command.initialize(self, targets)
    self.prevAxis = prevAxis
    self.prevOffset = prevOffset
    self.prevStretch = prevStretch

    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)
end

function CommandScale:execute()

end

function CommandScale:undo()

    local stretch = true
    if self.prevStretch == 1 then
        stretch = false
    else
        stretch = true
    end

    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)

    PartTransformHelper.getScale(self.objects, self.prevAxis, -self.prevOffset, stretch)
    Lib.emitEvent(Event.EVENT_SCALE_GIZMO)
end

function CommandScale:redo()
    local stretch = true
    if self.prevStretch == 1 then
        stretch = true
    else
        stretch = false
    end

    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)
    PartTransformHelper.getScale(self.objects, self.prevAxis, self.prevOffset, stretch)
    Lib.emitEvent(Event.EVENT_SCALE_GIZMO)
end


return CommandScale