local widget_base = require "ui.widget.widget_base"
---@class WidgetChatNearItem : widget_base
local WidgetChatNearItem = Lib.derive(widget_base)
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")
local chatSetting = World.cfg.chatSetting or {}

function WidgetChatNearItem:init()
	widget_base.init(self, "ChatNearItem.json")
	self._allEvent = {}
	self:initUI()
	self:initEvent()
end

function WidgetChatNearItem:initUI()
	self.imgItemBg = self:child("ChatNearItem-itemBg")
	self.lytHeadPanel = self:child("ChatNearItem-HeadPanel")
	self.imgHeadImg = self:child("ChatNearItem-HeadImg")
	self.imgHeadFrame = self:child("ChatNearItem-HeadFrame")
	self.imgHeadMale = self:child("ChatNearItem-HeadMale")
	self.imgHeadFemale = self:child("ChatNearItem-HeadFemale")
	self.txtHeadLevel = self:child("ChatNearItem-HeadLevel")
	self.txtName = self:child("ChatNearItem-Name")
	self.imgCareerIcon = self:child("ChatNearItem-CareerIcon")
	self.btnAddFriendBtn = self:child("ChatNearItem-addFriendBtn")
	self.btnDeleteBtn = self:child("ChatNearItem-deleteBtn")
	self.txtLanguage = self:child("ChatNearItem-language")
	self.txtLanguage:SetVisible(chatSetting.isShowLanguage)

	self.btnDeleteBtn:SetText(Lang:toText("ui.chat.player_delFriend"))
	self.btnAddFriendBtn:SetText(Lang:toText("ui.chat.player_addFriend"))

	self.isInitUI = true
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatNearItem:initEvent()
	self:subscribe(self.btnAddFriendBtn, UIEvent.EventButtonClick, function()
		AsyncProcess.FriendOperation(FriendManager.operationType.ADD_FRIEND, self.data.userId)
		self.btnAddFriendBtn:SetEnabled(false)
		self.btnAddFriendBtn:SetTouchable(false)
	end)
	self:subscribe(self.btnDeleteBtn, UIEvent.EventButtonClick, function()
		UIChatManage:doDeleteFriendOperate(self.data.userId, self.data.nickName)
		self.btnDeleteBtn:SetEnabled(false)
		self.btnDeleteBtn:SetTouchable(false)
	end)
end


function WidgetChatNearItem:initItemByData(data, index)
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
	self.btnDeleteBtn:SetEnabled(true)
	self.btnDeleteBtn:SetTouchable(true)
	self.btnAddFriendBtn:SetEnabled(true)
	self.btnAddFriendBtn:SetTouchable(true)

	self.imgCareerIcon:SetVisible(false)
	self.txtHeadLevel:SetVisible(false)
	if self.data.userId then
		self.curPlayerIsFriend = Plugins.CallTargetPluginFunc("platform_chat", "checkPlayerIsMyChatFriend", self.data.userId)
		if self.curPlayerIsFriend then
			self.btnAddFriendBtn:SetVisible(false)
			self.btnDeleteBtn:SetVisible(true)
		else
			self.btnAddFriendBtn:SetVisible(true)
			self.btnDeleteBtn:SetVisible(false)
		end

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

function WidgetChatNearItem:onDestroy()
	self.isInitUI = false
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
end

return WidgetChatNearItem
