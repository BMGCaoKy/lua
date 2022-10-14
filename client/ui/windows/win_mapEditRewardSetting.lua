local global_setting = require "editor.setting.global_setting"
local dataIndex = {"killReward", "bedBreakReward"}
local sliderIndex = {23, 24}
local buttonIndex = {28, 29}
local rewardData

function M:init()
	WinBase.init(self, "rewardSetting.json")
	self:initUI()
	self:initData()
	self.sureBtn = self:child("reward-sureBtn")
	self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
		global_setting:saveKillReward(rewardData[1], true)
		global_setting:saveBedBreakReward(rewardData[2], true)
		UI:closeWnd(self)
	end)
	self:initComponents(1)
	self:initComponents(2)
end

function M:initUI()
	self.setLayout = self:child("reward-layout")
	self.setLayout:InitConfig(0, 20, 1)
	self.setLayout:SetAutoColumnCount(false)
	self.setLayout:RemoveAllItems()
end

function M:initComponents(key)
	local slider = UILib.createSlider({
			index = sliderIndex[key], 
			value = rewardData[key].addScore.score
		}, function(value, isInfinity)
			rewardData[key].addScore.score = value
			rewardData[key].addScore.enable = tonumber(value) ~= 0
		end)
	self.setLayout:AddItem(slider)
	local button = UILib.createButton({
		index = buttonIndex[key],
	}, function()
		CGame.instance:onEditorDataReport("click_global_setting_rewards_settings", "")
		UI:openWnd("mapEditRewardSettingDetail", dataIndex[key])
	end)
	self.setLayout:AddItem(button)
end

function M:initData()
	rewardData = {}
	rewardData[1] = global_setting:getValByKey("killReward") or {}
	rewardData[2] = global_setting:getValByKey("bedBreakReward") or {}
end

function M:saveData()
end

function M:onOpen()
	self:initData()
end

function M:onReload(reloadArg)

end

function M:onClose()
	
end

return M