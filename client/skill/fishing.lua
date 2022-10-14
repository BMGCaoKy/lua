
local SkillBase = Skill.GetType("Base")
local Fishing = Skill.GetType("Fishing")

Fishing.waitTime = 20

local function updateHandItem(entity, fishing)
	local item = entity:getHandItem()
	if not item then
		entity:updateHoldModel()
		return
	end

	local model = item:model(fishing and "fishing")
	entity:updateHoldModel(model)
end

function Fishing:doThrow(packet, from)
	local data = from:data("fishing")
	data.state = "wait"
	data.startTime = World.Now()
    data.hookPos = packet.hookPos or self:findHookPos(from)
	if self.fishhookCfg then
	    local hook = EntityClient.CreateClientEntity({cfgName=self.fishhookCfg, pos=data.hookPos, name=""})
		data.hookID = hook.objID
		hook:showEffect(hook:cfg().throwEffect)
		hook:playSound(hook:cfg().throwSound)
		from:setFishingHookPos(data.hookPos)
    end

	updateHandItem(from, true)
end

function Fishing:doHook(packet, from)
	if not from then
		return
	end
	local data = from:data("fishing")
	data.state = "catch"
	data.runStart = packet.runStart
	data.hookTime = World.Now()
	data.pullTimes = 0
    local hook = World.CurWorld:getObject(data.hookID)
    if hook then
        hook:showEffect(hook:cfg().hookEffect)
		hook:playSound(hook:cfg().hookSound)
		hook.isMoving = true
	end
	if packet.needShowGuide ~= nil then
		Lib.emitEvent(Event.EVENT_SHOW_FISHING_CATCH_GUIDE, packet.needShowGuide )
	end
end

function Fishing:doPull(packet, from)
	local data = from:data("fishing")
	data.pullTimes = data.pullTimes + 1
	from:playSound(self.pullSound, self)
	local value = self:getRunValue(from)
	if value>=0 then
		self:preCast(packet, from)
		return false
	end
	data.state = "finish"
	packet.method = "catch"
	packet.pullTimes = data.pullTimes
	return true
end

function Fishing:doCatch(packet, from)
	local data = from:data("fishing")
	data.state = nil
	data.waitTime = World.Now() + self.waitTime
    local hook = World.CurWorld:getObject(data.hookID)
    if hook then
        hook:destroy()
    end
    data.hookID = nil
	from:setFishingHookPos(nil)

	updateHandItem(from, false)
end

function Fishing:doCancel(packet, from)
	local data = from:data("fishing")
	data.state = nil
	data.waitTime = World.Now() + self.waitTime
    if data.hookID then
        local hook = World.CurWorld:getObject(data.hookID)
        if hook then
            hook:destroy()
        end
        data.hookID = nil
    end
	from:setFishingHookPos(nil)

	updateHandItem(from, false)
end

function Fishing:getRunValue(from)
	local data = from:data("fishing")
	if data.state~="catch" then
		return -1
	end
	return data.runStart + (World.Now() - data.hookTime) * self.runSpeed - data.pullTimes * self.pullSpeed
end

function Fishing:findHookPos(from)
    local world = World.CurWorld
	local yaw = math.rad(from:getRotationYaw())
	local pos = Lib.tov3(from:getEyePos())
	pos.x = pos.x - math.sin(yaw) * self.throwDistance
	pos.z = pos.z + math.cos(yaw) * self.throwDistance
	return pos
end

function Fishing:canCast(packet, from)
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	local data = from:data("fishing")
	if packet.method=="cancel" then
		return true
	elseif not data.state then
		if data.waitTime and World.Now()<data.waitTime then
			return false
		end
		packet.method = "throw"
		data.waitTime = World.Now() + self.waitTime
		return true
	elseif data.state=="catch" then
		return self:doPull(packet, from)
	else
		return false
	end
end

function Fishing:cast(packet, from)
	local method = packet.method
	if method=="throw" then
		self:doThrow(packet, from)
	elseif method=="hook" then
		self:doHook(packet, from)
	elseif method=="catch" then
		self:doCatch(packet, from)
	elseif method=="cancel" then
		self:doCancel(packet, from)
	end
end

function Fishing:singleCast(packet, from)
	local data = from:data("fishing")
	if packet.method=="throw" then
		local time = math.random(self.hookTime[1], self.hookTime[2])
        time = time - from:prop("subfishtime")
		data.timer = from:timer(time, function()
				data.timer = nil
				packet.method = "hook"
				packet.runStart = math.random(self.runStart[1], self.runStart[2])
				self:cast(packet, from)
			end)
	elseif packet.method=="cancel" then
		if data.timer then
			data.timer()
			data.timer = nil
		end
	end
	SkillBase.singleCast(self, packet, from)
end

function Fishing:showIcon(show)
	local data = Player.CurPlayer:data("fishing")
	if show then
		data.skillName = self.fullName
		data.state = nil
	elseif data.skillName then
		Skill.Cast(data.skillName, {method="cancel"})
		data.skillName = nil
	end
	Lib.emitEvent(Event.EVENT_SHOW_FINSHING, show)
end

function Fishing:preCast(packet, from)
	if packet.method~="cancel" then
		SkillBase.preCast(self, packet, from)
	end
end
