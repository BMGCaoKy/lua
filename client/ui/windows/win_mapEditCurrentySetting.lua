local entity_obj = require "editor.entity_obj"
local uiNameList = {"block", "equip", "bagWeaponList", "dropItemList", "shopResourceList"}

function M:init()
	WinBase.init(self, "currencySetting.json")
	self:initUIName()
	self:initUI()
	self.isClose = true
end

function M:initUIName()
	self.gridUI = self:child("currencySetting-gird")
end

function M:switchAddItemUI(isShowAddItem)
	local icon = self.selectItemIcon
	if not isShowAddItem then
		if self.itemType == "block" then
			icon = ObjectPicture.Instance():buildBlockPicture(Block.GetNameCfgId(self.selectFullName))
		end
		self.itemIcon:SetImage(icon)
	end
	self.itemIcon:SetVisible(not isShowAddItem)
	self.itemIconClose:SetVisible(not isShowAddItem)
	self.addItemBtn:SetVisible(isShowAddItem)
end

function M:initUI()
	self:child("currencySetting-title"):SetText(Lang:toText("editor.ui.currencyType"))
	self:child("currencySetting-title_0"):SetText(Lang:toText("editor.ui.produceTime"))
	self.gridUI:InitConfig(0, 30, 1)
	self.gridUI:SetMoveAble(false)
	self.gridUI:SetXPosition({0, 100})
	self.gridUI:SetAutoColumnCount(false)
	self.addItemLayout = self:child("currencySetting-AddItem")
	self.itemIcon = self:child("currencySetting-AddItem-ItemIcon")
	self.addItemBtn = self:child("currencySetting-AddItem-addItemBtn")
	self.itemIconClose = self:child("currencySetting-AddItem-Close")

	self:subscribe(self.itemIconClose, UIEvent.EventButtonClick, function()
		self:switchAddItemUI(true)
	end)

	self:subscribe(self.addItemBtn, UIEvent.EventButtonClick, function()
		UI:openMultiInstanceWnd("mapEditItemBagSelect", {uiNameList = uiNameList, backFunc = function(item)
			self:setCurrentyItem(item:full_name(), item:icon(), item:type())
		end})
	end)
end
function M:onOpen(params)
	if not params then
		print("error not the params for set currenty by entity id!!!")
		return
	end
	local lastEntityId = self.entityId
	self.entityId = params
	if self.isClose or self.entityId ~= lastEntityId then
		self.isClose = false
		self.wantSaveData = {}
		self:updataUI()
	end
end

function M:setCurrentyItem(fullName, icon, itemType)
	self.selectFullName = fullName
	self.selectItemIcon = icon
	self.itemType = itemType
	self:switchAddItemUI(not fullName)
end

function M:updataUI()
	local uiOffsetX = 0
	if World.Lang ~= "zh_CN" then
		uiOffsetX = 80
	end
	self.addItemLayout:SetXPosition({0, self.addItemLayout:GetXPosition()[2] + uiOffsetX})
	local function addItem(value, descIndex, func, childItemType, isNoAdd)
		local childItem
		local createChildFun = UILib["create" .. childItemType]
		if not createChildFun then
			print("childItemType is error-------------------")
			return
		end
		childItem = createChildFun({value = value, index = descIndex}, function(value)
			if func then
				func(value)
			end
		end)
		childItem:invoke("setSliderUiOffsetX", uiOffsetX)
		if not isNoAdd then
			self.gridUI:AddItem(childItem)
		end
		return childItem
	end

	local function setStartProductTime(value)
		self.wantSaveData.startTime = value * 20
	end

	local function setInitSpeed(value)
		self.wantSaveData.initSpeed = value * 20
	end

	local productMaxUi
	local function setProductNumMaxSwitch(value)
		self.wantSaveData.productNumMaxSwitch = value
		if not value then
			self.gridUI:RemoveItem(productMaxUi)
		else
			self.gridUI:AddItem(productMaxUi)
		end
	end

	local function setProductNumMax(value)
		self.wantSaveData.productNumMax = value
	end

	local fullName = entity_obj:Cmd("getCurrentyType", self.entityId)
	local itemIcon = entity_obj:Cmd("getCurrentyIcon", self.entityId)
	local itemType = entity_obj:Cmd("getResPointItemType", self.entityId)
	local startProductTime = entity_obj:Cmd("getStartTime", self.entityId) or 20
	local initSpeed = entity_obj:Cmd("getInitSpeed", self.entityId) or 20
	local productNumMaxSwitch = entity_obj:Cmd("getProductNumMaxSwitch", self.entityId) or false
	local productNumMax = entity_obj:Cmd("getProductNumMax", self.entityId) or 1
	local childItemData = {
		{
			index = 100,
			value = startProductTime / 20,
			itemType = "Slider",
			func = setStartProductTime
		},
		{
			index = 2002,
			value = initSpeed / 20,
			itemType = "Slider",
			func = setInitSpeed
		},
		{
			index = 5032,
			value = productNumMaxSwitch,
			itemType = "Switch",
			func = setProductNumMaxSwitch
		},
		{
			index = 5033,
			value = productNumMax,
			itemType = "Slider",
			func = setProductNumMax,
			isNoAdd = not productNumMaxSwitch,
			isSwitchChildItem = true
		},
	}
	self:setCurrentyItem(fullName, itemIcon, itemType)
	self.gridUI:RemoveAllItems()

	for _, itemData in pairs(childItemData) do
		local item = addItem(itemData.value, itemData.index, itemData.func, itemData.itemType, itemData.isNoAdd)
		if itemData.isSwitchChildItem then
			productMaxUi = item
		end
	end
end

function M:onSave()
	if self.wantSaveData.startTime then
		entity_obj:Cmd("setStartTime", self.entityId, self.wantSaveData.startTime)
	end
	if self.wantSaveData.initSpeed then
		entity_obj:Cmd("setInitSpeed", self.entityId, self.wantSaveData.initSpeed)
	end

	entity_obj:Cmd("setProductNumMaxSwitch", self.entityId, self.wantSaveData.productNumMaxSwitch or false)
	if self.wantSaveData.productNumMaxSwitch then
		entity_obj:Cmd("setProductNumMax", self.entityId, self.wantSaveData.productNumMax or 1)
	end

	if self.selectFullName then
		entity_obj:Cmd("setCurrentyType", self.entityId, self.selectFullName)
	end

	if self.selectItemIcon then
		entity_obj:Cmd("setCurrentyIcon", self.entityId, self.selectItemIcon)
	end

	if self.itemType then
		entity_obj:Cmd("setResPointItemType", self.entityId, self.itemType)
	end
end

function M:onCancel()
	self.isClose = true
end

return M