
--重载：去掉怪物行走的声音
function Entity:getMoveStateSwitchBuffFullNames(oldState, newState)
	local buffsKey = (self:cfg().entityMoveStateSwithBuffCfgs[newState] or {})[oldState]
	if not buffsKey then
		return nil
	end
    local buffs = {jumpBuff = true, runBuff = true, walkBuff = true, sprintBuff = true}
	if buffs[buffsKey] and not self.isPlayer then
		return nil
	end
	
	local pos = self:getPosition()
	local underFootBlockCfg = self.map:getBlock({x = pos.x // 1, y = pos.y // 1 - 1, z = pos.z // 1})
	
	local underFootObjectCfg = {}
	local underFootObjectId = self:getCollidableUnderfootObjId()

	if underFootObjectId > 0 then -- 提供一个可选的被踩时的移动状态变化配置，
									-- 解决骑乘物被踩时，给踩在上面的entity错误的移动状态变化配置(该骑乘物的移动状态变化配置)
		local object = World.CurWorld:getObject(underFootObjectId)
		underFootObjectCfg = object and object:cfg()
		if underFootObjectCfg and underFootObjectCfg.objectWasTrampledMoveStateSwitchCfg then
			underFootObjectCfg = underFootObjectCfg.objectWasTrampledMoveStateSwitchCfg
		end
	end
				
	for _, cfg in ipairs({ underFootBlockCfg, underFootObjectCfg, self:cfg() }) do
		if cfg[buffsKey] then
			return cfg[buffsKey]
		end
	end
	return nil
end

function Entity:doHurt(motionV, callDohurtBySelf)
	if self:prop("undamageable") > 0 then return end

	if callDohurtBySelf then
		self:doHurtInC(motionV, -1)
		return
	end
	
	local cfg = self:cfg()
	if cfg.moveSpeed and cfg.moveSpeed <= 0 or cfg.canFly then
		self:doHurtInC({x = 0, y = 0, z = 0}, -1)
		return
	end

	motionV.y = 0
	local ml = motionV:len()
	if ml == 0 then
		motionV.x = 0
		motionV.z = 0
	else
		motionV = motionV * 0.3 / ml
	end
	local hurtTime = self:data("main").hurtTime or World.Now() + 1
	motionV.y = 0.55
	local pos = self:getPosition()
	if hurtTime < World.Now() and World.Now() - hurtTime <= 10 then
		if (self:data("main").fristY or 0) - pos.y < 2 then
			motionV.y = 0.5
		else
			motionV.y = 0.2
		end
	else
	    self:data("main").fristY = pos.y
	end
	self:data("main").hurtTime = World.Now() + 10
	self:doHurtInC(motionV, 10)
	motionV:normalize()
	if self.hurtTimer then
		self.hurtTimer()
	end
	self.hurtTimer = self:lightTimer("dohurt", 10, function()
		self:data("aiData").needEmergency = motionV
	end)
end


function Player:startPlayTime()
    --unit: millisecond
    self.playStartTime = Lib.getTime()
end

function Player:getPlayTime(needRefresh)
	if not self.playTime or needRefresh then
		local ret
		if self.playStartTime then
			ret = Lib.getTime() - self.playStartTime
			ret = math.floor(ret)
			ret = ret - ret % 10
		else
			self:startPlayTime()
			ret = 0.01 * 1000
		end
		self.playTime = ret
	end
	return self.playTime
end

function Entity.EntityProp:sound(value, add, buff)
	if not World.CurWorld.isClient then
		return
	end
	local ti = TdAudioEngine.Instance()
	self.baseActionScale = 1.0
	
	local function addSound(isRunSound)
		if isRunSound then
			value.loop = false 
		end
		buff.soundId = self:playSound(value, buff.cfg)
		local soundId = buff.soundId
		local volume = tonumber(value.volume)
		if volume then
			ti:setSoundsVolume(soundId, volume)
		end
		local rollOffType = Sound3DRollOffType[value.rollOffType]
		if rollOffType then
			ti:set3DRollOffMode(soundId, rollOffType)
		end
		local distance = value.distance
		if distance then
			ti:set3DMinMaxDistance(soundId, distance[1], distance[2])
		end
		if value.speed then
			buff.soundId:setSoundSpeed(value.speed)
		end
	end

	if buff.cfg.fullName:find("run_") then
		local scale = self:getMoveSpeed() / 0.3
		-- 0.1 5.1 
		scale = scale > 3 and 3 or scale
		if scale > 1 then
			scale = 1 + ((scale - 1) / 3 )
		else
			scale = 1 - (1 - scale) / 1.7
		end
		self.baseActionScale = scale
		if add then
			if self:data("main").moveSpeedSoundTimer then
				self:data("main").moveSpeedSoundTimer()
			end
			self:data("main").moveSpeedSoundTimer = World.Timer(math.ceil(7 / scale), function()
				addSound(true)
				return true
			end)
		end
		if not add then
			if self:data("main").moveSpeedSoundTimer then
				self:data("main").moveSpeedSoundTimer()
				self:data("main").moveSpeedSoundTimer = nil
			end
			ti:stopSound(buff.soundId)
		end
	else
		if add then
			addSound()
		else
			ti:stopSound(buff.soundId)
		end
	end

end

function Entity:getMoveSpeed()
	local movingStyle = self.movingStyle
	local moveSpeed = self:prop("moveSpeed")
	local sneakDownRate = self:prop("sneakDownRate") or 1
	local sprintUpRate = self:prop("sprintUpRate") or 1
	local moveFactor = self:prop("moveFactor") or 1
	
	if movingStyle == 1 then
		moveSpeed = moveSpeed * sneakDownRate
	elseif movingStyle == 2 then
		moveSpeed = moveSpeed * sprintUpRate
	end
	moveSpeed = moveSpeed * moveFactor
	return moveSpeed
end
