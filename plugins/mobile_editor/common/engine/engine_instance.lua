--- engine_instance.lua
---@class engine_instance
local M = {}

M.INSTANCECOLOR = {
    SELECT	= {255 / 255, 54 / 255, 245 / 255, 1.0},
    HOVER	= {245 / 255, 173 / 255, 50 / 255, 1.0}
}

function M:set(inst, name, val)
    return inst:setProperty(name, val)
end

function M:get(inst, name)
    return inst:getProperty(name)
end

function M:id(inst)
    return inst:getInstanceID()
end

function M:set_hover(inst, flag)
    if self:get(inst, "isSelectInEditor") == "true" then
        return
    end
    if self:get(inst, "isLockedInEditor") == "true" then
        return
    end
    assert(inst.setIsRenderBox, inst:getTypeName())
    if flag then
        inst:setRenderBoxColor(M.INSTANCECOLOR.HOVER)
        inst:setIsRenderBox(true)
    else
        inst:setIsRenderBox(false)
    end
end

function M:set_selectable(inst, flag)
    return inst:setSelectable(flag)
end

function M:set_select(inst, flag)
    if inst:isA("Force") then
        inst:setDebugGraphShow(flag)
    elseif inst:isA("Torque") then
        inst:setDebugGraphShow(flag)
    elseif inst:isA("ConstraintBase") then
        inst:setDebugGraphShow(flag)
    elseif inst:isA("BasePart") then
        inst:setRenderBoxColor(M.INSTANCECOLOR.SELECT)
        inst:setIsRenderBox(flag)
    elseif inst:isA("Entity") then
        if flag then
            inst:setEdge(true, { 1.0, 209.0 / 255, 26.0 / 255, 1.0 })
        else
            inst:setEdge(false, {1.0, 0, 0, 1.0})
        end
    elseif inst:isA("DropItem") then
        inst:setIsRenderBox(flag)
    elseif inst:isA("Model") then
        inst:setIsRenderBox(flag)
    elseif inst:isA("RegionPart") then
        self:set(inst, "isSelectInEditor", tostring(flag))
    end
end

function M:getClassName(inst)
    local className = nil
    if inst:isA("Part") then
        className = "Part"
    elseif inst:isA("MeshPart") then
        className = "MeshPart"
    elseif inst:isA("Model") then
        className = "Model"
    elseif inst:isA("PartOperation") then
        className = "PartOperation"
    end

    return className
end

function M:set_world_pos(inst, pos)
    return inst:setWorldPos(pos)
end

function M:position(inst)
    return inst:getPosition()
end

function M:rotation(inst)
    return inst:getRotation()
end

function M:transform(inst)
    return inst:getWorldTransform()
end

function M:get_volume(inst)
    return inst:getVolume()
end

function M:set_shape(part, shape)
    return part:setShape(shape)
end

function M:set_parent(part, parent)
    return part:setParent(parent)
end

function M:get_parent(inst)
    return inst:getParent()
end

function M:set_size_x(part, len)
    part:setSizeX(len)
end

function M:set_size_y(part, len)
    part:setSizeY(len)
end

function M:set_size_z(part, len)
    part:setSizeZ(len)
end

function M:size(part)
    return part:getSize()
end

function M:destroy(inst)
    inst:destroy()
end

function M:rotation(inst)
    return inst:getRotation()
end

return M