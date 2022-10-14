local widget_base = require "ui.widget.widget_base"

local M = Lib.derive(widget_base)

function M:init()
	widget_base.init(self)
	self._root:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
	local bg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "selectBg")
	bg:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
	bg:SetProperty("StretchType", "NineGrid")
	bg:SetProperty("StretchOffset", "10 10 10 10")
	self.bg = bg
	self:setBg("set:setting_base.json image:bg_pullDown.png")
	self._root:AddChildWindow(bg)
	self.grid = GUIWindowManager.instance:CreateGUIWindow1("GridView", "selectItems")
	self.grid:SetArea({0, 0}, {0, 0}, {1, -5}, {1, -5})
	self.bg:AddChildWindow(self.grid)
	self.grid:InitConfig(0, 0, 1)
	self.grid:SetAutoColumnCount(false)
	self.grid:SetVerticalAlignment(1)
	self.grid:SetHorizontalAlignment(1)
	self.selectFuncList = {}
end

function M:setBg(bg)
	self.bg:SetImage(bg)
end

function M:fillData(params)
	self.selectIndex = params.value or 1
	self.showCheckUI = params.showCheckUI == nil and true or params.showCheckUI
	self.selectList = params.selectList or {
		{
			text = "不設為商店",
		},
		{
			text = "裝備商店",
		},
		{
			text = "附魔商店",
		},
		{
			text = "ff商店",
		}
	}
	self.itemSize = params.itemSize or 60
	self.backFunc = params.backFunc
	self:initSelectListUI()
	if not params.disableSelect then
		self:select(self.selectIndex, false)
	else
		for _, selectFunc in pairs(self.selectFuncList) do
			selectFunc(false)
		end
	end
	local mask = GUIWindowManager.instance:CreateGUIWindow1("Layout", "")
	mask:SetLevel(1000)
	self:root():AddChildWindow(mask)
	mask:SetArea({0, -1500}, {0, -1500},{0, 3000}, {0, 3000})
	self:subscribe(mask, UIEvent.EventWindowClick, function()
		self:root():SetVisible(false)
	end)
end

function M:newItemUI()
	local item = GUIWindowManager.instance:CreateGUIWindow1("Layout", "")
	item:SetWidth({1, 0})
	item:SetHeight({0, 60})
	return item
end

function M:initItem(itemUI, itemData, index, len)

	local icon = itemData.icon
	local text = itemData.text
	local disable = itemData.disable
	local selectBg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")

	if index == 1 then
		selectBg:SetImage("set:setting_base.json image:bg_pullDwon_select_top.png")
	elseif index == len then
		selectBg:SetImage("set:setting_base.json image:bg_pullDown_select_bottom.png")
	else
		selectBg:SetImage("set:setting_base.json image:bg_pullDown_select_mid.png")
	end
	selectBg:SetProperty("StretchType", "NineGrid")
	selectBg:SetProperty("StretchOffset", "10 10 10 10")
	selectBg:SetArea({0, 0}, {0,0},{1,0},{1,0})
	itemUI:AddChildWindow(selectBg)
	--selectBg:SetVisible(false)

	if text then
		local textUI = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "")
		textUI:SetText(Lang:toText(text))
		textUI:SetProperty("Font", "HT14")
		textUI:SetTextColor({44 / 255, 177 / 255, 130 / 255,1})
		textUI:SetArea({0, 30}, {0, 0}, {1, -30}, {1, 0})
		itemUI:AddChildWindow(textUI)
		textUI:SetTextVertAlign(1)
	end

	if icon then
		local iconUI = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
		iconUI:SetArea({0, 19}, {0, 0}, {0, 40}, {0, 40})
		iconUI:SetVerticalAlignment(1)
		iconUI:SetImage(icon)
		itemUI:AddChildWindow(iconUI)
	end
	local selectIconUI = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
	selectIconUI:SetVerticalAlignment(1)
	selectIconUI:SetHorizontalAlignment(2)
	selectIconUI:SetArea({0, -25}, {0, 0}, {0,32},{0,22})
	selectIconUI:SetImage("set:setting_base.json image:check_click.png")
	itemUI:AddChildWindow(selectIconUI)

	local selectFunc = function(flag)
		selectIconUI:SetVisible(flag and self.showCheckUI)
		selectBg:SetVisible(flag)
	end 
	self.selectFuncList[index] = selectFunc
	self:subscribe(itemUI, UIEvent.EventWindowClick, function()
		self:select(index, true)
	end)
	if disable then
		itemUI:SetEnabledRecursivly(false)
        if text then
            itemUI:GetChildByIndex(1):SetTextColor({157 / 255, 157 / 255, 157 / 255, 1})
	    end
    end
end

function M:select(index, emitEvent)
	for _, selectFunc in pairs(self.selectFuncList) do
		selectFunc(false)
	end
	local selectFunc = self.selectFuncList[index]
	if selectFunc then
		selectFunc(true)
		if self.backFunc and emitEvent then
			self.backFunc(index)
		end
	end
end

function M:initSelectListUI()
	local selectList = self.selectList
	for index, itemData in pairs(selectList or {}) do
		local itemUI = self:newItemUI()
		self:initItem(itemUI, itemData, index, #selectList)
		self.grid:AddItem(itemUI)
	end
end

return M
