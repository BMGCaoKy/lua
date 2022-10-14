local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer

local WatchTarget = Lib.class("WatchTarget", StoryCommand)

local freeVis = 4
local distance = 6
local smooth = 0

function WatchTarget:onEnter()
    Lib.logInfo("WatchTarget:onEnter value = ", self.value)
    self.mainCamera = Camera.getActiveCamera()
    if self.mainCamera then
        self.target = World.CurWorld:getEntity(self.value)

        if self.target then
            self:lock()

            self:watch(true)
            self:continue()

        else
            Lib.logError("WatchTarget cannot find target")

        end
    end
end

function WatchTarget:lock()
    Blockman.instance:setPersonView(freeVis)

    self.targetPos =  self.target:getPosition()
    self.playerPos = Lib.v3(Me:getPosition().x, Me:getPosition().y, Me:getPosition().z)

    Me.sourceCameraPos = Lib.v3(self.mainCamera:getPosition().x, self.mainCamera:getPosition().y, self.mainCamera:getPosition().z)
    Lib.logInfo("WatchTarget sourceCameraPos = ", Lib.v2s(Me.sourceCameraPos))
    Me.sourceCameraPitch = Blockman.instance:getViewerPitch()
    Me.sourceCameraYaw = Blockman.instance:getViewerYaw()

    Me:changeCameraView(Me.sourceCameraPos, Me.sourceCameraYaw, Me.sourceCameraPitch,6, 0)
end

function WatchTarget:watch(isMe)
    if not self.targetPos then
        return
    end

    if isMe then
        self.playerPos.y = self.playerPos.y + 1.5
    else
        self.targetPos.y = self.targetPos.y + 1.5
    end

    local len = Lib.getPosDistance(self.targetPos, self.playerPos)

    local deltaX = self.playerPos.x - self.targetPos.x
    local deltaZ = self.playerPos.z - self.targetPos.z
    local deltaY = self.playerPos.y - self.targetPos.y

    if not isMe then
        deltaX = -deltaX
        deltaZ = -deltaZ
        deltaY = -deltaY
    end

    local p = math.asin((deltaY) / len)
    local y = math.atan(deltaZ / deltaX)
    local angY = math.deg(y)
    if deltaX > 0 and deltaZ > 0  then
        angY = angY + 90
    elseif deltaX < 0 and deltaZ < 0 then
        angY = angY - 90
    elseif deltaX > 0 and deltaZ < 0 then
        angY = angY + 90
    elseif deltaX < 0 and deltaZ > 0 then
        angY = angY - 90
    end

    Me:changeCameraView(isMe and self.playerPos or self.targetPos,angY , math.deg(p),5, World.cfg.InterractiveCameraSpdIn or 10)

    if isMe then
        self.playerPos.y = self.playerPos.y - 1.5
    else
        self.targetPos.y = self.targetPos.y - 1.5
    end
end


function WatchTarget:onExit()
    Lib.logInfo("WatchTarget:onExit")
    self.isExecuting = false
    self:onStopExecuting()
end


function WatchTarget:onReset()

end