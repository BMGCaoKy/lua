local setting = require "common.setting"

function M:init()
	WinBase.init(self, "KillerInfo.json", true)
	self:initHead()
	self:initReviveButton()
	self:initActor()
	self:initWeapon()
	self:initEquip()

	Lib.subscribeEvent(Event.EVENT_PLAYER_REBIRTH, function (objID)
		if objID == Me.objID then
            UI:closeWnd(self)
            if self.recoverWndFunc then
                self.recoverWndFunc()
                self.recoverWndFunc = nil
            end
		end
	end)
end

--[[
{
	name = "", level = 1, event = "",
	actor = { name = "", scale = 1, props = {}, skin = {}, },
	weapon = { name = "", props = {} },
	equips = { name = "", props = {} }
}
]]
function M:onOpen(data, recoverWndFunc)
	WinBase.onOpen(self)

    self.recoverWndFunc = recoverWndFunc
	self.weaponInfo:SetVisible(false)
	self.equipInfo:SetVisible(false)

	self.data = assert(data, "need killer info")
	self:updateHead()
	self:updateReviveButton()
	self:updateActor()
	self:updateWeapon()
	self:updateEquip()

	self.openArgs = table.pack(data, recoverWndFunc)
end

function M:onClose()
	local closeTimer = self.closeTimer
	if closeTimer then
		closeTimer()
		self.closeTimer = nil
	end
	WinBase.onClose(self)
end

----------------------------------------
function M:initHead()
	local grid = self:child("KillerInfo-Infos")
	grid:InitConfig(0, 0, 1)
	grid:SetAutoColumnCount(false)
	grid:HasItemHidden(false)
	grid:SetMoveAble(false)
	self.killerInfoGrid = grid
end

local function fetchInfoItem(title, value, width, height)
	local item = GUIWindowManager.instance:LoadWindowFromJSON("Text_Templte.json")
	item:SetWidth(width)
	item:SetHeight(height)
	local textColor = {212.0 / 255, 1.0 / 255, 1.0 / 255}
	local textBorder = {0, 0, 0}
	local list = {title, value}
	for i = 1, #list do
		local child = item:GetChildByIndex(i - 1)
		child:SetText(Lang:toText(list[i]))
		child:SetTextColor(textColor)
		child:SetTextBoader(textBorder)
	end
	return item
end

function M:updateHead()
	local grid = self.killerInfoGrid
	grid:RemoveAllItems()
	local list = {"name", "level"}
	local width = { 0, grid:GetPixelSize().x }
	local height = { 0, grid:GetPixelSize().y / #list }
	for i, key in ipairs(list) do
		local title = "gui.killerinfo.killer."..key
		local value = self.data[key] or ""
		grid:AddItem(fetchInfoItem(title, value, width, height))
	end
	grid:SetVisible(true)
end

function M:initReviveButton()
	local reviveNormalBtn = self:child("KillerInfo-ReviveNormal")
	reviveNormalBtn:SetText(Lang:toText("gui.killerinfo.button.revivenormal"))
	self:subscribe(reviveNormalBtn, UIEvent.EventButtonClick, function()
		self:onClickReviveButton(false)
	end)
	self.reviveNormalBtn = reviveNormalBtn

	local reviveNowBtn = self:child("KillerInfo-ReviveNow")
	reviveNowBtn:SetText(Lang:toText("gui.killerinfo.button.revivenow"))
	self:subscribe(reviveNowBtn, UIEvent.EventButtonClick, function()
		self:onClickReviveButton(true)
	end)
	self.reviveNowBtn = reviveNowBtn

	self.reviveCostText = self:child("KillerInfo-Cost")
end

function M:updateReviveButton()
	self.reviveCostText:SetText(tostring(self.data.cost or 0))

	local closeTimer = self.closeTimer
	if closeTimer then
		closeTimer()
	end
	local timeout = self.data.timeout or 60
	self.closeTimer = World.Timer(timeout, function()
		self:onClickReviveButton(false)
		UI:closeWnd(self)
	end)
end

function M:onClickReviveButton(reviveNow)
	--print("click revive button", reviveNow)
	local data  = self.data
	Me:doCallBack("killerInfo", "key", data.regId, {result = reviveNow, coinName = data.coinName, cost = data.cost})
end

function M:initActor()
	self.actor = self:child("KillerInfo-Actor")
	self.actor:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
end

function M:updateActor()
	local actor = self.actor
	actor:UpdateSelf(1)
	local info = self.data.actor
	if info then
		actor:SetActor1(info.name, "idle")
		actor:SetActorScale(info.scale or 1)
		-- property and skin
	end
end

local function fetchCell()
	local cell = UIMgr:new_widget("cell")
	cell:invoke("FRAME_IMAGE", nil, "set:killer_info.json image:item_frame.png")
	cell:invoke("FRAME_SELECT_IMAGE", nil, "set:killer_info.json image:selected_frame.png")
	cell:invoke("SHOW_FRAME", true)
	return cell
end

function M:initWeapon()
	local cell = fetchCell()
	cell:SetWidth({1, 0})
	cell:SetHeight({1, 0})
	self:child("KillerInfo-Weapon"):AddChildWindow(cell)
	self:subscribe(cell, UIEvent.EventWindowClick, function()
		self:onClickWeaponCell()
	end)
	self.weaponCell = cell

	local weaponInfo = self:newItemInfoWnd()
	weaponInfo:SetVisible(false)
	self.weaponInfo = weaponInfo
	self:child("KillerInfo-WeaponInfo"):AddChildWindow(weaponInfo)
	self:child("KillerInfo-WeaponLabel"):SetText(Lang:toText("gui.killerinfo.label.weapon"))
	self.weaponPannel = self:child("KillerInfo-Left")
end

function M:updateWeapon()
	if not self.data.isPlayer then
		self.weaponPannel:SetVisible(false)
		return
	end
	self.weaponPannel:SetVisible(true)

	local cell = self.weaponCell
	cell:invoke("RESET")
	local weapon = self.data.weapon
	local fullName = weapon and weapon.name
	if fullName then
		cell:invoke("ITEM_FULLNAME", fullName)
		cell:SetName("equip:"..fullName)
	end
end

function M:onClickWeaponCell()
	local weapon = self.data.weapon
	if weapon then
		self.weaponCell:receiver():onClick(true)
		self:updateItemInfo(self.weaponInfo, weapon.name, weapon.props)
	end
end

function M:initEquip()
	local grid = self:child("KillerInfo-Equip")
	grid:InitConfig(0, 0, 1)
	grid:SetAutoColumnCount(false)
	grid:HasItemHidden(false)
	grid:SetMoveAble(false)
	self.equipsGrid = grid
	local equipInfo = self:newItemInfoWnd()
	equipInfo:SetVisible(false)
	self.equipInfo = equipInfo
	self:child("KillerInfo-EquipInfo"):AddChildWindow(equipInfo)
	self:child("KillerInfo-EquipLabel"):SetText(Lang:toText("gui.killerinfo.label.equip"))
	self.equipPannel = self:child("KillerInfo-Right")
end

function M:updateEquip()
	if not self.data.isPlayer then
		self.equipPannel:SetVisible(false)
		return
	end
	self.equipPannel:SetVisible(true)

	local grid = self.equipsGrid
	grid:RemoveAllItems()
	local size = grid:GetPixelSize().x
	local NONE = {}
	for _, equip in ipairs(self.data.equips or {NONE, NONE, NONE, NONE}) do
		local cell = fetchCell()
		cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, size }, { 0, size})
		local fullName = equip.name
		if fullName then
			cell:invoke("ITEM_FULLNAME", fullName)
			cell:SetName("equip:"..fullName)

			self:subscribe(cell, UIEvent.EventWindowClick, function()
				for i = 0, grid:GetItemCount() - 1 do
					grid:GetItem(i):receiver():onClick(false)
				end
				cell:receiver():onClick(true)
				self:updateItemInfo(self.equipInfo, fullName, equip.props)
			end)
		end
		grid:AddItem(cell)
	end
	grid:SetVisible(true)
end

----------------------------------------
function M:newItemInfoWnd()
	return GUIWindowManager.instance:LoadWindowFromJSON("ItemShowInfo.json")
end

function M:updateItemInfo(wnd, fullName, props)
	local item = Item.CreateItem(fullName)
	assert(item, fullName)
	local cfg = item:cfg()
	wnd:SetVisible(true)
	wnd:child("ItemShowInfo-ItemIcon"):SetImage(item:icon())
	wnd:child("ItemShowInfo-ItemName"):SetText(Lang:toText(cfg.itemname or ""))
	local infoList = wnd:child("ItemShowInfo-InfoList")
	infoList:ClearAllItem()
	local total = 80
	for _, prop in ipairs(props or {}) do
		local node = GUIWindowManager.instance:LoadWindowFromJSON("ItemInfoNode.json")
		infoList:AddItem(node) -- must add to parent before modify
		local name, value = prop[1], prop[2]
		if type(value) == "string" then
			value = Lang:toText(value)
		end
		local info = node:child("ItemInfoNode-Info")
		info:SetText(Lang:toText({"gui.killerinfo.item."..name, value}))
		local height = info:GetPixelSize().y
		node:SetHeight({0, height})
		total = total + height
	end
	wnd:SetHeight({0, total})
end
