local widget_base = require "ui.widget.widget_base"
---@class WidgetChatTagTabItem : widget_base
local WidgetChatTagTabItem = Lib.derive(widget_base)
local chatSetting = World.cfg.chatSetting
function WidgetChatTagTabItem:init()
	widget_base.init(self, "ChatTagTabItem.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatTagTabItem:initUI()
	self.lytTabPanel = self:child("ChatTagTabItem-tabPanel")
	self.imgNormalBg = self:child("ChatTagTabItem-normalBg")
	self.imgSelectBg = self:child("ChatTagTabItem-selectBg")
	self.txtTabTitle = self:child("ChatTagTabItem-tabTitle")

	self.imgRedIcon= self:child("ChatTagTabItem-redIcon")
	self.txtRedNum = self:child("ChatTagTabItem-redNum")
	self:updateRedCounts(0)
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatTagTabItem:initEvent()
	self:subscribe(self.lytTabPanel, UIEvent.EventWindowClick, function()
		if self.clickFunc then
			self.clickFunc(self.tabKey)
		end
	end)
end

function WidgetChatTagTabItem:initTabKey(tabKey, curNum, totalNum)
	self.tabKey = tabKey
	self.txtTabTitle:SetText(Lang:toText(chatSetting.chatTagSetting[tostring(tabKey)].tagTypeName))
	if totalNum == 1 then
		self.imgNormalBg:SetImage("set:friendTag.json image:chb_9_center")
		self.imgSelectBg:SetImage("set:friendTag.json image:chb_9_center_sle")
	elseif curNum == 1 then
		self.imgNormalBg:SetImage("set:friendTag.json image:chb_9_left")
		self.imgSelectBg:SetImage("set:friendTag.json image:chb_9_left_sle")
	elseif curNum == totalNum then
		self.imgNormalBg:SetImage("set:friendTag.json image:chb_9_right")
		self.imgSelectBg:SetImage("set:friendTag.json image:chb_9_right_sle")
	else
		self.imgNormalBg:SetImage("set:friendTag.json image:chb_9_center")
		self.imgSelectBg:SetImage("set:friendTag.json image:chb_9_center_sle")
	end
end

function WidgetChatTagTabItem:setTabClickFunc(clickFunc)
	self.clickFunc =  clickFunc
end

local function getTextColor(str)
	-- 去掉#字符
	local newstr = string.gsub(str, '#', '')

	-- 每次截取两个字符 转换成十进制
	local colorlist = {}
	local index = 1
	while index < string.len(newstr) do
		local tempstr = string.sub(newstr, index, index + 1)
		table.insert(colorlist, tonumber(tempstr, 16))
		index = index + 2
	end
	return { colorlist[1] / 255, colorlist[2] / 255, colorlist[3] / 255 }
end

function WidgetChatTagTabItem:updateTabIconShow(selectTabKey)
	if selectTabKey == self.tabKey then
		self.imgNormalBg:SetVisible(false)
		self.imgSelectBg:SetVisible(true)
		self.txtTabTitle:SetTextColor( getTextColor("FEFEFE"))
	else
		self.imgNormalBg:SetVisible(true)
		self.imgSelectBg:SetVisible(false)
		self.txtTabTitle:SetTextColor( getTextColor("2F333F"))
	end
end

-- 更新红点数量
function WidgetChatTagTabItem:updateRedCounts(num)
	if num > 0 then
		self.imgRedIcon:SetVisible(true)
		self.txtRedNum:SetText(num)
	else
		self.imgRedIcon:SetVisible(false)
	end
end
return WidgetChatTagTabItem
