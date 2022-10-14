local itemID = {}
local regId = 0
local canClickUpgradeBtn = true

function M:init()
	WinBase.init(self, "UpgradePropsPanel.json", true)

	self.goodsCount = 0
	self:child("UpgradePropsPanel-TitleName"):SetText(Lang:toText("gui.upgrade.title.name"))
    self.tabs = self:child("UpgradePropsPanel-Content-Tabs")
	self.list = self:child("UpgradePropsPanel-list")
	self.itemList = self:child("UpgradePropsPanel-Content-ItemList")
	self.gridView = self:child("UpgradePropsPanel-Content-GirdView")
    self.gridView:InitConfig(0, 0, 4)
	self.tip = self:child("UpgradePropsPanel-Content-Tip")

	self:subscribe(self:child("UpgradePropsPanel-BtnClose"), UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_OPEN_UPGRADE_SHOP, false)
	end)

	Lib.subscribeEvent(Event.EVENT_SEND_ESPECIALLY_SHOP_Tip, function(msg)
		self:onUpgradeResult(msg)
    end)
	self:initPopups()

	self:updateList()
end


function M:addMenu(name,list_data)
	local btn = GUIWindowManager.instance:CreateGUIWindow1("Button")
	btn:SetArea({ 0, 0}, { 0, 0}, { 1, 10 }, { 0, 80 })
    btn:SetNormalImage("set:app_shop.json image:app_shop_tab_nor")
    btn:SetPushedImage("set:app_shop.json image:app_shop_tab_pre")
    btn:SetProperty("StretchType", "NineGrid")
    btn:SetProperty("StretchOffset", "15 15 15 15")
	btn:SetProperty("TextBorder", "true")
    btn:SetProperty("TextRenderOffset", "0 0")
    btn:SetText(Lang:toText(name))
	self:subscribe(btn, UIEvent.EventButtonClick, function()
		self.gridView:RemoveAllItems()
		for k,v in pairs(list_data) do
			self:addObject(v)
		end
	end)
	self.list:AddItem(btn)
end

function M:addObject(data)
    local maxWidth = (self.gridView:GetPixelSize().x - 8 * 3) / 4
    self.goodsCount = self.goodsCount + 1
    local strTabName = string.format("UpgradePropsPanel-Content-ItemList-GridView-Item-%d", self.goodsCount)
    local goodsItem = GUIWindowManager.instance:CreateWindowFromTemplate(strTabName, "UpgradePropItem.json")
    goodsItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, math.min(maxWidth, 280) }, { 0, 500 })
	self:updateObjectItem(goodsItem,data)
	itemID[data.data.id] = goodsItem
	self.gridView:AddItem(goodsItem)
end

function M:updateObjectItem(item,itemData)
	item:GetChildByIndex(0):GetChildByIndex(0):SetText(Lang:toText(itemData.data.title))
	if itemData.data.image then item:GetChildByIndex(1):GetChildByIndex(0):SetImage(itemData.data.image) end
	item:GetChildByIndex(2):SetText(Lang:toText("gui.upgrade.item.title.destitle"))
	item:GetChildByIndex(3):SetText(Lang:toText(itemData.data.des))
	local coinIcon = item:GetChildByIndex(4):GetChildByIndex(1)
	if itemData.data.deal_ico == "green_currency" then
		coinIcon:SetImage("set:jail_break.json image:jail_break_currency")
	elseif itemData.data.deal_ico == "gDiamonds" then
		coinIcon:SetImage("set:diamond.json image:Diamond-icon2.png")
	elseif itemData.data.deal_ico == "item" then
		coinIcon:SetImage(Item.CreateItem(itemData.data.deal_item):icon())
	end
	local priceLayout = item:GetChildByIndex(4)
	local priceItem = priceLayout:GetChildByIndex(0):GetChildByIndex(0)
	priceItem:SetText(itemData.data.price)
	priceItem:SetProperty("AllShowOneLine", "true")
	local width = math.min(math.max(100, priceItem:GetWidth()[2]), 180)
	priceItem:SetWidth({ 0, width + 25 })
	local btn = item:GetChildByIndex(5)
	if itemData.data.btn then
		btn:SetEnabled(true)
		btn:SetText(Lang:toText(itemData.data.btn))
        if itemData.data.key then
			btn:SetName(itemData.data.menu .. ":" .. itemData.data.key)
	    end
	else
		btn:SetEnabled(false)
		btn:SetVisible(false)
		btn:SetText("")
		btn:SetVisible(false)
		item:GetChildByIndex(4):SetVisible(false)
	end
	self:unsubscribe(btn)
	btn:SetEnabled(canClickUpgradeBtn)
	self:subscribe(btn, UIEvent.EventButtonClick, function()
		if canClickUpgradeBtn then
			regId = itemData.data.id
			self:onBtnUpgrade(itemData.data.menu,itemData,item:GetChildByIndex(1):GetChildByIndex(0))
			canClickUpgradeBtn = false
		end
		World.Timer(5, function()
			canClickUpgradeBtn = true
			btn:SetEnabled(true)
		end)
	end)
	item:GetChildByIndex(6):SetText(itemData.data.lv and Lang:toText(itemData.data.lv) or "")
end

function M:updateList(menu)
	self.menu = menu
	if regId ~= 0 then
		self:updateItem(menu, regId)
        return
	end
	self.gridView:RemoveAllItems()
	local index=nil
	self.list:ClearAllItem()
	for k,v in pairs(Me.espcially_shop_data) do
		index=k
		self:addMenu(k,Me.espcially_shop_data[k])
	end
	if index==nil then return end
	for k,v in pairs(Me.espcially_shop_data[index]) do
		self:addObject(Me.espcially_shop_data[index][k])

	end

    if self.list:getContainerWindow():GetChildCount() <= 1 then
        self.tabs:SetVisible(false)
        self.itemList:SetArea({ 0, -10 }, { 0, 10 }, { 1, -10 }, { 1, -10 })
    else
        self.tabs:SetVisible(true)
        self.itemList:SetArea({ 0, -16 }, { 0, 15 }, { 1, -294 }, { 1, -30 })
    end

end

function M:updateItem(menu, id)
    if itemID[id] and menu then
        self:updateObjectItem(itemID[id], Me.espcially_shop_data[menu][id])
    end
end

function M:initPopups()
	local popups = GUIWindowManager.instance:LoadWindowFromJSON("Lv3Popups.json")
	self.popups = popups
	self.itemList:AddChildWindow(popups)
	self.popups:SetVisible(false)

	local popupsWnd = popups:child("Lv3Popups-Base")
	local x,y = popupsWnd:GetPixelSize().x,popupsWnd:GetPixelSize().y
	popupsWnd:SetArea({0.5,- 0.5 * x},{0.5,- 0.5 * y},{0,x},{0,y})

	popups:child("Lv3Popups-Top_Text"):SetText(Lang:toText("gui.tip"))
	popups:child("Lv3Popups-Text"):SetText(Lang:toText("gui.skillbook.not.full"))
	popups:child("Lv3Popups-Btn_Text"):SetText(Lang:toText("sure"))
	self:subscribe(popups:child("Lv3Popups-Btn"), UIEvent.EventButtonClick, function()
		self.popups:SetVisible(false)
		Lib.emitEvent(Event.EVENT_OPEN_UPGRADE_SHOP, false)
		Lib.emitEvent(Event.EVENT_OPEN_APPSHOP, true)
	end)
	self:subscribe(popups:child("Lv3Popups-Close_Btn"), UIEvent.EventButtonClick, function()
		self.popups:SetVisible(false)
	end)
	self:subscribe(popups:child("Lv3Popups-Back"), UIEvent.EventWindowClick, function()
		self.popups:SetVisible(false)
	end)
end

function M:onBtnUpgrade(menu,itemData,item)
	Me:espShopCommit(menu,itemData.data.id,function(msg,result,needPopups)
		Lib.emitEvent(Event.EVENT_SEND_ESPECIALLY_SHOP_Tip,msg)
		--todo
		if result then
			item:PlayEffect()
		elseif needPopups then
			self.popups:SetVisible(true)
		end
	end)
end

function M:onUpgradeResult(msg)
    if self.tipTimer then
        self.tipTimer()
    end
    self.tip:SetText(Lang:toText(msg))
    local function resetTip()
		self.tip:SetText("")
    end
    self.tipTimer = World.Timer(20, resetTip)
end

function M:onClose()
	if self.popups then
		self.popups:SetVisible(false)
	end
	if World.cfg.autoClearUpgradeShop then
		regId = 0
		Me.espcially_shop_data[self.menu] = {}
	end
end

return M