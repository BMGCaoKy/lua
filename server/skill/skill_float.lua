---@type SkillBase
local SkillBase = Skill.GetType("Base")
---@type Float
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

	local isShowbutton = false
	local data = target:getFloatData(self.LevitationType)
	if data and data.fullName == info.fullName and self.stopMode == Define.SkillStopMode.ClickAgain then
		target:setFloatData(self.LevitationType, nil)
		
	else
		target:setFloatData(self.LevitationType, info)

		if self.LevitationType == Define.SkillFloatType.Free then 
			target.EntityProp.horizonFloatSpeedLimit = self.maxHorizontalSpeed
			target.EntityProp.horizonFloatSpeedAccAdd = self.horizontalAcceleration
			target.EntityProp.horizonFloatSpeedAccDec = self.horizontalDeceleration
			target.EntityProp.verticalFloatSpeedLimit = self.maxVerticalSpeed
			target.EntityProp.verticalFloatSpeedAccAdd = self.verticalAcceleration
			target.EntityProp.verticalFloatSpeedAccDec = self.verticalDeceleration
		elseif self.LevitationType == Define.SkillFloatType.Direction then
			target.EntityProp.floatSpeedLimit = self.maxFaceSpeed
			target.EntityProp.floatSpeedAccAdd = self.acceleration
			target.EntityProp.floatSpeedAccDec = self.deceleration
		end

		packet.isFloat = true
		

		if self.LevitationType == Define.SkillFloatType.Free then 
			isShowbutton = false
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
end
