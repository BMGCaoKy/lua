local widget_base = require "ui.widget.widget_base"
---@class WidgetChatEmojiTab : widget_base
local WidgetChatEmojiTab = Lib.derive(widget_base)

function WidgetChatEmojiTab:init()
	widget_base.init(self, "ChatEmojiTab.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatEmojiTab:initUI()
	self.lytPanel = self:child("ChatEmojiTab-panel")
	self.imgEmojiTabN = self:child("ChatEmojiTab-emojiTabN")
	self.imgEmojiTabS = self:child("ChatEmojiTab-emojiTabS")
	self.txtEmojiTabName = self:child("ChatEmojiTab-emojiTabName")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatEmojiTab:initEvent()
	self:subscribe(self.lytPanel, UIEvent.EventWindowClick, function()
		if self.clickFunc then
			self.clickFunc(self.tabKey or Define.chatEmojiTab.FACE)
		end
	end)
end

function WidgetChatEmojiTab:initTabKey(tabKey)
	self.tabKey = tabKey
	if tabKey == Define.chatEmojiTab.FACE then
		self.txtEmojiTabName:SetText(Lang:toText("ui.chat.emoji.face"))
	elseif tabKey == Define.chatEmojiTab.GOODS then
		self.txtEmojiTabName:SetText(Lang:toText("ui.chat.emoji.goods"))
	elseif tabKey == Define.chatEmojiTab.PET then
		self.txtEmojiTabName:SetText(Lang:toText("ui.chat.emoji.pet"))
	elseif tabKey == Define.chatEmojiTab.SHORT then
		self.txtEmojiTabName:SetText(Lang:toText("ui.chat.emoji.short"))
	else
		self.txtEmojiTabName:SetText("")
	end
end

function WidgetChatEmojiTab:setTabClickFunc(clickFunc)
	self.clickFunc =  clickFunc
end

function WidgetChatEmojiTab:updateTabIconShow(selectTabKey)
	if selectTabKey == self.tabKey then
		self.imgEmojiTabN:SetVisible(false)
		self.imgEmojiTabS:SetVisible(true)
	else
		self.imgEmojiTabN:SetVisible(true)
		self.imgEmojiTabS:SetVisible(false)
	end
end
return WidgetChatEmojiTab
