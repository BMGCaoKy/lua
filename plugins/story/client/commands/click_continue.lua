

local ClickContinue = Lib.class("ClickContinue", StoryCommand)


function ClickContinue:onEnter()
    Lib.logInfo("ClickContinue:onEnter")
    UI:getWnd("sayDialog"):showTips()

end


function ClickContinue:onExit()
    Lib.logInfo("ClickContinue:onExit")
    self.isExecuting = false
    self:onStopExecuting()
end


function ClickContinue:onReset()

end