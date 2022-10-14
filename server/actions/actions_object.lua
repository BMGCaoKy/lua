local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.GetObject(data, params, context)
    if ActionsLib.isNil(params.objID, "ObjectID") then
        return
    end
    return World.CurWorld:getObject(params.objID)
end

function Actions.GetObjectID(data, params, context)
    local object = params.object
    if ActionsLib.isInvalidInstance(object, "Object") then
        return
    end
    return object.objID
end

function Actions.IsValidObject(data, params, context)
    local object = params.object
    return object and object:isValid() or false
end

function Actions.SameObj(node, params, context)
    return params.entity == params.entity2
end

function Actions.GetObjectDistance(data, params, context)
    local obj1, obj2 = params.obj1, params.obj2
    if ActionsLib.isInvalidInstance(obj1, "Object1") or ActionsLib.isInvalidInstance(obj2, "Object2") then
        return
    end
    return obj1:distance(obj2)
end

function Actions.AddObjectAura(data, params, context)
    local name = assert(params.name or params.cfgName)
    return params.obj1:addAura(name, params)
end
