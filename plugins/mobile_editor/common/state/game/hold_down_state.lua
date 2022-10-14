--- hold_down_state.lua
---@type util
local util = require "common.util.util"
---@type engine_scene
local IScene = require "common.engine.engine_scene"
---@class HoldDownState : IGameManager
local HoldDownState = {}

function HoldDownState:enteredState()
    --Lib.logDebug("HoldDownState:enteredState")
    Lib.emitEvent(Event.EVENT_SHOW_NOTIFICATION, Lang:toText("ui.enter.rect"))
end

function HoldDownState:exitedState(pos)
    --Lib.logDebug("HoldDownState:exitedState")
    Lib.emitEvent(Event.EVENT_SHOW_NOTIFICATION, Lang:toText("ui.exit.rect"))
    Lib.emitEvent(Event.EVENT_END_SELECTION, pos)
    self.isTouchBegin = false
    self.isTouchMove = false
    self.touchBeginId = nil
    self.touchEndId = nil
    self.touchBeginPos = nil
    --Blockman.Instance().gameSettings:setLockSlideScreen(false)
    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
    self.selectedNodes = nil
end

function HoldDownState:touchMove(x, y)
    if self.selectedNodes then
        Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
        Lib.emitEvent(Event.EVENT_RESET_TARGET)
    end

    --Blockman.Instance().gameSettings:setLockSlideScreen(true)
    Lib.emitEvent(Event.EVENT_UPDATE_SELECTION, Lib.v2(x, y))
    local dx, dy = util:logicPosToScreenPos(x, y)
    local sx, sy = util:logicPosToScreenPos(self.touchBeginPos.x, self.touchBeginPos.y)
    local rect = {
        left = math.min(sx, dx),
        top = math.min(sy, dy),
        right = math.max(sx, dx),
        bottom = math.max(sy, dy)
    }
    self.selectedNodes = IScene:pick_rect(rect, 1 << 3)
    for _, node in pairs(self.selectedNodes) do
        local root = util:getRoot(node, self.root)
        if root then
            local id = root:getInstanceID()
            if id ~= self.floor:getId() then
                Lib.emitEvent(Event.EVENT_ADD_TARGET, root:getInstanceID())
            end
        end
    end
    Lib.emitEvent(Event.EVENT_CHANGE_TARGET_STATE, "Select")
end

function HoldDownState:touchEnd(x, y)
    self:popState("HoldDown", Lib.v2(x, y))
end

return HoldDownState