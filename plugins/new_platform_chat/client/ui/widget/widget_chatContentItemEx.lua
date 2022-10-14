local widget_base = require "ui.widget.widget_base"
---@class WidgetChatContentItemEx : widget_base
local WidgetChatContentItemEx = Lib.derive(widget_base)
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")
local ShortConfig = T(Config, "ShortConfig")

local chatSetting = World.cfg.chatSetting or {}
local function getColorOfRGB(str)
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

	return {(colorlist[1] or 0)/255, (colorlist[2] or 0)/255, (colorlist[3] or 0)/255}
end

function WidgetChatContentItemEx:init()
	widget_base.init(self, "ChatContentItemEx.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatContentItemEx:initUI()
	self.lytHeadPanel = self:child("ChatContentItemEx-HeadPanel")
	self.imgHeadImg = self:child("ChatContentItemEx-HeadImg")
	self.imgHeadFrame = self:child("ChatContentItemEx-HeadFrame")
	self.imgHeadMale = self:child("ChatContentItemEx-HeadMale")
	self.imgHeadFemale = self:child("ChatContentItemEx-HeadFemale")
	self.txtHeadLevel = self:child("ChatContentItemEx-HeadLevel")
	self.imgHeadCareer = self:child("ChatContentItemEx-HeadCareer")

	self.txtName = self:child("ChatContentItemEx-Name")
	self.imgChatPop = self:child("ChatContentItemEx-ChatPop")
	self.txtChatText = self:child("ChatContentItemEx-ChatText")
	self.lytVoiceContent = self:child("ChatContentItemEx-VoiceContent")
	self.imgVoicePoint = self:child("ChatContentItemEx-VoicePoint")
	self.imgVoiceImg = self:child("ChatContentItemEx-VoiceImg")
	self.txtVoiceTime = self:child("ChatContentItemEx-VoiceTime")
	self.imgEffect = self:child("ChatContentItemEx-VoicePlaying")
	self.imgEmoji = self:child("ChatContentItemEx-Emoji")
	if chatSetting.chatMainSelfVoiceColor then
		--self.imgVoiceImg:SetDrawColor(getColorOfRGB(chatSetting.chatMainSelfVoiceColor))
		self.txtVoiceTime:SetTextColor(getColorOfRGB(chatSetting.chatMainSelfVoiceColor))
	end

	self.initPopHeight = 39
end

function WidgetChatContentItemEx:getData()
	return self.data
end

function WidgetChatContentItemEx:setItemContentType(contentType)
	self.contentType = contentType
end

function WidgetChatContentItemEx:getItemContentType()
	return self.contentType
end

function WidgetChatContentItemEx:initViewByData(data)
	self.data = data
	self.msgEvent = nil
	self.eventArgs = nil
	if self.data.playing then
		self.imgEffect:SetVisible(true)
	else
		self.imgEffect:SetVisible(false)
	end
	self:setSide(data.platId == Me.platformUserId)
	self:initNameColor(data)

	if not data.fromname then
		return
	end

	self.txtName:SetText("▢"..self.nameColorStr..data.fromname)
	self.lytHeadPanel:SetVisible(true)
	self.imgChatPop:SetVisible(true)
	if data.voiceTime then
		if not data.isRead then
			data.isRead = data.objID==Me.objID
		end
		self.imgEmoji:SetVisible(false)
		self.imgVoicePoint:SetVisible(not data.isRead)
		local times = math.floor(data.voiceTime/1000)

		self.txtVoiceTime:SetText("▢"..self.voiceColorStr.."".. times.."''")
		self.lytVoiceContent:SetVisible(true)
		self.imgChatPop:SetVisible(true)
		self.txtChatText:SetVisible(false)

		self.imgChatPop:SetHeight({0,self.initPopHeight+2})
		self.imgChatPop:SetWidth({0,100+150*(times/chatSetting.voiceMaxTime or 59)})
		self._root:SetHeight({0,80})
	elseif data.emoji then
		self.lytVoiceContent:SetVisible(false)
		self.imgChatPop:SetVisible(false)
		self.imgEmoji:SetVisible(true)
		if data.emoji.type == Define.chatEmojiTab.FACE then
			self.imgEmoji:SetImage(data.emoji.emojiData)
		end
		self._root:SetHeight({0, 110})
	else
		self.lytVoiceContent:SetVisible(false)
		self.imgChatPop:SetVisible(true)
		self.txtChatText:SetVisible(true)
		self.imgEmoji:SetVisible(false)
		if data.dign == Define.ChatPlayerType.server then
			self.lytHeadPanel:SetVisible(false)
			self.imgChatPop:SetVisible(false)
			self.txtName:SetVisible(false)
			local text = "▢"..self.nameColorStr.."▢"..self.contentColorStr..""..Lang:toText(data.msg)
			self:autoBarSize(text)
		else
			local finalMsg = data.msg
			local item = ShortConfig:getItemByName(finalMsg)
			if item then
				finalMsg = Lang:toText(finalMsg)
				self.msgEvent = item.event
				self.eventArgs = item.eventArgs
			end
			self.txtChatText:SetText("▢"..self.contentColorStr..""..finalMsg)
			self:autoBarSize(finalMsg)
		end
	end

	self:initHeadImg()
end
function WidgetChatContentItemEx:initHeadImg()
	self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_players")
	self.imgHeadMale:SetVisible(false)
	self.imgHeadFemale:SetVisible(false)
	self.txtHeadLevel:SetText("")
	self.imgHeadCareer:SetVisible(false)
	self.txtHeadLevel:SetVisible(false)
	if self.data.platId then
		--print("WidgetChatContentItemEx:initHeadImg:",Lib.v2s(self.data,2))
		local detailInfo = UIChatManage:getUserDetailInfo(self.data.platId)
		if detailInfo then
			self:setUserDetailInfo(detailInfo)
		else
			self:listenDetailInfo(self.data.platId)
		end

		UIChatManage:getFriendListItemSpDisplay(self.data.platId,function(info)
			if not info then
				return
			end
			if info.icon then
				self.imgHeadCareer:SetVisible(true)
				self.imgHeadCareer:SetImage(info.icon)
			end
			if info.txt then
				self.txtHeadLevel:SetVisible(true)
				self.txtHeadLevel:SetText(Lang:toText(info.txt))
			end
		end)
	end
end

function WidgetChatContentItemEx:listenDetailInfo(platId)
	if not platId then
		Lib.logError("WidgetChatContentItemEx:listenDetailInfo id is nil!")
		return
	end
	if self.userDetailInfoCancel then
		self.userDetailInfoCancel()
	end
	self.userDetailInfoCancel = Lib.lightSubscribeEvent("error!!!!! EVENT_USER_DETAIL","EVENT_USER_DETAIL"..platId, function(data)
		self:setUserDetailInfo(data)
	end)
	UIChatManage:initDetailInfo(platId)
end
function WidgetChatContentItemEx:setUserDetailInfo(data)
	if data and data.picUrl and #data.picUrl > 0  then
		self.imgHeadImg:SetImageUrl(data.picUrl)
	else
		self.imgHeadImg:SetImage("set:default_icon.json image:header_icon")
	end

	if data.sex == 1 then
		self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_players")
		self.imgHeadMale:SetVisible(true)
	else
		self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_captain")
		self.imgHeadFemale:SetVisible(true)
	end

	self.txtName:SetText("▢"..self.nameColorStr.. data.nickName)
end

function WidgetChatContentItemEx:autoBarSize(msg)
	local strW = self.txtChatText:GetFont():GetStringWidth(msg)
	local uiW = self.txtChatText:GetWidth()[2]
	uiW = uiW>0 and uiW or -uiW
	local maxWidth = 276
	local maxHeight = 75
	if strW+uiW>maxWidth then
		self.imgChatPop:SetWidth({0,maxWidth})
		uiW = maxWidth-uiW
		local offsetLine = math.floor(strW/uiW)
		self.imgChatPop:SetHeight({0,self.initPopHeight+offsetLine*27})
		self._root:SetHeight({0,maxHeight+offsetLine*27})
	else
		self.imgChatPop:SetHeight({0,self.initPopHeight})
		self.imgChatPop:SetWidth({0,math.max(strW+uiW+5,55) })
		self._root:SetHeight({0,maxHeight})
	end
end

function WidgetChatContentItemEx:initNameColor(data)
	local defaultNameColor = chatSetting.miniNiceNameColor or "FF0000"
	if chatSetting.isOpenChatHeadColor then
		self.nameColorStr = "FF"..(data.nameColor or defaultNameColor)
	else
		self.nameColorStr = "FF"..defaultNameColor
	end
	self.contentColorStr = "FF"..(chatSetting.mainNickFontColor or "000000")
	self.voiceColorStr = "FF"..(chatSetting.chatMainOtherVoiceColor or "000000")
	if self.data.platId ==Me.platformUserId then
		self.nameColorStr =  "FF"..(chatSetting.mainSelfNameColor or "33BD41")
		self.contentColorStr = "FF"..(chatSetting.mainSelfFontColor or "000000")
		self.voiceColorStr = "FF"..(chatSetting.chatMainSelfVoiceColor or "000000")
	--elseif not self.data.dign then
	--	self.nameColorStr = "FF"..(chatSetting.mainSelfNameColor or "FF0000")
	--	self.contentColorStr = "FF"..(chatSetting.mainNickFontColor or "000000")
	elseif self.data.dign == Define.ChatPlayerType.server then
		self.nameColorStr = "FFFFFFFF"
		self.contentColorStr = "FF909090"
	elseif self.data.dign == Define.ChatPlayerType.vip then
		self.nameColorStr = "FFFAFF07"
	elseif self.data.dign == Define.ChatPlayerType.svip then
		self.nameColorStr = "FFEC0420"
	end
end

function WidgetChatContentItemEx:setSide(isSelf)
	local headPanelX = 10
	local txtNameX = 100
	local emojiX = 100
	local chatPopX = 75
	if isSelf then
		self.lytHeadPanel:SetHorizontalAlignment(2)
		self.lytHeadPanel:SetXPosition({0, -headPanelX})
		self.txtName:SetHorizontalAlignment(2)
		self.txtName:SetTextHorzAlign(2)
		self.txtName:SetXPosition({0, -txtNameX})

		self.imgChatPop:SetHorizontalAlignment(2)
		self.imgChatPop:SetXPosition({0, -chatPopX})
		self.imgChatPop:SetImage("set:chat.json image:img_9_bubble_self")
		self.imgChatPop:SetStretchOffset(20,30,30,10)

		self.txtChatText:SetXPosition({0, -17})
		self.imgVoicePoint:SetHorizontalAlignment(0)
		self.imgVoicePoint:SetXPosition({0, 8})

		self.imgVoiceImg:SetHorizontalAlignment(2)
		self.imgVoiceImg:SetXPosition({0, -30})
		self.imgVoiceImg:SetRotate(0)
		self.imgVoiceImg:SetImage("set:chat.json image:img_0_voiceicon_self")

		self.txtVoiceTime:SetHorizontalAlignment(2)
		self.txtVoiceTime:SetTextHorzAlign(2)
		self.txtVoiceTime:SetXPosition({0, -70})

		self.imgEffect:SetHorizontalAlignment(2)
		self.imgEffect:SetXPosition({0, -20})
		self.imgEffect:SetProperty("EffectRotate", "180")
		self.imgEffect:SetProperty("EffectOffset", "0 -1 0")

		self.imgEmoji:SetHorizontalAlignment(2)
		self.imgEmoji:SetXPosition({0, -emojiX})
	else
		self.lytHeadPanel:SetHorizontalAlignment(0)
		self.lytHeadPanel:SetXPosition({0, headPanelX})
		self.txtName:SetHorizontalAlignment(0)
		self.txtName:SetTextHorzAlign(0)
		self.txtName:SetXPosition({0, txtNameX})

		self.imgChatPop:SetHorizontalAlignment(0)
		self.imgChatPop:SetXPosition({0, chatPopX})

		self.imgChatPop:SetImage("set:chat.json image:img_9_bubble_other")
		self.imgChatPop:SetStretchOffset(30,20,30,10)

		self.txtChatText:SetXPosition({0, -3})
		self.imgVoicePoint:SetHorizontalAlignment(2)
		self.imgVoicePoint:SetXPosition({0, -8})

		self.imgVoiceImg:SetHorizontalAlignment(0)
		self.imgVoiceImg:SetXPosition({0, 30})
		self.imgVoiceImg:SetRotate(0)
		self.imgVoiceImg:SetImage("set:chat.json image:img_0_voiceicon_other")

		self.txtVoiceTime:SetHorizontalAlignment(0)
		self.txtVoiceTime:SetTextHorzAlign(0)
		self.txtVoiceTime:SetXPosition({0, 70})

		self.imgEffect:SetHorizontalAlignment(0)
		self.imgEffect:SetXPosition({0, 20})
		self.imgEffect:SetProperty("EffectRotate", "0")
		self.imgEffect:SetProperty("EffectOffset", "0 0 0")

		self.imgEmoji:SetHorizontalAlignment(0)
		self.imgEmoji:SetXPosition({0, emojiX})
	end
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatContentItemEx:initEvent()
	self:lightSubscribe("error!!!!! script_client widget_chatContentItem lytVoiceContent event : EventWindowClick",self.lytVoiceContent, UIEvent.EventWindowClick, function()
		if not self.data.playing then
			self:onPlaySound()
		end
	end)
	self:lightSubscribe("error!!!!! script_client widget_chatContentItem imgHeadImg event : EventWindowClick",self.imgHeadImg, UIEvent.EventWindowClick, function()
		if self.data and #self.data.fromname >0 then
			if self.data and #self.data.fromname >0 then
				self.data.nameColorStr = self.nameColorStr
				UIChatManage:openChatPlayerInfoWnd(self.data.platId)
			end
		end
	end)
	self.voiceStart = Lib.lightSubscribeEvent("error!!!!! script_client widget_chatContentItem Lib event : EVENT_CHAT_VOICE_START",Event.EVENT_CHAT_VOICE_START, function(path)
		--   print("EVENT_CHAT_VOICE_START ininininininininininininininini")
		local voiceName = string.sub(path,-19)
		-- self.voiceTimer = World.Timer(2, function()

		-- end)
		if not self.data then
			--   print("EVENT_CHAT_VOICE_START but data still void")
			return
		end
		--  print("self.data.voiceTime:",self.data.voiceTime)
		--  print("voiceName:",voiceName)
		--  print("voiceName2:",voiceName2)
		local voiceName2 = string.sub(self.data.msg,-19)
		if self.data.voiceTime  and voiceName2 == voiceName then
			self.data.isRead = true
			self.data.playing = true
			self.imgVoicePoint:SetVisible(false)
			self.imgEffect:SetVisible(true)
			self.imgVoiceImg:SetVisible(false)

			-- self.imgSound:SetDrawColor({ 150/255, 255/255, 223/255 , 1 })
			-- print("-----------------EVENT_CHAT_VOICE_START  item------------------")
		else
			-- print("----------------EVENT_CHAT_VOICE_START------no pick  voiceName------------",voiceName)
			-- print("----------------EVENT_CHAT_VOICE_START------no pick  voiceName2------------",voiceName2)
		end
	end)
	self.voiceEnd = Lib.lightSubscribeEvent("error!!!!! script_client widget_chatContentItem Lib event : EVENT_CHAT_VOICE_END",Event.EVENT_CHAT_VOICE_END, function(path)

		if not self.data then
			-- print("EVENT_CHAT_VOICE_END but data still void")
			return
		end
		local voiceName = string.sub(path,-19)
		local voiceName2 = string.sub(self.data.msg,-19)
		if self.data.voiceTime  and voiceName == voiceName2 then
			self.imgEffect:SetVisible(false)
			self.imgVoiceImg:SetVisible(true)
			--self.txtVoiceTime:SetVisible(false)
			self.data.playing = false
		end

	end)

	self:lightSubscribe("error!!!!! script_client widget_chatContentItem imgChatPop event : EventWindowClick",self.imgChatPop, UIEvent.EventWindowClick, function()
		if not self.msgEvent then return end
		local func = Me[self.msgEvent]
		if func then
			local data = {
				objID = self.data.objID,
				platId = self.data.platId,
				eventArgs = self.eventArgs
			}
			func(Me, data)
		end
	end)
end

function WidgetChatContentItemEx:onPlaySound()
	if not self.data.isRead then
		self.data.isRead = true
		self.imgVoicePoint:SetVisible(false)
	end
	print("playVoice")
	VoiceManager:playVoice(self.data.msg, math.floor(self.data.voiceTime/1000))
end
function WidgetChatContentItemEx:onDestroy()
	-- print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$destory")
	if self.voiceStart then
		self.voiceStart()
	end
	if self.voiceEnd then
		self.voiceEnd()
	end
	if self.userDetailInfoCancel then
		self.userDetailInfoCancel()
	end
end

return WidgetChatContentItemEx
