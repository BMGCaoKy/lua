---@class StoryCommand
local StoryCommand = Lib.class("StoryCommand")

function StoryCommand:ctor(param)
    Lib.logInfo("StoryCommand ctor param = ", Lib.v2s(param))
    -- parent block
    self.parentBlock = param.parentBlock
    -- value of the command
    self.value = param.value
    -- whether the command is executing
    self.isExecuting = false
end

-- execute the command
function StoryCommand:execute()
    self:onEnter()
end

-- end execution of this command and continue execution at the next command.
function StoryCommand:continue()
    if self.isExecuting == true then
        self:onExit()
        if self.parentBlock then
            self.parentBlock:continue()
        end
    end
end

-- stops the parent Block executing.
function StoryCommand:stopParentBlock()
    self:onExit()
    if self.parentBlock then
        self.parentBlock:stop()
    end
end

-- cleanup state so that the command is ready to execute again later on
function StoryCommand:onStopExecuting()

end

-- called when this command starts execution.
function StoryCommand:onEnter()

end

-- called when this command ends execution.
function StoryCommand:onExit()


end

-- called when this command is reset. This happens when the Reset command is used.
function StoryCommand:onReset()

end


function StoryCommand:setExecuting(value)
    self.isExecuting = value
end

function StoryCommand:isExecuting()
    return self.isExecuting
end


return StoryCommand