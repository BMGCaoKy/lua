--- place_state.lua
---@class PlaceState : BaseNode
local PlaceState = {}

function PlaceState:enteredState()
    --Lib.logDebug("PlaceState:enteredState")
    self:setSelection(false)
end

function PlaceState:exitedState()
    --Lib.logDebug("PlaceState:exitedState")



end


return PlaceState