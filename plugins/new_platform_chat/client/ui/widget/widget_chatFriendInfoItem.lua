local widget_base = require "ui.widget.widget_base"
---@class WidgetChatFriendInfoItem : widget_base
local WidgetChatFriendInfoItem = Lib.derive(widget_base)
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")
local chatSetting = World.cfg.chatSetting or {}

function WidgetChatFriendInfoItem:init()
	widget_base.init(self, "ChatFriendInfoItem.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatFriendInfoItem:initUI()
	self.imgItemBg = self:child("ChatFriendInfoItem-itemBg")
	self.lytItemPanel = self:child("ChatFriendInfoItem-itemPanel")
	self.lytHeadPanel = self:child("ChatFriendInfoItem-HeadPanel")
	self.imgHeadImg = self:child("ChatFriendInfoItem-HeadImg")
	self.imgHeadFrame = self:child("ChatFriendInfoItem-HeadFrame")
	self.imgHeadMale = self:child("ChatFriendInfoItem-HeadMale")
	self.imgHeadFemale = self:child("ChatFriendInfoItem-HeadFemale")
	self.txtHeadLevel = self:child("ChatFriendInfoItem-HeadLevel")
	self.txtName = self:child("ChatFriendInfoItem-Name")
	self.imgCareerIcon = self:child("ChatFriendInfoItem-CareerIcon")
	self.txtOffline = self:child("ChatFriendInfoItem-offline")
	self.txtOnLine = self:child("ChatFriendInfoItem-onLine")
	self.imgLocationIcon = self:child("ChatFriendInfoItem-locationIcon")
	self.txtLocationStr = self:child("ChatFriendInfoItem-locationStr")
	self.txtLanguageStr = self:child("ChatFriendInfoItem-language")

	self.txtOnLine:SetText(Lang:toText("ui.chat.friend.online"))
	self.txtOffline:SetText(Lang:toText("ui.chat.friend.offline"))
	self.txtLanguageStr:SetVisible(chatSetting.isShowLanguage)

	self.isInitUI = true
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatFriendInfoItem:initEvent()
	self._allEvent = {}

	self:subscribe(self.lytItemPanel, UIEvent.EventWindowClick, function()
		UIChatManage:setCurPrivateFriend(self.data.userId)
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

function WidgetChatFriendInfoItem:updateOnlineShow(status)
	if status ~= 30 then
		self.txtOffline:SetVisible(false)
		if self.friendType == Define.chatFriendType.platform then
			self.txtOnLine:SetVisible(true)
			self.imgLocationIcon:SetVisible(false)
		else
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
		end
	else
		self.txtOffline:SetVisible(true)
		self.txtOnLine:SetVisible(false)
		self.imgLocationIcon:SetVisible(false)
	end
end

function WidgetChatFriendInfoItem:onDataChanged(data)
	self:initItemByData(data.friendData, data.friendType)
end

function WidgetChatFriendInfoItem:initItemByData(data, friendType)
	self.friendType = friendType
	self.data = data
	self.txtName:SetText(Lang:toText({"ui.chat.friend.name", self.data.nickName}))
	self.txtLanguageStr:SetText(Lang:toText(self.data.language))
	if self.data.picUrl and #self.data.picUrl>1 then
		self.imgHeadImg:SetImageUrl(self.data.picUrl)
	else
		self.imgHeadImg:SetImage("set:default_icon.json image:header_icon")
	end

	self.imgHeadFrame:SetImage(self.data.sex == 2 and "set:chat.json image:img_9_headframe_captain" or "set:chat.json image:img_9_headframe_players")

	self.imgHeadMale:SetVisible(self.data.sex ~= 2)
	self.imgHeadFemale:SetVisible(self.data.sex == 2)
	if self.data.userId then
		self.imgCareerIcon:SetVisible(false)
		self.txtHeadLevel:SetVisible(false)
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

		self:updateOnlineShow(self.data.status)
	end
end

function WidgetChatFriendInfoItem:onDestroy()
	self.isInitUI = false
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
end
return WidgetChatFriendInfoItem
