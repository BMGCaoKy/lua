local setting = require "common.setting"
local entity_obj_derive = require "editor.entity_obj_derive"
local entity_obj = require "editor.entity_obj"
local blockVector_obj = require "editor.blockVector_obj"


local cell_pool = {}

local FILTER_TYPE = {
    ALL_TYPE = 3,
    ITEM = 1,
    MONSTER = 2
}

local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell")
	end
	return ret
end

local function CreateItem(type, fullName)
    if not fullName then
        return
    end
	local item = EditorModule:createItem(type, fullName)
	local cfg = item:cfg()
	return item, cfg
end

local function initCell(self, cell, newSize, item, idx, cfg, type)
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, newSize }, { 0, newSize})
    cell:setData("index", idx)
    cell:receiver()._img_frame:SetImage("set:map_edit_bag.json image:itembox1_bag.png")
    cell:receiver()._img_frame_select:SetImage("")
    cell:receiver()._img_frame_select:SetVisible(true)
    
    if not item then
        cell:receiver()._img_locked:SetVisible(true)
        cell:receiver()._img_locked:SetArea({0,0},{0,0},{1,0},{1,0})
        cell:receiver()._img_locked:SetImage("set:map_edit_bag.json image:itembox2_empty_bag.png")
        return
    end
    cell:setData("item", item)
    cell:setData("cfg", cfg)
    cell:setData("type", type)

    cell:invoke("ITEM_SLOTER", item)
    cell:SetName("item:"..item:full_name())
    local settingTable = self.settingTable
    self:subscribe(cell, UIEvent.EventWindowClick, function()
        local item = cell:data("item")
        if self._select_cell then
            self._select_cell:receiver():onClick(false, "")
        end
        self._select_cell = cell
        self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self:showItemInfo(item, cfg)
        self.settingTable.curSelectFullName =  type == "block" and item:block_cfg().fullName or item:full_name()
		self.settingTable.curSelectType = type
        -- Lib.emitEvent(Event.EVENT_PACK_SWAP_ITEM, item)
    end)
    
end

local function itemTypeFilterFunc()
    local ret = {}
    local items = Clientsetting.getItemList()

    for index, value in ipairs(items) do
        if value.dropobjects then
            items[index] = nil 
        end
    end

    ret.data = items
    ret.type = "item"
    return {ret}
end

local function monsterTypeFilterFunc()
    local ret = {}
    local items = Clientsetting.getEntityList()
    for index, value in ipairs(items) do
        if value.dropobjects then
            items[index] = nil 
        end
    end
    ret.data = items
    ret.type = "entity"
    return {ret}
end

local function allTypeFilterFunc()
    local item1 = itemTypeFilterFunc() [1]
    local item2 = monsterTypeFilterFunc()[1]
    return {item1, item2}
end

local filterFunc = {
    [FILTER_TYPE.ALL_TYPE] = allTypeFilterFunc,
    [FILTER_TYPE.ITEM] = itemTypeFilterFunc,
    [FILTER_TYPE.MONSTER] = monsterTypeFilterFunc,
}

function M:init()
    WinBase.init(self, "mapEditBlockVector_edit.json", true)
    self:root():setBelongWhitelist(true)
    self:child("mapEditItemBagRoot-title"):SetText(Lang:toText("gui.editor.drop.object"))
    self:initUiName()
    self:registerEvent()
	self:initUi()
	self.lastCurType = nil
end

function M:initUi()
    self.grid:InitConfig(20, 20, 5)
    self.grid:SetAutoColumnCount(false)
    self.itemLayout = self:child("mapEditItemBagRoot-itemLayout")
    local titleIcon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "TitleIcon")
    if World.Lang == "zh_CN" then
        titleIcon:SetImage("set:mapBag.json image:illustration1.png")
        titleIcon:SetArea({0, 168}, {0, 20}, {0, 103}, {0, 20})
    else
        titleIcon:SetImage("set:mapBagDescription.json image:DESCRIPTION")
        titleIcon:SetArea({0, 142}, {0, 20}, {0, 171}, {0, 25})
    end
    self.itemLayout:AddChildWindow(titleIcon)
    self:child("mapEditItemBagRoot-infoDescribe"):SetText(Lang:toText("desc"))
end

function M:initUiName()
    self.closeBtn = self:child("mapEditItemBagRoot-btnClose")
    self.okBtn = self:child("mapEditItemBagRoot-btnOk")
    self.addCount = self:child("mapEditItemBagRoot-btnAdd")
    self.subCount = self:child("mapEditItemBagRoot-btnSub")
    self.countText = self:child("mapEditItemBagRoot-textCount")
    self.grid = self:child("mapEditItemBagRoot-grid")
    self.itemIcon = self:child("mapEditItemBagRoot-Icon")
    self.infoList = self:child("mapEditItemBagRoot-infoList")
    self.name = self:child("mapEditItemBagRoot-infoName")

    self.descText = GUIWindowManager.instance:CreateGUIWindow1("StaticText")
    self.descText:SetWordWrap(true)
    self.descText:SetWidth({1, 0})
    self.descText:SetTextColor({0.388235, 0.392157, 0.415686, 1})
    self:child("mapEditItemBagRoot-constOkText"):SetText(Lang:toText("win.map.edit.entity.setting.change.ok"))

    self.filterButton = {}
    for i = 1, 3 do
        local name = string.format("mapEditItemBagRoot-selectBtn-%d",i)
        self.filterButton[i] = self:child(name)
    end
end

function M:updataFilter()
    self.gridItemCount = 0
    self.grid:RemoveAllItems()
    self.grid:SetArea({0, 576}, {0, 163}, {0, 580}, {0, 220})
	self._select_cell = nil
	self.cellUIList = {}
    local f = filterFunc[self.curType]
    local itemsList = f(self)
    local idx = 0
    local newSize = self.grid:GetPixelSize().x / 5 - 16
    local maxItemCount = 0
    for index = 1, #itemsList do
        maxItemCount = maxItemCount + #(itemsList[index].data)
    end
    local itemsListCount = 1
    local itemDataCount = 1
    local preType = self.curType
    local isShowSelectIcon = false
    local function fetch()
        if not itemsList[itemsListCount].data[itemDataCount] then
            itemsListCount = itemsListCount + 1
            itemDataCount = 1
        end
        if self.curType ~= preType then
            return false
        end
        local type = itemsList[itemsListCount].type
        local itemData = itemsList[itemsListCount].data[itemDataCount]
        local itemName = itemData.name
        local item, cfg
        item, cfg = CreateItem(itemData.type or type, itemName or itemData)
        idx = idx + 1
        local cell = fetchCell()
        initCell(self, cell, newSize, item, idx, cfg, itemData.type or type)
        cell:setData("fullName", item:full_name())
        self.cellUIList[#self.cellUIList + 1] = cell
        self.grid:AddItem(cell)
        if idx >= maxItemCount then
            return false
        end
        itemDataCount = itemDataCount + 1
        self.gridItemCount = self.gridItemCount + 1
        local selectIndex = self.settingTable.selectItemIndex
        if not isShowSelectIcon and selectIndex == self.gridItemCount and self.curType == self.settingTable.curType then
            self:selectItem(selectIndex)
            self.grid:SetScrollOffset(self.settingTable.scrollOffset)
            isShowSelectIcon = true
        end
        return true
    end
    World.Timer(1, fetch)
    self.grid:ResetPos()
    -- for i = idx, 20 do
    --     local cell = fetchCell()
    --     initCell(self, cell, newSize, nil, idx, nil)
	-- 	self.grid:AddItem(cell)
    -- end
end

function M:showItemInfo(item, cfg)
    if not item then
        return
    end
    self.infoList:ResetScroll()
    local name = item:getNameText() or ""
    local desc = item:getDescText()
    self.itemIcon:SetImage(item and item:icon() or "")
    self.countText:SetText(string.format( "%d", self.settingTable.count or 0))
    self.name:SetText(Lang:toText(name))

    self.descText:SetText(Lang:formatText(desc))
    local high = self.descText:GetTextStringHigh() + 20
    self.descText:SetHeight({0, high})
    self.descText:SetFontSize("HT12")
    self.infoList:AddItem(self.descText)
end

function M:getSetting(params)
    local pos = params.pos
    self.pos = pos
    local entityId = params.entityId
    self.entityId = entityId
    self.blockVector = params.blockVector
    self.vectorEntityId = self.entityId
    self.entityVector = not params.blockVector
    local setting,curSelectType,curSelectFullName
    if self.blockVector then
        if not self.vectorEntityId then
            return {}
        end
        setting = entity_obj:getDataById(self.vectorEntityId)
    elseif self.entityVector then
        if not entityId then
            return {}
        end
        setting = entity_obj:getDataById(entityId).dropItem
        setting = setting and setting[1]
    end
    return setting and {
                curSelectType = setting.type or setting[1],
                count = setting.count or setting[2] or 0,
                icon_type_id = setting.icon_type_id or setting[3] or 1,
                curSelectFullName = setting.fullName or setting[4],
                selectItemIndex = setting.selectItemIndex or setting[5] or 1,
                scrollOffset = setting.scrollOffset or setting[6] or 0,
                curType = setting.curType or setting[7] or FILTER_TYPE.ALL_TYPE
            } or {}
end

function M:saveSetting()
	local st = self.settingTable
	if not st.curSelectFullName then
        return
    end

    if not st.curSelectType then
        st.count = 0    
        st.curSelectFullName = nil
        st.curSelectType = nil
    end
    
    local temp = {}
    if self.blockVector then
        temp.type = st.curSelectType
        temp.count = st.count
        temp.icon_type_id = st.icon_type_id or 1
		temp.fullName = st.curSelectFullName
        temp.selectItemIndex = self:calcSelectItemOnBagIndex()
        temp.scrollOffset = self.grid:GetScrollOffset()
        temp.curType = self.curType
        entity_obj:Cmd("replaceTable", self.vectorEntityId, st.count~=0 and temp or nil)
        --Lib.emitEvent(Event.EVENT_BLOCK_VECTOR, true, {vectorEntityId = self.vectorEntityId})
    elseif self.entityVector then
        temp[1] = st.curSelectType
        temp[2] = st.count
        temp[3] = st.icon_type_id or 1
        temp[4] = st.curSelectFullName
        temp[5] = self:calcSelectItemOnBagIndex()
        temp[6] = self.grid:GetScrollOffset()
        temp[7] = self.curType
        local dropItem = {}
        table.insert(dropItem, st.count ~=0 and temp or nil)
        entity_obj:Cmd("replaceTable", self.entityId, #dropItem > 0 and dropItem or nil)
    end
    UI:closeWnd("mapEditVector")
end

function M:registerEvent()
    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_VECTOR_SET_VALUE, false)
    end)

    self:subscribe(self:child("mapEditItemRoot-BG"), UIEvent.EventWindowClick, function()
        Lib.emitEvent(Event.EVENT_VECTOR_SET_VALUE, false)
    end)

    self:subscribe(self.okBtn, UIEvent.EventButtonClick, function()
        self:saveSetting()    
    end)
    self:subscribe(self.addCount, UIEvent.EventButtonClick, function()
        self:updataCount(1)         
    end)
    self:subscribe(self.subCount, UIEvent.EventButtonClick, function()
        self:updataCount(-1)         
    end)

    for i = 1, 3 do
        self:subscribe(self.filterButton[i], UIEvent.EventRadioStateChanged, function(status)
            if not status:IsSelected() then
                return
            end
			self.curType = i
			if self.lastType ~= self.curType then
				self.lastType = self.curType
				self:updataFilter()
			end
        end)
    end
end

function M:updataFilterButton()
    for _, v in pairs(self.filterButton) do
        v:SetSelected(false)
    end 
    self.filterButton[self.curType]:SetSelected(true)
end

function M:updataCount(num)
    local st = self.settingTable
    if not st.count then
        st.count = 0
    end
    st.count = st.count + num
    st.count = st.count >=0 and st.count or 0
    self.countText:SetText(string.format( "%d",st.count))
end

function M:updataSelectItem(cell, type, itemName)
    local st = self.settingTable
    if not st.curSelectFullName or not st.curSelectType then
        return
    end

    local selectKeyName = string.format( "%s%s", type, itemName)
    local compereKeyName = string.format( "%s%s",st.curSelectType, st.curSelectFullName)
    if selectKeyName == compereKeyName then
        cell:receiver():onClick(true, "set:new_gui_material.json image:wupinkuang_xuanzhong")
    end
end

function M:onOpen(params)
    Lib.emitEvent(Event.EVENT_OPEN_INVENTORY, false)
    Lib.emitEvent(Event.EVENT_BLOCK_VECTOR, false)
	self.settingTable = self:getSetting(params)
	self.curType = self.settingTable.curType
    local item, cfg = CreateItem(self.settingTable.curSelectType, self.settingTable.curSelectFullName)
    self:updataCount(0)   
	self:updataFilterButton(false)
	if self.lastType ~= self.curType then
		self.lastType = self.curType
		self:updataFilter()
	end
    self:showItemInfo(item, cfg)
	self:selectItemEffect()
end

function M:selectItemEffect()
	for k, cell in pairs(self.cellUIList or {}) do
		local fullName = cell:data("fullName")
		if fullName == self.settingTable.curSelectFullName then
			cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
			self._select_cell = cell
		else
            cell:receiver():onClick(false, "")
		end
	end
end

function M:selectItem(index)
    if self.gridItemCount > 0 then
        local cell = self.grid:GetItem(index - 1)
        cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self._select_cell = cell
        local item = cell:data("item")
        self:showItemInfo(item, cell:data("cfg"))
        self.settingTable.curSelectFullName = item:full_name()
        self.settingTable.curSelectType = cell:data("type")
    end
end


function M:calcSelectItemOnBagIndex()
    local defaultSelectItemIndex = 1
    local select_cell_item = self._select_cell:data("item")
    if self.gridItemCount > 0 then
        for index = 1, self.gridItemCount do
            local cell = self.grid:GetItem(index - 1)
            if not cell then
                return
            end
            local cell_item = cell:data("item")
            if cell_item == select_cell_item then
                return index
            end
        end
    end
    return defaultSelectItemIndex
end

function M:onClose()
    Lib.emitEvent(Event.EVENT_OPEN_INVENTORY, true)
	local pos = entity_obj:getPosById(self.entityId)
    Lib.emitEvent(Event.EVENT_ENTITY_SETTING, self.entityId, pos)
end