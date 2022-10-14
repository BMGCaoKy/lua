local editorSetting = require "editor.setting"
local global_setting = require "editor.setting.global_setting"

local itemData
local lastItem
local dataStr

function M:init()
	WinBase.init(self, "rewardSettingDetail.json")

	self:initUI()

	self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
		local data = global_setting:getValByKey(dataStr)
		data.addItem = itemData
		global_setting:saveKey(dataStr, data, true)
		UI:closeWnd(self)
	end)
	self:subscribe(self.cancelBtn, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)
	self:subscribe(self.replaceBtn, UIEvent.EventButtonClick, function()
		UI:openMultiInstanceWnd("mapEditItemBagSelect", {
			backFunc = function(item, isBuff)
			local index = lastItem:data("index")
			itemData[index] = {
				type = item:type(), 
				name = item:cfg().fullName, 
				count = 1, 
				icon = item:icon(), 
				isBuff = isBuff }
			self:initGrid()
			self:selectItem(index, true)
		end})
	end)
	self:subscribe(self.addBtn, UIEvent.EventButtonClick, function()
		UI:openMultiInstanceWnd("mapEditItemBagSelect", {
			backFunc = function(item, isBuff)
			table.insert(itemData, 1, {
				type = item:type(), 
				name = item:cfg().fullName, 
				count = 1, 
				icon = item:icon(), 
				isBuff = isBuff })
			lastItem = nil
			self:initGrid()
		end})
	end)

end

function M:initUI()

	self.cancelBtn = self:child("reward-cencelBtn")
	self.cancelBtn:child("reward-cancelBtn_text"):SetText(Lang:toText("global.cancel"))
	self.sureBtn = self:child("reward-sureBtn")
	self.sureBtn:child("reward-sureBtn_text"):SetText(Lang:toText("global.sure"))
	self.addBtn = self:child("reward-addBtn")
	self.showGrid = self:child("reward-showGrid")
	self.showGrid:InitConfig(1, 6, 5)
	self.showGrid:SetvScorllMoveAble(true)
	self.showGrid:SethScorllMoveAble(false)
	self.showGrid:SetAutoColumnCount(true)
	self.tipName = self:child("reward-item-detail-item_tip_name")
	self.tipIcon = self:child("reward-item-detail-item_tip_icon")
	self.tipInfoGrid = self:child("reward-item-detail-item_tip-InfoGrid")
	self.replaceBtn = self:child("reward-item-detail-item_tip-replaceBtn")
	self:child("reward-item-detail-Rt-Txt"):SetText(Lang:toText("win.map.global.setting.shop.details.title"))
	self:child("reward-item-detail-item_tip-replaceBtn_Text"):SetText(Lang:toText("win.map.global.setting.shop.details.btn"))
	self:child("reward-set-Text"):SetText(Lang:toText("win.map.global.rewardSetting.setTitlle"))
	self:child("reward-set-Text1"):SetText(Lang:toText("editor.ui.upgrade.add"))
	self:child("reward-showGrid-title"):SetText(Lang:toText("win.map.global.rewardSetting.showGrid.titlle"))
end

function M:initData(dataString)
	dataStr = dataString
	itemData = Lib.copy(global_setting:getValByKey(dataStr).addItem)
end

local function CreateItemData(type, fullName, args)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

function M:getItem(index, data)
	local Item = UIMgr:new_widget("cell", "widgetSettingItem_edt.json")
	local numBtn = Item:receiver()._cs_bottom
	local delBtn = Item:receiver()._btn_close
	local nameText = Item:receiver()._lb_bottom
	local img = Item:receiver()._img_item
	local bg = Item:receiver()._img_bg
	local item = CreateItemData(data.type, data.name, {
		icon = data.icon
	})
	img:SetImage(item:icon())
	numBtn:SetVisible(not data.isBuff and true or false)
	Item:receiver()._bottom_text:SetText("X"..data.count)
	nameText:SetVisible(true)
	nameText:SetText(Lang:toText(item:getNameText() or ""))
	nameText:SetTextColor({64/255, 132/255, 75/255, 1})
	Item:setData("index", index)
	Item:setData("item", item)
	self:subscribe(delBtn, UIEvent.EventButtonClick, function()
		table.remove(itemData, index)
		self:initGrid()
		local count = self.showGrid:GetItemCount()
		local idx = nil
		if count < 1 then
			idx = nil
		elseif count <= index then
			idx = count
		elseif count > index then
			idx = index
		end
		self:selectItem(idx, idx and true or false)
	end)
	self:subscribe(bg, UIEvent.EventWindowTouchUp, function()
		self:selectItem(Item)
	end)

	self:subscribe(numBtn, UIEvent.EventButtonClick, function()
		UILib.openCountUI(data.count, function(num)
			itemData[index].count = num
			self:initGrid()
			self:selectItem(index, true)
		end)
	end)
	return Item
end

function M:setItemInfo(clickItem)

	self.tipInfoGrid:RemoveAllItems()
	self.tipName:SetText("")
	self.tipIcon:SetImage("")

	if not clickItem then
		self.replaceBtn:SetEnabledRecursivly(false)
		return
	end

	local item = clickItem:data("item")
	self.tipName:SetText(Lang:toText(item:getNameText() or ""))
	self.tipIcon:SetImage(item:icon())
	self.replaceBtn:SetEnabledRecursivly(true)
    
	local attrs = Lib.splitString(item:getDescText() or "", "&")
	local yOffset = 0
	local w = self.tipInfoGrid:GetPixelSize().x
	local h = self.tipInfoGrid:GetPixelSize().y
	for index, attr in pairs(attrs) do
		local stAttr = GUIWindowManager.instance:CreateGUIWindow1("StaticText", string.format("ShopItem-Tip-Desc-%d", index))
		stAttr:SetWordWrap(true)
		if string.match(attr, "false") then
			-- 进行匹配"{xxx}false\n"格式的字符串
			attr = string.gsub(attr, "{%a-}false%c+", "")
		end
		if string.find(attr, "=") then
			local kvPair = Lib.splitString(attr, "=")
			stAttr:SetText(Lang:formatText(kvPair))
		else
			stAttr:SetText(Lang:formatText(attr))
		end
		stAttr:SetWidth({ 0, w })
		local height = stAttr:GetTextStringHigh()
		stAttr:SetHeight({ 0, height })
		stAttr:SetXPosition({ 0, 0 })
		stAttr:SetYPosition({ 0, yOffset})
		stAttr:SetTextColor({64/255, 132/255, 75/255, 1})
		stAttr:SetFontSize("HT12")
		yOffset = yOffset + height
		self.tipInfoGrid:AddItem(stAttr)
	end
	self.tipInfoGrid:SetMoveAble(yOffset > h)
end

function M:selectItem(clickItem, flag)
	if flag then
		local item = self.showGrid:GetItem(clickItem - 1)
		self:selectItem(item)
		return
	end
	if lastItem then
		lastItem:receiver():onClick(false, "")
		lastItem:receiver()._btn_close:SetVisible(false)
	end
	if clickItem then
		clickItem:receiver()._btn_close:SetVisible(true)
		clickItem:receiver():onClick(true, "set:setting_global.json image:check_equip_show_click.png")
	end
	lastItem = clickItem
	self:setItemInfo(lastItem)
end

function M:initGrid()
	self.showGrid:RemoveAllItems()
	lastItem = nil
	self:selectItem()

	for index, data in pairs(itemData) do 
		local item = self:getItem(index, data)
		self.showGrid:AddItem(item)
		if not lastItem then
			self:selectItem(item)
		end
	end
end

function M:saveData()

end

function M:onOpen(dataString)
	self:initData(dataString)
	lastItem = nil
	self:initGrid()
end

function M:onReload(reloadArg)

end

function M:onClose()

end

return M