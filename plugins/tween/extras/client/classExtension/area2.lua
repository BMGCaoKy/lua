
Lib.class("Area2")

---@param ... any like : ( {x = {1,99}} ), ( {{1,99}, {2,99}} ),  (5)
---@return player like : {{1, 100}, {1, 100}, {1, 100}, {1, 100}}
local function _toArray(args, array)
    local array = array or {}

    if type(args) == "number" then
        for i = 1, 4 do
            array[i] = {args, args}
        end
    else
        local isHash
        for key, value in pairs(args) do
            if type(key) ~= "number" then
                isHash = true
                break
            end
        end
    
        if isHash then
            array[1] = args.x
            array[2] = args.y
            array[3] = args.width
            array[4] = args.height
        else
            for i, v in ipairs(args) do
                array[i] = v
            end
        end
    end

    return array
end

local function _clac(self, other, operator)
    local reslut = {}

    self = _toArray(self)
    other = _toArray(other)

    for i = 1, 4 do
        local selfV = self[i]
        local otherV = other[i]
        if not selfV then selfV = otherV end
        if not otherV then otherV = selfV end

        if selfV and otherV then
            reslut[i] = operator(selfV, otherV)
        end
    end

    return Area2.new(reslut)
end

function Area2:ctor(...)
    local args = {...}
    
    if #args == 1 then
        args = args[1]
    end

    _toArray(args, self)
end

function Area2:toHash()
    return {
        x = self[1],
        y = self[2],
        width = self[3],
        height = self[4]
    }
end

function Area2:toArray()
    return {
        [1] = self[1],
        [2] = self[2],
        [3] = self[3],
        [4] = self[4]
    }
end

function Area2.__add(self, other)
    return _clac(self, other, function(x, y) 
        return {x[1] + y[1], x[2] + y[2]}
    end)
end

function Area2.__sub(self, other)
    return _clac(self, other, function(x, y) 
        return {x[1] - y[1], x[2] - y[2]}
    end)
end

function Area2.__mul(self, other)
    return _clac(self, other, function(x, y) 
        return {x[1] * y[1], x[2] * y[2]}
    end)
end

function Area2.__div(self, other)
    return _clac(self, other, function(x, y) 
        return {x[1] / y[1], x[2] / y[2]}
    end)
end

function Area2.__unm(self)
    return self * -1
end

function Area2.__tostring(self)
    local function arrStr(t)
        return string.format("{%0.2f, %0.2f}", t[1], t[2])
    end
    
    return string.format("{x = %s, y = %s, width = %s, height = %s}", 
        arrStr(self[1]), arrStr(self[2]), arrStr(self[3]), arrStr(self[4]))
end
