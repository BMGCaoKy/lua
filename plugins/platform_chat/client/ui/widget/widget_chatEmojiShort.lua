local widget_base = require "ui.widget.widget_base"
---@class WidgetChatEmojiShort : widget_base
local WidgetChatEmojiShort = Lib.derive(widget_base)

function WidgetChatEmojiShort:init()
	widget_base.init(self, "ChatEmojiShort.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatEmojiShort:initUI()
	self.imgContentBg = self:child("ChatEmojiShort-contentBg")
	self.txtContentTxt = self:child("ChatEmojiShort-contentTxt")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatEmojiShort:initEvent()
	self:lightSubscribe("error!!!!! script_client WidgetChatEmojiPet img event : EventWindowClick",self._root, UIEvent.EventWindowClick, function()
		---发短语
		local emojiInfo = {
			type = Define.chatEmojiTab.SHORT,
			emojiData = self.text
		}
		UI:getWnd("chatMain"):sendEmoji(emojiInfo)
	end)
end

function WidgetChatEmojiShort:onDataChanged(data)
	self.text = data.text
	self.txtContentTxt:SetText(Lang:toText(data.name))
end

return WidgetChatEmojiShort
