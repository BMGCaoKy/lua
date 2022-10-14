local SkillBase = Skill.GetType("Base")
local RaySkill = Skill.GetType("Ray")


local defaultShakeType = {}
local shakeTypeMap = { ["default"] = defaultShakeType,}

local shakeData = {}
shakeData.shootTime = 0
shakeData.curTrajectory = {}
shakeData.idxOfCurTrajectory = 0
shakeData.idxOfTrajectorys = 0
shakeData.shooting = false
shakeData.config = {}

local maxRayLength = World.cfg.maxRayLength or 1000

local function timeToFrame(time)
    assert(type(time) == "number")
    local frame = time * 20.0
    return math.floor(frame + 0.5) -- 四舍五入取整
end

function defaultShakeType:canCast(packet, from)
    if shakeData.shootTime > 0 then
        local elapseTime = World.Now() - shakeData.shootTime
        if elapseTime < timeToFrame(shakeData.config.shakeDuration) then
            return false
        end
    end
    return true
end

function defaultShakeType:getShootPoint()
    local shootPoint = {}
    local x = self:getTrajectoryX(shakeData.idxOfTrajectorys, shakeData.idxOfCurTrajectory)
    local y = self:getTrajectoryY(shakeData.idxOfTrajectorys, shakeData.idxOfCurTrajectory)
    -- 原点为(0, 0)
    local preX = shakeData.idxOfCurTrajectory-1 ~= 0 and self:getTrajectoryX(shakeData.idxOfTrajectorys, shakeData.idxOfCurTrajectory-1) or 0
    local preY = shakeData.idxOfCurTrajectory-1 ~= 0 and self:getTrajectoryY(shakeData.idxOfTrajectorys, shakeData.idxOfCurTrajectory-1) or 0
    local yaw = x - preX
    local pitch = y - preY
    shootPoint.yaw = yaw * shakeData.config.shakeCoefficient
    shootPoint.pitch = -pitch * shakeData.config.shakeCoefficient
    return shootPoint
end


function defaultShakeType:getDropPoint()
    local dropPoint = {}
    local dropDistance = self:getTrajectoryY(shakeData.idxOfTrajectorys, shakeData.idxOfCurTrajectory) / 2.0
    dropPoint.yaw = 0
    dropPoint.pitch = dropDistance  * shakeData.config.shakeCoefficient
    return dropPoint
end


function defaultShakeType:reset()
    shakeData.shootTime = 0
    shakeData.curTrajectory = {}
    shakeData.idxOfCurTrajectory = 0
    shakeData.idxOfTrajectorys = 0
    shakeData.shooting = false
    shakeData.config = {}
end

function defaultShakeType:stop()
    local elapseTime = World.Now() - shakeData.shootTime
    if elapseTime >= self:getStopShootTime() then
        self:reset()
    end
    return false
end

function defaultShakeType:dropPoint(from, dropPoint, smooth)
    local elapseTime = World.Now() - shakeData.shootTime
    if elapseTime >= self:getDropTime() then
        self:changeCameraView(from, dropPoint, smooth)
    end
    return false
end

function defaultShakeType:changeCameraView(from, point, smooth)
    local curPitch = from:getRotationPitch()
    local curYaw = from:getRotationYaw()
    local curPosition = from:getPosition()
    local finalYaw = curYaw + point.yaw
    local finalPitch = curPitch + point.pitch
    from:changeCameraView(curPosition, finalYaw, finalPitch, nil, smooth)
end

function defaultShakeType:getTrajectoryX(idxOfTrajectorys, idxOfCurTrajectory)
    local coordinate = shakeData.config.trajectorys[idxOfTrajectorys][idxOfCurTrajectory]
    assert(coordinate)
    local x = coordinate[1]
    return x
end

function defaultShakeType:getTrajectoryY(idxOfTrajectorys, idxOfCurTrajectory)
    local coordinate = shakeData.config.trajectorys[idxOfTrajectorys][idxOfCurTrajectory]
    assert(coordinate)
    local y = coordinate[2]
    return y
end

function defaultShakeType:getDropTime()
    return timeToFrame(shakeData.config.shakeDuration) + timeToFrame(shakeData.config.dropTime)
end

function defaultShakeType:getStopShootTime()
    return timeToFrame(shakeData.config.shakeDuration) + timeToFrame(shakeData.config.stopShootTime)
end

local function shakeStop(shootType)
    return shootType:stop()
end

local function shakeDropPoint(shootType, from, dropPoint, smooth)
    return shootType:dropPoint(from, dropPoint, smooth)
end

function defaultShakeType:shake(packet, from)
    local sdc = shakeData.config
    if not shakeData.shooting then
        shakeData.shooting = true
        shakeData.idxOfTrajectorys = math.random(1, #sdc.trajectorys)
        shakeData.curTrajectory = sdc.trajectorys[shakeData.idxOfTrajectorys]
        assert(next(shakeData.curTrajectory))
    end

    shakeData.idxOfCurTrajectory  = shakeData.idxOfCurTrajectory + 1
    if shakeData.idxOfCurTrajectory > #shakeData.curTrajectory then
        shakeData.idxOfCurTrajectory = 1
    end
    assert(shakeData.idxOfCurTrajectory > 0 and shakeData.idxOfCurTrajectory <= #shakeData.curTrajectory)

    shakeData.shootTime = World.Now()
    local dropPoint = self:getDropPoint()
    World.Timer(self:getDropTime(), shakeDropPoint, self, from, dropPoint, timeToFrame(sdc.dropDuration))

    World.Timer(self:getStopShootTime(), shakeStop, self)

    local shootPoint = self:getShootPoint()
    self:changeCameraView(from, shootPoint, timeToFrame(sdc.shakeDuration))
end

function RaySkill:preCast(packet, from)
    SkillBase.preCast(self, packet, from)
    local from_isControl = from:isControl()
    if from_isControl and self.recoil then
        local recoil = self.recoil
        if type(recoil) == "table" then
            recoil = recoil.recoil
        end
        local currPitch = from:getRotationPitch()
        local _autoRecoverRecoil = self.autoRecoverRecoil
        if recoil then
            from:setMove(0, from:getPosition(), from:getRotationYaw(), currPitch - recoil, 1, 0)
        end
        if _autoRecoverRecoil then
            local subPitch
            local function tick()
				local curPitch = from:getRotationPitch()
                if _autoRecoverRecoil.value >= recoil then
                    from:setMove(0, from:getPosition(), from:getRotationYaw(), curPitch + recoil, 1, 0)
                    return false
                end
                subPitch = curPitch + _autoRecoverRecoil.value
                if subPitch>=currPitch then
                    return false
                end
                from:setMove(0, from:getPosition(), from:getRotationYaw(), subPitch, 1, 0)
                return true
            end
            World.Timer(_autoRecoverRecoil.time, tick)
        end
    end

    if packet.result then
        return
    end
    local screenPos = {x=0, y=0}
    if self.frontSight and self.isHitPointRandom then
        screenPos = FrontSight.randomPointByRrange()
    end
    local bi = Blockman.instance
	local screenSize = bi:getScreenSize()
    screenPos.x = screenPos.x + screenSize.w / 2
    screenPos.y = screenPos.y + screenSize.h / 2
    packet.result = bi:getRayTraceResult(screenPos, math.min(maxRayLength, self.rayLenth), 
        self.needLogicPositinToScreenPosition and true or false, self.hitEffect and true or false, self.trajectoryEffect and true or false, {})
    packet.result.mapId = World.CurMap.id
    if from_isControl and self.shakeType then
        shakeData.config = self
        local shakeType = shakeTypeMap[self.shakeType]
        assert(shakeType)
        from:setCD("net_delay", self.netDelay or 0)
        shakeType:shake(packet, from)
    end

    if from_isControl and self.cameraShake then
        local duration = self.cameraShake.duration
        local shakeTimes = self.cameraShake.shakeTimes
        local scaleX = self.cameraShake.scale.x or 0
        local scaleY = self.cameraShake.scale.y or 0
        local scaleZ = self.cameraShake.scale.z or 0
        local scale = Lib.v3(scaleX, scaleY, scaleZ)
        bi:addCameraShakeExtend(scale, duration, shakeTimes)
    end
end

function RaySkill:cast(packet, from)
    SkillBase.cast(self, packet, from)
    local result = packet.result
    local bi = Blockman.instance
    assert(result, "ray result is nil !!!")
    if result.aiRay then
		local entity = World.CurWorld:getEntity(result.objID)
		if not entity then
			return
		end
        local aiResult = bi:getAiRayResult(from:getPosition(), entity:getPosition())
        result.pitch = aiResult.pitch
        result.trajectoryYaw = aiResult.trajectoryYaw
        result.roll = aiResult.roll
    end
	local hitduration = self.hitduration or result.duration
    local hitEffect = self.hitEffect
	if result.hitHead and self.hitHeadEffect then
		hitEffect = self.hitHeadEffect
	end
    if hitEffect and hitEffect ~= "" then
        hitEffect = ResLoader:filePathJoint(self, hitEffect)
        bi:playEffectByPos(hitEffect, result.hitPos, result.yaw, hitduration)
    end
	local startPos = result.trajectoryPos
	local muzzleEffectScale = self.muzzleEffectScale
	local pv = bi:getCurrPersonView()
	if  self.startOffset and (from ~= Me or pv == 1) then
		local offset = self.startOffset
		local yaw = math.rad(from:getBodyYaw() + offset.yaw)
		local pitch = math.rad(offset.pitch)
		local pos = from:getEyePos()
		local len = offset.len
		pos.x = pos.x - math.sin(yaw) * math.cos(pitch) * len
		pos.y = pos.y - math.sin(pitch) * len
		pos.z = pos.z + math.cos(yaw) * math.cos(pitch) * len
		startPos = pos
	end
	if self.fPStartOffset and (Me == from and pv == 0) then
		local ri = Root.Instance()
		local offset = self.fPStartOffset
		muzzleEffectScale = offset.effectScale or muzzleEffectScale
        local screenPos = {x=ri:getRealWidth() / 2 + offset.x, y=ri:getRealHeight() / 2 + offset.y}
		local resultF = bi:getRayTraceResult(screenPos, offset.len or 1, false, false, true , {})
		startPos = resultF.oPosition
	end
	local duration = self.duration or result.duration
	local muzzleEffect = self.muzzleEffect
	if muzzleEffect then
		muzzleEffect = ResLoader:filePathJoint(self, muzzleEffect)
		bi:playEffectByPos(muzzleEffect, startPos, 0, duration, muzzleEffectScale)
	end

	local trajectoryEffect = self.trajectoryEffect
	if not trajectoryEffect then
		return
	end
	trajectoryEffect = ResLoader:filePathJoint(self, trajectoryEffect)
	if not self.dontPenetrate then
		bi:trajectoryEffect(trajectoryEffect, startPos,  result.pitch, result.trajectoryYaw, result.roll, duration)
	else
		bi:addBetweenEffect(trajectoryEffect, startPos, result.hitPos or result.farthest, duration)
	end
end

function RaySkill:canCast(packet, from)
    if not SkillBase.canCast(self, packet, from) then
        return false
    end

    if self.shakeType then
        local shakeType = shakeTypeMap[self.shakeType]
        assert(shakeType)
        if not shakeType:canCast(packet, from) then
            return false
        end
    end

    if self.enableRayTest then
        local ri = Root.Instance()
        local bi = Blockman.instance
        local screenPos = {x=ri:getRealWidth() / 2, y=ri:getRealHeight() / 2}
        local chestPos = from:getChestPos()
        local bi_viewerRenderYaw = bi:viewerRenderYaw()
        local chestRayLength = 1
        -- 趴着则修正胸口位置和射线长度
        if from.getCreepState and from:getCreepState() then
            chestPos.y = chestPos.y - 0.8
            chestRayLength = 2
        end

        -- 检测垂直胸口的射线，判断前方是否有碰撞
        local chestEndPos = chestPos + Lib.posAroundYaw({x = 0, y = 0, z = 1}, bi_viewerRenderYaw)
        local chestResult = bi:getClosestRayTraceResult(chestPos, chestEndPos, chestRayLength)
        if chestResult.hitPos then
            local rayTestLength = 150
            local rayStartPos = chestPos + Lib.posAroundYaw({x = -0.3, y = 0, z = 0}, bi_viewerRenderYaw)
            local screenRayTestResult = bi:getRayTraceResult(screenPos, rayTestLength, false, false, false , {})
            local rayTestResult = bi:getRayResultBetweenPosAndScreen(rayStartPos, screenPos, rayTestLength)
            if screenRayTestResult.hitPos then
                if not rayTestResult.hitPos then
                    return false
                end

                local v3ScreenResult = Lib.v3(screenRayTestResult.hitPos.x, screenRayTestResult.hitPos.y, screenRayTestResult.hitPos.z)
                local v3RayResult = Lib.v3(rayTestResult.hitPos.x, rayTestResult.hitPos.y, rayTestResult.hitPos.z)
                local v3Diff = v3ScreenResult - v3RayResult
                local diff = v3Diff:len()
                local tolerance = 1.0
                if diff > tolerance then
                    return false
                end
            else
                if rayTestResult.hitPos then
                    return false
                end
            end
        end
    end

    return true
end


