local entity_obj = require "editor.entity_obj"

function M:init()
	WinBase.init(self, "currentyAutoUpLevel.json")
	self:initUIName()
	self:initUI()
	self.isClose = true
end

function M:initUIName()
	self.autoLevelLayout = self:child("currencySetting-title")
	self.addBtn = self:child("currencySetting-add")
	self.gridUI = self:child("currencySetting-gird")

    self:child("currencySetting-title_0"):SetText(Lang:toText("editor.ui.upgrade.setUpgrade"))
    self:child("currencySetting-add"):SetText(Lang:toText("editor.ui.upgrade.add"))

end

function M:initUI()
	self.switchUI = UILib.createSwitch({
		index = 2000,
		value = 1
	}, function(status)
		self.wantSaveData.autoLevel = status 
		self.addBtn:SetEnabled(status)
		self.gridUI:SetEnabledRecursivly(status)
	end)
	self.autoLevelLayout:AddChildWindow(self.switchUI)
	self:subscribe(self.addBtn, UIEvent.EventButtonClick, function()
		self.levelList[#self.levelList + 1] = {
			speed = 500,
			upLevelTime = 20,
			productNumMax = entity_obj:Cmd("getProductNumMax", self.entityId),
			productNumMaxSwitch = entity_obj:Cmd("getProductNumMaxSwitch", self.entityId)
		}
		self:addItem(#self.levelList)
	end)
	self.gridUI:InitConfig(0, 0, 1)
	self.gridUI:SetAutoColumnCount(false)
end

function M:setUpLevelTime(level, value)
	self.levelList[level].upLevelTime = value
end

function M:getUpLevelTime(level)
	return self.levelList[level].upLevelTime
end

function M:getSpeed(level)
	return self.levelList[level].speed
end

function M:setSpeed(level, value)
	self.levelList[level].speed = value
end

function M:onOpen(params)
	if not params then
		print("error not the params for set currenty by entity id!!!")
		return
	end
	self.gridUI:ResetPos()
	local lastEntityId = self.entityId
	self.entityId = params
	if self.isClose or self.entityId ~= lastEntityId then
		self.isClose = false
		self.wantSaveData = {}
		self.maxLevel = nil
		self.levelList = nil
		self:updataUI()
	end
end

function M:setCurrentyIcon(fullName)
	local item = Item.CreateItem(fullName, 1)
	self.currentyTypeIconUI:SetImage(item:icon())
	self.selectIndex = self.selectIconList[item:icon()]
	self.selectFullName = fullName
end

function M:removeItem(index)
	table.remove(self.levelList, index)
	self:fetchLevelItem()
end

function M:removeLevel(index)
    local function sureFun()
        self:removeItem(index)
    end
    local function cancelFun()
        UI:closeWnd("mapEditEntitySetting")
    end
    self.tipWnd = UI:openWnd("mapEditTeamSettingTip", sureFun, cancelFun, Lang:toText("editor.ui.confirm.delect"))
    self.tipWnd:switchBtnPosition()
end

function M:addItem(index)
	local itemUI = GUIWindowManager.instance:LoadWindowFromJSON("currentyLevelItem.json")
	itemUI:child("currentyLevelItem-title"):SetText((index) .. " " ..Lang:toText("level"))
	local closeBtn = itemUI:child("currentyLevelItem-close")
	self:subscribe(closeBtn, UIEvent.EventButtonClick, function()
		self:removeLevel(index)
	end)
	
    itemUI:child("currentyLevelItem-tips"):SetText(Lang:toText("editor.ui.afterProduce"))
	--升級倒計時
	local layout1 = itemUI:child("currentyLevelItem-timeToUp")
	local timerToUpValue = self:getUpLevelTime(index - 1) / 20
	local timerToUpSlider = UILib.createSlider({value = timerToUpValue or 9999999, index = 2001}, function(value)
		self:setUpLevelTime(index - 1, value * 20)
	end)
	layout1:AddChildWindow(timerToUpSlider)

	--生产速度
	local layout2 = itemUI:child("currentyLevelItem-timeToUp_0")
	local speed = self:getSpeed(index)
	local speedSlider = UILib.createSlider({value = (speed or 9999999) / 20, index = 2002}, function(value)
		self:setSpeed(index , value * 20)
	end)
	layout2:AddChildWindow(speedSlider)
	self.gridUI:AddItem(itemUI)
end

function M:fetchLevelItem()
	self.maxLevel = 0
	self.gridUI:RemoveAllItems()
	if not self.levelList then
		self.levelList = entity_obj:Cmd("getLevelList", self.entityId)
	end
	local maxLevel = #self.levelList
	for i = 2, maxLevel do
		self:addItem(i)
	end
end

function M:updataUI()
	local isAutoLevel = entity_obj:Cmd("getAutoLevel", self.entityId)
	self.switchUI:invoke("setUIValue", isAutoLevel)
	self:fetchLevelItem()
	self.gridUI:SetEnabledRecursivly(isAutoLevel)
end

function M:onSave()
	local saveData = self.wantSaveData
	local startTime = saveData.startTime
	local initSpeed = saveData.initSpeed
	local autoLevel = saveData.autoLevel
	if startTime then
		entity_obj:Cmd("setStartTime", self.entityId, startTime)
	end
	
	if self.selectFullName then
		entity_obj:Cmd("setCurrentyType", self.entityId, self.selectFullName)
	end

	if initSpeed then
		entity_obj:Cmd("setInitSpeed", self.entityId, initSpeed)
	end
	if autoLevel ~= nil then
		entity_obj:Cmd("setAutoLevel", self.entityId, autoLevel)
	end
	entity_obj:Cmd("setLevelList", self.entityId, self.levelList)
	self.levelList = Lib.copy(self.levelList)
end

function M:onCancel()
	self.isClose = true
end

return M