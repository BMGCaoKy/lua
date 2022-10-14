local itemSetting = require "editor.setting.item_setting"
function M:init()
	WinBase.init(self, "item_base_prop_setting.json")
	self:initUIName()
	self:initUI()
	self:initData()
end

function M:initUIName()
	self.itemNameUI = self:child("base_prop_setting-name")
	self.itemPropGridUI = self:child("base_prop_setting-propGrid")
end

function M:initData()
	self.baseProp = {
		{["prop"] = "maxHp",	["descIndex"] = 1},
		{["prop"] = "jumpSpeed",["descIndex"] = 1},
		{["prop"] = "damage",	["descIndex"] = 1},
		{["prop"] = "armor",	["descIndex"] = 1},
		{["prop"] = "moveSpeed",["descIndex"] = 1},
	}
	self.appendBuffList = {
		smallWoodSword = {
				"hp", "jumpSpeed", "damage"
		},
		bigWoodSword = {
				"hp", "jumpSpeed", "damage"
		},
	}

	self.buffNameIconList = {
		hp = {
			name = "hp",
			icon = "myplugin/image/1.png",
			descIndex = 1,
			titile = "hp",
		},
		jumpSpeed = {
			name = "jumpSpeed",
			icon = "myplugin/image/1.png",
			descIndex = 1,
			titile = "jumpSpeed",

		},
		damage = {
			name = "damage",
			icon = "myplugin/image/1.png",
			descIndex = 1,
			titile = "damage",

		},
	}
	if World.cfg.baseProp then
		self.baseProp = World.cfg.baseProp
	end
	if World.cfg.appendBuffList then
		self.appendBuffList = World.cfg.appendBuffList
	end
	self.wantSaveData = { base = {}, addBuff = {}, modifyList = {}}
end

function M:initUI()
	self:child("base_prop_setting-title"):SetText(Lang:toText("editor.ui.itemName"))
	self.itemPropGridUI:InitConfig(0, 30, 1)
end

function M:initItemName()
	local item = self.item
	if not item then
		return
	end
	self.itemNameUI:SetText(Lang:toText(item:cfg().itemname))
end

function M:fetchBaseProp()
	self.itemPropGridUI:RemoveAllItems()
	for _, propItem in pairs(self.baseProp or {}) do
		local value = itemSetting:getBaseProp(self.fullName, propItem.prop)
		local slider = UILib.createSlider({value = value or 9999999, index = propItem.descIndex or 1}, function(value)
			self.wantSaveData.base[propItem.prop] = value  
		end)
		self.itemPropGridUI:SetXPosition({0, 20})
		self.itemPropGridUI:AddItem(slider)
	end
end

function M:fetchAppendBuff()
	local function newAddBtn()
		local btn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "button")
		btn:SetArea({0, 0}, {0, 0}, {0, 140}, {0, 140})
		btn:SetImage("set:setting_global.json image:btn_add_player_actor_a.png")
		self:subscribe(btn, UIEvent.EventWindowClick, function()
			-- open window
			UI:openWnd("mapEditBuffSetting")
		end)
		return btn
	end

	local function newBuffItemUI(self, buffName)
		local itemUI = GUIWindowManager.instance:LoadWindowFromJSON("buffCell.json")
		local icon = self:getBuffIcon(buffName)
		local name = Lang:toText(self:getBuffName(buffName))
		local level = self:getBuffLevel(buffName)
		if level and level > 0 then
			name = name .. "(" .. level .. "lv)"
		end
		itemUI:child("buffCell-icon"):SetImage(icon)
		itemUI:child("buffCell-name"):SetText(name)
		return itemUI
	end
	-- todo new add btn
	local gridLayout = GUIWindowManager.instance:LoadWindowFromJSON("buffList.json")

	gridLayout:child("buffGrid-name"):SetText(Lang:toText("editor.ui.itemBuff"))
	local buffGrid = gridLayout:child("buffGrid-buffList")
	
	local function addBuffItem(self, item, row, cellWidth, index)
		local cellHegiht = 190
		buffGrid:AddChildWindow(item)
		item:SetXPosition({0, (index % row) * cellWidth})
		local height = math.floor(index / row) * cellHegiht
		item:SetYPosition({0, height})
		gridLayout:SetArea({0, 0}, {0, 0}, {0, 700}, {0, height + cellHegiht})

		local close = item:child("buffCell-close")
		local edit = item:child("buffCell-jumpSetting")
		if not close then
			return
		end
		self:subscribe(close, UIEvent.EventButtonClick, function()
			self:delBuff(index)
		end)
		self:subscribe(edit, UIEvent.EventButtonClick, function()
			self:popEditBuff(index)
		end)
	end

	local function removeAllBuffUI()
		local count = buffGrid:GetChildCount()
		for i = 1, count do
			local child = buffGrid:GetChildByIndex(0)
			buffGrid:RemoveChildWindow1(child)
		end
	end
	
	removeAllBuffUI()
	if self.buffLayout then
		self.itemPropGridUI:RemoveItem(self.buffLayout)
	end
	self.buffLayout = gridLayout
	local index = 0
	local appendBuffNameList = self:getTypeBuffInfoList()
	addBuffItem(self, newAddBtn(), 3, 182, index)
	for _, buffName in pairs(appendBuffNameList) do
		local item = newBuffItemUI(self, buffName)
		index = index + 1
		addBuffItem(self, item, 3, 182, index)
	end
	self.itemPropGridUI:AddItem(gridLayout)
end

function M:popEditBuff(index)
	local value, level = self:getBuffValue(index)
	local buffList = self:getTypeBuffInfoList()
	local modifyBuffList = self.wantSaveData.modifyList
	local buffName = buffList[index]

	local buffIcon = self:getBuffIcon(buffName)
	local title = self:getBuffTitle(buffName)
	local descIndex = self:getBuffDesc(buffName)


	local desktop = GUISystem.instance:GetRootWindow()
	local ui = UIMgr:new_widget("leftTab")

	local function sureOnSaveBackFunc(value)
		local buffType = self:getBuffType(buffName)
		self:modifyBuff(buffName, value[1][1], buffType)
		self:modifyBuff(buffName, value[1][2], "level")
		desktop:RemoveChildWindow1(ui)
		self:fetchAppendBuff()
	end

	local function cancelFunc()
		desktop:RemoveChildWindow1(ui)
	end
	ui:invoke("fillData", {
		tabDataList = {
			{
				leftTabName = "editor.ui.setCount",
				widgetName = "baseProp",
				params = {
					title = title,
					dataUIList = {
						{
							type = "slider",
							index = descIndex or 1, 
							value = value,
						},
						{
							type = "slider",
							index = descIndex or 1, 
							value = level,
						}
					}
				},
			}
		},
		sureOnSaveBackFunc = sureOnSaveBackFunc,
		cancelFunc = cancelFunc
	})
	desktop:AddChildWindow(ui)
end

function M:getTypeBuffInfoList()
	local buffList = self.buffTypeList
	if not buffList then
		buffList = itemSetting:getTypeBuffList(self.fullName) or {}
		local addBuffList = self.wantSaveData.addBuff
		for _, buffName in pairs(addBuffList or {}) do
			buffList[#buffList + 1] = buffName
		end
		self.buffTypeList = buffList
	end
	return buffList
end

function M:addBuff(buffName, value, buffType)
	local addBuff = self.wantSaveData.addBuff
	if not addBuff then
		addBuff = {}
		self.wantSaveData.addBuff = addBuff
	end
	addBuff[#addBuff + 1] = buffName

	itemSetting:setBuffProp(buffName, buffType, value[1][1])
	itemSetting:setBuffProp(buffName, "level", value[1][2])

	local buffList = self:getTypeBuffInfoList()
	buffList[#buffList + 1] = buffName
	self:modifyBuff(buffName, value[1][1], buffType)
	self:modifyBuff(buffName, value[1][2], "level")
	self:fetchAppendBuff()
end

function M:delBuff(index)
	local buffList = self:getTypeBuffInfoList()
	table.remove(buffList, index)
	self:fetchAppendBuff()
end

function M:modifyBuff(buffName, value, propKey)
	if not value then
		return
	end
	local modifyBuffList = self.wantSaveData.modifyList
	-- modifyBuffList[buffName] = {
	-- 	[1] = {
	-- 		[buffType] = value[1][1],
	-- 		level = value[1][2]
	-- 	}
	-- }
	local targetBuffData = modifyBuffList[buffName]
	if not targetBuffData then
		targetBuffData = {}
		modifyBuffList[buffName] = targetBuffData
	end
	targetBuffData[propKey] = value
end

function M:getBuffValue(index)
	
	local buffList = self:getTypeBuffInfoList()
	local modifyBuffList = self.wantSaveData.modifyList
	local buffName

	if type(index) == "number" then
		buffName = buffList[index]
	else
		buffName = index
	end

	local proKey = self:getBuffType(buffName)
	local value, level
	if buffName then
		--这里后面可能是一个value列表
		local propList = modifyBuffList[buffName]
		if propList then
			value = propList[proKey]
			level = propList["level"]
		end
	end
	-- 重新读配置取出值
	local value = value or itemSetting:getBuffProp(buffName, proKey)
	local level = level or itemSetting:getBuffProp(buffName, "level") or 0
	return value, level
end

function M:getBuffType(buffName)
	local splitRet = Lib.splitString(buffName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	splitRet = Lib.splitString(buffName, "[")
	len = #splitRet
	local type = len > 0 and splitRet[len]
	return type
end

function M:getBuffIcon(buffName)
	local buffType = self:getBuffType(buffName)
	local buffItem = self.buffNameIconList[buffType]
	if not buffItem then
		return
	end
	return buffItem.icon
end

function M:getBuffLevel(buffName)
	local value, level = self:getBuffValue(buffName)
	return level
end

function M:getBuffName(buffName)
	local buffType = self:getBuffType(buffName)
	local buffItem = self.buffNameIconList[buffType]
	if not buffItem then
		return
	end
	return buffItem.name
end

function M:getBuffDesc(buffName)
	local buffType = self:getBuffType(buffName)
	local buffItem = self.buffNameIconList[buffType]
	if not buffItem then
		return
	end
	return buffItem.desc
end

function M:getBuffTitle(buffName)
	local buffType = self:getBuffType(buffName)
	local buffItem = self.buffNameIconList[buffType]
	if not buffItem then
		return
	end
	return buffItem.title
end

function M:onSave()
	-- 保存增加的buff
	local typeBuffList = self:getTypeBuffInfoList()
	itemSetting:setTypeBuffList(self.fullName, typeBuffList)

	itemSetting:save(self.fullName)
	-- 保存基本属性
	for prop, value in pairs(self.wantSaveData.base) do
		itemSetting:setBaseProp(self.fullName, prop, value)
	end

	--保存修改buff的属性
	local modifyBuffList = self.wantSaveData.modifyList
	for buffName, propList in pairs(modifyBuffList) do
		for prop, value in pairs(propList) do
			itemSetting:setBuffProp(buffName, prop, value)
		end
	end

	itemSetting:save(self.fullName)
end

function M:onOpen(params)
	if params then
		local item = params.item
		self.item = item
	end
	self.buffLayout = nil
	self.itemType = params and params.itemType or "item"
	self.fullName = params and params.fullName or "myplugin/16"
	self:initData()
	self:initItemName()
	self:fetchBaseProp()
	self:fetchAppendBuff()
end

return M