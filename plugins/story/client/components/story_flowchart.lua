-- flowchart是block的容器
local NPCDialogueListConfig = T(Config, "NPCDialogueListConfig")


---@class StoryFlowChart
local StoryFlowChart = Lib.class("StoryFlowChart")


function StoryFlowChart:ctor(param)

    self.dialogueId = param.dialogueId
    self.targetId = param.targetId
    self.type = param.type

    -- invalid active block index
    self.activeBlockIndex = 0

    self.blocks = {}

    local list_config = NPCDialogueListConfig:getDialogueById(self.dialogueId)
    if list_config then
        for index, dialogue_content_id in pairs(list_config.dialogue_list) do
            local block = self:createBlock(dialogue_content_id, self.targetId, index, index == #list_config.dialogue_list and true or false)
            table.insert(self.blocks, block)
        end
    end
end

function StoryFlowChart:createBlock(blockId, targetId, index, last)
    local param = {
        parentFlowchart = self,
        blockId = blockId,
        targetId = targetId,
        type = self.type,
        index = index,
        last = last
    }

    local block = StoryBlock.new(param)
    return block
end

function StoryFlowChart:startExecution()
    Lib.logInfo("StoryFlowChart:startExecution")

    self:continue()
end

function StoryFlowChart:continue()
    self.activeBlockIndex = self.activeBlockIndex + 1
    self:executeBlock(self.activeBlockIndex)
end

function StoryFlowChart:executeBlock(index)
    local block = self.blocks[index]
    if block and not block:isExecuting() then
        block:startExecution()
    else
        Lib.logInfo("no block left")

        Lib.emitEvent(Event.EVENT_HIDE_DIALOG)

    end
end



function StoryFlowChart:stopBlock(index)
    local block = self.blocks[index]
    if block and block:isExecuting() then
        block:stop()
    end

end

function StoryFlowChart:resumeBlock()
    local block = self.blocks[self.activeBlockIndex]
    if block and block:isExecuting() then
        block:resume()
    end
end

function StoryFlowChart:isClickContinue()
    local block = self.blocks[self.activeBlockIndex]
    if block and block:isExecuting() then
        return block:isClickContinue()
    end
end


return StoryFlowChart