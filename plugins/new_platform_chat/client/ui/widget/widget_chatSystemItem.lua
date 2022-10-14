local widget_base = require "ui.widget.widget_base"
---@class WidgetChatSystemItem : widget_base
local WidgetChatSystemItem = Lib.derive(widget_base)
local chatSetting = World.cfg.chatSetting

function WidgetChatSystemItem:init()
	widget_base.init(self, "ChatSystemItem.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatSystemItem:initUI()
	self.imgTypeBg = self:child("ChatSystemItem-typeBg")
	self.txtTypeStr = self:child("ChatSystemItem-typeStr")
	self.txtChat = self:child("ChatSystemItem-Text")
	self.lytTopPanel = self:child("ChatSystemItem-topPanel")
end

function WidgetChatSystemItem:initEvent()
	self:lightSubscribe("error!!!!! script_client WidgetChatSystemItem lytTopPanel event : EventWindowClick",self.lytTopPanel, UIEvent.EventWindowClick, function()
		if not self.msgEvent then return end
		local func = Me[self.msgEvent]
		if func then
			func(Me, self.eventArgs)
		end
	end)
end

local function getColorOfRGB(str)
	local curColorStr = str or "000000"
	-- 去掉#字符
	local newstr = string.gsub(curColorStr, '#', '')

	-- 每次截取两个字符 转换成十进制
	local colorlist = {}
	local index = 1
	while index < string.len(newstr) do
		local tempstr = string.sub(newstr, index, index + 1)
		table.insert(colorlist, tonumber(tempstr, 16))
		index = index + 2
	end

	return {(colorlist[1] or 0)/255, (colorlist[2] or 0)/255, (colorlist[3] or 0)/255, 1}
end

local function getBorderColor(str)
	local curColorStr = str or "000000"
	-- 去掉#字符
	local newstr = string.gsub(curColorStr, '#', '')

	-- 每次截取两个字符 转换成十进制
	local colorlist = {}
	local index = 1
	while index < string.len(newstr) do
		local tempstr = string.sub(newstr, index, index + 1)
		table.insert(colorlist, tonumber(tempstr, 16))
		index = index + 2
	end
	return tostring(colorlist[1]/255) .. " " .. tostring(colorlist[2]/255) .. " " .. tostring(colorlist[3]/255) .. " 1"
end

--系统消息
function WidgetChatSystemItem:initSystemMsg(data)

	local preTypeStr =  Lang:toText("ui.chat.chatMsgType" .. Define.Page.SYSTEM)
	local curColor = getColorOfRGB(chatSetting.chatTypeColor[data.type])
	self.imgTypeBg:SetDrawColor(curColor)
	local borderColor = getBorderColor(chatSetting.chatTypeColor[data.type])
	self.txtTypeStr:SetProperty("TextBorderColor", borderColor)
	self.txtTypeStr:SetText(preTypeStr)

	self.contentColorStr = "FF" .. chatSetting.chatTypeColor[Define.Page.SYSTEM] or "000000"
	local finalShowStr = "▢"..self.contentColorStr..""..data.msg

	if data.msgPack then
		self.msgEvent = data.msgPack.event
		self.eventArgs = data.msgPack.args
	else
		self.msgEvent = nil
		self.eventArgs = nil
	end

	self.txtChat:SetText(finalShowStr)
	self:autoBarSize(data.msg)
end

function WidgetChatSystemItem:setItemContentType(contentType)
	self.contentType = contentType
end

function WidgetChatSystemItem:getItemContentType()
	return self.contentType
end

function WidgetChatSystemItem:initViewByData(data)
	self.data = data
	self:initSystemMsg(data)
end

function WidgetChatSystemItem:autoBarSize(msg)
	local onlineHeight = 30
	local strW = self.txtChat:GetFont():GetStringWidth(msg)
	local rootW =  self._root:GetWidth()[2]
	local txtNodeW = self.txtChat:GetWidth()
	local uiW = rootW*txtNodeW[1] + txtNodeW[2]
	uiW = uiW>0 and uiW or -uiW
	uiW = uiW - 5
	if strW > uiW then
		local offsetLine = math.floor(strW/uiW)
		local curHeight = onlineHeight + offsetLine*(onlineHeight-5)
		self._root:SetHeight({0, curHeight})
	else
		self._root:SetHeight({0, onlineHeight})
	end
end

function WidgetChatSystemItem:SetWidth(width1, width2)
	self._root:SetWidth({width1, width2})
end

function WidgetChatSystemItem:onDestroy()
end
return WidgetChatSystemItem
