local math = math
local setting = require "common.setting"
---@type Object
local Object = Object

--3D音效
local Sound_3D_RollOffMode = {}
Sound_3D_RollOffMode["0"] = 0x00200000 --FMOD_3D_LINEARROLLOFF
Sound_3D_RollOffMode["1"] = 0x00400000 --FMOD_3D_LINEARSQUAREROLLOFF
Sound_3D_RollOffMode["2"] = 0x00800000 --FMOD_3D_INVERSETAPEREDROLLOFF
Sound_3D_RollOffMode["3"] = 0x00100000 --FMOD_3D_INVERSEROLLOFF

function Object:playSound(sound, cfg, noFollow)
	if not Blockman.instance.gameSettings:getEnableAudioUpdate() then
		return nil
	end
	if not sound or not sound.sound then
		return nil
	end

	if not self:isValid() then
		return
	end

	if sound.selfOnly then
		local entity
		if self.isEntity then
			entity = self
		else
			entity = self.world:getEntity(self.ownerId)
		end
		if not (entity and entity:isControl()) then
			return nil
		end
	end

	cfg = cfg or self:cfg()

	if not sound.path then
        sound.path = ResLoader:filePathJoint(cfg, sound.sound)
	end

    local isLoop = false
    if sound.loop ~= nil then
       isLoop = sound.loop
    end

	local id
	if noFollow then
		id = TdAudioEngine.Instance():play3dSound(sound.path, self:getPosition(), isLoop)
	elseif sound.distance then
		id = self:play3dSound(sound.path, isLoop, true)
	else
		id = self:play3dSound(sound.path, isLoop, sound.is3dSound)
	end

	if sound.volume then
		TdAudioEngine.Instance():setSoundsVolume(id, sound.volume)
	end
	if sound.multiPly then
		TdAudioEngine.Instance():setSoundSpeed(id, sound.multiPly)
	end
	if true == sound.is3dSound then
		local mode = Sound_3D_RollOffMode[sound.attenuationType]
		TdAudioEngine.Instance():set3DRollOffMode(id, mode)
		TdAudioEngine.Instance():set3DMinMaxDistance(id, sound.losslessDistance, sound.maxDistance)
	end

    return id
end

function Object:stopSound(soundId)
	if soundId then
		TdAudioEngine.Instance():stopSound(soundId)
	end
end

function Object:fadeSound(soundId, volume, ticks)
	if not soundId then
		return
	end

	local curVolume = TdAudioEngine.Instance():getSoundsVolume(soundId)
	local delta = (volume - curVolume) / ticks

	self.fadeSoundTimer = self.fadeSoundTimer or {}

	---@type LuaTimer
	local LuaTimer = T(Lib, "LuaTimer")
	LuaTimer:cancel(self.fadeSoundTimer[soundId])

	self.fadeSoundTimer[soundId] = LuaTimer:scheduleTimer(function()
		curVolume = TdAudioEngine.Instance():getSoundsVolume(soundId)
		local volume = curVolume + delta
		TdAudioEngine.Instance():setSoundsVolume(soundId, volume)
		--Lib.logDebug("setSoundsVolume", soundId, volume)
	end, 50, ticks)
end

function Object:isPlaying(soundId)
	if soundId then
		return TdAudioEngine.Instance():isPlaying(soundId)
	end
	return false
end

-- 客户端光环，目前实际上仅有显示作用
function Object:addAura(name, info)
	if not World.gameCfg.debug then
		return
	end
	local auralist = self:data("aura")
	assert(not auralist[name], name)
	local range = info.range
	if not range and info.cfgName then
		local cfg = setting:fetch("aura", info.cfgName)
		range = cfg.range
	end
	range = math.floor((range or 5) / 1)	-- 整除，为了取整
	if range<0 then
		range = 0
	end
	local rangelist = self:data("aurarange")
	local rangedata = rangelist[range]
	if not rangedata then
		rangedata = {
			range = range,
			list = {},
		}
		rangelist[range] = rangedata
		self:createObjectSphere(range, range, range*1.2, 0, {x = 0, y = 0, z = 0})
	end
	rangedata.list[name] = true
	auralist[name] = rangedata
	return true
end

function Object:removeAura(name)
	local auralist = self.luaData.aura
	if not auralist then
		return false
	end
	local rangedata = auralist[name]
	if not rangedata then
		return false
	end
	auralist[name] = nil
	local list = rangedata.list
	list[name] = nil
	if not next(list) then
		self:data("aurarange")[rangedata.range] = nil
		self:removeObjectSphere(rangedata.range)
	end
	return true
end

function Object:call_sphereChange(...)
	self:onInteractionRangeChanged(...)
end

function Object:onInteractionRangeChanged(id, list)
	if id ~= self.interactionRange then
		return
	end
	local objID = self.objID
	Me:onInInteractionRangesChanged(self.objID, list[1][2])
end