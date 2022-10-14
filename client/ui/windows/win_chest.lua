local item_manager = require "item.item_manager"

function M:init()
	WinBase.init(self, "Chest.json", true)
	self:initBackpackWnd()
	self:initChestWnd()
	Lib.subscribeEvent(Event.EVENT_PLAYER_ITEM_MODIFY, function () self:updateBackpackView() end)
	self:subscribe(self:child("Chest-Btn-Close"), UIEvent.EventButtonClick, function ()
		Lib.emitEvent(Event.EVENT_OPEN_CHEST, false)
	end)
	self:child("Chest-Content-Inventory-Title"):SetText(Lang:toText("chest_content_inventory"))
	self:child("Chest-Content-Chest-Title"):SetText(Lang:toText("chest_content_chest"))
end

function M:onOpen(chestPos)
    self.chestPos = chestPos
	self:updateBackpackView()
	self:updateChestView()
	self.openArgs = table.pack(chestPos)
end

function M:initBackpackWnd()
	self.gvBag = self:child("Chest-Content-Backpack-GridView")
	self:initPageView(self.gvBag)
end

function M:initChestWnd()
	self.gvChest = self:child("Chest-Content-Chest-GridView")
	self:initPageView(self.gvChest)
end

function M:updateBackpackView()
	self:resetGridView(self.gvBag)
    local items = Me:tray():fetch_tray(1):query_items()
    self:setItemData(self.gvBag, items)
end

function M:updateChestView()
    self:resetGridView(self.gvChest)
    self:queryChestTray()
end

function M:queryChestTray()
	local packet = {
		pid = "QueryChestTray",
		pos = self.chestPos
	}

	Me:sendPacket(packet, function (items)
		if items then
			self.itemData = items
			self:setChestItem(self.gvChest, items)
		end
	end)
end

local rowSize = 9
local cellCount = 54

function M:setChestItem(gridView, items)
	local index = 0
	for slot, item in pairs(items) do
		self:updateItemView(gridView, Item.DeseriItem(item), index, 2, slot)
		index = index + 1
	end
	for i = index, cellCount - 1 do
		self:updateItemView(gridView, nil, i, 2)
	end
end

function M:setItemData(gridView, items)
	local index = 0
	for slot in pairs(items) do
		self:updateItemView(gridView, Item.CreateSlotItem(Me, 1, slot), index, 1, slot)
		index = index + 1
	end
	for i = index, cellCount - 1 do
		self:updateItemView(gridView, nil, i, 1)
	end
end


function M:initPageView(gridView)
	gridView:InitConfig(0, 0, rowSize)
	gridView:HasItemHidden(false)
	gridView:SetMoveAble(false)
	local newSize = gridView:GetPixelSize().y / rowSize
	local xpos, ypos, width, height = { 0, 0 }, { 0, 0 }, { 0, newSize }, { 0, newSize}
	for i = 1, cellCount do
		local cell = UIMgr:new_widget("cell")
		cell:SetArea(xpos, ypos, width, height)
		gridView:AddItem(cell)
	end
end

function M:resetGridView(gridView)
	for i = 0, gridView:GetItemCount() - 1 do
		local cell = gridView:GetItem(i)
		if cell then
			cell:setData("sloter")
			cell:invoke("RESET")
			cell:SetName("")
			self:unsubscribe(cell)
		end
	end
end

function M:updateItemView(gridView, sloter, index, type, slot)
	local cell = gridView:GetItem(index)
	assert(cell)
	if sloter then
		cell:setData("sloter", sloter)
		cell:invoke("ITEM_SLOTER", sloter)
		cell:SetName("item:"..sloter:full_name())
	end
	
	local function onClickCurItem(cell, type, slot)
		if not sloter then
			return
		end
		if sloter:null() then
			return
		end

		local packet = {
			pid = "SwitchChestItem",
			dropSlot = slot,
			isPutIntoChest = type == 1 and true or false,
			chestPos = self.chestPos
		}

		Me:sendPacket(packet, function (ok)
			self:updateChestView()
		end)
	end
	self:subscribe(cell, UIEvent.EventWindowClick, function () onClickCurItem(cell, type, slot) end)
end

return M