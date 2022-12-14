---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Administrator.
--- DateTime: 2022/4/2 15:13
---

---@class EasterClickHandler
local EasterClickHandler = Lib.class("EasterClickHandler")

---@type EasterClickHandler
local _instance

---@return EasterClickHandler
function EasterClickHandler.Instance()
    if _instance == nil then
        _instance = EasterClickHandler.new()
    end
    return _instance
end

function EasterClickHandler:ctor()

end

function EasterClickHandler:init()
    InputSystem.instance:addHandler(self, 641)
end

function EasterClickHandler:destroy()
    InputSystem.instance:removeHandler(self)
end

function EasterClickHandler:handleInput(input)
    if not input then
        return false
    end

    if input.type == InputType.Mouse then
        local pos = nil
        pos = input.position
        if input.subtype == MouseInputSubType.LeftDown then
            self:onTouchBegin(pos)
        elseif input.subtype == MouseInputSubType.MouseMove then
            self:onTouchMove(pos)
        elseif input.subtype == MouseInputSubType.LeftUp or input.subtype == MouseInputSubType.MouseLeave then
            self:onTouchEnd(pos)
        end

    elseif input.type == InputType.TouchScreen then
        local pos = nil
        for _, touch in ipairs(input.touches) do
            pos = touch.position
            break
        end
        if input.subtype == TouchScreenInputSubType.TouchDown then
            self:onTouchBegin(pos)
        elseif input.subtype == TouchScreenInputSubType.TouchMove then
            self:onTouchMove(pos)
        elseif input.subtype == TouchScreenInputSubType.TouchUp or input.subtype == TouchScreenInputSubType.TouchCancel then
            self:onTouchEnd(pos)
        end
    end

    return false
end

function EasterClickHandler:onTouchBegin(pos)
    if not pos then
        return
    end
    self.touchBeginPos = pos
    self.maxMoveDistance = 0
end

function EasterClickHandler:onTouchMove(pos)
    if not pos then
        return
    end

    if not self.touchBeginPos then
        return
    end

    local offset = pos - self.touchBeginPos
    local moveDistance = offset:len()
    self.maxMoveDistance = math.max(moveDistance, self.maxMoveDistance)
end

function EasterClickHandler:onTouchEnd(pos)
    if not pos then
        return
    end

    if not self.touchBeginPos then
        return
    end

    if not self.maxMoveDistance then
        return
    end

    if self.maxMoveDistance >= 100 then
        return
    end

    local camera = CameraManager.Instance():getMainCamera()
    ---@type Vector3
    local position = camera:getPosition()
    ---@type Vector3
    local worldTargetPos = Blockman.Instance():getScreenToPos(pos, 20).oPosition
    if not worldTargetPos then
        return
    end
    local direction = (worldTargetPos - position):normalize()

    local world = Me.map:getPhysicsWorld()
    local hitGhostMask = 1 + 2 + 4 + 8 + 16 + 32 + 64
    local hitGhost = world:raycast(position, direction, 10, hitGhostMask, 256)

    if hitGhost and hitGhost.targetType == 2 and hitGhost.target then
        local entity = hitGhost.target
        if entity and entity:isValid() and entity.isEasterEggs and entity:isEasterEggs() then
            local easterEgg = entity:getEasterEggs()
            easterEgg:onInteract()


            --Me:sendPacket({
            --    pid = "onClickEggsEntity",
            --    objID = entity.objID,
            --})
            --Lib.logInfo("click 111111111111111111111 ")
        end
        --Lib.logInfo("click 22222222222222222 ")
    end
end

EasterClickHandler.Instance():init()

return EasterClickHandler