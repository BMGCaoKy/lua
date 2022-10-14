require 'common.class'
---@class UDim2 : cls
---@field new fun(x1 : number, x2 : number, y1 : number, y2 : number)
UDim2 = class('UDim2')
local new = UDim2.new

local function checkArgsType(args)
    -- 检查所有参数的类型是否一致
    local argsType = classof(args[1])
    for _, v in pairs(args) do
        if argsType ~= classof(v) then
            assert("UDim2 invalid operand type !!!")
        end
    end
    return argsType
end

function UDim2:ctor(...)
    local args = { ... }
    local argsType = checkArgsType(args)
    local x, y
    if argsType == "number" then
        -- number xScale, number xOffset, number yScale, number yOffset
        x = UDim.new(args[1] or 0, args[2] or 0)
        y = UDim.new(args[3] or 0, args[4] or 0)
    elseif argsType == "UDim" then
        x = UDim.new(args[1].scale, args[1].offset)
        y = UDim.new(args[2].scale, args[2].offset)
    else
        assert("UDim2 error in type !!!")
    end
    self[1] = x
    self[2] = y
end

function UDim2.fromString(content)
    local udims = {}
    for _, v in pairs(Lib.parseUdimString(content)) do
        local args = Lib.splitString(v, ",", true)
        udims[#udims + 1] = UDim.new(args[1], args[2])
    end
    return new(udims[1], udims[2])
end

local __oldIndex = UDim2.__index
function UDim2:__index(key)
    if key == "x" or key == "width" then
        return self[1]
    elseif key == "y" or key == "height" then
        return self[2]
    end
    return rawget(self, key) or __oldIndex[key]
end

function UDim2:__newindex(key, value)
    if classof(value) ~= "UDim" then
        perror("UDim2 error in type !!!")
        return
    end
    if key == "x" or key == "width" then
        rawset(self, 1, value)
    elseif key == "y" or key == "height" then
        rawset(self, 2, value)
    else
        rawset(self, key, value)
    end
end

function UDim2.__add(lhs, rhs)
    local typelhs = classof(lhs)
    local typerhs = classof(rhs)
    if typelhs == 'number' then
        return new(rhs.x + lhs, rhs.y + lhs)
    elseif typerhs == 'number' then
        return new(lhs.x + rhs, lhs.y + rhs)
    elseif typelhs == 'UDim2' and typerhs == 'UDim2' then
        return new(lhs.x + rhs.x, lhs.y + rhs.y)
    end
    assert("UDim2 invalid operand type !!!")
end

function Lib.udim2(...)
    return new(...)
end

function UDim2.__sub(lhs, rhs)
    return lhs + (-rhs)
end

function UDim2.__mul(lhs, rhs)
    local typelhs = classof(lhs)
    local typerhs = classof(rhs)
    if typelhs == 'number' then
        return new(rhs.x * lhs, rhs.y * lhs)
    elseif typerhs == 'number' then
        return new(lhs.x * rhs, lhs.y * rhs)
    end
end

function UDim2.__div(lhs, rhs)
    local typelhs = classof(lhs)
    local typerhs = classof(rhs)
    if typelhs == 'number' then
        return new(rhs.x / lhs, rhs.y / lhs)
    elseif typerhs == 'number' then
        return new(lhs.x / rhs, lhs.y / rhs)
    end
end

function UDim2.__unm(value)
    return new(-value.x, -value.y)
end