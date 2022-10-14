require 'common.class'
local Color3 = class('Color3')

local new = function(...)
    return Color3.new(...)
end

local function checkValid(r, g, b, minLimit, maxLimit)
    local function isValid(value)
        return value >= minLimit and value <= maxLimit
    end
    local errorText = 'Color3 Parameter error, rang is [' .. minLimit .. ", " .. maxLimit .. "]"
    assert(isValid(r) and isValid(g) and isValid(b), errorText)
end

function Color3:ctor(red, green, blue)
    -- 参数区间范围在[0, 1]
    red = red or 0
    green = green or 0
    blue = blue or 0
    checkValid(red, green, blue, 0, 1)
    self.r = red
    self.g = green
    self.b = blue
    self.a = 1
end

function Color3.fromRGB(red, green, blue)
    -- 参数区间范围在[0, 255]
    checkValid(red, green, blue, 0, 255)
    return new(red / 255, green / 255, blue / 255)
end

local function toString(r, g, b)
    assert(r and g and b, 'need new Color3 !!!')
    local hexR, hexG, hexB
    hexR = string.format('%02X', math.ceil(r * 255))
    hexG = string.format('%02X', math.ceil(g * 255))
    hexB = string.format('%02X', math.ceil(b * 255))
    return 'FF' .. hexR .. hexG .. hexB
end

function Lib.ucolor3(...)
    return new(...)
end

function Color3:__tostring()
    return toString(self.r, self.g, self.b)
end

local function calc(left, right, operator)
    if type(left) == "number" then
        return new(operator(left, right.r), operator(left, right.g), operator(left, right.b))
    elseif type(right) == "number" then
        return new(operator(left.r, right), operator(left.g, right), operator(left.b, right))
    else
        return new(operator(left.r, right.r), operator(left.g, right.g), operator(left.b, right.b))
    end
end

function Color3.__add(left, right)
    return calc(left, right, function(l, r)
        return l + r
    end)
end

function Color3.__sub(left, right)
    return calc(left, right, function(l, r)
        return l - r
    end)
end

function Color3.__mul(left, right)
    return calc(left, right, function(l, r)
        return l * r
    end)
end

function Color3.__div(left, right)
    return calc(left, right, function(l, r)
        return l / r
    end)
end

function Color3.__unm(self)
    return self * -1
end