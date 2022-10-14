--- camera_manager.lua
--- 相机的管理器
---
---@alias MobileEditorCameraManager IMobileEditorCameraManager | singleton | FirstPersonState | ThirdPersonState
---@class IMobileEditorCameraManager : Stateful
local CameraManager = T(MobileEditor, "CameraManager")
CameraManager:addState("FirstPerson", require "common.state.camera.first_person_state")
CameraManager:addState("ThirdPerson", require "common.state.camera.third_person_state")

local BM = Blockman.Instance()
---@type GameManager
local GameManager = T(MobileEditor, "GameManager")
---@type util
local util = require "common.util.util"

function CameraManager:initialize()
    self.width = GUISystem.instance:GetScreenWidth()
    self.height = GUISystem.instance:GetScreenHeight()
--    self.speed = 1.0
    self.pinchRatio = 1 / 72
    self.minHeight = 0
    self.maxHeight = 32
    self.curPos = nil
    self.curYaw = nil
    self.curPitch = nil
    self.minPitch = 15
    self.maxPitch = 90
    self.target = nil
    self:subscribeEvents()
end

function CameraManager:finalize()

end

function CameraManager:setTarget(pos)
    self.target = pos
    --BM:setViewerLookAt(self.target)
    self.curYaw = BM:getViewerYaw()
    self.curPitch = BM:getViewerPitch()
    self.curPos = BM:getViewerPos()
end

local function inArea(point, floorBound)
    local cameraAreaOffset = World.CurMap.cfg.cameraAreaOffset or 0
    if point.x >= (floorBound.min.x - cameraAreaOffset)
    and point.y >= (floorBound.min.y - cameraAreaOffset)
    and point.z >= (floorBound.min.z - cameraAreaOffset)
    and point.x <= (floorBound.max.x + cameraAreaOffset)
    and point.y <= (floorBound.max.y + cameraAreaOffset)
    and point.z <= (floorBound.max.z + cameraAreaOffset) then
        return true
    end
    return false
end

function CameraManager:setFocus(center, size)
    local yaw, pitch = self.curYaw, self.curPitch
    local dist = size ^ 0.5
    local ryaw, rpitch = math.rad(yaw), math.rad(pitch)
    local hl = dist * math.cos(rpitch)
    local pos = {
        x = center.x + hl * math.sin(ryaw),
        y = center.y + dist * math.sin(rpitch),
        z = center.z - hl * math.cos(ryaw)
    }

    local floorBound = GameManager:instance():getFloorBound()
    if inArea(pos, floorBound) then
        BM:setViewerPos(pos, self.curYaw, self.curPitch, 1)
        self:setTarget(center)
    end
end

function CameraManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_TOGGLE_CAMERA, function()
        Lib.logDebug("EVENT_TOGGLE_CAMERA")
        if self:getCurrentState() == "FirstPerson" then
            Lib.logDebug("ThirdPerson")
            self:gotoState("ThirdPerson")
        elseif self:getCurrentState() == "ThirdPerson" then
            Lib.logDebug("FirstPerson")
            self:gotoState("FirstPerson")
        end
    end)

    Lib.subscribeEvent(Event.EVENT_SET_CAMERA, function(pos, yaw, pitch, smooth)
        local floorBound = GameManager:instance():getFloorBound()
        if inArea(pos, floorBound) then
            self.curPos = pos
            self.curYaw = yaw
            self.curPitch = pitch
            BM:setViewerPos(self.curPos, self.curYaw, self.curPitch, smooth)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_TURN_CAMERA, function(target, axis, angle)
        --Lib.logDebug("EVENT_TURN_CAMERA angle = ", angle)
        local direction = self.curPos - target
        local rotate = Quaternion.rotateAxis(axis, angle)
        local nextPos = rotate * direction + target
        local floorBound = GameManager:instance():getFloorBound()
        if inArea(nextPos, floorBound) then
            self.curPos = nextPos
            self.curYaw = self.curYaw - angle
            BM:setViewerPos(self.curPos, self.curYaw, self.curPitch, 0)
            Lib.emitEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_PAN_CAMERA, function(delta)
        delta = Lib.v3(util:clamp(delta.x, -5, 5), delta.y, util:clamp(delta.z, -5, 5))
        local floorBound = GameManager:instance():getFloorBound()
        local nextPos = self.curPos + delta * World.cfg.panSpeed
        if inArea(nextPos, floorBound) then
            self.curPos = nextPos
            BM:setViewerPos(self.curPos, self.curYaw, self.curPitch, 0)
            Lib.emitEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_PINCH_CAMERA, function(delta)
        --Lib.logDebug("EVENT_PINCH_CAMERA delta = ", delta)
        delta = delta * self.pinchRatio
        local rotate = Quaternion.fromEulerAngle(self.curPitch, self.curYaw, 0)
        local diff = rotate * Vector3.fromTable({ x = 0, y = 0, z = 1 })
        local nextPos = Lib.v3()
        nextPos.x = self.curPos.x - diff.x * World.cfg.turnSpeed * delta
        nextPos.z = self.curPos.z + diff.z * World.cfg.turnSpeed * delta
        nextPos.y = self.curPos.y + diff.y * World.cfg.turnSpeed * delta

        local offset = 7    -- cameraInitPos和地面的距离
        if delta > 0 then
            local minDistance = self.minHeight + offset
            if nextPos.y <= World.cfg.cameraInitPosOffset.y + minDistance then
                return
            end
        else
            local maxDistance = self.maxHeight + offset
            if nextPos.y >= World.cfg.cameraInitPosOffset.y + maxDistance then
                return
            end
        end

        local floorBound = GameManager:instance():getFloorBound()
        if inArea(nextPos, floorBound) then
            self.curPos = nextPos
            BM:setViewerPos(self.curPos, self.curYaw, self.curPitch, 3)
            Lib.emitEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_PITCH_CAMERA, function(delta)
        self.curPitch = util:clamp(self.curPitch + delta, self.minPitch, self.maxPitch)
        BM:setViewerPos(self.curPos, self.curYaw, self.curPitch, 3)
        Lib.emitEvent(Event.EVENT_UPDATE_GIZMO_SCENE_UI)
    end)

    Lib.subscribeEvent(Event.EVENT_FOCUS_TARGET, function()
        local TargetManager = T(MobileEditor, "TargetManager")
        local targets = TargetManager:instance():getTargets()
        if Lib.getTableSize(targets) > 0 then
            local nodes = GameManager:instance():getNodes(targets)
            local bounds = util:getBound(nodes)
            local center = {
                x = bounds.min.x + (bounds.max.x - bounds.min.x) / 2,
                y = bounds.min.y + (bounds.max.y - bounds.min.y) / 2,
                z = bounds.min.z + (bounds.max.z - bounds.min.z) / 2,
            }

            local size = (bounds.max.x - bounds.min.x) ^ 2 +
                    (bounds.max.y - bounds.min.y) ^ 2 +
                    (bounds.max.z - bounds.min.z) ^ 2
            self:setFocus(center, size)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_SET_FOCUS, function(target)
        self:setFocus(target, 2)
    end)
end

return CameraManager