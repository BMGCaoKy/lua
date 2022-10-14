local setting = require "common.setting"
local entity_obj_derive = require "editor.entity_obj_derive"
local entity_obj = require "editor.entity_obj"
local blockVector_obj = require "editor.blockVector_obj"
local isMoveBlock = false

local cell_pool = {}

local FILTER_TYPE = {
    ALL_TYPE = 3
}

local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell")
	end
	return ret
end

local function CreateItem(type, fullName, args)
    if type == "moveBlock" then
        type = "block"
    end
    local item = EditorModule:createItem(type, fullName, args)
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
    if settingTable.cfg == item:full_name() then
        cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self._select_cell = cell
    end
    self:subscribe(cell, UIEvent.EventWindowClick, function()
        local item = cell:data("item")
        if self._select_cell then
            self._select_cell:receiver():onClick(false, "")
        end
        self._select_cell = cell
        self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self:showItemInfo(item, cfg)
        --settingTable.cfg = item:full_name()
        -- Lib.emitEvent(Event.EVENT_PACK_SWAP_ITEM, item)
    end)
    if idx==1 then
        self:showItemInfo(item, cfg)
    end
end

local function monsterTypeFilterFunc()
    local ret = {}
    local items = Clientsetting.getEntityList()
    ret.data = items
    ret.type = "entity"
    return {ret}
end

local function moveBlockTypeFilterFunc()
    local ret = {}
    local items = Clientsetting.getMoveBlock()
    ret.data = items
    ret.type = "moveBlock"
    return {ret}
end

local function allTypeFilterFunc()
    local item = {}
    if isMoveBlock then
        item = moveBlockTypeFilterFunc()[1]
    else
        item = monsterTypeFilterFunc()[1]
    end
    return {item}
end

local filterFunc = {
    [FILTER_TYPE.ALL_TYPE] = allTypeFilterFunc
}

function M:init()
    WinBase.init(self, "mapEditBlockVector_edit.json", true)
    self:root():setBelongWhitelist(true)
    self:initUiName()
    self:registerEvent()
    self:initUi()
end

function M:initUi()
    self.grid:InitConfig(20, 20, 5)
    self.grid:SetAutoColumnCount(false)
    self.countUI:SetVisible(false)
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
    self.name = self:child("mapEditItemBagRoot-infoName")

    self.itemIcon = self:child("mapEditItemBagRoot-Icon")
    self.infoList = self:child("mapEditItemBagRoot-infoList")
    self.countUI = self:child("mapEditItemBagRoot-setCountLayout")

    self:child("mapEditItemBagRoot-title"):SetVisible(false)
    self:child("mapEditItemBagRoot-constOkText"):SetText(Lang:toText("win.map.edit.entity.setting.change.ok"))

    self.descText = GUIWindowManager.instance:CreateGUIWindow1("StaticText")
    self.descText:SetWordWrap(true)
    self.descText:SetWidth({1, 0})
    self.descText:SetTextColor({0.388235, 0.392157, 0.415686, 1})

    self.filterButton = {}
    for i = 1, 3 do
        local name = string.format("mapEditItemBagRoot-selectBtn-%d",i)
        self.filterButton[i] = self:child(name)
    end

end

function M:updataFilter()
    self.grid:RemoveAllItems()
    self.grid:SetArea({0, 576}, {0, 85}, {0, 580}, {0, 370})
    self._select_cell = nil
    local f = filterFunc[self.curType]
    local itemsList = f(self)
    local idx = 0
	local newSize = self.grid:GetPixelSize().x / 5 - 16
    for _, items in ipairs(itemsList) do 
        local type = items.type
        for _, itemData in pairs(items.data) do
			if not itemData.dropobjects then
			    local itemName = itemData.name
                local item, cfg
				item, cfg = CreateItem(itemData.type or type, itemName or itemData)
				if isMoveBlock then
					local block_id = Block.GetNameCfgId(itemName or itemData)
					function item:icon()
						return ObjectPicture.Instance():buildBlockPicture(block_id)
					end
				end

				idx = idx + 1
				local cell = fetchCell()
				initCell(self, cell, newSize, item, idx, cfg, itemData.type or type)
				--self:updataSelectItem(cell, itemData.type or type, itemName)
				self.grid:AddItem(cell)
			end
        end
    end
end

function M:showItemInfo(item, cfg)
    local name = item and item:getNameText() or ""
    local desc = item and item:getDescText() or "editor_base_desc"
    self.infoList:ResetScroll()
    self.descText:SetText(Lang:formatText(desc))
    local high = self.descText:GetTextStringHigh() + 20
    self.descText:SetHeight({0, high})
    self.descText:SetFontSize("HT12")
    self.infoList:AddItem(self.descText)

    self.itemIcon:SetImage(item and item:icon() or "")
    self.name:SetText(Lang:toText(name))
end

function M:getSetting(entityID)
    self.settingTable = {}
    self.settingTable = entity_obj:getAllDataById(entityID)
end

function M:saveSetting()
    UI:closeWnd("mapEditChangeStyle")
	if self._select_cell then
		self.settingTable.cfg = self._select_cell:data("item"):full_name()
	end
    entity_obj:Cmd("changeEntity", self._entityID, self.settingTable.cfg)
end

function M:registerEvent()
    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd("mapEditChangeStyle")
    end)

    self:subscribe(self:child("mapEditItemRoot-BG"), UIEvent.EventWindowClick, function()
        UI:closeWnd("mapEditChangeStyle")
    end)
    self:subscribe(self.okBtn, UIEvent.EventButtonClick, function()
        self:saveSetting()    
    end)
    for i = 3, 3 do
        self:subscribe(self.filterButton[i], UIEvent.EventRadioStateChanged, function(status)
            if not status:IsSelected() then
                return
            end
            self.curType = i
            self:updataFilter()
            self.filterButton[i]:SetVisible(false)
        end)
    end
end

function M:updataFilterButton()
    for _, v in pairs(self.filterButton) do
        v:SetSelected(false)
        v:SetVisible(false)
    end 
    self.filterButton[self.curType]:SetVisible(true)
    self.filterButton[self.curType]:SetSelected(true)
end

function M:updataSelectItem(cell, type, itemName)
    local selectKeyName = string.format( "%s%s", type, itemName)
    local compereKeyName = string.format( "%s%s",st.curSelectType, st.curSelectFullName)
    if selectKeyName == compereKeyName then
        cell:receiver():onClick(true, "set:new_gui_material.json image:wupinkuang_xuanzhong")
    end
end

function M:onOpen(entityID, _isMoveBlock)
    Lib.emitEvent(Event.EVENT_OPEN_INVENTORY, false)
    isMoveBlock = _isMoveBlock
    Lib.emitEvent(Event.EVENT_BLOCK_VECTOR, false)
    self.curType = FILTER_TYPE.ALL_TYPE
    self._entityID = entityID
    self:getSetting(entityID)
    self:updataFilterButton()
    self:updataFilter()
end

function M:onClose()
    Lib.emitEvent(Event.EVENT_OPEN_INVENTORY, true)
	local pos = entity_obj:getPosById(self._entityID)
    Lib.emitEvent(Event.EVENT_ENTITY_SETTING, self._entityID, pos)
end
