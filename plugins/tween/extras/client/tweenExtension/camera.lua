local blockman = Blockman.Instance()
local originCameraView

local function changeView(pos, yaw, pitch, distance)
    pos = pos or blockman:getViewerPos()
    yaw = yaw or blockman:getViewerYaw()
    pitch = pitch or blockman:getViewerPitch()
    distance = distance or blockman:getCameraInfo().distance

    blockman:changeCameraView(pos, yaw, pitch, distance, 0)
end

local function setPosition(pos)
    changeView(pos)
end

local function saveCameraView()
    local personView = blockman:getPersonView()
    if personView == 4 then return end
    originCameraView = personView
end

local function loadCameraView()
    if not originCameraView then
        return
    end
    
    blockman:setPersonView(originCameraView)
    originCameraView = nil
end

---@param to Vector3
---@param duration number
---@return TweenerOperator
function Camera.doMove(to, duration)
    local function getter()
        return blockman:getViewerPos()
    end

    local function setter(value)
        setPosition(value)
    end

    saveCameraView()
    
    local operator = Tween.tweener(getter, setter, to, duration, "CameraDoMove")
    
    local oldOnFinish = operator.onFinish
    function operator:onFinish(...)
        loadCameraView()
        oldOnFinish(self, ...)
        return self
    end

    return operator
end

function Camera.doDistance()
end

function Camera.doLookAt()
end