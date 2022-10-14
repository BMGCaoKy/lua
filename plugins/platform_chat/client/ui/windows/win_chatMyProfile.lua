---@class WinChatMyProfile : WinBase
local WinChatMyProfile = M
local chatSetting = World.cfg.chatSetting
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

function WinChatMyProfile:init()
	WinBase.init(self, "ChatMyProfile.json")
	self:initUI()
	self:initEvent()

	if World.cfg.chatSetting and World.cfg.chatSetting.chatLevel then
		self:root():SetLevel(World.cfg.chatSetting.chatLevel)
	end
end

function WinChatMyProfile:initUI()
	self.imgBackBg = self:child("ChatMyProfile-back_Bg")
	self.lytPanel = self:child("ChatMyProfile-panel")
	self.imgPanelBg = self:child("ChatMyProfile-panelBg")
	self.imgTitleBg = self:child("ChatMyProfile-title_Bg")
	self.imgTitleBgMaskPattern = self:child("ChatMyProfile-title_BgMaskPattern")
	self.txtTitleName = self:child("ChatMyProfile-title_name")
	self.btnCloseBtn = self:child("ChatMyProfile-closeBtn")
	self.lytLeftPanel = self:child("ChatMyProfile-leftPanel")
	self.imgLeftPanelBg = self:child("ChatMyProfile-leftPanelBg")
	self.lytHeadPanel = self:child("ChatMyProfile-headPanel")
	self.imgHeadIcon = self:child("ChatMyProfile-headIcon")
	self.imgHeadFrame = self:child("ChatMyProfile-headFrame")
	self.imgLeftSexIcon = self:child("ChatMyProfile-leftSexIcon")
	self.txtLeftNameTxt = self:child("ChatMyProfile-leftNameTxt")
	self.imgLeftCareerIcon = self:child("ChatMyProfile-leftCareerIcon")
	self.txtLeftCareerTxt = self:child("ChatMyProfile-leftCareerTxt")
	self.imgLeftLvIcon = self:child("ChatMyProfile-leftLvIcon")
	self.txtLeftLvTxt = self:child("ChatMyProfile-leftLvTxt")
	self.imgLeftTimeIcon = self:child("ChatMyProfile-leftTimeIcon")
	self.txtLeftTimeTxt = self:child("ChatMyProfile-leftTimeTxt")
	self.imgBirthPanel = self:child("ChatMyProfile-birthPanel")
	self.txtBirthTitle = self:child("ChatMyProfile-birthTitle")
	self.txtBirthDate = self:child("ChatMyProfile-birthDate")
	self.imgTribalPanel = self:child("ChatMyProfile-tribalPanel")
	self.txtTribalTitle = self:child("ChatMyProfile-tribalTitle")
	self.txtTribalDate = self:child("ChatMyProfile-tribalDate")
	self.imgConstellationPanel = self:child("ChatMyProfile-constellationPanel")
	self.txtConstellationTitle = self:child("ChatMyProfile-constellationTitle")
	self.txtConstellationDate = self:child("ChatMyProfile-constellationDate")
	self.lytSignPanel = self:child("ChatMyProfile-signPanel")
	self.txtSignTxt = self:child("ChatMyProfile-signTxt")
	self.lytTagPanel = self:child("ChatMyProfile-tagPanel")
	self.txtTagTxt = self:child("ChatMyProfile-tagTxt")
	self.lytTagList = self:child("ChatMyProfile-tagList")
	self.btnConfirmBtn = self:child("ChatMyProfile-confirmBtn")
	self.txtConfirmTxt = self:child("ChatMyProfile-confirmTxt")

	self.gvSignTxt = UIMgr:new_widget("grid_view")
	self.lytSignPanel:AddChildWindow(self.gvSignTxt)
	self.gvSignTxt:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.gvSignTxt:InitConfig(0, 5, 1)
	self.gvSignTxt:AddItem(self.txtSignTxt)

	self.tagGridView = UIMgr:new_widget("grid_view", self.lytTagList)
	self.tagGridView:SetAutoColumnCount(false)
	self.tagGridView:InitConfig(10, 5, 4)
	self.tagAdapter = UIMgr:new_adapter("common",100,33, "chatTagItem", "ChatTagItem.json")
	self.tagGridView:invoke("setAdapter", self.tagAdapter)


	self.txtBirthDate:SetText("")
	self.txtConstellationDate:SetText("")
	self.txtTribalDate:SetText("")

	self.txtTitleName:SetText(Lang:toText("ui.chat.profile.title"))
	self.txtBirthTitle:SetText(Lang:toText("ui.chat.profile.birth"))
	self.txtConstellationTitle:SetText(Lang:toText("ui.chat.profile.constellation"))
	self.txtTribalTitle:SetText(Lang:toText("ui.chat.profile.tribal"))
	self.txtTagTxt:SetText(Lang:toText("ui.chat.profile.tag"))
	self.txtConfirmTxt:SetText(Lang:toText("ui.chat.profile.confirm"))

	self.leftNodePosY = {
		self.imgLeftSexIcon:GetYPosition(),
		self.imgLeftCareerIcon:GetYPosition(),
		self.imgLeftLvIcon:GetYPosition(),
		self.imgLeftTimeIcon:GetYPosition(),
	}
	self.leftIconNode = {
		self.imgLeftSexIcon,
		self.imgLeftCareerIcon,
		self.imgLeftLvIcon,
		self.imgLeftTimeIcon,
	}
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WinChatMyProfile:initEvent()
	self:subscribe(self.btnCloseBtn, UIEvent.EventButtonClick, function()
		self:onHide()
	end)
	self:subscribe(self.btnConfirmBtn, UIEvent.EventButtonClick, function()
		self:onHide()
	end)
end

--注册event事件监听，注意这里的事件是show的时候注册，close的时候注销的，常驻事件可在initEvent里面注册
function WinChatMyProfile:subscribeEvent()
	self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_UPDATE_PLAYER_TAG_DATA, function(labels)
		self:updateTagsProfileShow(labels)
	end)

	self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_UPDATE_PLAYER_GAME_TIME, function(time, userId)
		if self.curShowUserId == userId then
			self:updatePlayGameTimes(time)
		end
	end)

	self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_UPDATE_PLAYER_DETAIL_DATA, function(data, userId)
		if self.curShowUserId == userId then
			self:updatePlayerBirthData(data)
		end
	end)
end

--界面数据初始化
function WinChatMyProfile:initView(userId)
	self.curShowUserId = userId
	if self.curShowUserId == Me.platformUserId then
		self.txtTitleName:SetText(Lang:toText("ui.chat.profile.title"))
	else
		self.txtTitleName:SetText(Lang:toText("ui.chat.profile.others_title"))
	end

	self.lytTagPanel:SetVisible(true)
	self.myTagData = {}
	self.imgLeftSexIcon:SetVisible(false)
	self.imgLeftCareerIcon:SetVisible(false)
	self.imgLeftLvIcon:SetVisible(false)
	self.imgLeftTimeIcon:SetVisible(false)
	self:setRequestingTagData(false)
	self:requestPlayerTagsData()
	Me:requestThePlayGameTimes(self.curShowUserId)
	if self.curShowUserId == Me.platformUserId then
		self:updateLeftCareerInfo()
	end
	Me:getOnePlayerDetailData(self.curShowUserId)
	self:updateLeftHeadView()
end

function WinChatMyProfile:requestPlayerTagsData()
	self:setRequestingTagData(true)
	AsyncProcess.GetPlayerListTagData({ self.curShowUserId },function(data)
		if data then
			for _, val in pairs(data) do
				if tonumber(val.userId) == self.curShowUserId then
					self:updateTagsProfileShow(val.labels or {})
					return
				end
			end
			self:updateTagsProfileShow({})
		end
	end)
end

function WinChatMyProfile:updateTagsProfileShow(labels)
	self:setRequestingTagData(false)
	self.myTagData = labels
	self:updateTagViewShow(self.myTagData)
end

function WinChatMyProfile:updatePlayGameTimes(time)
	self.imgLeftTimeIcon:SetVisible(true)
	local hours, min, second = Lib.timeFormatting(time)
	local hoursStr = Lang:toText({"ui.chat.profile.playTime",hours})
	self.txtLeftTimeTxt:SetText(hoursStr)
	--self.txtLeftTimeTxt:SetText(string.format("%02d:%02d", min, second))
	-- 有游戏时长，表示玩过这个游戏
	if tonumber(time) > 0 then
		if self.curShowUserId ~= Me.platformUserId then
			self:updateLeftCareerInfo()
		end
	end
	self:updateLeftIconPos()
end

function WinChatMyProfile:updatePlayerBirthData(data)
	if not data.birthday or data.birthday == "" then
		self.txtBirthDate:SetText("None")
		self.txtConstellationDate:SetText("None")
	else
		self.txtBirthDate:SetText(data.birthday)
		local constellationId = Lib.calConstellationWithBirth(data.birthday)
		local constellationName = Lang:toText("ui.chat.profile.constellationName" .. constellationId)
		self.txtConstellationDate:SetText(constellationName)
	end

	self.txtTribalDate:SetText(data.clanName or "None")
	if data.details and data.details ~= "" then
		self.txtSignTxt:SetText(data.details)
	else
		self.txtSignTxt:SetText(Lang:toText("ui.chat.profile.none_details"))
	end
end

function WinChatMyProfile:updateLeftHeadView()
	self.imgHeadIcon:SetImage("set:default_icon.json image:header_icon")

	local detailInfo = UIChatManage:getUserDetailInfo(self.curShowUserId)
	if detailInfo then
		self:setUserDetailInfo(detailInfo)
	else
		self:listenDetailInfo(self.curShowUserId)
	end
end

function WinChatMyProfile:updateLeftCareerInfo()
	UIChatManage:getFriendListItemSpDisplay(self.curShowUserId,function(info)
		if not info then
			return
		end
		if info.icon then
			self.imgLeftCareerIcon:SetVisible(true)
			self.imgLeftCareerIcon:SetImage(info.icon)
			self.txtLeftCareerTxt:SetText(info.className or "")
		end
		if info.txt then
			self.imgLeftLvIcon:SetVisible(true)
			self.txtLeftLvTxt:SetText(Lang:toText(info.txt))
		end
		self:updateLeftIconPos()
	end)
end

function WinChatMyProfile:listenDetailInfo(platId)
	if self.userDetailInfoCancel then
		self.userDetailInfoCancel()
	end
	self.userDetailInfoCancel = Lib.lightSubscribeEvent("error!!!!! EVENT_USER_DETAIL","EVENT_USER_DETAIL"..platId, function(data)
		self:setUserDetailInfo(data)
	end)
	UIChatManage:initDetailInfo(platId)
end
function WinChatMyProfile:setUserDetailInfo(data)
	if data and data.picUrl and #data.picUrl > 0  then
		self.imgHeadIcon:SetImageUrl(data.picUrl)
	else
		self.imgHeadIcon:SetImage("set:default_icon.json image:header_icon")
	end

	if data.sex == 1 then
		--self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_players")
		self.imgLeftSexIcon:SetImage("set:chat.json image:img_0_male")
	else
		--self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_captain")
		self.imgLeftSexIcon:SetImage("set:chat.json image:img_0_female")
	end
	self.imgLeftSexIcon:SetVisible(true)
	self.txtLeftNameTxt:SetText(data.nickName)

	self:updateLeftIconPos()
end

function WinChatMyProfile:updateLeftIconPos()
	local curShowPosY = 1
	for i = 1, 4 do
		if self.leftIconNode[i]:IsVisible() then
			self.leftIconNode[i]:SetYPosition(self.leftNodePosY[curShowPosY])
			curShowPosY = curShowPosY + 1
		end
	end
end

function WinChatMyProfile:updateTagViewShow(myTagData)
	self.tagAdapter:clearItems()
	self.tagGridView:ResetPos()
	for _, data in pairs(myTagData) do
		self.tagAdapter:addItem(tonumber(data))
	end

	if self.curShowUserId == Me.platformUserId then
		local selectTagMax = chatSetting.chatTagSetting.selectTagMax
		if #myTagData < selectTagMax then
			self.tagAdapter:addItem(0)
		end
	end
end

function WinChatMyProfile:showSelectTagWnd()
	if self.curShowUserId ~= Me.platformUserId then
		return
	end
	if self.requestingTagData then
		return
	end
	UI:getWnd("chatTagSelect"):onShow(true, self.myTagData)
end

function WinChatMyProfile:setRequestingTagData(value)
	self.requestingTagData = value
end

function WinChatMyProfile:onHide()
	UI:closeWnd("chatMyProfile")
end

function WinChatMyProfile:onShow(isShow, userId)
	if isShow then
		if not UI:isOpen(self) then
			UI:openWnd("chatMyProfile", userId)
		else
			self:onHide()
		end
	else
		self:onHide()
	end
end

function WinChatMyProfile:onOpen(userId)
	self._allEvent = {}
	self:subscribeEvent()
	self:initView(userId)
end

function WinChatMyProfile:onClose()
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
end

return WinChatMyProfile

