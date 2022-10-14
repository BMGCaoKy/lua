local chatSetting = World.cfg.chatSetting
local ShortConfig = T(Config, "ShortConfig")
local widget_base = require "ui.widget.widget_base"
---@class WidgetChatContentItemEx : widget_base
local WidgetChatContentItemEx = Lib.derive(widget_base)
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
local playerImgPool = {}

function WidgetChatContentItemEx:init()
	widget_base.init(self, "ChatContentItemEx.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatContentItemEx:initUI()
	self.imgHeadImg = self:child("ChatContentItemEx-HeadImg")
	self.txtName = self:child("ChatContentItemEx-Name")
	self.imgChatPop = self:child("ChatContentItemEx-ChatPop")
	self.txtChatText = self:child("ChatContentItemEx-ChatText")
	self.lytVoiceContent = self:child("ChatContentItemEx-VoiceContent")
	self.imgVoicePoint = self:child("ChatContentItemEx-VoicePoint")
	self.imgVoiceImg = self:child("ChatContentItemEx-VoiceImg")
	self.txtVoiceTime = self:child("ChatContentItemEx-VoiceTime")
	self.imgEffect = self:child("ChatContentItemEx-VoicePlaying")
	self.imgEmoji = self:child("ChatContentItemEx-Emoji")
	if chatSetting.chatVoiceColor then
		self.imgVoiceImg:SetDrawColor(getColorOfRGB(chatSetting.chatVoiceColor))
		self.txtVoiceTime:SetTextColor(getColorOfRGB(chatSetting.chatVoiceColor))
	end
end

function WidgetChatContentItemEx:getData()
	return self.data
end

function WidgetChatContentItemEx:initViewByData(data)
	self.data = data
	self.event = nil
	self.eventArgs = nil
	if self.data.playing then
		self.imgEffect:SetVisible(true)
	else
		self.imgEffect:SetVisible(false)
	end
	self:setSide(data.fromname == Me.name)
	self:initNameColor(data.nameColor)

	self:initHeadImg()


	if not data.fromname then
		return
	end

	self.txtName:SetText("▢"..self.nameColorStr..data.fromname)
	self.imgHeadImg:SetVisible(true)
	self.imgChatPop:SetVisible(true)
	if data.voiceTime then
		if not data.isRead then
			data.isRead = data.objID==Me.objID
		end
		self.imgEmoji:SetVisible(false)
		self.imgVoicePoint:SetVisible(not data.isRead)
		local times = math.floor(data.voiceTime/1000)
		self.txtVoiceTime:SetText(times.."''")
		self.lytVoiceContent:SetVisible(true)
		self.imgChatPop:SetVisible(true)
		self.txtChatText:SetVisible(false)
		-- if not Me.test then
		--     Me.test = "aaaa"
		-- end
		-- Me.test = Me.test.. "a"

		-- data.fromname = Me.test

		self.imgChatPop:SetHeight({0,39})
		self.imgChatPop:SetWidth({0,100+150*(times/chatSetting.voiceMaxTime or 59)})
		self._root:SetHeight({0,72})
	elseif data.emoji then
		self.lytVoiceContent:SetVisible(false)
		self.imgChatPop:SetVisible(false)
		self.imgEmoji:SetVisible(true)
		self.imgEmoji:SetImage(data.emoji)
		self._root:SetHeight({0,92})
	else
		self.lytVoiceContent:SetVisible(false)
		self.imgChatPop:SetVisible(true)
		self.txtChatText:SetVisible(true)
		self.imgEmoji:SetVisible(false)
		if  data.dign == Define.ChatPlayerType.server then
			self.imgHeadImg:SetVisible(false)
			self.imgChatPop:SetVisible(false)
			self.txtName:SetText("▢"..self.nameColorStr.."▢"..self.contentColorStr..""..data.msg)
		else
			local text = data.msg
			local item = ShortConfig:getItemByName(text)
			if item then
				text = Lang:toText(text)
				self.event = item.event
				self.eventArgs = item.eventArgs
			end
			self.txtChatText:SetText("▢"..self.contentColorStr..""..text)
			self:autoBarSize(text)
		end
	end
end
function WidgetChatContentItemEx:initHeadImg()
	print("self.data:",Lib.v2s(self.data,2))
	if self.data.platId then
		if not playerImgPool[self.data.platId] then
			AsyncProcess.GetUserDetail(self.data.platId, function (data)
                if data and data.picUrl and #data.picUrl > 0  then
                    playerImgPool[self.data.platId] = data.picUrl
                    --print("data.picUrl:",data.picUrl)
                    self.imgHeadImg:SetImageUrl(data.picUrl)
                else
                    self.imgHeadImg:SetImage("set:default_icon.json image:header_icon")
                end
			end)
		else
			self.imgHeadImg:SetImageUrl(playerImgPool[self.data.platId])
		end
	end
end

function WidgetChatContentItemEx:autoBarSize(msg)
	local strW = self.txtChatText:GetFont():GetStringWidth(msg)
	local uiW = self.txtChatText:GetWidth()[2]
	uiW = uiW>0 and uiW or -uiW
	print("strW",strW)
	print("uiW",uiW)

	if strW+uiW>480 then
		self.imgChatPop:SetWidth({0,480})
		uiW = 480-uiW
		local offsetLine = math.floor(strW/uiW)
		self.imgChatPop:SetHeight({0,39+offsetLine*20})
		self._root:SetHeight({0,72+offsetLine*20})
	else
		self.imgChatPop:SetHeight({0,39})
		self.imgChatPop:SetWidth({0,math.max(strW+uiW+5,55) })
		self._root:SetHeight({0,72})
	end
end

function WidgetChatContentItemEx:initNameColor(color)
	local defaultNameColor = chatSetting.chatNiceNameColor or "FF0000"
	self.nameColorStr = "FF"..(color or defaultNameColor)
	self.contentColorStr = "FF"..(chatSetting.chatFontColor or "000000")
	if self.data.fromname ==Me.name then
		self.nameColorStr = "FF"..(chatSetting.chatSelfNameColor or "33BD41")
	--elseif not self.data.dign then
	--	self.nameColorStr = "FF"..(chatSetting.chatNiceNameColor or "FF0000")
	elseif self.data.dign == Define.ChatPlayerType.server then
		self.nameColorStr = "FFFFFFFF"
		self.contentColorStr = "FF909090"
	--elseif self.data.dign == Define.ChatPlayerType.vip then
	--	self.nameColorStr = "FFFAFF07"
	--elseif self.data.dign == Define.ChatPlayerType.svip then
	--	self.nameColorStr = "FFEC0420"
	end
end

function WidgetChatContentItemEx:setSide(isSelf)
	if isSelf then
		self.imgHeadImg:SetHorizontalAlignment(2)
		self.imgHeadImg:SetXPosition({0, -20})
		self.txtName:SetHorizontalAlignment(2)
		self.txtName:SetTextHorzAlign(2)
		self.txtName:SetXPosition({0, -110})

		self.imgChatPop:SetHorizontalAlignment(2)
		self.imgChatPop:SetXPosition({0, -110})
		self.imgChatPop:SetImage("set:chat_main.json image:img_9_smsbd_self")
		self.imgChatPop:SetStretchOffset(20,30,30,10)

		self.txtChatText:SetXPosition({0, -20})
		self.imgVoicePoint:SetHorizontalAlignment(0)
		self.imgVoicePoint:SetXPosition({0, 8})

		self.imgVoiceImg:SetHorizontalAlignment(2)
		self.imgVoiceImg:SetXPosition({0, -30})
		self.imgVoiceImg:SetRotate(180)

		self.txtVoiceTime:SetHorizontalAlignment(2)
		self.txtVoiceTime:SetTextHorzAlign(2)
		self.txtVoiceTime:SetXPosition({0, -70})

		self.imgEffect:SetHorizontalAlignment(2)
		self.imgEffect:SetXPosition({0, -20})
		self.imgEffect:SetProperty("EffectRotate", "180")
		self.imgEffect:SetProperty("EffectOffset", "0 -1 0")

		self.imgEmoji:SetHorizontalAlignment(2)
		self.imgEmoji:SetXPosition({0, -110})
	else
		self.imgHeadImg:SetHorizontalAlignment(0)
		self.imgHeadImg:SetXPosition({0, 20})
		self.txtName:SetHorizontalAlignment(0)
		self.txtName:SetTextHorzAlign(0)
		self.txtName:SetXPosition({0, 110})

		self.imgChatPop:SetHorizontalAlignment(0)
		self.imgChatPop:SetXPosition({0, 110})

		self.imgChatPop:SetImage("set:chat_main.json image:img_9_smsbd_other")
		self.imgChatPop:SetStretchOffset(30,20,30,10)

		self.txtChatText:SetXPosition({0, -10})
		self.imgVoicePoint:SetHorizontalAlignment(2)
		self.imgVoicePoint:SetXPosition({0, -8})

		self.imgVoiceImg:SetHorizontalAlignment(0)
		self.imgVoiceImg:SetXPosition({0, 30})
		self.imgVoiceImg:SetRotate(0)

		self.txtVoiceTime:SetHorizontalAlignment(0)
		self.txtVoiceTime:SetTextHorzAlign(0)
		self.txtVoiceTime:SetXPosition({0, 70})

		self.imgEffect:SetHorizontalAlignment(0)
		self.imgEffect:SetXPosition({0, 20})
		self.imgEffect:SetProperty("EffectRotate", "0")
		self.imgEffect:SetProperty("EffectOffset", "0 0 0")

		self.imgEmoji:SetHorizontalAlignment(0)
		self.imgEmoji:SetXPosition({0, 110})
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
			self:onOpenInfo()
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
		-- print("----------------EVENT_CHAT_VOICE_END------no pick  voiceName------------",voiceName)
		-- print("----------------EVENT_CHAT_VOICE_END------no pick  voiceName2------------",voiceName2)
		if self.data.voiceTime  and voiceName == voiceName2 then
			self.imgEffect:SetVisible(false)
			self.imgVoiceImg:SetVisible(true)
			--self.txtVoiceTime:SetVisible(false)
			self.data.playing = false
		end

	end)
	self:lightSubscribe("error!!!!! script_client widget_chatContentItem imgChatPop event : EventWindowClick",self.imgChatPop, UIEvent.EventWindowClick, function()
		if not self.event then return end
		local func = Me[self.event]
		if func then
			local data = {
				objID = self.data.objID,
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
	VoiceManager:playVoice(self.data.msg)
end
function WidgetChatContentItemEx:onDestroy()
	-- print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$destory")
	if self.voiceStart then
		self.voiceStart()
	end
	if self.voiceEnd then
		self.voiceEnd()
	end
end
function WidgetChatContentItemEx:onOpenInfo()
	-- print("=======================================self.data.objID",Lib.v2s(self.data))
	if self.data.objID == -1 or not self.data.fromname or self.data.fromname =="" or not self.data.platId or self.data.platId == Me.platformUserId then
		return
	end
	-- print("=======================================self.data.objID",self.data.objID)
	-- print("=======================================Me.objID",Me.objID)
	Lib.emitEvent("EVENT_OPEN_CHAT_PLAYER", {self.data.objID,self.data.fromname,self.nameColorStr,self.data.platId})
	UI:openWnd("chatPlayerInfo", {
		objId = self.data.objID,
		name = self.data.fromname,
		nameColor = self.nameColorStr,
		uId = self.data.platId
	})
end

return WidgetChatContentItemEx
