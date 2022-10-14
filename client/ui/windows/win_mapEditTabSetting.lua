local labelName = {
	{
		leftName = "ItemBaseProp",
		wndName = "ItemBaseProp"
	}
}

function M:init()
    WinBase.init(self, "setting_edit_tab.json")
    self.m_root = self:child("Global-root")
    self.m_sure = self:child("Global-BackBtn")
    self.m_ltGrid = self:child("Global-Lt-Grid")
    self.last_selectIdx = 1


    self.maskBtn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "maskImge")
    self.maskBtn:SetHeight({0, 80})
    self.maskBtn:SetWidth({0, 180})
    self.maskBtn:SetImage("set:setting_base.json image:tap_left_click.png")
    self.maskText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "maskText")
    self.maskText:SetArea({0, 0}, {0, -7}, {0.8, 0}, {1, 0})
    self.maskText:SetTextVertAlign(1)
    self.maskText:SetTextHorzAlign(1)
    self.maskBtn:AddChildWindow(self.maskText)
    self.maskBtn:SetXPosition({0, 46})
    self.maskBtn:SetYPosition({0, 110})
    self.m_root:AddChildWindow(self.maskBtn)

    self:initRtLayout()
    self:initBtLabel()

	self:subscribe(self.m_sure, UIEvent.EventButtonClick, function()
		for k, win in pairs(self.winList or {}) do
			if win.onSave then
				win:onSave()
			end
		end
		if self.backFunc then
			self.backFunc(true)
		end
		UI:closeWnd(self)
	end)
end

function M:clickLeftTab(key)
	local btn = self.m_ltGrid:GetItem(key - 1)
	local btnText = btn:GetChildByIndex(0)
	if self.curWin then
		self.curWin:root():SetVisible(false)
	end
	self:setSelectMask(btn, btnText:GetText())
	self:openWindow(key)
end


function M:openWindow(key)
    local labelName = self.labelName
    if not labelName[key] then
        return
    end
    local winName = labelName[key].wndName
    local name = winName:sub(1,1):upper() .. winName:sub(2)
    local winName = string.format("mapEdit%s",name)
    if not self.winList[key] then
        local win = UI:openMultiInstanceWnd(winName, self.paramsData, self)
        self.winList[key] = win
        self.m_rtLayout:AddChildWindow(win:root())
    end
    self.curWin = self.winList[key]
    self.curWin:root():SetVisible(true)
end

function M:initLtLabel()
	self.m_ltGrid:RemoveAllItems()
    self.m_ltGrid:SetMoveAble(false)
	self.m_ltGrid:InitConfig(0, 3, 1)
    for key, itemData in ipairs(self.labelName) do
        local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "btn" .. key)
        btn:SetHeight({0, 80})
        btn:SetWidth({1, 0})
        btn:SetNormalImage("set:setting_base.json image:tap_left_empty.png")
        btn:SetPushedImage("set:setting_base.json image:tap_left_empty.png")
        local btnText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "btnText" .. key)
        btnText:SetArea({0, 0}, {0, 0}, {0.8, 0}, {1, 0})
        btnText:SetTextVertAlign(1)
        btnText:SetTextHorzAlign(1)
        btnText:SetText(Lang:toText(itemData.leftName))
        btnText:SetTextColor({44 / 255, 177 / 255, 130 / 255,1})
        btnText:SetProperty("TextWordWrap", "true")
        btn:AddChildWindow(btnText)
        self:subscribe(btn, UIEvent.EventButtonClick, function()
			self:clickLeftTab(key)
        end)
		self.m_ltGrid:AddItem(btn)
	end
end

function M:setSelectMask(btn, text)
    local y = btn:GetYPosition()[2]
    self.maskBtn:SetYPosition({0, y + 72})
    self.maskText:SetText(text)
end

function M:initRtLayout()
    self.m_rtLayout = self:child("Global-Rt-Layout")
end

function M:initBtLabel()
    self.m_btLabel = self:child("Global-Bt-Label")
end

function M:onOpen(params)
	self:root():SetLevel(10)
	self.paramsData = params and params.data
	self.labelName = params and params.labelName or labelName
	self.winList = {}
	self:initLtLabel()
	self:clickLeftTab(1)
	self.backFunc = params.backFunc
end

function M:onClose()
    for _, wnd in pairs(self.winList) do
        self.m_rtLayout:RemoveChildWindow1(wnd:root())
    end
end

function M:onReload()

end

return M