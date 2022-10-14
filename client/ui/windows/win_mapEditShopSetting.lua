local global_setting = require "editor.setting.global_setting"

local shopData = {}
local shopDataList
local lastShopItem
local lastShopFlag

function M:init()
	WinBase.init(self, "shopSetting.json")
	self:initUI()
	self:initPopWnd()

	local func = function()
		self:initData()
		self:initGrid()
	end
	Lib.subscribeEvent(Event.EVENT_SHOP_SETTING_ADDSHOP_REFRESH, func)

	Lib.subscribeEvent(Event.EVENT_SHOP_SETTING_EDIT, function(text)
		local shopFlag = "shop" ..os.time()
		UI:openWnd("mapEditShopSettingDetail", shopFlag, true, text)
	end)

end

function M:initUI()
	self.shopList = self:child("Setting-shopList")
	self.shopList:InitConfig(30,20,7)
	self.shopList:SetvScorllMoveAble(true)
	self.shopList:SethScorllMoveAble(false)
	self.shopList:SetAutoColumnCount(false)
end

function M:initData()
	shopData = global_setting:getMerchantGroup() or {}
	shopDataList = shopDataList or {}

	local function inList(flag)
		for _,fg in pairs(shopDataList) do
			if flag == fg then
				return true
			end
		end
		return false
	end
    
	while(true)
	do
		local pi = true
		for _, flag in pairs(shopDataList) do
			if not shopData[flag] then
				table.remove(shopDataList, _)
				pi = false
				break
			end
		end
		if pi then
			break
		end
	end

	for flag, data in pairs(shopData) do
		if not inList(flag) then
			table.insert(shopDataList, 1, flag)
		end
	end
end

function M:initPopWnd()
	self.toolPopWnd = UI:openMultiInstanceWnd("mapEditPopWnd")

	self.popWndBgBtn = self.toolPopWnd:child("popWndRoot-BgBtn")
	self.toolSet = self.toolPopWnd:child("Setting-Shop-Item-Layout-Tool-Set")
	self.toolDelete = self.toolPopWnd:child("Setting-Shop-Item-Layout-Tool-Delete")
	self.toolWnd = self.toolPopWnd:child("Setting-Shop-Item-Layout-Tool")

	self.toolWnd:child("Setting-Shop-Item-Layout-Tool-Set-Text"):SetText(Lang:toText("win.map.global.setting.shop.set"))
	self.toolWnd:child("Setting-Shop-Item-Layout-Tool-Delete-Text"):SetText(Lang:toText("win.map.global.setting.shop.tool.delete"))

	self:setPopWndEnabled(false)

	self:subscribe(self.toolSet, UIEvent.EventButtonClick, function()
		UI:openWnd("mapEditShopSettingDetail", lastShopFlag)
		self:selectShopItem()
	end)

	local function deleteFun()
		shopData[lastShopFlag] = nil
		global_setting:saveMerchantGroup(shopData, false)
		self:initData()
		self:initGrid()
		UI:getWnd("mapEditGlobalSetting"):addDelShopName(lastShopFlag)
	end

	self:subscribe(self.toolDelete, UIEvent.EventButtonClick, function()
		self:createDelTips(deleteFun)
		self:selectShopItem()
	end)

	self:subscribe(self.popWndBgBtn, UIEvent.EventWindowTouchUp, function()
		self:selectShopItem()
	end)
end

function M:setPopWndEnabled(isEnable, btn)
    
	self.popWndBgBtn:SetEnabledRecursivly(isEnable)
	self.popWndBgBtn:SetVisible(isEnable)

	self.toolWnd:SetEnabledRecursivly(isEnable)
	self.toolWnd:SetVisible(isEnable)

	if isEnable then
		self:setPopWndPosition(btn)
	end
end

function M:setPopWndPosition(btn)
	local pos = btn:GetRenderArea()
	local posx = {[1] = 0, [2] = pos[1] + btn:GetPixelSize().x + 8}
	local posy = {[1] = 0, [2] = pos[2]}
	if posx[2] + 238 >= 1280 then
		posx[2] = pos[1] - 238 - 8
	end
	self.toolWnd:SetXPosition(posx)
	self.toolWnd:SetYPosition(posy)
end

function M:selectShopItem(clickItem)
	if lastShopItem then
		lastShopItem:child("setting-item-bg"):SetImage("set:new_shop1.json image:shop_icon_bg_nor.png")
	end
	if clickItem then
		clickItem:child("setting-item-bg"):SetImage("set:new_shop1.json image:shop_icon_bg_act.png")
		lastShopItem = clickItem
		lastShopFlag = clickItem:data("flag")
		self:setPopWndEnabled(true, clickItem)
	else
		lastShopItem = nil
		self:setPopWndEnabled(false)
	end
end

function M:createDelTips(fun)
	local tipContext = Lang:toText("win.map.global.setting.shop.delete.shop") or ""
	local tipsWnd = UI:openWnd("mapEditTeamSettingTip", fun, nil, tipContext)
	tipsWnd:switchBtnPosition()
end

local function checkNameLength(name, limitlength)
	name = Lang:toText(name)
    if Lib.getStringLen(name) > limitlength then
        name = Lib.subString(name, limitlength - 2) .. "..."
	end
	return name
end

function M:getShopItem(_flag, _name)
	local item = GUIWindowManager.instance:LoadWindowFromJSON("shopSettingListItem_edit.json")
	local itemText = item:child("setting-item-text")
	itemText:SetWordWrap(true)
	itemText:SetWidth({0, 180})
	itemText:setTextAutolinefeed(checkNameLength(_name, 12))
	item:setData("flag", _flag)
	self:subscribe(item, UIEvent.EventWindowTouchUp, function()
		self:selectShopItem(item)
	end)
	return item
end

function M:getAddShopItem()
	local item = GUIWindowManager.instance:LoadWindowFromJSON("shopSettingListItem_edit.json")
	item:RemoveChildWindow("setting-item-bg1")
	item:child("setting-item-text"):SetWordWrap(true)
	item:child("setting-item-text"):SetWidth({0, 180})
	item:child("setting-item-text"):setTextAutolinefeed(checkNameLength("win.map.global.setting.shop.add.shop", 22))
	self:subscribe(item, UIEvent.EventWindowTouchUp, function()
		CGame.instance:onEditorDataReport("click_global_setting_add_store", "")
		UI:openWnd("mapEditShopEditName")
	end)
	return item
end

function M:initGrid()
	self.shopList:RemoveAllItems()
	local addShopItem = self:getAddShopItem()
	self.shopList:AddItem(addShopItem)

	for _, shopflag in pairs(shopDataList) do
		local shopItem = self:getShopItem(shopflag, shopData[shopflag].showTitle)
		self.shopList:AddItem(shopItem)
	end
end

function M:saveData()

end

function M:onOpen(monsterfullName)
	self.monsterfullName = monsterfullName
	lastShopItem = nil
	lastShopFlag = nil
	self:initData()
	self:initGrid()
end

function M:onClose()
	if self.monsterfullName then
		Lib.emitEvent(Event.EVENT_SHOP_BINGDING_REFRESH_WND)
	end
end

function M:onReload(reloadArg)

end

return M