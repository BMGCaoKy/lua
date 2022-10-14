local widget_base = require "ui.widget.widget_base"
---@class WidgetChatEmojiPet : widget_base
local WidgetChatEmojiPet = Lib.derive(widget_base)

function WidgetChatEmojiPet:init()
	widget_base.init(self, "ChatEmojiPet.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatEmojiPet:initUI()
	self.imgItemBg = self:child("ChatEmojiPet-itemBg")
	self.imgNameBg = self:child("ChatEmojiPet-NameBg")
	self.txtName = self:child("ChatEmojiPet-Name")
	self.imgIconBg = self:child("ChatEmojiPet-IconBg")
	self.imgIcon = self:child("ChatEmojiPet-Icon")
	self.txtLevel = self:child("ChatEmojiPet-Level")
	self.imgPowerIcon = self:child("ChatEmojiPet-powerIcon")
	self.txtPowerTxt = self:child("ChatEmojiPet-powerTxt")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatEmojiPet:initEvent()
	self:lightSubscribe("error!!!!! script_client WidgetChatEmojiPet img event : EventWindowClick",self._root, UIEvent.EventWindowClick, function(window,dx,dy)
		if self.clickSendPet then
			local emojiInfo = {
				type = Define.chatEmojiTab.PET,
				emojiData = self.petJson
			}
			UI:getWnd("chatMain"):sendEmoji(emojiInfo)
		else
			Me:showChatPetDetailView(self.petJson, dx,dy)
		end
	end)
end

function WidgetChatEmojiPet:onDataChanged(petJson)
	self.clickSendPet = true
	self:initLinkItemInfo(petJson)
end

-- 初始化item内容
function WidgetChatEmojiPet:initLinkItemInfo(petJson)
	self.petJson = petJson
	local entityData = Me:decodeChatPetBodyJson(petJson)
	self.petId = entityData.petId
	self.uid = entityData.uid
	local name = entityData.name
	if Lib.getStringLen(name) > 10 then
		name = Lib.subString(name, 8) .. "..."
	end
	self.txtName:SetText( name )
	if entityData.nameColor then
		self.txtName:SetTextColor(entityData.nameColor)
	end
	if entityData.icon then
		self.imgIcon:SetImage(entityData.icon)
	end
	if entityData.iconBg then
		self.imgIconBg:SetImage(entityData.iconBg)
	end
	self.txtLevel:SetText(string.format("Lv.%d", entityData.level or 0))
	self.txtPowerTxt:SetText(entityData.power or 0)
end

return WidgetChatEmojiPet
