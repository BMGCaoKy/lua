local imageSet = L("imageSet", {})
local path = "set:g2020_bag.json image:"
imageSet.bg         = path .. "bg.png"
imageSet.titleBg    = path .. "titleBg.png"
imageSet.titleIcon  = path .. "titleIcon.png"
imageSet.boomIcon   = path .. "boomIcon.png"
imageSet.closeBtn   = path .. "closeBtn.png"
imageSet.not_tabItem_bg   = path .. "not_tabItem_bg.png"
imageSet.tabItem_bg   = path .. "tabItem_bg.png"


imageSet.item_bg   = path .. "item_bg.png"
imageSet.add   = path .. "add.png"
imageSet.sub   = path .. "sub.png"
imageSet.equip_level_1   = "image/equip_level_5.png"
imageSet.equip_level_2   = path .. "equip_level_3.png"
imageSet.equip_level_3   = path .. "equip_level_2.png"
imageSet.equip_level_4   = path .. "equip_level_4.png"
imageSet.equip_level_5   = path .. "equip_level_1.png"
imageSet.cancel_bg   = path .. "cancel_bg.png"

function M:initData()
    self.transferData = {}
    if World.cfg.transferData then
        self.transferData = World.cfg.transferData
    end
    self.tabItemList = {}
    self.curDelStatus = false
    self.handItem = Me:getHandItem()
end

function M:init()
    WinBase.init(self, "g2020_bag_ui.json")
    self:loadConfig()
    self:initUIName()
    self:initUIStyle()
	self:initLeftTab()
	self:initEvent()
end

function M:initEvent()
	self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd("bag_style_blue")
    end)
end

function M:loadConfig()
	self.UIConfig = World.cfg.bagMainUi or {
		{
			["tabName"] = "g2020-baby-bed",
			["selectLeft"] = {
				["icon"] = path .. "baby_car.png",
				["bg"] = path .. "tabItem_bg.png",
				["textColor"] = "0.8, 0.28, 0, 1",
				["TextBoader"] = "0.98, 0.97, 0.5, 1"
			},
			["notSelectLeft"] = 
			{
				["icon"] = path .. "not_baby_car.png",
				["bg"] = path .. "not_tabItem_bg.png",
				["textColor"] = "0.078, 0.317, 0.568, 1",
				["TextBoader"] = "0.62, 0.874, 0.96, 1"
			},
			["openWindow"] = "character_panel",
			["params"] = {
				["openIndex"] = 1,
			},
		},
		{
			["tabName"] = "g2020-food",
			["selectLeft"] = {
				["icon"] = path .. "food.png",
				["bg"] = path .. "tabItem_bg.png",
				["textColor"] = "0.8, 0.28, 0, 1",
				["TextBoader"] = "0.98, 0.97, 0.5, 1"
			},
			["notSelectLeft"] = 
			{
				["icon"] = path .. "not_food.png",
				["bg"] = path .. "not_tabItem_bg.png",
				["textColor"] = "0.078, 0.317, 0.568, 1",
				["TextBoader"] = "0.62, 0.874, 0.96, 1"
			},
			["openWindow"] = "character_panel",
			["params"] = {
				["openIndex"] = 2,
			},
		},
		{
			["tabName"] = "g2020-car",
			["selectLeft"] = {
				["icon"] = path .. "car.png",
				["bg"] = path .. "tabItem_bg.png",
				["textColor"] = "0.8, 0.28, 0, 1",
				["TextBoader"] = "0.98, 0.97, 0.5, 1"
			},
			["notSelectLeft"] = 
			{
				["icon"] = path .. "not_car.png",
				["bg"] = path .. "not_tabItem_bg.png",
				["textColor"] = "0.078, 0.317, 0.568, 1",
				["TextBoader"] = "0.62, 0.874, 0.96, 1"
			},
			["openWindow"] = "character_panel",
			["params"] = {
				["openIndex"] = 3,
			},
		},
		{
			["tabName"] = "g2020-toy",
			["selectLeft"] = {
				["icon"] = path .. "toy.png",
				["bg"] = path .. "tabItem_bg.png",
				["textColor"] = "0.8, 0.28, 0, 1",
				["TextBoader"] = "0.98, 0.97, 0.5, 1"
			},
			["notSelectLeft"] = 
			{
				["icon"] = path .. "not_toy.png",
				["bg"] = path .. "not_tabItem_bg.png",
				["textColor"] = "0.078, 0.317, 0.568, 1",
				["TextBoader"] = "0.62, 0.874, 0.96, 1"
			},
			["openWindow"] = "character_panel",
			["params"] = {
				["openIndex"] = 4,
			},
		},
		{
			["tabName"] = "g2020-task-item",
			["selectLeft"] = {
				["icon"] = path .. "task.png",
				["bg"] = path .. "tabItem_bg.png",
				["textColor"] = "0.8, 0.28, 0, 1",
				["TextBoader"] = "0.98, 0.97, 0.5, 1"
			},
			["notSelectLeft"] = 
			{
				["icon"] = path .. "not_task.png",
				["bg"] = path .. "not_tabItem_bg.png",
				["textColor"] = "0.078, 0.317, 0.568, 1",
				["TextBoader"] = "0.62, 0.874, 0.96, 1"
			},
			["openWindow"] = "character_panel",
			["params"] = {
				["openIndex"] = 5,
			},
		},
	}
	self.tabItemList = {}
end

function M:initUIName()
    self.closeBtn = self:child("root-close")
    self.leftTabList = self:child("root-left_list")
    self.bg = self:child("root-bg")
    self.itemsGrid = self:child("root-right_gridview")
    self.titleBg = self:child("root-title-layout")
    self.titleIcon = self:child("root-titleIcon")
    self.boomIcon = self:child("root-right-boom-icon")
    self.titleName = self:child("root-titleName")
    self.tabList = self:child("root-left_list")
    self.descBg = self:child("root-desc-bg")
    self.descLayout = self:child("root-desc")
    self.itemName = self:child("root-name")
    self.itemLevel = self:child("root-level")
	self.childLayout = self:child("root-right_contents")
end

function M:initUIStyle()
    self.bg:SetImage(imageSet.bg)
    self.titleBg:SetImage(imageSet.titleBg)
    self.titleIcon:SetImage(imageSet.titleIcon)
    self.boomIcon:SetImage(imageSet.boomIcon)
    self.closeBtn:SetNormalImage(imageSet.closeBtn)
    self.closeBtn:SetPushedImage(imageSet.closeBtn)
    self.titleName:SetText(Lang:toText("g2020-bag"))
end

function M:initLeftTab()
	self.tabList:SetInterval(7)
	for index = 1, #self.UIConfig do
		local item = self:newLeftTabItem()
		self.tabList:AddItem(item)
		self.tabItemList[index] = item
		self:subscribe(item, UIEvent.EventButtonClick, function()
			self:selectLeftTabItem(index)
		end)
	end
	self:selectLeftTabItem(1)
end

function M:newLeftTabItem()
    local item = GUIWindowManager.instance:LoadWindowFromJSON("g2020_bag_leftTab.json")
    return item
end

function M:selectLeftTabItem(selectIndex)
	for index, item in pairs(self.tabItemList) do
		local styleKey = "notSelectLeft"
		print(index, selectIndex, selectIndex == index)
		if index == selectIndex then
			styleKey = "selectLeft"
		end
		local styleCfg = self.UIConfig[index][styleKey]
		local nameUI = item:child("root-name")
		nameUI:SetText(Lang:toText(self.UIConfig[index].tabName))
		item:child("root-icon"):SetImage(styleCfg.icon)
		item:child("root-bg"):SetImage(styleCfg.bg)
		nameUI:SetProperty("TextColor", styleCfg.textColor)
		nameUI:SetProperty("BoaderColor", styleCfg.TextBoader)
	end
end

function M:openDefaultWin()
	if not self.curOpenWindow then
		self:openChirldWin(1)
	end
end

function M:openChirldWin(index)
	if not self.UIConfig[index] then
		return
	end
	local window = UI:getWnd(self.UIConfig[index].openWindow)
	if not window then
		return
	end
	window:onOpen(self.UIConfig[index].params)
	self.curOpenWindow = window
	print(Lib.v2s(window, 2))
	print(self.childLayout.AddChildWindow)
	self.childLayout:AddChildWindow(window._root)
end

function M:onOpen(params)
	self:openDefaultWin()
end

function M:onClose()
	self.curOpenWindow = nil
end

return M