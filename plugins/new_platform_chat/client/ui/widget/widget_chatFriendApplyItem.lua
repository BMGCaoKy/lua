local widget_base = require "ui.widget.widget_base"
---@class WidgetChatFriendApplyItem : widget_base
local WidgetChatFriendApplyItem = Lib.derive(widget_base)
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")
local chatSetting = World.cfg.chatSetting or {}

function WidgetChatFriendApplyItem:init()
	widget_base.init(self, "ChatFriendApplyItem.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatFriendApplyItem:initUI()
	self.imgItemBg = self:child("ChatFriendApplyItem-itemBg")
	self.lytHeadPanel = self:child("ChatFriendApplyItem-HeadPanel")
	self.imgHeadImg = self:child("ChatFriendApplyItem-HeadImg")
	self.imgHeadFrame = self:child("ChatFriendApplyItem-HeadFrame")
	self.imgHeadMale = self:child("ChatFriendApplyItem-HeadMale")
	self.imgHeadFemale = self:child("ChatFriendApplyItem-HeadFemale")
	self.txtHeadLevel = self:child("ChatFriendApplyItem-HeadLevel")
	self.txtName = self:child("ChatFriendApplyItem-Name")
	self.imgCareerIcon = self:child("ChatFriendApplyItem-CareerIcon")
	self.btnAgreeBtn = self:child("ChatFriendApplyItem-agreeBtn")
	self.btnRefusedBtn = self:child("ChatFriendApplyItem-refusedBtn")
	self.txtLanguage = self:child("ChatFriendApplyItem-language")
	self.txtLanguage:SetVisible(chatSetting.isShowLanguage)

	self.isInitUI = true
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatFriendApplyItem:initEvent()
	self:subscribe(self.btnAgreeBtn, UIEvent.EventButtonClick, function()
		if self.responseApplyFunc then
			self.responseApplyFunc(self.index, true)
		end
	end)
	self:subscribe(self.btnRefusedBtn, UIEvent.EventButtonClick, function()
		if self.responseApplyFunc then
			self.responseApplyFunc(self.index, false)
		end
	end)
end

function WidgetChatFriendApplyItem:initItemByData(data, index)
	self.index = index
	self.data = data
	self.txtName:SetText(Lang:toText({"ui.chat.friend.name", self.data.nickName}))
	self.txtLanguage:SetText(Lang:toText(self.data.language))
	if self.data.picUrl and #self.data.picUrl>1 then
		self.imgHeadImg:SetImageUrl(self.data.picUrl)
	else
		self.imgHeadImg:SetImage("set:default_icon.json image:header_icon")
	end
	self.imgHeadFrame:SetImage(self.data.sex == 2 and "set:chat.json image:img_9_headframe_captain" or "set:chat.json image:img_9_headframe_players")
	self.imgHeadMale:SetVisible(self.data.sex == 1)
	self.imgHeadFemale:SetVisible(self.data.sex == 2)

	self.imgCareerIcon:SetVisible(false)
	self.txtHeadLevel:SetVisible(false)
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
	end
end

function WidgetChatFriendApplyItem:setResponseApplyFunc(responseApplyFunc)
	self.responseApplyFunc = responseApplyFunc
end

function WidgetChatFriendApplyItem:onDestroy()
	self.isInitUI = false
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
end
return WidgetChatFriendApplyItem
