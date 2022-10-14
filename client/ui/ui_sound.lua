local guiMgr = L("guiMgr", GUIManager:Instance())
if not guiMgr:isEnabled() then
	print("useNewUI: false")
	return
end
--triggerRange 音效触发时机
--[[triggerRange = {
	  ST_NONE,  //无    0
      ST_DOWN,  //按下  1
      ST_UP,    //抬起  2
	  ST_CLICK  //点击  3
}--]]

UI:subscribeGlobalEvent("Window/MouseButtonDownPlay2dSound", 
	function(eventName, eventArgs)
		local window = eventArgs.window
		local range = window:getTriggerRange()
		local volume = window:getVolume()
		local soundFile = window:getSoundFile()
		if range == 0 and soundFile == ""then
			return
		end

		if range == 1 then
			local soundId = TdAudioEngine.Instance():play2dSound(soundFile, false)
			if volume then
				TdAudioEngine.Instance():setSoundsVolume(soundId, volume)
			end
		end
	end
)

UI:subscribeGlobalEvent("Window/MouseButtonUpPlay2dSound", 
	function(eventName, eventArgs)
		local window = eventArgs.window
		local range = window:getTriggerRange()
		local volume = window:getVolume()
		local soundFile = window:getSoundFile()
		if range == 0 and soundFile == ""then
			return
		end

		if range == 2 then
			local soundId = TdAudioEngine.Instance():play2dSound(soundFile, false)
			if volume then
				TdAudioEngine.Instance():setSoundsVolume(soundId, volume)
			end
		end
	end
)

UI:subscribeGlobalEvent("Window/MouseClickPlay2dSound", 
	function(eventName, eventArgs)
		local window = eventArgs.window
		local range = window:getTriggerRange()
		local volume = window:getVolume()
		local soundFile = window:getSoundFile()
		if range == 0 and soundFile == ""then
			return
		end

		if range == 3 then
			local soundId = TdAudioEngine.Instance():play2dSound(soundFile, false)
			if volume then
				TdAudioEngine.Instance():setSoundsVolume(soundId, volume)
			end
		end
	end
)