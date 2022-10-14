local setting = require "common.setting"
local editorSetting = require "editor.setting"
local cell_pool = {}
local move_Block_pool = {}
local dragCell = nil
local isCanClick = true
local loadTimers = {}

local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell")
	end
	return ret
end

local function fetchSetMoveBlockUi()
    local ret = table.remove(move_Block_pool)
	if not ret then
		ret = UIMgr:new_widget("setNum")
	end
	return ret
end

local childUiType = {
    build = 1,
    special = 2,
    item = 3,
    monster = 4,
	moveBlock = 5,
    equip = 6,
}

local childUiLang = {
    [childUiType.build] = "建筑",
    [childUiType.special] = "特殊",
    [childUiType.item] = "道具",
    [childUiType.monster] = "怪物",
    [childUiType.moveBlock] = "移动地形",
}

local function openBuffUI(self, openType)
	self.bagTable[openType]:SetVisible(false)
	self.buffUI:onOpen()
	self.openBuffUI = true 
	self.buffLayout:SetVisible(true)
end

local function openBuildUi(self)
	self:openBlockMove(false)
	self.buffLayout:SetVisible(false)
end

local function openSpecialUi(self)
    self:openBlockMove(false)
end

local function openItemUi(self)
    self:openBlockMove(false)
end

local function openMonsterUi(self)
    self:openBlockMove(false)
end

local function openMoveBlock(self)
    self:openBlockMove(true)
    UI:getWnd("mapEditItemBag"):setMoveBlockSize({1,1,1})
end

local function openEquip(self)
    self:openBlockMove(false)
end

local function showDropobjects(cell, dropobjects, size)
	if cell and dropobjects and dropobjects.fullName then
		local cfg = setting:fetch(dropobjects.type or "entity", dropobjects.fullName)
		local icon = ResLoader:loadImage(cfg, "small.png")
		if icon then
			if size then
				cell:receiver()._img_frame_sign:SetArea({0,10},{0,10},{0,20},{0,20})
			else
				cell:receiver()._img_frame_sign:SetArea({0,2},{0,2},{0,30},{0,30})
			end
			cell:receiver()._img_frame_sign:SetImage(icon)
		end
		cell:receiver()._img_frame_sign:SetVisible(true)
	elseif cell then
		cell:receiver()._img_frame_sign:SetVisible(false)
	end
end

local function selectCell(self, cell, cfg)
	local item = cell:data("item")
	if self._select_cell then
		self._select_cell:receiver():onClick(false, "")
	end
	self._select_cell = cell
	self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")

	-- 设置属性
	if item:type() == "block" then
		self.settingPropBtn:SetVisible(cfg.settingUI and not self.setDropItem and true or false)
	else
		self.settingPropBtn:SetVisible(cfg.settingUI and true or false)
	end
	--fullName
	self:showItemInfo(item, cfg)
	--Lib.emitEvent(Event.EVENT_PACK_SWAP_ITEM, item)
end

local function initCell(self, cell, newSize, item, idx, cfg, dropobjects, isSubscribe, droopobjectsSize)
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
    cell:setData("dropobjects", dropobjects)
    cell:setData("cfg", cfg)
    cell:invoke("ITEM_SLOTER", item)
    cell:SetName("item:"..item:full_name())
	--cell:child("widget_cell-actor_item"):setEnableLongTouch(true)
	showDropobjects(cell, item.dropobjects and item:dropobjects(), droopobjectsSize)
	if not isSubscribe then
		self:subscribe(cell, UIEvent.EventWindowClick, function()
			if not isCanClick then
				return
			end
			selectCell(self, cell, cfg)

			if idx == 1 then
				if self:child("mapEditItemBagRoot-btnAdd") then
					self:child("mapEditItemBagRoot-btnAdd"):SetName("mapEditItemBagRoot-btnAdd1")
				end
			end
		end)

		self:subscribe(cell, UIEvent.EventWindowLongTouchStart, function(...) 
			if not isCanClick then
				return
			end
			isCanClick = false
			selectCell(self, cell, cfg)
			dragCell = fetchCell()
			dragCell:SetLevel(0)
			local cellPos = dragCell:GetUnclippedOuterRect()
			local arg = table.pack(...)
			local pos = arg[2]:getTouchPoint()
			initCell(self, dragCell, newSize, item, idx, cfg, dropobjects, true)
			GUISystem.instance:GetRootWindow():AddChildWindow(dragCell)
			dragCell:SetXPosition({0, pos.x - newSize})
			dragCell:SetYPosition({0, pos.y - newSize})
			--dragCell:receiver():onClick(true, "set:map_edit_drag.json image:bigshortcuts")
			dragCell:receiver()._img_frame:SetImage("set:map_edit_drag.json image:bigshortcuts")
			self.bagTable[self.openType]:SetMoveAble(false)
			cell:child("widget_cell-img_item"):setEnableDrag(true)
			Lib.emitEvent(Event.EVENT_DRAGING_CELL, false)
		end)

		self:subscribe(cell, UIEvent.EventWindowLongTouchEnd, function() 
			if dragCell then
				GUISystem.instance:GetRootWindow():RemoveChildWindow1(dragCell)
				GUIWindowManager.instance:DestroyGUIWindow(dragCell)
			end
			dragCell = nil
			isCanClick = true
			self.bagTable[self.openType]:SetMoveAble(true)
			cell:child("widget_cell-actor_item"):setEnableDrag(false)
			Lib.emitEvent(Event.EVENT_DRAGING_CELL, true)
		end)

		self:subscribe(cell, UIEvent.EventMotionRelease, function() 
			if dragCell then
				GUISystem.instance:GetRootWindow():RemoveChildWindow1(dragCell)
				GUIWindowManager.instance:DestroyGUIWindow(dragCell)
			end
			dragCell = nil
			isCanClick = true
			self.bagTable[self.openType]:SetMoveAble(true)
			cell:child("widget_cell-actor_item"):setEnableDrag(false)
			Lib.emitEvent(Event.EVENT_DRAGING_CELL, true)
		end)

		self:subscribe(cell, UIEvent.EventWindowDragStart, function(...) 
			local arg = table.pack(...)
			local pos = arg[2]:getTouchPoint()
		end)
    
		self:subscribe(cell, UIEvent.EventWindowDragging, function(...) 
			local arg = table.pack(...)
			local pos = arg[2]:getTouchPoint()
			if dragCell then
				dragCell:SetXPosition({0, pos.x - newSize})
				dragCell:SetYPosition({0, pos.y - newSize})
			end
			Lib.emitEvent(Event.EVENT_SWAP_INVENTORY, pos)
		end)

		self:subscribe(cell, UIEvent.EventWindowDragEnd, function(...) 
			local arg = table.pack(...)
			local pos = arg[2]:getTouchPoint()
			Lib.emitEvent(Event.EVENT_SWAP_INVENTORY, pos, item)
		end)

	end

end

local function CreateItem(type, fullName, args)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

local function fetchBuildInfo(self, bagGrid)
    local idx = 1
    bagGrid:InitConfig(20, 20, 4)
	local newSize = bagGrid:GetPixelSize().y / 4 - 15
    local blocks = Clientsetting.getBlockList()
    local maxIdx = #blocks
    local function fetch()
        local loadCount = 0
        for _ = idx, maxIdx do 
            loadCount = loadCount + 1
            local itemName = blocks[idx]
            local type
            local name = itemName
            if itemName.name then
                name =  itemName.name
                type = itemName.type
            end
            local item, cfg
            item, cfg = CreateItem(type or "block", name, {
                type = type or "block",
                icon = itemName.icon,
                descTipInfo = itemName.descTipInfo,
                nameTipInfo = itemName.nameTipInfo,
            })

            local cell = fetchCell()
            initCell(self, cell, newSize, item, idx, cfg)
            bagGrid:AddItem(cell)
            idx = idx + 1
            if idx > maxIdx and maxIdx % 4 ~= 0 then
                for i = idx % 4, 4 do
                    local cell = fetchCell()
                    initCell(self, cell, newSize, nil, idx, nil)
                    bagGrid:AddItem(cell)
                end
                return false
            end
            return true
        end
        return false
    end
    fetch()
    loadTimers[#loadTimers + 1] = World.Timer(1, fetch)
end

local function fetchSpecial(self, bagGrid, items)
    bagGrid:InitConfig(20, 20, 4)
    local newSize = bagGrid:GetPixelSize().y / 4 -15
    items = items or Clientsetting.getSpecialList()
    local idx = 1
    local maxIdx = #items
    local function fetch()
        for _ = idx, maxIdx do
            local itemName = items[idx]
            local type
            local name = itemName
            local icon
            if itemName.name then
                name =  itemName.name
                type = itemName.type
                icon = itemName.icon
            end
            local item, cfg
            item, cfg = CreateItem(type or "block", name, {
                type = type or "block",
                icon = itemName.icon,
                descTipInfo = itemName.descTipInfo,
                nameTipInfo = itemName.nameTipInfo,
            })

            function item:dropobjects()
                return itemName and itemName.dropobjects
            end

            local cell = fetchCell()
            initCell(self, cell, newSize, item, idx, cfg)
		    bagGrid:AddItem(cell)
            idx = idx + 1
            if idx > maxIdx and maxIdx % 4 ~= 0 then
                for i = idx % 4, 4 do
                    local cell = fetchCell()
                    initCell(self, cell, newSize, nil, idx, nil)
                    bagGrid:AddItem(cell)
                end
                return false
            end
            return true
        end
        return false
    end
    fetch()
    loadTimers[#loadTimers + 1] = World.Timer(1, fetch)
end

local function fetchEquip(self, bagGrid)
	local items = Clientsetting.getequipList()
	fetchSpecial(self, bagGrid, items)
end

function M:fetchFunc(bagGrid, nameList)
	local items = Clientsetting.getData(nameList)
	fetchSpecial(self, bagGrid, items)
end

local function fetchMonster(self, bagGrid)
    bagGrid:InitConfig(20, 20, 4)
	local newSize = bagGrid:GetPixelSize().y / 4 - 15
	local items = Clientsetting.getEntityList()
    local idx = 1
    local maxIdx = #items
    local function fetch()
        for _ = idx, maxIdx do
            local itemName = items[idx]
            local type
            local name = itemName
            local icon
            if itemName.name then
                name =  itemName.name
                type = itemName.type
                icon = itemName.icon
            end
            local item, cfg
            item, cfg = CreateItem(type or "entity", name, {
                type = type or "entity",
                icon = itemName.icon,
                descTipInfo = itemName.descTipInfo,
                nameTipInfo = itemName.nameTipInfo,
            })

            function item:dropobjects()
                return itemName and itemName.dropobjects
            end
            local cell = fetchCell()
            initCell(self, cell, newSize, item, idx, cfg)
		    bagGrid:AddItem(cell)
            idx = idx + 1
             if idx > maxIdx and maxIdx % 4 ~= 0 then
                for i = idx % 4, 4 do
                    local cell = fetchCell()
                    initCell(self, cell, newSize, nil, idx, nil)
                    bagGrid:AddItem(cell)
                end
                return false
            end
            return true
        end
        return false
    end
    fetch()
    loadTimers[#loadTimers + 1] = World.Timer(1, fetch)
end

local function fetchItemInfo(self, bagGrid)
    bagGrid:InitConfig(20, 20, 4)
    local newSize = bagGrid:GetPixelSize().x / 4 - 15
	local items = Clientsetting.getItemList()
    local idx = 1
    local maxIdx = #items
	local colTmp = math.ceil(maxIdx / 4)
	local col = colTmp > 4 and colTmp or 4
    local function fetch()
        for _ = idx, maxIdx do
            local itemName = items[idx]
            local type
            local name = itemName
            local icon
            if itemName.name then
                name =  itemName.name
                type = itemName.type
                icon = itemName.icon
            end
            local item, cfg
            item, cfg = CreateItem(type or "item", name, {
                type = type or "item",
                icon = itemName.icon,
                descTipInfo = itemName.descTipInfo,
                nameTipInfo = itemName.nameTipInfo,
            })
            function item:dropobjects()
                return itemName and itemName.dropobjects
            end

            local cell = fetchCell()
            initCell(self, cell, newSize, item, idx, cfg)
		    bagGrid:AddItem(cell)
            idx = idx + 1
             if idx > maxIdx then
                for i = maxIdx + 1, col * 4 do
                    local cell = fetchCell()
                    initCell(self, cell, newSize, nil, idx, nil)
                    bagGrid:AddItem(cell)
                end
                return false
            end
            return true
        end
        return false
    end
    fetch()
    loadTimers[#loadTimers + 1] = World.Timer(1, fetch)
end

local function fetchMoveBlock(self, bagGrid)
    bagGrid:InitConfig(20, 20, 4)
    local newSize = bagGrid:GetPixelSize().x / 4 - 15
	local items = Clientsetting.getMoveBlock()
    local idx = 1
    local maxIdx = #items
    local function fetch()
        for _ = idx, maxIdx do
            local itemName = items[idx] 
            local type
            local name = itemName
            local icon
            if itemName.name then
                name =  itemName.name
                type = itemName.type
                icon = itemName.icon
            end
            local item, cfg
            item, cfg = CreateItem(type or "entity", name, {
                type = type or "entity",
                icon = itemName.icon,
                descTipInfo = itemName.descTipInfo,
                nameTipInfo = itemName.nameTipInfo,
            })
            function item:dropobjects()
                return itemName and itemName.dropobjects
            end
            local block_id = Block.GetNameCfgId(name)
            function item:icon()
                return icon or ObjectPicture.Instance():buildBlockPicture(block_id)
            end

            function item:block_id()
                return block_id
            end

            local cell = fetchCell()
            initCell(self, cell, newSize, item, idx, cfg)
		    bagGrid:AddItem(cell)
            idx = idx + 1
             if idx > maxIdx and maxIdx % 4 ~= 0 then
                for i = idx % 4, 4 do
                    local cell = fetchCell()
                    initCell(self, cell, newSize, nil, idx, nil)
                    bagGrid:AddItem(cell)
                end
                return false
            end
            return true
        end
        return false
    end
    fetch()
    loadTimers[#loadTimers + 1] = World.Timer(1, fetch)
end

local openUiTypeFunc = {
    [childUiType.build] = openBuildUi,
    [childUiType.special] = openSpecialUi,
    [childUiType.item] = openItemUi,
    [childUiType.monster] = openMonsterUi,
	[childUiType.moveBlock] = openMoveBlock,
    [childUiType.equip] = openEquip,
}

local fetchInfoFunc = {
    [childUiType.build] = fetchBuildInfo,
    [childUiType.special] = fetchSpecial,
    [childUiType.item] = fetchItemInfo,
    [childUiType.monster] = fetchMonster,
	[childUiType.moveBlock] = fetchMoveBlock,
    [childUiType.equip] = fetchEquip,
}

local leftLayoutData = {
	{
		text = "win.map.item.bag.blocks.text",
		icon = "set:map_edit_bag.json image:block_icon_tap_bag.png",
		dataListName = "block",
		openUI = openBuildUi
	},
	{
		text = "win.map.item.bag.equipment.text",
		icon = "set:map_edit_bag2.json image:icon_equipment_tap_bag.png",
		dataListName = "equip",
		openUI = openBuildUi,
	},
	{
		text = "win.map.item.bag.arms.text",
		icon = "set:map_edit_bag2.json image:icon_arms_tap_bag.png",
		dataListName = "bagWeaponList",
		openUI = openBuildUi,
	},
	{
		text = "win.map.item.bag.tools.text",
		icon = "set:map_edit_bag.json image:tools_icon_tap_bag.png",
		dataListName = "shopItemList",
		openUI = openBuildUi,
	},
	{
		text = "win.map.item.bag.resources.text",
		icon = "set:map_edit_bag2.json image:icon_resources_tap_bag.png",
		dataListName = "shopResourceList",
		openUI = openBuildUi,
	},
	{
		text = "win.map.item.bag.tools.text",
		icon = "set:map_edit_bag.json image:tools_icon_tap_bag.png",
		dataListName = "dropItemList",
		openUI = openBuildUi,
	},
	{
		text = "win.map.item.bag.buff.text",
		icon = "set:map_edit_bag2.json image:icon_buff_tap_bag.png",
		dataListName = "buff",
		openUI = openBuffUI,
	},
	{
		text = "win.map.item.bag.monsters.text",
		icon = "set:map_edit_bag.json image:monsters_icon_tap_bag.png",
		dataListName = "monster",
		openUI = openMonsterUi,
	}
}

function M:getMoveBlockSize()
    if self.openType ~= childUiType.moveBlock then
        return nil
    end
    if not self.setMoveBlockUi then
        return nil
    end
    local receiver = self.setMoveBlockUi:receiver()
    return receiver:getSize()
end

function M:setMoveBlockSize(table)
    if self.openType ~= childUiType.moveBlock then
        return nil
    end
    if not self.setMoveBlockUi then
        return nil
    end
    local receiver = self.setMoveBlockUi:receiver()
    receiver:setSize(table)
end

function M:openBlockMove(isOpen)
    if isOpen then
        self.setMoveBlockUi:SetVisible(true)
        self.bagGrids:SetHeight({0, 230})
    else
        self.bagGrids:SetHeight({0, 460})
        self.setMoveBlockUi:SetVisible(false)
    end
end

function M:initSetMoveBlockUi()
	self.setMoveBlockUi = fetchSetMoveBlockUi()
    self.setMoveBlockUi:SetVisible(false)
    self.roots:AddChildWindow(self.setMoveBlockUi)
    self.setMoveBlockUi:SetArea({0, 664}, {0, 320}, {0, 320}, {0, 201})
end

function M:init()
    WinBase.init(self, "bag_edit.json")	
    self:initVar()
    self:initUi()
	self:initTip()

    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        if not isCanClick then
			return
		end
        Lib.emitEvent(Event.EVENT_OPEN_PACK)
        --Lib.emitEvent(Event.EVENT_NOVICE_GUIDE,3)
    end)
    self:initOtherUI()
	
	self:subscribe(self.settingPropBtn, UIEvent.EventButtonClick, function()
		local cell = self._select_cell
		if cell then
			local item = cell:data("item")
			local cfg = item:cfg()
			if cfg.settingUI then
				UI:openMultiInstanceWnd("mapEditTabSetting", {
					data = {
						fullName = item:full_name(),
						itemType = item:type(),
						item = item,
					},
					labelName = 
					-- {
					-- 	leftName = "editCurrenty",
					-- 	wndName = "CurrentySetting"
					-- }
					cfg.settingUI.tabList,
					backFunc = function()
						self:updataSelectItem()
					end,
				fullName = item:full_name()
			})
			end
		end
	end)
end

function M:initVar(initByOnOpen)
    if initByOnOpen then
        return
    end
    self.bagTable = {}
	self.tabItemTable = {}
	self.leftItemTab = {}
    local function initUiName(self)
        self.allEvent = {}
        self.bagGrids = self:child("root-bagGridView")
        self.closeBtn = self:child("root-btnClose")
        self.itemIcon = self:child("root-icon")
        self.descTextList = self:child("root_base-Desc-Text-List")
        self.descText = GUIWindowManager.instance:CreateGUIWindow1("StaticText")
        self.descText:SetWordWrap(true)
        self.descText:SetWidth({1, 0})
        self.descText:SetTextColor({0.448888, 0.453333, 0.419607, 1})
        self.descText:SetFontSize("HT12")
        self.roots = self:child("roots")
		self.lifeInfo = self:child("root_base-lifeText")
		self.scoreInfo = self:child("root_base-lifeText_0")
		self.lifeImage = self:child("root_base-lifeImage")
		self.scoreImage =self:child("root_base-lifeImage_1")
		self.leftItemList = self:child("root_base-menu-list")
		self.swapTip = self:child("root_base-swap-tip")
		self.settingPropBtn = self:child("root_base-settingProp")
		self.midLayout = self:child("root_base-midLayout")
		self.buffLayout = self:child("root_base-buffLayout")
    end
    initUiName(self)
    self:initSetMoveBlockUi()
end

function M:initTip()
	self.leftCell = fetchCell()
	self.rightCell = fetchCell()
	self.swapTip:AddChildWindow(self.leftCell)
	self.swapTip:AddChildWindow(self.rightCell)
end

function M:setCellTip(item1)
    if not dragCell then
        self.swapTip:SetVisible(false)
        return
    end
	local item2 = dragCell:data("item")
	local dropobjects = dragCell:data("dropobjects")
	if item1 then
		initCell(self, self.leftCell, 90, item1, 0, nil, nil, true, true)
        initCell(self, self.rightCell, 90, item2, 1, nil, dropobjects, true, true)
        self.swapTip:SetImage("set:map_edit_drag.json image:shortcutstip")
	else
        initCell(self, self.leftCell, 90, item2, 0, nil, nil, true, true)
        self.rightCell:receiver()._img_frame_sign:SetVisible(false)
        self.rightCell:SetArea({0, 0}, {0, 0}, {0, 90}, {0, 90})
        local tempCell = self.rightCell:child("widget_cell-img_item")
        tempCell:SetImage("set:map_edit_drag.json image:shortcuts_null")
        tempCell:SetArea({0, 0}, {0, 0}, {0, 50}, {0, 50})
        self.swapTip:SetImage("set:map_edit_drag.json image:shortcutstipnull")
        self.rightCell:receiver()._img_frame_select:SetImage("")
    end
	
	self.leftCell:SetXPosition({0, 35})
	self.leftCell:SetYPosition({0, 0})
	self.rightCell:SetYPosition({0, 0})
	self.rightCell:SetXPosition({0, 185})
	self.leftCell:receiver()._img_frame:SetImage(" ")
	self.rightCell:receiver()._img_frame:SetImage(" ")
end

function M:initUi(initByOnOpen)
    if initByOnOpen then
        return
	end
	local function initBag(self, index, listName)
		local bagGrid = GUIWindowManager.instance:CreateGUIWindow1("GridView", string.format( "bagGrid_%d", index))
		self.bagGrids:AddChildWindow(bagGrid)
		bagGrid:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
		bagGrid:HasItemHidden(false)
		if listName == "monster" then
			fetchMonster(self, bagGrid)
		else
			self:fetchFunc(bagGrid, listName)
		end
		self.bagTable[index] = bagGrid
	end
	for index, data in pairs(leftLayoutData) do
		local leftItem = GUIWindowManager.instance:LoadWindowFromJSON("bag-menu-cell.json")
		self.leftItemTab[data.dataListName] = leftItem
		if World.Lang == "ru" or World.Lang == "pt" then
			local size = World.Lang == "ru" and "HT10" or "HT12"
			leftItem:child("bag-menu-cell-title"):SetFontSize(size)
		end
		leftItem:child("bag-menu-cell-title"):SetText(Lang:toText(data.text))
		leftItem:child("bag-menu-cell-icon"):SetImage(data.icon)
		leftItem:SetWidth({0, 106})
		self.tabItemTable[index] = leftItem
		self:selectTabItem(leftItem, false)
		initBag(self, index, data.dataListName)
		openUiTypeFunc[index] = data.openUI
		self:subscribe(leftItem, UIEvent.EventWindowTouchUp, function()
			if not isCanClick then
				return
			end
			self:openChildUi(index)
        end)
	end

	self.swapTip:SetVisible(false)
    if World.LangPrefix ~= "zh" then
        self.descTextList:SetArea({0, 157}, {0, 42}, {1, -170}, {1, -59})
	end
	self.closeBtn:SetVisible(false)
	local buffSettingUI = UI:openMultiInstanceWnd("mapEditBagBuff")
	self.buffUI = buffSettingUI
	self.buffLayout:AddChildWindow(buffSettingUI._root)
end

function M:selectTabItem(tabItem, isSelect)
    local selectBtn = tabItem:GetChildByIndex(0)
    if isSelect then
        selectBtn:SetVisible(true)
        tabItem:SetWidth({0, 121})
    else
        selectBtn:SetVisible(false)
        tabItem:SetWidth({0, 106})
    end
    
end

function M:openChildUi(openType)
    if self._select_cell then
        self._select_cell:receiver():onClick(false, "")
    end
    self.openType = openType
    self:closeAllChildUi()
    self:showItemEmpty()
    if not self.bagTable[openType] then
        return
	end
	self.openBuffUI = false
    self.bagTable[openType]:SetVisible(true)
    self.midLayout:SetVisible(leftLayoutData[openType].openUI ~= openBuffUI)
    self.bagTable[openType]:ResetPos()
    self:selectTabItem(self.tabItemTable[openType], true)
    self:selectFristItem(openType)
    local openFunc = openUiTypeFunc[openType]
    if openFunc then
        openFunc(self, openType)
    end
end

function M:closeAllChildUi()
    for index, childUi in pairs(self.bagTable) do
        childUi:SetVisible(false)
        self:selectTabItem(self.tabItemTable[index], false)
    end
end

function M:showItemInfo(item, cfg)
    self.descTextList:ResetScroll()
    local desc = item:getDescText()
	self.itemIcon:SetImage(item:icon())
	self.descText:SetText(Lang:formatText(desc))
    local high = self.descText:GetTextStringHigh() + 20
    self.descText:SetHeight({0, high})
    self.descText:SetFontSize("HT12")
	self.descTextList:AddItem(self.descText)
	self.descText:SetVisible(true);
    self:showItemInfoTip(cfg, nil, item)
	--self:showItemDieInfo(item, cfg)
end

-- 显示怪物死亡奖励的信息
function M:showItemDieInfo(item, cfg)
	local cfg = item:cfg()
	local score = cfg.addScore
	self.scoreInfo:SetText(Lang:toText("scoreInfo"))
	self.scoreImage:SetVisible(score ~= nil)
	self.scoreInfo:SetVisible(score ~= nil)
	local type = cfg.entityDerive
	if score then
		self.scoreImage:SetImage("set:map_edit_bagNum.json image:integral_" .. score)
	end
	local life = cfg.maxHp
	local noShowHp = cfg.noShowBagHp
	self.lifeInfo:SetText(Lang:toText("lifeInfo"))
	self.lifeInfo:SetVisible(type == "monster" and life and not noShowHp)
	self.lifeImage:SetVisible(type == "monster" and life and not noShowHp)
	if type == "monster" then
		self.lifeImage:SetImage("set:map_edit_bagNum.json image:hp_" .. life)
	end
end

function M:showItemInfoTip(cfg, moveBlockSize, item, flag)
    if not item then
        return
    end
    moveBlockSize = moveBlockSize or UI:getWnd("mapEditItemBag"):getMoveBlockSize()
	local tip = Lang:toText(item:getNameText())

    local tipLength = self.titleText:GetFont():GetTextExtent(tip,1.0)
    if tipLength > 400 then
        self.titleTip:SetArea({0, 40}, {0, 267 + 78}, {0, 100}, {0, 40})
        if World.LangPrefix ~= "zh" then
            self.descTextList:SetArea({0, 157}, {0, 62}, {1, -170}, {1, -69})
        end
        self.nameBg:SetVisible(true)
        local tempTip = self:split(tip,"(")
		if not flag and tempTip and #tempTip > 1 then
			self.titleText:SetText(tempTip[1] .. "\n(" .. tempTip[2])
		else
			self.titleText:SetText(tip)
		end
    else
        self.titleTip:SetArea({0, 40}, {0, 267 + 58}, {0, 100}, {0, 40})
        if World.LangPrefix ~= "zh" then
            self.descTextList:SetArea({0, 157}, {0, 42}, {1, -170}, {1, -59})
        end
        self.nameBg:SetVisible(false)
		if not flag then
			self.titleText:SetText(tip)
		end
    end
	
end


function M:split(str,reps)
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

function M:showItemEmpty()
    self.itemIcon:SetImage("")
end

function M:registerEvent()
    self.allEvent[#self.allEvent +1] = Lib.subscribeEvent(Event.EVENT_CHANGE_MODE_STATE, function(index)
        --self:openChildUi(index)
    end)

    self.allEvent[#self.allEvent +1] = Lib.subscribeEvent(Event.EVENT_SELECTING_ITEM, function(blockSize)
        local cell = self._select_cell
        if cell and not blockSize then
			cell:receiver():onClick(false, "")
			self._select_cell = nil
		end
    end)

    -- Lib.subscribeEvent(Event.EVENT_EDIT_ITEM_INFO, function(cfg, moveBlockSize)
    --     self:showItemInfoTip(cfg, moveBlockSize, nil, true)
    -- end)
end

function M:closeAllEvent()
    for _, closeEventF in pairs(self.allEvent or {}) do
        closeEventF()
    end
end

function M:selectFristItem(openType)
    if not self.bagTable[openType] then
        return
    end
    local grid = self.bagTable[openType]
    if grid:GetItemCount() > 0 then
        local cell = grid:GetItem(0)
        if not cell then
            return
        end
        local item = cell:data("item")
        local cfg = cell:data("cfg")
        self._select_cell = cell
        self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self:showItemInfo(item, cfg)
        if item:type() == "block" then
            self.settingPropBtn:SetVisible(cfg.settingUI and not self.setDropItem and true or false)
        else
            self.settingPropBtn:SetVisible(cfg.settingUI and true or false)
        end
        --Lib.emitEvent(Event.EVENT_PACK_SWAP_ITEM, item)
    end
end

function M:getSelectItem()
	if self.openBuffUI then
		return self.buffUI:getSelectItem()
	end
	local cell = self._select_cell
	return cell and cell:data("item")
end

local function removeChildAllWin(win)
    if not win then
        return
    end
    while(true)
    do
        local childCount = win:GetChildCount()
        if childCount == 0 then
            return
        end
        local child = win:GetChildByIndex(0)
        win:RemoveChildWindow1(child)
    end
end

function M:updataSelectItem()
	local cell = self._select_cell
	if not cell then
		return
	end
	local item = cell:data("item")
	local cfg = cell:data("cfg")
	cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
	self:showItemInfo(item, cfg)
	self.settingPropBtn:SetVisible(cfg.settingUI and true or false)
end

function M:onOpen(setDropItem, uiNameList)
	self.setDropItem = setDropItem
	-- Lib.emitEvent(Event.EVENT_EDIT_OPEN_BACKGROUND, true)
    local leftItemUITab = self.leftItemTab
    uiNameList = uiNameList or {"block", "equip", "bagWeaponList", "dropItemList", "shopResourceList", "buff"}
    removeChildAllWin(self.leftItemList:getContainerWindow())
    self.leftItemList:ResetScroll()
	for _, uiName in pairs(uiNameList) do
		local ui = leftItemUITab[uiName]
		if ui then
			self.leftItemList:AddItem(ui)
		end
	end
    self._select_cell = nil
    self:registerEvent()
    self:openChildUi(self:getChildUiIndex(uiNameList[1]))
    self.setMoveBlockUi:child("mapEditItemBagRoot-textCount"):SetText("1")
    self.setMoveBlockUi:child("mapEditItemBagRoot-textCount_13"):SetText("1")
    self.setMoveBlockUi:child("mapEditItemBagRoot-textCount_18"):SetText("1")
    UI:getWnd("mapEditItemBag"):setMoveBlockSize({1,1,1})
end

function M:getChildUiIndex(name)
    for k, data in pairs( leftLayoutData ) do
        if data.dataListName == name then
            return k
        end
    end
    return 1
end

local function closeLoadTimer()
    for _, timer in ipairs(loadTimers) do
        timer()
        timer = nil
    end
    loadTimers = {}
end

function M:onClose()
    self.buffLayout:SetVisible(false)
    self.buffUI:onClose()
    -- closeLoadTimer()
    Lib.emitEvent(Event.EVENT_EDIT_OPEN_BACKGROUND, false)
    self:closeAllEvent()
    if not self._select_cell then
        return
    end
    self._select_cell:receiver():onClick(false, "")
end

function M:initOtherUI()
    self.bg = self:child("root-item-bg")
    local titleIcon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "TitleIcon")
    titleIcon:SetArea({0, 142}, {0, 20}, {0, 171}, {0, 20})
    self.bg:AddChildWindow(titleIcon)
    if World.Lang == "zh_CN" then
        titleIcon:SetImage("set:mapBag.json image:illustration1.png")
        titleIcon:SetArea({0, 180}, {0, 20}, {0, 103}, {0, 20})
    else
        titleIcon:SetImage("set:mapBagDescription.json image:DESCRIPTION")
        titleIcon:SetArea({0, 142}, {0, 20}, {0, 171}, {0, 25})
    end

    self.nameBg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "nameBg")
    self.nameBg:SetBackgroundColor({227/255, 227/255, 227/255, 1})
    self.nameBg:SetArea({0, 30}, {0, 257}, {0, 416}, {0, 80})
    self.nameBg:SetVisible(false)
    self.bg:AddChildWindow(self.nameBg)

    self.titleText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "title")
    self.titleText:SetArea({0, 40}, {0, 264}, {0, 400}, {0, 40})
    self.titleText:SetTextColor({0.448888, 0.453333, 0.419607, 1})
    self.titleText:SetFontSize("HT18")
    self.titleText:SetText("")
    self.titleText:SetWordWrap(true)
    self.titleText:SetProperty("TextShadow", "true")
    self.titleText:SetProperty("TextShadowColor", tostring(0.448888) .. " " .. tostring(0.453333) .. " " .. tostring(0.419607) .. " 1")
    self.bg:AddChildWindow(self.titleText)

    self.titleTip = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "titleTip")
    self.titleTip:SetArea({0, 40}, {0, 267 + 58}, {0, 100}, {0, 40})
    self.titleTip:SetTextColor({0.172, 0.69, 0.52, 1})
    self.titleTip:SetFontSize("HT14")
    self.titleTip:SetText(Lang:toText("desc"))
    self.bg:AddChildWindow(self.titleTip)

end
return M