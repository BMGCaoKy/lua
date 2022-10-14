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
        UI:closeWnd(self)
    end)

end

function M:removeAllChildWnd()
	local count = self.m_rtLayout:GetChildCount()
	for i = 1, count do
		local child = self.m_rtLayout:GetChildByIndex(0)
		self.m_rtLayout:RemoveChildWindow1(child)
	end
	self.curWin = nil
end

function M:clickLeftTab(key)
	local btn = self.m_ltGrid:GetItem(key - 1)
	local btnText = btn:GetChildByIndex(0)
	self:setSelectMask(btn, btnText:GetText())
	self:removeAllChildWnd()
	self:closeWindow()
	self:openWindow(key)
	self.lastKey = key
end

local function getWinByKey(self, key)
    local winName = self.labelName[key].wndName
    local name = winName:sub(1,1):upper() .. winName:sub(2)
    local winName = string.format("mapEdit%s",name)
    local win = UI:getWnd(winName) or nil
    return win
end

function M:closeWindow()
    if not self.lastKey or not self.labelName[self.lastKey] then
        return
    end
    local win = getWinByKey(self, self.lastKey)
    if win then
        win:onClose()
    end
end


function M:openWindow(key)
	if not self.labelName[key] then
		return
	end
	local win = getWinByKey(self, key)
	self.winList[key] = win
	if win then
		self.m_rtLayout:AddChildWindow(win:root())
		win:onOpen(self.paramsData)
		self.curWin = win
	end
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
        btn:AddChildWindow(btnText)
        self:subscribe(btn, UIEvent.EventButtonClick, function()
			self:clickLeftTab(key)
        end)
		self.m_ltGrid:AddItem(btn)
	end
end

function M:setSelectMask(btn, text)
    local y = btn:GetYPosition()[2]
    self.maskBtn:SetYPosition({0, y + 75})
    self.maskText:SetText(text)
end

function M:initRtLayout()
    self.m_rtLayout = self:child("Global-Rt-Layout")
end

function M:initBtLabel()
    self.m_btLabel = self:child("Global-Bt-Label")
end

function M:onOpen(params)
	self.paramsData = params and params.data
	self.labelName = params and params.labelName or labelName
	self.winList = {}
	self:initLtLabel()
	self:clickLeftTab(1)
end

function M:onReload()

end

return M