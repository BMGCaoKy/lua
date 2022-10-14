local GameRequest = require "we.proto.request_audio"

return {
	PLAY_2D_SOUND = function(path)
		local id = TdAudioEngine.Instance():play2dSound(path, false)
		AudioEngineMgr:registerSoundFinishCallback(id, function(id)
			GameRequest.request_sound_end_2d(id);
		end)
		return { ok = true, id = id }
	end,

	PAUSE_SOUND = function(id)
		TdAudioEngine.Instance():pauseSound(id)
		return { ok = true }
	end,

	RESUME_SOUND = function(id)
		TdAudioEngine.Instance():resumeSound(id)
		return { ok = true }
	end,

	STOP_SOUND = function(id)
		TdAudioEngine.Instance():stopSound(id)
		AudioEngineMgr:unregisterSoundFinishCallback(id) 
		return { ok = true }
	end,

	SET_SOUNDS_VOLUME = function(id, volume)
		TdAudioEngine.Instance():setSoundsVolume(id, volume)
		return { ok = true }
	end
}