require 'common.class'

---@class Vector2
local Vector2 = class('Vector2')

local new = function(...)
    return Vector2.new(...)
end

function Vector2:ctor(x, y)
    self.x = x or 0
    self.y = y or 0
end

local function calc(left, right, operator)
    if type(left) == "number" then
        return new(operator(left, right.x), operator(left, right.y))
    elseif type(right) == "number" then
        return new(operator(left.x, right), operator(left.y, right))
    elseif type(left) == type(right) then
        return new(operator(left.x, right.x), operator(left.y, right.y))
    end
end

function Vector2.__add(left, right)
    return calc(left, right, function(l, r)
        return l + r
    end)
end

function Vector2.__sub(left, right)
    return calc(left, right, function(l, r)
        return l - r
    end)
end

function Vector2.__mul(left, right)
    return calc(left, right, function(l, r)
        return l * r
    end)
end

function Vector2.__div(left, right)
    return calc(left, right, function(l, r)
        return l / r
    end)
end

function Vector2:__unm()
    return new(-self.x, -self.y)
end

function Vector2:__eq(v2)
    return self.x == v2.x and self.y == v2.y
end

function Vector2:__lt(v2)
    return self.x < v2.x and self.y < v2.y
end

function Vector2:__le(v2)
    return self.x <= v2.x and self.y <= v2.y
end

function Vector2:__tostring()
    return string.format("Vector2: {%s,%s}", self.x, self.y)
end

function Vector2:add(v2)
    self.x = self.x + v2.x
    self.y = self.y + v2.y
end

function Vector2:sub(v2)
    self.x = self.x - v2.x
    self.y = self.y - v2.y
end

function Vector2.lerp(a, b, t)
    return a + (b - a) * t
end

function Vector2:mul(n)
    assert(type(n) == "number")
    self.x = self.x * n
    self.y = self.y * n
end

function Vector2:lenSqr(n)
    return self.x * self.x + self.y * self.y
end

function Vector2:len(n)
    return math.sqrt(self.x * self.x + self.y * self.y)
end

function Vector2:unpack()
    return self.x, self.y
end

---@return Vector2
function Vector2:copy()
    return new(self.x, self.y)
end

---@return Vector2
function Vector2:clone()
    return self:copy()
end

function Vector2:isZero()
    return self.x == 0 and self.y == 0
end

function Vector2:inArea(v2, offset)
    return v2.x >= self.x - offset and v2.x <= self.x + offset
            and v2.y >= self.y - offset and v2.y <= self.y + offset
end

function Vector2:normalize()
    local len = self:len()
    if len > 0 then
        self:mul(1 / len)
    end
    return self
end

---@return Vector2
function Vector2:blockPos()
    return new(math.floor(self.x), math.floor(self.y), math.floor(self.z))
end

function Vector2:dot(rhs)
    assert(classof(rhs) == 'Vector2', 'invalid operand type')
    return self.x * rhs.x + self.y * rhs.y
end

---@return Vector2
function Vector2.fromTable(v2)
    return new(v2.x, v2.y)
end

---@return Vector2
function Lib.v2(x, y)
    return new(x, y)
end

function Lib.tov2(v2)
    return setmetatable(v2, Vector2)
end

---@return Vector2
function Lib.strToV2(str)
    if type(str) ~= "string" then
        return nil
    end
    local result = Lib.splitString(str, ",", true)
    return new(result[1], result[2])
end

function Lib.v2Hash(pos, map)
    local str = math.floor(pos.x) .. "," .. math.floor(pos.y)
    if type(map) == "table" then
        return map.name .. "," .. str
    else
        return tostring(map) .. "," .. str
    end
end

return Vector2