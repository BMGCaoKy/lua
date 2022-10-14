require 'common.class'
---@type Vector3
local Vector3 = require 'common.math.vector3'
---@class Quaternion
local Quaternion = class('Quaternion')

local sqrt = math.sqrt
local abs = math.abs
local deg = math.deg
local rad = math.rad
local atan = math.atan
local asin = math.asin
local sin = math.sin
local cos = math.cos
local new = Quaternion.new

function Quaternion:ctor(w, x, y, z)
    self.w = w or 1
    self.x = x or 0
    self.y = y or 0
    self.z = z or 0
end

function Quaternion.__add(lhs, rhs)
    local typelhs = classof(lhs)
    local typerhs = classof(rhs)
    if typelhs == 'number' then
        return new(
            lhs + rhs.w,
            lhs + rhs.x,
            lhs + rhs.y,
            lhs + rhs.z
        )
    elseif typerhs == 'number' then
        return new(
            lhs.w + rhs,
            lhs.x + rhs,
            lhs.y + rhs,
            lhs.z + rhs
        )
    elseif typelhs == 'Quaternion' and typerhs == 'Quaternion' then
        return new(
            lhs.w + rhs.w,
            lhs.x + rhs.x,
            lhs.y + rhs.y,
            lhs.z + rhs.z
        )
    end
    error("invalid operand type")
end

function Quaternion.__sub(lhs, rhs)
    return lhs + (-rhs)
end

function Quaternion:__unm()
    return new(-self.w, -self.x, -self.y, -self.z)
end

function Quaternion.__mul(lhs, rhs)
    local typelhs = classof(lhs)
    local typerhs = classof(rhs)
    if typelhs == 'number' then
        return new(
            lhs * rhs.w,
            lhs * rhs.x,
            lhs * rhs.y,
            lhs * rhs.z
        )
    elseif typerhs == 'number' then
        return new(
            lhs.w * rhs,
            lhs.x * rhs,
            lhs.y * rhs,
            lhs.z * rhs
        )
    elseif typelhs == 'Quaternion' and typerhs == 'Quaternion' then
        return new(
            lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
            lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            lhs.w * rhs.y + lhs.y * rhs.w + lhs.z * rhs.x - lhs.x * rhs.z,
            lhs.w * rhs.z + lhs.z * rhs.w + lhs.x * rhs.y - lhs.y * rhs.x
        )
    elseif typelhs == 'Quaternion' and typerhs == 'Vector3' then
        -- nVidia SDK implementation
        local qvec = Vector3.new(lhs.x, lhs.y, lhs.z)
        local uv = qvec:cross(rhs)
        local uuv = qvec:cross(uv)
        return rhs + 2 * lhs.w * uv + 2 * uuv
    end
    error("invalid operand type")
end

function Quaternion.__div(lhs, rhs)
    assert(type(rhs) == 'number', "invalid operand")
    return lhs * (1 / rhs)
end

function Quaternion:lenSqr()
    return self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z
end

function Quaternion:len()
    return sqrt(self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z)
end

---@return Quaternion
function Quaternion.rotateAxis(v3, degree)
    v3 = Lib.v3normalize(v3)
    degree = degree * 0.5
    local s = math.sin(math.rad(degree))
    local w = math.cos(math.rad(degree))
    local x = s * v3.x
    local y = s * v3.y
    local z = s * v3.z
    return new(w, x, y, z)
end

-- ZXY extrinsic rotation (equivalent to YXZ, or yaw pitch roll order in instrinsic rotation)
function Quaternion:toEulerAngle()
    local w, x, y, z = self.w, self.x, self.y, self.z
    local sinPitch = 2 * (w * x - y * z)
    local GIMBAL_LOCK_THRESHOLD = 0.0001;
    if 1 - abs(sinPitch) < GIMBAL_LOCK_THRESHOLD then
        -- 当pitch接近90度或-90度时，发生万向锁，需要特殊处理。这个时候只要roll + yaw等于一个固定值，roll和yaw可以是任意值。我们不妨将roll设置为0
        local roll = 0
        local pitch = sinPitch > 0 and 90 or -90
        local cosYaw = 1 - 2 * (y * y + z * z)
        local sinYaw = 2 * (w * y - x * z)
        local yaw = deg(atan(sinYaw, cosYaw))
        return pitch, yaw, roll
    end
    local roll = deg(atan(2 * (w * z + x * y), 1 - 2 * (z * z + x * x)))
    local pitch = deg(asin(2 * (w * x - y * z)))
    local yaw = deg(atan(2 * (w * y + z * x), 1 - 2 * (x * x + y * y)))
    return pitch, yaw, roll
end

-- ZXY extrinsic rotation (equivalent to YXZ, or yaw pitch roll order in instrinsic rotation)
---@return Quaternion
function Quaternion.fromEulerAngle(pitch, yaw, roll)
    local hPitch = rad(pitch) * 0.5
    local hYaw = rad(yaw) * 0.5
    local hRoll = rad(roll) * 0.5

    local cosHPitch = cos(hPitch);
    local sinHPitch = sin(hPitch);
    local cosHYaw = cos(hYaw);
    local sinHYaw = sin(hYaw);
    local cosHRoll = cos(hRoll)
    local sinHRoll = sin(hRoll)

    return new(
        cosHRoll * cosHPitch * cosHYaw + sinHRoll * sinHPitch * sinHYaw,
        cosHRoll * sinHPitch * cosHYaw + sinHRoll * cosHPitch * sinHYaw,
        cosHRoll * cosHPitch * sinHYaw - sinHRoll * sinHPitch * cosHYaw,
        sinHRoll * cosHPitch * cosHYaw - cosHRoll * sinHPitch * sinHYaw
    )
end

---@return Quaternion
function Quaternion.fromEulerAngleVector(v3)
    return Quaternion.fromEulerAngle(v3.x, v3.y, v3.z)
end

---@return Quaternion
function Quaternion.fromTable(v4)
    return new(v4.w, v4.x, v4.y, v4.z)
end

---@return Quaternion
function Quaternion.fromVectorRotation(from, to)
    from, to = from:copy(), to:copy()
    from:normalize()
    to:normalize()

    local normal = from:cross(to)
    if normal:isZero() then
        -- parallel case
        if from:dot(to) > 0 then
            return new()
        else
            return Quaternion.rotateAxis(from:perpendicular(), 180)
        end
    end

    normal:normalize()

    local cosAngle = from:dot(to)
    local angle2 = math.acos(cosAngle) / 2;

    local sin2 = math.sin(angle2);
    local cos2 = math.cos(angle2);

    return new(
        cos2,
        normal.x * sin2,
        normal.y * sin2,
        normal.z * sin2
    )
end

---@return Quaternion
function Quaternion.lookRotation(forward, upwards)
    if not upwards then
        upwards = Lib.v3(0, 1, 0) -- up
    end
    return Quaternion.fromVectorRotation(upwards, forward)
end

---@return Quaternion
function Quaternion:cross(rhs)
    assert(classof(rhs) == 'Quaternion', 'invalid operand type')
    local w, x, y, z = self.w, self.x, self.y, self.z
    return new(
        w * rhs.w - x * rhs.x - y * rhs.y - z *rhs.z,
        w * rhs.x + x * rhs.w + y * rhs.z - z *rhs.y,
        w * rhs.y + y * rhs.w + z * rhs.x - x *rhs.z,
        w * rhs.z + z * rhs.w + x * rhs.y - y *rhs.x
    )
end

function Quaternion:dot(rhs)
    return self.w * rhs.w + self.x * rhs.x + self.y * rhs.y + self.z * rhs.z
end

---@return Quaternion
function Quaternion:conjugated()
    return new(self.w, -self.x, -self.y, -self.z)
end

---@return Quaternion
function Quaternion:normalized()
    local len = self:len()
    return new(self.w / len, self.x / len, self.y / len, self.z / len)
end

function Quaternion:__tostring()
    return string.format("Quaternion: {%s,%s,%s,%s}", self.w, self.x, self.y, self.z)
end

function Quaternion.fromCEGUIPropetryString(str)
    local params = Lib.deserializerStrQuaternion(str)
    if type(params) == "table" and params.w and params.x and params.y and params.z then
        return Quaternion.new(params.w, params.x, params.y, params.z)
    else
        return Quaternion.new(1, 0, 0, 0)
    end
end

function Quaternion:toCEGUIPropetryString()
    return string.format(" w:%s x:%s y:%s z:%s", self.w, self.x, self.y, self.z)
end

return Quaternion