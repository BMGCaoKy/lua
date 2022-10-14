--enum
local defaultDefinition = {
    label = "Top"
}

local descFormat = {
    Top = "Right",
    Left = "Bottom"
}

function M:init()
    WinBase.init(self, "AppShop.json", true)

    self._item_pool = {}
    self._item_pool_num = 0
    self._item_pool_useNum = 0
    self.m_selectTab = nil
    self.goodsCount = 0
    self.m_showTipTime = 20
    self.m_item = nil
    self.m_buyCount = 1
    self.m_price = 0

    self.m_request_goodItem = {}

    --self.m_titleName = self:child("AppShop-TitleName"):SetText(Lang:toText("gui.app.shop"))
    self.titleTabs = self:child("AppShop-Title-Tabs")
    self.contentTip = self:child("AppShop-Content-Tip")
    self.contentItems = self:child("AppShop-Content-GridView-Items")
    self.contentDetailLayout = self:child("AppShop-Detail-Layout")
    self.gridView = UIMgr:new_widget("grid_view")
    self.gridView:invoke("INIT_CONFIG", 5, 5, 3)
    self.contentItems:AddChildWindow(self.gridView)

    self:subscribe(self:child("AppShop-Title-close"), UIEvent.EventButtonClick, function()
        self:button_close()
    end)

    self:subscribe(self:child("AppShop-Detail-Count-SubBtn"), UIEvent.EventButtonClick, function()
        if self.m_buyCount == 1 then
            return
        end
        self.m_buyCount = self.m_buyCount - 1
        self:updateCurrentGoods()
    end)
    self:subscribe(self:child("AppShop-Detail-Count-AddBtn"), UIEvent.EventButtonClick, function()
        if self.m_buyCount == self.m_item.stackLimit then
            return
        end
        self.m_buyCount = self.m_buyCount + 1
        self:updateCurrentGoods()
    end)
    self:child("AppShop-Detail-Buy-Btn"):SetText(Lang:toText("appShop.buy.button"))
    self:subscribe(self:child("AppShop-Detail-Buy-Btn"), UIEvent.EventButtonClick, function()
        if self.m_item then
            Shop:requestBuyStop(self.m_item.index, self.m_buyCount)
        end
    end)
    self.contentTip:SetText("")

    Lib.subscribeEvent(Event.EVENT_BUY_APPSHOP_TIP, function(msg)
        self:onBuyGoodsResult(Lang:toText(msg))
    end)
    Lib.subscribeEvent(Event.EVENT_SEND_BUY_SHOP_RESULT, function(itemIndex, limit, msg, count)
        self:showBuyGoodResult(itemIndex, limit, msg, count)
    end)
end

function M:onOpen()
    self:onShopUpdate()
end

function M:onShopUpdate()
    local shops = Shop:getGroups()
    if shops then
        local num = self.titleTabs:GetChildCount()
        for i = 1, num do
            self.titleTabs:RemoveChildWindow(self.titleTabs:GetChildByIndex(0))
        end
        local tab = UIMgr:new_widget("tab")
        for i, v in pairs(shops) do
            self:addTabView(v, tab, i - 1)
        end
        self.titleTabs:AddChildWindow(tab)
    end
end

function M:addTabView(group, tab, i)
    tab:invoke("ADD_BUTTON", group.name, function()
        self:onRadioChange(group)
    end)
    if i == 0 then
        tab:invoke("SELECTED", 0)
    end
end

function M:addGoodsItem(item)
    local maxWidth = (self.contentItems:GetPixelSize().x - 8 * 2) / 3
    self.goodsCount = self.goodsCount + 1
    local strTabName = string.format("AppShop-Content-GridView-Item-%d", self.goodsCount)
    local goodsItem = GUIWindowManager.instance:CreateWindowFromTemplate(strTabName, "AppShopItem.json")
    local Height = goodsItem:GetPixelSize().y
    goodsItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, maxWidth }, { 0, Height })
    self:updateItem(goodsItem, item)
    local good_item = {}
    good_item.widget = goodsItem
    good_item.data = item

    for _, xx in ipairs(self._item_pool) do
        assert(xx.widget ~= goodsItem)
    end
    self._item_pool[self.goodsCount] = good_item
    self._item_pool_num = self._item_pool_num + 1
    self.gridView:invoke("ITEM", goodsItem)
end

local function resetSelfData(self)
    self._item_pool = {}
    self._item_pool_num = 0
    self._item_pool_useNum = 0
    self.m_selectTab = nil
    self.goodsCount = 0
    self.m_showTipTime = 20
    self.m_item = nil
    self.m_buyCount = 1
    self.m_price = 0
    self.gridView:invoke("CLEAN")
end

function M:onRadioChange(group, radio)
    local maxWidth = (self.contentItems:GetPixelSize().x - 8 * 2) / 3
    self._item_pool_useNum = 0
    resetSelfData(self)
    for _, item in ipairs(group.goods) do
        if #self._item_pool == 0 then
            self._item_pool_useNum = self._item_pool_useNum + 1
            self:addGoodsItem(item)
        else
            self._item_pool_useNum = self._item_pool_useNum + 1
            if self._item_pool_useNum < self._item_pool_num then
                local p_item = self._item_pool[self._item_pool_useNum]
                if p_item then
                    local goodsItem = p_item.widget
                    p_item.data = item
                    local Height = goodsItem:GetPixelSize().y
                    goodsItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, maxWidth }, { 0, Height })
                    self:updateItem(goodsItem, item)
                    self.gridView:invoke("ITEM", goodsItem)
                else
                    self:addGoodsItem(item)
                end
            else
                self:addGoodsItem(item)
            end
        end
        --set CurrentItem
        if self._item_pool_useNum == 1 then
            local p_item = self._item_pool[1]
            local m_item_selected = p_item.widget:GetChildByIndex(0):GetChildByIndex(0)
            m_item_selected:SetVisible(true)
            self:setCurrentItem(item)
        end
    end
    self.m_selectTab = radio
end

function M:updateItem(goodsItem, item)
    local m_button = goodsItem:GetChildByIndex(0)
    local m_itemIcon = m_button:GetChildByIndex(1):GetChildByIndex(0)
    local m_itemNum = m_button:GetChildByIndex(1):GetChildByIndex(1)
    local m_itemName = m_button:GetChildByIndex(3)
    local m_price_icon = m_button:GetChildByIndex(2):GetChildByIndex(0)
    local m_price_text = m_button:GetChildByIndex(2):GetChildByIndex(1)
    local m_item_selected = m_button:GetChildByIndex(0)
    self:unsubscribe(m_button, UIEvent.EventButtonClick)
    self:subscribe(m_button, UIEvent.EventButtonClick, function()
        for _, p_item in pairs(self._item_pool) do
            p_item.widget:GetChildByIndex(0):GetChildByIndex(0):SetVisible(false)
        end
        m_item_selected:SetVisible(true)
        self:setCurrentItem(item)
    end)
    m_price_text:SetText(item.price)
    m_itemName:SetText(Lang:toText(item.desc or ""))
    m_itemNum:SetText(string.format("x%d", item.num))
    m_itemNum:SetVisible(true)
    m_item_selected:SetVisible(false)
    if item.hideNum == 1 then
        m_itemNum:SetVisible(false)
    end
    self:showItemIcon(m_itemIcon, item.itemType, item.itemName)
    m_price_icon:SetImage(Coin:iconByCoinId(item.coinId))
end

function M:setCurrentItem(item)
    self.m_item = item
    self.m_buyCount = 1
    self.m_price = item.price
    self:updateCurrentGoods(true)
end

function M:updateCurrentGoods(isUpdateAll)
    local item = self.m_item
    if not item then
        return
    end
    local price = item.price

    local m_price_text = self.contentDetailLayout:child("AppShop-Detail-Price-Text")
    local m_count_text = self.contentDetailLayout:child("AppShop-Detail-Count-Text")
    local m_item_limit_img = self.contentDetailLayout:child("AppShop-Detail-Item-Limit")
    local m_item_limit_num = self.contentDetailLayout:child("AppShop-Detail-Item-LimitText")
    m_count_text:SetText(self.m_buyCount)
    m_price_text:SetText(price * self.m_buyCount)
    if item.limit <= -1 then
        m_item_limit_img:SetVisible(false)
        m_item_limit_num:SetVisible(false)

    else
        m_item_limit_img:SetVisible(true)
        m_item_limit_num:SetVisible(true)
        m_item_limit_num:SetText(item.limit .. "/" .. item.limitMax)
    end
    if isUpdateAll then
        local m_detail_title = self.contentDetailLayout:child("AppShop-Detail-Title")
        local m_detail_item_img = self.contentDetailLayout:child("AppShop-Detail-Item-Img")
        local m_detail_text = self.contentDetailLayout:child("AppShop-Detail-Text")
        local m_price_icon = self.contentDetailLayout:child("AppShop-Detail-Price-Icon")
        m_detail_title:SetText(Lang:toText(item.desc or ""))
        m_detail_text:SetText(Lang:toText(item.detail or ""))
        self:showItemIcon(m_detail_item_img, item.itemType, item.itemName)
        m_price_icon:SetImage(Coin:iconByCoinId(item.coinId))
    end
end

function M:showBuyGoodResult(itemIndex, limit, msg)
    local shop = Shop:getShop(itemIndex)
    shop.limit = limit
    self:updateCurrentGoods()
    Lib.emitEvent(Event.EVENT_BUY_APPSHOP_TIP, msg)
end

function M:onBuyGoodsResult(msg)
    if self.showBuyResultTip ~= nil then
        self.showBuyResultTip()
    end
    self.contentTip:SetText(msg)
    self.m_showTipTime = 30
    local function tip()
        self.m_showTipTime = self.m_showTipTime - 1
        if self.m_showTipTime <= 0 then
            self.m_showTipTime = 0
            self.contentTip:SetText("")
            return false
        end
        return true
    end
    self.showBuyResultTip = World.Timer(1, tip)
end

function M:showItemIcon(itemIcon, itemType, itemName)
    local icon = ""
    if itemType == "Item" then
        local item = Item.CreateItem(itemName)
        icon = item:icon()
    elseif itemType == "Block" then
        local item = Item.CreateItem("/block", 1, function(item)
            item:set_block(itemName)
        end)
        icon = item:icon()
    elseif itemType == "Coin" then
        icon = Coin:iconByCoinName(itemName)
    end
    itemIcon:SetImage(icon)
end

function M:button_close()
    Lib.emitEvent(Event.EVENT_OPEN_APPSHOP, false)
end

function M:onClose()
    resetSelfData(self)
end

return M