local setting = require "common.setting"
local bagCapacity = World.cfg.bagCap or 9

local cell_pool = {}
local BAG_FRIST = 1
local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell","widget_cell_2.json","widget_cell_2")
	end
	return ret
end

function M:init()
	WinBase.init(self, "app_bag.json", true)
	self.btnFilters = {}
	self:initItemGridView()
	self:initUiName()
	self:initFiterUi()
	self:createBagFilter()
	self._selectedCell = nil

	self:child("CharacterPanel-Btn_List"):SetTouchable(false)
	self:child("CharacterPanel-Btn_Grid_View"):SetTouchable(false)

	
	Lib.subscribeEvent(Event.EVENT_PLAYER_ITEM_MODIFY, function() 
		if not self.isOpen then
			return
		end
		self._selectedCell = nil
		self:fetchPlayerInfo() 
	end)

	Lib.subscribeEvent(Event.CHECK_SWAP, function(index, newCell)
		if not self._selectedCell then
			return
		end
		local desTrays = Me:tray():query_trays(Define.TRAY_TYPE.HAND_BAG)[1]
		local handTid = desTrays.tid
		local desTray = desTrays.tray

		local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.BAG)
		local bagTid, bag = trayArray[1].tid,  trayArray[1].tray

		local handSlot = index
		local resSlot
		local curCellSloter = self._selectedCell:data("sloter")
		if not curCellSloter and not desTray:fetch_item(index) then
			return
		end
		local bagSlot = curCellSloter and curCellSloter:slot()
		Me:combineItem(handTid,  handSlot, bagTid, bagSlot)
		self.selectedCell = nil
		UI:closeWnd("popups_property")

	end)
end

function M:initFiterUi()
	local btnGv = self:child("CharacterPanel-Btn_Grid_View")
	self.btnGv = btnGv
	local btnXModulus = 10
	for i, tb in pairs(World.cfg.bagFilter or {}) do
		local btnBase = GUIWindowManager.instance:LoadWindowFromJSON("widget_btn.json")
		local btnText = btnBase:child("widget_btn-Text_1")
		local btnName = Lang:toText(tb.btnName)
		local btnWidth = btnText:GetFont():GetTextExtent(btnName,1.0) + 20
		btnBase:SetVisible(true)
		btnBase:SetArea({ 0, btnXModulus }, { 0, 5 }, { 0, btnWidth }, { 0, 49}) -- 属性 坐标x，坐标y，长x，宽y {相对，绝对}
		btnText:SetText(btnName)
		self.btnFilters[i] = {btn = btnBase:child("widget_btn-button_1"), tray = tb.tray}
		btnGv:AddChildWindow(btnBase)
		btnXModulus = btnXModulus + btnWidth + 5
	end
end

function M:initUiName()
	self.bagUi = self:child("CharacterPanel-Character_Bag")
	self.fiterBtnGrid = self:child("CharacterPanel-Btn_Grid_View")
	self.itemGv = self:child("CharacterPanel-Item_Tray_Base")
end

function M:initItemGridView()
	local function onClickCurItem(cell)
		local sloter = cell:data("sloter")
		local newCell = self:resetSelectedCell(cell, sloter)
		if not sloter or sloter:null() then
			newCell = nil
		end
		Lib.emitEvent(Event.DIALOG_INFO, newCell)
	end
	local itemGv = self:child("CharacterPanel-Item_Tray_Base")
	self.itemGv = itemGv
	itemGv:InitConfig(0, 0, 5)
	itemGv:HasItemHidden(false)
	-- itemGv:SetMoveAble(true)
	local newSize = itemGv:GetPixelSize().y / 5
	for i = 1, bagCapacity do
		local cell = fetchCell()
		cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, newSize}, { 0, newSize})
		cell:setData("index", i)
		--cell:invoke("SHOW_FRAME",false)
		itemGv:AddItem(cell)
		self:subscribe(cell, UIEvent.EventWindowClick, function() 
			onClickCurItem(cell) 
		end)
	end
end

function M:createFiterBtn()
	local trigger = GUIWindowManager.instance:CreateGUIWindow1("RadioButton")
	self.fiterBtnGrid:AddItem(trigger)
	return trigger
end

function M:createBagFilter()
	local btnFilters = self.btnFilters
	for i,filters in pairs(btnFilters) do
		self:subscribe(filters.btn, UIEvent.EventButtonClick, 
			function() 
				self.itemFilter = filters.tray and 
					function(item) 
						local tray = item:tray_type()
						for _,v in pairs(filters.tray) do
							if tray[v] then
								return true
							end
						end
						return false
					end
					or nil
				self:fetchPlayerInfo()
			end)
	end
end

function M:resetSelectedCell(newCell, sloter)
	local curCell = self._selectedCell
	if curCell then
		if curCell == newCell then
			curCell:receiver():onClick(false)
			self._selectedCell = nil
			return
		end
		curCell:receiver():onClick(false)
	end

	self._selectedCell = newCell or nil
	if newCell then
		newCell:receiver():onClick(true)
	end
	return newCell
end

function M:updateItemView(sloter, idx)
	local cell = self.itemGv:GetItem(idx)
    assert(cell)
	if sloter then
		cell:setData("sloter", sloter)
		cell:invoke("ITEM_SLOTER", sloter)
    	cell:invoke("SET_BG", sloter)
		cell:SetName("item:"..sloter:full_name())
	end
end

function M:resetBagView()
	local gvBag = self.itemGv
    for i = 0, gvBag:GetItemCount() - 1 do
        local cell = gvBag:GetItem(i)
        if cell then
			cell:setData("sloter")
			cell:invoke("RESET")
			cell:invoke("SHOW_LOCKED", false)
			cell:invoke("RESET_OUTER_FRAME", false)
			cell:SetName("")
        end
    end
end

function M:fetchPlayerInfo()
	self:resetBagView()
	local trayArray = Me:tray():query_trays({ Define.TRAY_TYPE.BAG, Define.TRAY_TYPE.EXTRA_BAG})
    local idx = 0
	for _, element in pairs(trayArray) do
		local tid, tray = element.tid, element.tray
		local items = tray:query_items(self.itemFilter)
		for slot, item in pairs(items) do
            if idx == bagCapacity then
                break
            end
			self:updateItemView(item, idx)
            idx = idx + 1
		end
	end

	for i = idx, bagCapacity - 1 do
		self:updateItemView(nil, i)
	end
end

function M:onOpen(objID)
    self._isMe = not objID 
	self._selectedCell = nil
	self._root:SetVisible(true)	
	self._objID = self._isMe and Me.objID or objID
    self:fetchPlayerInfo()
	self.isOpen = true
end

function M:close()
	self.isOpen = false
	self._selectedCell = nil
end