--- edit_state.lua

---@type setting
local setting = require "common.setting"
---@type util
local util = require "common.util.util"
---@type engine_scene
local IScene = require "common.engine.engine_scene"
---@type TargetManager
local TargetManager = T(MobileEditor, "TargetManager")
---@type GizmoManager
local GizmoManager = T(MobileEditor, "GizmoManager")
local BM = Blockman.Instance()
---@class EditState : IGameManager
local EditState = {}

function EditState:enteredState()
    --Lib.logDebug("EditState:enteredState")
    Lib.emitEvent(Event.EVENT_UNLOCK_FLY_MODE)
    Lib.emitEvent(Event.EVENT_CHANGE_TOOL_BAR, "Edit")

    --[[local initPos = World.cfg.initPos
    GridRender.addEntry("drawGrid", function()
        GridRender.instance:drawGrid(Lib.v3(initPos.x + 0.5, initPos.y, initPos.z + 0.5), 16, 0xFFFFFFFF);
    end)
    GridRender.instance:setDrawGridEnabled(true)]]--
end

function EditState:exitedState()
    Lib.emitEvent(Event.EVENT_LOCK_FLY_MODE)
    self.floor = nil
    self.birth = nil
end

function EditState:touchBegin(x, y)
    self.touchBeginPos = Lib.v2(x, y)
    local result = IScene:raycast(Lib.v2(x, y), util:getRayLength(), 1 << 10, { self.floor:getId() })
    if result then
        local root = util:getRoot(result.target, self.root)
        if not root then
            Lib.logError("Edit EVENT_TOUCH_BEGIN getRoot is nil")
            return
        end

        self.touchBeginId = root:getInstanceID()
        local node = self:getNode(root:getInstanceID())
        if node and node:getCurrentState() == "Select" then
            Lib.emitEvent(Event.EVENT_START_TRANSLATE)
        end
    else
        self.pressTime = Lib.getTime()
        self.touchBeginId = nil
        self.isTouchBegin = true
        Lib.emitEvent(Event.EVENT_START_SELECTION, self.touchBeginPos)
    end
end

function EditState:touchMove(curX, curY, prevX, prevY)
    if self.isTouchMove == false then
        self.isTouchMove = true
    end

    if self.touchBeginId then
        if TargetManager:instance():containTarget(self.touchBeginId) then
            Lib.emitEvent(Event.EVENT_MOVE_TARGET, self.touchBeginId, Lib.v2(curX, curY))
        else
            self:panCamera(curX, curY, prevX, prevY)
        end
    else
        self:panCamera(curX, curY, prevX, prevY)
    end
end

function EditState:touchEnd(x, y)
    local result = IScene:raycast(Lib.v2(x, y), util:getRayLength(), 1 << 10, { self.floor:getId() })
    if result then
        --- 抬起的时候有节点
        --Lib.logDebug("touchEnd result.target id = ", result.target:getInstanceID())
        local root = util:getRoot(result.target, self.root)
        if not root then
            Lib.logError("Edit EVENT_TOUCH_END getRoot is nil")
            return
        end

        self.touchEndId = root:getInstanceID()
        --Lib.logDebug("touchEnd self.touchEndId = ", self.touchEndId)
        if self.touchBeginId and self.touchBeginId == self.touchEndId then
            local node = self:getNode(root:getInstanceID())
            if node then
                if node:getCurrentState() == "Place" then
                    if not TargetManager:instance():containTarget(root:getInstanceID()) then
                        if self.isTouchMove == false then
                            --Lib.logDebug("touchEnd add target = ", root:getInstanceID())

                            Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
                            Lib.emitEvent(Event.EVENT_RESET_TARGET)
                            Lib.emitEvent(Event.EVENT_ADD_TARGET, root:getInstanceID())
                            Lib.emitEvent(Event.EVENT_SELECT_TARGET)
                        end
                    else
                        Lib.emitEvent(Event.EVENT_FINISH_TRANSLATE)
                        Lib.emitEvent(Event.EVENT_SELECT_TARGET)
                    end
                elseif node:getCurrentState() == "Select" then
                    if self.isTouchMove == false then
                        Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
                        Lib.emitEvent(Event.EVENT_RESET_TARGET)
                    else
                        Lib.emitEvent(Event.EVENT_FINISH_TRANSLATE)
                        Lib.emitEvent(Event.EVENT_SELECT_TARGET)
                    end
                end
            else
                --Lib.logDebug("touchEnd node is nil = ", root:getInstanceID())
            end
        end
    else
        --- 抬起的时候没有节点
        if self.touchBeginId then
            --- 当零件或者模型非常小 在移动以后射线检测没有命中，这个时候要主动打开物体的选中状态
            if self.isTouchMove == true then
                if TargetManager:instance():containTarget(self.touchBeginId) then
                    Lib.emitEvent(Event.EVENT_FINISH_TRANSLATE)
                    Lib.emitEvent(Event.EVENT_SELECT_TARGET)
                else
                    Lib.emitEvent(Event.EVENT_SET_CAMERA, BM:getViewerPos(), BM:getViewerYaw(), BM:getViewerPitch(), 0)
                end
            end
        else
            if self.isTouchMove == false then
                Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
                Lib.emitEvent(Event.EVENT_RESET_TARGET)
                self.clickCount = self.clickCount + 1
                if self.clickCount == 1 then
                    self.clickTime = Lib.getTime()
                end
                local curTime = Lib.getTime()
                local diff = curTime - self.clickTime
                --Lib.logDebug("double click clickCount and diff = ", self.clickCount, diff)
                if self.clickCount > 1 and diff < self.clickDelay * 1000 then
                    self.clickCount = 0
                    self.clickTime = 0
                    local targetResult = BM:getScreenIntersectPlane(self.touchBeginPos, Lib.v3(0, 1, 0), Lib.v3(0, 31, 0))
                    Lib.emitEvent(Event.EVENT_SET_FOCUS, targetResult.intersect)
                elseif self.clickCount > 2 or diff >= 1.5 * 1000 then
                    self.clickCount = 0
                end

            else
                Lib.emitEvent(Event.EVENT_SET_CAMERA, BM:getViewerPos(), BM:getViewerYaw(), BM:getViewerPitch(), 0)
            end
        end
    end

    self.touchBeginPos = nil
    self.touchBeginId = nil
    self.touchEndId = nil
    self.isTouchMove = false
    self.isTouchBegin = false
    self.pressTime = 0
    --Blockman.Instance().gameSettings:setLockSlideScreen(false)
end

return EditState