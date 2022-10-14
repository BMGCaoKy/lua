-- 角色面板
local setting = require "common.setting"

local cell_pool = {}

local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell","widget_cell_2.json","widget_cell_2")
	end
	return ret
end

function M:attach(objID)
	if objID ~= self.objID then
		self.viewInfoCache = nil
	end
	self.objID = assert(objID)
end

function M:isMe()
	return self.objID == Me.objID
end

function M:init()
	self.objID = Me.objID
	self.lastPageType = Define.ENTITY_INTO_TYPE_PLAYER 
	WinBase.init(self, "CharacterPanel.json", true)
	self:initEntityWnd() 
	self._root:SetLevel(10)
end

function M:initEntityWnd()
	self.wndCharacter = self:child("CharacterPanel-Character_Base")
	self.entityActor = {
		model = self:child("CharacterPanel-Entity_Actor"),
		baseImage = self:child("CharacterPanel-Entity_Base")
	}
	self.equipCells = {} -- 左侧上方6个装备栏
	self.equipInfoGrid = self:child("CharacterPanel-Property_Base_Grid_View") -- 左侧下方的GridView
	self.lvNameTab = self:child("CharacterPanel-Lv_Name_Text") -- 上方横栏
	self:child("CharacterPanel-Property_Base"):SetTouchPierce(true)
	-- self:child("CharacterPanel-Actor_Equip_Base"):SetTouchable(false)
	-- self.equipInfoGrid:SetTouchable(false)
	-- self:child("CharacterPanel-Actor_Base"):SetTouchable(false)
	-- self:child("CharacterPanel-Character_Property"):SetTouchable(false)
	-- self.wndCharacter:SetTouchable(false)
	-- self._root:SetTouchable(false)
	self:initEquipCells() 
	self:initEquipCellEvent() 
end

function M:initEquipCells()
	local equipCells = self.equipCells
	local equipBaseGrid = self:child("CharacterPanel-Equip_Base_Grid_View")
	local curWorldCfg = World.cfg
	local equipTrayDatas = curWorldCfg.equipTrayDatas or 
	{
        {
            x = 15,
            y = 40
        },
        {
            x = 315,
            y = 40
        },	  
        {	  
            x = 15,
            y = 135
        },	  
        {	  
            x = 315,
            y = 135
        },	  
        {	  
            x = 15,
            y = 230
        },	  
        {	  
            x = 315,
            y = 230
        }
    }
	for i = 1, curWorldCfg.equipTrays or 6 do
		local tempCell = fetchCell()
		local tempData = equipTrayDatas[i]
		tempCell:SetArea({ 0, tempData["x"] }, { 0, tempData["y"]}, { 0, 83}, { 0, 83})
		equipBaseGrid:AddChildWindow(tempCell)
		tempCell:invoke("SHOW_FRAME",false)
		equipCells[i] = { sloter = tempCell }
	end	
end

function M:createItem(cell)
	local item = cell:data("item_pos")
	local cellFullName = cell:data("full_name")
	local retItem = Item.CreateItem(cellFullName, 1)
	local sloter = Lib.derive(retItem) 
	-- function sloter.cfg() 
	-- 	return cellCfg 
	-- end

	-- function sloter.icon()
	-- 	return  ResLoader:loadImage(cellCfg, cellCfg.icon)
	-- end

	function sloter.tid()
		return item.tid
	end

	function sloter.slot()
		return item.slot
	end
	
	return sloter
end

function M:initEquipCellEvent()
	local function cellOnClick(cell, index)
		if not self:isMe() then
			return
		end
		local item = cell:data("item_pos")
		if not item then
			return
		end
		
		local sloter = self:createItem(cell)
		-- ITEM_FULLNAME


		local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.BAG)[1]
		local destTid, bag = trayArray.tid, trayArray.tray
		local destSlot = bag:find_free()

		UI:closeWnd("popups_property")
		UI:openWnd("popups_property",
		cell,sloter,destSlot and {tid = destTid,slot = destSlot} or nil,false,self.lastPageType,self.bagRoot
		)
		-- self.itemPropertyPanel:openPopups(cell,sloter,destSlot and {tid = destTid,slot = destSlot} or nil,false,self.lastPageType,self.bagRoot)
	end
	for index, cell in pairs(self.equipCells) do
		local sloter = cell.sloter
		self:subscribe(sloter, UIEvent.EventWindowClick, function()
			if sloter:data("full_name") then
				cellOnClick(sloter, index)
			end
		end)
	end
end

function M:openRightWnd(isOpen)
	self:openBag(isOpen) 
	self.allEventTab[#self.allEventTab + 1] = Lib.subscribeEvent(Event.DIALOG_INFO,function(cell) 
		if not cell then
			UI:closeWnd("popups_property")
			return
		end
		local function getDestTidSlot(sloter)
			local types = sloter:data():tray_type()
			for t, data in pairs(self.entityData and self.entityData.equip or {}) do
				if types[t] then
					return data.tid, 1
				end
			end
		end
		local sloter = cell:data("sloter")
		if not sloter then
			return
		end
		local destTid,destSlot = getDestTidSlot(sloter)
		UI:closeWnd("popups_property")
		UI:openWnd("popups_property",
		cell,sloter,destTid and {tid = destTid, slot = destSlot} or nil,true,self.lastPageType,self.wndCharacter
		)
	end)
end

function M:openBag(isOpen)
	if isOpen then
		self.BagUi = UI:openWnd("bag")
		local bagRoot = self.BagUi._root 
		self.bagRoot = bagRoot
		self.parentUi:AddChildWindow(bagRoot)
		local imprintArea = self._root:GetWidth()
		bagRoot:SetArea({0,imprintArea[2]},{0,0},{1, -1 * imprintArea[2]},{1,0})
	else
		UI:closeWnd("bag")
	end

end

function M:onOpen(packet)
	self.allEventTab = {}
	self.parentUi = packet.parentUi
	self:openRightWnd(packet.isMe)
	self.entityData = packet.info --需要上层传过来的 entityData/info
	local isMe = packet.isMe or true -- 需要上层传过来的
	self.lastPageType = Define[packet.entityType]
	self.wndCharacter:SetVisible(isMe)
	self:attach(Me.objID)
	self.viewInfoCache = nil
	self.entityCfg = nil
	self:resetEntityViewInfo(packet.info)
	self.openArgs = table.pack(self.objID)
	self:registerEvent()
end

function M:clearAllEvent()
	for _, v in pairs(self.allEventTab) do
		v()
	end
end

function M:registerEvent()
	self.allEventTab[#self.allEventTab + 1] = Lib.subscribeEvent(Event.PUSH_ENTITY_INFO, function(info)
		self:onUpdate(info)
	end)

end

function M:onUpdate(entityData)
	self:resetEntityViewInfo(entityData)
end

function M:resetEntityViewInfo(info)
	if not info then
		return
	end
	self.viewInfoCache = info
	self.entityCfg = info.cfg
	self:showEntityEquipment(info)
	self.entityData = info
	local cfg = Entity.GetCfg(info.cfg)
	if info.values then
		cfg.infoValues = cfg.infoValues or {
			{
			  ["name"] = "gui.info.name",
			  ["value"] = "name"
			},
			{
			  ["name"] = "gui.info.clanname",
			  ["value"] = "vars.clanName"
			},
			{
			  ["name"]= "gui.info.vip",
			  ["value"]= "vars.vip",
			  ["langKey"]= "{.vip.name}",
			  ["default"]= 0
			}
		}
		local equipmentInfo = self:setContentValue(info.values, cfg.infoValues or {})
		self:setInfoGrid(self.equipInfoGrid, equipmentInfo, cfg.characterPanelColumns or 2 )
	end
	self:setTitleTabBar()
end

function M:showEntityEquipment(info)
	local cells = self.equipCells
	local entityActor = self.entityActor
	local image = entityActor.baseImage
	local actor = entityActor.model
	self:resetEntityEquipment(Entity.GetCfg(info.cfg))
	actor:UpdateSelf(1)
	actor:SetActor1(info.actor, "idle")
	local cfg = Entity.GetCfg(self.entityCfg)
	local showModelCfg = cfg.showModelCfg or {
		["scale"] = 1,
		["baseImage"] = "set:new_gui_material.json image:armor_foot_bg"
	}
	image:SetImage(showModelCfg.baseImage or "")
	image:SetVisible(true)
	local scale = showModelCfg.scale or 1
	actor:SetActorScale(scale)
	local property = showModelCfg.property or {}
	for _, v in pairs(property) do
		actor:SetProperty(v.name, v.value)
	end

	local skin = EntityClient.processSkin(info.actor, info.skin)
	for k, v in pairs(skin) do
		if v == "" then
			actor:UnloadBodyPart(k)
		else
			actor:UseBodyPart(k, v)
		end
	end
	self:setEquipCells(cells, info.equip)
end

function M:resetEntityEquipment(entityCfg)
	self:resetCurEntityEquipCells(self.equipCells,entityCfg)
	self.entityActor.baseImage:SetVisible(false)
end

function M:resetCurEntityEquipCells(cells,entityCfg)
	local characterEquipTrayDatas = entityCfg.characterEquipTrayDatas or {
		{
			["childBase"]= "set:skill_character_system.json image:helmet_tray.png",
			["tray"] = 1
		},
		{
			["childBase"] = "set:skill_character_system.json image:armor_tray.png",
			["tray"] = 2
		},
		{
			["childBase"] = "set:skill_character_system.json image:pants_tray.png",
			["tray"] = 3
		},
		{
			["childBase"] =  "set:skill_character_system.json image:shoes_tray.png",
			["tray"] =  4
		}
	}
	for i, cell in pairs(cells) do
		local sloter = cell.sloter
		local temp = characterEquipTrayDatas[i]
		sloter:invoke("RESET")
		sloter:invoke("SET_BASE_ICON",temp and temp["childBase"] or "set:skill_character_system.json image:reserved_tray.png") -- 背板
		sloter:invoke("SHOW_LOCKED", false)
		sloter:invoke("RESET_OUTER_FRAME", false)
		sloter:SetName("")
		sloter:setData("full_name", nil)
		cell.tray = temp and temp["tray"] or nil
	end
end

function M:setEquipCells(cells, data)
	for k, v in pairs(data) do
		for i, cell in pairs(cells) do
			if k == cell.tray then
				local slot, fullName = v.slot, v.fullName
				if cell and slot and fullName then
					local sloter = cell.sloter
					sloter:invoke("ITEM_FULLNAME", fullName)
					sloter:setData("full_name", fullName)
					sloter:setData("item_pos", {tid = v.tid, slot = slot})
					sloter:SetName("equip:" .. fullName)
					
					local item = Me:tray():fetch_tray(v.tid):fetch_item(slot)
    				sloter:invoke("SET_BG", item)
				end
			end
		end
	end
end

function M:setContentValue(infoValues, cfg)
	if not infoValues then
		return
	end
    local titles = {}
    local values = {}
	local iconBases = {}
	for i, info in ipairs(cfg) do
		local value = infoValues[i]
		if not info.langKey then
			value = tostring(value)
		elseif type(info.langKey) ~= "string" then
			value = Lang:toText(value)
		elseif type(value) ~= "table" then
			value = Lang:toText({info.langKey, value or ""})
		else
			value = Lang:toText({info.langKey, table.unpack(value, 1, #info.value)})
		end
		titles[i] = Lang:toText(info.name or "")
        values[i] = value or ""
		iconBases[i] = info.iconBase -- 每项属性对应的图标 例 set:skill_character_system.json image:character_life_icon.png
	end
	local ret = {
		titles = titles,
		values = values,
		iconBases = iconBases,
	}
	return ret
end

function M:setInfoGrid(infoGrid, info, column)
	local titles = info.titles
	local values = info.values
	local iconBases = info.iconBases
	if not titles then
		return
	end
	infoGrid:RemoveAllItems()
	infoGrid:InitConfig(0, 0, column)
	local width = infoGrid:GetPixelSize().x / column - 10
	for i, title in ipairs(titles) do
		local tab = GUIWindowManager.instance:LoadWindowFromJSON("PropertyTab.json"):child("PropertyTab-Base")
		tab:SetArea({ 0, 0 }, { 0, 0}, { 0, width}, { 0, tab:GetPixelSize().y})
		tab:child("PropertyTab-Base_Icon"):SetImage(iconBases[i])
		tab:child("PropertyTab-Base_Text"):SetText(Lang:toText(title or ""))
		tab:child("PropertyTab-Base_Text"):SetProperty("Font", "HT12")
		if values[i] == "nil" or values[i] == "(nil)" then
			values[i] = ""
		end
		tab:child("PropertyTab-Base_Data"):SetText(Lang:toText(values[i] or ""))
		tab:child("PropertyTab-Base_Data"):SetProperty("Font", "HT12")
		infoGrid:AddItem(tab)
	end
	infoGrid:SetVisible(true)
end

-- 
function M:setTitleTabBar()
	self.lvNameTab:SetText("  lv" .. Me:getValue("level") .. "      " .. Me.name .. "  ")
end

function M:onClose()
	local num = self.parentUi:GetChildCount()
	for i = 1, num do
		local win = self.parentUi:GetChildByIndex(i - 1)
		win:SetVisible(false)
		self.parentUi:RemoveChildWindow(win)
	end

	UI:closeWnd("popups_property")
	self:clearAllEvent()
end

return M