local setting = require "common.setting"

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
	WinBase.init(self, "imprint.json", true)
	self.specialEquipCells = {}	
	self.containter = self:child("CharacterPanel-Imprint-Containter")
	self:child("CharacterPanel-Property_Base"):SetTouchPierce(true)
end

function M:createItem(cell)
	local item = cell:data("item_pos")
	local cellFullName = cell:data("full_name")
	local retItem = Item.CreateItem(cellFullName, 1)
	local sloter = Lib.derive(retItem) 
	function sloter.tid()
		return item.tid
	end

	function sloter.slot()
		return item.slot
	end
	return sloter
end

function M:initImprintCell(cells)
	local function cellOnClick(cell, index)
		if not self._isMe then
			return
		end
		local item = cell:data("item_pos")
		if not item then
			return
		end

		local sloter = self:createItem(cell)
		
		local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.BAG)[1]
		local tid, bag = trayArray.tid, trayArray.tray

		local slot = bag:find_free()
		if not slot then
			return
		end
		local function onTakeOff(ok)
			if ok then
				cell:setData("sloter")
				cell:invoke("RESET")
				cell:SetName("")
				self:queryEntityViewInfo(true)
			end
		end
		UI:closeWnd("popups_property")
		UI:openWnd("popups_property",
		cell,sloter, {tid = tid, slot = slot},false,Define[self._entityType],self.BagUi._root)
	end
	for index, cell in pairs(cells) do
		local sloter = cell.sloter
		self:subscribe(sloter, UIEvent.EventWindowClick, function()
			cellOnClick(sloter, index, cell)
		end)
	end
end

function M:resetImprintView(traysCfgs)
	local function fetchTitleItem(name)
		local titleUi = GUIWindowManager.instance:LoadWindowFromJSON("imprintTitle.json")
		titleUi:SetArea({ 0, 0 }, { 0, 5 }, { 1, 0}, { 0, 50 })
		titleUi:child("imprintTitle-title"):SetText(Lang:toText(name))
		return titleUi
	end
	local function fetchGridView(height)
		local gv = GUIWindowManager.instance:CreateGUIWindow1("GridView")
		gv:SetArea({ 0, 0 }, { 0, 0 }, { 1, -2}, { 0, height })
		gv:InitConfig(0, 0, 5)
		gv:SetHorizontalAlignment(1)
		gv:HasItemHidden(false)
		-- gv:SetMoveAble(true)
		return gv
	end
	local function fetchCellItem(size)
		local cell = fetchCell()
		cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, size }, { 0, size})
		cell:invoke("SHOW_LOCKED", true)
		cell:invoke("RESET_OUTER_FRAME",false)
		return cell
	end
	if self.initList then
		return
	end
	self.initList = true
	local containter = self.containter
	local cellSize = (containter:GetPixelSize().x - 2) / 5
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
		self:initImprintCell(cells)
	end
end

function M:initImprint()
	self:resetImprintView(self:getTraysImprintCfg())
end

function M:getTraysImprintCfg()
	local traysCfgs = {}
	for _, cfg in ipairs(Entity.GetCfg(self._entityCfg).trays or {}) do
		if cfg.class == Define.TRAY_CLASS_IMPRINT then
			traysCfgs[#traysCfgs + 1] = cfg
		end
	end
	return traysCfgs
end

function M:showEntityImprint(info)
	if not info then
		return
	end
	self:initImprint()	
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
				cell:setData("full_name", data.fullName)
			end
		end
	end
end

function M:queryEntityViewInfo(ignore)
	Lib.emitEvent(Event.FETCH_ENTITY_INFO, ignore)
end

function M:setContentValue(infoValues, cfg)
	if not infoValues then
	 return
	end
	   local titles = {}
	   local values = {}
	local iconBases = {}
	for i, info in ipairs(cfg) do
	 local value = infoValues and infoValues[i] or ""
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
	 iconBases[i] = info.iconBase -- 每项属性对应的图标 例 set:skill_character_system.json image:character_life_icon.png
	end
	local ret = {
	 titles = titles,
	 values = values,
	 iconBases = iconBases,
	}
	return ret
end

function M:updataViewProp(info)
	local function setViewProp(info, column)	
		local titles = info.titles
		local values = info.values
		local iconBases = info.iconBases
		if not titles then
		 return
		end
		local infoGrid = self:child("CharacterPanel-prop")
		infoGrid:RemoveAllItems()
		infoGrid:InitConfig(0, 0, column)
		local width = infoGrid:GetPixelSize().x / column - 10
		for i, title in ipairs(titles) do
		 local tab = GUIWindowManager.instance:LoadWindowFromJSON("PropertyTab.json"):child("PropertyTab-Base")
		 tab:SetArea({ 0, 0 }, { 0, 0}, { 0, width}, { 0, tab:GetPixelSize().y})
		 tab:child("PropertyTab-Base_Icon"):SetImage(iconBases[i])
		 tab:child("PropertyTab-Base_Text"):SetText(title)
		 tab:child("PropertyTab-Base_Data"):SetText(values[i])
		 infoGrid:AddItem(tab)
		end
		infoGrid:SetVisible(true)
	end
	local cfg = Entity.GetCfg(self._entityCfg)
	local imprintInfo = self:setContentValue(info and info.imprint and info.imprint.values or nil, cfg.imprintValues or {})
	setViewProp(imprintInfo, 2)
end


function M:openBag(isOpen, parentUi)
	if isOpen then
		self.BagUi = UI:openWnd("bag")
		local bagRoot = self.BagUi._root
		local imprintArea = self._root:GetWidth()
		--bagRoot:SetParent(parentUi)
		parentUi:AddChildWindow(bagRoot)
		bagRoot:SetArea({0, imprintArea[2]}, {0, 0}, {1, -1 * imprintArea[2]}, {1, 0})
	else
		UI:closeWnd("bag")
	end


end

function M:onClose()
	local num = self.parentUi and self.parentUi:GetChildCount() or 0
	for i = 1, num do
		local win = self.parentUi:GetChildByIndex(i - 1)
		win:SetVisible(false)
		self.parentUi:RemoveChildWindow(win)
	end

	if self._allEvent then
        for k, fun in pairs(self._allEvent) do
            fun()
        end
	end
end

function M:popDialog(cell)
	if not cell then
		UI:openWnd("popups_property",
		cell)
		return
	end
	local sloter = cell:data("sloter")
	local function isCanEquip()
		
		local types = sloter:data():tray_type()
		local imprintData = self._info.imprint or {}
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
		return nil
	end

	local function onEquipItem(ok)
		if ok then
			self:queryEntityViewInfo(true)
			--self:resetSelectedCell()
		end
	end

	local curCfg = sloter:cfg()
	local tid, slot = isCanEquip()
	local canEquip = curCfg.tray and true
	local cansell = curCfg.cansell and true or false
	local candestroy = curCfg.candestroy and true or false
	if not tid then
		--return
	end
	UI:closeWnd("popups_property")
	UI:openWnd("popups_property",
	cell,sloter, {tid = tid, slot = slot},true,Define[self._entityType],self.BagUi._root)

end

function M:updataViewInfo(info)
	if not info then
		return
	end
	self._viewInfoCache= info
	self._entityCfg = info.cfg
	self._info = info
	self:showEntityImprint(info)
	self:updataViewProp(info)
end

function M:subscribeEvent()
	self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.PUSH_ENTITY_INFO, function(info)
		if not self.pushEndTime or self.pushEndTime <= World.Now() then
			self.pushEndTime = World.Now() + 5
			if self.lastPushTimer then
				self.lastPushTimer()
				self.lastPushTimer = nil
			end
			self.lastPushTimer = World.Timer(5, function()
				self:updataViewInfo(info)
			end)
		end
	end)
	
	self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.DIALOG_INFO, function(cell)
		self:popDialog(cell)
	end)
	
end

function M:onOpen(packet)
	self._root:SetVisible(true)
	self._info = packet.info 
	self._isMe = packet.isMe
	self._allEvent = {}
	self:subscribeEvent()
	self._entityType = packet.entityType
	self._objID = self._isMe and Me.objID or packet.objID
	self:openBag(self._isMe, packet.parentUi)
	self._viewInfoCache = nil
	self.parentUi = packet.parentUi
	self:updataViewInfo(self._info)
end
