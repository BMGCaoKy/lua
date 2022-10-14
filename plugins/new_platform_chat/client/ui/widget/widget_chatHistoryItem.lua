local widget_base = require "ui.widget.widget_base"
---@class WidgetChatHistoryItem : widget_base
local WidgetChatHistoryItem = Lib.derive(widget_base)
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")
function WidgetChatHistoryItem:init()
	widget_base.init(self, "ChatHistoryItem.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatHistoryItem:initUI()
	self.lytItemPanel = self:child("ChatHistoryItem-itemPanel")
	self.imgItemBg = self:child("ChatHistoryItem-itemBg")
	self.lytHeadPanel = self:child("ChatHistoryItem-HeadPanel")
	self.imgHeadImg = self:child("ChatHistoryItem-HeadImg")
	self.imgHeadFrame = self:child("ChatHistoryItem-HeadFrame")
	self.imgHeadMale = self:child("ChatHistoryItem-HeadMale")
	self.imgHeadFemale = self:child("ChatHistoryItem-HeadFemale")
	self.txtHeadLevel = self:child("ChatHistoryItem-HeadLevel")
	self.imgCareerIcon = self:child("ChatHistoryItem-CareerIcon")
	self.txtName = self:child("ChatHistoryItem-Name")
	self.txtOffline = self:child("ChatHistoryItem-offline")
	self.txtOnLine = self:child("ChatHistoryItem-onLine")
	self.txtLastMsg = self:child("ChatHistoryItem-lastMsg")
	self.imgLocationIcon = self:child("ChatHistoryItem-locationIcon")
	self.txtLocationStr = self:child("ChatHistoryItem-locationStr")
	self.imgRedIcon = self:child("ChatHistoryItem-redIcon")
	self.txtRedStr = self:child("ChatHistoryItem-redStr")

	self.txtOnLine:SetText(Lang:toText("ui.chat.friend.online"))
	self.txtOffline:SetText(Lang:toText("ui.chat.friend.offline"))

	self.isInitUI = true
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatHistoryItem:initEvent()
	self._allEvent = {}

	self:subscribe(self.lytItemPanel, UIEvent.EventWindowClick, function()
		UIChatManage:setCurPrivateFriend(self.data.keyId)
	end)

	self:subscribe(self.lytHeadPanel, UIEvent.EventWindowClick, function()
		UIChatManage:openChatPlayerInfoWnd(self.data.userId)
	end)

	self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_UPDATE_ONLINE_STATE_SHOW, function(data)
		if self.data and self.data.userId then
			self:updateOnlineShow(UIChatManage:getChatPlayerOnlineState(self.data.userId))
		end
	end)
end

function WidgetChatHistoryItem:updateOnlineShow(status)
	if status ~= 30 then
		self.txtOffline:SetVisible(false)
		if status == 20 then
			local locationMap = UIChatManage:getOnlineFriendLocationMap(self.data.userId)
			if locationMap and locationMap ~= "" then
				self.txtOnLine:SetVisible(false)
				self.imgLocationIcon:SetVisible(true)
				self.txtLocationStr:SetText(locationMap)
			else
				self.txtOnLine:SetVisible(true)
				self.imgLocationIcon:SetVisible(false)
			end
		else
			self.txtOnLine:SetVisible(true)
			self.imgLocationIcon:SetVisible(false)
		end
	else
		self.txtOffline:SetVisible(true)
		self.txtOnLine:SetVisible(false)
		self.imgLocationIcon:SetVisible(false)
	end
end

function WidgetChatHistoryItem:updateRedNum(redNum)
	if redNum > 0 then
		self.imgRedIcon:SetVisible(true)
		self.txtRedStr:SetText(redNum)
	else
		self.imgRedIcon:SetVisible(false)
	end
end

function WidgetChatHistoryItem:getHistoryKeyId()
	return self.data.keyId
end

function WidgetChatHistoryItem:initItemByData(data)
	--print("WidgetChatHistoryItem:initItemByData：",Lib.v2s(data,2))
	self.data = data
	self.data.userId = self.data.keyId
	self.txtName:SetText(self.data.keyId)
	if self.data.extraMsgArgs then
		if self.data.extraMsgArgs.messageType == Define.privateMessageType.emojiMsg then
			self.txtLastMsg:SetText(Lang:toText("[emoji]"))
		elseif self.data.extraMsgArgs.messageType == Define.privateMessageType.voiceMsg then
			self.txtLastMsg:SetText(Lang:toText("[voice]"))
		else
			local lastContent = Lang:toText(self.data.info and self.data.info.msg or "")
			local endIndex = Lib.subStringGetTotalIndex(lastContent);
			local maxLen = 12
			if endIndex > maxLen then
				lastContent = Lib.subStringUTF8(lastContent, 1, maxLen) .. "..."
			end
			self.txtLastMsg:SetText(lastContent)
		end
	end

	self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_players")
	self.imgHeadMale:SetVisible(false)
	self.imgHeadFemale:SetVisible(false)

	self.imgCareerIcon:SetVisible(false)
	self.txtHeadLevel:SetVisible(false)
	self.txtOffline:SetVisible(false)
	self.txtOnLine:SetVisible(false)
	self.imgLocationIcon:SetVisible(false)
	if self.data.userId then
		UIChatManage:getFriendListItemSpDisplay(self.data.userId,function(info)
			if not info then
				return
			end
			if not self.isInitUI then
				return
			end
			if info.icon then
				self.imgCareerIcon:SetVisible(true)
				self.imgCareerIcon:SetImage(info.icon)
			end
			if info.txt then
				self.txtHeadLevel:SetVisible(true)
				self.txtHeadLevel:SetText(Lang:toText(info.txt))
			end
		end)
		self:updateOnlineShow(UIChatManage:getChatPlayerOnlineState(self.data.userId))

		local detailInfo = UIChatManage:getUserDetailInfo(self.data.keyId)
		if detailInfo then
			self:setUserDetailInfo(detailInfo)
		else
			self:listenDetailInfo(self.data.keyId)
		end
	end
end
function WidgetChatHistoryItem:listenDetailInfo(id)
	if not id then
		Lib.logError("WidgetChatHistoryItem:listenDetailInfo id is nil!")
		return
	end
	if self.userDetailInfoCancel then
		self.userDetailInfoCancel()
	end
	self.userDetailInfoCancel = Lib.lightSubscribeEvent("error!!!!! EVENT_USER_DETAIL","EVENT_USER_DETAIL"..id, function(data)
		self:setUserDetailInfo(data)
	end)
	UIChatManage:initDetailInfo(id)
end

function WidgetChatHistoryItem:setUserDetailInfo(data)
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
	self.txtName:SetText(Lang:toText({"ui.chat.friend.name",  data.nickName}))
end

function WidgetChatHistoryItem:onDestroy()
	self.isInitUI = false
	if self.userDetailInfoCancel then
		self.userDetailInfoCancel()
	end
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
end

return WidgetChatHistoryItem

