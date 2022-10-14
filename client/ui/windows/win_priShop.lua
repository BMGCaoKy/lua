local Tipdata = {
	showTypeTop = 1,
	showTime = 40
}

local setting = require "common.setting"

local function getItemName(itemType, fullName)
	local name = ""
	if itemType == "Item" then
		local cfg = setting:fetch("item", fullName)
		name = cfg and cfg.itemname
    elseif itemType == "Block" then
		local cfg = setting:fetch("block", fullName)
		name = cfg and cfg.itemname
    elseif itemType == "Coin" then
        name = Coin:coinNameByCoinId(fullName)
    end
	return name
end

function M:init()
    WinBase.init(self, "partyPgShopBg.json", true)
	
	self.shopBg = self:child("partyPgShopBg-bg")
	self.titleName = self:child("partyPgShopBg-titleText")
    self.contentItems = self:child("partyPgShopBg-container")

	self.haveGoldText = self:child("partyPgShopBg-havdtext")
	self.haveGoldCount = self:child("partyPgShopBg-havdCount")
	self.havegoldLayout = self:child("partyPgShopBg-goldhave")

	self.containerBg = self:child("partyPgShopBg-containerBg")
	self.shopList = self:child("partyPgShopBg-shopList")
	self.leftBtn = self:child("partyPgShopBg-goldBtn")
	self.tipBuyGold = self:child("partyPgShopBg-enterGoldDesc")

	self.shopType = World.cfg.partypriShops --特权商品种类
	self.selectedItem = nil
	self.buyIndex = nil
	self.selectedBtn = nil
	self.shopItemList = {}
	self.checkTime = os.time()

	self:subscribe(self:child("partyPgShopBg-goldEnterBtn"), UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_SHOW_GOLD_SHOP, true)
		UI:closeWnd(self)
    end)

    self:subscribe(self:child("partyPgShopBg-close"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

	Lib.subscribeEvent(Event.EVENT_BUY_APPSHOP_TIP, function(msg)
		if UI:isOpen(self) then
			 local choice = false
			 self:openBuyCoin(choice)
		end
    end)

	Lib.subscribeEvent(Event.EVENT_SEND_BUY_SHOP_RESULT, function(itemIndex, limit, msg, forceUpdate, succeed)
		if UI:isOpen(self) and self.buyIndex == itemIndex and self.selectedBtn then
			self.buyIndex = nil
			if not succeed then
				--Lib.emitEvent(Event.EVENT_SHOW_REWARD_EFFECT, "Image", self.selectedItem.icon, 1)
			--else
				Client.ShowTip(Tipdata.showTypeTop, Lang:toText(msg), Tipdata.showTime)
			end
			local alreadyHad = 0
			if limit == alreadyHad then --已拥有
				local buyButton = self.selectedBtn
				buyButton:SetNormalImage("set:party_pg_shop_img.json image:btn_bg.png")
				buyButton:SetPushedImage("set:party_pg_shop_img.json image:btn_bg.png")
				buyButton:SetText(Lang:toText("already.had"))
				buyButton:child("partyPriShopItem-btnPricelayout"):SetVisible(false)
				self.selectedBtn:SetTouchable(false)
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
	local func = function(goodsInfo)
		for _, item in pairs(self.shopItemList) do
			if item:data("limit")~= -1 and item:data("limit") <= goodsInfo[item:data("index")] then
				local buyButton = item:child("partyPriShopItem-buyBtn")
				buyButton:SetNormalImage("set:party_pg_shop_img.json image:btn_bg.png")
				buyButton:SetPushedImage("set:party_pg_shop_img.json image:btn_bg.png")
				buyButton:SetText(Lang:toText("already.had"))
				buyButton:child("partyPriShopItem-btnPricelayout"):SetVisible(false)
			end
		end
	end
	local requestInterval = 5
	if os.time() - self.checkTime > requestInterval then
		self.checkTime = os.time()
		Me:sendPacket({pid = "GetGoodsInfo", indexs = self.indexs or {}}, func)
	end
end

function M:initItemList()
	self.selectedItem = nil

	local shopsItems = Shop:getGroups(self.shopType)
	
	self.titleName:SetText(Lang:toText("additionalcell.priShop_icon.text"))
	self.tipBuyGold:SetText(Lang:toText("gui.go.buy.gold"))
	self.shopList:SetVisible(true)
	self.leftBtn:SetVisible(true)
	self.containerBg:SetVisible(true)
	self.havegoldLayout:SetVisible(false)
	self.shopBg:SetImage("set:party_pg_shop_img.json image:bigBg2.png")
	self.contentItems:SetProperty("StretchType", "NineGrid")
	self.contentItems:SetProperty("StretchOffset", "20 20 10 50")
	self.contentItems:SetArea({ 0, 8}, { 0, -10 }, { 1, -20 }, { 0.83, 0 })
	self.contentItems:SetBackImage("set:party_pg_shop_img.json image:bg.png")
	self.leftBtn:SetArea({ 0, 0 }, { 0, -10 }, { 0, 260 }, { 1, -20 })
	self.shopList:SetArea({ 0, -16 }, { 0, 0 }, { 1, -290 }, { 1, -30 })
	self.containerBg:SetBackImage("set:party_pg_shop_img.json image:toGoldBg.png")
	self.containerBg:SetProperty("StretchType", "NineGrid")
	self.containerBg:SetProperty("StretchOffset", "20 20 10 50")
	self.containerBg:SetArea({ 0, 0 }, { 0, -10 }, { 1, -12 }, { 1, 0 })
	self.shopList:SetProperty("BetweenDistance", 2)
	self.btnKey = World.cfg.priShopKey

	local items = {}
	local indexs = {}
	for _,group in pairs(shopsItems) do
		for _, item in pairs(group.goods) do
			indexs[#indexs + 1] = item.index
			items[#items + 1] = item
		end
	end
	table.sort(items, function(item1, item2)
		if not item1.sort or not item2.sort then
			return false
		end
		return item1.sort < item2.sort
	end)
	local func = function(goodsInfo)
		for index, item in pairs(items) do
			item.haveCount = goodsInfo[item.index]
			self:addShopItem(item)
		end
	end
	self.indexs = indexs
	Me:sendPacket({pid = "GetGoodsInfo", indexs = indexs}, func)
end

function M:addShopItem(item)
	local shopItem = GUIWindowManager.instance:LoadWindowFromJSON("partyPriShopItem.json")
	shopItem:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, 135})
	
	local buyButton = shopItem:child("partyPriShopItem-buyBtn")
	local itemIcon = shopItem:child("partyPriShopItem-itemImg")
    local itemName = shopItem:child("partyPriShopItem-itemName")
    local priceIcon = shopItem:child("partyPriShopItem-icon")
	local priceText = shopItem:child("partyPriShopItem-price")
    local itemDesc = shopItem:child("partyPriShopItem-itemDesc")

	local notLimit = -1
	if item.limit == notLimit or item.haveCount < item.limit then
		self:subscribe(buyButton, UIEvent.EventButtonClick, function()
			self.selectedItem = item
			self.buyIndex = item.index
			self.selectedBtn = buyButton

			local msg = {"ui_sure_to_pay",Lang:toText(item.desc)}
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
	elseif item.limit ~= -1 and item.limit <= item.haveCount then
		buyButton:SetNormalImage("set:party_pg_shop_img.json image:btn_bg.png")
		buyButton:SetPushedImage("set:party_pg_shop_img.json image:btn_bg.png")
		buyButton:SetText(Lang:toText("already.had"))
		buyButton:child("partyPriShopItem-btnPricelayout"):SetVisible(false)
	end
	
	itemName:SetText(Lang:toText(item.name))
    priceText:SetText(item.price)
    itemDesc:SetText(Lang:toText(item.desc or ""))
	itemIcon:SetImage(item.icon)
    priceIcon:SetImage(Coin:iconByCoinId(item.coinId))
	shopItem:setData("index", item.index)
	shopItem:setData("limit", item.limit)
	self.shopItemList[#self.shopItemList + 1] = shopItem
	self.shopList:AddItem(shopItem)
end

return M