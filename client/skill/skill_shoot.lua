local SkillBase = Skill.GetType("Base")
local Shoot = Skill.GetType("Shoot")

Shoot.shootType = "default"

local defaultType = {}

local shootTypeMap = { ["default"] = defaultType,}

local shootTime = 0
local curTrajectory = {}
local idxOfCurTrajectory = 0
local idxOfTrajectorys = 0
local shooting = false
local config = {}

local function timeToFrame(time)
    assert(type(time) == "number")
    local frame = time * 20.0
    return math.floor(frame + 0.5) -- 四舍五入取整
end

function defaultType:canCast(packet, from)
    local sloter = from:getHandItem()
    if config.handItem and not (sloter and sloter:cfg().fullName == config.handItem) then
        return false
    end

    if shootTime > 0 then
        local elapseTime = World.Now() - shootTime
        if elapseTime < timeToFrame(config.shakeDuration) then 
            return false
        end
    end
    return true
end

function defaultType:getShootPoint()
    local shootPoint = {}
    local x = self:getTrajectoryX(idxOfTrajectorys, idxOfCurTrajectory)
    local y = self:getTrajectoryY(idxOfTrajectorys, idxOfCurTrajectory)
    -- 原点为(0, 0)
    local preX = idxOfCurTrajectory-1 ~= 0 and self:getTrajectoryX(idxOfTrajectorys, idxOfCurTrajectory-1) or 0
    local preY = idxOfCurTrajectory-1 ~= 0 and self:getTrajectoryY(idxOfTrajectorys, idxOfCurTrajectory-1) or 0
    local yaw = x - preX
    local pitch = y - preY
    shootPoint.yaw = yaw * config.shakeCoefficient
    shootPoint.pitch = -pitch * config.shakeCoefficient
    return shootPoint
end


function defaultType:getDropPoint()
    local dropPoint = {}
    local dropDistance = self:getTrajectoryY(idxOfTrajectorys, idxOfCurTrajectory) / 2.0
    dropPoint.yaw = 0
    dropPoint.pitch = dropDistance  * config.shakeCoefficient
    return dropPoint
end


function defaultType:reset()
    shootTime = 0
    curTrajectory = {}
    idxOfCurTrajectory = 0
    idxOfTrajectorys = 0
    shooting = false
    config = {}
end

function defaultType:stop()
    local elapseTime = World.Now() - shootTime
    if elapseTime >= self:getStopShootTime() then
        self:reset()
    end
    return false
end

function defaultType:dropPoint(from, dropPoint, smooth)
    local elapseTime = World.Now() - shootTime
    if elapseTime >= self:getDropTime() then
        self:changeCameraView(from, dropPoint, smooth)
    end
    return false
end

function defaultType:changeCameraView(from, point, smooth)
    local curPitch = from:getRotationPitch()
    local curYaw = from:getRotationYaw()
    local curPosition = from:getPosition()
    local finalYaw = curYaw + point.yaw
    local finalPitch = curPitch + point.pitch
    from:changeCameraView(curPosition, finalYaw, finalPitch, nil, smooth)
end

function defaultType:getTrajectoryX(idxOfTrajectorys, idxOfCurTrajectory)
    local coordinate = config.trajectorys[idxOfTrajectorys][idxOfCurTrajectory]
    assert(coordinate)
    local x = coordinate[1]
    return x
end

function defaultType:getTrajectoryY(idxOfTrajectorys, idxOfCurTrajectory)
    local coordinate = config.trajectorys[idxOfTrajectorys][idxOfCurTrajectory]
    assert(coordinate)
    local y = coordinate[2]
    return y
end

function defaultType:getDropTime()
    return timeToFrame(config.shakeDuration) + timeToFrame(config.dropTime)
end

function defaultType:getStopShootTime()
    return timeToFrame(config.shakeDuration) + timeToFrame(config.stopShootTime)
end

function defaultType:shoot(packet, from)
    if not shooting then
        shooting = true
        idxOfTrajectorys = math.random(1, #config.trajectorys)
        curTrajectory = config.trajectorys[idxOfTrajectorys]
        assert(next(curTrajectory))
    end

    idxOfCurTrajectory  = idxOfCurTrajectory + 1
    if idxOfCurTrajectory > #curTrajectory then
        idxOfCurTrajectory = 1
    end
    assert(idxOfCurTrajectory > 0 and idxOfCurTrajectory <= #curTrajectory)

    shootTime = World.Now()
    local dropPoint = self:getDropPoint()
    World.Timer(self:getDropTime(), Shoot.dropPoint, self, from, dropPoint, timeToFrame(config.dropDuration))

    World.Timer(self:getStopShootTime(), Shoot.stop, self)

    local shootPoint = self:getShootPoint()
    self:changeCameraView(from, shootPoint, timeToFrame(config.shakeDuration))
end



function Shoot:canCast(packet, from)
    local shootType = shootTypeMap[self.shootType] or shootTypeMap["default"]
    assert(shootType)
    if not shootType:canCast(packet, from) then
        return false
    end
    if not SkillBase.canCast(self, packet, from) then return false end
    return true
end

function Shoot.stop(shootType)
    return shootType:stop()
end

function  Shoot.dropPoint(shootType, from, dropPoint, smooth)
    return shootType:dropPoint(from, dropPoint, smooth)
end


function Shoot:preCast(packet, from)
    SkillBase.preCast(self, packet, from)
    if from:isControl() then
        config = self
        local shootType = shootTypeMap[config.shootType] or shootTypeMap["default"]
        assert(shootType)
        from:setCD("net_delay", config.netDelay or 0)
        shootType:shoot(packet, from)
    end
end

function Shoot:cast(packet, from)
    SkillBase.cast(self, packet, from)
end
