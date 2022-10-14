-- AudioEngineMgr
local callbackMap = {}
function AudioEngineMgr:registerSoundFinishCallback(id, callback)
    if not id or id < 0 then
        perror("registerSoundFinishCallback error !! bad id : ", id)
        return
    end
    TdAudioEngine.Instance():registerSoundFinishEvent(id)
    callbackMap[id] = callback
end

function AudioEngineMgr:unregisterSoundFinishCallback(id)
    if not id or id < 0 then
        perror("unregisterSoundFinishCallback error !! bad id : ", id)
        return
    end
    callbackMap[id] = nil
end

function AudioEngineMgr:soundFinishCallback(id)
    if not id or not callbackMap[id] then
        return
    end
    local func = callbackMap[id]
    if func then
        func(id)
    end
    callbackMap[id] = nil
end
