---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Anybook.
--- DateTime: 2022/5/16 18:00
---
local adapter = {}
local mapping = {
    ["boolean"] = {
        getter = function(params)
            local ins, key = params[1], params[2]
            return ins[key] and 1 or 0
        end,
        setter = function(params, value)
            local ins, key = params[1], params[2]
            if value == 0 then
                ins[key] = false
            elseif value == 1 then
                ins[key] = true
            end
        end,
        to = function(params)
            return params[3] and 1 or 0
        end
    },
    ["string"] = {
        getter = function()
            return 0
        end,
        setter = function(params, value)
            local ins, key = params[1], params[2]
            local str = Lib.subString(params[3], math.ceil(value))
            ins[key] = str
        end,
        to = function(params)
            return Lib.getStringLen(params[3])
        end
    }
}

local function typeReferee(params)
    local ins, key = params[1], params[2]
    local val = ins[key]
    local typ = classof(val)
    return typ
end

function adapter:getter(params)
    local ins, key = params[1], params[2]
    local map = mapping[typeReferee(params)]
    if map and map.getter then
        return function()
            return map.getter(params)
        end
    else
        return function()
            return ins[key]
        end
    end
end

function adapter:setter(params)
    local ins, key = params[1], params[2]
    local map = mapping[typeReferee(params)]
    if map and map.setter then
        return function(val)
            map.setter(params, val)
        end
    else
        return function(val)
            ins[key] = val
        end
    end
end

function adapter:to(params)
    local to = params[3]
    local map = mapping[typeReferee(params)]
    if map and map.to then
        return map.to(params)
    else
        return to
    end
end

return adapter