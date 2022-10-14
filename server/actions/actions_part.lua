local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"


function Actions.SetPartPosition(data, params, context)
    local part = params.part
    local targetPos = params.pos
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(targetPos, "Position") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    if ActionsLib.isEmptyString(params.map, "Map") then
        return
    end
    local map = World.CurWorld:getMap(params.map)
    if ActionsLib.isInvalidMap(map) then
        return
    end
    local manager = World.CurWorld:getSceneManager()
    local mapScene = manager:getOrCreateScene(map.obj)
    local partScene = part:getScene()
    if mapScene:getRoot() ~= partScene:getRoot() then
        part:setParent(mapScene:getRoot())
    end
    part:setPosition(targetPos)
end

function Actions.AddPartForce(data, params, context)
    local part = params.part
    local force = params.force
    if part:isStaticBatch() then
        return
    end
    part:applyCentralForce(force)
end

function Actions.AddPartTorque(data, params, context)
    local part = params.part
    local torque = params.torque
    if part:isStaticBatch() then
        return
    end
    part:applyTorque(torque)
end

function Actions.GetPartPosition(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    return part.position
end

function Actions.SetPartRotation(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setRotation(Lib.v3(params.pitch, params.yaw, params.roll))
end

function Actions.GetPartRotation(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    return part.rotation
end

function Actions.SetPartSize(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(params.size, "Size") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setSize(params.size)
end

function Actions.GetPartSize(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    return part:getSize()
end

function Actions.SetPartShape(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(params.shapeId, "Shape") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setShape(params.shapeId)
end

function Actions.SetPartAlpha(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(params.alpha, "Alpha") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setAlpha(params.alpha)
end

function Actions.SetPartColor(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setColor(params.color)
end

function Actions.SetPartMaterialTexture(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isEmptyString(params.material, "MaterialTexture") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setMaterialPath(params.material)
end

function Actions.SetPartMaterialOffset(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setUV(Lib.v3(params.ux, params.vy, 1))
end

function Actions.SetPartUseCollide(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    if part:isStaticBatch() then
        return
    end
    local useCollide = (params.useCollide~=nil and {params.useCollide} or {true})[1]
    part:setUseCollide(useCollide)
    return useCollide
end

function Actions.Action_SetPartStaticObject(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    if part:isStaticBatch() then
        return
    end
    local staticObject = (params.staticObject~=nil and {params.staticObject} or {true})[1]
    part:setStaticObject(staticObject)
    return staticObject
end

function Actions.Action_SetPartSelectable(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    local selectable = (params.selectable~=nil and {params.selectable} or {true})[1]
    part:setSelectable(selectable)
    return selectable
end

function Actions.Action_SetPartNeedSync(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    local needSync = (params.needSync~=nil and {params.needSync} or {true})[1]
    part:setNeedSync(needSync)
    return needSync
end

function Actions.Action_SetPartBloom(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    local bloom = (params.bloom~=nil and {params.bloom} or {true})[1]
    part:setBloom(bloom)
    return bloom
end

function Actions.SetPartUseGravity(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    if part:isStaticBatch() then
        return
    end
    local useGravity = (params.useGravity~=nil and {params.useGravity} or {true})[1]
    part:setUseGravity(useGravity)
    return useGravity
end

function Actions.GetPartConstraintByName(data, params, context)
    local part = params.part
    local name = params.name
    if ActionsLib.isInvalidPart(part) or ActionsLib.isEmptyString(name) then
        return
    end
    if part:isStaticBatch() then
        return
    end
    local constraints = part:getAllConstrainPtr()
    for _, cst in pairs(constraints) do
        if cst:getName() == name then
            return cst
        end
    end
    return nil
end

function Actions.SetPartConstraintEnable(data, params, context)
    local constraint = params.cst
    if ActionsLib.isInvalidInstance(constraint, "Constraint") then
        return
    end
    local val = (params.val~=nil and {params.val} or {true})[1]
    constraint:setEnable(val)
    if not val and constraint:isA("FixedConstraint") then
        constraint:setParent(nil)
    end
    return val
end

function Actions.SetPartLineVelocity(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(params.lv, "LineVelocity") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setLineVelocity(params.lv)
end

function Actions.GetPartLineVelocity(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    return part.lineVelocity
end

function Actions.SetPartAngleVelocity(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(params.av, "AngleVelocity") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setAngleVelocity(params.av)
end

function Actions.GetPartAngleVelocity(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    return part.angleVelocity
end


function Actions.SetPartDensity(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(params.density, "Density") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setDensity(params.density)
end

function Actions.GetPartDensity(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    return part.density
end


function Actions.SetPartRestitution(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(params.density, "Restitution") then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setRestitution(params.rst)
end

function Actions.GetPartRestitution(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    return part.restitution
end

function Actions.SetPartFriction(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) or ActionsLib.isNil(params.friction, "Friction")then
        return
    end
    if part:isStaticBatch() then
        return
    end
    part:setFriction(params.friction)
end

function Actions.GetPartFriction(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    return part.friction
end

function Actions.CreatePart(data, params, context)
  if ActionsLib.isEmptyString(params.map, "Map") or ActionsLib.isEmptyString(params.name) then
      return
  end
  if ActionsLib.isNil(params.pos, "Position") or ActionsLib.isNil(params.size, "Size") then
      return
  end
  if ActionsLib.isEmptyString(params.material, "Material") or ActionsLib.isNil(params.shapeId, "Shape") then
      return
  end
  local map = World.CurWorld:getMap(params.map)
  if ActionsLib.isInvalidMap(map) then
      return
  end
  local part = Instance.Create("Part")
  part:setName(params.name)
  part:setShape(params.shapeId)
  part:setColor(params.color)
  part:setMaterialPath(params.material)
  part:setSize(params.size)
  local manager = World.CurWorld:getSceneManager()
  local scene = manager:getOrCreateScene(map.obj)
  part:setPosition(params.pos)
  part:setRotation(params.pitch, params.yaw, params.roll)
  part:setParent(scene:getRoot())
  return part
end

function Actions.DestoryPart(data, params, context)
    local part = params.part
    if ActionsLib.isInvalidPart(part) then
        return
    end
    part:destroy()
end

function Actions.GetPartByID(data, params, context)
    local partID = params.id
    if not partID then
        return
    end
    return Instance.getByInstanceId(partID)
end

function Actions.CreatePartByPartStorage(data, params, context)
    if ActionsLib.isEmptyString(params.map, "Map") then
        return
    end

    local partID = params.id
    local map = World.CurWorld:getMap(params.map) or params.map
    if not partID or not params.pos or not map then
        return
    end

    local partStorage = Game.GetService("PartStorage")
    local part = partStorage:getByInstanceId(partID)
    if not part then
        return
    end
    Trigger.CheckTriggers(part._cfg, "PART_CREATED", {part = part})

    local scene = World.CurWorld:getScene(map.obj)
    part:setPosition(params.pos)
    part:setParent(scene:getRoot())
end
