local function XPCall(func, ...)
    if not func then
        return
    end
    
    xpcall(func, debug.traceback, ...)
end

local function XPCallByPackArgs(func, args)
    if not func then
        return
    end

    xpcall(func, debug.traceback, table.unpack(args))
end

local function extends(super)
     local class = setmetatable({}, {__index = super})
     return class, super
end

local function new(class, ...)
    local instance = setmetatable({}, {__index = class})
    XPCall(instance.init, instance, ...)
    return instance
end

return {
    XPCall = XPCall,
    XPCallByPackArgs = XPCallByPackArgs,
    extends = extends,
    new = new
}