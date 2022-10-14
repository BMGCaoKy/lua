
local SkillMissile = Skill.GetType("Missile")

SkillMissile.targetType = "Any"

local handleTarget = {}
SkillMissile.handleTarget = handleTarget

function handleTarget.CameraYaw(skillMissileInstance, packet, from)
    if not from or not from:isValid() then
        return false
    end
	local yaw = math.rad(from:getRotationYaw())
	local pos = skillMissileInstance:getStartPos(from)
	pos.x = pos.x - math.sin(yaw)
	pos.z = pos.z + math.cos(yaw)
	packet.targetPos = pos
	return true
end

function handleTarget.Camera(skillMissileInstance, packet, from)
    if not from or not from:isValid() then
        return false
    end
	local yaw = math.rad(from:getRotationYaw())
	local pitch = math.rad(from:getRotationPitch())
	local pos = skillMissileInstance:getStartPos(from)
	pos.x = pos.x - math.sin(yaw) * math.cos(pitch)
	pos.y = pos.y - math.sin(pitch)
	pos.z = pos.z + math.cos(yaw) * math.cos(pitch)
	packet.targetPos = pos
	return true
end

function handleTarget.FrontSight(skillMissileInstance, packet, from)
	if not from or not from:isValid() then
        return false
    end
	local yaw = math.rad(from:getRotationYaw())
	local pitch = math.rad(from:getRotationPitch())

	local frontSightCfg = skillMissileInstance.frontSightCfg or 
	{
		offset = {x = 0,y = 0},
		len = 100
	}
	local screenPos = {x=0, y=0}
	local ri = Root.Instance()
	screenPos.x = screenPos.x + ri:getRealWidth() / 2 + frontSightCfg.offset.x
	screenPos.y = screenPos.y + ri:getRealHeight() / 2 + frontSightCfg.offset.y
	local result = Blockman.instance:getRayTraceResult(screenPos, frontSightCfg.len or 100, false, false, true , {})
	local pos = result and (result.hitPos or result.oPosition)

	if not pos then 
		return false
	end
	
	packet.targetPos = pos
	return true
end

function handleTarget.FromBodyYaw(skillMissileInstance, packet, from, bodyYaw)
    if not from or not from:isValid() or not bodyYaw then
        return false
    end
	local yaw = math.rad(bodyYaw)
	local pos = skillMissileInstance:getStartPos(from)
	pos.x = pos.x - math.sin(yaw)
	pos.z = pos.z + math.cos(yaw)
	packet.targetPos = pos
	return true
end

function handleTarget.Entity(skillMissileInstance, packet, from)
    if not from or not from:isValid() then
        return false
    end
	packet.targetID = packet.targetID or tonumber(from:data("targetId"))
	if not packet.targetID then
		return false
	end
	local entity = from.world:getEntity(skillMissileInstance, packet.targetID)
	if not entity or not entity:isValid() then
		return false
	end
	packet.targetPos = skillMissileInstance:getStartPos(entity)
	return true
end

function handleTarget.Self(skillMissileInstance,packet, from)
	packet.targetID = from.objID
	--packet.targetPos = skillMissileInstance:getStartPos(from)
	--return true
	return handleTarget.CameraYaw(skillMissileInstance, packet, from)
end

function handleTarget.Block(skillMissileInstance, packet, from)
	if not packet.blockPos then

		return false
	end
	packet.targetPos = packet.blockPos + Lib.v3(0.5, 0.5, 0.5)
	return true
end

function handleTarget.Any(skillMissileInstance, packet, from)
	return handleTarget.Entity(skillMissileInstance, packet, from) or handleTarget.Block(skillMissileInstance, packet, from) or handleTarget.CameraYaw(skillMissileInstance, packet, from)
end

function handleTarget.None(skillMissileInstance, packet, from)
	packet.targetPos = skillMissileInstance:getStartPos(from) + Lib.v3(0, 0, 1)
	return true
end























