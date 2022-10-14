local widget_base = require "ui.widget.widget_base"
---@class WidgetChatLinkItemEx : widget_base
local WidgetChatLinkItemEx = Lib.derive(widget_base)
local chatSetting = World.cfg.chatSetting
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

function WidgetChatLinkItemEx:init()
	widget_base.init(self, "ChatLinkItemEx.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatLinkItemEx:initUI()
	self.lytHeadPanel = self:child("ChatLinkItemEx-HeadPanel")
	self.imgHeadImg = self:child("ChatLinkItemEx-HeadImg")
	self.imgHeadFrame = self:child("ChatLinkItemEx-HeadFrame")
	self.imgHeadMale = self:child("ChatLinkItemEx-HeadMale")
	self.imgHeadFemale = self:child("ChatLinkItemEx-HeadFemale")
	self.txtHeadLevel = self:child("ChatLinkItemEx-HeadLevel")
	self.imgHeadCareer = self:child("ChatLinkItemEx-HeadCareer")

	self.txtName = self:child("ChatLinkItemEx-Name")
	self.lytContentPanel = self:child("ChatLinkItemEx-contentPanel")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatLinkItemEx:initEvent()
end

function WidgetChatLinkItemEx:setItemContentType(contentType)
	self.contentType = contentType
	if self.linkEmojiNode then
		return
	end
	if contentType == Define.chatMainContentType.petEx then
		self.linkEmojiNode = UIMgr:new_widget("chatEmojiPet")
	elseif contentType == Define.chatMainContentType.goodEx then
		self.linkEmojiNode = UIMgr:new_widget("chatEmojiGoods")
	end
	self.lytContentPanel:AddChildWindow(self.linkEmojiNode)
	self.linkEmojiNode:SetXPosition({0, 0})
	self.linkEmojiNode:SetYPosition({0, 0})
end

function WidgetChatLinkItemEx:getItemContentType()
	return self.contentType
end

function WidgetChatLinkItemEx:initHeadImg()
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

function WidgetChatLinkItemEx:listenDetailInfo(platId)
	if not platId then
		Lib.logError("WidgetChatLinkItemEx:listenDetailInfo id is nil!")
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
function WidgetChatLinkItemEx:setUserDetailInfo(data)
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

function WidgetChatLinkItemEx:initNameColor()
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

function WidgetChatLinkItemEx:initViewByData(data)
	self.data = data
	self:setSide(data.platId == Me.platformUserId)
	self:initNameColor()
	self:initHeadImg()

	if not data.fromname then
		return
	end
	self.txtName:SetText("▢"..self.nameColorStr..data.fromname)

	if self.linkEmojiNode and data.emoji then
		self.linkEmojiNode:invoke("initLinkItemInfo", data.emoji.emojiData)
	end
end

function WidgetChatLinkItemEx:setSide(isSelf)
	local headPanelX = 10
	local txtNameX = 100
	local emojiX = 100
	if isSelf then
		self.lytHeadPanel:SetHorizontalAlignment(2)
		self.lytHeadPanel:SetXPosition({0, -headPanelX})
		self.txtName:SetHorizontalAlignment(2)
		self.txtName:SetTextHorzAlign(2)
		self.txtName:SetXPosition({0, -txtNameX})

		self.lytContentPanel:SetHorizontalAlignment(2)
		self.lytContentPanel:SetXPosition({0, -emojiX})
		self.linkEmojiNode:SetHorizontalAlignment(2)
	else
		self.lytHeadPanel:SetHorizontalAlignment(0)
		self.lytHeadPanel:SetXPosition({0, headPanelX})
		self.txtName:SetHorizontalAlignment(0)
		self.txtName:SetTextHorzAlign(0)
		self.txtName:SetXPosition({0, txtNameX})

		self.lytContentPanel:SetHorizontalAlignment(0)
		self.lytContentPanel:SetXPosition({0, emojiX})
		self.linkEmojiNode:SetHorizontalAlignment(0)
	end
end

return WidgetChatLinkItemEx
