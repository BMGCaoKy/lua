

local events = {}

function audio_engine_event(event, ...)
	--print("audio_engine_event", event, ...)
	local handler = events[event]
	if not handler then
		print("no handler for audio_engine_event", event)
		return
	end
	Profiler:begin("audio_engine_event."..event)
	handler(...)
	Profiler:finish("audio_engine_event."..event)
end

function events.sound_finish_callback(soundID)
	AudioEngineMgr:soundFinishCallback(soundID)
end