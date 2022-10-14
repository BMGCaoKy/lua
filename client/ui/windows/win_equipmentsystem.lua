local cell_pool = {}

local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell")
	end
	return ret
end

function M:init()
	local defaultPages = { Define.ENTITY_INTO_TYPE_PLAYER }
	self.showPages = World.cfg.equipmentSystemShowPage or defaultPages
	self.objID = Me.objID
	WinBase.init(self, "EquipmentSystem.json", true)
	self:initFriendBtn()
	self:initEntityWnd()
	self:initTrayInfo()
	self:initTopTabBtn()
	self:initBackpackWnd()
	self:initSureDestroyWnd()
	self:initSellWnd()
	Lib.subscribeEvent(Event.EVENT_PLAYER_ITEM_MODIFY, function() self:updateBag() end)
end

function M:onOpen(objID)
	local isMe = (objID == nil)
	WinBase.onOpen(self)
	self.wndBag:SetVisible(isMe)
	self.btnCloseInfoView:SetVisible(not isMe)
	self.btnAddFriend:SetVisible(not isMe)
	self.btnInviteFriend:SetVisible(not isMe)
	if isMe then
		self:updateBag()
	end
	self:attach(objID or Me.objID)
	self.viewInfoCache = {}
	self.entityCfgs = {}
	self.firstTabBtn:SetSelected(true)

	for i, v in ipairs(self.showPages) do
		self:resetEntityEquipment(v)
		self.equipInfoGrids[v]:SetVisible(false)
		self.specialEquipInfoGrids[v]:SetVisible(false)
	end
	self:queryEntityViewInfo()
	self.openArgs = table.pack(objID)
end

function M:onClose()
	self:resetSelectedCell()
	WinBase.onClose(self)
end

function M:attach(objID)
	if objID ~= self.objID then
		self.viewInfoCache = {}
	end
	self.objID = assert(objID)
end

function M:isMe()
	return self.objID == Me.objID
end

function M:initEntityWnd()
	self.pageContent = self:child("EquipmentSystem-Content")
	self.entityPages = {}
	self.entityActors = {}
	self.equipCells = {}
	self.cellCfgs = {}
	self.cellCfgs[Define.ENTITY_INTO_TYPE_PLAYER] = {
		{"1", "set:new_gui_material.json image:armor_type_helmet"},
		{"2", "set:new_gui_material.json image:armor_type_leggings"},
		{"3", "set:new_gui_material.json image:armor_type_chestplate"},
		{"4", "set:new_gui_material.json image:armor_type_boots"},
	}
	self.equipCells[Define.ENTITY_INTO_TYPE_PLAYER] = {}
	self.cellCfgs[Define.ENTITY_INTO_TYPE_PET_1] = {
		{"5", "set:ship_assets.json image:attackdevice"},
		{"6", "set:ship_assets.json image:flag"},
		{"7", "set:ship_assets.json image:install_driver"},
		{"8", "set:ship_assets.json image:wing"},
	}
	self.equipCells[Define.ENTITY_INTO_TYPE_PET_1] = {}

	self.specialEquipCells = {}
	self.equipTabBtns = {}
	self.specialEquipTabBtns = {}
	self.lastTab = {}
	self.equipInfoGrids = {}
	self.specialEquipInfoGrids = {}
	local pageCfg = "EquipmentSystem_Entity.json"

	for index, entityType in ipairs(self.showPages) do
		self:initEntityPage(entityType, pageCfg, index)
	end
end

function M:getShowEntity(entityType)
	local entity = Me
	if entityType ~= Define.ENTITY_INTO_TYPE_PLAYER then
		entity = Me:getPet(entityType - 1)
	end
	return entity
end

function M:initTrayInfo()
	self.trayTypes = {}
	for _, entityType in pairs(self.showPages) do
		self.trayTypes[entityType] = {"equip", "imprint"}
	end
end

function M:initFriendBtn()
	local function showOpenSoon()
		Lib.emitEvent(Event.EVENT_CENTER_TIPS, 40, nil, nil, { "open_soon" })
	end

	local btnAddFriend = self:child("EquipmentSystem-AddFriendBtn")
	btnAddFriend:SetText(Lang:toText("add_friends_btn"))
	self:subscribe(btnAddFriend, UIEvent.EventButtonClick, showOpenSoon)

	local inviteFriend = self:child("EquipmentSystem-InviteFriendBtn")
	inviteFriend:SetText(Lang:toText("group_invite"))
	self:subscribe(inviteFriend, UIEvent.EventButtonClick, showOpenSoon)

	self.btnAddFriend = btnAddFriend
	self.btnInviteFriend = inviteFriend

	local btnClose = self:child("EquipmentSystem-Close")
	self:subscribe(btnClose, UIEvent.EventButtonClick, function() UI:closeWnd(self) end)
	self.btnCloseInfoView = btnClose
end

function M:initTopTabBtn()
	local function switchView(button, entityType)
		if not button:IsSelected() then
			return
		end
		self:resetSelectedCell()
		local lastType = self.lastPageType
		local entityPages = self.entityPages
		local lastPage = entityPages[lastType]
		if lastPage then
			lastPage:SetVisible(false)
		end
		entityPages[entityType]:SetVisible(true)
		self.lastPageType = entityType
		self:queryEntityViewInfo(entityType)
		self.equipTabBtns[entityType]:SetSelected(true)
	end

	local topTabCfg = {
		[Define.ENTITY_INTO_TYPE_PLAYER] = "EquipmentSystem-Btn_1",
		[Define.ENTITY_INTO_TYPE_PET_1] = "EquipmentSystem-Btn_2",
	}

	for index, name in pairs(topTabCfg) do
		self:child(name):SetVisible(false)
	end

	for index, entityType in ipairs(self.showPages) do
		local btn = self:child(topTabCfg[entityType])
		btn:SetVisible(true)
		btn:SetXPosition({ 0, 20 + (index - 1) * 80})
		self:subscribe(btn, UIEvent.EventRadioStateChanged, function() switchView(btn, entityType) end)
		if index == 1 then
			self.firstTabBtn = btn
		end
	end
end

function M:setContentValue(infoValues, cfg)
	if not infoValues then
		return
	end
    local titles = {}
    local values = {}
	for i, info in ipairs(cfg) do
		local value = infoValues[i]
		if not info.langKey then
			value = tostring(value)
		elseif type(info.langKey) ~= "string" then
			value = Lang:toText(value)
		elseif type(value) ~= "table" then
			value = Lang:toText({info.langKey, value})
		else
			value = Lang:toText({info.langKey, table.unpack(value, 1, #info.value)})
		end
		titles[i] = Lang:toText(info.name)
        values[i] = value
	end
	local ret = {
		titles = titles,
		values = values
	}
	return ret
end

local function fetchInfoItem(title, value, width, height)
	local item = GUIWindowManager.instance:LoadWindowFromJSON("Text_Templte.json")
	item:SetWidth(width)
	item:SetHeight(height)
	if value == "nil" then
		value = ""
	end
	item:GetChildByIndex(0):SetText(Lang:toText(title))
	item:GetChildByIndex(1):SetText(Lang:toText(value))
	return item
end

function M:setInfoGrid(infoGrid, info)
	local titles = info.titles
	local values = info.values
	if not titles then
		return
	end
	infoGrid:RemoveAllItems()
	local width = { 0, infoGrid:GetPixelSize().x / 2}
	local height = { 0, infoGrid:GetPixelSize().y / 4}
	for i, title in ipairs(titles) do
		infoGrid:AddItem(fetchInfoItem(title, values[i], width, height))
	end
	infoGrid:SetVisible(true)
end

function M:resetEquipCells(cells)
	for i, cell in pairs(cells) do
		local sloter = cell.sloter
		sloter:invoke("RESET")
		sloter:invoke("SHOW_FRAME", false)
		sloter:SetName("")
		local icon = cell.baseIcon
		if icon then
			icon:SetVisible(true)
		end
	end
end

function M:setEquipCells(cells, data)
	for k, v in pairs(data) do
		local cell = cells[k]
		local slot, fullName = v.slot, v.fullName
		if cell and slot and fullName then
			local sloter = cell.sloter
			sloter:invoke("ITEM_FULLNAME", fullName)
			sloter:setData("item_pos", {tid = v.tid, slot = slot})
			sloter:SetName("equip:"..fullName)
			local icon = cell.baseIcon
			if icon then
				icon:SetVisible(false)
			end
		end
	end
end

function M:resetEntityEquipment(entityType)
	self:resetEquipCells(self.equipCells[entityType])
	local actor = self.entityActors[entityType]
	actor.baseImage:SetVisible(false)
end

function M:showEntityEquipment(info, entityType)
local cells = self.equipCells[entityType]
	local entityActor = self.entityActors[entityType]
	local image = entityActor.baseImage
	local actor = entityActor.model
	self:resetEntityEquipment(entityType)
	actor:UpdateSelf(1)
	actor:SetActor1(info.actor, "idle")
	local cfg = Entity.GetCfg(self.entityCfgs[entityType])
	local showModelCfg = cfg.showModelCfg
	image:SetImage(showModelCfg and showModelCfg.baseImage or "")
	image:SetVisible(true)
	if showModelCfg then
		local scale = showModelCfg.scale or 1
		actor:SetActorScale(scale / 2)
		local property = showModelCfg.property or {}
		for _, v in pairs(property) do
			actor:SetProperty(v.name, v.value)
		end
	end

	local skin = EntityClient.processSkin(info.actor, info.skin)
	for k, v in pairs(skin) do
		actor:UseBodyPart(k, v)
	end
	self:setEquipCells(cells, info.equip)
end

function M:initEntityCell(cells, entityType)
	local function cellOnClick(cell, index)
		if not self:isMe() then
			return
		end
		local item = cell:data("item_pos")
		if not item then
			return
		end
		local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.BAG)[1]
		local tid, bag = trayArray.tid, trayArray.tray
		local slot = bag:find_free()
		if not slot then
			return
		end
		local function onTakeOff(ok)
			if ok then
				cell:invoke("RESET_CONTENT")
				cell:setData("item_pos", nil)
				self:queryEntityViewInfo(nil, true)
			end
		end
		if self.lastPageType == Define.ENTITY_INTO_TYPE_PLAYER then
			Me:switchItem(item.tid, item.slot, tid, slot, onTakeOff)
		else
			Me:petTakeOff(self.lastPageType - 1, item.tid, item.slot, onTakeOff)
		end
	end
	for index, cell in pairs(cells) do
		local sloter = cell.sloter
		self:subscribe(sloter, UIEvent.EventWindowClick, function()
			cellOnClick(sloter, index)
		end)
	end
end

function M:initCell(page, cellCfg, cells)
	local equipCellsCfg = {
		{ "EquipmentSystem_Entity-Slot_1", "EquipmentSystem_Entity-Icon_1" },
		{ "EquipmentSystem_Entity-Slot_4", "EquipmentSystem_Entity-Icon_4" },
		{ "EquipmentSystem_Entity-Slot_2", "EquipmentSystem_Entity-Icon_2" },
		{ "EquipmentSystem_Entity-Slot_5", "EquipmentSystem_Entity-Icon_5" },
		{ "EquipmentSystem_Entity-Slot_3", "EquipmentSystem_Entity-Icon_3" },
		{ "EquipmentSystem_Entity-Slot_6", "EquipmentSystem_Entity-Icon_6" },
	}
	for i, cfg in ipairs(cellCfg) do
		local index = tonumber(cfg[1])
		local tempCell = fetchCell()
		tempCell:SetWidth({1, 0})
		tempCell:SetHeight({1, 0})
		page:child(equipCellsCfg[i][1]):AddChildWindow(tempCell)
		local icon = page:child(equipCellsCfg[i][2])
		icon:SetImage(cfg[2])
		cells[index] = { sloter = tempCell, baseIcon = icon }
	end
end

function M:initInfoGrid(textGrid, columnNums)
	textGrid:InitConfig(0, 0, columnNums)
	textGrid:SetAutoColumnCount(false)
	textGrid:HasItemHidden(false)
	textGrid:SetMoveAble(false)
end

function M:initEquipmentTab(entityType)
	local page = self.entityPages[entityType]
	local cellCfg = self.cellCfgs[entityType]
	local cells = self.equipCells[entityType]
	self:initCell(page, cellCfg, cells)
	self:initEntityCell(cells, entityType)
	self.entityActors[entityType] = {
		model = page:child("EquipmentSystem_Entity-Actor"),
		baseImage = page:child("EquipmentSystem_Entity-BaseImage")
	}
	local tabEquipment = page:child("EquipmentSystem_Entity-TabView-Equipment")
	local btnEquipment = page:child("EquipmentSystem_Entity-Btn-Equipment")
    btnEquipment:GetChildByIndex(1):SetText(Lang:toText("btnEquipmentText"))
	btnEquipment:SetGroupID(entityType)
	self:subscribe(btnEquipment, UIEvent.EventRadioStateChanged, function()
		self:switchTabView(btnEquipment, tabEquipment, entityType)
		self.curEquipTabType = 1
	end)
	local infoGrid = page:child("EquipmentSystem_Info-Equipment")
	self:initInfoGrid(infoGrid, 2)
	self.equipInfoGrids[entityType] = infoGrid
	self.equipTabBtns[entityType] = btnEquipment
end

function M:initImprintTab(entityType)
	local page = self.entityPages[entityType]
	local tabImprint = page:child("EquipmentSystem_Entity-TabView-Imprint")
	local btnImprint = page:child("EquipmentSystem_Entity-Btn-Imprint")
    btnImprint:GetChildByIndex(0):SetText(Lang:toText("btnImprintText"))
	btnImprint:SetGroupID(entityType)
	self:subscribe(btnImprint, UIEvent.EventRadioStateChanged, function()
		self:switchTabView(btnImprint, tabImprint, entityType)
		self.curEquipTabType = 2
	end)
	local infoGrid = page:child("EquipmentSystem_Info-Imprint")
	self:initInfoGrid(infoGrid, 2)
	self.specialEquipInfoGrids[entityType] = infoGrid
	self.specialEquipTabBtns[entityType] = btnImprint
	self.lastTab[entityType] = tabImprint
end

function M:resetImprintView(traysCfgs, entityType)
	local function fetchTitleItem(name)
		local titleItem = GUIWindowManager.instance:CreateGUIWindow1("StaticText")
		titleItem:SetArea({ 0, 0 }, { 0, 5 }, { 1, 0}, { 0, 30 })
		titleItem:SetWordWrap(true)
		titleItem:SetText(Lang:toText(name))
		return titleItem
	end
	local function fetchGridView(height)
		local gv = GUIWindowManager.instance:CreateGUIWindow1("GridView")
		gv:SetArea({ 0, 0 }, { 0, 0 }, { 1, -2}, { 0, height })
		gv:InitConfig(0, 0, 7)
		gv:SetHorizontalAlignment(1)
		gv:HasItemHidden(false)
		gv:SetMoveAble(true)
		return gv
	end
	local function fetchCellItem(size)
		local cell = fetchCell()
		cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, size }, { 0, size})
		cell:invoke("SHOW_LOCKED", true)
		return cell
	end
	local page = self.entityPages[entityType]
	local containter = page:child("EquipmentSystem_Entity-Imprint-Containter")
	containter:ClearAllItem()
	local cellSize = (containter:GetPixelSize().x - 2) / 7
	for _, cfg in pairs(traysCfgs) do
		containter:AddItem(fetchTitleItem(cfg.showTitle))
		local gv = fetchGridView(cellSize * 2)
		gv:SetMoveByParent(true)
		containter:AddItem(gv)
		local cells = {}
		for j = 1, cfg.maxCap do
			local cell = fetchCellItem(cellSize)
			gv:AddItem(cell)
			cells[#cells + 1] = { sloter = cell }
		end
		self.specialEquipCells[cfg.type] = cells
		self:initEntityCell(cells, entityType)
	end
end

function M:showEntityImprint(info, entityType)
	local traysCfgs = {}
	for _, cfg in ipairs(Entity.GetCfg(self.entityCfgs[entityType]).trays or {}) do
		if cfg.class == Define.TRAY_CLASS_IMPRINT then
			traysCfgs[#traysCfgs + 1] = cfg
		end
	end
	if not next(traysCfgs) then
		self.specialEquipTabBtns[entityType]:SetVisible(false)
		return
	end
	self:resetImprintView(traysCfgs, entityType)
	local imprint = info.imprint
	local trays = imprint.trays
	for trayType, tray in pairs(trays) do
		local cells = self.specialEquipCells[trayType]
		for i = 1, tray.capacity do
			cells[i].sloter:invoke("SHOW_LOCKED", false)
		end
		local imprints = tray.imprints
		if next(imprints) then
			local tid = tray.tid
			for i, data in pairs(imprints) do
				local cell = cells[i].sloter
				local item_pos = cell:data("item_pos")
				cell:invoke("ITEM_FULLNAME", data.fullName)
				cell:setData("item_pos", {tid = tid, slot = data.slot})
			end
		end
	end
end

function M:queryEntityViewInfo(entityType, ignoreCache)
	if not entityType then
		entityType = self.lastPageType or self.showPages[1]
	end
	local function handleViewInfo(info)
		self.viewInfoCache[entityType] = info
		if not info then
			self.specialEquipTabBtns[entityType]:SetVisible(false)
			return
		end
		info.updateTime = os.time()
		self.entityCfgs[entityType] = info.cfg
		self:showEntityEquipment(info, entityType)
		self:showEntityImprint(info, entityType)
		local cfg = Entity.GetCfg(info.cfg)
		local page = self.entityPages[entityType]
		if info.values then
			local equipmentInfo = self:setContentValue(info.values, cfg.infoValues or {})
			self:setInfoGrid(self.equipInfoGrids[entityType], equipmentInfo)
		end
		if info.imprint then
			local imprintInfo = self:setContentValue(info.imprint.values, cfg.imprintValues or {})
			self:setInfoGrid(self.specialEquipInfoGrids[entityType], imprintInfo)
		end
	end
	local cache = self.viewInfoCache[entityType]
	if not ignoreCache and cache and cache.updateTime >= os.time() - 3 then	-- cache 3s
		handleViewInfo(cache)
		return
	end
	Me:sendPacket({
		pid = "QueryEntityViewInfo",
		objID = assert(self.objID),
		entityType = entityType,
	}, handleViewInfo)
end

function M:switchTabView(button, showView, entityType)
	if not button:IsSelected() then
		return
	end
	self:resetSelectedCell()
	local lastTab = self.lastTab[entityType]
	if lastTab then
		lastTab:SetVisible(false)
	end
	showView:SetVisible(true)
	self.lastTab[entityType] = showView
end

function M:initEntityPage(entityType, name, index)
	local page = GUIWindowManager.instance:LoadWindowFromJSON(name)
	self.entityPages[entityType] = page
	self.pageContent:AddChildWindow(page)
	self:initEquipmentTab(entityType)
	self:initImprintTab(entityType)
	page:SetVisible(false)
end

local sellSloter = nil
local itemAllCount = 0
local sellCount = 1
local sellAmount = 0
local curItemCost = 0

function M:resetSelectedCell(newCell)
	local curCell = self.selectedCell
	if curCell then
		if curCell == newCell then
			return
		end
		curCell:receiver():onClick(false)
		local newId = newCell and newCell:data("index")
		local curId = curCell:data("index")
		if newId then
			if ((newId > 0 and newId < 10) and (curId > 9 and curId < 55)) or
			   ((newId > 9 and newId < 55) and (curId > 0 and curId < 10)) or
				((newId > 0 and newId < 10) and (curId > 0 and curId < 10)) then
				local curCellSloter = curCell:data("sloter")
				local newCellSloter = newCell:data("sloter")
				if curCellSloter and (not curCellSloter:null()) and newCellSloter and (not newCellSloter:null()) then
					Me:switchItem(newCellSloter:tid(), newCellSloter:slot(), curCellSloter:tid(), curCellSloter:slot())
					self.selectedCell = nil
					return
				end
			end
		end
	end
	self.selectedCell = newCell or nil
	if newCell then
		newCell:receiver():onClick(true)
	else
		self:clearItemDetailView()
	end
	return newCell
end

function M:initSellWnd()
	local wndSell = GUIWindowManager.instance:LoadWindowFromJSON("Sell.json")
	self:root():AddChildWindow(wndSell)
	wndSell:child("Sell-sell_text"):SetText(Lang:toText("bag_sell"))
	wndSell:child("Sell-sell_number"):SetText(Lang:toText("allsell"))
	wndSell:child("Sell-sell_allmoney"):SetText(Lang:toText("allsellmoney"))


	local btnSellSure = wndSell:child("Sell-sell_button")
	btnSellSure:SetText(Lang:toText("sure"))


	local btnSellCancel = wndSell:child("Sell-cancel_button")
	btnSellCancel:SetText(Lang:toText("cancel"))

	local btnAdd = wndSell:child("Sell-add_numbtn")
	local btnSub = wndSell:child("Sell-sub_numbtn")
	local textSellCount = wndSell:child("Sell-show_sellnumber")
	local textSellAmount = wndSell:child("Sell-showsell_moneynumber")
	local btnCloseWnd = wndSell:child("Sell-close_sell_button")


	wndSell:SetVisible(false)


	local function changeSellCount(addNumber)
        if sellCount + addNumber < 1 or sellCount + addNumber > itemAllCount then
            return
        end
		sellCount = sellCount + addNumber
		if 1 <= sellCount and sellCount <= itemAllCount then
			textSellCount:SetText(tostring(sellCount))
			sellAmount = curItemCost * sellCount
			textSellAmount:SetText(tostring(sellAmount))
		end
	end
	self:subscribe(btnAdd, UIEvent.EventButtonClick, function() changeSellCount(1) end)
	self:subscribe(btnSub, UIEvent.EventButtonClick, function() changeSellCount(-1) end)
	self:subscribe(btnSellSure, UIEvent.EventButtonClick, function()
		local sellSloter = self.sellSloter
		if sellSloter and sellCount > 0 then
			Me:sendPacket({ pid = "SellItem", objID = Me.objID, tid = sellSloter:tid(),
							slot = sellSloter:slot(), item_num = sellCount,  money = sellAmount })
		end
		self:resetSelectedCell()
		wndSell:SetVisible(false)
	end)


	self:subscribe(btnCloseWnd, UIEvent.EventButtonClick, function() wndSell:SetVisible(false) end)
	self:subscribe(btnSellCancel, UIEvent.EventButtonClick, function() wndSell:SetVisible(false) end)
	self:subscribe(self.btnSale, UIEvent.EventButtonClick, function()
        sellCount = 1
		textSellCount:SetText(tostring(sellCount))
		textSellAmount:SetText(tostring(curItemCost * sellCount))
		wndSell:SetVisible(true)
		local curCell = self.selectedCell
		if curCell then
			local sellSloter = curCell:data("sloter")
			if sellSloter then
				itemAllCount = sellSloter:stack_count() or 0
                self.sellSloter = sellSloter
			end
		end
	end)
end


function M:initSureDestroyWnd()
	local wndSureDestroy = self:child("EquipmentSystem-sureDestroy")
	local btnCloseWnd = self:child("EquipmentSystem-closeWnd")
	local btnSureDestroy = self:child("EquipmentSystem-suredestroy")
	local btnCancelDestroy = self:child("EquipmentSystem-canceldestroy")
	self:child("EquipmentSystem-NoticeText"):SetText(Lang:toText("sure_destroy_tip"))
	btnSureDestroy:SetText(Lang:toText("sure"))
	btnCancelDestroy:SetText(Lang:toText("cancel"))

	local function setCurWndVisiable(isOpen)
		wndSureDestroy:SetVisible(isOpen)
	end
	self:subscribe(self.btnDiscard, UIEvent.EventButtonClick, function()
		self:clearItemDetailView()
		setCurWndVisiable(true)
	end)

	self:subscribe(btnSureDestroy, UIEvent.EventButtonClick, function()
		local curCell = self.selectedCell
		local sloter = curCell:data("sloter")
		if sloter then
			Me:sendPacket({ pid = "DeleteItem", objID = Me.objID,
							bag = sloter:tid(), slot = sloter:slot() })
		end
		self:resetSelectedCell()
		setCurWndVisiable(false)
	end)
	self:subscribe(btnCancelDestroy, UIEvent.EventButtonClick, function() setCurWndVisiable(false) end)
	self:subscribe(btnCloseWnd, UIEvent.EventButtonClick, function() setCurWndVisiable(false) end)
end

function M:onClickEquipItem()
	local sloter = self.selectedCell:data("sloter")
	if sloter:null() then
		return
	end
	local function onEquipItem(ok)
		if ok then
			self:queryEntityViewInfo(nil, true)
			self:resetSelectedCell()
		end
	end
	local tid, slot = self:getEquipableTraySlot(sloter)
	if not tid then
		return
	elseif self.lastPageType == Define.ENTITY_INTO_TYPE_PLAYER then
		Me:switchItem(sloter:tid(), sloter:slot(), tid, slot, onEquipItem)
	else
		Me:petPutOn(sloter:tid(), sloter:slot(), self.lastPageType - 1, onEquipItem)
	end
end

function M:initCellGridView()
	local gvBag = self:child("EquipmentSystem-Item_information")
	self.gvBag = gvBag
	gvBag:InitConfig(0, 0, 9)
	gvBag:HasItemHidden(false)
	gvBag:SetMoveAble(false)
	local newSize = gvBag:GetPixelSize().y / 6
	for i = 1, 54 do
		local cell = fetchCell()
		cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, newSize }, { 0, newSize})
		cell:setData("index", i)
		gvBag:AddItem(cell)
	end
end


function M:setBagFilter()
	local filterCfgs = {
		{"all", "EquipmentSystem-Btn_3", nil},
		{"equip6", "EquipmentSystem-Btn_4", "6"},
		{"equip5", "EquipmentSystem-Btn_5", "5"},
		{"equip8", "EquipmentSystem-Btn_6", "8"},
		{"equip7", "EquipmentSystem-Btn_7", "7"},
		{"other", "EquipmentSystem-Btn_8", nil},
	}
	local pageBag = {nil, nil, nil, nil, nil, nil}
	for i = 1, #filterCfgs do
		local cfg = filterCfgs[i]
		local index = tonumber(cfg[3])
		local page = {
			name = cfg[1],
			trigger = self:child(cfg[2]),
			filter = index and function(item) return item:tray_type()[index] end or nil
		}
		pageBag[i] = page
	end


	pageBag[6].filter = function(item)
							local tray = item:tray_type()
							return not tray[Define.TRAY_TYPE.EQUIP_5] and
									not tray[Define.TRAY_TYPE.EQUIP_6] and
									not tray[Define.TRAY_TYPE.EQUIP_7] and
									not tray[Define.TRAY_TYPE.EQUIP_8]
							end
	self.pageBag =pageBag
	for pageIndex, page in ipairs(pageBag) do
		self:subscribe(page.trigger, UIEvent.EventRadioStateChanged, function()
			if page.trigger:IsSelected() then
				self.selectedPage = pageIndex
				self:updateBag()
			end
		end)
	end
	pageBag[1].trigger:SetSelected(true)
end


function M:initBackpackWnd()
	self.wndBag = self:child("EquipmentSystem-Backpack")
	self.selectedPage = 1

	self:initCellGridView()

	local btnEquip = self:child("EquipmentSystem-zhuangbei")
	btnEquip:SetText(Lang:toText("bag_equip"))

	self:subscribe(btnEquip, UIEvent.EventButtonClick, function() self:onClickEquipItem() end)
	self.btnEquip = btnEquip

	local btnSale = self:child("EquipmentSystem-sell")
	btnSale:SetText(Lang:toText("bag_sell"))
	self.btnSale = btnSale

	local btnDiscard = self:child("EquipmentSystem-destroy")
	btnDiscard:SetText(Lang:toText("bag_destroy"))
	self.btnDiscard = btnDiscard

	local btnClose = self:child("EquipmentSystem-BpClose")
	self:subscribe(btnClose, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
        self:child("EquipmentSystem-sureDestroy"):SetVisible(false)
    end)
	self.textItemIntro = self:child("EquipmentSystem-item_introduce")

	self:setBagFilter()
end


function M:updateBag()
	self:resetBagView()
	local curPage = self.selectedPage
	local pageData = self.pageBag[curPage]
	assert(pageData, string.format("page is invalid: %s", curPage))
	local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.BAG)
    local idx = 0
	for _, element in pairs(trayArray) do
		local tid, tray = element.tid, element.tray
		local items = tray:query_items(pageData.filter)
		for slot, item in pairs(items) do
			self:updateItemView(Item.CreateSlotItem(Me, tid, slot), idx)
            idx = idx + 1
		end
	end

	for i = idx, 53 do
		self:updateItemView(nil, i)
	end
end


function M:clearItemDetailView()
	self.textItemIntro:SetText("")
	self.btnSale:SetVisible(false)
	self.btnDiscard:SetVisible(false)
	self.btnEquip:SetVisible(false)
end


function M:resetBagView()
	self:clearItemDetailView()
	local gvBag = self.gvBag
    for i = 0, gvBag:GetItemCount() - 1 do
        local cell = gvBag:GetItem(i)
        if cell then
			cell:setData("sloter")
			cell:invoke("RESET")
			cell:SetName("")
			self:unsubscribe(cell)
        end
    end
end

function M:updateItemView(sloter, idx)
    local cell = self.gvBag:GetItem(idx)
    assert(cell)
	if sloter then
		cell:setData("sloter", sloter)
		cell:invoke("ITEM_SLOTER", sloter)
		cell:SetName("item:"..sloter:full_name())
	end
	local function onClickCurItem(cell)
		self:resetSelectedCell(cell)
		if not sloter then
			self:clearItemDetailView()
			return
		end
		if sloter:null() then
			return
		end
		local curCfg = sloter:cfg()
		curItemCost = curCfg.itemcost or 0
		self.textItemIntro:SetText(Lang:toText(curCfg.itemintroduction or ""))
		self.btnSale:SetVisible(curCfg.cansell and true or false)
		self.btnDiscard:SetVisible(curCfg.candestroy and true or false)
		local canEquip = curCfg.tray and true
		if canEquip then
			self.btnEquip:SetEnabled(self:getEquipableTraySlot(sloter) and true or false)
		end
		self.btnEquip:SetVisible(canEquip)
	end
	self:subscribe(cell, UIEvent.EventWindowClick, function() onClickCurItem(cell) end)
end

function M:getEquipableTraySlot(sloter)
	if not sloter or sloter:null() then
		return
	end
	local viewInfo = self.viewInfoCache[self.lastPageType]
	if not viewInfo then
		return
	end
	local trayClass = self.trayTypes[self.lastPageType][self.curEquipTabType]
	local types = sloter:data():tray_type()
	if trayClass == "equip" then
		for t, data in pairs(viewInfo.equip or {}) do
			if types[t] then
				return data.tid, 1
			end
		end
	elseif trayClass == "imprint" then
		local imprintData = viewInfo.imprint or {}
		for t, data in pairs(imprintData.trays or {}) do
			if types[t] and #data.imprints < data.capacity then
				local slots = {}
				for _, info in pairs(data.imprints) do
					slots[info.slot] = true
				end
				for i = 1, data.capacity do
					if not slots[i] then
						return data.tid, i
					end
				end
			end
		end
	end
	return nil
end

return M
