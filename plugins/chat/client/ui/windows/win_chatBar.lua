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

function M:init()
    WinBase.init(self, "ChatBar.json",false)
    self:initWnd()
    self:initEvent()
end

function M:initWnd()
    self.lytBtnView = self:child("ChatBar-Button-Win")
    self.btnVoice = self:child("ChatBar-Voice")
    self.btnVoiceTouch = self:child("ChatBar-Voice-Touch")
    self.txtVoiceCount = self:child("ChatBar-Voice-Count")
    self.btnChat = self:child("ChatBar-Msg")
    self.imgRedPoint = self:child("ChatBar-Red-Point")
    self.txtChatCnt = self:child("ChatBar-New-Count")
    self.imgRedPoint:SetVisible(false)

    self.lytSound = self:child("ChatBar-Sound-Groud")
    self.txtSoundTip = self:child("ChatBar-Window-Mic-Tip")
    self.lytVoiceCancelBg = self:child("ChatBar-Voice-Cancel-Bg")
    self.imgMicIcon = self:child("ChatBar-Mic-Icon")
    self.imgMicCancelIcon = self:child("ChatBar-Mic-Cancel-Icon")
    self.imgMicIcon:SetVisible(false)
    self.imgMicCancelIcon:SetVisible(false)
    self.lytSound:SetVisible(false)

    self.isChatShow = true

    if chatSetting.chatBarPos then
        self.lytBtnView:SetXPosition({0, chatSetting.chatBarPos[1]})
        self.lytBtnView:SetYPosition({0, chatSetting.chatBarPos[2]})
    end

    if chatSetting.chatSystemColor then
        self.txtSoundTip:SetTextColor(getColorOfRGB(chatSetting.chatSystemColor))
    end

    self:root():SetLevel((chatSetting.chatLevel or 48) + 1)
end

function M:initEvent()
    self:lightSubscribe("error!!!!! script_client win_chatBar btnChat event : EventButtonClick", self.btnChat, UIEvent.EventButtonClick, function()
        UI:openWnd("chatMain", true)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_SOUND_TIME_CHANGE", Event.EVENT_SOUND_TIME_CHANGE, function(value)
        self:updateVoiceTimes()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_FREE_SOUND_TIME_CHANGE", Event.EVENT_FREE_SOUND_TIME_CHANGE, function(value)
        self:updateVoiceTimes()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_SOUND_MOON_CHANGE", Event.EVENT_SOUND_MOON_CHANGE, function(value)
        self.btnVoice:SetImage(Me:getSoundMoonCardEnable() and "set:chat_main.json image:btn_0_voice_forever" or "set:chat_main.json image:btn_0_voice")
        self.txtVoiceCount:SetVisible(not Me:getSoundMoonCardEnable())
        if Me:getSoundMoonCardEnable() then
            self.txtVoiceCount:SetText('*')
        end
    end)
    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_CHAT_POINT_CHANGE", Event.EVENT_CHAT_POINT_CHANGE, function(num, type)
        if not type then
            return
        end
        if not self.pointList then
            self.pointList = {[Define.Page.COMMON] = 0, [Define.Page.HISTORY] = 0}
        end
        self.pointList[type] = num
        self.imgRedPoint:SetVisible(true)
        if self.pointList[Define.Page.HISTORY] > 0 then
            self.imgRedPoint:SetImage("set:chat_main.json image:icon_private_point")
            self.txtChatCnt:SetText(self.pointList[Define.Page.HISTORY])
        elseif self.pointList[Define.Page.COMMON] > 0 then
            self.imgRedPoint:SetImage("set:chat_main.json image:icon_chat_point")
            self.txtChatCnt:SetText(self.pointList[Define.Page.COMMON])
        else
            self.imgRedPoint:SetVisible(false)
        end
    end)
    self:lightSubscribe("error!!!!! script_client win_chatBar btnVoice event : EventWindowTouchDown", self.btnVoiceTouch, UIEvent.EventWindowTouchDown, function()
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            return
        end
        self.lytSound:SetVisible(true)
        self.isRecording = true
        UI:getWnd("chatMain"):startRecordMsg()
        self.txtSoundTip:SetText(Lang:toText("ui.chat.send.voice"))
        self.imgMicIcon:SetVisible(true)
        self.imgMicCancelIcon:SetVisible(false)
        self:root():SetAlwaysOnTop(true)
    end)

    self:lightSubscribe("error!!!!! script_client win_chatBar btnVoice event : EventWindowTouchUp", self.btnVoiceTouch, UIEvent.EventWindowTouchUp, function()
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            return
        end
        self.lytSound:SetVisible(false)
        self.isRecording = false
        UI:getWnd("chatMain"):stopRecordMsg()
        if self.forceOnTop then
            self:root():SetAlwaysOnTop(false)
        end
    end)

    self:lightSubscribe("error!!!!! script_client win_chatBar btnVoice event : EventWindowTouchMove", self.btnVoiceTouch, UIEvent.EventWindowTouchMove, function()
        if not self.isRecording then return end
        self.txtSoundTip:SetText(Lang:toText("ui.chat.send.voice"))
        self.imgMicIcon:SetVisible(true)
        self.imgMicCancelIcon:SetVisible(false)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lytVoiceCancelBg event : EventWindowTouchUp", self.lytVoiceCancelBg, UIEvent.EventWindowTouchMove, function()
        if not self.isRecording then return end
        self.txtSoundTip:SetText(Lang:toText("ui.chat.cancel.send.voice"))
        self.imgMicIcon:SetVisible(false)
        self.imgMicCancelIcon:SetVisible(true)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lytVoiceCancelBg event : EventWindowTouchUp", self.lytVoiceCancelBg, UIEvent.EventWindowTouchUp, function()
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            return
        end
        self.lytSound:SetVisible(false)
        self.isRecording = false
        UI:getWnd("chatMain"):cancelRecordMsg()
        if self.forceOnTop then
            self:root():SetAlwaysOnTop(false)
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_SET_CHAT_BAR_POS", Event.EVENT_SET_CHAT_BAR_POS, function(pos)
        self:setPos(pos or false)
    end)
end

function M:setChatShow(isShow)
    self.isChatShow = isShow
    self.btnChat:SetVisible(not isShow)
end

function M:ShowBar(isShow)
    self.lytBtnView:SetVisible(isShow)
end

function M:setPos(pos)
    local _p = pos or chatSetting.chatBarPos
    self.lytBtnView:SetXPosition({0, _p[1]})
    self.lytBtnView:SetYPosition({0, _p[2]})
end

function M:setForceOnTop(forceOnTop)
    self.forceOnTop = forceOnTop
    self:root():SetAlwaysOnTop(forceOnTop)
end

function M:setLevelOffset(offset)
    self:root():SetLevel((chatSetting.chatLevel or 48) + offset)
end

function M:updateVoiceTimes()
    if Me:getSoundMoonCardEnable() then
        self.txtVoiceCount:SetText('*')
    else
        if Me:getSoundTimes() > 0 then
            self.txtVoiceCount:SetText(Me:getSoundTimes())
        else
            if Me:getFreeSoundTimes() > 0 then
                self.txtVoiceCount:SetText(Me:getFreeSoundTimes())
            else
                self.txtVoiceCount:SetText("")
            end
        end
    end
end

function M:onClose()
end

function M:onOpen()
    if not self.isInit then
        UI:closeWnd("chat")
        self.isInit = true
    end
end