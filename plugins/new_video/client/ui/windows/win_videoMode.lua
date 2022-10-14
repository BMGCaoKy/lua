---@class WinVideoMode : WinBase
local WinVideoMode = M

local Recorder = T(Lib, "Recorder")

--- @type NewVideoHelper
local NewVideoHelper = T(Lib, "NewVideoHelper")

---@type VideoEffectConfig
local VideoEffectConfig = T(Config, "VideoEffectConfig")
local HANDLE_STATE = {
	DOWN_HANDLE_LIST = 1,--展开
	UP_HANDLE_LIST = 2--收起
}
function WinVideoMode:init()
	WinBase.init(self, "videoMode.json")
	self._allEvent = {}
	self.curHideData = {}
	self.btnVideoModeSettingData = {}
	self.txtVideoModeSettingDataDec = {}
	self.imgVideoModeDataSelectImg = {}
	self.btnVideoModeTabBtn = {}
	self.imgVideoModeTabBtnSelectImg = {}
	self.txtVideoModeTabBtnDec = {}

	self.tabDataItem = {}
	self.curSelectEffectTab = 1
	self.curSelectEffect = {}
	self.curHandleState = HANDLE_STATE.DOWN_HANDLE_LIST
	self.curHideUIState = 0

	self:initUI()
	self:initEvent()
	--self:root():SetLevel(Define.UILevel.Main)
end

function WinVideoMode:initUI()
	self.lytVideoModeHandleList = self:child("videoMode-handleList")
	self.lytVideoModeHideSettingList = self:child("videoMode-hideSettingList")
	for i = 1, 3 do
		self.btnVideoModeSettingData[i] = self:child("videoMode-settingData"..i)
		self.txtVideoModeSettingDataDec[i] = self:child("videoMode-settingDataDec"..i)
		self.imgVideoModeDataSelectImg[i] = self:child("videoMode-dataSelectImg"..i)

		self.txtVideoModeSettingDataDec[i]:SetText(Lang:toText("gui.new_video.hide.setting.data"..i))
		self.curHideData[i] = false
		self.imgVideoModeDataSelectImg[i]:SetVisible(false)
	end
	self.lytVideoModeHideSettingList:SetVisible(false)

	self.btnVideoModeEffectBtn = self:child("videoMode-effectBtn")
	self.txtVideoModeEffectBtnText = self:child("videoMode-effectBtnText")
	self.txtVideoModeEffectBtnText:SetText(Lang:toText("gui.new_video.handle.tab1"))
	self.imgEffectNormalIcon = self:child("videoMode-normalIcon")
	self.imgEffectSelectIcon = self:child("videoMode-selectIcon")
	self.imgEffectNormalIcon:SetVisible(true)
	self.imgEffectSelectIcon:SetVisible(false)

	self.btnVideoModeHideUiBtn = self:child("videoMode-hideUiBtn")
	self.txtVideoModeHideUIBtnText = self:child("videoMode-hideUIBtnText")
	self.txtVideoModeHideUIBtnText:SetText(Lang:toText("gui.new_video.handle.tab2"))
	self.btnVideoModeHideUiSettingBtn = self:child("videoMode-hideUiSettingBtn")

	self.imgVideoModeSettingListBtnUpImg = self:child("videoMode-settingListBtnUpImg")
	self.imgVideoModeSettingListBtnDownImg = self:child("videoMode-settingListBtnDownImg")
	self.imgVideoModeSettingListBtnUpImg:SetVisible(false)
	self.imgVideoModeSettingListBtnDownImg:SetVisible(true)

	self.lytDownFlagPanel = self:child("videoMode-downFlagPanel")
	self.txtVideoModeHideUISettingBtnText = self:child("videoMode-hideUISettingBtnText")
	self.txtVideoModeHideUISettingBtnText:SetText(Lang:toText("gui.new_video.handle.tab3"))
	self.btnVideoModeShowOrHideHandleListBtn = self:child("videoMode-showOrHideHandleListBtn")
	self.imgVideoModeHideFlagImg = self:child("videoMode-hideFlagImg")
	self.imgVideoModeUpFlagImg = self:child("videoMode-upFlagImg")
	self.imgVideoModeDownFlagImg = self:child("videoMode-downFlagImg")
	self.lytDownFlagPanel:SetVisible(false)

	self.lytVideoModeEffectListPanel = self:child("videoMode-effectListPanel")
	self:updateEffectListPanelShow(false)
	self.lytVideoModeCloseEffect = self:child("videoMode-CloseEffect")

	for i = 1, 3 do
		self.btnVideoModeTabBtn[i] = self:child("videoMode-tabBtn"..i)
		self.imgVideoModeTabBtnSelectImg[i] = self:child("videoMode-TabBtnSelectImg"..i)
		self.txtVideoModeTabBtnDec[i] = self:child("videoMode-tabBtnDec"..i)
		self.txtVideoModeTabBtnDec[i]:SetText(Lang:toText("gui.new_video.tab"..i))

		if self.curSelectEffectTab == i then
			self.imgVideoModeTabBtnSelectImg[i]:SetVisible(true)
			self.txtVideoModeTabBtnDec[i]:SetTextColor({0, 0, 0, 1})
		else
			self.imgVideoModeTabBtnSelectImg[i]:SetVisible(false)
			self.txtVideoModeTabBtnDec[i]:SetTextColor({255, 255, 255, 1})
		end
	end

	self.lytRecordPanel = self:child("videoMode-recordPanel")
	self.lytRecordPanel:SetVisible(false)
	self.lytRecordHidePanel = self:child("videoMode-recordHidePanel")
	self.lytRecordHidePanel:SetVisible(false)
	self.imgHideRecordImg = self:child("videoMode-hideRecordImg")
	self.txtHideRecordTime = self:child("videoMode-hideRecordTime")
	self.imgHideRecordImg:SetVisible(false)
	self.btnWaitRecordBtn = self:child("videoMode-waitRecordBtn")
	self.btnRecordingBtn = self:child("videoMode-recordingBtn")
	self.imgRecordDownIcon = self:child("videoMode-recordDownIcon")
	self.txtRecordDownStr = self:child("videoMode-recordDownStr")
	self.txtRecordTimeStr = self:child("videoMode-recordTimeStr")
	self.btnWaitRecordBtn:SetVisible(false)
	self.btnRecordingBtn:SetVisible(false)
	self.imgRecordDownIcon:SetVisible(false)

	self.lytVideoModeTabDataList = self:child("videoMode-tabDataList")
	self.gridViewVideoModeTabDataList = UIMgr:new_widget("grid_view")
	self.gridViewVideoModeTabDataList:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.gridViewVideoModeTabDataList:InitConfig(0, 10, 1)
	self.gridViewVideoModeTabDataList:SetMoveAble(true)
	self.gridViewVideoModeTabDataList:SetvScorllMoveAble(true)
	self.gridViewVideoModeTabDataList:SetAutoColumnCount(false)
	self.lytVideoModeTabDataList:AddChildWindow(self.gridViewVideoModeTabDataList)

	self.btnVideoModeExitBtn = self:child("videoMode-exitBtn")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WinVideoMode:initEvent()

	self:subscribe(self.btnWaitRecordBtn, UIEvent.EventButtonClick, function()
		self:updateRecordState(Define.newVideoRecordState.WaitStart)
		Plugins.CallTargetPluginFunc("report", "report", "video_start",  {}, Me)
	end)

	self:subscribe(self.btnRecordingBtn, UIEvent.EventButtonClick, function()
		NewVideoHelper:stopNewVideoRecord()
	end)

	for i = 1, 3 do
		self:subscribe(self.btnVideoModeSettingData[i], UIEvent.EventButtonClick, function()
			if not self.lytVideoModeHideSettingList:IsVisible() then
				return
			end

			if self.curHideData[i] then
				self:setCurHideData(i, false)
			else
				self:setCurHideData(i, true)
			end
		end)
	end

	self:subscribe(self.lytVideoModeCloseEffect, UIEvent.EventWindowClick, function()
		self:updateEffectViewShow()
	end)

	self:subscribe(self.btnVideoModeEffectBtn, UIEvent.EventButtonClick, function()
		local defaultData = {
			entrance = 0,
			filter = 1,
			hideUI = 0,
			hideSetting = 0,
			pull = 0,
			push = 0,
			exit = 0,
		}
		Plugins.CallTargetPluginFunc("report", "report", "video_press", defaultData, Me)
		self:updateEffectViewShow()
	end)
	self:subscribe(self.btnVideoModeHideUiBtn, UIEvent.EventButtonClick, function()
		local defaultData = {
			entrance = 0,
			filter = 0,
			hideUI = 1,
			hideSetting = 0,
			pull = 0,
			push = 0,
			exit = 0,
		}
		Plugins.CallTargetPluginFunc("report", "report", "video_press", defaultData, Me)
		Recorder:SetHideUi(true)
		self:updateEffectListPanelShow(false)
		self.imgVideoModeHideFlagImg:SetVisible(true)
		self:setHandleListState(true)
		self.curHandleState = HANDLE_STATE.UP_HANDLE_LIST
	end)
	self:subscribe(self.btnVideoModeHideUiSettingBtn, UIEvent.EventButtonClick, function()
		local defaultData = {
			entrance = 0,
			filter = 0,
			hideUI = 0,
			hideSetting = 1,
			pull = 0,
			push = 0,
			exit = 0,
		}
		Plugins.CallTargetPluginFunc("report", "report", "video_press", defaultData, Me)
		if self.lytVideoModeHideSettingList:IsVisible() then
			self:setHideSettingState(false)
		else
			self:setHideSettingState(true)
		end
	end)
	self:subscribe(self.btnVideoModeShowOrHideHandleListBtn, UIEvent.EventButtonClick, function()
		if self.curHandleState == HANDLE_STATE.DOWN_HANDLE_LIST then
			self.curHandleState = HANDLE_STATE.UP_HANDLE_LIST
			self:setHandleListState(true)
			local defaultData = {
				entrance = 0,
				filter = 0,
				hideUI = 0,
				hideSetting = 0,
				pull = 1,
				push = 0,
				exit = 0,
			}
			Plugins.CallTargetPluginFunc("report", "report", "video_press", defaultData, Me)
			return
		end

		if self.curHandleState == HANDLE_STATE.UP_HANDLE_LIST then
			self.imgVideoModeHideFlagImg:SetVisible(false)
			self.curHandleState = HANDLE_STATE.DOWN_HANDLE_LIST
			self:setHandleListState(false)
			Recorder:SetHideUi(false)
			local defaultData = {
				entrance = 0,
				filter = 0,
				hideUI = 0,
				hideSetting = 0,
				pull = 0,
				push = 1,
				exit = 0,
			}
			Plugins.CallTargetPluginFunc("report", "report", "video_press", defaultData, Me)
			return
		end
	end)

	for i = 1, 3 do
		self:subscribe(self.btnVideoModeTabBtn[i], UIEvent.EventButtonClick, function()
			if self.curSelectEffectTab == i then
				return
			end
			self.curSelectEffectTab = i

			for j = 1, 3 do
				if self.curSelectEffectTab == j then
					self.imgVideoModeTabBtnSelectImg[j]:SetVisible(true)
					self.txtVideoModeTabBtnDec[j]:SetTextColor({0, 0, 0, 1})
				else
					self.imgVideoModeTabBtnSelectImg[j]:SetVisible(false)
					self.txtVideoModeTabBtnDec[j]:SetTextColor({255, 255, 255, 1})
				end
			end

			self:showEffectData(i)
		end)
	end

	self:subscribe(self.btnVideoModeExitBtn, UIEvent.EventButtonClick, function()
		self:closeCurWnd()
	end)
end

function WinVideoMode:closeCurWnd()
	self:onHide()
end

function WinVideoMode:setHandleListState(isUp)
	if isUp then
		self.lytVideoModeHandleList:SetYPosition({0, -80})
		self.btnVideoModeExitBtn:SetVisible(false)
		if self.lytVideoModeHideSettingList:IsVisible() then
			self.lytVideoModeHideSettingList:SetVisible(false)
		end

		self.imgVideoModeUpFlagImg:SetVisible(false)
		self.lytDownFlagPanel:SetVisible(true)
	else
		self.lytVideoModeHandleList:SetYPosition({0, 0})
		self.btnVideoModeExitBtn:SetVisible(true)

		self.imgVideoModeUpFlagImg:SetVisible(true)
		self.lytDownFlagPanel:SetVisible(false)
	end
end

function WinVideoMode:updateEffectViewShow()
	if self.lytVideoModeEffectListPanel:IsVisible() then
		self:setEffectListPanelState(false)
	else
		self:updateEffectListPanelShow(true)
		self:setEffectListPanelState(true)
	end
end

function WinVideoMode:setEffectListPanelState(isShow)
	if not isShow then
		self:updateEffectListPanelShow(false)
	else
		self:updateEffectListPanelShow(true)
		self:showEffectData(self.curSelectEffectTab)
	end
end

function WinVideoMode:updateEffectListPanelShow(isShow)
	self.lytVideoModeEffectListPanel:SetVisible(isShow)
	self.imgEffectNormalIcon:SetVisible(not isShow)
	self.imgEffectSelectIcon:SetVisible(isShow)
end

function WinVideoMode:showEffectData(tab)
	local cfg = VideoEffectConfig:getCfgByTabId(tab)
	if cfg then
		self.gridViewVideoModeTabDataList:RemoveAllItems()
		self.tabDataItem = {}
		for _, data in pairs(cfg) do
			local item = UIMgr:new_widget("videoEffecDataItem", function(index)
				if self.curSelectEffect[tab] == index then
					if self.tabDataItem[index] then
						self.tabDataItem[index]:invoke("setSelectState", false)
					end

					self.curSelectEffect[tab] = 0
					Recorder:OnSelect(data, false)
					return
				end
				self.curSelectEffect[tab] = index

				for sortIndex, dataItem in pairs(self.tabDataItem) do
					if sortIndex ~= index then
						dataItem:invoke("setSelectState", false)
					end
				end

				local defaultData = {
					videoSelectId = tab .. "_" .. index,
				}
				Plugins.CallTargetPluginFunc("report", "report", "video_select", defaultData, Me)

				Recorder:OnSelect(data, true)
			end)

			if item then
				item:SetArea({ 0, 0 }, { 0, 0 }, { 0, 116 }, { 0, 145 })
				self.gridViewVideoModeTabDataList:AddItem(item)

				local isSelected = false
				if data.sortIndex == (self.curSelectEffect[tab] or 0) then
					isSelected = true
				end
				item:invoke("setData", data, isSelected)
				self.tabDataItem[data.sortIndex] = item
			else
				Lib.logDebug("Error：item is nil when  UIMgr:new_widget(videoEffecDataItem)")
			end

		end
	end
end

function WinVideoMode:setHideSettingState(isShow)
	if not isShow then
		self.lytVideoModeHideSettingList:SetVisible(false)
		self.imgVideoModeSettingListBtnUpImg:SetVisible(false)
		self.imgVideoModeSettingListBtnDownImg:SetVisible(true)
	else
		self.lytVideoModeHideSettingList:SetVisible(true)
		self.imgVideoModeSettingListBtnUpImg:SetVisible(true)
		self.imgVideoModeSettingListBtnDownImg:SetVisible(false)
	end
end

---@param index number 数据索引：1-隐藏名字；2-隐藏玩家；3-隐藏自己
---@param isSelected boolean 是否选中隐藏选项
function WinVideoMode:setCurHideData(index, isSelected)
	self.curHideData[index] = isSelected
	if self.imgVideoModeDataSelectImg[index] then
		self.imgVideoModeDataSelectImg[index]:SetVisible(isSelected)
	end

	if index == 1 then
		Recorder:SetHideName(isSelected)
	elseif index == 2 then
		Recorder:SetHideOtherPlayers(isSelected)
	elseif index == 3 then
		Recorder:SetHideSelf(isSelected)
	end
end

--注册event事件监听，注意这里的事件是show的时候注册，close的时候注销的，常驻事件可在initEvent里面注册
function WinVideoMode:subscribeEvent()
	self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_UPDATE_VIDEO_RECORD_STATE, function(state)
		self:updateRecordState(state)
	end)
end

--界面数据初始化
function WinVideoMode:initView()
	for i = 1, 3 do
		self.txtVideoModeSettingDataDec[i]:SetText(Lang:toText("gui.new_video.hide.setting.data"..i))
		self.curHideData[i] = false
		self.imgVideoModeDataSelectImg[i]:SetVisible(false)
	end
	self.lytVideoModeHideSettingList:SetVisible(false)
	self.txtVideoModeEffectBtnText:SetText(Lang:toText("gui.new_video.handle.tab1"))
	self.txtVideoModeHideUIBtnText:SetText(Lang:toText("gui.new_video.handle.tab2"))
	self.imgVideoModeSettingListBtnUpImg:SetVisible(false)
	self.imgVideoModeSettingListBtnDownImg:SetVisible(true)
	self.txtVideoModeHideUISettingBtnText:SetText(Lang:toText("gui.new_video.handle.tab3"))
	self:updateEffectListPanelShow(false)

	for i = 1, 3 do
		self.txtVideoModeTabBtnDec[i]:SetText(Lang:toText("gui.new_video.tab"..i))
		if self.curSelectEffectTab == i then
			self.imgVideoModeTabBtnSelectImg[i]:SetVisible(true)
			self.txtVideoModeTabBtnDec[i]:SetTextColor({0, 0, 0, 1})
		else
			self.imgVideoModeTabBtnSelectImg[i]:SetVisible(false)
			self.txtVideoModeTabBtnDec[i]:SetTextColor({255, 255, 255, 1})
		end
	end
	self:setHandleListState(false)
	self.imgVideoModeHideFlagImg:SetVisible(false)
end

function WinVideoMode:onHide()
	UI:closeWnd("videoMode")
end

function WinVideoMode:emptyData()
	local defaultData = {
		entrance = 0,
		filter = 0,
		hideUI = 0,
		hideSetting = 0,
		pull = 0,
		push = 0,
		exit = 1,
	}
	Plugins.CallTargetPluginFunc("report", "report", "video_press", defaultData, Me)
	Recorder:OnQuit()
	self:clearData()
end

function WinVideoMode:updateRecordState(state)
	self.curRecordState = state
	if self.curRecordState == Define.newVideoRecordState.NoneRecord then
		self.btnWaitRecordBtn:SetVisible(true)
		self.btnRecordingBtn:SetVisible(false)
		self.imgRecordDownIcon:SetVisible(false)
		self.imgHideRecordImg:SetVisible(false)
		self:cleanRecordTimer()
	elseif self.curRecordState == Define.newVideoRecordState.WaitStart then
		self.btnWaitRecordBtn:SetVisible(false)
		self.btnRecordingBtn:SetVisible(false)
		self.imgRecordDownIcon:SetVisible(true)
		self.imgHideRecordImg:SetVisible(false)
		self.recordPassTime = 0
		self.waitTotalTime = 3
		self.txtRecordDownStr:SetText(self.waitTotalTime)
		self:startRecordTimer()
	elseif self.curRecordState == Define.newVideoRecordState.WaitConfirm then
		self.btnWaitRecordBtn:SetVisible(false)
		self.btnRecordingBtn:SetVisible(false)
		self.imgRecordDownIcon:SetVisible(true)
		self.imgHideRecordImg:SetVisible(false)
		self.recordPassTime = 0
		self.waitTotalTime = 0
		self.txtRecordDownStr:SetText(self.waitTotalTime)
		self:cleanRecordTimer()
	elseif self.curRecordState == Define.newVideoRecordState.Recording then
		self.btnWaitRecordBtn:SetVisible(false)
		self.btnRecordingBtn:SetVisible(true)
		self.imgRecordDownIcon:SetVisible(false)
		self.imgHideRecordImg:SetVisible(true)
		self.recordPassTime = 0
		local hours, min, second = Lib.timeFormatting(self.recordPassTime)
		self.txtRecordTimeStr:SetText(string.format("%02d:%02d", min, second))
		self.txtHideRecordTime:SetText(string.format("%02d:%02d", min, second))
		self:startRecordTimer()
	end
end

function WinVideoMode:updateRecordShow()
	self.curRecordState = Define.newVideoRecordState.NoneRecord
	self.recordPassTime = 0
	if NewVideoHelper:isCanNewVideoRecord() then
		self.lytRecordPanel:SetVisible(true)
		self.lytRecordHidePanel:SetVisible(true)
		if NewVideoHelper:isGoingNewVideoRecord() then
			self:updateRecordState(Define.newVideoRecordState.Recording)
		else
			self:updateRecordState(Define.newVideoRecordState.NoneRecord)
		end
	else
		self.lytRecordPanel:SetVisible(false)
		self.lytRecordHidePanel:SetVisible(false)
		Plugins.CallTargetPluginFunc("report", "report", "error_not_available",  {}, Me)
	end
end

function WinVideoMode:startRecordTimer()
	self:cleanRecordTimer()
	self.recordVideoTimer = World.Timer(20, function()
		self.recordPassTime =  self.recordPassTime + 1
		if self.curRecordState == Define.newVideoRecordState.WaitStart then
			local remainTime = self.waitTotalTime - self.recordPassTime
			self.txtRecordDownStr:SetText(remainTime)
			if remainTime <= 0 then
				self:cleanRecordTimer()
				NewVideoHelper:beginNewVideoRecord()
			end
		elseif self.curRecordState == Define.newVideoRecordState.Recording then
			local hours, min, second = Lib.timeFormatting(self.recordPassTime)
			self.txtRecordTimeStr:SetText(string.format("%02d:%02d", min, second))
			self.txtHideRecordTime:SetText(string.format("%02d:%02d", min, second))
		end
		return true
	end)
end

function WinVideoMode:cleanRecordTimer()
	if self.recordVideoTimer then
		self.recordVideoTimer()
		self.recordVideoTimer = nil
	end
end

function WinVideoMode:onShow(isShow)
	if isShow then
		if not UI:isOpen(self) then
			UI:openWnd("videoMode")
		else
			self:onHide()
		end
	else
		self:onHide()
	end
end

function WinVideoMode:onOpen()
	self.startShowTime = os.time()
	self:initView()
	self:subscribeEvent()

	local defaultData = {
		entrance = 1,
		filter = 0,
		hideUI = 0,
		hideSetting = 0,
		pull = 0,
		push = 0,
		exit = 0,
	}
	Plugins.CallTargetPluginFunc("report", "report", "video_press", defaultData, Me)

	self:cleanRecordTimer()
	self:updateRecordShow()
end

function WinVideoMode:onClose()

	if self.curRecordState == Define.newVideoRecordState.Recording then
		NewVideoHelper:stopNewVideoRecord()
	end
	self:cleanRecordTimer()

	if self.startShowTime then
		local defaultData = {
			stayVideoTime = os.time() - self.startShowTime,
		}
		Plugins.CallTargetPluginFunc("report", "report", "video_time", defaultData, Me)
	end
	self:clearData()
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
		self._allEvent = {}
	end
	self:emptyData()
end

function WinVideoMode:clearData()
	self.curHideUIState = 0
	self.curHideData = {}
	self.tabDataItem = {}
	self.curSelectEffectTab = 1
	self.curSelectEffect = { }
	self.curHandleState = HANDLE_STATE.DOWN_HANDLE_LIST
end

return WinVideoMode
