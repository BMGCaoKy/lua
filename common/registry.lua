---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Administrator.
--- DateTime: 2021/4/11 0:50
---

local Registry = class("Registry")

Registry._classes = {}
Registry._objects = {}

function Registry.add(cls, name)
    assert(type(cls) == "table" and cls.__cname ~= nil, "Registry.add() - invalid class")
    if not name then name = cls.__cname end
    assert(Registry._classes[name] == nil, string.format("Registry.add() - class \"%s\" already exists", tostring(name)))
    Registry._classes[name] = cls
end

function Registry.remove(name)
    assert(Registry._classes[name] ~= nil, string.format("Registry.remove() - class \"%s\" not found", name))
    Registry._classes[name] = nil
end

function Registry.get(name)
    return Registry._classes[name]
end

function Registry.exists(name)
    return Registry._classes[name] ~= nil
end

function Registry.newObject(name, ...)
    local cls = Registry._classes[name]
    if not cls then
        -- auto load
        pcall(function()
            cls = require(name)
            Registry.add(cls, name)
        end)
    end
    assert(cls ~= nil, string.format("Registry.newObject() - invalid class \"%s\"", tostring(name)))
    return cls.new(...)
end

function Registry.setObject(object, name)
    assert(Registry._objects[name] == nil, string.format("Registry.setObject() - object \"%s\" already exists", tostring(name)))
    assert(object ~= nil, "Registry.setObject() - object \"%s\" is nil", tostring(name))
    Registry._objects[name] = object
end

function Registry.getObject(name)
    assert(Registry._objects[name] ~= nil, string.format("Registry.getObject() - object \"%s\" not exists", tostring(name)))
    return Registry._objects[name]
end

function Registry.removeObject(name)
    assert(Registry._objects[name] ~= nil, string.format("Registry.removeObject() - object \"%s\" not exists", tostring(name)))
    Registry._objects[name] = nil
end

function Registry.isObjectExists(name)
    return Registry._objects[name] ~= nil
end

return Registry