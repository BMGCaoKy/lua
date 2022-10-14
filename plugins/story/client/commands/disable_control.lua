local DisableControl = Lib.class("DisableControl", StoryCommand)


function DisableControl:onEnter()
    Lib.logInfo("DisableControl:onEnter value = ", self.value)
    Me.disableControl = self.value
    self:continue()
end


function DisableControl:onExit()
    Lib.logInfo("DisableControl:onExit")
    self.isExecuting = false
    self:onStopExecuting()
end


function DisableControl:onReset()

end