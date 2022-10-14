--- third_person_state.lua
---@class ThirdPersonState : CameraManager
local ThirdPersonState = {}


function ThirdPersonState:enteredState()
    --Lib.logDebug("ThirdPersonState:enteredState")
    Blockman.Instance().gameSettings:setLockSlideScreen(true)
end

function ThirdPersonState:exitedState()
    --Lib.logDebug("ThirdPersonState:exitedState")

end


return ThirdPersonState