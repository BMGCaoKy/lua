local ResetCamera = Lib.class("ResetCamera", StoryCommand)

local normalVis = 3
local distance = 6
local smooth = 10

function ResetCamera:onEnter()
    Lib.logInfo("ResetCamera:onEnter value = ", self.value)
    local mainCamera = Camera.getActiveCamera()
    if mainCamera then
        local target = World.CurWorld:getEntity(self.value)
        if target then
            self:reset()
            self:continue()
        end
    end

end

function ResetCamera:reset()
    Me:changeCameraView(Me.sourceCameraPos, Me.sourceCameraYaw, Me.sourceCameraPitch, distance, World.cfg.InterractiveCameraSpdOut or smooth)
    World.Timer(World.cfg.InterractiveCameraSpdOut or smooth, function()
        Blockman.instance:setPersonView(normalVis)
    end)

end


function ResetCamera:onExit()
    Lib.logInfo("ResetCamera:onExit")
    self.isExecuting = false
    self:onStopExecuting()
end


function ResetCamera:onReset()

end