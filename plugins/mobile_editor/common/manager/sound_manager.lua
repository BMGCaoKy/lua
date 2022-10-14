--- sound_manager.lua
--- 声音的管理器
---
---@class SoundManager : singleton
local SoundManager = T(MobileEditor, "SoundManager")
---@type ConfigManager
local ConfigManager = T(MobileEditor, "ConfigManager")

function SoundManager:initialize()
    self.bgmSoundId = nil
    self.sounds = {}
    self:subscribeEvents()
end

function SoundManager:load()
    World.cfg.bgm = World.cfg.bgm or {}
    if World.cfg.bgm.id then
        self:playBGM(World.cfg.bgm.id, true)
    end
end

function SoundManager:finalize()

end

function SoundManager:playBGM(bgmId, force)
    local config = ConfigManager:instance().musicConfig:getConfig(bgmId)
    if not config then
        return
    end
    if World.cfg.bgm.id == bgmId and not force then
        return
    end
    World.cfg.bgm.id = config.id
    World.cfg.bgm.path = config.path
    if self.bgmSoundId then
        TdAudioEngine.Instance():stopSound(self.bgmSoundId)
    end
    self.bgmSoundId = self:play2DSound(config.path, true, 1.0, Define.SOUND_CHANNEL_GROUP.BGM)
end

function SoundManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_PLAY_BGM, function(id)
        self:playBGM(id)
    end)

    Lib.subscribeEvent(Event.EVENT_STOP_BGM, function()
        self:stopBGM()
    end)

    Lib.subscribeEvent(Event.EVENT_PAUSE_BGM, function()
        self:pauseBGM()
    end)

    Lib.subscribeEvent(Event.EVENT_RESUME_BGM, function()
        self:resumeBGM()
    end)

    Lib.subscribeEvent(Event.EVENT_PLAY_SOUND, function(path, loop, volume, pos)
        self:playSound(path, loop, volume, pos)
    end)

    Lib.subscribeEvent(Event.EVENT_STOP_SOUND, function()
        self:stopSounds()
    end)
end

function SoundManager:playSound(path, loop, volume, pos)
    local soundId
    if pos then
        soundId = self:play3DSound(path, loop, volume, pos, Define.SOUND_CHANNEL_GROUP.EFFECT)
    else
        soundId = self:play2DSound(path, loop, volume, Define.SOUND_CHANNEL_GROUP.EFFECT)
    end
    if loop == true then
        table.insert(self.sounds, soundId)
    end
end

function SoundManager:stopSounds()
    for _, soundId in pairs(self.sounds) do
        TdAudioEngine.Instance():stopSound(soundId)
    end
    self.sounds = {}
end

function SoundManager:play2DSound(path, loop, volume, group)
    local soundId = TdAudioEngine.Instance():play2dSound(path, loop, group)
    if volume then
        TdAudioEngine.Instance():setSoundsVolume(soundId, volume)
    end
    return soundId
end

function SoundManager:play3DSound(path, loop, volume, pos, group)
    local soundId = TdAudioEngine.Instance():play3dSound(path, pos, loop, volume, group)
    if volume then
        TdAudioEngine.Instance():setSoundsVolume(soundId, volume)
    end
    return soundId
end

function SoundManager:stopBGM()
    World.cfg.bgm = {}
    if self.bgmSoundId then
        TdAudioEngine.Instance():stopSound(self.bgmSoundId)
        self.bgmSoundId = nil
    end
end

function SoundManager:pauseBGM()
    if self.bgmSoundId then
        TdAudioEngine.Instance():pauseSound(self.bgmSoundId)
    end
end

function SoundManager:resumeBGM()
    if self.bgmSoundId then
        TdAudioEngine.Instance():resumeSound(self.bgmSoundId)
    end
end

return SoundManager