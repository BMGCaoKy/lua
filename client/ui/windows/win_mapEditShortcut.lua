local setting = require "common.setting"
local cell_pool = {}
local MAX_COUNT = 7
local enumStateType = Clientsetting.getEnumStateType()
local customHandBagSetting = Clientsetting.getCustomHandBag()
local enumItemType = Clientsetting.getData("bagItemsType") or {"block", "item", "item", "entity", "item"}
local isGuide = true
local isCanClick = true

local mapModeType =
{
	{
		icon = "set:mapEditToolbarImg.json image:icon_allItem",
		changeImage = "set:map_edit_map_homepage.json image:allItem_change.png",
	},
	{
		icon = "set:mapEditToolbarImg.json image:icon_block",
		changeImage = "set:map_edit_map_homepage.json image:block_change.png",
	},
	{
		icon = "set:mapEditToolbarImg.json image:icon_Special",
		changeImage = "set:map_edit_map_homepage.json image:Special_change.png",
	},
	{
		icon = "set:mapEditToolbarImg.json image:icon_tools",
		changeImage = "set:map_edit_map_homepage.json image:tools_change.png",
	},
	{
		icon = "set:mapEditToolbarImg.json image:icon_Monsters",
		changeImage = "set:map_edit_map_homepage.json image:Monsters_change.png",
	},
	{
		icon = "set:mapEditToolbarImg.json image:icon_Mobileterrain",
		changeImage = "set:map_edit_map_homepage.json image:Mobileterrain_change.png",
	},
	{
		icon = "set:mapEditToolbarImg.json image:icon_equipment",
		changeImage = "set:map_edit_bag2.json image:equipment_change.png",
	},
	{
		icon = "set:mapEditToolbarImg.json image:icon_arms",
		changeImage = "set:map_edit_bag2.json image:arms_change.png",
	},
	{
		icon = "set:mapEditToolbarImg.json image:icon_resources",
		changeImage = "set:map_edit_bag2.json image:resources_change.png",
	},
}

local mapModeTip =
{
	"allItem_tip",
    "block_tip",
    "special_block_tip",
    "items_tip",
    "monsters_tip",
	"mobileterrain_tip",
	"equipment_tip",
    "arms_tip",
    "resources_tip",
}
local function fetchCell()
    local ret = table.remove(cell_pool)
    if not ret then
        ret = UIMgr:new_widget("cell", "widgetCell_edt.json")
    end
    return ret
end

local function unifyProc(self, btn, proc)
    self:subscribe(btn, UIEvent.EventButtonClick, function()
        self:unsubscribe(btn)
        World.Timer(1, function()
            if not btn then
                return
            end
            unifyProc(self, btn, proc)
        end)
        if proc then
            proc()
        end
    end)
end

local function CreateItem(type, fullName)
	local item = EditorModule:createItem(type, fullName)
	local cfg = item:cfg()
	return item, cfg
end

function M:initHandBagData()
	local function getList(mode_state)
		local itemsList = Clientsetting.getBagItemsList()
		local itemsName = itemsList[mode_state]
		assert(itemsName, "not the itemsName")
        return customHandBagSetting[itemsName]
	end



	for _, mode_state in pairs(enumStateType) do
		local items = getList(mode_state)
		local idx = 0
		for _, item in pairs(items or {}) do
			local type
			local name = item
			if item.name then
				name =  item.name
				type = item.type
			end
			local targetItem = CreateItem(type or enumItemType[mode_state], name, {
                icon = item.icon,
                descTipInfo = item.descTipInfo,
                nameTipInfo = item.nameTipInfo,
			})
			
            if item.dropobjects then
                function targetItem:dropobjects()
                    return item.dropobjects
                end
            end

			self.allHandBag[string.format( "%d-%d",mode_state, idx + 1)] = {
				item = targetItem,
                moveBlockSize = item.moveBlockSize
			}
			idx = idx + 1
			if idx >= MAX_COUNT then
				break
			end
		end
	end

end

local function createTopItemUi(self, showImage, showText, index)
	local layout = GUIWindowManager.instance:CreateGUIWindow1("Layout", "switchLayout_" .. index)
	layout:SetArea({0, (index - 1) * 80 + 20}, {0, 0}, {0, 50}, {1, 0})
	
	local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
	image:SetArea({0, 15}, {0, 9}, {0, 50}, {0, 50})
	image:SetImage(showImage)

	local imageBg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
	imageBg:SetArea({0, 5}, {0, 0}, {0, 70}, {0, 70})
	imageBg:SetVisible(false)
	imageBg:SetImage("set:mapEditToolbarImg.json image:select_status")

	self.TopSwitchBtnBgs[#self.TopSwitchBtnBgs + 1] = imageBg

	if index == 1 then
		imageBg:SetVisible(true)
		self.lastTopSwitchBtnBg = imageBg
	end

	layout:AddChildWindow(imageBg)
	layout:AddChildWindow(image)
	self.switchLayout:AddChildWindow(layout)

	self:subscribe(layout, UIEvent.EventWindowTouchUp, function()
		if not isCanClick then
			return
		end
		self:showItemInfoTip(Lang:toText(showText))
		CGame.instance:onEditorDataReport("click_change", "")
		self:switchState(index)
		Blockman.instance.gameSettings.isPopWindow = true
    end)
end

function M:initTopSwitchUi()
	self.switchLayout = self:child("Shortcut-SwitchLayout")
	self.switchLayout:SetVisible(false)
	for index, type in pairs(mapModeType) do
		createTopItemUi(self, type.icon, mapModeTip[index], index)
	end

	Lib.subscribeEvent(Event.EVENT_CLOSE_POP_WIN, function()
		if self.switchLayout:IsVisible() then
			self.switchLayout:SetVisible(false)
			Blockman.instance.gameSettings.isPopWindow = false
		end
	end)
	self.itemBagBtn:setBelongWhitelist(true)
	self.switchLayout:setBelongWhitelist(true)
end

function M:init()
    WinBase.init(self, "shortcuts_edit.json")
    self.itemBagBtn = self:child("Shortcut-ItemBagbtn")
    self.toggleInventoryBtn = self:child("Shortcut-ToggleInventoryButton")
    self.mode_state = 1
	self.allHandBag = {}
	self.lastTopSwitchBtnBg = nil
	self.TopSwitchBtnBgs = {}
    Blockman.instance.gameSettings.isPopWindow = true
    self.gridview = self:child("Shortcut-GridView")
    do
        self.gridview:InitConfig(15, 0, MAX_COUNT)
        self.gridview:HasItemHidden(false)
        self.gridview:SetMoveAble(false)
		self.gridview:SetAutoColumnCount(false)
		local function tick()
			self:initHandBagData()
			self:resetHandBag()
			return false
		end
		World.Timer(10, tick)
    end

	self:subscribe(self.toggleInventoryBtn, UIEvent.EventButtonClick, function()
		if not isCanClick then
			return
		end
        CGame.instance:onEditorDataReport("click_bag", "", 3)
		Lib.emitEvent(Event.EVENT_OPEN_PACK, self.mode_state, self._select_cell)
    end)

    local index = 1
    unifyProc(self, self.itemBagBtn, function()
		if not isCanClick then
			return
		end
		local switchLayoutShowState = self.switchLayout:IsVisible()
		self.switchLayout:SetVisible(not switchLayoutShowState)
		Blockman.instance.gameSettings.isPopWindow = not switchLayoutShowState
		self:showItemInfoTip("")
    end)

    Lib.subscribeEvent(Event.EVENT_EMPTY_STATE, function(flag)
		if flag then
			self:restoration()
			return
		end
		self:reset()
	end)

    Lib.subscribeEvent(Event.EVENT_PACK_SWAP_ITEM, function(swapItem)
		self.packSelectItem = swapItem
	end)

	Lib.subscribeEvent(Event.EVENT_PACK_CLOSE_PACK, function(cell)
		self.packSelectItem = nil
	end)

	Lib.subscribeEvent(Event.EVENT_CHANGE_MODE_STATE, function(mode_state)
		if self.mode_state ~= mode_state then
			self.mode_state = mode_state
			self:resetHandBag()
			handle_mp_editor_command("esc")
			Lib.emitEvent(Event.EVENT_EMPTY_STATE)
		end
		self.itemBagBtn:SetNormalImage(mapModeType[self.mode_state].changeImage)
		self.itemBagBtn:SetPushedImage(mapModeType[self.mode_state].changeImage)
		local curBg = self.TopSwitchBtnBgs[self.mode_state]
		curBg:SetVisible(true)
		self.lastTopSwitchBtnBg:SetVisible(false)
		self.lastTopSwitchBtnBg = curBg
		self.changeCell = nil
	end)

     Lib.subscribeEvent(Event.EVENT_NOVICE_GUIDE, function(indexType, isFinish)
        if indexType == 1 then
            if self.firstCell then
                self.firstCell:SetName("HandBag1")
	        end
        elseif indexType == 5 then
            if isGuide then
                self.itemBagBtn:SetName("ShortcutClick")
                isGuide = false
            end
        end
    end)

	Lib.subscribeEvent(Event.EVENT_SWAP_INVENTORY, function(pos, item)
		if self.changeCell then
			self.changeCell:receiver()._img_frame_1:SetImage("")
			self.changeCell:receiver():onClick(false)
			self.changeCell = nil
		end
		local rect = self.gridview:GetUnclippedOuterRect()
		local cellIndex = 0
		local leftPos = rect[1]
		if pos.x >= rect[1] and pos.x <= rect[3] and pos.y >= rect[2] and pos.y <= rect[4] then
			for i = 1, MAX_COUNT do
				leftPos = leftPos + 60
				if leftPos > pos.x then
					cellIndex = i
					break
				end
				leftPos = leftPos + 15
				if leftPos > pos.x then
					break
				end
			end
		end
		cellIndex = cellIndex - 1
		local flag = false
		if cellIndex >= 0 and cellIndex <= MAX_COUNT - 1 then
			self.packSelectItem = item
			self.changeCell = self.gridview:GetItem(cellIndex)
			if not item then
				local cellItem = self.changeCell:data("item")
				Lib.emitEvent(Event.EVENT_SWAP_INVENTORY_TIP, false, cellItem)
				self.changeCell:receiver()._img_frame_1:SetImage("set:map_edit_drag.json image:shortcuts")
				--self.changeCell:receiver():onClick(true, "set:map_edit_drag.json image:shortcuts")
				return
			end
			local _,isFindSameSlot = self:changeItem(self.changeCell, false)
            if self._select_cell and (self._select_cell:data("slot") == self.changeCell:data("slot") or self._select_cell:data("slot") == isFindSameSlot) then
				flag = true
			end
		end
		Lib.emitEvent(Event.EVENT_SWAP_INVENTORY_TIP, true)
		if self._select_cell then
			self._select_cell:receiver():onClick(true, "set:map_edit_mainVisibleBarSelected.json image:main_visiblebar_Selected")
			if flag then
				local moveBlockSize = UI:getWnd("mapEditItemBag"):getMoveBlockSize()
				local selectItem = self._select_cell:data("item")
				local params = nil
				if moveBlockSize then
					Lib.emitEvent(Event.EVENT_EDIT_ITEM_INFO, item:cfg(), moveBlockSize)
				end
				Lib.emitEvent(Event.EVENT_EDIT_ITEM_INFO, selectItem:cfg(), moveBlockSize)
				if selectItem:type() == "block" then  --block
					params = {mode_type = "Block", name = setting:id2name("block", selectItem:block_id()), icon = selectItem:icon()}
					--Me:setHandItem(item)
				elseif selectItem:type() == "item" then  --MONSTER
					params = {mode_type = "Item", name = selectItem:full_name(), cell = self._select_cell}
					--Me:setHandItem(item)
				elseif selectItem:type() == "entity" then
					params = {mode_type = "Entity", name = selectItem:full_name(), cell = self._select_cell}				
				end
				EditorModule:emitEvent("shortClick", selectItem)
				handle_mp_editor_command("set_palette", params)
			end
		end
	end)

	Lib.subscribeEvent(Event.EVENT_DRAGING_CELL, function(flag)
		isCanClick = flag
	end)
	self:initTopSwitchUi()
end

local function showDropobjects(cell, dropobjects)
	if cell and dropobjects and dropobjects.fullName then
		local cfg = setting:fetch(dropobjects.type or "entity", dropobjects.fullName)
		local icon = ResLoader:loadImage(cfg, "small.png")
		if icon then
			cell:receiver()._smallIcon:SetArea({0,0},{0,0},{0,20},{0,20})
			cell:receiver()._smallIcon:SetImage(icon)
			cell:receiver()._smallIcon:SetVisible(true)
		end
	elseif cell then
		cell:receiver()._smallIcon:SetVisible(false)
	end
end

function M:resetHandBag()

	local function setCellInfo(cell, slot)
		local itemData = self.allHandBag[string.format("%d-%d",self.mode_state, slot)]
		local item = itemData and itemData.item
		if not item then
            self.firstCell = (slot == 1) and cell or self.firstCell
			return
		end
		cell:setData("item", item)
		cell:setData("moveBlockSize", itemData.moveBlockSize)
		cell:invoke("ITEM_SLOTER", item)
        cell:receiver()._img_item:SetArea({0,0},{0,0},{0,55},{0,55})
		cell:SetName("item:"..item:full_name().. slot)
        if self.mode_state == enumStateType.MONSTER then
            if slot == 1 then
                cell:SetName("item:myplugin/big_turtle1")
            end
        end
		showDropobjects(cell, item.dropobjects and item:dropobjects())
        if slot == 1 and cell then
            self.firstCell = cell
        end
        
	end

	self.gridview:RemoveAllItems()
	self._slot = {}
	self._select_cell = nil
	for slot = 1, MAX_COUNT do
		local cell = fetchCell()
		cell:setData("slot", slot)
		setCellInfo(cell, slot)--mode_state == entity
		self:subscribe(cell, UIEvent.EventWindowClick, function()
			if not isCanClick then
				return
			end
            if slot == 1 then
                Lib.emitEvent(Event.EVENT_NOVICE_GUIDE, 6)
            end
			local moveBlockSize = cell:data("moveBlockSize")
			if self._select_cell then
				self._select_cell:receiver():onClick(false)
			end
			self._select_cell = cell
			self._select_cell:receiver():onClick(true)
			local resultCell = self:changeItem(self._select_cell, true)
			local item = resultCell:data("item")
			self:showItemTip(self._select_cell)
			if item then
				resultCell:receiver():onClick(true,"set:map_edit_mainVisibleBarSelected.json image:main_visiblebar_Selected")
				self._select_cell = resultCell
			end
			if not item then
				handle_mp_editor_command("esc")
				Lib.emitEvent(Event.EVENT_EMPTY_STATE)
				return
			end
			local params = nil
			if moveBlockSize then
				Lib.emitEvent(Event.EVENT_EDIT_ITEM_INFO, item:cfg(), moveBlockSize)
			end
			if item:type() == "block" then  --block
				params = {mode_type = "Block", name = setting:id2name("block", item:block_id()), icon = item:icon()}
				--Me:setHandItem(item)
			elseif item:type() == "item" then  --MONSTER
				params = {mode_type = "Item", name = item:full_name(), cell = resultCell}
				--Me:setHandItem(item)
			elseif item:type() == "entity" then
				params = {mode_type = "Entity", name = item:full_name(), cell = resultCell}				
			end
			
			handle_mp_editor_command("set_palette", params)
			EditorModule:emitEvent("shortClick", item)
			Lib.emitEvent(Event.EVENT_NOVICE_GUIDE,2)
			self.switchLayout:SetVisible(false)
			Blockman.instance.gameSettings.isPopWindow = false
		end)

		self.gridview:AddItem(cell)
		table.insert(self._slot, cell)
	end
end

function M:showItemTip(cell)
	if not cell or not cell:data("item") then
		return
	end
	local size = cell:data("moveBlockSize")
	local itemName = Lang:toText(cell:data("item"):getNameText())

    if size then
	    self:showItemInfoTip(string.format( "%s:%d * %d * %d",itemName,size[1], size[2], size[3]))
    else
        local item = cell:data("item")
        if not item then
            return
        end
	    self:showItemInfoTip(itemName)
    end
end

function M:showItemInfoTip(msg)
	local offsetY = self.switchLayout:IsVisible() and 85 or 0
    Lib.emitEvent(Event.EVENT_EDIT_INFORM_MAIN_WND, msg, offsetY)
end

function M:switchState(state)
    self.changeCell = nil
    Lib.emitEvent(Event.EVENT_CHANGE_MODE_STATE, state)
end

function M:isBlockState()
	return self.mode_state == 1 or self.mode_state == 2
end

function M:reset()
	if self._select_cell then
		self._last_select_cell = self._select_cell
		self._select_cell:receiver():onClick(false)
		self._select_cell = nil
	end
end

function M:restoration()
	if self._last_select_cell and self._last_select_cell:data("item") then
		self._select_cell = self._last_select_cell
		self._select_cell:receiver():onClick(true)
	end
end

function M:changeItem(select_cell, isReset)
	local function findSameItem(self, mianSelectCell, packSelectItem, ignoreIndex)
		local findType = "full_name"
		
		local findKey = packSelectItem:full_name()
		if packSelectItem.is_block and  packSelectItem:is_block() then
			findType = "block_id"
			findKey = packSelectItem:block_id()
		end
		local findkeyDropobjects = packSelectItem.dropobjects and packSelectItem:dropobjects()
		findkeyDropobjects = findkeyDropobjects and findkeyDropobjects.fullName
		for i = 1, MAX_COUNT do
			local itemData = self.allHandBag[string.format("%d-%d",self.mode_state, i)]
			local item = itemData and itemData.item
			if item then
				local resFunc = item[findType]
				local key = resFunc and resFunc(item)
				local keyDropobjects = item.dropobjects and item:dropobjects()
				keyDropobjects = keyDropobjects and keyDropobjects.fullName
				if key == findKey and findkeyDropobjects == keyDropobjects and i ~= ignoreIndex  then
					if not self.moveBlockSize or not itemData.moveBlockSize 
						or self.moveBlockSize[1] == itemData.moveBlockSize[1]
						and (self.moveBlockSize[2] == itemData.moveBlockSize[2]
						and self.moveBlockSize[3] == itemData.moveBlockSize[3]) then
							return i
					end
				end
			end
		end
	end
	local resultCell = select_cell
	local cell = select_cell
    local SameItemSlot = nil
	if cell and self.packSelectItem then
		self.moveBlockSize = UI:getWnd("mapEditItemBag"):getMoveBlockSize()
		SameItemSlot = findSameItem(self, cell, self.packSelectItem, cell:data("slot"))

		local tempSelectItem = cell:data("item")
		local tempSelectMoveBlockSize = cell:data("moveBlockSize")

		cell = self.gridview:GetItem(cell:data("slot") - 1)
		cell:setData("item", self.packSelectItem)
		showDropobjects(cell, self.packSelectItem.dropobjects and self.packSelectItem:dropobjects())
		cell:invoke("ITEM_SLOTER", self.packSelectItem)
		cell:setData("moveBlockSize", self.moveBlockSize)
        cell:receiver()._img_item:SetArea({0,0},{0,0},{0,55},{0,55})
		if isReset then
			cell:receiver():onClick(false)
		end
		self.allHandBag[string.format("%d-%d",self.mode_state, cell:data("slot"))] = {
			item = self.packSelectItem,
			moveBlockSize = self.moveBlockSize
		}
		if isReset then
			select_cell:receiver():onClick(false)
			select_cell = nil
		end
		if SameItemSlot then
			local wantSwapCell = self.gridview:GetItem(SameItemSlot - 1)
			if not tempSelectItem then
				wantSwapCell:invoke("RESET")
				wantSwapCell:receiver():onClick(false)
			end
			wantSwapCell:setData("item", tempSelectItem)
			wantSwapCell:setData("moveBlockSize", tempSelectMoveBlockSize)
			wantSwapCell:invoke("ITEM_SLOTER", tempSelectItem)
            wantSwapCell:receiver()._img_item:SetArea({0,0},{0,0},{0,55},{0,55})
			showDropobjects(wantSwapCell, tempSelectItem and tempSelectItem.dropobjects and tempSelectItem:dropobjects())
			self.allHandBag[string.format("%d-%d",self.mode_state, SameItemSlot)] = {
				item = tempSelectItem,
				moveBlockSize = tempSelectMoveBlockSize
			}
		end
        self:saveHandBag()
		if not self.moveBlockSize then
			self.packSelectItem = nil
		end
		if isReset then
			Lib.emitEvent(Event.EVENT_SELECTING_ITEM, self.moveBlockSize)
		end
	end
	return resultCell, SameItemSlot
end

function M:updateBag()
    local blocks = Clientsetting.getBlockList()
    local idx = 0
    for _, blockName in ipairs(blocks) do 
		local item = CreateItem("block", blockName)
		self:bagViewUpdateItem(item, idx)
		idx = idx + 1
		if idx >= MAX_COUNT then
			break
		end
		if self._select_cell then
		   Me:setHandItem(self._select_cell:data("item"))
		end
	end
end

function M:bagViewReset()
    for i = 0, self.gridview:GetItemCount() - 1 do
        local cell = self.gridview:GetItem(i)
        if cell then
            cell:setData("item")
            cell:invoke("RESET")
        end
    end
end

function M:bagViewUpdateItem(item, idx)
    local cell = self.gridview:GetItem(idx)
    cell:setData("item", item)
    cell:invoke("ITEM_SLOTER", item)
	cell:SetName("item:"..item:full_name())
end

function M:saveHandBag()
    local bagType = Clientsetting.getBagItemsList() or {"block", "special", "item", "entity", "moveBlock"}
    for key, mode_state in pairs(enumStateType) do
        
        local insertItems = {}
        for slot = 1, MAX_COUNT do
            
            local handItem = self.allHandBag[string.format( "%d-%d",mode_state, slot)]
            if handItem then
                local item = handItem.item
                if not item then
                    goto continue
                end
                local name = item:full_name()
                if item:type() == "block" then
                    name = setting:id2name("block", item:block_id())
                end
                table.insert(insertItems, {
                    name = name,
                    type = item:type(),
                    icon = not item:icon():find("block:") and item:icon() or nil,
                    dropobjects = item.dropobjects and item:dropobjects(),
					descTipInfo = item.descTipInfo,
					nameTipInfo = item.nameTipInfo,
                    moveBlockSize = handItem.moveBlockSize 
                })
                ::continue::
            end

        end
        customHandBagSetting[bagType[mode_state]] = insertItems
    end
end

function M:onClose()
end

function M:onOpen()
end

function M:onReload()
end

return M
