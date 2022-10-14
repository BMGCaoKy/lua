
function M:init()
    WinBase.init(self, "Store.json", true)
    self.curItemIndex = -1
    self.curStoreId = -1
    self:initMain();
end

function M:onOpen(storeId, itemIndex)
    self.curItemIndex = itemIndex
    self.curStoreId = storeId
    self:updateItem()
end

function M:onClose()

end

function M:initMain()
    self:subscribe(self:child("Store-Close"), UIEvent.EventButtonClick, function()
        self:onClickCloseBtn()
    end)

    self:subscribe(self:child("Store-Next"), UIEvent.EventButtonClick, function()
        self:onClickNextBtn()
    end)

    self:subscribe(self:child("Store-Prev"), UIEvent.EventButtonClick, function()
        self:onClickPrevBtn()
    end)

    self:subscribe(self:child("Store-Info-Operation"), UIEvent.EventButtonClick, function()
        self:onOperation()
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_STORE, function()
        if UI:isOpen(self) then
            self:updateItem()
        end
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_STORE_ITEM, function(storeId, itemIndex, msg)
        if storeId == self.curStoreId and itemIndex == self.curItemIndex and UI:isOpen(self) then
            self:updateItem()
            self:updateTip(msg)
        end
    end)



    self.descTitle = self:child("Store-Info-Title")
    self.descTitle:SetText(Lang:getMessage("ui_store_item_desc_title"))
end

function M:onClickNextBtn()
    local store = Store:getStoreById(self.curStoreId)
    if store and self.curItemIndex < #store.items then
        self.curItemIndex = self.curItemIndex + 1
    elseif store then
        self.curItemIndex = 1
    else
        self.curItemIndex = -1
    end
    self:updateItem()
end

function M:onClickPrevBtn()
    local store = Store:getStoreById(self.curStoreId)
    if store and self.curItemIndex > 1 then
        self.curItemIndex = self.curItemIndex - 1
    elseif store then
        self.curItemIndex = #store.items
    else
        self.curItemIndex = -1
    end
    self:updateItem()
end

function M:onClickCloseBtn()
    UI:closeWnd(self)
end

function M:onOperation()
    if self.curStoreId > 0 and self.curItemIndex > 0 then
        Me:SyncStoreOperation(self.curStoreId, self.curItemIndex)
    end
end

function M:updateItem()
    if self.curStoreId > 0 and self.curItemIndex > 0 then
        local item = Store:getStoreItem(self.curStoreId, self.curItemIndex)
        self:initItemInfo(item)
    else
        self:onClickCloseBtn()
    end
end

function M:initItemInfo(item)
    self.btnBuy = self:child("Store-Info-Operation")
    self.itemDesc = self:child("Store-Info-Text")
    self.itemName = self:child("Store-Title-Name")
    self.itemIcon = self:child("Store-Info-Item-Icon")
    self.priceInfo = self:child("Store-Info-Price")
    self.priceIcon = self:child("Store-Info-Price-Icon")
    self.priceValue = self:child("Store-Info-Price-Text")

    self.itemName:SetText(Lang:getMessage(item.itemName))
    self.itemDesc:SetText(Lang:getMessage(item.desc))
    self.priceValue:SetText(tostring(item.price))
    self:setCoinIcon(self.priceIcon, item.coinId)
    --self.itemIcon:SetImage(item.icon)
    if item.status == -1 then
        self.btnBuy:SetVisible(false)
    elseif item.status == 0 then
        self.btnBuy:SetText("")
        self.btnBuy:SetVisible(true)
        self.priceInfo:SetVisible(true)
    elseif item.status == 1 then
        self.btnBuy:SetVisible(true)
        self.priceInfo:SetVisible(false)
        self.btnBuy:SetText(Lang:getMessage("ui_store_item_take_on"))
    elseif item.status == 2 then
        self.btnBuy:SetVisible(true)
        self.priceInfo:SetVisible(false)
        self.btnBuy:SetText(Lang:getMessage("ui_store_item_take_off"))
    end
end

function M:updateTip(msg)
    if string.len(msg) > 0 then
        --TODO
        if self.showOperationResultTip ~= nil then
            self.showOperationResultTip()
        end

        self.tvTip = self:child("Store-Tip")
        self.tvTip:SetText(Lang:getMessage(msg))
        self.tvTip:SetVisible(true)
        self.showTipTime = 30
        self.showOperationResultTip = World.Timer(1, function ()
            self.showTipTime = self.showTipTime - 1
            if self.showTipTime <= 0 then
                self.showTipTime = 0
                self.tvTip:SetText("")
                return false
            end
            return true
        end)
    end
end

function M:setCoinIcon(view, coinId)
    view:SetImage(Coin:iconByCoinId(coinId))
end

return M