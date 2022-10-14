--- multiple_selection_state.lua
---@type util
local util = require "common.util.util"
---@type engine_scene
local IScene = require "common.engine.engine_scene"
---@type TargetManager
local TargetManager = T(MobileEditor, "TargetManager")
---@type CommandManager
local CommandManager = T(MobileEditor, "CommandManager")
---@type GameManager
local GameManager = T(MobileEditor, "GameManager")
---@type engine_instance
local IInstance = require "common.engine.engine_instance"

local BM = Blockman.Instance()
---@class MultipleSelectionState : IGameManager
local MultipleSelectionState = {}

local function enteredState()
    --Lib.logDebug("MultipleSelectionState:enteredState")
    local targets = TargetManager:instance():getTargets()
    if #targets <= 0 then
        return
    end
    for i = 1, #targets do
        local node = GameManager:instance():getNode(targets[i])
        if node then
            node:set("materialColor", "r:0.0 g:1.0 b:0.0 a:1.0")
        end
    end
    CommandManager:instance():startFrame()
end

function MultipleSelectionState:enteredState()
    enteredState()
end

function MultipleSelectionState:exitedState()
    --Lib.logDebug("MultipleSelectionState:exitedState")
    local targets = TargetManager:instance():getTargets()
    if #targets <= 0 then
        return
    end

    for i = 1, #targets do
        local node = self:getNode(targets[i])
        if node then
            node:resetMaterialColor()
        end
    end
end

function MultipleSelectionState:touchBegin(x, y)
    self.touchBeginPos = Lib.v2(x, y)
    local result = IScene:raycast(Lib.v2(x, y), util:getRayLength(), 1 << 10, { self.floor:getId() })
    if result then
        self.touchBeginId = result.target:getInstanceID()
        --Lib.logDebug("MultipleSelectionState:touchBegin = ", IInstance:getClassName(result.target))
    else
        self.pressTime = Lib.getTime()
        self.touchBeginId = nil
        self.isTouchBegin = true
        Lib.emitEvent(Event.EVENT_START_SELECTION, Lib.v2(x, y))
    end
end

function MultipleSelectionState:touchMove(curX, curY, prevX, prevY)
    if self.isTouchMove == false then
        self.isTouchMove = true
    end

    self:panCamera(curX, curY, prevX, prevY)
end

function MultipleSelectionState:touchEnd(x, y)
    local result = IScene:raycast(Lib.v2(x, y), util:getRayLength(), 1 << 10, { self.floor:getId() })
    if result then
        self.touchEndId = result.target:getInstanceID()
        if self.isTouchMove == false and self.touchBeginId and self.touchBeginId == self.touchEndId then
            --Lib.logDebug("MultipleSelectionState:touchEnd = ", IInstance:getClassName(result.target))
            local parent = util:getRoot(result.target, self.root)
            if TargetManager:instance():containTarget(parent:getInstanceID()) then
                --- 当选中的对象已经被选中
                --Lib.logDebug("remove target from group id = ", result.target:getInstanceID())
                if parent == result.target then
                    --Lib.logDebug("remove single object")

                else
                    --Lib.logDebug("remove group")
                    Lib.emitEvent(Event.EVENT_REMOVE_GROUP, result.target:getInstanceID())
                end
            else
                if IInstance:get(parent, "name") == "birth" then
                    ---如果多选模式选中了出生点，就别进组了
                    return
                end
                ---当选中的对象之前未被选中 不管是单个对象还是对象所属的父类未被选中
                local targets = TargetManager:instance():getTargets()
                if Lib.getTableSize(targets) == 0 then
                    Lib.emitEvent(Event.EVENT_ADD_TARGET, parent:getInstanceID())
                    Lib.emitEvent(Event.EVENT_UPDATE_TARGET)
                    enteredState()
                else
                    Lib.emitEvent(Event.EVENT_ADD_GROUP, parent:getInstanceID())
                end
            end
        end
    end

    Lib.emitEvent(Event.EVENT_SET_CAMERA, BM:getViewerPos(), BM:getViewerYaw(), BM:getViewerPitch(), 0)
    self.touchBeginPos = nil
    self.touchBeginId = nil
    self.touchEndId = nil
    self.isTouchMove = false
    self.isTouchBegin = false
    self.pressTime = 0
end

return MultipleSelectionState