local entity_obj = require "editor.entity_obj"
local globalSetting = require "editor.setting.global_setting"

local enumColorSet = {"[C=FFFF0000]", "[C=FF33FF00]", "[C=FFFFFF00]", "[C=FF0000FF]"}
local colorImage = {"set:setting_global.json image:icon_red.png",
                    "set:setting_global.json image:icon_green.png",
                    "set:setting_global.json image:icon_yellow.png",
					"set:setting_global.json image:icon_bule.png"}
					
function M:init()
	WinBase.init(self, "currentyTeam.json")
	self:initUIName()
	self:initUI()
	self.isClose = true
    self:child("currencySetting-title_0"):SetText(Lang:toText("editor.ui.selectTeam"))
end

function M:initUIName()
	self.autoLevelLayout = self:child("currencySetting-title")
	self.addBtn = self:child("currencySetting-add")
    self.addBtn:SetText(Lang:toText("editor.ui.editTeam"))
	self.gridUI = self:child("currencySetting-gird")
	self.tipsUI = self:child("currencySetting-tips")
end

function M:initUI()
	self.switchUI = UILib.createSwitch({
		index = 2003,
		value = 1
	}, function(status)
		if not status then
			self.wantSaveData.teamID = nil
			self.canSwitch = false
		else
			self.canSwitch = true
			self.wantSaveData.teamID = self.teamID
		end
		--self.addBtn:SetEnabled(status)
		self.gridUI:SetEnabledRecursivly(status)
	end)
	self.autoLevelLayout:AddChildWindow(self.switchUI)
	self:subscribe(self.addBtn, UIEvent.EventButtonClick, function()
		UI:openWnd("mapEditGlobalSetting",  3)
		if self.uperWnd then
			self.uperWnd:root():SetLevel(40)
		end
	end)
	self.gridUI:InitConfig(0, 30, 1)
	self.gridUI:SetAutoColumnCount(false)
	self.tipsUI:SetText(Lang:toText("not_team_to_edit"))
end

function M:initUIShow()
	local function getTeamInfo()
		local result = globalSetting:getTeamMsg()
		return result
	end
	local teamInfo = getTeamInfo()
	self.teamInfo = teamInfo
	if teamInfo and #teamInfo > 0 then
		self.tipsUI:SetVisible(false)
		self.gridUI:SetVisible(true)
	else
		self.tipsUI:SetVisible(true)
		self.gridUI:SetVisible(false)
	end
end

function M:onOpen(params, uperWnd)
	self.uperWnd = uperWnd
	if not params then
		print("error not the params for set currenty by entity id!!!")
		return
	end
	self.changeSucribeFunc = Lib.subscribeEvent(Event.EVENT_TEAM_SETTING_CHANGE, function()
		self:initUIShow()
		self:fetchTeamItem()
		self:selectItem(self.teamID, true)
		self.gridUI:SetEnabledRecursivly(self.canSwitch)
	end)
	self:initUIShow()
	self.gridUI:ResetPos()
	local lastEntityId = self.entityId
	self.entityId = params
	-- if self.isClose or self.entityId ~= lastEntityId then
		self.isClose = false
		self.wantSaveData = {}
		self.btnList = {}
		self:updataUI()
	-- end
end

function M:setCurrentyIcon(fullName)
	local item = Item.CreateItem(fullName, 1)
	self.currentyTypeIconUI:SetImage(item:icon())
	self.selectIndex = self.selectIconList[item:icon()]
	self.selectFullName = fullName
end

function M:selectItem(index, ignore)
	for k, btn in pairs(self.btnList) do
		if k ~= index then
			btn:SetSelected(false)
		elseif ignore then
			btn:SetSelected(true)
		end
	end
end

function M:addItem(index, itemData)
	local function getColor()
		for k, colorName in pairs(enumColorSet) do
			if colorName == itemData.color then
				return colorImage[k]
			end
		end
	end

	local function getText()
		local text = Lang:toText("editor.ui.team_"..itemData.color)
		text = text .. "-" .. itemData.memberLimit .. Lang:toText("people")
		return text
	end

	local color = getColor() 
	local text = getText()
	local itemUI = GUIWindowManager.instance:LoadWindowFromJSON("teamItem.json")
	itemUI:child("teamItem-icon"):SetImage(color)
	itemUI:child("teamItem-text"):SetText(Lang:toText(text))
	local btn = itemUI:child("teamItem-btn")
	self.btnList[index] = btn
	self:subscribe(btn, UIEvent.EventRadioStateChanged, function(btn)
		if btn:IsSelected() then
			self.teamID = index
			self:selectItem(index)
		end
	end)
	self.gridUI:AddItem(itemUI)
end

function M:fetchTeamItem()
	self.gridUI:RemoveAllItems()
	self.btnList = {}
	local teams = {
		{
			id = 1,
			color = "image/icon/blue.png",
			text = "blue",
		},
		{
			id = 1,
			color = "image/icon/red.png",
			text = "red",
		},		
		{
			id = 1,
			color = "image/icon/yellow.png",
			text = "yellow",
		},
		{
			id = 1,
			color = "image/icon/green.png",
			text = "green",
		}
	}
	self.teamInfo = globalSetting:getTeamMsg() 
	for i, value in ipairs(self.teamInfo or {}) do
		self:addItem(i, value)
	end
end

function M:updataUI()
	local teamID = entity_obj:Cmd("getTeamID", self.entityId)
	self.canSwitch = teamID and true or false
	self.switchUI:invoke("setUIValue", self.canSwitch)
	self:fetchTeamItem()
	self.gridUI:SetEnabledRecursivly(self.canSwitch)
	self:selectItem(teamID, true)
	self.teamID = teamID
end

function M:onSave()
	self.wantSaveData.teamID = self.teamID
	if not self.canSwitch then
		self.wantSaveData.teamID = nil
	end
	entity_obj:Cmd("setTeamID", self.entityId, self.wantSaveData.teamID)
    entity_obj:Cmd("setTeamPic", self.entityId, self.wantSaveData.teamID)
    entity_obj:Cmd("showTeamPic", self.entityId, self.wantSaveData.teamID)
end

function M:onCancel()
	self.wantSaveData = {}
	self.canSwitch = nil
	self.teamID = nil
	self.isClose = true
end

function M:onClose()
	if self.changeSucribeFunc then
		self.changeSucribeFunc()
	end
end
return M