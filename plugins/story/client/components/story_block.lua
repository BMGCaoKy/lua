---@class StoryBlock
-- test: 嗯，你选择了一只很棒的宠物作为伙伴呢{sound:sell_success}。现在来熟悉一下宠物{shake:1.0}对战吧。
local StoryBlock = Lib.class("StoryBlock")

local NPCDialogueContentConfig = T(Config, "NPCDialogueContentConfig")

local ExecutionState = {
    Idle = 0,
    Executing = 1,
}



function StoryBlock:ctor(param)
    Lib.logInfo("block ctor param = ", Lib.v2s(param))
    -- parent flowchart
    self.parentFlowchart = param.parentFlowchart
    -- block's unique id
    self.blockId = param.blockId
    -- index of the block in the parent flowchart's block list
    self.index = param.index

    -- last block of the flowchart
    self.last = param.last

    -- target entity objId
    self.targetId = param.targetId
    -- target name
    self.targetName = ""

    self.type = param.type

    self.executionState = ExecutionState.Idle
    -- invalid active command index
    self.activeCommandIndex = 0

    self.commands = {}

    self:setExecutionInfo()


end

function StoryBlock:setExecutionInfo()
    local dialog_content = NPCDialogueContentConfig:getContentById(self.blockId)
    Lib.logInfo("dialog_content = ", Lib.v2s(dialog_content)) -- {name, content}
    self.targetName = dialog_content.name
    self:buildCommands(Lang:toText(dialog_content.content))

end

function StoryBlock:startExecution()
    Lib.logInfo("StoryBlock:startExecution")

    if self.executionState ~= ExecutionState.Idle then
        return
    end

    UI:getWnd("sayDialog"):setName(self.targetName)
    UI:getWnd("sayDialog"):resetWriter()
    self.executionState = ExecutionState.Executing

    self:continue()

end

function StoryBlock:continue()
    self.activeCommandIndex = self.activeCommandIndex + 1
    local activeCommand = self.commands[self.activeCommandIndex]
    if activeCommand then
        activeCommand:setExecuting(true)
        activeCommand:execute()
    else

        Lib.logInfo("current block finished")
        self:stop()
        self.parentFlowchart:continue()
    end
end

function StoryBlock:resume()

    local activeCommand = self.commands[self.activeCommandIndex]
    if activeCommand then
        activeCommand:continue()
    end
end

function StoryBlock:isClickContinue()
    local activeCommand = self.commands[self.activeCommandIndex]
    Lib.logInfo("isClickContinue = ", classof(activeCommand))
    if classof(activeCommand) == "ClickContinue" then
        return true
    end

    return false
end


function StoryBlock:stripAllCommands(text)
    local pattern = "%{.[^}]+%}"
    local cleanString = string.gsub(text, pattern, "")
    return cleanString
end

function StoryBlock:buildCommands(text)
    Lib.logInfo("buildCommands index = ", self.index)
    if World.cfg.dialogSetting and World.cfg.dialogSetting.watchTarget then
        if self.index == 1 then
            self:createDisableControlCommand(true)
            self:createWatchTargetCommand()
        end
    end


    local commandString = ""
    local textLength = Lib.subStringGetTotalIndex(text)
    local sayIndex = 1
    for i = 1, textLength do
        local character = Lib.subStringUTF8(text, i, i)

        if i == textLength then
            local sayString = Lib.subStringUTF8(text, sayIndex, i)
            self:createSayCommand(sayString)

        end


        if character == "{" then
            local sayString = Lib.subStringUTF8(text, sayIndex, i - 1)
            sayIndex = i
            self:createSayCommand(sayString)


            while character ~= "}" and i < textLength do
                character = Lib.subStringUTF8(text, i, i)
                commandString = commandString .. character
                -- remove current character
                text = Lib.replaceStringUTF8(text, i, "")
            end

            if character == "}" then
                commandString = string.gsub(commandString, "[{}]", "")
                self:createOtherCommand(commandString)
                commandString = ""
                i = i - 1

            else

            end
        end
    end


    if self.last == true  then
        if self.type == Define.DIALOG_TYPE.TWO then
            self:createOptionCommand()
        elseif self.type == Define.DIALOG_TYPE.NONE then
            self:createClickContinueCommand()
        end

        if World.cfg.dialogSetting and World.cfg.dialogSetting.watchTarget then
            self:createResetCameraCommand()
            self:createDisableControlCommand(false)
        end

    else
        self:createClickContinueCommand()
    end
end

function StoryBlock:createOtherCommand(str)
    local commandInfo = Lib.split(str, ":")

    local key = commandInfo[1]
    local value = commandInfo[2]
    local command = nil
    local param = {
        parentBlock = self,
        value = value
    }
    if key == "sound" then
        command = PlaySound.new(param)
    elseif key == "shake" then
        command = ShakeCamera.new(param)
    end

    table.insert(self.commands, command)
end


function StoryBlock:createSayCommand(str)
    local command = nil
    local param = {
        parentBlock = self,
        value = str
    }

    local command = Say.new(param)
    table.insert(self.commands, command)
end

function StoryBlock:createWatchTargetCommand()

    local param = {
        parentBlock = self,
        value = tonumber(self.targetId)
    }

    local command = WatchTarget.new(param)
    table.insert(self.commands, command)

end

function StoryBlock:createOptionCommand()
    Lib.logInfo("createOptionCommand")
    local param = {
        parentBlock = self,
        value = self.type
    }

    local command = Option.new(param)
    table.insert(self.commands, command)
end

function StoryBlock:createClickContinueCommand()
    local param = {
        parentBlock = self,
    }

    local command = ClickContinue.new(param)
    table.insert(self.commands, command)
end

function StoryBlock:createResetCameraCommand()
    Lib.logInfo("createResetCameraCommand")
    local param = {
        parentBlock = self,
        value = self.targetId
    }

    local command = ResetCamera.new(param)
    table.insert(self.commands, command)
end

function StoryBlock:createDisableControlCommand(status)
    local param = {
        parentBlock = self,
        value = status
    }

    local command = DisableControl.new(param)
    table.insert(self.commands, command)
end

function StoryBlock:stop()

    self.activeCommandIndex = 0

    self.executionState = ExecutionState.Idle
end



function StoryBlock:isExecuting()
    return self.executionState == ExecutionState.Executing
end



return StoryBlock