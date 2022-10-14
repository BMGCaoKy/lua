local widget_base = require "ui.widget.widget_base"
---@class WidgetChatTagItem : widget_base
local WidgetChatTagItem = Lib.derive(widget_base)
---@type TagsConfig
local TagsConfig = T(Config, "TagsConfig")
local chatSetting = World.cfg.chatSetting

function WidgetChatTagItem:init()
	widget_base.init(self, "ChatTagItem.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatTagItem:initUI()
	self.lytItemPanel = self:child("ChatTagItem-itemPanel")
	self.imgItemBg = self:child("ChatTagItem-itemBg")
	self.txtItemTitle = self:child("ChatTagItem-itemTitle")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatTagItem:initEvent()
	self:subscribe(self.lytItemPanel, UIEvent.EventWindowClick, function()
		UI:getWnd("chatMyProfile"):showSelectTagWnd()
	end)
end

function WidgetChatTagItem:onDataChanged(tagId)
	self.tagId = tagId
	if self.tagId == 0 then
		self.imgItemBg:SetImage("set:friendTag.json image:btn_0_add")
		self.txtItemTitle:SetVisible(false)
	else
		self.txtItemTitle:SetVisible(true)
		local tagCfg = TagsConfig:getItemByTagId(self.tagId)
		if tagCfg then
			self.txtItemTitle:SetText(Lang:toText(tagCfg.name))
			self.imgItemBg:SetImage(chatSetting.chatTagSetting[tostring(tagCfg.tagType)].tagTypeRes)
		else
			self.txtItemTitle:SetText(self.tagId or "")
		end
	end
end

return WidgetChatTagItem
