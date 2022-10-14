--- engine_scene.lua
local BM = Blockman.Instance()
local CW = World.CurWorld
local GAME = CGame.instance

---@class engine_scene
local M = {
    on_drag = false,
}

function M:raycast(screenPos, length, mask, ignoreInstanceIds)
    local origin = Camera.getActiveCamera():getPosition()
    local world = World.CurMap:getPhysicsWorld()
    local directionResult = Blockman.Instance():getRaycastDirection(screenPos, true)
    local result = world:raycast(origin, directionResult.direction, length, 0, mask)
    if result and result.targetType ~= 0 and result.target and result.target:isValid() then
        for _, id in pairs(ignoreInstanceIds) do
            if id == result.target:getInstanceID() then
                return nil
            end
        end
        return result
    else
        return nil
    end
end

function M:raycastAll(screenPos, length, mask, ignoreInstanceIds)
    local origin = Camera.getActiveCamera():getPosition()
    local world = World.CurMap:getPhysicsWorld()
    local directionResult = Blockman.Instance():getRaycastDirection(screenPos, true)
    local result = world:raycastAll(origin, directionResult.direction, length, 0, mask)
    if result and result.targetType ~= 0 and result.target and result.target:isValid() and result.target.isInsteance == true then
        for _, id in pairs(ignoreInstanceIds) do
            if id == result.target:getInstanceID() then
                return nil
            end
        end
        return result
    else
        return nil
    end
end

function M:pick_rect(rect, filter)
    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)

    local screen_size = GAME:getWndSize()
    local l, t, r, b = rect.left/screen_size.x, rect.top/screen_size.y, rect.right/screen_size.x, rect.bottom/screen_size.y

    return scene:getRenderablesInScreenArea(l, t, r, b, true, false)
end

function M:move_parts(parts, displacement)
    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)
    scene.move(parts, displacement, true)
end

function M:move_parts_to(parts, pos_d)
    local pos_s = self:parts_center(parts)
    self:move_parts(parts, {x = pos_d.x - pos_s.x, y = pos_d.y - pos_s.y, z = pos_d.z - pos_s.z}, true)
end

function M:start_drag_parts(parts)
    local manager = CW:getSceneManager()
    self.on_drag = true
    manager:startMoveParts(parts)
end

function M:end_drag_parts()
    local manager = CW:getSceneManager()
    manager:endMoveParts()
    self.on_drag = false
end

function M:drag_parts(parts, x, y)
    local manager = CW:getSceneManager()
    manager:rayMoveParts(parts, {x = x, y = y}, 1000)
end

function M:scale_parts(parts, scale)
    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)
    scene.scale(parts, scale)
end

function M:rotate_parts(parts, aix, degree)
    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)
    scene.rotateAround(parts, aix, degree)
end

function M:parts_center(parts)
    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)
    local box = scene.getWorldAABB(parts, true)
    if box then
        return {
            x = box[2].x + (box[3].x - box[2].x) / 2,
            y = box[2].y + (box[3].y - box[2].y) / 2,
            z = box[2].z + (box[3].z - box[2].z) / 2,
        }
    else
        return {
            x = math.maxinteger,
            y = math.maxinteger,
            z = math.maxinteger
        }
    end
end

function M:parts_aabb(parts)
    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)
    local box = scene.getWorldAABB(parts, true)

    return box
end

function M:parts_bound(parts)
    local box = self:parts_aabb(parts)
    if box then
        return {
            min = {
                x = box[2].x,
                y = box[2].y,
                z = box[2].z
            },
            max = {
                x = box[3].x,
                y = box[3].y,
                z = box[3].z
            }
        }
    end
end

function M:parts_obb(parts, act_part, unionChildren)
    local manager = CW:getSceneManager()
    local scene = manager:getOrCreateScene(CW.CurMap.obj)
    local box = scene.getWorldOBB(parts, act_part, unionChildren)

    return box
end

function M:parts_obb_bound(parts, act_part)
    local box = self:parts_obb(parts, act_part, true)
    if box then
        return {
            min = {
                x = box[2].x,
                y = box[2].y,
                z = box[2].z
            },
            max = {
                x = box[3].x,
                y = box[3].y,
                z = box[3].z
            }
        }
    end
end

function M:parts_obb_bound_extra(parts, act_part)
    local box = self:parts_obb(parts, act_part, true)
    return box
end

return M