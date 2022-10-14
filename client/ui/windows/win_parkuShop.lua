local Tipdata = {
	showTypeTop = 1,
	showTime = 40
}

function M:init()
    WinBase.init(self, "parkuShop.json", true)
	
	self.shopBg = self:child("parkuShop-bg")
	self.titleName = self:child("parkuShop-titleText")
    self.contentItems = self:child("parkuShop-container")

	self.itemGridView = self:child("parkuShop-itemGridView")
	self.itemGridView:InitConfig(10,10,3)

	self.shopType = World.cfg.parkuShops or {} --特权商品种类
	self.selectedItem = nil
	self.buyIndex = nil
	self.selectedBtn = nil

    self:subscribe(self:child("parkuShop-close"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

	Lib.subscribeEvent(Event.EVENT_BUY_APPSHOP_TIP, function(msg)
		if UI:isOpen(self) then
			Client.ShowTip(Tipdata.showTypeTop, Lang:toText(msg), Tipdata.showTime)
		end
    end)

	Lib.subscribeEvent(Event.EVENT_SEND_BUY_SHOP_RESULT, function(itemIndex, limit, msg, forceUpdate)
		if UI:isOpen(self) and self.buyIndex == itemIndex and self.selectedBtn or forceUpdate then
			self.buyIndex = nil
			if msg ~= "" then 
				Client.ShowTip(Tipdata.showTypeTop, Lang:toText(msg), Tipdata.showTime)
			end
			if self.shopIdx2BuyButton then 
				local button = self.shopIdx2BuyButton[itemIndex]
				self:updateBuyButton(button, limit)
			end
		end
	end)

	self:initItemList()
end

function M:initItemList()
	self.selectedItem = nil
	self.titleName:SetText(Lang:toText("additionalcell.parkuShop.title"))
	self.itemGridView:SetVisible(true)

	local shopsItems = Shop:getGroups(self.shopType)
	local items = {}
	local indexs = {}
	for _,group in pairs(shopsItems) do
		for _, item in pairs(group.goods) do
			indexs[#indexs + 1] = item.index
			items[item.index] = item
		end
	end
	local func = function(goodsInfo)
		self.shopIdx2BuyButton = {}
		for index, item in pairs(items) do
			item.haveCount = goodsInfo[index]
			self:addShopItem(item)
		end
	end
	Me:sendPacket({pid = "GetGoodsInfo", indexs = indexs}, func)
end

function M:addShopItem(item)
	local shopItem = GUIWindowManager.instance:LoadWindowFromJSON("parkuShopItem.json")
	local buyButton = shopItem:child("parkuShopItem-priceBtn")
	local itemIcon = shopItem:child("parkuShopItem-itemIcon")
	local priceImg = shopItem:child("parkuShopItem-priceImg")

	local notLimit = -1
	if item.limit == notLimit or item.haveCount < item.limit then
		self:subscribe(buyButton, UIEvent.EventButtonClick, function()
			self.selectedItem = item
			self.buyIndex = item.index
			self.selectedBtn = buyButton

			local msg = {"gui_you_want_to_buy_this",item.price , Lang:toText(item.desc)}
			local content = {
				msgText = msg,
				newUI = true,
			}
			UI:openWnd("alternativeDialog", content, function(selectedLeft)
				if UI:isOpen(self) and not selectedLeft then
					Shop:requestBuyStop(self.selectedItem.index, 1)
				end
			end) 
		end)
		buyButton:SetText(item.price)
		priceImg:SetImage(Coin:iconByCoinId(item.coinId))
	elseif item.limit ~= -1 and item.limit <= item.haveCount then
		buyButton:SetText(Lang:toText("already.had"))
		buyButton:SetTextHorzAlign(1)
		priceImg:SetVisible(false)
	end
	
	itemIcon:SetImage(UILib.getItemIcon(item.itemType, item.itemName))
	self.itemGridView:AddItem(shopItem)
	self.shopIdx2BuyButton[item.index] = {button = buyButton, price = item.price}
end

function M:updateBuyButton(buyButton, limit)
	local alreadyHad = 0
	local button = buyButton.button
	if limit == alreadyHad then --售罄
		button:SetText(Lang:toText("already.had"))
		button:SetTouchable(false)
		self:child("parkuShopItem-priceImg"):SetVisible(false)
	else
		button:SetText(buyButton.price)
		button:SetTouchable(true)
		self:child("parkuShopItem-priceImg"):SetVisible(true)
	end
end

return M