local chatSetting = World.cfg.chatSetting or {}
---@type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

function M:init()
    WinBase.init(self, "ChatBar.json",false)
    self:initWnd()
    self:initEvent()
    self.horizontalAlignment = chatSetting.alignment and chatSetting.alignment.horizontalAlignment or 1
    self.verticalAlignment = chatSetting.alignment and chatSetting.alignment.verticalAlignment or 2
    self.isBigState = false
    self:initBarPos()
end

function M:initWnd()
    self.lytBtnView = self:child("ChatBar-Button-Win")
    self.btnVoice = self:child("ChatBar-Voice")
    self.iconVoice = self:child("ChatBar-VoiceIcon")
    self.txtVoiceCount = self:child("ChatBar-Voice-Count")
    self.btnChat = self:child("ChatBar-Msg")
    self.imgRedPoint = self:child("ChatBar-Red-Point")
    self.txtChatCnt = self:child("ChatBar-New-Count")
    self.imgRedPoint:SetVisible(false)
    self.btnFriend = self:child("ChatBar-Friend")
    self.imgFriendRedIcon = self:child("ChatBar-friendRedIcon")
    self.txtFriendRedNum = self:child("ChatBar-friendRedNum")
    self.imgFriendRedIcon:SetVisible(false)

    self.lytSound = self:child("ChatBar-Sound-Groud")
    self.txtSoundTip = self:child("ChatBar-Window-Mic-Tip")
    self.lytVoiceCancelBg = self:child("ChatBar-Voice-Cancel-Bg")
    self.lytSound:SetVisible(false)

    self.imgSoundCancelIcon = self:child("ChatBar-Mic-CancelIcon")
    self.imgSoundMicStartIcon = self:child("ChatBar-Mic-StartIcon")
    self:updateVoiceIconShow(2)

    if World.cfg.chatSetting and World.cfg.chatSetting.chatLevel then
        self:root():SetLevel(World.cfg.chatSetting.chatLevel)
    end
    self.lytBtnView:SetVisible(true)

    self.btnChat:SetVisible(chatSetting.isShowChatBtn)
    self.btnFriend:SetVisible(chatSetting.isShowFriendBtn)
    self.btnVoice:SetVisible(chatSetting.isShowVoiceBtn)

    self:updateVoiceTimes()
end

function M:initEvent()
    self:lightSubscribe("error!!!!! script_client win_chatBar btnFriend event : EventButtonClick", self.btnFriend, UIEvent.EventButtonClick, function()
        UIChatManage:showChatViewByType(Define.chatWinSizeType.mainChat, Define.Page.FRIEND)
    end)

    self:lightSubscribe("error!!!!! script_client win_chatBar btnChat event : EventButtonClick", self.btnChat, UIEvent.EventButtonClick, function()
        UIChatManage:showChatViewByType(Define.chatWinSizeType.mainChat, Define.Page.COMMON)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_SOUND_TIME_CHANGE", Event.EVENT_SOUND_TIME_CHANGE, function(value)
        self:updateVoiceTimes()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_FREE_SOUND_TIME_CHANGE", Event.EVENT_FREE_SOUND_TIME_CHANGE, function(value)
        self:updateVoiceTimes()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_SOUND_MOON_CHANGE", Event.EVENT_SOUND_MOON_CHANGE, function(value)
        self.iconVoice:SetImage(Me:getSoundMoonCardEnable() and "set:chat.json image:btn_0_voice_opened" or "set:chat.json image:btn_0_voice")
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
            self.pointList = {}
        end
        self.pointList[type] = num or 0
        self.imgRedPoint:SetVisible(true)

        local chatBarRedShow = chatSetting.chatBarRedShow or {}
        local totalRed = 0
        for _, tabKey in pairs(chatBarRedShow) do
            if self.pointList[tabKey] and self.pointList[tabKey] > 0 then
                totalRed = totalRed + self.pointList[tabKey]
            end
        end
        -- 现在主界面的聊天红点
        if totalRed > 0 then
            self.imgRedPoint:SetImage("set:chat.json image:icon_chat_point")
            self.txtChatCnt:SetText(totalRed)
        else
            self.imgRedPoint:SetVisible(false)
        end
    end)
    self:lightSubscribe("error!!!!! script_client win_chatBar btnVoice event : EventWindowTouchDown", self.btnVoice, UIEvent.EventWindowTouchDown, function()
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            self:stopClickVoiceRecord()
            return
        end
        self.lytSound:SetVisible(true)
        self.isRecording = true
        UI:getWnd("chatMain"):startRecordMsg()
        self.txtSoundTip:SetText(Lang:toText("ui.chat.send.voice"))
        self:updateVoiceIconShow(2)
        self:root():SetAlwaysOnTop(true)
    end)

    self:lightSubscribe("error!!!!! script_client win_chatBar btnVoice event : EventWindowTouchUp", self.btnVoice, UIEvent.EventWindowTouchUp, function()
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            self:stopClickVoiceRecord()
            return
        end
        if not self.isRecording then return end

        UI:getWnd("chatMain"):stopRecordMsg()
        self:voicedSuccess()
    end)

    self:lightSubscribe("error!!!!! script_client win_chatBar btnVoice event : EventWindowTouchMove", self.btnVoice, UIEvent.EventWindowTouchMove, function()
        if not self.isRecording then return end
        self.txtSoundTip:SetText(Lang:toText("ui.chat.send.voice"))
        self:updateVoiceIconShow(2)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lytVoiceCancelBg event : EventWindowTouchUp", self.lytVoiceCancelBg, UIEvent.EventWindowTouchMove, function()
        if not self.isRecording then return end
        self.txtSoundTip:SetText(Lang:toText("ui.chat.cancel.send.voice"))
        self:updateVoiceIconShow(3)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lytVoiceCancelBg event : EventWindowTouchUp", self.lytVoiceCancelBg, UIEvent.EventWindowTouchUp, function()
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            self:stopClickVoiceRecord()
            return
        end
        self.lytSound:SetVisible(false)
        self.isRecording = false
        UI:getWnd("chatMain"):cancelRecordMsg()
        self:root():SetAlwaysOnTop(false)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chatBar Lib event : EVENT_SET_CHAT_BAR_POS", Event.EVENT_SET_CHAT_BAR_POS, function(value)
        self.isBigState = value
        self:initBarPos()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_SET_CHAT_ALIGNMENT", Event.EVENT_SET_CHAT_ALIGNMENT, function(horizontalType, verticalType, offset, barOffset)
        self:setAlignmentType(horizontalType, verticalType, offset or false, barOffset)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client widget_chatTabItem Lib event : EVENT_UPDATE_FRIEND_RED_NUM",Event.EVENT_UPDATE_FRIEND_RED_NUM, function(redNum)
        self.imgFriendRedIcon = self:child("ChatBar-friendRedIcon")
        self.txtFriendRedNum = self:child("ChatBar-friendRedNum")
        self.imgFriendRedIcon:SetVisible(false)

        self.txtFriendRedNum:SetText( redNum>99 and "99+" or redNum.."")
        if redNum > 0 then
            self.imgFriendRedIcon:SetVisible(true)
        else
            self.imgFriendRedIcon:SetVisible(false)
        end
    end)
end

function M:stopClickVoiceRecord()
    if self.isRecording then
        UI:getWnd("chatMain"):cancelRecordMsg()
    end
    self.lytSound:SetVisible(false)
    self.isRecording = false
    self:root():SetAlwaysOnTop(false)
end

function M:voicedSuccess()
    self.lytSound:SetVisible(false)
    self.isRecording = false
    self:root():SetAlwaysOnTop(false)
end

function M:updateVoiceIconShow(vState)
    if vState == 1 then
        self.imgSoundMicStartIcon:SetVisible(false)
        self.imgSoundCancelIcon:SetVisible(false)
    elseif vState == 2 then
        self.imgSoundMicStartIcon:SetVisible(true)
        self.imgSoundCancelIcon:SetVisible(false)
    elseif vState == 3 then
        self.imgSoundMicStartIcon:SetVisible(false)
        self.imgSoundCancelIcon:SetVisible(true)
    end
end

function M:setAlignmentType(horizontalType, verticalType, offset, barOffset)
    if not horizontalType then return end
    if not verticalType then return end
    self.horizontalAlignment = horizontalType
    self.verticalAlignment = verticalType
    self.alignmentOffset = barOffset
    self:initBarPos()
end

function M:initBarPos()
    self.lytBtnView:SetHorizontalAlignment(self.horizontalAlignment)
    self.lytBtnView:SetVerticalAlignment(self.verticalAlignment)

    local offset =chatSetting.alignment and chatSetting.alignment.barOffset or {0,0,0,0}
    local _off = self.alignmentOffset or offset

    local barPosy
    if self.isBigState then
        barPosy = _off[5]
        self.lytBtnView:SetYPosition({_off[3], barPosy})
    else
        barPosy = _off[4]
        self.lytBtnView:SetYPosition({_off[3], barPosy})
    end
    self.lytBtnView:SetXPosition({_off[1],_off[2]})
end

function M:ShowBar(isShow)
    self.lytBtnView:SetVisible(isShow)
end

function M:setChatBarPos(isBig)
    --self.lytBtnView:SetXPosition({0, 10})

end

function M:setForceOnTop(forceOnTop)
    self.forceOnTop = forceOnTop
    self:root():SetAlwaysOnTop(forceOnTop)
end

function M:setRootLevel(level)
    self:root():SetLevel(level)
end

function M:updateVoiceTimes()
    if Me:getSoundMoonCardEnable() then
        self.txtVoiceCount:SetText('*')
    else
        if Me:getFreeSoundTimes() > 0 then
            self.txtVoiceCount:SetText(Me:getFreeSoundTimes())
        else
            if Me:getSoundTimes() > 0 then
                self.txtVoiceCount:SetText(Me:getSoundTimes())
            else
                self.txtVoiceCount:SetText("")
            end
        end
    end
end

function M:onClose()
end

function M:onOpen()
end