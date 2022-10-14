function M:init()
    WinBase.init(self, "LongTextTip.json", true)
    self:initTitle()
    self:initCloseBtn()
    self:initContent()
end

function M:initTitle()
    self.titleName = self:child("LongTextTip-Title-Name")
end

function M:initCloseBtn()
    M:subscribe(self:child("LongTextTip-Title-Btn-Close"), UIEvent.EventButtonClick, function()
        self.titleName:SetText("")
        UI:closeWnd("longTextTip")
    end)
end

function M:initContent()
    self.list = self:child("LongTextTip-Content-List")
end

function M:onOpen(packet)
    if not packet.text then
        return
    end
    self.titleName:SetText(Lang:toText(packet.title))

    self.list:ClearAllItem()
    local text = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "LongTextTip-Content-List-Text" )
    text:SetText(Lang:toText(packet.text))
    text:SetWordWrap(true)
    text:SetWidth({0, 510})

    local renderTextHeight = text:GetTextHeight()
    text:SetHeight({0, renderTextHeight})
    text:SetHorizontalAlignment(1)
    if renderTextHeight <= 210 then
        self.list:SetMoveAble(false)
    end
    self.list:AddItem(text)
end