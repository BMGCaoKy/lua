function M:init()
    WinBase.init(self, "Select.json", true)
    self.m_nCloseWindow = self:child("Select-New_Close_Btn")
    self.m_nTittle = self:child("Select-New_Select_Tittle")
    self.m_Describe = self:child("Select-Describe")
    self.m_Select_List = self:child("Select-New_Select_List")
    self.m_Select_Desc = self:child("Select-New_Delect_Desc_Bg")
    self.m_ShowMask = self:child("Select-Select_Mask")

    self:subscribe(self.m_nCloseWindow, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
end

function M:setOption(options, regId, forcedChoice, content, tittle, showMask)
    self.m_nCloseWindow:SetVisible(forcedChoice==false)
	self.m_ShowMask:SetVisible(showMask)
    self.m_nTittle:SetText(Lang:toText(tittle))
    if content then
        self.m_Describe:SetVisible(true)
        self.m_Describe:SetText(Lang:toText(content))
        self.m_Select_Desc:SetArea({ 0, -1 }, { 0, -78 }, { 1, 0 }, { 0, 572 })
    end

    self.m_Select_List:ClearAllItem()
    self.m_Select_List:SetItemHeight(50)
    self.m_Select_List:SetProperty("BetweenDistance", "50")

    for i, v in ipairs(options) do
        local informationitem = GUIWindowManager.instance:CreateWindowFromTemplate("option" .. tostring(i), "Option.json")
        local m_option = informationitem:GetChildByIndex(2)
        m_option:SetText(Lang:toText(v))
        informationitem:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, 50 })
        self:subscribe(informationitem, UIEvent.EventWindowTouchUp, function()
            UI:closeWnd(self)
            Me:doCallBack("select", i, regId)
        end)
        self.m_Select_List:AddItem(informationitem, true)
    end
    self.reloadArg = table.pack(options, regId, forcedChoice, content, tittle, showMask)
end

function M:onReload(reloadArg)
    local options, regId, forcedChoice, content, tittle, showMask = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
    self:setOption(options, regId, forcedChoice, content, tittle, showMask)
end

return M