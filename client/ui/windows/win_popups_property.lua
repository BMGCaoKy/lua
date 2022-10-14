-- 属性弹窗面板 -- 点击道具cell的时候弹出该道具对应的各项属性已经能使用的按钮
function M:init()
	self.objID = Me.objID
	WinBase.init(self, "CharacterPanelProPopups.json",true)
	self.base = self:child("CharacterPanelProPopups-Base_Image")
	self.base:SetVisible(false)
	self.baseXY = self.base:GetPixelSize()
	self.itemIcon = self:child("CharacterPanelProPopups-Item_View_Base-Icon")
	self.itemName = self:child("CharacterPanelProPopups-Item_Name_Base_Text")
	self.itemType = self:child("CharacterPanelProPopups-Item_Type")
	self.itemRemark = self:child("CharacterPanelProPopups-Item_Remark")
	-- self.itemPropertyGv = self:child("CharacterPanelProPopups-Slot_Base")
	self.itemPropertyText = self:child("CharacterPanelProPopups-Slot_Text")
	self.itemPropertyLayout = self:child("CharacterPanelProPopups-Slot_Layout")
	self.itemPropertyList = self:child("CharacterPanelProPopups-Slot_List")
	self.itemPropertyList:AddItem(self.itemPropertyLayout)
	self.itemPropertyTab = self:child("CharacterPanelProPopups-Item_Property_Tab")
	self.itemPropertyTabXY = self.itemPropertyTab:GetPixelSize()

	self.itemBtnGv = self:child("CharacterPanelProPopups-Btn_Grid_Base")

	self:initSurePopupsPanel()
	self:initSellPopupsPanel()
end

function M:initSurePopupsPanel()
	local surePanel = UI:openWnd("popups_destory")
	self.surePanel = surePanel
	self.surePanel._root:SetVisible(false)
end

function M:initSellPopupsPanel()
	local sellPanel = UI:openWnd("popups_sell")
	self.sellPanel = sellPanel
	self.sellPanel._root:SetVisible(false)

end

local function getBtnGvColumn(self,itemCfg)
	local column = 0
	local isClickOnBag = self.isClickOnBag
	if isClickOnBag and itemCfg.candestroy then
		column = column + 1
	end
	if isClickOnBag and itemCfg.cansell then
		column = column + 1
	end
	if itemCfg.tray then
		column = column + 1
	end
	return column
end

-- 当前点击cell，当前点击slot，如果是装备/取下的目标位置{slot，tid}(nil则是不能装备)destTable，
-- 是否是在背包中点击的isClickOnBag，当前是entity还是宠物lastPageType，当前面板的底面板backWnd
function M:openPopups(cell,curSloter,destTable,isClickOnBag,lastPageType,backWnd,noBtn,x,y)
	if not cell then
		UI:closeWnd("popups_property")
		return
	end
	self.cell = cell
	self.curSloter = curSloter
	if curSloter:is_block() then
		self.itemCfg = curSloter:block_cfg()
	else
		self.itemCfg = curSloter:cfg()
	end
	self.destTable = destTable
	self.isClickOnBag = isClickOnBag
	if isClickOnBag then
		self.takeOnOffBtnText = "character_panel_takeOnBtn"
	else
		self.takeOnOffBtnText = "character_panel_takeOffBtn"
	end
	self.lastPageType = lastPageType
	self.backWnd = backWnd
	self._root:SetLevel(9)
	local base = self.base
	-- self._root:SetParent(backWnd)
	base:SetVisible(true)
	base:SetArea({ 0.5, x or -200 }, { 0, y or 40 }, { 0, 400 }, { 0, 312})
	backWnd:AddChildWindow(base)
	base:SetHorizontalAlignment(0)

	self:resetItemMsg()
	self.itemBtnGv:RemoveAllItems()
	if not noBtn then
        local column = getBtnGvColumn(self,self.itemCfg)
        self:resetBtn(column)
    end
end

local function resetPropertyText(self, cell, itemintroduction)
	
	local str = Lang:formatText(itemintroduction or "")
	local itemPropertyTab = self.itemPropertyTab
	local def = self.itemPropertyTabXY
	cell:SetText(str)
	local height = cell:GetTextStringHigh()
	local addY = height - def.y

	if addY > 0 then
        addY = addY > 140 and 140 or addY
		itemPropertyTab:SetHeight({0,def.y + addY + 10})
		self.base:SetHeight({0, self.baseXY.y + addY + 10})
	else
		itemPropertyTab:SetHeight({0,def.y})
		self.base:SetHeight({0, self.baseXY.y})
	end
	self.itemPropertyLayout:SetHeight({0, height})
end

function M:resetItemMsg()
	local itemCfg = self.itemCfg
	self.itemPropertyList:ResetScroll()
	self.itemIcon:SetImage(self.curSloter:icon())
	self.itemName:SetText(Lang:toText(itemCfg.itemname or ""))
	self.itemType:SetText(Lang:toText(itemCfg.itemtype or ""))
	self.itemRemark:SetText(Lang:toText(itemCfg.itemremark or ""))

	resetPropertyText(self, self.itemPropertyText, itemCfg.desc)
end

function M:resetBtn(column)
	local itemCfg = self.itemCfg
	local itemBtnGv = self.itemBtnGv
	itemBtnGv:SetVisible(true)
	itemBtnGv:RemoveAllItems()
	itemBtnGv:InitConfig(0, 0, column)
	itemBtnGv:SetItemAlignment(1)
	local btnWidth = math.min(itemBtnGv:GetPixelSize().x / column - 30,120)
	local isClickOnBag = self.isClickOnBag

	if isClickOnBag and itemCfg.candestroy then
		itemBtnGv:AddItem(self:fetchDestroyBtn(btnWidth))
	end

	if itemCfg.tray then
		itemBtnGv:AddItem(self:fetchTakeOnOffBtn(btnWidth))
	end

	if isClickOnBag and itemCfg.cansell then
		itemBtnGv:AddItem(self:fetchSellBtn(btnWidth))
	end	
end

local function fetchBtn(type,btnWidth,textString)
	local base = GUIWindowManager.instance:LoadWindowFromJSON("widget_btn.json"):child("widget_btn-base_" .. type)
	local btn = base:child("widget_btn-button_" .. type)
	local text = base:child("widget_btn-Text_" .. type)
	base:SetArea({ 0, 0 }, { 0, 0 }, { 0, btnWidth}, { 0, base:GetPixelSize().y})
	text:SetTextColor({82/255,67/255,45/255,255})
	text:SetText(Lang:toText(textString))
	return base,btn,text
end

function M:fetchDestroyBtn(btnWidth)
	local base,btn,text = fetchBtn(1,btnWidth,"character_panel_destroyBtn")
	self:subscribe(btn, UIEvent.EventButtonClick, function()	
		self.surePanel:openPopups(self.cell,self.curSloter,self.backWnd,self.isClickOnBag)
		self.base:SetVisible(false)	
		self._root:SetTouchPierce(true)
	end)
	return base
end

function M:fetchTakeOnOffBtn(btnWidth)
	local base,btn,text = fetchBtn(1,btnWidth,self.takeOnOffBtnText)

	local function emitEvent()
		Lib.emitEvent(Event.FETCH_ENTITY_INFO, true)
		self.base:SetVisible(false)
		UI:closeWnd("popups_property")	
	end

	local function onTakeOff(ok)
		if ok then -- 如果是取下装备就需要重置这个cell的数据
			self.cell:invoke("RESET_CONTENT")
			self.cell:setData("item_pos", nil)
			self.cell:setData("full_name", nil)
			emitEvent()
		end
	end
	local function onTakeOn(ok)
		if ok then 
			emitEvent()
		end
	end
	local sloter = self.curSloter
	local destTable = self.destTable
	if not destTable or not next(destTable) then
		btn:SetEnabled(false)
		return base
	end	
	if not self.isClickOnBag then 
		self:subscribe(btn, UIEvent.EventButtonClick, function() 
			if self.lastPageType == Define.ENTITY_INTO_TYPE_PLAYER then
				Me:switchItem(sloter:tid(), sloter:slot(), destTable.tid, destTable.slot, onTakeOff)
			else
				Me:petTakeOff(self.lastPageType - 1, sloter:tid(), sloter:slot(), onTakeOff)
			end
		end)
	else 
		self:subscribe(btn, UIEvent.EventButtonClick, function()  
			if self.lastPageType == Define.ENTITY_INTO_TYPE_PLAYER then
				Me:switchItem(sloter:tid(), sloter:slot(), destTable.tid, destTable.slot, onTakeOn)
			else
				Me:petPutOn(sloter:tid(), sloter:slot(), self.lastPageType - 1, onTakeOn)

			end
		end)
	end
	return base
end

function M:fetchSellBtn(btnWidth)
	local base,btn,text = fetchBtn(1,btnWidth,"character_panel_sellBtn")
	self:subscribe(btn, UIEvent.EventButtonClick, function()	
		self.sellPanel:openPopups(self.cell,self.curSloter,self.backWnd,self.isClickOnBag)
		self.base:SetVisible(false)
		self._root:SetTouchPierce(true)
	end)
	return base
end

function M:onClose()
	self._root:SetVisible(false)	
	self.base:SetVisible(false)
	UI:closeWnd("popups_destory")
	UI:closeWnd("popups_sell")
end

function M:onOpen(cell,curSloter,destTable,isClickOnBag,lastPageType,backWnd,noBtn,x,y)
	self._root:SetTouchPierce(false)
	self._root:SetVisible(true)	
	self:openPopups(cell,curSloter,destTable,isClickOnBag,lastPageType,backWnd,noBtn,x,y)
end
return M