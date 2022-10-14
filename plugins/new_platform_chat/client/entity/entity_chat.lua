local Entity = Entity
if World.cfg.chatSetting and World.cfg.chatSetting.familyIcon then
    Entity.ValueFunc[World.cfg.chatSetting.familyVal] = function(self,value)
        Lib.emitEvent(Event.EVENT_FAMILY_ICON_CHANGE, value)
    end
end

function Entity.ValueFunc:soundTimes(value)
    if not self:getSoundMoonCardEnable() then
        Lib.emitEvent(Event.EVENT_SOUND_TIME_CHANGE, value)
    end
end
function Entity.ValueFunc:soundMoonCard(value)
    Lib.emitEvent(Event.EVENT_SOUND_MOON_CHANGE, value)
end

function Entity.ValueFunc:freeSoundTimes(value)
    if not self:getSoundMoonCardEnable() then
        Lib.emitEvent(Event.EVENT_FREE_SOUND_TIME_CHANGE, value)
    end
end
