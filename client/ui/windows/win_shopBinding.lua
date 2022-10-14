local entity_obj = require "editor.entity_obj"
local entitySetting = require "editor.setting.entity_setting"
local global_setting = require "editor.setting.global_setting"
local shop_setting = require "editor.setting.shop_setting"
local editorSetting = require "editor.setting"

local merchantGroup = World.cfg.merchantGroup
local cellPoolSize = World.cfg.merchantCellPoolSize or 12
local originGroupName

function M:init()
	WinBase.init(self, "shopBinding.json", true)
	self:child("shop-binding-title_text"):SetText(Lang:toText("editor.ui.selectShop"))
	self:child("shop-binding-btn_setting"):SetText(Lang:toText("editor.ui.toSetShop"))
	self:child("shop-binding-btn_cencel"):SetText(Lang:toText("global.cancel"))
	self:child("shop-binding-btn_ok"):SetText(Lang:toText("global.sure"))
	if World.Lang == "ru" or World.Lang == "pt" then
		self:child("shop-binding-btn_setting"):SetWidth({0, 240})
	end

	self.lastGroupIndex = -1
	self.m_currencyMap = {}
	self.m_selectGoodsIndex = 1

	self.showBuyResultTip = nil
	self.currentSelectGood = nil

	self.m_showTipTime = 20
	self.m_tipMessage = ""

	self.limitType = {
		{lang = "person_limit"},
		{lang = "team_limit"}
	}

	self.m_titleName = self:child("shop-preview-shop_name")
	self.m_titleName1 = self:child("shop-binding-type_text")
	self.m_tabLayout = self:child("shop-preview-Item-Layout-List")
	self.m_tabLayout:InitConfig(0,8,1)
	self.m_tabLayout:SetMoveAble(true)
	self.m_tabLayout:SetvScorllMoveAble(true)
	self.m_shopItemTip = self:child("shop-preview-item_tip")
	self.m_goodsIcon = self:child("shop-preview-item_tip_icon")
	self.m_shopItemName = self:child("shop-preview-item_tip_name")
	self.list = self:child("shop-preview-item_desc")
	self.m_shopItemTip:SetVisible(false)

	self.selectShopBtn = self:child("shop-binding-refresh_icon")
	self:subscribe(self.selectShopBtn, UIEvent.EventWindowClick, function()
		self:showPullDownSelect()
	end)
	self.emptyBg = self:child("shop-binding-preview_empty")
	self.shopPreview = self:child("shop-binding-preview")
	self.m_itemGridView = self:child("shop-preview-gridview")
	self.m_itemGridView:InitConfig(4, 4, 5)
	self:initCellsPool()

	self.pullDownLayout = self:child("shop-binding-type_select")
	self.pullDownLayout:SetVisible(false)

	self:subscribe(self:child("shop-binding-btn_cencel"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)

	self:subscribe(self:child("shop-binding-btn_ok"), UIEvent.EventButtonClick, function()
		self:onBindShopChanged()
		UI:closeWnd(self)
	end)

	self:subscribe(self:child("shop-binding-btn_setting"), UIEvent.EventButtonClick, function()
		UI:openWnd("mapEditGlobalSetting",  5, self.fullName)
	end)

	Lib.subscribeEvent(Event.EVENT_SHOP_BINGDING_REFRESH_WND,function()
		self:onOpen(self.fullName)
	end)

end

function M:onBindShopChanged()
	local groupName = self.lastGroupName
	if groupName == originGroupName then
		return
	end
	local shopData = global_setting:getMerchantGroup()
	local fullName = self.fullName
	if groupName then
		local new = shopData[groupName].bindMonsters
		if not new then
			new = {}
			shopData[groupName].bindMonsters = new
		end
		new[fullName] = true
	end
	if originGroupName then
		local old = shopData[originGroupName].bindMonsters
		if not old then
			old = {}
			shopData[originGroupName].bindMonsters = old
		end
		old[fullName] = nil
	end
	global_setting:saveMerchantGroup(shopData, true)
	entitySetting:setShopName(self.fullName, groupName, true)
end

function M:showPullDownSelect()
	self.pullDownLayout:CleanupChildren()
	local pullDown = UIMgr:new_widget("pullDown")
	pullDown:SetVisible(true)
	self.pullDownLayout:SetVisible(true)
	self.pullDownLayout:AddChildWindow(pullDown)
	pullDown:invoke("fillData", {
		selectList = self.selectList,
		value = self.selectIndex,
		backFunc = function(index)
			self.pullDownLayout:SetVisible(false)
			self.selectIndex = index
			self:switchShopPreview(self.selectList[index].groupName)
		end
	})
end

function M:switchShopPreview(groupName)
	if not groupName or not merchantGroup[groupName] then
		self.emptyBg:SetVisible(true)
		self.shopPreview:SetVisible(false)
		self.m_titleName1:SetText(Lang:toText("editor.ui.notSetShop"))
		self.lastGroupName = nil
		return
	else
		self.emptyBg:SetVisible(false)
		self.shopPreview:SetVisible(true)
	end
	local title = merchantGroup[groupName].showTitle or "gui_merchant_titleName"
	self.m_titleName:SetText(Lang:toText(title))
	self.m_titleName1:SetText(Lang:toText(title))
	self:reset()
	self:addGroupTabView(groupName)
	self.lastGroupName = groupName
	self.openArgs = table.pack(groupName)
end

function M:initCellsPool()
	local cellList = {}
	local cellUseList = {}
	for i = 1, cellPoolSize do
		local item = GUIWindowManager.instance:LoadWindowFromJSON("shopPreviewItem.json")
		item:SetVisible(false)
		cellList[i] = item
		cellUseList[i] = false
	end
	self.cellList = cellList
	self.cellUseList = cellUseList
end

function M:reset()
	self.m_selectGoodsIndex = 1
	self.m_selectTypeIndex = nil
	self.m_tabLayout:RemoveAllItems()
end

function M:addGroupTabView(groupName)
	local selectFirst = false
	local indexCfg = merchantGroup[groupName].typeIndex
	if not next(indexCfg) then
		if self.usedItems then
			self:resetUsedCells()
		end
		return
	end
	local index = 1
	for _, type in ipairs(indexCfg) do
		local typeIndex = type[1]
		local radioItem = self:getTabItem(typeIndex, type[2], index - 1)
		radioItem:SetVisible(true)
		if not selectFirst then
			radioItem:SetSelected(true)
			selectFirst = true
		end
		index = index + 1
	end
end

function M:onOpen(fullName)
	self.pullDownLayout:SetVisible(false)
	self.selectIndex = 1
	merchantGroup = global_setting:getMerchantGroup()
	entitySetting:clearData(fullName)
	local groupName = entitySetting:getCfg(fullName).shopGroupName
	originGroupName = groupName
	local selectList = {
		{text = "editor.ui.notSetShop"}
	}
	local index = 1
	for curName, cfg in pairs(merchantGroup) do
		index = index + 1
		if curName == groupName then
			self.selectIndex = index
		end
		selectList[#selectList + 1] = {
			text = cfg.showTitle,
			groupName = curName,
		}
	end
	self.selectList = selectList
	self.fullName = fullName
	self:switchShopPreview(groupName)
end

local function switchFrame(old, new)
	if old then
		old:GetChildByIndex(0):SetVisible(false)
	end
	if new then
		new:GetChildByIndex(0):SetVisible(true)
	end
end

function M:getTabItem(typeIndex, typeName, index)
	local strTabName = string.format("Shop-Content-Tabs-Item-%d", index)
	local iconName = string.format("Shop-Content-Tabs-Item-Icon-%d", index)
	local radioItem = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", strTabName)
	radioItem:SetArea({ 0, 0 }, { 0, index * 50 }, { 1, 0 }, { 0, 42 })
	radioItem:SetNormalImage("set:setting_global.json image:icon_commoditytap_no.png")
	radioItem:SetPushedImage("set:setting_global.json image:icon_commoditytap_ok.png")
	radioItem:SetProperty("StretchType", "NineGrid")
	radioItem:SetProperty("StretchOffset", "15 15 15 15")
	radioItem:SetProperty("Font", "HT18")
	radioItem:SetProperty("BtnTextColor", tostring(235/255) .. " " .. tostring(235/255) .. " " .. tostring(235/255) .. " 1")
	radioItem:SetProperty("TextBorderColor", tostring(37/255) .. " " .. tostring(36/255) .. " " .. tostring(41/255) .. " 1")
	radioItem:SetText(Lang:toText(typeName))
	radioItem:SetProperty("TextHorzAlignment", "Centre")
	self:subscribe(radioItem, UIEvent.EventRadioStateChanged, function(statu)
		if statu:IsSelected() then
			self:onRadioChange(typeIndex)
			if self.m_itemGridView then
				self.m_itemGridView:ResetPos()
			end
		--     --todo: btn style
		-- else
		--     --todo: btn style
		end
	end)
	self.m_tabLayout:AddItem(radioItem)
	return radioItem
end

local function getOneCell(self)
	local cellUseList, cellList = self.cellUseList, self.cellList
	for i = 1, cellPoolSize do
		if not cellUseList[i] then
			cellUseList[i] = true
			return cellList[i]
		end
	end
	-- new cell
	local item = GUIWindowManager.instance:LoadWindowFromJSON("shopPreviewItem.json")
	item:SetVisible(false)
	cellPoolSize = cellPoolSize + 1
	self.cellList[cellPoolSize] = item
	self.cellUseList[cellPoolSize] = true
	return item
end

function M:addGoodsItem(item)
	local maxWidth = (self.m_itemGridView:GetPixelSize().x - 4 * 4) / 5
	local goodsItem = getOneCell(self)
	goodsItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, math.min(maxWidth, 135) }, { 0, 150 })
	self:updateItem(goodsItem, item)
	self.m_itemGridView:AddItem(goodsItem)
	goodsItem:SetVisible(true)
	return goodsItem
end

function M:updateItem(goodsItem, item)
	local m_goodsIcon = goodsItem:child("shop-preview-img_item")
	local m_buy = goodsItem:child("shop-preview-img_masking")
	local m_goodsLimit   = goodsItem:child("shop-preview-widget-cell-samll")
	m_goodsLimit:SetVisible(false)
	local limitLang = m_goodsLimit:GetChildByIndex(0)
	local limitType = tonumber(item.limitType)
	if limitType and self.limitType[limitType] and tonumber(item.limit) > 0 then
		m_goodsLimit:SetVisible(true)
		limitLang:SetText(Lang:toText({self.limitType[limitType].lang, item.limit}))
	end
	local m_currencyIcon = goodsItem:child("shop-preview-img_sign")
	local m_goodPrice = goodsItem:child("shop-preview-bottom-text")
	local m_tipBtn = goodsItem:child("shop-preview-btn_tip")
	self:showItemIcon(m_goodsIcon, item.itemName, item.meta or item.blockName)
	local image = Coin:iconByCoinName(item.coinName)
	m_currencyIcon:SetImage(image)
	m_goodPrice:SetText(item.price)
	local width = m_buy:GetPixelSize().x
	local m_price = tonumber(item.price)
	local digits = 0
	while m_price > 10 do
		digits = digits + 1
		m_price = m_price / 10
	end
	local left = (width - (85 + 12 * digits)) / 2
	m_currencyIcon:SetXPosition({ 0, left + 20 })
	m_goodPrice:SetXPosition({ 0, 50 + left })
	goodsItem:child("shop-preview-item_name"):SetText(Lang:toText(item.desc))
	local index = self.m_itemGridView:GetItemCount() + 1
	self:unsubscribe(m_tipBtn, UIEvent.EventButtonClick)
	self:subscribe(m_tipBtn, UIEvent.EventButtonClick, function()
		self.m_selectGoodsIndex = index
		self:selectGood(goodsItem, item)
	end)
	if self.m_selectGoodsIndex == index then
		self:selectGood(goodsItem, item)
	end
end

local function createCell(self, text)
    local width = self.list:GetPixelSize().x
    local cell = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Cell")
    cell:SetWordWrap(true)
    cell:SetWidth({0, width})
    cell:SetText(Lang:formatText(text))
    cell:SetTextColor({ 64 / 255, 132 / 255, 75 / 255, 1 })
    cell:SetFontSize("HT12")
    local height = cell:GetTextStringHigh()
    cell:SetHeight({0, height})
    return cell
end

local function createCell(self, text)
    local width = self.list:GetPixelSize().x
    local cell = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Cell")
    cell:SetWordWrap(true)
    cell:SetWidth({0, width})
    cell:SetText(Lang:formatText(text))
    local height = cell:GetTextStringHigh()
    cell:SetHeight({0, height})
    return cell
end

function M:selectGood(goodsItem, item)
	self.m_shopItemTip:SetVisible(true)
	if self.currentSelectGood == goodsItem then
		return
	else
		switchFrame(self.currentSelectGood, goodsItem)
		self.currentSelectGood = goodsItem
	end
	self:showItemIcon(self.m_goodsIcon, item.itemName, item.meta or item.blockName)

	self.m_shopItemName:SetText(Lang:toText(item.desc))
	self.list:ClearAllItem()
	self.list:AddItem(createCell(self, item.tipDesc))
end

local function getNameByFullName(fullName)
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end

local function CreateItem(type, fullName)
	local item = {}
	local cfg

	function item:full_name()
		return fullName
	end
	
	function item:cfg()
		local rCfg = editorSetting:fetch(type, fullName) 
		return rCfg and rCfg.cfg
	end

	function item:type()
		return "item"
	end

	function item:icon()
		local name = getNameByFullName(fullName)
		local cfg = self:cfg()
		local image = cfg.icon
		if image and (image:find("set:") or image:find("http:") or image:find("https:")) then
			return image
		end
		local path = "plugin/myplugin/".. type .."/"  .. name .. "/" .. image
		return path
	end
	return item
end

function M:showItemIcon(itemIcon, itemName, blockId)
	local item
	if itemName == "/block" then
		item = Item.CreateItem(itemName, 1, function(_item)
			if tonumber(blockId) then
				_item:set_block_id(blockId)
			else
				_item:set_block(blockId)
			end
		end)
	else
		item = CreateItem("item", itemName)
	end
	if item then
		itemIcon:SetImage(item:icon())
		return
	end
end

local function putOneCell(self, cell)
	local cellUseList, cellList = self.cellUseList, self.cellList
	for i = 1, cellPoolSize do
		if cellUseList[i] then
			cellUseList[i] = false
			cellList[i] = cell
			return
		end
	end
end

function M:resetUsedCells()
	local cellUseList, cellList = self.cellUseList, self.cellList
	local usedItems = self.usedItems
	for _, cell in ipairs(usedItems) do
		cell:SetVisible(false)
		putOneCell(self, cell)
		self:unsubscribe(cell)
		self.m_itemGridView:RemoveItem(cell)
	end
end

function M:updateItemView(typeIndex)
	switchFrame(self.currentSelectGood)
	self.currentSelectGood = nil
	if not typeIndex then
		typeIndex = 1
	end
	local commoditys = shop_setting:getValByType(typeIndex)
	if not commoditys then
		return
	end
	if self.usedItems then
		self:resetUsedCells()
	end
	local usedItems = {}
	for _, item in pairs(commoditys) do
		usedItems[#usedItems + 1] = self:addGoodsItem(item)
	end
	self.usedItems = usedItems
	self.m_selectTypeIndex = typeIndex
end

function M:onRadioChange(typeIndex)
	if self.m_selectTypeIndex == typeIndex then
		return
	end
	self.m_selectGoodsIndex = 1
	self:updateItemView(typeIndex)
end

return M