--- input_handler.lua
local BM = Blockman.Instance()
---@type Touch
local Touch = require "common.handler.touch"
---@type util
local util = require "common.util.util"
---@class InputManager : singleton
local InputManager = T(MobileEditor, "InputManager")

function InputManager:initialize()
    Lib.logDebug("InputManager:initialize")
    self.touches = {}
    self.keyStates = {}

    local widthRatio = GUISystem:Instance():GetScreenWidth() / GUISystem:Instance():GetLogicWidth()
    local heightRatio = GUISystem:Instance():GetScreenHeight() / GUISystem:Instance():GetLogicHeight()
    self.ratio = math.max(widthRatio, heightRatio)

    self.planeNormal = Lib.v3(0, 1, 0)
    self.planePos = Lib.v3(0, 31, 0)

    self.sensitive = World.cfg.cameraZoomSensitive or 0.05
    self.minPinchDistance = 1
    self.minTurnAngle = 1
    self.minSwipeDistance = 5
    self.minSwipeDelta = 1
end

function InputManager:checkKeyState(key, state)
    if self.keyStates[key] == state then
        return false
    end

    self.keyStates[key] = state
    return true
end

function InputManager:isKeyDown(key)
    local state = BM:isKeyPressing(key)
    return self:checkKeyState(key, state) and state
end

function InputManager:getAxisValue(forward, back)
    local value = 0.0
    if BM:isKeyPressing(forward) then
        value = value + 1
    end

    if BM:isKeyPressing(back) then
        value = value - 1
    end
    return value
end

function InputManager:handleInput(input)
    if not self.enabled then
        return false
    end

    if input.type == InputType.Mouse then
        if input.subtype == MouseInputSubType.LeftDown then
            self:handleMouseBegin(input)
        elseif input.subtype == MouseInputSubType.LeftUp then
            self:handleMouseEnd(input)
        elseif input.subtype == MouseInputSubType.MouseMove then
            self:handleMouseMove(input)
        elseif input.subtype == MouseInputSubType.MouseLeave then
            self:handleMouseLeave(input)
        elseif input.subtype == MouseInputSubType.MouseWheel then
            self:handleMouseWheel(input)
        end
    elseif input.type == InputType.TouchScreen then
        if input.subtype == TouchScreenInputSubType.TouchDown then
            self:handleTouchesBegin(input)
        elseif input.subtype == TouchScreenInputSubType.TouchUp then
            self:handleTouchesEnd(input)
        elseif input.subtype == TouchScreenInputSubType.TouchMove then
            self:handleTouchesMove(input)
        elseif input.subtype == TouchScreenInputSubType.TouchCancel then
            self:handleTouchesCancel(input)
        end
    elseif input.type == InputType.KeyboardInputSubType then

    end

    return true
end

function InputManager:handleMouseBegin(input)
    --Lib.logDebug("handleMouseBegin input.position = ", input.position)
    local touches = {}
    if BM:isKeyPressing("key.forward") then
        table.insert(touches, {
            id = 0,
            position = Lib.v2(GUISystem.Instance():GetScreenWidth() * 0.5, GUISystem.Instance():GetScreenHeight() * 0.5)
        })

        table.insert(touches, {
            id = 1,
            position = input.position
        })
    else
        table.insert(touches, {
            id = 0,
            position = input.position
        })
    end

    local touchInput = {
        type = InputType.TouchScreen,
        subtype = TouchScreenInputSubType.TouchDown,
        touches = touches
    }
    self:handleTouchesBegin(touchInput)
end

function InputManager:handleMouseMove(input)
    local touches = {}
    if BM:isKeyPressing("key.forward") then
        table.insert(touches, {
            id = 0,
            position = Lib.v2(GUISystem.Instance():GetScreenWidth() * 0.5, GUISystem.Instance():GetScreenHeight() * 0.5)
        })

        table.insert(touches, {
            id = 1,
            position = input.position
        })
    else
        table.insert(touches, {
            id = 0,
            position = input.position
        })
    end

    local touchInput = {
        type = InputType.TouchScreen,
        subtype = TouchScreenInputSubType.TouchMove,
        touches = touches
    }

    self:handleTouchesMove(touchInput)
end

function InputManager:handleMouseEnd(input)
    local touches = {}
    if BM:isKeyPressing("key.forward") then
        table.insert(touches, {
            id = 0,
            position = Lib.v2(GUISystem.Instance():GetScreenWidth() * 0.5, GUISystem.Instance():GetScreenHeight() * 0.5)
        })

        table.insert(touches, {
            id = 1,
            position = input.position
        })
    else
        table.insert(touches, {
            id = 0,
            position = input.position
        })
    end

    local touchInput = {
        type = InputType.TouchScreen,
        subtype = TouchScreenInputSubType.TouchUp,
        touches = touches
    }
    self:handleTouchesEnd(touchInput)
end

function InputManager:handleMouseLeave(input)
    --Lib.logDebug("handleMouseLeave input = ", Lib.v2s(input, 7))
    local touches = {}
    if BM:isKeyPressing("key.forward") then
        table.insert(touches, {
            id = 0,
            position = Lib.v2(GUISystem.Instance():GetScreenWidth() * 0.5, GUISystem.Instance():GetScreenHeight() * 0.5)
        })

        table.insert(touches, {
            id = 1,
            position = input.position
        })
    else
        table.insert(touches, {
            id = 0,
            position = input.position
        })
    end

    local touchInput = {
        type = InputType.TouchScreen,
        subtype = TouchScreenInputSubType.TouchCancel,
        touches = touches
    }
    self:handleTouchesCancel(touchInput)
end

function InputManager:handleTouchesBegin(input)
    --Lib.logDebug("handleTouchesBegin touch count = ", Lib.getTableSize(input.touches))
    for _, t in ipairs(input.touches) do
        self.touches[t.id] = Touch:new(t.id, t.position)
    end

    if Lib.getTableSize(self.touches) == 1 then
        for _, touch in pairs(self.touches) do
            local curPosition = GUISystem.Instance():AdaptPosition(touch:getCurPos())
            local prevPosition = GUISystem.Instance():AdaptPosition(touch:getPrevPos())
            Lib.emitEvent(Event.EVENT_TOUCH_BEGIN, touch:getId(), curPosition.x, curPosition.y, prevPosition.x, prevPosition.y)
        end
    end
end

function InputManager:handleTouchesMove(input)
    if Lib.getTableSize(self.touches) == 1 then
        local deadZone = BM.gameSettings:getDeadZone()
        for _, t in ipairs(input.touches) do
            local touch = self.touches[t.id]
            if touch then
                local rawPoint = touch:getCurPos()
                if math.abs(rawPoint.x - t.position.x) < deadZone.x and math.abs(rawPoint.y - t.position.y) < deadZone.y then
                    --Lib.logDebug("in deadZone")
                else
                    touch:setPrevPos(rawPoint)
                    touch:setCurPos(t.position)
                    local curPosition = GUISystem.Instance():AdaptPosition(t.position)
                    local prevPosition = GUISystem.Instance():AdaptPosition(rawPoint)
                    Lib.emitEvent(Event.EVENT_TOUCH_MOVE, t.id, curPosition.x, curPosition.y, prevPosition.x, prevPosition.y)
                end
            end
        end
    elseif Lib.getTableSize(self.touches) >= 2 then
        local deadZone = BM.gameSettings:getDeadZone()
        for _, t in ipairs(input.touches) do
            local touch = self.touches[t.id]
            if touch then
                local rawPoint = touch:getCurPos()
                if math.abs(rawPoint.x - t.position.x) < deadZone.x and math.abs(rawPoint.y - t.position.y) < deadZone.y then
                    --Lib.logDebug("in deadZone")
                else
                    touch:setPrevPos(rawPoint)
                    touch:setCurPos(t.position)
                end
            end
        end
        self:checkGesture()
    end
end

function InputManager:handleTouchesEnd(input)
    --Lib.logDebug("handleTouchesEnd touch count = ", Lib.getTableSize(self.touches))
    if Lib.getTableSize(self.touches) == 1 then
        for _, t in ipairs(input.touches) do
            local touch = self.touches[t.id]
            if touch then
                local rawPoint = touch:getCurPos()
                local curPosition = GUISystem.Instance():AdaptPosition(t.position)
                local prevPosition = GUISystem.Instance():AdaptPosition(rawPoint)
                Lib.emitEvent(Event.EVENT_TOUCH_END, t.id, curPosition.x, curPosition.y, prevPosition.x, prevPosition.y)
                self.touches[t.id] = nil
            end
        end
    elseif Lib.getTableSize(self.touches) >= 2 then
        self.touches = {}
    end
end

function InputManager:handleTouchesCancel(input)
    if Lib.getTableSize(self.touches) == 1 then
        for _, t in ipairs(input.touches) do
            local touch = self.touches[t.id]
            if touch then
                local rawPoint = touch:getCurPos()
                local curPosition = GUISystem.Instance():AdaptPosition(t.position)
                local prevPosition = GUISystem.Instance():AdaptPosition(rawPoint)
                Lib.emitEvent(Event.EVENT_TOUCH_CANCEL, t.id, curPosition.x, curPosition.y, prevPosition.x, prevPosition.y)
                self.touches[t.id] = nil
            end
        end
    elseif Lib.getTableSize(self.touches) >= 2 then
        self.touches = {}
    end
end

function InputManager:handleMouseWheel(input)
    local delta = input.position.y * self.sensitive
    Lib.emitEvent(Event.EVENT_PINCH_CAMERA, delta)
end

function InputManager:checkGesture()
    local touchZero = self.touches[0]
    local touchOne = self.touches[1]

    local touchOneCurPos = GUISystem.Instance():AdaptPosition(touchOne:getCurPos())
    local touchOnePrePos = GUISystem.Instance():AdaptPosition(touchOne:getPrevPos())

    local touchZeroCurPos = GUISystem.Instance():AdaptPosition(touchZero:getCurPos())
    local touchZeroPrevPos = GUISystem.Instance():AdaptPosition(touchZero:getPrevPos())

    local currentDistance = (touchOneCurPos - touchZeroCurPos):len()
    local prevDistance = (touchOnePrePos - touchZeroPrevPos):len()
    local pinchDistanceDelta = currentDistance - prevDistance

    if math.abs(pinchDistanceDelta) > self.minPinchDistance * self.ratio then
        Lib.emitEvent(Event.EVENT_PINCH_CAMERA, pinchDistanceDelta)
    end

    local touchZeroCurResult = BM:getScreenIntersectPlane(touchZeroCurPos, self.planeNormal, self.planePos).intersect
    local touchOneCurResult = BM:getScreenIntersectPlane(touchOneCurPos, self.planeNormal, self.planePos).intersect
    local touchZeroPrevResult = BM:getScreenIntersectPlane(touchZeroPrevPos, self.planeNormal, self.planePos).intersect
    local touchOnePrevResult = BM:getScreenIntersectPlane(touchOnePrePos, self.planeNormal, self.planePos).intersect

    local angle = util:signedAngle(touchOneCurResult - touchZeroCurResult, touchOnePrevResult - touchZeroPrevResult, self.planeNormal)
    if math.abs(angle) > self.minTurnAngle then
        local screenCenterPos = Lib.v2(GUISystem.Instance():GetScreenWidth() * 0.5, GUISystem.Instance():GetScreenHeight() * 0.5)
        local centerResult = BM:getScreenIntersectPlane(GUISystem.Instance():AdaptPosition(screenCenterPos), self.planeNormal, self.planePos)
        Lib.emitEvent(Event.EVENT_TURN_CAMERA, centerResult.intersect, self.planeNormal, angle)
    else
        if math.abs(pinchDistanceDelta) <= self.minSwipeDistance * self.ratio then
            local touchOneDelta = touchOneCurPos - touchOnePrePos
            local touchZeroDelta = touchZeroCurPos - touchZeroPrevPos
            local opposite = util:oppositeSigns(touchOneDelta.y, touchZeroDelta.y)
            Lib.logDebug("opposite = ", opposite)
            if not util:oppositeSigns(touchOneDelta.y, touchZeroDelta.y) then
                local delta = 0
                if math.abs(touchZeroDelta.y) > math.abs(touchOneDelta.y) then
                    delta = touchZeroDelta.y
                else
                    delta = touchOneDelta.y
                end

                Lib.logDebug("start swipe delta = ", delta)
                if math.abs(delta) >= self.minSwipeDelta * self.ratio then
                    Lib.emitEvent(Event.EVENT_PITCH_CAMERA, delta * self.sensitive * 2)
                end
            end
        end
    end
end

function InputManager:tick()
    if self:isKeyDown("key.f1") and World.gameCfg.gm then
        Lib.emitEvent(Event.EVENT_SHOW_GMBOARD)
    end
end

return InputManager