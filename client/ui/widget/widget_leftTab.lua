local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

function M:init()
	widget_base.init(self, "setting_edit_tab.json")
	self:initUIName()
	self:initUI()
	self:initData()
end

function M:initData()
	self.rightWidgets = {} 
end

function M:initUIName()
	self.m_root = self:child("Global-root")
    self.m_sure = self:child("Global-BackBtn")
	self.m_rtLayout = self:child("Global-Rt-Layout")
    self.m_ltGrid = self:child("Global-Lt-Grid")
end

function M:initUI()
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
	

    self:subscribe(self.m_sure, UIEvent.EventButtonClick, function()
		self:onSave()
    end)

end

function M:onSave()
	local result = {}
	for key, widget in pairs(self.rightWidgets or {}) do
		local data = widget:invoke("getModify")
		result[key] = data
	end
	if self.sureOnSaveBackFunc then
		if not self.detailsData then
			for _, leftTabData in pairs(result) do
				for widgetIndex, widgetData in pairs(leftTabData) do
					leftTabData[widgetIndex] = widgetData.value
				end
			end
		end
		self.sureOnSaveBackFunc(result)
	end
end

function M:fillData(params)
	-- tabDataList = {
		-- {
			-- leftTabName = "leftTabName",
			-- widgetName = "widgetName",
			-- params = "params"
		-- }
	-- }
	self.detailsData = params.detailsData
	self.tabDataList = params.tabDataList
	self.sureOnSaveBackFunc = params.sureOnSaveBackFunc
	self.cancelFunc = params.cancelFunc
	self:fetch()
end

function M:removeAllChildWnd()
	local count = self.m_rtLayout:GetChildCount()
	for i = 1, count do
		local child = self.m_rtLayout:GetChildByIndex(0)
		self.m_rtLayout:RemoveChildWindow1(child)
	end
	self.curWin = nil
end

function M:onCancel()
	if self.cancelFunc then
		self.cancelFunc()
	end
end

function M:openWidget(key)
	local tabData = self.tabDataList and self.tabDataList[key]
    if not tabData then
        return
	end

	local widgetName = tabData.widgetName
	local widget = self.rightWidgets[key]
	if not widget then
		widget = UIMgr:new_widget(widgetName)
		widget:invoke("fillData", tabData.params)
		self.rightWidgets[key] = widget
	end
	self.m_rtLayout:AddChildWindow(widget)
end

function M:clickLeftTab(key)
	local btn = self.m_ltGrid:GetItem(key - 1)
	local btnText = btn:GetChildByIndex(0)
	self:setSelectMask(btn, btnText:GetText())
	self:removeAllChildWnd()
	self:openWidget(key)
end

function M:setSelectMask(btn, text)
    local y = btn:GetYPosition()[2]
    self.maskBtn:SetYPosition({0, y + 75})
    self.maskText:SetText(text)
end

function M:fetch()
	self:initLtLabel()
	self:clickLeftTab(1)
end

function M:initLtLabel()
	self.m_ltGrid:RemoveAllItems()
    self.m_ltGrid:SetMoveAble(false)
	self.m_ltGrid:InitConfig(0, 3, 1)
    for key, itemData in ipairs(self.tabDataList or {}) do
        local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "btn" .. key)
        btn:SetHeight({0, 80})
        btn:SetWidth({1, 0})
        btn:SetNormalImage("set:setting_base.json image:tap_left_empty.png")
        btn:SetPushedImage("set:setting_base.json image:tap_left_empty.png")
        local btnText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "btnText" .. key)
        btnText:SetArea({0, 0}, {0, 0}, {0.8, 0}, {1, 0})
        btnText:SetTextVertAlign(1)
        btnText:SetTextHorzAlign(1)
        btnText:SetText(Lang:toText(itemData.leftTabName))
        btnText:SetTextColor({44 / 255, 177 / 255, 130 / 255,1})
        btn:AddChildWindow(btnText)
        self:subscribe(btn, UIEvent.EventButtonClick, function()
			self:clickLeftTab(key)
        end)
		self.m_ltGrid:AddItem(btn)
	end
end

return M

