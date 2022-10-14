local PlaySound = Lib.class("PlaySound", StoryCommand)


function PlaySound:onEnter()
    Lib.logInfo("PlaySound:onEnter value = ", self.value)
    Me:playSoundByKey(self.value)
    self:continue()
end


function PlaySound:onExit()
    Lib.logInfo("PlaySound:onExit")
    self.isExecuting = false
    self:onStopExecuting()
end


function PlaySound:onReset()

end