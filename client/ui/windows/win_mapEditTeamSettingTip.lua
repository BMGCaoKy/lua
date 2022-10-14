function M:init()
    WinBase.init(self, "entitySetting_tips_edit.json")

    self.context = self:child("Entity-Tips-Frame-Context")
    self.title = self:child("Entity-Tips-Frame-Title")
    self.sureText = self:child("Entity-Tips-Frame-Sure-Text")
    self.cancelText = self:child("Entity-Tips-Frame-Cancel-Text")
    
    self.sureBtn = self:child("Entity-Tips-Frame-Sure")
    self.cancelBtn = self:child("Entity-Tips-Frame-Cancel")
    self.bgBtn = self:child("Entity-Tips-Bg")

    self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
        if self.sureFun then
            self.sureFun()
        end
        UI:closeWnd(self)
    end)
    self:subscribe(self.cancelBtn, UIEvent.EventButtonClick, function()
        if self.cancelFun then
            self.cancelFun()
        end
        UI:closeWnd(self)
    end)
    self:subscribe(self.bgBtn, UIEvent.EventWindowTouchDown, function()
        if self.blockClick then
            return
        end
        if self.cancelFun then
            self.cancelFun()
        end
        UI:closeWnd(self)
    end)
    self:subscribe(self.bgBtn, UIEvent.EventWindowClick, function()
        if not self.blockClick then
            return
        end
        if self.cancelFun then
            self.cancelFun()
        end
        UI:closeWnd(self)
    end)

    self:initText()

end

function M:switchBtnPosition()
    self.sureBtn:SetArea({0.159011, 0}, {0.655738, 0}, {0.24735, 0}, {0.196721, 0})
    self.cancelBtn:SetArea({-0.159011, 0}, {0.655738, 0}, {0.24735, 0}, {0.196721, 0})
end

function M:initText()
    self.title:SetText(Lang:toText("player_die_title"))
    self.sureText:SetText(Lang:toText("global.sure"))
    self.cancelText:SetText(Lang:toText("global.cancel"))
end

function M:setContext(context)
    self.context:SetText(context or "context")
end

function M:onOpen(sureFun, cancelFun, context)
	self.sureFun = sureFun
    self.cancelFun = cancelFun
    self:setContext(context)
end

function M:onClose()
    self.sureFun = nil
    self.cancelFun = nil
    self.blockClick = nil
end

function M:onReload(reloadArg)

end

return M