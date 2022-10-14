local Utils = require "common.api.util"

function MovableNode:Rotate(rotation, isWorldSpace)
    if isWorldSpace then
        self:rotate(rotation)
    else
        self:rotateInLocalSpace(rotation)
    end
end

function MovableNode:Move(displacement, isWorldSpace)
    if isWorldSpace then
        self:move(displacement)
    else
        self:moveInLocalSpace(displacement)
    end
end

local fieldMap = 
{
    WorldPosition = {get = "getPosition", set = "setPosition", getTypeFunc = Utils.ToNewVector3},
    WorldRotation = {get = "getRotation", set = "setRotation", getTypeFunc = Utils.ToNewVector3},
    WorldScale = {get = "getScale", set = "setScale", getTypeFunc = Utils.ToNewVector3},
    LocalPosition = {get = "getLocalPosition", set = "setLocalPosition", getTypeFunc = Utils.ToNewVector3},
    LocalRotation = {get = "getLocalRotation", set = "setLocalRotation", getTypeFunc = Utils.ToNewVector3},
    LocalScale = {get = "getLocalScale", set = "setLocalScale", getTypeFunc = Utils.ToNewVector3},
    ForwardVector = {get = "getForwardVector", set = "setForwardVector", getTypeFunc = Utils.ToNewVector3},
    UpVector = {get = "getUpVector", set = "setUpVector", getTypeFunc = Utils.ToNewVector3},
    LeftVector = {get = "getLeftVector", set = "setLeftVector", getTypeFunc = Utils.ToNewVector3},
    
    RotateAround = {func = "rotateAroundPoint"},
}

APIProxy.RegisterFieldMap(fieldMap)