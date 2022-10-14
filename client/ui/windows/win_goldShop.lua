local Tipdata = {
	showTypeTop = 1,
	showTime = 40
}

function M:init()
    WinBase.init(self, "partyPgShopBg.json", true)
	
	self.shopBg = self:child("partyPgShopBg-bg")
	self.titleName = self:child("partyPgShopBg-titleText")
    self.contentItems = self:child("partyPgShopBg-container")

	self.haveGoldCount = self:child("partyPgShopBg-havdCount")
	self.havegoldLayout = self:child("partyPgShopBg-goldhave")

	self.containerBg = self:child("partyPgShopBg-containerBg")
	self.shopList = self:child("partyPgShopBg-shopList")
	self.leftBtn = self:child("partyPgShopBg-goldBtn")

	self.gridView = UIMgr:new_widget("grid_view")
	self.gridView:invoke("INIT_CONFIG", 25, 15, 3)
	self.gridView:invoke("MOVE_ABLE", false)
	self.contentItems:AddChildWindow(self.gridView)
	self.goldType = World.cfg.partyGoldShops --金币种类
	self.selectedItem = nil
	self.coinId = 1

	self:child("partyPgShopBg-havdtext"):SetText(Lang:toText("gui.have_money_tip"))
    self:subscribe(self:child("partyPgShopBg-close"), UIEvent.EventButtonClick, function()
         UI:closeWnd(self)
    end)

	Lib.subscribeEvent(Event.EVENT_CHANGE_CURRENCY, function()
		 self:changeCurrency()
    end)

	Lib.subscribeEvent(Event.EVENT_BUY_APPSHOP_TIP, function(msg)
		if UI:isOpen(self) then
			 local choice = false
			 self:openBuyCoin(choice)
		end
    end)

	Lib.subscribeEvent(Event.EVENT_SEND_BUY_SHOP_RESULT, function(itemIndex, limit, msg, forceUpdate, succeed)
		if UI:isOpen(self) and self.buyIndex == itemIndex then
			self.buyIndex = nil
			if succeed then
				local showTime = 50
				Lib.emitEvent(Event.EVENT_SHOW_REWARD_EFFECT, "Image", self.selectedItem.icon, 1, showTime)
			else
				Client.ShowTip(Tipdata.showTypeTop, Lang:toText(msg), Tipdata.showTime)
			end	
		end
    end)

	self:initItemList()
end

function M:openBuyCoin(choice)
	if not choice then
		UI:closeWnd(self)
		Lib.emitEvent(Event.EVENT_SHOW_RECHARGE)
		return
	end
	UILib.openChoiceDialog({msgText = "lack_money_and_go_buy_gold"}, function(cancel)
		if not cancel then
			UI:closeWnd(self)
			Lib.emitEvent(Event.EVENT_SHOW_RECHARGE)
		end
	end)
end

function M:onOpen()
	
end

function M:initItemList()
	self.goodsCount = 0
	self.selectedItem = nil
	self:changeCurrency()
	local shopsItems = Shop:getGroups(self.goldType)

	self.titleName:SetText(Lang:toText("additionalcell.goldShop_icon.text"))
	self.gridView:SetVisible(true)
	self.contentItems:SetArea({ 0, 0}, { 0, -18 }, { 1, 0 }, { 0.83, 0 })
	self.havegoldLayout:SetVisible(true)
	self.shopList:SetVisible(false)
	self.leftBtn:SetVisible(false)
	self.containerBg:SetVisible(false)
	self.shopBg:SetImage("set:party_pg_shop_img.json image:bigBG.png")

	for _,group in pairs(shopsItems) do
		for _, item in pairs(group.goods) do
			self:addGoldItem(item)
		end	
	end
end

function M:addGoldItem(item)
	self.goodsCount = self.goodsCount + 1
    local strTabName = string.format("Gold-Item-%d", self.goodsCount)
    local goodsItem = GUIWindowManager.instance:CreateWindowFromTemplate(strTabName, "partyGoldShopItem.json")
    goodsItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, 253 }, { 0, 225})
    
	local button = goodsItem:child(strTabName .."_partyGoldShopItem-BuyBtn")
    local itemIcon = goodsItem:child(strTabName .."_partyGoldShopItem-itemImg")
    local itemNum = goodsItem:child(strTabName .."_partyGoldShopItem-descNum")
    local itemName = goodsItem:child(strTabName .."_partyGoldShopItem-desc")
    local priceIcon = goodsItem:child(strTabName .."_partyGoldShopItem-iconImg")
    local priceText = goodsItem:child(strTabName .."_partyGoldShopItem-price")

    self:subscribe(button, UIEvent.EventButtonClick, function()
		self.selectedItem = item
		self.buyIndex = item.index
		local msg = {"ui_sure_to_pay", Lang:toText(item.desc)}
		local showArgs = {
			msgText = msg,
			leftText = "ui_cancel",
			leftCoinId = -1,
			rightCoinId = item.coinId,
			rightText = item.price
		}
		UILib.openPayDialog(showArgs, function(selectedLeft)
			if UI:isOpen(self) and not selectedLeft then
				Shop:requestBuyStop(self.selectedItem.index, 1)
			end
		end) 
    end)
    priceText:SetText(item.price)
    itemName:SetText(Lang:toText(item.desc or ""))
    itemNum:SetText(Lang:toText(item.num))
    itemNum:SetVisible(true)
	itemIcon:SetImage(item.icon)
    priceIcon:SetImage(Coin:iconByCoinId(item.coinId))

    self.gridView:invoke("ITEM", goodsItem)
end

function M:changeCurrency()
    local wallet = Me:data("wallet")
    local coinCfg = Coin:GetCoinCfg()[1]
    if coinCfg and wallet[coinCfg.coinName] then
        local count = Coin:countByCoinName(Me, coinCfg.coinName)
        self.haveGoldCount:SetText(count or 0)
    end
end

return M