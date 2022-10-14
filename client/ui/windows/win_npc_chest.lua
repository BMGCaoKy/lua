local ROW_SIZE = 9
local CELL_COUNT = 54
local chestSwitchItemInterval = World.cfg.chestSwitchItemInterval or 5
local chestSwitchItemAnimationTime = World.cfg.chestSwitchItemAnimationTime or 5
local bagCapacity = World.cfg.bagCap or 9
local handBagCapacity = World.cfg.handBagCap or 9

local trayType = {
	HAND_BAG = "HAND_BAG",
	BAG = "BAG",
	CHEST = "CHEST",
}

local function subscribeEvents(self)
	Lib.subscribeEvent(Event.EVENT_PLAYER_ITEM_MODIFY, self.updateBagView, self)
	self:subscribe(self:child("Chest-Btn-Close"), UIEvent.EventButtonClick, function ()
		UI:closeWnd(self)
	end)
end

function M:initCellsPool()
	local cellList = {}
	local cellUseList = {}
	for i = 1, 20 do
		local item = UIMgr:new_widget("cell")
		self:root():AddChildWindow(item)
		item:SetVisible(false)
		cellList[i] = item
		cellUseList[i] = false
	end
	self.cellList = cellList
	self.cellUseList = cellUseList
end

function M:init()
	WinBase.init(self, "NpcChest.json", true)
	self.initChestCellsDone = false
	self.initBagCellsDone = false
	self.itemCellList = {}
	self:initPlayerTrayWnd()
	self:initChestWnd()
	self:initCellsPool()
	subscribeEvents(self)
end

function M:onOpen(objID, regId)
	self.objID = objID
	self.regId = regId
	self:updateHandBagView()
	self:updateBagView()
	self:updateChestView()
end

function M:onClose()
	if not self.regId then
		return
	end
	Me:doCallBack("NpcChest", "closeEvent", self.regId)
	self.regId = nil
end

function M:initPlayerTrayWnd()
	self:child("Chest-Content-Inventory-Title"):SetText(Lang:toText("chest_content_inventory"))
	self.gvBag = self:child("Chest-Content-Backpack-GridView")
	self:initCellPage(self.gvBag, trayType.HAND_BAG, handBagCapacity)
	self:initCellPage(self.gvBag, trayType.BAG, bagCapacity)
end

function M:initChestWnd()
	self:child("Chest-Content-Chest-Title"):SetText(Lang:toText("chest_content_chest"))
	self.gvChest = self:child("Chest-Content-Chest-GridView")
	self:initCellPage(self.gvChest, trayType.CHEST)
end

function M:updateBagView()
	if not UI:isOpen(self) then
		return
	end
	if not self.initBagCellsDone then
		return
	end
	if self.dontUpdateBagView then
		return
	end
	local tray = Me:tray():query_trays({Define.TRAY_TYPE.BAG})[1]
	local tid, bag = tray.tid, tray.tray
	local gridView = self.gvBag
	for i = 1, bagCapacity do
		self:setItemAction(gridView:GetItem(i + handBagCapacity - 1), bag:query_items()[i], trayType.BAG, tid)
	end
end

function M:updateHandBagView()
	if not UI:isOpen(self) then
		return
	end
	if not self.initHandBagCellsDone then
		return
	end
	if self.dontUpdateBagView then
		return
	end
	local tray = Me:tray():query_trays({Define.TRAY_TYPE.HAND_BAG})[1]
	local tid, bag = tray.tid, tray.tray
	local gridView = self.gvBag
	for i = 1, handBagCapacity do
		self:setItemAction(gridView:GetItem(i - 1), bag:query_items()[i], trayType.HAND_BAG, tid)
	end
end

function M:updateChestView()
	if not UI:isOpen(self) then
		return
	end
	if not self.initChestCellsDone then
		return
	end
	if not self.objID then
		return
	end
	self:queryChestTray()
end

function M:queryChestTray()
	local packet = {
		pid = "QueryChestTray",
		objID = self.objID
	}

	Me:sendPacket(packet, function (items)
		if not UI:isOpen(self) then
			return
		end
		local gridView = self.gvChest
		for i = 1, CELL_COUNT do
			self:setItemAction(gridView:GetItem(i - 1), items[i] and Item.DeseriItem(items[i]), trayType.CHEST, 1)
		end
	end)
end

local function stopTimer(cell)
	local stopTimer = cell:data("stopTimer")
	if stopTimer then
		stopTimer()
		cell:setData("stopTimer")
	end
end

local function onClickItem(self, cell, slot)
	local sloter = cell:data("sloter")
	if not sloter then
		return
	end

	local type = cell:data("type")
	local isPutIntoChest = not (type == trayType.CHEST)

	local slotInfo = {
		fullName = sloter:full_name(),
		blockId = sloter:is_block() and sloter:block_id()
	}

	local packet = {
		pid = "SwitchNpcChestItem",
		dropSlot = slot,
		dropTid = cell:data("tid"),
		dropCount = 1,
		isPutIntoChest = isPutIntoChest,
		objID = self.objID
	}
	self.dontUpdateBagView = true
	Me:sendPacket(packet, function (ok, settleSlot, settleTid)
		if not ok then
			self.inLongTouch = false
			stopTimer(cell)
			self.dontUpdateBagView = false
			self:updateHandBagView()
			self:updateBagView()
			self:updateChestView()
			return
		end
		self:playAnimation(isPutIntoChest, type, slot, settleSlot, settleTid, slotInfo)
	end)
end

local function subscribeEvent(self, cell, slot)
	self:subscribe(cell, UIEvent.EventWindowClick, onClickItem, self, cell, slot)
	self:subscribe(cell, UIEvent.EventWindowLongTouchStart, function()
		self.inLongTouch = true
		cell:setData("stopTimer", World.Timer(chestSwitchItemInterval, function()
			onClickItem(self, cell, slot)
			return true
		end))
	end)
	self:subscribe(cell, UIEvent.EventWindowLongTouchEnd, function()
		self.inLongTouch = false
		stopTimer(cell)
	end)
	self:subscribe(cell, UIEvent.EventMotionRelease, function()
		self.inLongTouch = false
		stopTimer(cell)
	end)
end

function M:initCellPage(gridView, type, cellCount)
	gridView:InitConfig(0, 0, ROW_SIZE)
	gridView:HasItemHidden(false)
	gridView:SetMoveAble(false)

	local newSize = gridView:GetPixelSize().y / ROW_SIZE
	self.cellSize = newSize
	local xpos, ypos, width, height = { 0, 0 }, { 0, 0 }, { 0, newSize }, { 0, newSize}
	for i = 1, cellCount or CELL_COUNT do
		local cell = UIMgr:new_widget("cell")
		cell:SetArea(xpos, ypos, width, height)
		cell:setEnableLongTouchRecursivly(true)
		self.itemCellList[string.format("item_%s_%s", type, i)] = cell
		cell:setData("type", type)
		subscribeEvent(self, cell, i)
		gridView:AddItem(cell)
	end

	if type == trayType.CHEST then
		self.initChestCellsDone = true
		self:updateChestView()
	elseif type == trayType.BAG then
		self.initBagCellsDone = true
		self:updateBagView()
	else
		self.initHandBagCellsDone = true
		self:updateHandBagView()
	end
end

function M:setItemAction(cell, sloter, type, tid)
	if not sloter then
		cell:invoke("RESET")
		cell:setData("sloter")
		cell:setData("tid")
		return
	end
	cell:setData("sloter", sloter)
	cell:setData("tid", tid)
	cell:invoke("ITEM_SLOTER", sloter)
end

function M:getOneWidget()
	for i = 1, 20 do
		if not self.cellUseList[i] then
			self.cellUseList[i] = true
			return self.cellList[i], i
		end
	end
end

function M:playAnimation(isPutIntoChest, type, dropSlot, settleSlot, settleTid, slotInfo)
	local function refreshDropView()
		if isPutIntoChest then
			self.dontUpdateBagView = false
			self:updateHandBagView()
			self:updateBagView()
		else
			self:updateChestView()
		end
	end

	local function refreshSettleView()
		if isPutIntoChest then
			self:updateChestView()
			if not self.inLongTouch then
				self.dontUpdateBagView = false
				self:updateHandBagView()
				self:updateBagView()
			end
		else
			self.dontUpdateBagView = false
			self:updateHandBagView()
			self:updateBagView()
			if not self.inLongTouch then
				self:updateChestView()
			end
		end
	end

	local function getCellPos(type, slot)
		local target = self.itemCellList[string.format("item_%s_%s", type, slot)]
		local sl, st = table.unpack(target:GetRenderArea())
		return {0, sl}, {0, st}
	end

	local fromX, fromY, toX, toY, playerSlot, chestSlot
	if isPutIntoChest then
		playerSlot, chestSlot = dropSlot, settleSlot
		fromX, fromY = getCellPos(type, playerSlot)
		toX, toY = getCellPos(trayType.CHEST, chestSlot)
	else
		playerSlot, chestSlot = settleSlot, dropSlot
		toX, toY = getCellPos(settleTid == 1 and trayType.BAG or trayType.HAND_BAG, playerSlot)
		fromX, fromY = getCellPos(trayType.CHEST, chestSlot)
	end

	local item, index = self:getOneWidget()
	local itemObj
	if slotInfo.blockId then
		item:invoke("ITEM_BLOCK_ID", slotInfo.blockId)
	else
		item:invoke("ITEM_FULLNAME", slotInfo.fullName)
	end
	item:invoke("FRAME_IMAGE", item, "")
	item:SetArea(fromX, fromY, {0, self.cellSize}, {0, self.cellSize})
	item:SetVisible(true)

	refreshDropView()
	UILib.uiTween(item, {
		X = toX,
		Y = toY,
	}, chestSwitchItemAnimationTime, function()
		item:SetVisible(false)
		self.cellUseList[index] = false
		refreshSettleView()
	end)

end