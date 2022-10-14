M.NotDialogWnd = true

local buttonNames = {
    "forward",
    "back",
    "left",
    "right",
    "horn",
    "brake",
    "debark"
}
local player = Player.CurPlayer

local function interactionWithDriverButton(targetObjID, interactionType, interactionName)
    local packet = {
        pid = "InteractionWithMovementEvent",
        objID = player.objID,
        params = {
            interactionType = interactionType,
            interactionName = interactionName,
            targetObjId = targetObjID
        }
	}
	player:sendPacket(packet)
end

function M:init()
    WinBase.init(self, "DriveControl.json", false)
    for _, name in ipairs(buttonNames) do
        local button = self:child("DriveControl-" .. name:sub(1,1):upper() .. name:sub(2))
        local keyName = "key." .. name
        local normalImage = "set:drive.json image:" .. name
        local pressedImage = "set:drive.json image:" .. name .. "_pressed"
        button:subscribe(UIEvent.EventWindowTouchDown, function()
            Blockman.instance:setKeyPressing(keyName, true)
            button:SetImage(pressedImage)
            interactionWithDriverButton(player.rideOnId, UIEvent.EventWindowTouchDown, name)
        end)
        button:subscribe(UIEvent.EventMotionRelease, function()
            Blockman.instance:setKeyPressing(keyName, false)
            button:SetImage(normalImage)
            interactionWithDriverButton(player.rideOnId, UIEvent.EventMotionRelease, name)
        end)
        button:subscribe(UIEvent.EventWindowTouchUp, function()
            Blockman.instance:setKeyPressing(keyName, false)
            button:SetImage(normalImage)
            interactionWithDriverButton(player.rideOnId, UIEvent.EventWindowTouchUp, name)
        end)
    end
    self:child("DriveControl-Debark"):subscribe(UIEvent.EventWindowTouchUp, function()
        interactionWithDriverButton(player.objID, UIEvent.EventWindowTouchUp, "debark")
    end)
    self:child("DriveControl-Horn"):subscribe(UIEvent.EventWindowTouchDown, function()
        interactionWithDriverButton(player.rideOnId, UIEvent.EventWindowTouchDown, "startHorn")
    end)
    self:child("DriveControl-Horn"):subscribe(UIEvent.EventWindowTouchUp, function()
        interactionWithDriverButton(player.rideOnId, UIEvent.EventWindowTouchUp, "stopHorn")
    end)
end