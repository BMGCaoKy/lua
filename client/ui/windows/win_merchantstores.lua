local type = {
    TOOL = 0,
    ARMOR = 1,
    ARMS = 2,
    BLOCK = 3,
    FOOD = 4,
    OTHERS = 5,
    UPGRADE = 6,
    COLOR = 7,
    WOOD = 8,
    STONE = 9,
    METAL = 10
}

function M:init()
    WinBase.init(self, "Shop.json", true)

    self._slot = {}
    self._item_pool = {}
    self._item_pool_num = 0
    self._item_pool_useNum = 0
    self.goodsCount = 0
    self.m_currencyMap = {}

    self.showBuyResultTip = nil

    self.m_showTipTime = 20
    self.m_tipMessage = ""

    self.m_titleName = self:child("Shop-Title-Name")
    self.m_tabLayout = self:child("Shop-Content-Tabs")
    self.m_currencyLayout = self:child("Shop-Currency")
    self.m_textTip = self:child("Shop-Content-Tip")
    self.m_goodsGridView = self:child("Shop-Content-Goods-List")

    self.m_shopItemTip = self:child("Shop-ItemTip")
    self.m_closeTipBtn = self:child("Shop-Item-Tip-button")
    self.m_goodsIcon = self:child("Shop-Item-Icon")
    self.m_shopItemName = self:child("Shop-Item-Tip-Name")
    self.m_shopItemBuyLayout = self:child("Shop-Item-buy-btn")
    self.m_shopItemBuyIcon = self:child("Shop-Item-buy-img")
    self.m_shopItemBuyCount = self:child("Shop-Item-buy-desc")
    self.m_shopItemTipDesc = self:child("Shop-Item-Tips-Desc")
    self.m_shopItemTip:SetVisible(false)
    self.m_closeTipBtn:SetEnabled(false)

    self:subscribe(self.m_closeTipBtn, UIEvent.EventButtonClick, function()
        self:onClickCloseShopItemTipBtn()
    end)

    Lib.subscribeEvent(Event.EVENT_SHOW_SHOP_ITEM_TIP, function(itemName, mate, image, coinImage, tipDesc, name, price)
        self:onShowShopItemTip(itemName, mate, image, coinImage, tipDesc, name, price)
    end)

    Lib.subscribeEvent(Event.EVENT_SEND_BUY_COMMODITY_RESULT, function(msg)
        self:updateItemView(self.m_selectTypeIndex)
        self:updateCurrent()
        self:onBuyGoodsResulf(msg)
    end)

    self.m_closeBtn = self:child("Shop-Btn-Close")
    self.m_itemGridView = GUIWindowManager.instance:CreateGUIWindow1("GridView", "Shop-Content-ItemList-GridView");
    self.m_itemGridView:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.m_itemGridView:InitConfig(6, 6, 4)
    self.m_goodsGridView:AddChildWindow(self.m_itemGridView)

    self.m_textTip:SetText("")

    self:subscribe(self.m_closeBtn, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)
end

function M:reset()
    self:updateItemView(self.m_selectTypeIndex)
    self.m_tabLayout:CleanupChildren()
    self._item_pool_num = 0
    self._item_pool_useNum = 0
end

local merchant = Commodity:getGrouds()

function M:onOpen(showType, showTitle)
    local title = showTitle or "gui_merchant_titleName"
    self.m_titleName:SetText(Lang:toText(title))
    self:reset()
    if merchant then
        local index = 1
        if not showType then
            for typeIndex in pairs(merchant) do
                self:addTabView(typeIndex, index - 1)
                index = index + 1
            end
        else
            for _, typeIndex in pairs(showType) do
                if merchant[typeIndex] then
                    self:addTabView(typeIndex, index - 1)
                    index = index + 1
                end
            end
        end
    end
    self:updateCurrent()
	self.openArgs = table.pack(showType, showTitle)
end

function M:updateCurrent()
    if self.m_currencyLayout then
        local i = 0
        for _, item in ipairs(Coin:GetCoinCfg()) do
            self:findCurrentViewByCoinId(item.coinName, i)
            i = i + 1
        end
    end
end

function M:updateSlot()
    local count = 0
	local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.BAG)
    for _, element in pairs(trayArray) do
        local id, bag = element.tid, element.tray
        local items = bag:query_items()
        for slot, item in pairs(items) do
            if count >= 9 then
                break
            end
            count = count + 1
            self._slot[count]:SetImage(item:icon())
        end
    end
end

function M:findCurrentViewByCoinId(coinName, index)
    if not self.m_currencyMap[coinName] then
        local strName = string.format("Shop-Currency-Item-%s", coinName)
        local strIconName = string.format("Shop-Currency-Item-Icon-%s", coinName)
        local strValueName = string.format("Shop-Currency-Item-Value-%s", coinName)
        local currencyItem = GUIWindowManager.instance:CreateGUIWindow1("Layout", strName)
        currencyItem:SetArea({ 0, index * 150 + 10 }, { 0, 0 }, { 0, 120 }, { 1, 0 })

        local currencyIcon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", strIconName)
        currencyIcon:SetArea({ 0, 0 }, { 0, 0 }, { 0, 20 }, { 0, 20 })
        currencyIcon:SetVerticalAlignment(1)
        local icon = Coin:iconByCoinName(coinName)
        currencyIcon:SetImage(icon)
        currencyItem:AddChildWindow(currencyIcon)

        local currencyValue = GUIWindowManager.instance:CreateGUIWindow1("StaticText", strValueName)
        currencyValue:SetArea({ 0, 30 }, { 0, 0 }, { 0, 90 }, { 1, 0 })
        currencyValue:SetVerticalAlignment(1)
        currencyValue:SetTextVertAlign(1)
        currencyValue:SetText(Coin:countByCoinName(Me, coinName))
        currencyItem:AddChildWindow(currencyValue)
        self.m_currencyMap[coinName] = currencyValue
        self.m_currencyLayout:AddChildWindow(currencyItem)
    end

    --todo 拿到玩家钱包里其他货币的数量
    self.m_currencyMap[coinName]:SetText(Coin:countByCoinName(Me, coinName))
    return self.m_currencyMap[coinName]
end

function M:addTabView(typeIndex, index)
    local strTabName = string.format("Shop-Content-Tabs-Item-%d", index)
    local iconName = string.format("Shop-Content-Tabs-Item-Icon-%d", index)
    local radioItem = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", strTabName)
    radioItem:SetArea({ 0, 0 }, { 0, index * 70 }, { 1, 0 }, { 0, 64 })
    radioItem:SetNormalImage("set:gui_shop.json image:shop_tab_nor")
    radioItem:SetPushedImage("set:gui_shop.json image:shop_tab_pre")
    radioItem:SetProperty("StretchType", "NineGrid")
    radioItem:SetProperty("StretchOffset", "15 15 15 15")

    local iconItem = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", iconName)
    iconItem:SetVerticalAlignment(1)
    iconItem:SetHorizontalAlignment(0)
    iconItem:SetArea({ 0, 30 }, { 0, 0 }, { 0, 30 }, { 0, 30 })

    local tabName, imageRes = self:getIcon(radioItem, typeIndex)

    radioItem:SetProperty("TextBorder", "true")
    radioItem:SetText(tabName)
    self:subscribe(radioItem, UIEvent.EventRadioStateChanged, function(statu)
        if statu:IsSelected() then
            self:onRadioChange(typeIndex)
            if self.m_itemGridView then
                self.m_itemGridView:ResetPos()
            end
        end
    end)
    iconItem:SetImage(imageRes)
    radioItem:AddChildWindow(iconItem)
    self.m_tabLayout:AddChildWindow(radioItem)
    if index == 0 then
        radioItem:SetSelected(true)
    end
end

function M:addGoodsItem(item)
    local maxWidth = (self.m_itemGridView:GetPixelSize().x - 6 * 3) / 4
    self.goodsCount = self.goodsCount + 1
    local strTabName = string.format("Shop-Content-ItemList-GridView-Item-%d", self.goodsCount)
    local goodsItem = GUIWindowManager.instance:CreateWindowFromTemplate(strTabName, "ShopGoogsItem.json")
    goodsItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, math.min(maxWidth, 180) }, { 0, 228 })
    self:updateItem(goodsItem, item)
    local good_item = {}
    good_item.widget = goodsItem
    good_item.data = item

    for _, xx in ipairs(self._item_pool) do
        assert(xx.widget ~= goodsItem)
    end
    self._item_pool[self.goodsCount] = good_item
    self._item_pool_num = self._item_pool_num + 1

    self.m_itemGridView:AddItem(goodsItem)
end

function M:updateItem(goodsItem, item)
    local m_goodsIcon = goodsItem:GetChildByIndex(0)
    local m_goodsDetails = goodsItem:GetChildByIndex(1)
    local m_buy = goodsItem:GetChildByIndex(2)
    local m_goodsNum = goodsItem:GetChildByIndex(3)
    local m_currencyIcon = m_buy:GetChildByIndex(0)
    local m_goodPrice = m_buy:GetChildByIndex(1)
    local m_tipBtn = goodsItem:GetChildByIndex(4)
    m_buy:SetText("")
    self:showItemIcon(m_goodsIcon, item.itemName, item.image, item.meta)
    m_goodsDetails:SetText(Lang:toText(item.desc))
    m_goodsNum:SetText(tostring(item.num))
    local image = Coin:iconByCoinName(item.coinName)
    m_currencyIcon:SetImage(image)
    m_goodPrice:SetText(item.price)
    local width = m_buy:GetPixelSize().x
    local m_price = item.price
    local digits = 0
    while m_price > 10 do
        digits = digits + 1
        m_price = m_price / 10
    end
    local left = (width - (85 + 12 * digits)) / 2
    m_currencyIcon:SetXPosition({ 0, left + 20 })
    m_goodPrice:SetXPosition({ 0, 45 + left })
    self:unsubscribe(m_buy, UIEvent.EventButtonClick)
    self:subscribe(m_buy, UIEvent.EventButtonClick, function()
        self:onBtnBuy(item)
    end)
    if string.len(item.tipDesc) > 0 then
        self:subscribe(m_tipBtn, UIEvent.EventButtonClick, function()
            local name = Lang:toText(item.desc)
            Lib.emitEvent(Event.EVENT_SHOW_SHOP_ITEM_TIP, item.itemName, item.meta, item.image, image, item.tipDesc, name, item.price)
        end)
    end
end

function M:showItemIcon(itemIcon, itemName, image, blockId)
    if image and string.len(image) > 0 then
        if itemIcon then
            itemIcon:SetImage(image)
        end
        return
    end
    if itemName == "" then
        if itemIcon then
            itemIcon:SetImage("")
        end
        return
    end

    --todo 默认根据item名字 取得item的图标
    local item
    if itemName == "/block" then
        item = Item.CreateItem(itemName, 1, function (_item)
            if tonumber(blockId) then
                _item:set_block_id(blockId)
            else
                _item:set_block(blockId)
            end
        end)
    else
        item = Item.CreateItem(itemName)
    end
    if item then
        itemIcon:SetImage(item:icon())
        return
    end
end

function M:updateItemView(typeIndex)
    if not typeIndex then
        return
    end
    self.m_itemGridView:RemoveAllItems()
    local maxWidth = (self.m_itemGridView:GetPixelSize().x - 6 * 3) / 4
    for _, item in pairs(merchant[typeIndex].commoditys) do
        local canShow = true
        if item.checkCond.funcName ~= "" then
            canShow = Me:checkCond(item.checkCond)
        end
        if canShow then
            self._item_pool_useNum = self._item_pool_useNum + 1
            if #self._item_pool == 0 then
                self:addGoodsItem(item)
            elseif self._item_pool_useNum < self._item_pool_num then
                local p_item = self._item_pool[self._item_pool_useNum]
                if p_item then
                    local goodsItem = p_item.widget
                    p_item.data = item
                    goodsItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, math.min(maxWidth, 190) }, { 0, 260 })
                    self:updateItem(goodsItem, item)
                    self.m_itemGridView:AddItem(goodsItem)
                else
                    self:addGoodsItem(item)
                end
            else
                self:addGoodsItem(item)
            end
        end
    end
    self.m_selectTypeIndex = typeIndex
end

function M:onRadioChange(typeIndex)
    if self.m_selectTypeIndex == typeIndex then
        return
    end
    self:updateItemView(typeIndex)
end

function M:onBtnBuy(item)
    Me:syncBuyCommodityGood(item.index)
end

function M:getIcon(radioItem, typeIndex)
    local group = merchant[typeIndex]
    local tabName, imageRes = ""
    if group.type == type.TOOL then
        tabName = Lang:toText("gui.shop.tab.tool")
        imageRes = "set:shop_tab_icon.json image:Tool"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.ARMOR then
        tabName = Lang:toText("gui.shop.tab.armor")
        imageRes = "set:shop_tab_icon.json image:Armor"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.ARMS then
        tabName = Lang:toText("gui.shop.tab.arms")
        imageRes = "set:shop_tab_icon.json image:Weapon"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.BLOCK then
        tabName = Lang:toText("gui.shop.tab.block")
        imageRes = "set:shop_tab_icon.json image:Block"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.FOOD then
        tabName = Lang:toText("gui.shop.tab.food")
        imageRes = "set:shop_tab_icon.json image:Food"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.OTHERS then
        tabName = Lang:toText("gui.shop.tab.other")
        imageRes = "set:shop_tab_icon.json image:Other"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.UPGRADE then
        tabName = Lang:toText("gui.shop.tab.upgrade")
        imageRes = "set:shop_tab_icon.json image:Upgrade"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.COLOR then
        tabName = Lang:toText("gui.shop.tab.color")
        imageRes = "set:shop_tab_icon.json image:Block"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.WOOD then
        tabName = Lang:toText("gui.shop.tab.wood")
        imageRes = "set:shop_tab_icon.json image:Block"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.STONE then
        tabName = Lang:toText("gui.shop.tab.stone")
        imageRes = "set:shop_tab_icon.json image:Block"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    elseif group.type == type.METAL then
        tabName = Lang:toText("gui.shop.tab.metal")
        imageRes = "set:shop_tab_icon.json image:Block"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    else
        tabName = Lang:toText("gui.shop.tab.other")
        imageRes = "set:shop_tab_icon.json image:Other"
        radioItem:SetProperty("TextRenderOffset", "20 0")
    end
    if group.name ~= "" then
        tabName = Lang:toText(group.name)
    end
    if group.icon ~= "" then
        imageRes = group.icon
    end
    return tabName, imageRes
end

function M:onBuyGoodsResulf(msg)
    if self.showBuyResultTip ~= nil then
        self.showBuyResultTip()
    end
    self.m_showTipTime = 20
    self.m_tipMessage = Lang:toText(msg)
    self.m_textTip:SetText(self.m_tipMessage)
    local function tip()
        self.m_showTipTime = self.m_showTipTime - 1
        if self.m_showTipTime <= 0 then
            self.m_showTipTime = 0
            self.m_tipMessage = ""
            self.m_textTip:SetText(self.m_tipMessage)
            return false
        end
        return true
    end
    self.showBuyResultTip = World.Timer(1, tip)
end

function M:onShowShopItemTip(itemName, meta, image, coinImage, tipDesc, name, price)
    --todo 点击货品显示详细介绍
    self.m_shopItemBuyIcon:SetImage(coinImage)
    self:showItemIcon(self.m_goodsIcon, itemName, image, meta)

    self.m_shopItemName:SetText(name)
    self.m_shopItemBuyCount:SetText(tostring(price))

    local width = self.m_shopItemBuyLayout:GetPixelSize().x
    local m_price = price
    local digits = 0
    while m_price > 10 do
        digits = digits + 1
        m_price = m_price / 10
    end
    local left = (width - (75 + 12 * digits)) / 2
    self.m_shopItemBuyIcon:SetXPosition({ 0, left })
    self.m_shopItemBuyCount:SetXPosition({ 0, 45 + left })
    self.m_shopItemBuyIcon:SetVisible(tonumber(price) > 0)
    self.m_shopItemBuyCount:SetVisible(tonumber(price) > 0)

    self.m_shopItemTipDesc:CleanupChildren()
    local attrs = Lib.splitString(tipDesc, "&")
    local index = 0
    for _, attr in pairs(attrs) do
        index = index + 1
        local stAttr = GUIWindowManager.instance:CreateGUIWindow1("StaticText", string.format("ShopItem-Tip-Desc-%d", index))
        stAttr:SetWidth({ 1, 0 })
        stAttr:SetHeight({ (1 / #attrs), 0 })
        stAttr:SetXPosition({ 0, 0 })
        stAttr:SetYPosition({ ((index - 1) * (1 / #attrs)), 0 })
        stAttr:SetWordWrap(true)
        if string.find(attr, "=") then
            local kvPair = Lib.splitString(attr, "=")
            stAttr:SetText(Lang:toText(kvPair))
        else
            stAttr:SetText(Lang:toText(attr))
        end

        self.m_shopItemTipDesc:AddChildWindow(stAttr)
    end

    self.m_shopItemTip:SetVisible(true)
    self.m_closeTipBtn:SetEnabled(true)
    self.m_closeTipBtn:SetTouchable(true)
end

function M:onClickCloseShopItemTipBtn()
    self.m_shopItemTip:SetVisible(false)
    self.m_closeTipBtn:SetEnabled(false)
    self.m_closeTipBtn:SetTouchable(false)
end

return M