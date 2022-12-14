function M:init()
    WinBase.init(self, "GameTipDialog.json", true)

    self.m_msgText = self:child("GameTipDialog-MsgText")
    self.m_btnSure = self:child("GameTipDialog-BtnSure")
    self.m_btnCancel = self:child("GameTipDialog-BtnCancel")

    self.m_showType = 1  -- 0 - dead    1 - close game ...

    self:subscribe(self.m_btnSure, UIEvent.EventButtonClick, function()
        self:btnSureClick()
    end)
    self:subscribe(self.m_btnCancel, UIEvent.EventButtonClick, function()
        self:btnCancelClick()
    end)
    self.m_showAll = nil
end

function M:refreshUi(callback)
    --if not self:isvisible() then
    --    self:show()
    --end
    local sureTxt = self.m_btnSure:GetText()
    local cancelTxt = self.m_btnCancel:GetText()
    local msgTxt = self.m_msgText:GetText()
    if self.m_showType == 0 then

    elseif self.m_showType == 1 then
        sureTxt = Lang:toText("gui_menu_exit_game_sure")
        cancelTxt = Lang:toText("gui_menu_exit_game_cancel")
        msgTxt = Lang:toText("gui_menu_exit_game")
    else

    end

    self.m_msgText:SetText(msgTxt)
    self.m_btnSure:SetText(sureTxt)
    self.m_btnCancel:SetText(cancelTxt)

	self:showAllHide(callback)
	self.reloadArg = table.pack(callback)

end

function M:btnSureClick()
    if self.m_showType == 0 then

    elseif self.m_showType == 1 then
        if not Blockman.instance.singleGame and CGame.instance:getIsMobileEditor() and not CGame.instance:getIsEditor() then
            Lib.emitEvent(Event.EVENT_SELF_EXIT_GAME)
            UI:closeWnd(self)
            CGame.instance:exitGame()
        else
            if World.CurWorld.isEditorEnvironment then
                EditorModule:emitEvent("enterEditorMode")
            else
                Lib.emitEvent(Event.EVENT_SELF_EXIT_GAME)
                UI:closeWnd(self)
                CGame.instance:exitGame()
            end
        end

    else

    end
end

function M:btnCancelClick()
    if self.m_showType == 0 then

    elseif self.m_showType == 1 then
        UI:closeWnd(self)
    else

    end
end

function M:showAllHide(callback)
    self.m_showAll = callback
end

function M:onReload(reloadArg)
	local callback = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	self:refreshUi(callback)
end

function M:onClose()
    if self.m_showType == 1 then
        if self.m_showAll then
            self.m_showAll()
        end
    end
end

return M