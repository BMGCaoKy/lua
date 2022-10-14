function M:init()
    WinBase.init(self, "tip_popWnd_edit.json")

    self.title = self:child("Tip-Dlg-Title")
    self.tips = self:child("Tip-Dlg-Tips")
    self.closeBtn = self:child("Tip-Close-Btn")

    self.title:SetText(Lang:toText("composition.replenish.title"))

    self.tips:SetWordWrap(true)

    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

end

function M:onOpen(tips)
    self.tips:SetText(tips or " ")
end

function M:onReload()

end

return M