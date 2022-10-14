--- capture_screen_state.lua
local BM = Blockman.Instance()
---@class CaptureScreenState : IGameManager
local CaptureScreenState = {}

function CaptureScreenState:enteredState()
    Lib.emitEvent(Event.EVENT_CLOSE_MAIN)
    Lib.emitEvent(Event.EVENT_CLOSE_SETTING)
    Lib.emitEvent(Event.EVENT_OPEN_SCREENSHOT)
end
function CaptureScreenState:exitedState()
    Lib.emitEvent(Event.EVENT_CLOSE_SCREENSHOT)
    Lib.emitEvent(Event.EVENT_OPEN_MAIN)
end

function CaptureScreenState:touchBegin(x, y)
    self.touchBeginPos = Lib.v2(x, y)
    self.isTouchBegin = true
end

function CaptureScreenState:touchMove(curX, curY, prevX, prevY)
    if self.isTouchMove == false then
        self.isTouchMove = true
    end

    self:panCamera(curX, curY, prevX, prevY)
end

function CaptureScreenState:touchEnd(x, y)
    if self.isTouchMove == false then
        self.clickCount = self.clickCount + 1
        if self.clickCount == 1 then
            self.clickTime = Lib.getTime()
        end
        local curTime = Lib.getTime()
        local diff = curTime - self.clickTime
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

    self.touchBeginPos = nil
    self.isTouchMove = false
    self.isTouchBegin = false
end

return CaptureScreenState