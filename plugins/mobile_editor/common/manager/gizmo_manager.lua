--- gizmo_manager.lua
--- gizmo的管理器
---
---@class GizmoManager : singleton
local GizmoManager = T(MobileEditor, "GizmoManager")
---@type engine_scene
local IScene = require "common.engine.engine_scene"
---@type engine_instance
local IInstance = require "common.engine.engine_instance"
---@type PartTransformHelper
local PartTransformHelper = require "common.helper.part_transform_helper"
---@type util
local util = require "common.util.util"
---@type GameManager
local GameManager = T(MobileEditor,"GameManager")
---@type CommandManager
local CommandManager = T(MobileEditor,"CommandManager")
---@type UIManager
local UIManager = T(MobileEditor, "UIManager")

local last = nil
function GizmoManager:initialize()
    DebugDraw.instance:setEnabled(true)
    DebugDraw.instance:setDrawSelectedPartAABBEnabled(true)

    self.transformType = Define.TRANSFORM_TYPE.NONE
    self.mode = Define.SPACE_MODE.LOCAL
    self.targets = {}
    self.objects = nil

    self.prevPos = {}
    self.prevAxis = nil
    self.prevDegree = 0
    self.degreeInterval = 15
    self.prevOffset = Lib.v3()
    self.prevStretch = nil

    self:subscribeEvents()
end

function GizmoManager:finalize()

end

local function calcSceneGizmoUIPosition(self)
    if not self.targets or not next(self.targets) then
        return
    end
    local nodes = GameManager:instance():getNodes(self.targets)
    local obb = util:getObbBoundExtra(nodes)
    if not obb or not next(obb) then
        return
    end
    local r = obb[1]
    local pos = obb[4]
    local axis1 = obb[5]
    local axis2 = obb[6]
    local axis3 = obb[7]
    --[[
          / 8------------- / 4                     / 0--------- --- / v4
         / |              /  |                    / |              /  |
        /  |             /   |                   /  |             /   |
        7--|-------------3   |                  v5--|------------ v2  |
        |  |             |   |                  |   |             |   |
        |  6 ------------|---2                  |   v6 ---------- |--v1
        | /              |  /                   | /               |  /
        |/               | /                    |/                | /
       5 ----------------1/                    v3 ---------------0/
    ]]
    local vec = {
        pos - r.x * axis1 - r.y * axis2 - r.z * axis3,
        pos - r.x * axis1 - r.y * axis2 + r.z * axis3,
        pos - r.x * axis1 + r.y * axis2 - r.z * axis3,
        pos - r.x * axis1 + r.y * axis2 + r.z * axis3,
        pos + r.x * axis1 - r.y * axis2 - r.z * axis3,
        pos + r.x * axis1 - r.y * axis2 + r.z * axis3,
        pos + r.x * axis1 + r.y * axis2 - r.z * axis3,
        pos + r.x * axis1 + r.y * axis2 + r.z * axis3,
    }
    local v1 = vec[2] - vec[1]
    local v2 = vec[3] - vec[1]
    local v3 = vec[5] - vec[1]
    local v4 = vec[4] - vec[8]
    local v5 = vec[7] - vec[8]
    local v6 = vec[6] - vec[8]

    local normalVector = {
        v6:cross(v5):normalize(), -- left
        v2:cross(v3):normalize(), -- front
        v3:cross(v1):normalize(), -- down
        v1:cross(v2):normalize(), -- right
        v5:cross(v4):normalize(), -- up
        v4:cross(v6):normalize(), -- back
    }

    local mainCamera = CameraManager.Instance():findCamera('mainCamera')
    local lookAt = mainCamera:getPosition() - pos
    local pitch, yaw, roll = mainCamera:getOrientation():toEulerAngle()
    while (yaw < 0) do
        yaw = yaw + 360
    end
    yaw = yaw % 360
    local cos = 0
    local curIndex = 0
    for index, normal in pairs(normalVector) do
        local c = lookAt:normalize():dot(normal)
        if c > 0 and c > cos then
            cos = c
            curIndex = index
        end
    end
    if curIndex <= 0 then
        return
    end
    local planeList = {
        {
            vec[8],
            vec[7],
            vec[6],
            vec[5]
        },
        {
            vec[7],
            vec[3],
            vec[5],
            vec[1]
        },
        {
            vec[2],
            vec[6],
            vec[1],
            vec[5]
        },
        {
            vec[3],
            vec[4],
            vec[1],
            vec[2]
        },
        {
            vec[8],
            vec[4],
            vec[7],
            vec[3]
        },
        {
            vec[4],
            vec[8],
            vec[2],
            vec[6]
        }
    }

    local plane = planeList[curIndex]
    if curIndex == 5 then
        if 0 < yaw and yaw <= 45 then
            plane = {
                vec[3],
                vec[7],
                vec[4],
                vec[8]
            }
        elseif 45 < yaw and yaw <= 135 then
            plane = {
                vec[4],
                vec[3],
                vec[8],
                vec[7],
            }
        elseif 135 < yaw and yaw <= 225 then
            plane = {
                vec[8],
                vec[4],
                vec[7],
                vec[3]
            }
        elseif 225 < yaw and yaw <= 315 then
            plane = {
                vec[7],
                vec[8],
                vec[3],
                vec[4]
            }
        elseif 315 < yaw and yaw <= 360 then
            plane = {
                vec[3],
                vec[7],
                vec[4],
                vec[8]
            }
        end
    end

    local DEG2RAD = 0.01745329
    local rotateList = {
        Vector3.new(0, 90 * DEG2RAD , 0),
        Vector3.new(0, 0, 0),
        Vector3.new(-90 * DEG2RAD, 0, 0),
        Vector3.new(0, -90 * DEG2RAD, 0),
        Vector3.new(90 * DEG2RAD, 0, 0),
        Vector3.new(0, 180 * DEG2RAD, 0),
    }

    UIManager:instance().sceneGizmoRotate:setPosition(plane[2])
    UIManager:instance().sceneGizmoRotate:setRotation(rotateList[curIndex])

    UIManager:instance().sceneGizmoMove:setPosition(plane[3])
    UIManager:instance().sceneGizmoMove:setRotation(rotateList[curIndex])

    UIManager:instance().sceneGizmoScale:setPosition(plane[4])
    UIManager:instance().sceneGizmoScale:setRotation(rotateList[curIndex])

    Lib.emitEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI_DATA, plane, rotateList, curIndex)
end

function GizmoManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_UPDATE_SPACE, function(mode)
        self.mode = mode
        if self.transformType ~= Define.TRANSFORM_TYPE.NONE then
            local center = GameManager:instance():getCenter(self.targets)
            self:switch(center)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_SHOW_GIZMO, function(targets)
        self.targets = targets
        local enableTranslate = false
        local translateObjects  = GameManager:instance():all(self.targets, function(node)
            return node:checkAbility(Define.ABILITY.TRANSLATE)
        end)

        if Lib.getTableSize(translateObjects) > 0 then
            enableTranslate = true
        end
        local enableRotate = false
        local rotateObjects  = GameManager:instance():all(self.targets, function(node)
            return node:checkAbility(Define.ABILITY.ROTATE)
        end)

        if Lib.getTableSize(rotateObjects) > 0 then
            enableRotate = true
        end
        local enableScale = false
        local scaleObjects  = GameManager:instance():all(self.targets, function(node)
            return node:checkAbility(Define.ABILITY.SCALE)
        end)

        if Lib.getTableSize(scaleObjects) > 0 then
            enableScale = true
        end

        if self.transformType ~= Define.TRANSFORM_TYPE.NONE then
            if (self.transformType == Define.TRANSFORM_TYPE.TRANSLATE and enableTranslate == true) or (self.transformType == Define.TRANSFORM_TYPE.ROTATE and enableRotate == true) or (self.transformType == Define.TRANSFORM_TYPE.SCALE and enableScale == true) then
                local center = GameManager:instance():getCenter(self.targets)
                self:switch(center)
            else
                if self.node then
                    self.node:destroy()
                    self.node = nil
                end
            end
        end
    end)

    Lib.subscribeEvent(Event.EVENT_SWITCH_GIZMO, function(type)
        self.transformType = type
        if self.transformType == Define.TRANSFORM_TYPE.NONE then
            if self.node then
                self.node:destroy()
                self.node = nil
            end
        else
            local center = GameManager:instance():getCenter(self.targets)
            self:switch(center)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_HIDE_GIZMO, function()
        if self.node then
            self.node:destroy()
            self.node = nil
        end

        self.targets = {}
        --self.transformType = Define.TRANSFORM_TYPE.NONE
    end)

    Lib.subscribeEvent(Event.EVENT_MOVE_GIZMO, function()
        if self.node then
            local center = GameManager:instance():getCenter(self.targets)
            self.node:setPosition(center)
            Lib.emitEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_ROTATE_GIZMO, function()
        if self.node then
            local target = self.targets[#self.targets]
            local node = GameManager:instance():getNode(target)
            if node then
                local rotation = node:getRotation()
                if rotation then
                    self.node:setRotationXYZ(rotation)
                    Lib.emitEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI)
                end
            end
        end
    end)

    Lib.subscribeEvent(Event.EVENT_SCALE_GIZMO, function()
        if self.node then
            local center = GameManager:instance():getCenter(self.targets)
            self.node:setPosition(center)
            Lib.emitEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI, function()
        calcSceneGizmoUIPosition(self)
    end)
end

function GizmoManager:switch(pos)
    last = nil
    local manager = World.CurWorld:getSceneManager()
    if self.node then
        self.node:destroy()
        self.node = nil
    end

    self.mode = Define.SPACE_MODE.LOCAL
    if self.transformType == Define.TRANSFORM_TYPE.TRANSLATE then
        self.node = GizmoTransformMove.createWithParameter(6, 0.1, 0.5, 1.5, 0.25, 0.5, false, false)
        self.node:setMoveInterval(0.25)
        self.mode = Define.SPACE_MODE.WORLD
    elseif self.transformType == Define.TRANSFORM_TYPE.ROTATE then
        self.node = GizmoTransformRotate.createWithParameter(26, 196)
        self.node:setDegreeInterval(self.degreeInterval)
        self.node:setShowAxis(0)
    elseif self.transformType == Define.TRANSFORM_TYPE.SCALE then
        self.node = GizmoTransformScale.createWithParameter(6, 0.1, 0.5, 1.5, 0.2, false)
        self.node:setScaleInterval(0.25)
    end

    if self.mode == Define.SPACE_MODE.LOCAL then
        local target = self.targets[#self.targets]
        local node = GameManager:instance():getNode(target)
        if node then
            local rotation = node:getRotation()
            if rotation then
                self.node:setRotationXYZ(rotation)
            end
        end
    end

    self.node:setHighLightColor(Lib.v3(242 / 255, 242 / 255, 242 / 255))
    self.node:setAxisColor(0, Lib.v3(253 / 255, 131 / 255, 152 / 255))
    self.node:setAxisColor(1, Lib.v3(150 / 255, 251 / 255, 165 / 255))
    self.node:setAxisColor(2, Lib.v3(132 / 255, 197 / 255, 253 / 255))

    self.node:setPosition(pos)
    manager:setGizmo(self.node)
end

function GizmoManager:isShow()
    return self.node ~= nil
end

local function getDiff(type, ...)
    if type == Define.TRANSFORM_TYPE.TRANSLATE then
        local offset = ...
        last = last or { x = 0, y = 0, z = 0}
        local diff = {
            x = offset.x - last.x,
            y = offset.y - last.y,
            z = offset.z - last.z
        }
        return diff, offset
    elseif type == Define.TRANSFORM_TYPE.SCALE then
        local offset = ...
        last = last or { x = 0, y = 0, z = 0}
        local diff = {
            x = offset.x - last.x,
            y = offset.y - last.y,
            z = offset.z - last.z
        }
        return diff, offset
    elseif type == Define.TRANSFORM_TYPE.ROTATE then
        local degress = ...
        last = last or 0.0
        local diff = degress - last
        return diff, degress
    end
end

function GizmoManager:handleEventBegin()
    last = nil
    self.prevPos = {}
    self.prevAxis = nil
    self.prevDegree = 0
    self.prevOffset = Lib.v3()
    self.prevStretch = nil
    self.objects = nil

    self.objects = GameManager:instance():filter(self.targets, function(node)
        return node:checkAbility(Define.ABILITY.AABB)
    end, true)

    if self.transformType == Define.TRANSFORM_TYPE.TRANSLATE  then
        for _, object in pairs(self.objects) do
            self.prevPos[object:getInstanceID()] = object:getPosition()
        end
    elseif self.transformType == Define.TRANSFORM_TYPE.SCALE then
        local nodes = GameManager:instance():getNodes(self.targets)
        local bounds = util:getBound(nodes)
        self.beginBounds = bounds
    elseif self.transformType == Define.TRANSFORM_TYPE.ROTATE then

    end
end

local function testMoveBound(bounds, diff, floorBound)
    local newBound = {
        min = {
            x = bounds.min.x + diff.x,
            y = bounds.min.y + diff.y,
            z = bounds.min.z + diff.z,
        },
        max = {
            x = bounds.max.x + diff.x,
            y = bounds.max.y + diff.y,
            z = bounds.max.z + diff.z,
        }
    }
    if newBound.min.x >= floorBound.min.x
    and newBound.min.y >= floorBound.min.y
    and newBound.min.z >= floorBound.min.z
    and newBound.max.x <= floorBound.max.x
    and newBound.max.y <= floorBound.max.y
    and newBound.max.z <= floorBound.max.z then
        return true
    end

    return false
end

local function inArea(p, center, floorBound)
    p = p + center

    if p.x >= floorBound.min.x
            and p.y >= floorBound.min.y
            and p.z >= floorBound.min.z
            and p.x <= floorBound.max.x
            and p.y <= floorBound.max.y
            and p.z <= floorBound.max.z then
        return true
    end

    return false
end

local function testRotateBound(axis, center, bounds, floorBound, degree)
    local rotate = Quaternion.rotateAxis(axis, degree)
    -- 默认的旋转中心为世界坐标中心轴
    -- 在这里因为是局部旋转，所以旋转中心要以AABB中心为旋转点
    -- 需要把AABB的8个点 -center 偏移
    -- 最后旋转完再 + center 偏移
    local vec = {
        Vector3.fromTable({x = bounds.min.x, y = bounds.min.y, z = bounds.min.z}) - center,
        Vector3.fromTable({x = bounds.min.x, y = bounds.min.y, z = bounds.max.z}) - center,
        Vector3.fromTable({x = bounds.max.x, y = bounds.min.y, z = bounds.max.z}) - center,
        Vector3.fromTable({x = bounds.max.x, y = bounds.min.y, z = bounds.min.z}) - center,
        Vector3.fromTable({x = bounds.max.x, y = bounds.max.y, z = bounds.max.z}) - center,
        Vector3.fromTable({x = bounds.max.x, y = bounds.max.y, z = bounds.min.z}) - center,
        Vector3.fromTable({x = bounds.min.x, y = bounds.max.y, z = bounds.min.z}) - center,
        Vector3.fromTable({x = bounds.min.x, y = bounds.max.y, z = bounds.max.z}) - center,
    }

    for _, p in pairs(vec) do
        if not inArea( rotate * p, center, floorBound) then
            return false
        end
    end

    return true
end

function GizmoManager:handleEventMove(...)
    local floorBound = GameManager:instance():getFloorBound()
    local nodes = GameManager:instance():getNodes(self.targets)
    local bounds = util:getBound(nodes)
    local center = GameManager:instance():getCenter(self.targets)

    if self.transformType == Define.TRANSFORM_TYPE.TRANSLATE then
        local offset = ...
        local diff, cur = getDiff(Define.TRANSFORM_TYPE.TRANSLATE, offset)
        if testMoveBound(bounds, diff, floorBound) then
            IScene:move_parts(self.objects, diff)
            last = cur
        end
        Lib.emitEvent(Event.EVENT_MOVE_GIZMO)
    elseif self.transformType == Define.TRANSFORM_TYPE.ROTATE then
        local axis_t, degree = ...
        local diff, cur = getDiff(Define.TRANSFORM_TYPE.ROTATE, degree)
        local axis = {
            x = axis_t == 1 and 1 or 0,
            y = axis_t == 2 and 1 or 0,
            z = axis_t == 3 and 1 or 0
        }

        if self.mode == Define.SPACE_MODE.LOCAL then
            local rotate = Quaternion.fromEulerAngleVector(self.node:getRotationXYZ())
            local v3 = Vector3.fromTable(axis)
            axis = rotate * v3
        end

        if testRotateBound(axis, center, bounds, floorBound, degree) then
            self.prevAxis = axis
            self.prevDegree = self.prevDegree + diff
            if diff ~= 0.0 then
                Lib.logDebug("ROTATE diff = ", diff)
                IScene:rotate_parts(self.objects, self.prevAxis, diff)
                last = cur
            end
        end
        Lib.emitEvent(Event.EVENT_ROTATE_GIZMO)
    elseif self.transformType == Define.TRANSFORM_TYPE.SCALE then
        local axis, scale, stretch = ...
        --Lib.logDebug("SCALE handleEventMove axis and scale and stretch = ", axis, scale, stretch)
        local diff, cur = getDiff(self.transformType, scale)
        local rotate = Quaternion.fromEulerAngleVector(self.node:getRotationXYZ())
        local extra = {
            bounds = bounds,
            center = center,
            floorBound = floorBound,
            rotate = rotate,
            func = function(canScale)
                if canScale then
                    self.prevAxis = axis
                    self.prevOffset = Lib.v3(self.prevOffset.x + diff.x, self.prevOffset.y + diff.y, self.prevOffset.z + diff.z)
                    self.prevStretch = stretch
                end
                last = cur
                Lib.emitEvent(Event.EVENT_SCALE_GIZMO)
            end
        }
        PartTransformHelper.getScale(self.objects, axis, diff, stretch == 1, extra)
    end
end

function GizmoManager:handleEventEnd()
    if self.transformType == Define.TRANSFORM_TYPE.TRANSLATE then
        local CommandTranslate = require "common.command.command_translate"
        CommandManager:instance():register(CommandTranslate:new(self.targets, self.prevPos))
    elseif self.transformType == Define.TRANSFORM_TYPE.ROTATE then
        local CommandRotate = require "common.command.command_rotate"
        CommandManager:instance():register(CommandRotate:new(self.targets, self.prevAxis, self.prevDegree, self.degreeInterval))
    elseif self.transformType == Define.TRANSFORM_TYPE.SCALE then
        local CommandScale = require "common.command.command_scale"
        if self.beginBounds then
            local stretch = self.prevStretch
            local nodes = GameManager:instance():getNodes(self.targets)

            local temp_axis
            temp_axis = self.prevAxis == 1 and "x" or self.prevAxis == 2 and "y" or "z"
            local bounds = util:getBound(nodes)
            local beginSize = self.beginBounds.max[temp_axis] - self.beginBounds.min[temp_axis]
            local curSize = bounds.max[temp_axis] - bounds.min[temp_axis]
            if curSize >= beginSize then
                stretch = 1
            else
                stretch = 0
            end
            CommandManager:instance():register(CommandScale:new(self.targets, self.prevAxis, self.prevOffset, stretch))
        end
    end
end

return GizmoManager