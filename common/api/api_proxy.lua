function APIProxy.getPropertyFuncMap()
    if not APIProxy.PropertyFuncMap then
        APIProxy.PropertyFuncMap = {}
    end
    return APIProxy.PropertyFuncMap
end

function APIProxy.RegisterFieldMap(fieldMap)
    local map = APIProxy.getPropertyFuncMap()
    for k, v in pairs(fieldMap) do
        map[k] = v
    end
end

local function getMetaProxy(class, proxyTb, staticAPITb)
    proxyTb = proxyTb or {}

    local meta = {}
    for k, v in pairs(class) do
        meta[k] = v
    end

    meta.__index = function(t, k)
        if proxyTb[k] then
            if type(proxyTb[k]) == "table" and proxyTb[k].get then
                return proxyTb[k].get(t, k)
            end
        else
            return class[k]
        end
    end

    meta.__newindex = function(t, k, v)
        if staticAPITb and staticAPITb[k] then
            Lib.logError(string.format("Set %s failed, %s is read only!", k, k))
            return
        end
        if proxyTb[k] then
            if not proxyTb[k].set then
                Lib.logError(string.format("Set %s failed, %s is read only!", k, k))
                return
            end
            proxyTb[k].set(t, v)
        else
            rawset(t, k, v)
        end
    end

    return meta
end

local function addStaticAPI(class, apiTb)
    apiTb = apiTb or {}
    setmetatable(class, {
        __index = function(_, k)
            if apiTb[k] and apiTb[k].get then
                return apiTb[k].get(class, k)
            else
                return rawget(class, k)
            end
        end,
        __newindex = function(_, k, v)
            if apiTb[k] and type(apiTb[k]) == "table" then
                if apiTb[k].set then
                    apiTb[k].set(class, v)
                else
                    Lib.logError(string.format("Set %s failed, %s is read only!", k, k))
                    return
                end
            else
                rawset(class, k, v)
            end
        end
    })
end

function APIProxy.OverrideAPI(class, proxyTb, staticAPITb)
    addStaticAPI(class, staticAPITb)

    local meta = getMetaProxy(class, proxyTb, staticAPITb)
    if class.new then
        class.new = function(...)
            local instance = setmetatable({}, meta)
            instance:ctor(...)
            return instance
        end
    end
    return meta
end

local function _declareMetaMethod(class, name, f)
    if f == nil then
        return class[name]
    end
    local metaMethod = class[name]
    class[name] = function(self, key)
        if type(metaMethod) == "function" and metaMethod(self, key) then
            return (metaMethod(self, key))
        elseif type(metaMethod) == "table" and metaMethod[key] then
            return metaMethod[key]
        elseif type(f) == "function" then
            return (f(self, key))
        else
            return f[key]
        end
    end
end

local function _includeMixin(class, mixin)
    for k, f in pairs(mixin) do
        if k == "__index" then
            _declareMetaMethod(class, k, f)
        else
            class[k] = f
        end
    end
end

function APIProxy.Include(class, ...)
    if type(class) ~= "table" then
        return
    end
    for _, mixin in pairs({ ... }) do
        _includeMixin(class, mixin)
    end
end