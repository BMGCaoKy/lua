---@type SkillBase
local SkillBase = Skill.GetType("Base")
---@class Float
local Levitation = Skill.GetType("Levitation")

function Levitation:cast(packet, from)
	local target = from
	if not target then
		print("float wrong target!", packet.targetID)
		return
	end

	SkillBase.cast(self, packet, from)

	local info = {
		endTime = self.untilTimeOver and self.levitationTime + World.Now() or nil,
		fullName = self.fullName,
		isPressJoystickMove = self.isPressJoystickMove
	}

	local data = target:getFloatData(self.LevitationType)
	if data and data.fullName == info.fullName and self.stopMode == Define.SkillStopMode.ClickAgain then
		target:setFloatData(self.LevitationType, nil)
		
		if target~= Me then 
			target:setFloatMode(Define.SkillFloatType.None)
		else 
			if self.LevitationType == Define.SkillFloatType.Free then 
				Lib.emitEvent(Event.EVENT_SHOW_FLOAT_SKILL_ICON, false)
			end
		end
	else
		target:setFloatData(self.LevitationType, info)

		if self.LevitationType == Define.SkillFloatType.Free then 
			target:doSetProp("horizonFloatSpeedLimit",self.maxHorizontalSpeed)
			target:doSetProp("horizonFloatSpeedAccAdd",self.horizontalAcceleration)
			target:doSetProp("horizonFloatSpeedAccDec",self.horizontalDeceleration)
			target:doSetProp("verticalFloatSpeedLimit",self.maxVerticalSpeed)
			target:doSetProp("verticalFloatSpeedAccAdd",self.verticalAcceleration)
			target:doSetProp("verticalFloatSpeedAccDec",self.verticalDeceleration)

		--[[	target.EntityProp.horizonFloatSpeedLimit = self.maxHorizontalSpeed
			target.EntityProp.horizonFloatSpeedAccAdd = self.horizontalAcceleration
			target.EntityProp.horizonFloatSpeedAccDec = self.horizontalDeceleration
			target.EntityProp.verticalFloatSpeedLimit = self.maxVerticalSpeed
			target.EntityProp.verticalFloatSpeedAccAdd = self.verticalAcceleration
			target.EntityProp.verticalFloatSpeedAccDec = self.verticalDeceleration]]--
		elseif self.LevitationType == Define.SkillFloatType.Direction then

			target:doSetProp("floatSpeedLimit",self.maxSpeed)
			target:doSetProp("floatSpeedAccAdd",self.acceleration)
			target:doSetProp("floatSpeedAccDec",self.deceleration)
			--[[target.EntityProp.floatSpeedLimit = self.maxFaceSpeed
			target.EntityProp.floatSpeedAccAdd = self.acceleration
			target.EntityProp.floatSpeedAccDec = self.deceleration]]--
		end

		packet.isFloat = true
		

		if target~= Me then 
			target:setFloatMode(self.LevitationType)
		else 
			if self.LevitationType == Define.SkillFloatType.Free then 
				Lib.emitEvent(Event.EVENT_SHOW_FLOAT_SKILL_ICON, true)
			end
		end
	end
end

function Levitation:stop(packet, from)
	local target = from
	if not target then
		print("float wrong target!", packet.targetID)
		return
	end

	target:setFloatData(self.LevitationType, nil)
	if target~= Me then 
		target:setFloatMode(Define.SkillFloatType.None)
	else 
		if self.LevitationType == Define.SkillFloatType.Free then 
			Lib.emitEvent(Event.EVENT_SHOW_FLOAT_SKILL_ICON, false)
		end
	end
end
