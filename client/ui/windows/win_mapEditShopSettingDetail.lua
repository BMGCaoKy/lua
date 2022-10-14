local shop_setting = require "editor.setting.shop_setting"
local editorSetting = require "editor.setting"
local global_setting = require "editor.setting.global_setting"
local entitySetting = require "editor.setting.entity_setting"

local goodsTypeData = {}
local goodsData = {}
local initShopData = {}
local lastLtBtn
local lastGoodsBtn
local shopChangeName
local isAddShop
local localTimer = {}
local bindMonsters
local originBindMonsters

local  selectList = 
{
	iron_ingot = "image/icon/currenty_3.png",
	gold_ingot = "image/icon/currenty_1.png",
	diamond = "image/icon/currenty_4.png",
	emerald = "image/icon/currenty_2.png",
	green_currency = "set:shop_sell.json image:icon_banknote.png",
	gDiamonds = "set:shop_sell.json image:icon_cube.png",
}

function M:initData()
	goodsTypeData = {}
	goodsData = {}
	bindMonsters = {}
	originBindMonsters = {}
	if not initShopData then
		return
	end
	goodsTypeData = initShopData.typeIndex or {}
	bindMonsters = initShopData.bindMonsters or {}
	originBindMonsters = Lib.copy(bindMonsters)
	for _, goodstype in pairs(goodsTypeData) do 
		local shopitem = shop_setting:getValByType(goodstype[1])
		goodsData[goodstype[1]] = shopitem or {}
	end
end

function M:onBindMonsterChanged()
	local new = {}
	local del = {}
	for key in pairs(originBindMonsters) do
		if not bindMonsters[key] then
			del[#del + 1] = key
		end
	end
	for key in pairs(bindMonsters) do
		if not originBindMonsters[key] then
			new[#new + 1] = key
		end
	end
	local groupName = self.shopFlag
	if next(new) then
		global_setting:checkBindMonster(groupName)
	end

	for _, fullName in ipairs(new) do
		entitySetting:setShopName(fullName, groupName, true)
	end

	for _, fullName in ipairs(del) do
		entitySetting:setShopName(fullName, nil, true)
	end
end

function M:init()
	WinBase.init(self, "shopSettingDetail.json")

	self:initUI()

	self:subscribe(self.cancelBtn, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)
	self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
		local shopData = global_setting:getMerchantGroup()
		if isAddShop then
			shopData[self.shopFlag] = {
				showTitle = shopChangeName,
				typeIndex = {},
				bindMonsters = {},
			}
		end
		for typeidx, data in pairs(goodsData) do
			shop_setting:saveValByType(typeidx, data, false)
		end
		shopData[self.shopFlag].showTitle = shopChangeName
		shopData[self.shopFlag].typeIndex = goodsTypeData
		shopData[self.shopFlag].bindMonsters = bindMonsters
		global_setting:saveMerchantGroup(shopData, false)
		self:onBindMonsterChanged()
		Lib.emitEvent(Event.EVENT_SHOP_SETTING_ADDSHOP_REFRESH)
		UI:closeWnd(self)
	end)
	self:subscribe(self.replaceBtn, UIEvent.EventButtonClick, function()
		UI:openMultiInstanceWnd("mapEditItemBagSelect", {backFunc = function(item)
				local typeIndex = lastLtBtn:data("typeidx")
				local idx = lastGoodsBtn:data("index")
				local name = lastGoodsBtn:receiver()._lb_bottom
				local icon = lastGoodsBtn:receiver()._img_item
				icon:SetImage(item:icon())
				name:SetVisible(true)
				name:SetText(Lang:toText(item.getNameText and item:getNameText() or item:cfg().itemname  or ""))
				local data = goodsData[typeIndex][idx]
				data.desc =  item.getNameText and item:getNameText() or item:cfg().itemname 
				data.tipDesc = item:cfg().desc
				if item:type() == "block" then
					data.itemName = "/block"
					data.blockName = item:full_name()
				else
					data.itemName = item:full_name()
				end
				goodsData[typeIndex][idx] = data
				self:selectGoodsBtn(lastGoodsBtn)
			end})
	end)
	self:subscribe(self.renameEdit, UIEvent.EventWindowTextChanged, function()
		local text = self.renameEdit:GetPropertyString("Text","")
		self.renameEdit:SetText("")
		if not lastLtBtn then
			return
		end
		if text ~= "" then
			lastLtBtn:GetChildByIndex(0):SetText(Lang:toText(text))
			goodsTypeData[lastLtBtn:data("index")][2] = text
		end
	end)
	self:subscribe(self.deleteBtn, UIEvent.EventButtonClick, function()
		local function fun()
			if not lastLtBtn then
				return
			end
			local typeidx = lastLtBtn:data("typeidx")
			local idx = lastLtBtn:data("index")
			table.remove(goodsTypeData, idx)
			goodsData[typeidx] = nil
			self:initGoodsTypeGird()
			local count = self.ltGrid:GetItemCount()
			if count <= 1 then
				lastLtBtn = nil
			elseif count > idx then
				lastLtBtn = self.ltGrid:GetItem(idx)
			else
				lastLtBtn = self.ltGrid:GetItem(count - 1)
			end
			self:selectLtBtn(lastLtBtn, 9)
			if lastLtBtn then
				self:setLtGridOffSet(lastLtBtn:data("index"), true)
			end
		end
		local tipContext = Lang:toText("win.map.global.setting.shop.delete.classification") or ""
		local tipsWnd = UI:openWnd("mapEditTeamSettingTip", fun, nil, tipContext)
		tipsWnd:switchBtnPosition()
	end)
	self:subscribe(self.upBtn, UIEvent.EventButtonClick, function()
		if not lastLtBtn then
			return
		end
		local idx = lastLtBtn:data("index")
		if idx > 1 then
			local typedata = goodsTypeData[idx]
			table.remove(goodsTypeData, idx)
			table.insert(goodsTypeData, idx - 1, typedata)
			self:initGoodsTypeGird()
			lastLtBtn = self.ltGrid:GetItem(idx - 1)
			self:selectLtBtn(lastLtBtn, 9)
			self:setLtGridOffSet(idx-1)
		end
	end)
	self:subscribe(self.downBtn, UIEvent.EventButtonClick, function()
		if not lastLtBtn then
			return
		end
		local idx = lastLtBtn:data("index")
		local count = self.ltGrid:GetItemCount()
		if idx < count - 1 then
			local typedata = goodsTypeData[idx]
			table.remove(goodsTypeData, idx)
			table.insert(goodsTypeData, idx + 1, typedata)
			self:initGoodsTypeGird()
			lastLtBtn = self.ltGrid:GetItem(idx + 1)
			self:selectLtBtn(lastLtBtn, 9)
			self:setLtGridOffSet(idx+1)
		end
	end)
	self:subscribe(self.shopNameEdit, UIEvent.EventWindowTouchDown, function()
		self.shopNameEdit:SetTextWithNoTextChange(self.shopNameText:GetText())
	end)
	self:subscribe(self.shopNameEdit, UIEvent.EventWindowTextChanged, function()
		local text = self.shopNameEdit:GetPropertyString("Text","")
		if text ~= "" then
			self:setShopName(text)
			self.shopNameEdit:SetText("")
			shopChangeName = text
		end
	end)

	self.bindMonsterBtn = self:child("shop-layout-bindMonster")
	local strLength = #Lang:toText("win.map.global.setting.shop.details.bindMonster")
	if strLength > 15 then
		self.bindMonsterBtn:SetWidth({0, 270})
	end
	self:subscribe(self.bindMonsterBtn, UIEvent.EventButtonClick, function()
		local wndMultiSelect = UI:openWnd("mapEditItemBagMultiSelect")
		wndMultiSelect:setMultiSelectData("entity", bindMonsters, function (data)
			bindMonsters = data
		end)
	end)
	self:subscribe(self:child("shop-layout-showShop"), UIEvent.EventWindowTouchUp, function()
		self.isShowShop = not self.isShowShop
		local shopName = "" 
		if self.isShowShop then
			shopName = self.shopFlag
		end
		self.showShopCheck:SetChecked(self.isShowShop)
		global_setting:saveShowButtonShopName(shopName, false)
	end)
end

function M:initUI()

	self.sureBtn = self:child("shop-layout-btn_ok")
	self.sureBtn:child("shop-layout-btn_ok-text"):SetText(Lang:toText("global.sure"))
	self.cancelBtn = self:child("shop-layout-btn_cencel")
	self.cancelBtn:child("shop-layout-btn_cancel-text"):SetText(Lang:toText("global.cancel"))
	self.ltGrid = self:child("shop-layout-ltGrid")
	self.ltGrid:InitConfig(0,8,1)
	self.ltGrid:SetMoveAble(true)
	self.midGrid = self:child("shop-layout-midGrid")
	self.midGrid:InitConfig(10, 10, 5)
	self.midGrid:SetMoveAble(true)
	self.midGrid:SetAutoColumnCount(true)
	self.renameEdit = self:child("shop-layout-optBtn-rename_Edit")
	self.deleteBtn = self:child("shop-layout-optBtn-delete")
	self.upBtn = self:child("shop-layout-optBtn-up")
	self.downBtn = self:child("shop-layout-optBtn-down")
	self.goodsInfoTextGrid = self:child("shop-layout-item_tip-InfoGrid")
	local decText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "")
	decText:SetFontSize("HT12")
	decText:SetWidth({1, 0})
	decText:SetWordWrap(true)
	decText:SetTextColor({1, 1, 1, 1})
	self.goodsInfoTextGrid:SetAutoColumnCount(false)
	self.goodsInfoTextGrid:AddItem(decText)
	self.goodsReplaceBtn = self:child("shop-layout-item_tip-replaceBtn")
	self.replaceBtn = self:child("shop-layout-item_tip-replaceBtn")
	self.shopNameEdit = self:child("shop-layout-Title-show-frame")
	self.shopNameText = self:child("shop-layout-Title-show-text")
	self.showShopCheck = self:child("shop-layout-showShop-EndKillCheck")
	self:child("shop-layout-Item-Layout-Rt-Txt"):SetText(Lang:toText("win.map.global.setting.shop.details.title"))
	self:child("shop-layout-showShop-Text"):SetText(Lang:toText("win.map.global.setting.shopShop.text"))
	self:child("shop-layout-item_tip-replaceBtn_Text"):SetText(Lang:toText("win.map.global.setting.shop.details.btn"))
	self:child("shop-layout-Title_Text"):setTextAutolinefeed(Lang:toText("win.map.global.setting.shop.details.title.text"))
	self:child("shop-layout-bindMonster-BtnText"):SetText(Lang:toText("win.map.global.setting.shop.details.bindMonster"))
	self:child("shop-layout-Title_Text"):SetWordWrap(true)
	self:child("shop-layout-Title_Text"):SetWidth({0, 160})
end

function M:initShopUISelect()
	local shopName = global_setting:getShowButtonShopName()
	self.isShowShop = (shopName == self.shopFlag)
	self.showShopCheck:SetChecked(self.isShowShop)
end

function M:setLtGridOffSet(index, del)
	local offset = -self.ltGrid:GetVScrollOffset()
	local typeBtnHight = 42
	local moveStep = 50
	local gridHight = 304
	local set = -1
	if del then
		set = math.max(0, offset-moveStep)
	elseif offset > moveStep*index then
		if index == 1 then
			set = 0
		else
			set = moveStep*index
		end
	elseif	offset + gridHight < moveStep*index + typeBtnHight then
		set = moveStep*(index + 1) - gridHight
	end
	World.Timer(1, function()
		if set ~= -1 and UI:isOpen(self) then
			self.ltGrid:SetOffset(0, -set)
		end
	end)
end

function M:setMidGridOffSet(index, count)
	local offset = -self.midGrid:GetVScrollOffset()
	local gridHight = 204
	local gridRowSize = 5
	local set = gridHight - offset
	if index+gridRowSize < count then
		return
	end
	if count == gridRowSize then
		set = 0
	end
	World.Timer(1, function()
		if UI:isOpen(self) then
			self.midGrid:SetOffset(0, set)
		end
	end)
end

function M:setShopName(text)
	self.shopNameText:SetText(text)
	local width = self.shopNameText:GetFont():GetTextExtent(Lang:toText(text),1.0)
	self.shopNameText:SetWidth({0, width})
end

local function creatItem(data)
	local type
	local fullName = data.itemName
	if fullName == "/block" then
		type = "block"
	else
		type = "item"
	end
    local item = EditorModule:createItem(type,type == "block" and data.blockName or fullName)

	return item
end

function M:setGoodsInfo(data)
	local text = self.goodsInfoTextGrid:GetItem(0)
	local tipTxt = ""
	local icon = ""
	local txt = ""
	if data then
		local item = creatItem(data)
		tipTxt = Lang:formatText( (not data.tipDesc or data.tipDesc == "") and  "base_block_desc" or data.tipDesc)
		txt = Lang:toText(data.desc)
		icon = item:icon()
		self.goodsReplaceBtn:SetEnabledRecursivly(true)
		self.goodsReplaceBtn:setProgram("NORMAL")
		self.goodsReplaceBtn:SetNormalImage("set:setting_base.json image:btn_change_equip_n.png")
	else
		self.goodsReplaceBtn:SetEnabledRecursivly(false)
		self.goodsReplaceBtn:setProgram("NORMAL")
		self.goodsReplaceBtn:SetNormalImage("set:new_shop1.json image:btn_change_equip_null.png")
	end
	if text then
		text:setTextAutolinefeed(tipTxt)
		text:SetTextColor({64/255, 132/255, 75/255, 1})
		local high = text:GetTextStringHigh() + 20
		text:SetHeight({0, high})
	end
	self:child("shop-layout-item_tip_icon"):SetImage(icon)
	if string.len(txt) > 15 and World.Lang ~= "zh" then
		txt = string.sub(txt, 1, 12) .. "..."
	end
	self:child("shop-layout-item_tip_name"):SetText(txt)
end

function M:setBtnEnable(rename, del, up, down)
	local editBtn = self:child("shop-layout-optBtn-rename")
	editBtn:SetEnabledRecursivly( rename )
	editBtn:setProgram("NORMAL")
	self.deleteBtn:setEnabled(del)
	if rename then
		editBtn:SetNormalImage("set:new_shop1.json image:shop_left_btn_rename_nor.png")
	else
		editBtn:SetNormalImage("set:new_shop1.json image:shop_left_btn_rename_null.png")
	end

	if del then
		self.deleteBtn:SetNormalImage("set:new_shop1.json image:shop_left_btn_del_nor.png")
	else
		self.deleteBtn:SetNormalImage("set:new_shop1.json image:shop_left_btn_del_null.png")
	end

	if up ~= nil then
		self.upBtn:setEnabled(up)
		if up then
			self.upBtn:SetNormalImage("set:new_shop1.json image:shop_left_btn_up_nor.png")
		else
			self.upBtn:SetNormalImage("set:new_shop1.json image:shop_left_btn_up_null.png")
		end
	end
	if down ~= nil then
		self.downBtn:setEnabled(down)
		if down then
			self.downBtn:SetNormalImage("set:new_shop1.json image:shop_left_btn_down_nor.png")
		else
			self.downBtn:SetNormalImage("set:new_shop1.json image:shop_left_btn_down_null.png")
		end
	end
end

function M:selectLtBtn(clickLtBtn, step)
	if lastLtBtn then
		lastLtBtn:SetImage("set:setting_global.json image:icon_commoditytap_no.png")
		local typeidx = lastLtBtn:data("typeidx")
		if localTimer[typeidx] then
			localTimer[typeidx]()
			localTimer[typeidx] = nil
		end
	end
	self:setGoodsInfo()
	if not clickLtBtn then
		self:showGoods()
		self:setBtnEnable(false, false, false, false)
		return
	end
	clickLtBtn:SetImage("set:setting_global.json image:icon_commoditytap_ok.png")
	lastLtBtn = clickLtBtn
	lastGoodsBtn = nil
	self:setBtnEnable(true, true, true, true)
	local idx = lastLtBtn:data("index")
	local count = #goodsTypeData
	if idx == 1 then
		self:setBtnEnable(true, true, false, nil)
	end
	if idx == count then
		self:setBtnEnable(true, true, nil, false)
	end
	self:showGoods(clickLtBtn:data("typeidx"), step)
	self.midGrid:ResetPos()
end

function M:selectGoodsBtn(clickGoodsBtn)
	if lastGoodsBtn then
		lastGoodsBtn:receiver():onClick(false, "")
		lastGoodsBtn:receiver()._btn_close:SetVisible(false)
	end
	lastGoodsBtn = clickGoodsBtn
	if not clickGoodsBtn then
		self:setGoodsInfo()
		return
	end
	clickGoodsBtn:receiver():onClick(true, "set:setting_global.json image:bg_shopitem_act.png")
	clickGoodsBtn:receiver()._btn_close:SetVisible(true)
	self:setGoodsInfo(clickGoodsBtn:data("data"))
end

function M:getGoods(typeidx, index, data)
	if not data then
		return
	end
	local cell = UIMgr:new_widget("cell","shopSettingGridItem_edt.json")

	local function initCell()
		local itemBG = cell:receiver()._img_bg
		local name = cell:receiver()._lb_bottom
		local limitBG = cell:receiver()._smallIcon
		local limitText = cell:receiver()._text_limit
		local icon = cell:receiver()._img_item
		local colseBtn = cell:receiver()._btn_close
		local moneyIcon = cell:receiver()._img_frame_sign
		local moneyText = cell:receiver()._bottom_text
		local moneyMask = cell:receiver()._img_frame_masking
		local btn = cell:receiver()._cs_bottom
		local btnTxt = cell:receiver()._top_text
		local limit = tonumber(data.limit)
		if limit == -1  then
			limitBG:SetVisible(false)
			limitText:SetVisible(false)
		else
			limitBG:SetVisible(true)
			limitText:SetVisible(true)
		end
		moneyIcon:SetImage(selectList[data.coinName])
		moneyText:SetText(data.price)
		moneyText:SetTextColor({64/255, 132/255, 75/255, 1})
		local wid = moneyText:GetFont():GetTextExtent(data.price or "",1.0)
		moneyText:SetWidth({0, wid})
		local wid1 = moneyIcon:GetWidth()[2] + moneyText:GetWidth()[2]
		moneyMask:SetWidth({0, wid1})
		limitText:SetText(Lang:toText("win.map.global.setting.shop.item.limit") .. (data.limit or -1))
		btnTxt:SetText(Lang:toText("win.map.global.setting.shop.item.btn"))
		if World.Lang == "ru" or World.Lang == "pt" then
			btnTxt:SetFontSize("HT12")
			name:SetFontSize("HT10")
		end
		local descText = Lang:toText(data.desc)
		if string.len(descText) > 12 and World.Lang ~= "zh_CN" then
			descText = string.sub(descText, 1, 10) .. ".."
		end
		local item = creatItem(data)
		icon:SetImage(item:icon())
		name:SetVisible(true)
		name:SetText(descText)
		name:SetTextColor({99/255, 100/255, 106/255, 1})
		cell:SetHeight({0, 204})
		cell:SetWidth({0, 120})
		cell:setData("typeidx", typeidx)
		cell:setData("data", data)
		cell:setData("index", index)
	end
	local btn = cell:receiver()._cs_bottom
	local colseBtn = cell:receiver()._btn_close
	initCell()
	self:subscribe(colseBtn, UIEvent.EventButtonClick, function()
		if localTimer[typeidx] then
			return
		end
		self.midGrid:RemoveItem(cell)
		local goodsTypeIndex = lastLtBtn:data("typeidx")
		local goodsIdx = lastGoodsBtn:data("index")
		table.remove(goodsData[goodsTypeIndex], goodsIdx or 1)
		local function selectFunc()
			local count = self.midGrid:GetItemCount()
			if count <= 1 then
				lastGoodsBtn = nil
			elseif count > goodsIdx then
				lastGoodsBtn = self.midGrid:GetItem(goodsIdx)
			else
				lastGoodsBtn = self.midGrid:GetItem(count - 1)
			end
			self:selectGoodsBtn(lastGoodsBtn)
			if count > 0 and count % 5 == 0 then
				self:setMidGridOffSet(lastGoodsBtn:data("index"), count)
			end
		end
		self:showGoods(goodsTypeIndex, goodsIdx > 5 and goodsIdx or 5, selectFunc)
		--todo delete data
	end)

	self:subscribe(btn, UIEvent.EventButtonClick, function()
		--todo Sale settings
		UILib.openShopSetting(data, function(params)
			local goodsTypeIndex = lastLtBtn:data("typeidx")
			for k, v in pairs(params) do
				data[k] = v
			end
			initCell()
			goodsData[goodsTypeIndex][index] = data
		end)
	end)

	return cell
end

function M:getGoodsAddBtn()
	local item = GUIWindowManager.instance:CreateGUIWindow1("Layout", "AddLayout")
	item:SetHeight({0, 220})
	item:SetWidth({0, 120})
	local itemBtn = GUIWindowManager.instance:CreateGUIWindow1("Button", "AddBtn")
	itemBtn:SetHeight({0, 204})
	itemBtn:SetWidth({0, 120})
	itemBtn:SetHorizontalAlignment(1)
	itemBtn:SetVerticalAlignment(1)
	itemBtn:SetNormalImage("set:setting_global.json image:icon_shop_add_nor.png")
	itemBtn:SetPushedImage("set:setting_global.json image:icon_shop_add_act.png")
	item:AddChildWindow(itemBtn)
	self:subscribe(itemBtn, UIEvent.EventButtonClick, function()
		local typeidx = lastLtBtn:data("typeidx")
		--todo add goods item
		UI:openMultiInstanceWnd("mapEditItemBagSelect", {backFunc = function(item, isBuff)
			local data = Lib.copy(shop_setting:getTemplateItem())
			data.desc =  item.getNameText and item:getNameText() or item:cfg().itemname 
			data.tipDesc = item:cfg().desc
			data.type = typeidx
			data.limitType = item:cfg().forTeam and 2 or 1
            if isBuff then
                data.num = 1
            end
			if item:type() == "block" then
				data.itemName = "/block"
				data.blockName = item:full_name()
			else
				data.itemName = item:full_name()
			end
			table.insert(goodsData[typeidx], 1, data)
			lastGoodsBtn = nil
			self:showGoods(typeidx, 9)
		end})
	end)

	return item
end

function M:showGoods(typeidx, step, func)
	self.midGrid:RemoveAllItems()
	if lastLtBtn and typeidx then
		local addBtn = self:getGoodsAddBtn()
		self.midGrid:AddItem(addBtn)

		local itemcount = #goodsData[typeidx]
		local fir = 1
		local function loadItem()
			if not UI:isOpen(self) then
				return false
			end
			local offset = self.midGrid:GetVScrollOffset()
			local function judgeFunc()
				if func then
					self.midGrid:SetOffset(0, offset)
					func()
				else
					self.midGrid:ResetPos()
				end
			end
			for i = fir, itemcount do
				local data = goodsData[typeidx][i]
				local goods = self:getGoods(typeidx, i, data)
				if not lastGoodsBtn then
					self:selectGoodsBtn(goods)
				end
				self:subscribe(goods, UIEvent.EventWindowTouchUp, function()
					if not localTimer[typeidx] then
						self:selectGoodsBtn(goods)
					end
				end)
				self.midGrid:AddItem(goods)
				if i%step == 0 then
					fir = fir + step
					judgeFunc()
					return true
				end
			end
			judgeFunc()
			localTimer[typeidx] = nil
		end
		localTimer[typeidx] = World.Timer(1, loadItem)
	end
end

function M:getNextShopType()
	local allShopGroupData = global_setting:getMerchantGroup() or {}
	local maxType = 0
	for k, v in pairs(allShopGroupData) do
		for _, data in pairs(v.typeIndex or {}) do
			maxType = math.max(tonumber(data[1]), maxType)
		end
	end
	for _, idx in pairs(goodsTypeData) do
		maxType = math.max(tonumber(idx[1]), maxType)
	end
	return maxType + 1
end

function M:getGoodsTypeAddBtn()
	local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "addBtn")
	btn:SetHeight({0, 42})
	btn:SetWidth({0, 190})
	btn:SetNormalImage("set:new_shop1.json image:shop_left_add_nor.png")
	btn:SetPushedImage("set:new_shop1.json image:shop_left_add_nor.png")
	local edit = GUIWindowManager.instance:CreateGUIWindow1("Edit", "edit")
	edit:SetHeight({1, 0})
	edit:SetWidth({1, 0})
	edit:SetProperty("MaxTextLength", 15)
	btn:AddChildWindow(edit)
	self:unsubscribe(edit, UIEvent.EventEditTextInput)
	local canInsert = true
	self:subscribe(edit, UIEvent.EventWindowTouchUp, function()
		canInsert = true
	end)
	self:subscribe(edit, UIEvent.EventEditTextInput, function()
		local text = edit:GetPropertyString("Text","")
		if text ~= "" then
			edit:SetText("")
			local nextType = self:getNextShopType()
			if canInsert then
				table.insert(goodsTypeData, 1, {nextType, text})
				canInsert = false
			else
				goodsTypeData[1] = {nextType, text}
			end
			goodsData[nextType] = goodsData[nextType] or {}
			lastLtBtn = nil
			World.Timer(1, function()
				self:initGoodsTypeGird()
			end)
			World.Timer(2, function()
				if UI:isOpen(self) then
					self.ltGrid:ResetPos()
				end
			end)
		end
	end)
	return btn
end

function M:createGoodsTypeBtn(typeidx, text, index)
	local btn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "btn" .. tostring(typeidx))
	btn:setData("typeidx", typeidx)
	btn:setData("index", index)
	btn:SetHeight({0, 42})
	btn:SetWidth({0, 190})
	btn:SetImage("set:setting_global.json image:icon_commoditytap_no.png")
	local textWnd = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "text")
	textWnd:SetHeight({1, 0})
	textWnd:SetWidth({1, 0})
	textWnd:SetTextVertAlign(1)
	textWnd:SetTextHorzAlign(1)
	textWnd:SetText(Lang:toText(text))
	btn:AddChildWindow(textWnd)
	self:subscribe(btn, UIEvent.EventWindowTouchUp, function()
		self:selectLtBtn(btn, 3)
	end)
	return btn
end

function M:removeItems(grid, beginIndex, endIndex)
	local count = grid:GetItemCount()
	local items = {}
	if not endIndex then
		endIndex = count - 1
	end
	endIndex = endIndex > count - 1 and count - 1 or endIndex
	for index = beginIndex, endIndex do
		items[#items + 1] = grid:GetItem(index)
	end
	for _, item in pairs(items) do
		grid:RemoveItem(item)
	end
end

function M:initGoodsTypeGird()
	self:removeItems(self.ltGrid, 1)
	self:selectLtBtn()
	self.addBtn = self.addBtn or self:getGoodsTypeAddBtn()
	self.ltGrid:AddItem(self.addBtn)

	for i, goodstype in pairs(goodsTypeData) do 
		local typeBtn = self:createGoodsTypeBtn(goodstype[1], goodstype[2], i)
		self.ltGrid:AddItem(typeBtn)
		if not lastLtBtn then
			self:selectLtBtn(typeBtn, 3)
		end
	end

end

function M:saveData()

end

function M:onOpen(shopFlag, addShop, shopTitle)
	initShopData = Lib.copy(global_setting:getMerchantGroup()[shopFlag])
	isAddShop = addShop
	if isAddShop then
		shopChangeName = shopTitle
	else
		shopChangeName = initShopData.showTitle
	end
	lastLtBtn = nil
	lastGoodsBtn = nil
	self.shopFlag = shopFlag
	self:setShopName(Lang:toText(shopChangeName))
	self:initData()
	self:initGoodsTypeGird()
	self:initShopUISelect()
end

function M:onClose()
	
end

function M:onReload(reloadArg)

end

return M