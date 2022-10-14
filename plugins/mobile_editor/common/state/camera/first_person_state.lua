--- first_person_state.lua
---@class FirstPersonState : CameraManager
local FirstPersonState = {}


function FirstPersonState:enteredState()
    --Lib.logDebug("FirstPersonState:enteredState")
    --Blockman.Instance().gameSettings:setLockSlideScreen(false)
end

function FirstPersonState:exitedState()
    --Lib.logDebug("FirstPersonState:exitedState")
end


return FirstPersonState