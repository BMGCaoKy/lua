local widget_base = require "ui.widget.widget_base"
---@class WidgetChatTeamJoinItem : widget_base
local WidgetChatTeamJoinItem = Lib.derive(widget_base)
--- @type TeamGoalConfig
local TeamGoalConfig = T(Config, "TeamGoalConfig")
local chatSetting = World.cfg.chatSetting
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

function WidgetChatTeamJoinItem:init()
	widget_base.init(self, "ChatTeamJoinItem.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatTeamJoinItem:initUI()
	self.lytHeadPanel = self:child("ChatTeamJoinItem-HeadPanel")
	self.imgHeadImg = self:child("ChatTeamJoinItem-HeadImg")
	self.imgHeadFrame = self:child("ChatTeamJoinItem-HeadFrame")
	self.imgHeadMale = self:child("ChatTeamJoinItem-HeadMale")
	self.imgHeadFemale = self:child("ChatTeamJoinItem-HeadFemale")
	self.txtHeadLevel = self:child("ChatTeamJoinItem-HeadLevel")
	self.imgHeadCareer = self:child("ChatTeamJoinItem-HeadCareer")

	self.txtName = self:child("ChatTeamJoinItem-Name")
	self.imgChatPop = self:child("ChatTeamJoinItem-ChatPop")
	self.txtTeamName = self:child("ChatTeamJoinItem-teamName")
	self.txtTeamDesc = self:child("ChatTeamJoinItem-teamDesc")
	self.imgLvLimitBg = self:child("ChatTeamJoinItem-lvLimitBg")
	self.txtLvLimitStr = self:child("ChatTeamJoinItem-lvLimitStr")
	self.imgTeamNumBg = self:child("ChatTeamJoinItem-teamNumBg")
	self.imgTeamCareer1 = self:child("ChatTeamJoinItem-teamCareer1")
	self.imgTeamCareer2 = self:child("ChatTeamJoinItem-teamCareer2")
	self.imgTeamCareer3 = self:child("ChatTeamJoinItem-teamCareer3")
	self.imgTeamCareer4 = self:child("ChatTeamJoinItem-teamCareer4")
	self.imgTeamCareer5 = self:child("ChatTeamJoinItem-teamCareer5")
	self.btnJoinTeam = self:child("ChatTeamJoinItem-joinTeam")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatTeamJoinItem:initEvent()
	self:subscribe(self.btnJoinTeam, UIEvent.EventButtonClick, function()
		if Me:checkTeamSystemIsOpen() then
			Me:sendPacket({ pid = 'reqJoinTeam', teamId = self.data.teamInviteData.teamInfo.teamId })
		end
	end)

	self:subscribe(self.imgChatPop, UIEvent.EventWindowClick, function()
		if Me:checkTeamSystemIsOpen() then
			Me:sendPacket({ pid = 'getTeamData', teamId = self.data.teamInviteData.teamInfo.teamId })
		end
	end)
end

function WidgetChatTeamJoinItem:initHeadImg()
	self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_players")
	self.txtHeadLevel:SetText("")
	self.imgHeadMale:SetVisible(false)
	self.imgHeadFemale:SetVisible(false)

	self.imgHeadCareer:SetVisible(false)
	self.txtHeadLevel:SetVisible(false)
	if self.data.platId then
		local detailInfo = UIChatManage:getUserDetailInfo(self.data.platId)
		if detailInfo then
			self:setUserDetailInfo(detailInfo)
		else
			self:listenDetailInfo(self.data.platId)
		end

		UIChatManage:getFriendListItemSpDisplay(self.data.platId,function(info)
			if not info then
				return
			end
			if info.icon then
				self.imgHeadCareer:SetVisible(true)
				self.imgHeadCareer:SetImage(info.icon)
			end
			if info.txt then
				self.txtHeadLevel:SetVisible(true)
				self.txtHeadLevel:SetText(Lang:toText(info.txt))
			end
		end)
	end
end

function WidgetChatTeamJoinItem:listenDetailInfo(platId)
	if not platId then
		Lib.logError("WidgetChatTeamJoinItem:listenDetailInfo id is nil!")
		return
	end
	if self.userDetailInfoCancel then
		self.userDetailInfoCancel()
	end
	self.userDetailInfoCancel = Lib.lightSubscribeEvent("error!!!!! EVENT_USER_DETAIL","EVENT_USER_DETAIL"..platId, function(data)
		self:setUserDetailInfo(data)
	end)
	UIChatManage:initDetailInfo(platId)
end
function WidgetChatTeamJoinItem:setUserDetailInfo(data)
	if data and data.picUrl and #data.picUrl > 0  then
		self.imgHeadImg:SetImageUrl(data.picUrl)
	else
		self.imgHeadImg:SetImage("set:default_icon.json image:header_icon")
	end

	if data.sex == 1 then
		self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_players")
		self.imgHeadMale:SetVisible(true)
	else
		self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_captain")
		self.imgHeadFemale:SetVisible(true)
	end
	--self.txtName:SetText("▢"..self.nameColorStr.. data.nickName)
end

function WidgetChatTeamJoinItem:initNameColor()
	self.nameColorStr = "FF"..(chatSetting.mainSelfNameColor or "FF0000")
	self.contentColorStr = "FF"..(chatSetting.mainNickFontColor or "000000")
	if self.data.fromname ==Me.name then
		self.nameColorStr =  "FF"..(chatSetting.mainSelfNameColor or "33BD41")
		self.contentColorStr = "FF"..(chatSetting.mainSelfFontColor or "000000")
	elseif not self.data.dign then
		self.nameColorStr = "FF"..(chatSetting.mainSelfNameColor or "FF0000")
		self.contentColorStr = "FF"..(chatSetting.mainNickFontColor or "000000")
	elseif self.data.dign == Define.ChatPlayerType.server then
		self.nameColorStr = "FFFFFFFF"
		self.contentColorStr = "FF909090"
	elseif self.data.dign == Define.ChatPlayerType.vip then
		self.nameColorStr = "FFFAFF07"
	elseif self.data.dign == Define.ChatPlayerType.svip then
		self.nameColorStr = "FFEC0420"
	end
end

function WidgetChatTeamJoinItem:setItemContentType(contentType)
	self.contentType = contentType
end

function WidgetChatTeamJoinItem:getItemContentType()
	return self.contentType
end

function WidgetChatTeamJoinItem:initViewByData(data)
	self.data = data
	self:initNameColor()
	self:initHeadImg()

	if not data.fromname then
		return
	end

	self.txtName:SetText("▢"..self.nameColorStr..data.fromname)
	self.lytHeadPanel:SetVisible(true)
	self.imgChatPop:SetVisible(true)

	local teamInviteData = self.data.teamInviteData
	local cfg = TeamGoalConfig:getConfigById(teamInviteData.teamInfo.goal.goalId)
	local teamData = {
		teamName = Lang:toText(cfg.name),
		teamDesc = teamInviteData.shoutContent,
		maxLv = teamInviteData.teamInfo.goal.maxLevel,
		minLv = teamInviteData.teamInfo.goal.minLevel,
		maxNum = 5,
		curNum = #teamInviteData.teamInfo.info,
		info =  teamInviteData.teamInfo.info
	}

	self.txtTeamName:SetText(teamData.teamName)
	local teamDesc = teamData.teamDesc
	local endIndex = Lib.subStringGetTotalIndex(teamData.teamDesc);
	local maxLen = 29
	if endIndex > maxLen then
		teamDesc = Lib.subStringUTF8(teamData.teamDesc, 1, maxLen) .. "..."
	end
	self.txtTeamDesc:SetText(teamDesc)
	self.txtLvLimitStr:SetText("Lv." .. teamData.minLv .. "~" .. teamData.maxLv )
	
	for i = 1, 5 do
		local carNode = self["imgTeamCareer" .. i]
		if teamData.info[i] then
			local careerIcon = UIChatManage:getTeamJoinCareerIcon(teamData.info[i].class)
			if careerIcon then
				carNode:SetImage(careerIcon)
			else
				carNode:SetImage("set:chat.json image:img_0_waitbd")
			end
		else
			carNode:SetImage("set:chat.json image:img_0_waitbd")
		end
	end
end

return WidgetChatTeamJoinItem
