
---@class Dialog : WinBase

function M:init()
    -- WinBase.init(self, "Dialog.json", false)
    WinBase.init(self, "Dialog.json", true)
    self:root():SetLevel(2)
    self:initData()
    self:initWnd()
    self:initEvent()
end

function M:initData()
    self.writer = nil
    self.flowChart = nil
end

function M:initWnd()
    self.stName = self:child("Dialog-Name")
    self.stContent = self:child("Dialog-Content")
    self.stTip = self:child("Dialog-Tip")
    self.stTip:SetText(Lang:toText("tiptocontinue"))
    self.btnCancel = self:child("Dialog-BtnCancel")
    self.btnConfirm = self:child("Dialog-BtnConfirm")

end

function M:initEvent()
    self:lightSubscribe("error!!!!! script_client win_dialog btnCancel event : EventButtonClick", self.btnCancel, UIEvent.EventButtonClick, function()
        Lib.logDebug("click btnCancel")
        Me:onDialogCancel()
    end)

    self:lightSubscribe("error!!!!! script_client win_dialog btnConfirm event : EventButtonClick", self.btnConfirm, UIEvent.EventButtonClick, function()
        Lib.logDebug("click btnConfirm")
        Me:onDialogConfirm()

    end)

    self:lightSubscribe("error!!!!! script_client win_dialog _root event : EventWindowClick", self._root, UIEvent.EventWindowClick, function()
        Lib.logDebug("click root")
        if self.flowChart and self.flowChart:isClickContinue() == true then
            Me:onDialogContinue()
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_dialog Lib event : EVENT_SHOW_DIALOG", Event.EVENT_SHOW_DIALOG, function(type, dialogueId, targetId)
        Lib.logDebug("EVENT_SHOW_DIALOG")
        self:onShow(type, dialogueId, targetId)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_dialog Lib event : EVENT_HIDE_DIALOG", Event.EVENT_HIDE_DIALOG, function()
        Lib.logDebug("EVENT_HIDE_DIALOG")
        self:onHide()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_dialog Lib event : EVENT_SHOW_BUTTONS", Event.EVENT_SHOW_BUTTONS, function()
        Lib.logDebug("EVENT_SHOW_BUTTONS")
        self:showButtons()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_dialog Lib event : EVENT_RESUME_BLOCK", Event.EVENT_RESUME_BLOCK, function()
        Lib.logDebug("EVENT_RESUME_BLOCK")
        if self.flowChart then
            self.flowChart:resumeBlock()
        end


    end)

end

function M:onShow(type, dialogueId, targetId)

    UI:openWnd("sayDialog")
    self.type = type
    self.dialogueId = dialogueId
    self.targetId = targetId

    self.writer = StoryWriter.new()

    local param = {
        dialogueId = dialogueId,
        targetId = targetId,
        type = type
    }
    self.flowChart = StoryFlowChart.new(param)
    self.flowChart:startExecution()
end

function M:onHide()
    UI:closeWnd("sayDialog")
end

function M:onOpen()

end

function M:onClose()
    self.type = nil
    self.dialogueId = nil
    self.targetId = nil

    self.writer = nil
    self.flowChart = nil
    self.stTip:SetVisible(false)
    self.btnCancel:SetVisible(false)
    self.btnConfirm:SetVisible(false)

end

function M:doSay(text, onFinish)
    self.writer:write(text, function(content)
        self.stContent:SetText(content)
    end, function()
       Lib.logInfo("writer finish")
        onFinish()
    end)
end

function M:setName(name)
    if name == "" then
        self.stName:SetText(Me.name)
    else
        self.stName:SetText(Lang:toText(name))
    end
end

function M:resetWriter()
    self.writer:reset()
end

function M:showButtons()
    self.stTip:SetVisible(false)
    self.btnCancel:SetVisible(true)
    self.btnConfirm:SetVisible(true)
end

function M:showTips()
    self.stTip:SetVisible(true)
end

return M
