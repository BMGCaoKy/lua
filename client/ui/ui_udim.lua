require 'common.class'
UDim = class('UDim')
local new = UDim.new

function UDim:ctor(scale, offset)
    self.scale = scale or 0
    self.offset = offset or 0
end

function UDim.fromString(content)
    local udimString = Lib.parseUdimString(content)
    local args = Lib.splitString(udimString, ",", true)
    return new(args[1], args[2])
end

local __oldIndex = UDim.__index
function UDim:__index(key)
    if key == "scale" then
        return self[1]
    elseif key == "offset" then
        return self[2]
    end
    return rawget(self, key) or __oldIndex[key]
end

function UDim:__newindex(key, value)
    if key == "scale" then
        rawset(self, 1, value)
    elseif key == "offset" then
        rawset(self, 2, value)
    else
        rawset(self, key, value)
    end
end

function UDim.__add(lhs, rhs)
    local typelhs = classof(lhs)
    local typerhs = classof(rhs)
    if typelhs == 'number' then
        return new(rhs.scale, lhs + rhs.offset)
    elseif typerhs == 'number' then
        return new(lhs.scale, lhs.offset + rhs)
    elseif typelhs == 'UDim' and typerhs == 'UDim' then
        return new(lhs.scale + rhs.scale, lhs.offset + rhs.offset)
    end
    assert("UDim invalid operand type !!!")
end

function UDim.__sub(lhs, rhs)
    return lhs + (-rhs)
end

function UDim.__unm(value)
    return new(-value.scale, -value.offset)
end

function UDim.__mul(lhs, rhs)
    local typelhs = classof(lhs)
    local typerhs = classof(rhs)
    if typelhs == 'number' then
        return new(rhs.scale * lhs, rhs.offset * lhs)
    elseif typerhs == 'number' then
        return new(lhs.scale * rhs, lhs.offset * rhs)
    end
end

function UDim.__div(lhs, rhs)
    local typelhs = classof(lhs)
    local typerhs = classof(rhs)
    if typelhs == 'number' then
        return new(rhs.scale / lhs, rhs.offset / lhs)
    elseif typerhs == 'number' then
        return new(lhs.scale / rhs, lhs.offset / rhs)
    end
end
