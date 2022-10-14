local Say = Lib.class("Say", StoryCommand)


function Say:onEnter()
    Lib.logInfo("Say:onEnter value = ", self.value)
    -- dialog.say
    UI:getWnd("sayDialog"):doSay(self.value, function()
        Lib.logInfo("say finish")
        self:continue()
    end)
end


function Say:onExit()
    Lib.logInfo("Say:onExit")
    self.isExecuting = false
    self:onStopExecuting()
end


function Say:onReset()

end