---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2022/3/29 14:43
---
---@class SoundUtil
local SoundUtil = T(MobileEditor, "SoundUtil")

function SoundUtil.clickUI()
    Lib.emitEvent(Event.EVENT_PLAY_SOUND, "plugin/myplugin/sound/g2052_ui_click.mp3", false, 1.0)
end

function SoundUtil.closeUI()
    Lib.emitEvent(Event.EVENT_PLAY_SOUND, "plugin/myplugin/sound/g2052_ui_close.mp3", false, 1.0)
end