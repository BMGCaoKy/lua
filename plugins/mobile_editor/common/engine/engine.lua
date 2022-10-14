--- engine.lua

local M = {}

function M:getCamera(name)
    local cam = CameraManager.Instance():createCamera(name)
    return cam
end

return M