require 'common.class'

---@class Vector3 : cls
local Vector3 = class('Vector3')

local new = function(...)
    return Vector3.new(...)
end

function Vector3:ctor(x, y, z)
    self.x = x or 0
    self.y = y or 0
    self.z = z or 0
end

local function calc(left, right, operator)
    if type(left) == "number" then
        return new(operator(left, right.x), operator(left, right.y), operator(left, right.z))
    elseif type(right) == "number" then
        return new(operator(left.x, right), operator(left.y, right), operator(left.z, right))
    elseif type(right) == type(left) then
        return new(operator(left.x, right.x), operator(left.y, right.y), operator(left.z, right.z))
    end
end

---@return Vector3
function Vector3.__add(left, right)
    return calc(left, right, function(l, r)
        return l + r
    end)
end

---@return Vector3
function Vector3.__sub(left, right)
    return calc(left, right, function(l, r)
        return l - r
    end)
end

---@return Vector3
function Vector3.__mul(left, right)
    return calc(left, right, function(l, r)
        return l * r
    end)
end

---@return Vector3
function Vector3.__div(left, right)
    return calc(left, right, function(l, r)
        return l / r
    end)
end

---@return Vector3
function Vector3:__unm()
    return new(-self.x, -self.y, -self.z)
end

---@return Vector3
function Vector3:__eq(v3)
    return self.x == v3.x and self.y == v3.y and self.z == v3.z
end

---@return Vector3
function Vector3:__lt(v3)
    return self.x < v3.x and self.y < v3.y and self.z < v3.z
end

---@return Vector3
function Vector3:__le(v3)
    return self.x <= v3.x and self.y <= v3.y and self.z <= v3.z
end

---@return Vector3
function Vector3:__tostring()
    return string.format("Vector3: {%s,%s,%s}", self.x, self.y, self.z)
end

function Vector3:add(v3)
    self.x = self.x + v3.x
    self.y = self.y + v3.y
    self.z = self.z + v3.z
end

function Vector3:sub(v3)
    self.x = self.x - v3.x
    self.y = self.y - v3.y
    self.z = self.z - v3.z
end

function Vector3.lerp(a, b, t)
    return a + (b - a) * t
end

function Vector3:mul(n)
    assert(type(n) == "number")
    self.x = self.x * n
    self.y = self.y * n
    self.z = self.z * n
end

function Vector3:lenSqr(n)
    return self.x * self.x + self.y * self.y + self.z * self.z
end

function Vector3:len(n)
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function Vector3:unpack()
    return self.x, self.y, self.z
end

---@return Vector3
function Vector3:copy()
    return new(self.x, self.y, self.z)
end

---@return Vector3
function Vector3:clone()
    return self:copy()
end

function Vector3:isZero()
    return self.x == 0 and self.y == 0 and self.z == 0
end

function Vector3:inArea(v3, offset)
    return v3.x >= self.x - offset and v3.x <= self.x + offset
            and v3.y >= self.y - offset and v3.y <= self.y + offset
            and v3.z >= self.z - offset and v3.z <= self.z + offset
end

function Vector3:normalize()
    local len = self:len()
    if len > 0 then
        self:mul(1 / len)
    end
    return self
end

---@return Vector3
function Vector3:blockPos()
    return new(math.floor(self.x), math.floor(self.y), math.floor(self.z))
end

function Vector3:dot(rhs)
    --assert(classof(rhs) == 'Vector3', 'invalid operand type')
    return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z
end

---@return Vector3
function Vector3:cross(rhs)
    --assert(classof(rhs) == 'Vector3', 'invalid operand type')
    return new(
            self.y * rhs.z - self.z * rhs.y,
            self.z * rhs.x - self.x * rhs.z,
            self.x * rhs.y - self.y * rhs.x
    )
end

function Vector3:perpendicular()
    local temp = Vector3.new(1, 0, 0)
    local result = self:cross(temp)

    if result:isZero() then
        temp.x = 0
        temp.y = 1
        result = self:cross(temp)
    end
    result:normalize()

    return result;
end

---@return Vector3
function Vector3.fromTable(v3)
    return new(v3.x, v3.y, v3.z)
end

function Vector3.angle(v1, v2)
    local s = math.sqrt(Vector3.lenSqr(v1) * Vector3.lenSqr(v2))
    return math.acos(Vector3.dot(v1, v2) / s)
end

function Vector3.distance(va, vb)
    return math.sqrt((va.x - vb.x)^2 + (va.y - vb.y)^2 + (va.z - vb.z)^2)
end

function Vector3.Dot(lhs, rhs)
    return (((lhs.x * rhs.x) + (lhs.y * rhs.y)) + (lhs.z * rhs.z))
end

function Vector3.Cross(lhs, rhs)
    local x = lhs.y * rhs.z - lhs.z * rhs.y
    local y = lhs.z * rhs.x - lhs.x * rhs.z
    local z = lhs.x * rhs.y - lhs.y * rhs.x
    return Vector3.new(x,y,z)
end

function Vector3:toCEGUIPropetryString()
    return string.format(" x:%s y:%s z:%s", self.x, self.y, self.z)
end

---@return Vector3
function Lib.v3(x, y, z)
    return new(x, y, z)
end

function Lib.tov3(v3)
    return setmetatable(v3, Vector3)
end

---@return Vector3
function Lib.strToV3(str)
    if type(str) ~= "string" then
        return nil
    end
    local result = Lib.splitString(str, ",", true)
    return new(result[1], result[2], result[3])
end

function Lib.v3Hash(pos, map)
    local str = math.floor(pos.x) .. "," .. math.floor(pos.y) .. "," .. math.floor(pos.z)
    if type(map) == "table" then
        return map.name .. "," .. str
    else
        return tostring(map) .. "," .. str
    end
end

Vector3.up = Vector3.new(0, 1, 0)

return Vector3