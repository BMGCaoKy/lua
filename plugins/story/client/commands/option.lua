local Option = Lib.class("Option", StoryCommand)


function Option:onEnter()
    Lib.logInfo("Option:onEnter value = ", self.value)

    UI:getWnd("sayDialog"):showButtons()
end


function Option:onExit()
    Lib.logInfo("Option:onExit")
    self.isExecuting = false
    self:onStopExecuting()
end


function Option:onReset()

end