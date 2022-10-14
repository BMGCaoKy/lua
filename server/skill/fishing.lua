
local SkillBase = Skill.GetType("Base")
local Fishing = Skill.GetType("Fishing")

Fishing.throwDistance = 2

function Fishing:doThrow(packet, from)
	local data = from:data("fishing")
	data.state = "wait"
	data.startTime = World.Now()
	data.hookPos = packet.hookPos
	local vars = from.vars
	local times = vars.haveShowFishingGuideTimes or 0
	if times <= 1 then
		vars.haveShowFishingGuideTimes = 1 + times
		packet.needShowGuide = times == 0
	end
	local time = math.random(self.hookTime[1], self.hookTime[2])
    time = time - from:prop("subfishtime")
	data.timer = from:timer(time, function()
			data.timer = nil
			packet.method = "hook"
			packet.runStart = math.random(self.runStart[1], self.runStart[2])
			Skill.Cast(packet.name, packet, from)
		end)
end

function Fishing:doHook(packet, from)
	local data = from:data("fishing")
	data.state = "catch"
	data.hookTime = World.Now()
end

function Fishing:doCatch(packet, from)
	from:setData("fishing", nil)
    local item = from:getHandItem()
	if not item then
		return
	end
	local context = {
		obj1 = from,
		item = item,
	}
	Trigger.CheckTriggersOnly(from:cfg(), "FISHING_OK", context)
	Trigger.CheckTriggersOnly(item:cfg(), "FISHING_OK", context)
	from.map:triggerRegions(from:getPosition(), "FISHING_OK", context)
	Trigger.CheckTriggers(nil, "FISHING_OK", context)
end

function Fishing:doCancel(packet, from)
	local data = from:data("fishing")
	if data.timer then
		data.timer()
		data.timer = nil
	end
	from:setData("fishing", nil)
end

function Fishing:findHookPos(from)
    local map = from.map
	local yaw = math.rad(from:getRotationYaw())
	local pos = from:getEyePos()
	if not pos then
		return nil
	end
	Lib.tov3(pos)
	pos.x = pos.x - math.sin(yaw) * self.throwDistance
	pos.z = pos.z + math.cos(yaw) * self.throwDistance
    pos = pos:blockPos()
    for y = pos.y + 1, pos.y - 5, -1 do
        pos.y = y
        local block = map:getBlock(pos)
        if block.canSwim then
            return pos + Lib.v3(0.5, 1, 0.5)
        end
        if block.blockObjectOnCollision~=false then
            return nil
        end
    end
	return nil
end

function Fishing:canCast(packet, from)
    if not SkillBase.canCast(self, packet, from) then
        return false
    end
    if packet.method~="throw" then
        return true
    end
	local data = from:data("fishing")
	if data.state then
		return false
	end
    local pos = self:findHookPos(from)
    if not pos then
        return false
    end
    packet.hookPos = pos
    return true
end

function Fishing:cast(packet, from)
	local data = from:data("fishing")
	local method = packet.method
    data.skillName = self.fullName
	print("fishing!", method, from.name)
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
