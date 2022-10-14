function Client.ShowTip(tipType, textKey, keepTime, vars, regId, textArgs)
    if textKey == "game.playTime" then
        tipType = 5
        Client.ShowTip(3, "", 40)
    end
    local eventType
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
        Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, Lang:toText(t_arg), nil)
    else
        Lib.emitEvent(eventType, keepTime, vars, regId, t_arg)
    end
end
