local ShakeCamera = Lib.class("ShakeCamera", StoryCommand)

local duration = 1.0
local shakeTimes = 3


function ShakeCamera:onEnter()
    Lib.logInfo("ShakeCamera:onEnter value = ", self.value)
    Blockman.instance:addCameraShake(self.value, duration, shakeTimes)
    self:continue()
end


function ShakeCamera:onExit()
    Lib.logInfo("ShakeCamera:onExit")
    self.isExecuting = false
    self:onStopExecuting()
end


function ShakeCamera:onReset()

end