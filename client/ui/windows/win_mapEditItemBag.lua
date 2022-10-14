local setting = require "common.setting"
local globalSetting = require "editor.setting.global_setting"
local cell_pool = {}
local move_Block_pool = {}
local dragCell = nil
local isCanClick = true
local loadTime = 2
local delayLoadCell = true
local UI_LONG_TOUCH_TIME = 800
local moveBlockUiType = 6

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

local function openAllItemUi(self)
    -- CGame.instance:onEditorDataReport("click_bag_all", "", 3)
    self.allItemLayout:SetVisible(true)
end

local function openBuildUi(self)
    CGame.instance:onEditorDataReport("click_bag_block", "", 3)
    self.allItemLayout:SetVisible(false)
end

local function openSpecialUi(self)
    CGame.instance:onEditorDataReport("click_bag_special", "", 3)
    self.allItemLayout:SetVisible(false)
end

local function openItemUi(self)
    CGame.instance:onEditorDataReport("click_bag_tool", "", 3)
    self.allItemLayout:SetVisible(false)
end

local function openMonsterUi(self)
    CGame.instance:onEditorDataReport("click_bag_monsters", "", 3)
    self.allItemLayout:SetVisible(false)
end

local function openMoveBlock(self)
    CGame.instance:onEditorDataReport("click_bag_moveblock", "", 3)
    self.allItemLayout:SetVisible(false)
    UI:getWnd("mapEditItemBag"):setMoveBlockSize({1,1,1})
end

local function openEquipUi(self)
    CGame.instance:onEditorDataReport("click_bag_equipment", "", 3)
    self.allItemLayout:SetVisible(false)
end

local function openWeaponUi(self)
    CGame.instance:onEditorDataReport("click_bag_weapon", "", 3)
    self.allItemLayout:SetVisible(false)
end

local function openResourcesUi(self)
    CGame.instance:onEditorDataReport("click_bag_resources", "", 3)
    self.allItemLayout:SetVisible(false)
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
	self:child("root_base-settingPop"):CleanupChildren()
	local item = cell:data("item")
	if self._select_cell then
		self._select_cell:receiver():onClick(false, "")
	end
	self._select_cell = cell
	self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
    self:setAllItemNameTip(item:getNameText())
    -- 设置属性
    local canEdit = cfg.settingUI and true or false
	self.settingPropBtn:SetVisible(canEdit)
	
	--fullName
	self:showItemInfo(item, cfg)
	Lib.emitEvent(Event.EVENT_PACK_SWAP_ITEM, item)
end

local function initCell(self, cell, newSize, item, idx, cfg, dropobjects, isSubscribe, droopobjectsSize)
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, newSize }, { 0, newSize})
    cell:setData("index", idx)
    if item and item.isUnfold then
        cell:receiver()._img_frame:SetImage("set:map_edit_bag.json image:itembox1_unfold_bag.png")
    else
        cell:receiver()._img_frame:SetImage("set:map_edit_bag.json image:itembox1_bag.png")
    end
    cell:receiver()._img_frame_select:SetImage("")
    cell:receiver()._img_frame_select:SetVisible(true)
    if not item then
        cell:receiver()._img_locked:SetVisible(true)
        cell:receiver()._img_locked:SetArea({0,0},{0,0},{1,0},{1,0})
        cell:receiver()._img_locked:SetImage("set:map_edit_bag.json image:itembox2_empty_bag.png")
        return
    end
    cell:receiver()._fold_btn:SetVisible(item.isCategory or false)

	if EditorModule:isMustCreateDesc(item:type()) then
		item:getDescText(true)
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
        GlobalProperty:Instance():setIntProperty("UILongTouchTime", UI_LONG_TOUCH_TIME)
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
			cell:child("widget_cell-img_item"):setEnableDrag(false)
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
			cell:child("widget_cell-img_item"):setEnableDrag(false)
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
            self.bagTable[self.openType]:SetMoveAble(true)
			cell:child("widget_cell-img_item"):setEnableDrag(false)
			Lib.emitEvent(Event.EVENT_SWAP_INVENTORY, pos, item)
		end)

	end

end

local function CreateItem(type, fullName, args)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

-- 计算折叠操作方块之前的方块数量
local function getFoldBlocksCount(self, foldName, blocks)
    local listCount = 0
    for _, data in pairs(self.foldBlockList) do
        listCount = listCount + 1
        for idx = 1, #data.unfold do
            if blocks.foldBlocks[data.unfold[idx]] then
                listCount = listCount + 1
            end
        end
        if foldName == data.Category then
            break
        end
    end
    return listCount
end

-- 
local function updateBlockFold(self, foldName, blocks)
    local listCount = getFoldBlocksCount(self, foldName, blocks)
    local isUnFold = blocks.categoryIsFold[foldName]
    for _, data in pairs(self.foldBlockList) do
        if foldName == data.Category then
            local opType = isUnFold and "insert" or "remove"
            for idx = 1, #data.unfold do
                local opCount = isUnFold and (listCount + idx) or (listCount - idx + 1)
                table[opType](blocks.blocks, opCount, data.unfold[idx])
                blocks.foldBlocks[data.unfold[idx]] = isUnFold
            end
            break
        end
    end
end

local lastBlockName = ""
local function checkIsCategory(self, foldName)

    if lastBlockName == foldName then
        lastBlockName = ""
        return false
    end

    for _, data in pairs(self.foldBlockList) do
        if foldName and foldName == data.Category and data.unfold then
            lastBlockName = foldName
            return true
        end
    end

    return false
end

local function getFoldList(self, categoryName)
    for _, data in pairs(self.foldBlockList) do
        if categoryName == data.Category then
            return data.unfold
        end
    end
end

local function createItemCell(self, dataItems, bagGrid, itemName, newSize, idx, backcallFunc)
    local type, icon
    local name = itemName
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
    if dataItems and dataItems.blocks then
        item.isCategory = checkIsCategory(self, itemName)
        item.isUnfold = dataItems.foldBlocks[itemName]
    end

    function item:dropobjects()
        return itemName and itemName.dropobjects
    end

    local cell = fetchCell()
    if backcallFunc then
        backcallFunc(item, itemName, icon)
    end
    initCell(self, cell, newSize, item, idx, cfg, nil, item.isCategory)
    if item.isCategory then
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            if self._select_cell then
                self._select_cell:receiver():onClick(false, "")
            end
            self:setAllItemNameTip(item:getNameText())
            dataItems.categoryIsFold[itemName] = not dataItems.categoryIsFold[itemName]
            if dataItems.categoryIsFold[itemName] then
                cell:receiver()._fold_btn:SetImage("set:map_edit_bag.json image:bag_fold_icon.png")
            else
                cell:receiver()._fold_btn:SetImage("set:map_edit_bag.json image:bag_unfold_icon.png")
            end
            self:blockFoldSwitch(itemName, bagGrid, 100, dataItems)
        end)
    end
    return cell
end

function M:blockFoldSwitch(itemName, bagGrid, newSize, blocks)
    local isNoFold = blocks.categoryIsFold[itemName]
    local foldList = getFoldList(self, itemName)
    local listCount = getFoldBlocksCount(self, itemName, blocks)
    updateBlockFold(self, itemName, blocks)
    for idx = 1, #foldList do
        if isNoFold then
            local cell = createItemCell(self, blocks, bagGrid, foldList[idx], newSize, idx, function (item)
                item.isCategory = checkIsCategory(self, foldList[idx])
                item.isUnfold = blocks.foldBlocks[foldList[idx]]
            end)
            bagGrid:AddItem1(cell, listCount + idx - 1)
        else
            local cell = bagGrid:GetItem(listCount - idx)
            bagGrid:RemoveItem(cell)
        end
    end

end

local function timerFetch(self, bagGrid, dataItems, newGridSize, rowCount, backcallFunc)
    local idx = 1
    bagGrid:InitConfig(20, 20, rowCount or 4)
	local newSize = newGridSize or bagGrid:GetPixelSize().y / 4 - 15
    local items = dataItems.blocks or dataItems
    local maxIdx = #items
    local function fetch()
        local loadCount = 0
        for _ = delayLoadCell and idx or 1, maxIdx do 
            loadCount = loadCount + 1
            local itemName = items[idx]
            local cell = createItemCell(self, dataItems, bagGrid, itemName, newSize, idx, backcallFunc)
            bagGrid:AddItem(cell)
            idx = idx + 1
            if not rowCount and idx > maxIdx and maxIdx % 4 ~= 0 then
                for _ = idx % 4, 4 do
                    local cell = fetchCell()
                    initCell(self, cell, newSize, nil, idx, nil)
                    bagGrid:AddItem(cell)
                end
                if delayLoadCell then
                    return false
                end
            end
            if delayLoadCell then
                return true
            end
        end
        if delayLoadCell then
            return false
        end
    end
    fetch()
    if delayLoadCell then
        World.Timer(loadTime, fetch)
    end
end

local function fetchBuildInfo(self, bagGrid, dataItems, newGridSize, rowCount)
    dataItems = dataItems or self.allBlock.itemBlocks
    if rowCount then
        dataItems = self.allBlock.allBlocks
    end
    timerFetch(self, bagGrid, dataItems, newGridSize, rowCount)
end

local function fetchSpecial(self, bagGrid, dataItems, newGridSize, rowCount)
    dataItems = dataItems or Clientsetting.getSpecialList()
    timerFetch(self, bagGrid, dataItems, newGridSize, rowCount)
end

local function fetchEquip(self, bagGrid, dataItems, newGridSize, rowCount)
	dataItems = dataItems or Clientsetting.getequipList()
    timerFetch(self, bagGrid, dataItems, newGridSize, rowCount)
end

local function fetchMonster(self, bagGrid, dataItems, newGridSize, rowCount)
    dataItems = dataItems or Clientsetting.getEntityList()
    timerFetch(self, bagGrid, dataItems, newGridSize, rowCount)
end

local function fetchItemInfo(self, bagGrid, dataItems, newGridSize, rowCount)
    dataItems = dataItems or Clientsetting.getItemList()
    timerFetch(self, bagGrid, dataItems, newGridSize, rowCount)
end

local function fetchMoveBlock(self, bagGrid, dataItems, newGridSize, rowCount)
    dataItems = dataItems or Clientsetting.getMoveBlock()
    timerFetch(self, bagGrid, dataItems, newGridSize, rowCount, function (item, itemName, icon)
        local block_id = Block.GetNameCfgId(itemName.name or itemName)
        function item:icon()
            return icon or ObjectPicture.Instance():buildBlockPicture(block_id)
        end
        function item:block_id()
            return block_id
        end
    end)
    
end

local function fetchWeapon(self, bagGrid, dataItems, newGridSize, rowCount)
	dataItems = dataItems or Clientsetting.getWeaponList()
    timerFetch(self, bagGrid, dataItems, newGridSize, rowCount)
end

local function fetchResources(self, bagGrid, dataItems, newGridSize, rowCount)
	dataItems = dataItems or Clientsetting.getResourceList()
    timerFetch(self, bagGrid, dataItems, newGridSize, rowCount)
end

function M:setAllItemNameTip(showText)
	local isShow = showText ~= ""
	self.allItemNameTip:SetVisible(isShow)
	local text = Lang:toText(showText)
	if isShow then
		local width = self.allItemNameTip:GetFont():GetTextExtent(text, 1.0) + 50
		self.allItemNameTip:SetWidth({0 , width })
		self.allItemNameTip:SetText(text)
	end
end

local function fetchAllItemInfo(self)
    self:openBlockMove(false)
    self.allItemLayout:SetVisible(true)
    self.midLayout:SetVisible(false)
    local allItemDataList = {
        self.allBlock.allBlocks.blocks,
        Clientsetting.getSpecialList(),
        Clientsetting.getequipList(),
        Clientsetting.getEntityList(),
        Clientsetting.getItemList(),
        Clientsetting.getWeaponList(),
        Clientsetting.getResourceList()
    }

    local allItemFuncList = {
        fetchBuildInfo,
        fetchSpecial,
        fetchEquip,
        fetchMonster,
        fetchItemInfo,
        fetchWeapon,
        fetchResources,
    }

    local delayTime = 0
    local newSize = 100
    for index, func in pairs(allItemFuncList) do
        World.Timer(delayTime, function ()
            func(self, self.showAllItemGridView, nil, newSize, 8)
        end)
        delayTime = delayTime + #allItemDataList[index] * loadTime + 2
    end

    local function switchShowGridView(isShowSearchView)
        self.showAllItemGridView:SetVisible(not isShowSearchView)
        self.showSearchGridView:SetVisible(isShowSearchView)
        self:setAllItemNameTip("")
        if self._select_cell then
            self._select_cell:receiver():onClick(false, "")
            self._select_cell = nil
        end

    end

    local function filterNotMatch(langTextList)
        local temp = {}
        for idx = 1, #langTextList do
            local text = langTextList[idx]

            if text:find("_itemname") then
                text = text:match("(.+)_itemname")
            end

            if not text:find("myplugin") then
                text = "myplugin/" .. text
            end
            local itemName = self.showAllItemGridList[text]
            if itemName then
                temp[#temp + 1] = itemName
            end
        end
        return temp
    end

    self.showSearchGridView:InitConfig(20, 20, 8)
    local initText = Lang:toText("win.map.item.bag.allItem.search")
    local editText = ""
    self:subscribe(self.searchEdit, UIEvent.EventWindowTouchUp, function()
        editText = self.searchEdit:GetPropertyString("Text","")
        if editText == "" then
            self.searchEdit:SetText(initText)
            self.searchEdit:SetTextColor({157 / 255, 161 / 255, 164 / 255,1})
        end
    end)

    self:subscribe(self.searchEdit, UIEvent.EventWindowTouchDown, function()
        self.searchEdit:SetText("")
    end)

    self:subscribe(self.searchEdit, UIEvent.EventEditTextInput, function()
		editText = self.searchEdit:GetPropertyString("Text","")
        local isShowSearchView = editText ~= "" and editText ~= initText
        switchShowGridView(isShowSearchView)
		if isShowSearchView then
            self.showSearchGridView:RemoveAllItems()
            local idx = 1
            local matchList = filterNotMatch(Lang:getFuzzyLangTextList(editText))
            for _, item in pairs(matchList) do
                local cell = createItemCell(self, nil, self.showSearchGridView, item, newSize, idx)
                idx = idx + 1
                self.showSearchGridView:AddItem(cell)
            end
            self.searchEdit:SetTextColor({44 / 255, 177 / 255, 130 / 255,1})
		end
	end)
end

local openUiTypeFunc = {
    openAllItemUi = openAllItemUi,
    openBuildUi = openBuildUi,
    openSpecialUi = openSpecialUi,
	openItemUi = openItemUi,
    openMonsterUi = openMonsterUi,
	openMoveBlock = openMoveBlock,
    openEquipUi = openEquipUi,
    openWeaponUi = openWeaponUi,
    openResourcesUi = openResourcesUi
}

local fetchInfoFunc = {
    fetchAllItemInfo = fetchAllItemInfo,
    fetchBuildInfo = fetchBuildInfo,
    fetchSpecial = fetchSpecial,
    fetchItemInfo = fetchItemInfo,
    fetchMonster = fetchMonster,
    fetchMoveBlock = fetchMoveBlock,
    fetchEquip = fetchEquip,
    fetchWeapon = fetchWeapon,
    fetchResources = fetchResources
}

function M:getMoveBlockSize()
    if self.openType ~= moveBlockUiType then
        return nil
    end
    if not self.setMoveBlockUi then
        return nil
    end
    local receiver = self.setMoveBlockUi:receiver()
    return receiver:getSize()
end

function M:setMoveBlockSize(table)
    if self.openType ~= moveBlockUiType then
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
        Lib.emitEvent(Event.EVENT_NOVICE_GUIDE,3)
    end)
    self:initOtherUI()

    Lib.subscribeEvent(Event.EVENT_NOVICE_GUIDE, function(indexType, isFinish)
        if indexType == 2 then
            if self:child("root-btnClose") then
                self:child("root-btnClose"):SetName("bagClose1")
            end
        end
    end)

	Lib.subscribeEvent(Event.EVENT_SWAP_INVENTORY_TIP, function(flag, cellItem)
		if flag then
			self.swapTip:SetVisible(false)
			return
		end
		self.swapTip:SetVisible(true)
		self:setCellTip(cellItem)
    end)
	
	self:subscribe(self.settingPropBtn, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_resources_settings", "")
		self:child("root_base-settingPop"):CleanupChildren()
		local cell = self._select_cell
		if cell then
			local item = cell:data("item")
			local cfg = item:cfg()
			if cfg.settingUI then
				if cfg.entityDerive == "monster" then
					self:popMonsterShopUI({
						fullName = item:full_name(),
						item = item
					})
					return
				end
				local fullName
				if item:type() == "block" then
					fullName = setting:id2name("block", item:block_id())
				else
					fullName = item:full_name()
				end
				UI:openMultiInstanceWnd("mapEditTabSetting", {
					data = {
						fullName = fullName,
						item = item
					},
					labelName = 
					-- {
					-- 	leftName = "editCurrenty",
					-- 	wndName = "CurrentySetting"
					-- }
					cfg.settingUI.tabList,
					backFunc = function()
						self:updataSelectItem()
					end
				,
				fullName = item:full_name()
			})
			end
		end
	end)
end

function M:popMonsterShopUI(data)
	local pullDown = UIMgr:new_widget("pullDown")
	self:child("root_base-settingPop"):AddChildWindow(pullDown)
	local item = data.item
	local cfg = item:cfg()
    pullDown:invoke("fillData", {
		selectList = {
			{
				text = "editor.ui.monsterSetting",
				disable = cfg.shopGroupName and true or false
			},
			{
				text = "win.map.global.shopSetting",
			}
		},
		backFunc = function(index)
			self:child("root_base-settingPop"):CleanupChildren()
			if index == 1 then
					local cfg = item:cfg()
					UI:openMultiInstanceWnd("mapEditTabSetting", {
						data = {
							fullName = item:full_name(),
							item = item
						},
						labelName = 
						-- {
						-- 	leftName = "editCurrenty",
						-- 	wndName = "CurrentySetting"
						-- }
						cfg.settingUI.tabList,
						backFunc = function()
							self:updataSelectItem()
						end
						,
						fullName = item:full_name()
					})
			elseif index == 2 then
				UI:openWnd("shopBinding", item:cfg().fullName)
			end
		end,
		disableSelect = true
    })
end

function M:initVar(initByOnOpen)
    if initByOnOpen then
        return
    end
    self.bagTable = {}
    self.tabItemTable = {}
    self.allBlock = {
        itemBlocks = {},
        allBlocks = {}
    }
    for _, data in pairs(self.allBlock) do
        data.blocks = {}
        data.categoryIsFold = {}
        data.foldBlocks = {}
    end

    self.showAllItemGridList = Clientsetting.getAllItemList()
    self.foldBlockList = Clientsetting.getBlockFoldList()
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
        self.allItemLayout = self:child("root_base-root_base-AllItemLayout")
        self.midLayout = self:child("root_base-midLayout")
        self.showAllItemGridView = self:child("root_base-AllItem-ShowAllGridView")
        self.showSearchGridView = self:child("root_base-AllItem-ShowSearchGridView")
        self.searchBtn = self:child("root_base-SearchLayout-searchBtn")
        self.searchEdit = self:child("root_base-SearchLayout-edit")
        self.searchEdit:SetText(Lang:toText("win.map.item.bag.allItem.search"))
        self.allItemNameTip = self:child("root_base-AllItem-NameTip")
    end

    local function initBlocks()
        for _, data in pairs(self.foldBlockList) do

            for _, list in pairs(self.allBlock) do
                local blocks = list.blocks
                local categoryIsFold = list.categoryIsFold
                blocks[#blocks + 1] = data.Category
                categoryIsFold[#categoryIsFold + 1] = false
            end
        end
    end
    initBlocks()
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
	local leftLayoutData = Clientsetting.getData("bagUIData")
	local function initBag(self, index, func)
		local bagGrid = GUIWindowManager.instance:CreateGUIWindow1("GridView", string.format( "bagGrid_%d", index))
		bagGrid:SetVisible(false)
		self.bagGrids:AddChildWindow(bagGrid)
		bagGrid:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
		bagGrid:HasItemHidden(false)
		func(self, bagGrid)
		self.bagTable[index] = bagGrid
	end
	self.openChildUIFuncMap = {}
	for index, data in pairs(leftLayoutData) do
		local leftItem = GUIWindowManager.instance:LoadWindowFromJSON("bag-menu-cell.json")
		self.leftItemList:AddItem(leftItem)
		if World.Lang == "ru" or World.Lang == "pt" then
			local size = World.Lang == "ru" and "HT10" or "HT12"
            leftItem:child("bag-menu-cell-title"):SetFontSize(size)
		end
		leftItem:child("bag-menu-cell-title"):SetText(Lang:toText(data.text))
		leftItem:child("bag-menu-cell-icon"):SetImage(data.icon)
		leftItem:SetWidth({0, 106})
		self.tabItemTable[index] = leftItem
		self:selectTabItem(leftItem, false)
		self.openChildUIFuncMap[index] = openUiTypeFunc[data.openFunc]
		World.Timer(10 * index, function()
			initBag(self, index, fetchInfoFunc[data.fetchFunc])
		end)
		self:subscribe(leftItem, UIEvent.EventWindowTouchUp, function()
			if not isCanClick then
				return
			end
            self:openBlockMove(index == moveBlockUiType)
            self.allItemLayout:SetVisible(index == 1)
            self.midLayout:SetVisible(index ~= 1)
			Lib.emitEvent(Event.EVENT_CHANGE_MODE_STATE, index)
        end)
	end

	self.swapTip:SetVisible(false)
    if World.LangPrefix ~= "zh" then
        self.descTextList:SetArea({0, 157}, {0, 42}, {1, -170}, {1, -59})
    end
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
        self:setAllItemNameTip("")
    end
    self.openType = openType
    self:closeAllChildUi()
    self:showItemEmpty()
    if not self.bagTable[openType] then
        return
    end
    self.bagTable[openType]:SetVisible(true)
    self.bagTable[openType]:ResetPos()
    local openFunc = self.openChildUIFuncMap[openType]
    self.canEdit = (openFunc ~= openBuildUi)
    self.settingPropBtn:SetVisible(false)
    if openFunc then
        openFunc(self)
    end
    self:selectTabItem(self.tabItemTable[openType], true)
    self:selectItem(openType, self.selectItemIndex)
    self.selectItemIndex = 1
end

function M:closeAllChildUi()
    for index, childUi in pairs(self.bagTable) do
        childUi:SetVisible(false)
        self:selectTabItem(self.tabItemTable[index], false)
    end
end

function M:showItemInfo(item, cfg)
    if not item then
        return
    end
	-- 显示描述
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
        self:openChildUi(index)
    end)

    self.allEvent[#self.allEvent +1] = Lib.subscribeEvent(Event.EVENT_SELECTING_ITEM, function(blockSize)
        local cell = self._select_cell
        if cell and not blockSize then
			cell:receiver():onClick(false, "")
			self._select_cell = nil
		end
    end)

    Lib.subscribeEvent(Event.EVENT_EDIT_ITEM_INFO, function(cfg, moveBlockSize)
        self:showItemInfoTip(cfg, moveBlockSize, nil, true)
    end)
end

function M:closeAllEvent()
    for _, closeEventF in pairs(self.allEvent or {}) do
        closeEventF()
    end
end

function M:selectItem(openType, index)
	self:child("root_base-settingPop"):CleanupChildren()
    if not self.bagTable[openType] then
        return
    end
    local grid = self.bagTable[openType]
    index = math.min(index, grid:GetItemCount())
    if grid:GetItemCount() > 0 then
        local cell = grid:GetItem(index - 1)
        if not cell then
            return
        end
        local item = cell:data("item")
        local cfg = cell:data("cfg")
        self._select_cell = cell
        self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self:showItemInfo(item, cfg)
        local canEdit = cfg.settingUI and true or false
        self.settingPropBtn:SetVisible(canEdit)
        Lib.emitEvent(Event.EVENT_PACK_SWAP_ITEM, item)
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

function M:onOpen(openType, openCell)
    Lib.emitEvent(Event.EVENT_EDIT_OPEN_BACKGROUND, true)
    self._select_cell = nil
    self.openCell = self.openCell
    self.midLayout:SetVisible(openType~=1)
    self:registerEvent()
    self.selectItemIndex = globalSetting:getBagSelectItemStatus() and globalSetting:getBagSelectItemStatus().selectItemIndex or 1
    self:openChildUi(openType)
    self.reloadArg = table.pack(openType, openCell)
    self.setMoveBlockUi:child("mapEditItemBagRoot-textCount"):SetText("1")
    self.setMoveBlockUi:child("mapEditItemBagRoot-textCount_13"):SetText("1")
    self.setMoveBlockUi:child("mapEditItemBagRoot-textCount_18"):SetText("1")
    UI:getWnd("mapEditItemBag"):setMoveBlockSize({1,1,1})
    self:openBlockMove(openType == moveBlockUiType)
    local scrollOffset = globalSetting:getBagSelectItemStatus() and  globalSetting:getBagSelectItemStatus().scrollOffset or 0
    if self.bagTable[self.openType] then
        self.bagTable[self.openType]:SetScrollOffset(scrollOffset)
    end
end

function M:onReload(reloadArg)
	local openType, openCell = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
    self:onOpen(openType, openCell)
end

function M:calcSelectItemOnBagIndex()
    self:child("root_base-settingPop"):CleanupChildren()
    if not self.bagTable[self.openType] then
        return
    end
    local grid = self.bagTable[self.openType]
    local defaultSelectItemIndex = 1
    local select_cell_item = self._select_cell:data("item")
    if grid:GetItemCount() > 0 then
        for index = 1, grid:GetItemCount() do
            local cell = grid:GetItem(index - 1)
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
    Lib.emitEvent(Event.EVENT_EDIT_OPEN_BACKGROUND, false)
    self:closeAllEvent()
    if not self._select_cell then
        return
    end
    local curOffset = self.bagTable[self.openType]:GetScrollOffset()
    local selectItemIndex = self:calcSelectItemOnBagIndex()
    globalSetting:saveBagSelectItemStatus({selectItemIndex = selectItemIndex, scrollOffset = curOffset})
    self._select_cell:receiver():onClick(false, "")
    self:setAllItemNameTip("")
    Lib.emitEvent(Event.EVENT_PACK_CLOSE_PACK, self.openCell)
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