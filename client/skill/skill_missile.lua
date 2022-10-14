require "common.skill.skill_missile"
local SkillBase = Skill.GetType("Base")
local SkillMissile = Skill.GetType("Missile")

local handleTarget = SkillMissile.handleTarget

function handleTarget.trayTargets(skillMissileInstance,packet, from)
	local missileCount = self.missileCount or 1
	local targetPos = {}
	for i = 1, missileCount do
		targetPos[i] = Lib.getRayTarget(150, true)
	end
	packet.isMoreTargets = true
	packet.targetPos = targetPos
	return true
end

function handleTarget.trayRange(skillMissileInstance,packet, from)
	return skillMissileInstance.handleTarget.trayTargets(skillMissileInstance,packet, from)
end

function handleTarget.trayTarget(skillMissileInstancepacket, from)
	packet.targetPos = Lib.getRayTarget()
	return true
end

function handleTarget.BodyYaw(skillMissileInstance,packet, from)
    if not from or not from:isValid() then
        return false
    end
	local fromBodyYaw = from:getBodyYaw()
	if not skillMissileInstance.handleTarget.FromBodyYaw(skillMissileInstance,packet, from, fromBodyYaw) then 
		return false 
	end 

	packet.fromBodyYaw = fromBodyYaw
	return true
end

function handleTarget.FrontEntity(skillMissileInstance,packet, from)
	local yaw = math.rad(from:getBodyYaw())
	local pos = skillMissileInstance:getStartPos(from)
	local frontDistance = skillMissileInstance.frontDistance or 1
	pos.x = pos.x - math.sin(yaw) * frontDistance
	pos.z = pos.z + math.cos(yaw) * frontDistance
	local frontRange = math.abs(skillMissileInstance.frontRange or 1) / 2
	local frontHeight = math.abs(skillMissileInstance.frontHeight or 1) / 2
	local vr = Lib.v3(frontRange, frontHeight, frontRange)
	local entity = nil
	local distance = math.huge
	local array = from.map:getTouchObject(pos - vr, pos + vr)
	for _, obj in ipairs(array) do
		if obj.isEntity and from:canAttack(obj) then
			local d = from:distance(obj)
			if d < distance then
				entity = obj
				distance = d
			end
		end
	end
	if entity then
		packet.targetID = entity.objID
		packet.targetPos = skillMissileInstance:getStartPos(entity)
	else	-- 如果找不到对象就空放
		packet.targetID = from.objID
		packet.targetPos = pos
	end
	return true
end

local function getGroundPos(from)
	local pos = Lib.tov3(from:getPosition())
	local groundPos = pos:blockPos()
	local imcPos = {x = pos.x - groundPos.x, y = 1, z = pos.x - groundPos.z}
	local airFullName = Block.GetAirBlockName()
	local map = from.map
	while map:getBlock(groundPos).fullName == airFullName and groundPos.y>0 do
		groundPos = groundPos + {x=0,y=-1,z=0}
	end
	while map:getBlock(groundPos+{x=0,y=1,z=0}).fullName ~= airFullName do
		groundPos = groundPos + {x=0,y=1,z=0}
	end
	return groundPos+imcPos
end

local function getMuzzleParame(self, from)
	local muzzlePoint
	local effectCfg = self.muzzleEffect or {}
	local effectScale = effectCfg.scale or {x = 1, y = 1, z = 1}
	local pv = Blockman.Instance():getCurrPersonView()
	local item = from:getHandItem()
	local itemOffect = item and item:cfg().muzzleOffset
	local muzzleOffset = itemOffect or self.muzzleOffset
	if muzzleOffset and (from ~= Me or pv ~= 0) then
		local offset = muzzleOffset
		local yaw = math.rad(from:getBodyYaw() + offset.yaw)
		local pitch = math.rad(offset.pitch)
		local pos = from:getEyePos()
		local len = offset.len
		pos.x = pos.x - math.sin(yaw) * math.cos(pitch) * len
		pos.y = pos.y - math.sin(pitch) * len
		pos.z = pos.z + math.cos(yaw) * math.cos(pitch) * len
		muzzlePoint = pos
	end
	local itemFPSOffset = item and item:cfg().fPSmuzzleOffset
	local fPSmuzzleOffset = itemFPSOffset or self.fPSmuzzleOffset
	if fPSmuzzleOffset and (Me == from and pv == 0) then
		local offset = fPSmuzzleOffset
		effectScale = effectCfg.FPscale or effectScale
		local screenPos = {x=0, y=0}
		local ri = Root.Instance()
		screenPos.x = screenPos.x + ri:getRealWidth() / 2 + offset.x
		screenPos.y = screenPos.y + ri:getRealHeight() / 2 + offset.y
		local result = Blockman.instance:getRayTraceResult(screenPos, offset.len or 1, false, false, true , {})
		muzzlePoint = result.oPosition
	end
	return muzzlePoint, effectCfg.effect, effectScale, effectCfg.time
end

function SkillMissile:getStartPos(from)
    if not from or not from:isValid() then
        return false
    end
	if self.startFrom=="foot" then
		return from:getPosition()
	elseif self.startFrom == "ground" and not World.cfg.useVoxelTerrain then
		return getGroundPos(from)
	elseif self.startFrom == "trayTarget" then
		return getMuzzleParame(self, from)
	end
	return from:getEyePos()
end

function SkillMissile:canCast(packet, from)
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	local func = assert(handleTarget[self.targetType], self.targetType)
	if not func(self, packet, from) then
		return false
	end
	--把目标位置放在释放技能时候确定，因为现在的技能不是瞬发的
	--if not packet.startPos then
	--	packet.startPos = self:getStartPos(from)
	--end
	return true
end

function SkillMissile:setStartPos(packet, from)
	local func = assert(handleTarget[self.targetType], self.targetType)
	func(self, packet, from)
	if not packet.startPos then
		packet.startPos = self:getStartPos(from)
	end
end

function SkillMissile:preCast(packet, from)
	if self.targetType=="BodyYaw" then
		local d = Lib.tov3(packet.targetPos) - from:getPosition()
		local yaw = math.atan(-d.x, d.z)
		from:setBodyYaw(math.deg(yaw))
	end
	local muzzlePoint, muzzleEffect, muzzleEffectScale, time = getMuzzleParame(self, from)
	if muzzleEffect and muzzlePoint then
		muzzleEffect = ResLoader:filePathJoint(self, muzzleEffect)
		Blockman.instance:playEffectByPos(muzzleEffect, muzzlePoint, 0, time or 200, muzzleEffectScale)
	end
	SkillBase.preCast(self, packet, from)
end

function SkillMissile:cast(packet, from)
	Missile.SkillCast(packet, from, self)
	SkillBase.cast(self, packet, from)
end
