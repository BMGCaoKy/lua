require "async_process"

local events = {}

function client_event(event, ...)
    local handler = events[event]
    if not handler then
        print("no handler for client_event", event)
        return
    end
    handler(...)
end

function events.http_response(session, response)
    AsyncProcess.HandleHttpResponse(session, response)
end

local fakeFirstPersonViewMode = false
local oldLockBodyRotation = false
function events.changeCameraDistance(distance)
    local cfg = World.cfg.fakeFirstPersonViewMode
    if not cfg then
        return
    end

    local keepParts = cfg.keepParts or { "custom_hand" }
    if distance <= (cfg.distance or 0.35) then
        if not fakeFirstPersonViewMode then
            fakeFirstPersonViewMode = true
            oldLockBodyRotation = Blockman.Instance().gameSettings:isLockBodyRotation()
            if not oldLockBodyRotation and not Me:isForbidRotate() then
                Blockman.Instance().gameSettings:setLockBodyRotation(true)
            end
            Me:setAlphaEx(0, keepParts)
            Blockman.instance:setFakeFirstPersonViewMode(true)
        end
    else
        if fakeFirstPersonViewMode then
            fakeFirstPersonViewMode = false
            if not oldLockBodyRotation then
                Blockman.Instance().gameSettings:setLockBodyRotation(oldLockBodyRotation)
            end
            Me:setAlphaEx(1, keepParts)
            Blockman.instance:setFakeFirstPersonViewMode(false)
        end
    end
end

function events.onSkinChanged()
    if fakeFirstPersonViewMode then
        local cfg = World.cfg.fakeFirstPersonViewMode
        if not cfg then
            return
        end

        local keepParts = cfg.keepParts or { "custom_hand" }
        Me:setAlphaEx(1, keepParts)
        Me:setAlphaEx(0, keepParts)
    end
end

function events.onCinemachineBlendResult(callbackId, success)
    T(Lib, "LuaCinemachine"):onBlendResult(callbackId, success)
end

function events.emit_event(name, ...)
    Lib.emitEvent(Event[name], ...)
end

function Client.ShowTip(tipType, textKey, keepTime, vars, regId, textArgs)
    local eventType
    tipType = tonumber(tipType)
    if tipType == 1 then
        eventType = Event.EVENT_TOP_TIPS
    elseif tipType == 2 then
        eventType = Event.EVENT_CENTER_TIPS
    elseif tipType == 3 then
        eventType = Event.EVENT_BOTTOM_TIPS
    elseif tipType == 4 then
        eventType = Event.EVENT_CHAT_MESSAGE
    elseif tipType == 5 then
        eventType = Event.EVENT_GAME_COUNTDOWN
    elseif tipType == 6 then
        eventType = Event.EVENT_GAME_TOAST_TIPS
    end
    textArgs = textArgs or {}
    local t_arg = { textKey, table.unpack(textArgs) }
    if tipType == 4 then
        Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, Lang:toText(t_arg))
    else
        Lib.emitEvent(eventType, keepTime, vars, regId, t_arg)
    end
end

--register client events
Event.EVENT_SCREEN_TOUCH_BEGIN = Event.register("EVENT_SCREEN_TOUCH_BEGIN")
Event.EVENT_SCREEN_TOUCH_MOVE = Event.register("EVENT_SCREEN_TOUCH_MOVE")
Event.EVENT_SCREEN_TOUCH_END = Event.register("EVENT_SCREEN_TOUCH_END")