
local SkillBase = Skill.GetType("Base")
local BreakBlock = Skill.GetType("BreakBlock")
BreakBlock.startAction = ""
BreakBlock.sustainAction = "attack7"
BreakBlock.cycleSustainActionTime = 5
BreakBlock.breakBlockCD = World.cfg.breakBlockCD or 2

BreakBlock.isTouch = true

function BreakBlock:canCast(packet, from)
	if (World.Now() - (from and from.lastBreakBlockTime or -1)) < BreakBlock.breakBlockCD then
		return false
	end
	return SkillBase.canCast(self, packet, from)
end

function BreakBlock:getTouchTime(packet, from)
	local blockPos = packet.blockPos
	if not blockPos then
		return nil
	end
	if not self:canCast(packet, from) then
		return nil
	end
	local block = from.map:getBlock(blockPos)
	local clickDis = from:cfg().clickBlockDistance
	if clickDis and Lib.getPosDistance(from:getPosition(), blockPos) > clickDis then
		return false
	end
	local prop = from:prop()
	if not block.breakTime or prop.breakBlock <= 0 then
		return false
	end
	local breakTime = (block.breakTime + prop.breakTime) * prop.breakTimeFactor
	return math.max(breakTime, 1)
end

function BreakBlock:getSoundCfg(packet,soundName,from)
	if soundName == "startSound" then
		local blockCfg = from.map:getBlock(packet.blockPos)
		if blockCfg and blockCfg.breakBlockSound then
			return blockCfg, blockCfg.breakBlockSound
		end
	end
	return SkillBase.getSoundCfg(self, packet, soundName,from)
end

function BreakBlock:start(packet, from)
    if from:isControl() then
	    Lib.emitEvent(Event.EVENT_BREAK_BLOCK_UI_MANAGE, true, packet.touchTime, packet.blockPos)
    end
	from:destroyBlockStart(packet.blockPos, packet.touchTime)
	SkillBase.start(self, packet, from)
	SkillBase.sustain(self, packet, from)
end

function BreakBlock:preCast(packet, from)
	from.lastBreakBlockTime = World.Now()
	if from:isControl() then
		Lib.emitEvent(Event.EVENT_BREAK_BLOCK_UI_MANAGE, false)
	end
	SkillBase.preCast(self, packet, from)
end

local function playBreakBlockAfterSound(packet, from)
	if not from.map then
		return
	end

	local blockCfg = from.map:getBlock(packet.blockPos)
	if blockCfg and blockCfg.breakBlockAfterSound then
		from:playSound(blockCfg.breakBlockAfterSound, blockCfg)
	end
end

function BreakBlock:stop(packet, from)
	if from:isControl() then
		Lib.emitEvent(Event.EVENT_BREAK_BLOCK_UI_MANAGE, false)
	end
	from:destroyBlockStop()
	SkillBase.stop(self, packet, from)
end

function BreakBlock:cast(packet, from)
	from:destroyBlockStop()
	from:destroyBlockCast()
	playBreakBlockAfterSound(packet, from)
	SkillBase.stop(self, packet, from)
	SkillBase.cast(self, packet, from)
end

function BreakBlock:singleCast(packet, from)
	from.map:removeBlock(packet.blockPos)
	SkillBase.singleCast(self, packet, from)
end
