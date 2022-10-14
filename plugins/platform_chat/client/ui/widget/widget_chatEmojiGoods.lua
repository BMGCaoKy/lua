local widget_base = require "ui.widget.widget_base"
---@class WidgetChatEmojiGoods : widget_base
local WidgetChatEmojiGoods = Lib.derive(widget_base)

function WidgetChatEmojiGoods:init()
	widget_base.init(self, "ChatEmojiGoods.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatEmojiGoods:initUI()
	self.imgFrameIcon = self:child("ChatEmojiGoods-frame_icon")
	self.imgIcon = self:child("ChatEmojiGoods-icon")
	self.txtNum = self:child("ChatEmojiGoods-num")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatEmojiGoods:initEvent()
	self:lightSubscribe("error!!!!! script_client WidgetChatEmojiGoods img event : EventWindowClick",self._root, UIEvent.EventWindowClick, function(window,dx,dy)
		if self.clickSendGood then
			local emojiInfo = {
				type = Define.chatEmojiTab.GOODS,
				emojiData = self.goodJson
			}
			UI:getWnd("chatMain"):sendEmoji(emojiInfo)
		else
			Me:showChatGoodsDetailView(self.goodJson, dx,dy)
		end
	end)
end

function WidgetChatEmojiGoods:onDataChanged(goodJson)
	self.clickSendGood = true
	self:initLinkItemInfo(goodJson)
end

-- 初始化item内容
function WidgetChatEmojiGoods:initLinkItemInfo(goodJson)
	self.goodJson = goodJson
	local goodData = Me:decodeChatGoodBodyJson(goodJson)
	self.cfgId = goodData.cfgId
	self.imgIcon:SetImage(goodData.icon)
	self.imgFrameIcon:SetImage(goodData.iconBg)
	if self.clickSendGood then
		self.txtNum:SetText(goodData.amount)
	else
		self.txtNum:SetText("")
	end
end

return WidgetChatEmojiGoods
