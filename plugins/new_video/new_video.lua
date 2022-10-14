
require "common.event_new_video"
require "common.config.video_effect_config"
require "common.new_video_define"

if World.isClient then
    require "client.gm_new_video"
    require "client.new_video_helper"
    local Recorder = T(Lib, "Recorder")
    Recorder:LoadConfigFromJson()
end

local handlers = {}

if World.isClient then
    --- @type NewVideoHelper
    local NewVideoHelper = T(Lib, "NewVideoHelper")

    Lib.subscribeEvent(Event.EVENT_APP_VIDEO_RECORD_RESULT, function(state)
        NewVideoHelper:recordEndCallback(state)
    end)

    Lib.subscribeEvent(Event.EVENT_GAME_PAUSE, function()
        NewVideoHelper:stopNewVideoRecord()
    end)

    Lib.lightSubscribeEvent("error!!!!! : new_video event : EVENT_PLAYER_LOGOUT", Event.EVENT_PLAYER_LOGOUT, function(player)
        if player.userId == Me.platformUserId then
            NewVideoHelper:stopNewVideoRecord()
        end
    end)

    function handlers.updateNewVideoShow(isShow)
        if World.cfg.useNewUI then
            if isShow then
                UI:openWindow("UI/new_video/gui/win_video_mode")
            else
                UI:closeWindow("UI/new_video/gui/win_video_mode")
            end
        else
            if isShow then
                UI:openWnd("videoMode")
            else
                UI:closeWnd("videoMode")
            end
        end
    end

    function handlers.recordEndCallback(result)
        NewVideoHelper:recordEndCallback(result)
    end
end

return function(name, ...)
    if type(handlers[name]) ~= "function" then
        return
    end
    return handlers[name](...)
end