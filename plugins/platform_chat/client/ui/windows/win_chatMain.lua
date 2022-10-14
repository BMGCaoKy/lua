local UIAnimationManager = T(UILib, "UIAnimationManager") --@type UIAnimationManager
local LuaTimer = T(Lib, "LuaTimer")
local chatSetting = World.cfg.chatSetting or {}
local ShortConfig = T(Config, "ShortConfig")

--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

local misc = require "misc"
local now_nanoseconds = misc.now_nanoseconds
local function getTime()
    return now_nanoseconds() / 1000000
end

local WINDOW = {
    SETTING = 1,
    PLAYER = 2,
    SOUND = 3,
}

function M:init()
    WinBase.init(self, "ChatMain.json")
    self:initUI()
    self:initEvent()
end

function M:initUI()
    local begin = getTime()
    local begin1
    begin1 = getTime()

    begin1 = getTime()

    self.maxSendLen = chatSetting.maxMsgSize or 150
    
    --已申请过好友的列表
    self.addedFriendList = {}
    --锁屏状态列表
    self.lockScreenList = {}
    --自动播放状态表
    self.autoVoiceStateList = {}
    --右侧栏item实例表
    self.tabList = {}

    --新消息数量列表
    self.newMsgList = {}

    self:initSendTime()

    --拦截交互事件
    self:root():SetParentTouch(false)


    --聊天内容通用虚拟列表及其适配器初始化
    self.lytContent = self:child("ChatMain-Content-Pos")

    --当前页面索引
    self.curTab = Define.Page.COMMON
    self.lstTabContentEx = {}
    self.exInfoCache = {}
    -- 初始化聊天标签页数据列表
    for _, pageType in pairs(Define.Page) do
        self.lstTabContentEx[pageType] = UIMgr:new_widget("grid_view")
        self.lstTabContentEx[pageType]:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
        self.lstTabContentEx[pageType]:SetAutoColumnCount(false)
        self.lstTabContentEx[pageType]:InitConfig(0, 1, 1)
        self.lytContent:AddChildWindow(self.lstTabContentEx[pageType])
        self.lstTabContentEx[pageType]:SetVisible(false)

        self.exInfoCache[pageType] = {}
    end

    self.btnGotoBottom = self:child("ChatMain-Go-Bottom")
    self.btnGotoBottom:SetVisible(false)
    self.btnGotoNewMsg = self:child("ChatMain-Bottom-NewMsg")
    self.btnNewMsgText = self:child("ChatMain-New-Msg-Text")
    self.btnGotoNewMsg:SetVisible(false)
    self.sendMsgText = ""

    --其他交互项目初始化
    self.imgBg = self:child("ChatMain-Bg")
    self.lytPut = self:child("ChatMain-Input")
    self.btnMic = self:child("ChatMain-Mic")
    self.txtMicCnt = self:child("ChatMain-MicCount")
    self.imgMicIcon = self:child("ChatMain-Window-Mic")
    -- self.txtMicCnt:SetText(Me:getSoundTimes())
    self.m_inputBox = self:child("ChatMain-Input-Box")
    self.m_inputBox:SetMaxLength(chatSetting.maxMsgSize or 150)
    --self.m_inputBox:SetXPosition({0, 20})

    self.m_inputBtnSend = self:child("ChatMain-Input-BtnSend")
    self.btnEmoji = self:child("ChatMain-Emoji")
    self.lytWindow = self:child("ChatMain-Window")
    self.lytWindowClose = self:child("ChatMain-Window-Close")
    self.btnWindowClose = self:child("ChatMain-Close-Btn")

    self.inputBoxText = self:child("ChatMain-Input-Box-Text")
    self.inputBoxText:SetText(Lang:toText("ui.chat.click.chat"))
    self.inputBoxText:SetVisible(true)

    self.lytNoInputPanel = self:child("ChatMain-noInputPanel")
    self.txtNoInputTips = self:child("ChatMain-noInputTips")
    self.btnTeamHallBtn = self:child("ChatMain-teamHallBtn")
    self.lytNoInputPanel:SetVisible(false)

    --语音聊天操作面板
    self.lytSoundGround = self:child("ChatMain-Sound-Groud")
    self.txtSoundTime = self:child("ChatMain-Window-Time")
    self.txtSoundTime:SetVisible(false)
    self.btnSoundSend = self:child("ChatMain-Window-Send")
    self.txtSoundSend = self:child("ChatMain-Window-Send-Txt")
    self.txtSoundSend:SetText(Lang:toText("ui.chat.press.sound"))
    self.btnSoundCancel = self:child("ChatMain-Window-Cancel")
    self.lytVoiceCancelBg = self:child("ChatMain-Voice-Cancel-Bg")
    self.btnKeyBoard = self:child("ChatMain-Keyboard")
    self.txtSoundTip = self:child("ChatMain-Window-Mic-Tip")
    self.imgSoundMicStartIcon = self:child("ChatMain-Mic-StartIcon")
    self.imgSoundCancelIcon = self:child("ChatMain-Mic-CancelIcon")
    self.imgSoundMicStopIcon = self:child("ChatMain-Mic-StopIcon")
    self:updateVoiceIconShow(1)

    --设置交互操作面板
    self.lytSettingWindow = self:child("ChatMain-Setting-Window")
    --self.lytSettingCancel = self:child("ChatMain-Setting-Cancel")
    self.chkAutoPlay = self:child("ChatMain-Setting-Autoplay-Check")
    self.chkLock = self:child("ChatMain-Setting-Lock-Check")
    self.txtAutoPlay = self:child("ChatMain-Setting-AutoPlay")
    self.txtLock = self:child("ChatMain-Setting-Lock")
    self.txtAutoPlay:SetText(Lang:toText("ui.chat.autoplay"))
    self.txtLock:SetText(Lang:toText("ui.chat.lock"))

    --右侧切换栏
    self.ltTabList = self:child("ChatMain-Sel-List")
    self.ltTabList:SetProperty("BetweenDistance", "0")

    self.lytFriendPanel = self:child("ChatMain-friendPanel")
    self.lytPrivatePanel = self:child("ChatMain-privatePanel")
    self.lytNearPanel = self:child("ChatMain-nearPanel")
    self.lytChatPanel = self:child("ChatMain-chatPanel")
    self.lytChatPanel:SetVisible(true)
    self.lytFriendPanel:SetVisible(false)
    self.lytPrivatePanel:SetVisible(false)
    self.lytNearPanel:SetVisible(false)

    --语音录音最后剩余时间
    self.lastVoiceTime = chatSetting.voiceLastTime or 10

    self:initPrivateWnd()
    self:initFriendWnd()
    self:initNearWnd()

    if World.cfg.chatSetting and World.cfg.chatSetting.chatLevel then
        self:root():SetLevel(World.cfg.chatSetting.chatLevel)
    end
end

function M:initSendTime()
    -- 聊天间隔时间
    self.duration = chatSetting.duration or 2
    -- 上次发送消息的时间
    self.lastSendTime = {}
    -- 可以发送消息（文字与语音）的标识
    self.canSend = {}
    for _, tabKey in pairs(Define.Page) do
        self.lastSendTime[tabKey] = 0
        self.canSend[tabKey] = true
    end

    self.specialSendLimit = chatSetting.emojiSendLimit or {
        limitTime = 15,
        limitTimes = 3,
        cdTime = 30
    }
    self.specialSend = {}
    for _, val in pairs(Define.chatEmojiTab) do
        self.specialSend[val] = {
            cd = 0,
            record = {}
        }
    end
end

function M:onShow(isShow, openTab)
    if isShow then
        if not UI:isOpen(self) then
            UI:openWnd("chatMain", openTab)
        end
    else
        self:onHide()
    end
end

function M:onHide()
    UI:closeWnd("chatMain")
end

function M:onOpen(openTab)
    self.isShow = true
    self:initViewShow(openTab)
    self:updateSoundTimes()
    -- 好友邀请消息
    AsyncProcess.LoadUserRequests()

    self:startOnlineTimer()
end

function M:initViewShow(openTab)
    self:initTabList()
    self:onClickTab(openTab or self.curTab)

    self.lytChatFriend:invoke("updateProfileAndAddBtnShow")

    self:showOrHideWindowByType(WINDOW.SOUND, false)

    self:initAllExConfig()

    if self.curTab ~= Define.Page.FRIEND then
        self:loadExMsgCache(self.curTab)
    end
    self:updateLytPutShowWithTab()
    self:updateBtnEmojiShowWithTab()
    if self.lstTabContentEx[self.curTab] then
        self.lstTabContentEx[self.curTab]:SetVisible(self.curTab ~= Define.Page.FRIEND)
    end

    self.ltTabList:SetVisible(true and not self.hideTabList)
    self.lytWindowClose:SetVisible(true)
    self.btnWindowClose:SetVisible(true)
    self.txtAutoPlay:SetVisible(chatSetting.isShowAutoPlayVoice)

    self:gotoBottom()
end

function M:initFriendWnd()
    Me:initClientFriendInfo()
    self.lytChatFriend = UIMgr:new_widget("chatFriend")
    self.lytChatFriend:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lytFriendPanel:AddChildWindow(self.lytChatFriend)
    self.firstGetFriendData = false
end

function M:initNearWnd()
    self.lytChatNear = UIMgr:new_widget("chatNearWnd")
    self.lytChatNear:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lytNearPanel:AddChildWindow(self.lytChatNear)
end

function M:refreshRequestsList()
    local requests = FriendManager.requests
    self.lytChatFriend:invoke("updateFriendApplyList", requests)
end

function M:initPrivateWnd()
    self.lytChatPrivate = UIMgr:new_widget("chatPrivate")
    self.lytChatPrivate:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lytPrivatePanel:AddChildWindow(self.lytChatPrivate)
end

function M:updateVoiceIconShow(vState)
    if vState == 1 then
        self.btnSoundSend:SetImage(chatSetting.voicePlayNormalRes)
        self.imgMicIcon:SetVisible(false)
        self.imgSoundMicStartIcon:SetVisible(true)
        self.imgSoundMicStopIcon:SetVisible(false)
        self.imgSoundCancelIcon:SetVisible(false)
        self.btnSoundCancel:SetVisible(false)
        self.lytVoiceCancelBg:SetVisible(false)
    elseif vState == 2 then
        self.btnSoundSend:SetImage(chatSetting.voicePlayPushRes)
        self.imgMicIcon:SetVisible(true)
        self.imgSoundMicStartIcon:SetVisible(true)
        self.imgSoundMicStopIcon:SetVisible(false)
        self.imgSoundCancelIcon:SetVisible(false)

        self.btnSoundCancel:SetVisible(true)
        self.lytVoiceCancelBg:SetVisible(true)
    elseif vState == 3 then
        self.btnSoundSend:SetImage(chatSetting.voicePlayPushRes)
        self.imgMicIcon:SetVisible(true)
        self.imgSoundMicStartIcon:SetVisible(false)
        self.imgSoundMicStopIcon:SetVisible(false)
        self.imgSoundCancelIcon:SetVisible(true)
        self.btnSoundCancel:SetVisible(true)
        self.lytVoiceCancelBg:SetVisible(true)
    end
end

function M:updateSoundTimes()
    if not Me.getSoundMoonCardEnable then
        return
    end
    if Me:getSoundMoonCardEnable() then
        Lib.logDebug('is moon card')
        self.txtMicCnt:SetText('*')
    else
        if Me:getSoundTimes() > 0 then
            Lib.logDebug('is purchase sound')
            self.txtMicCnt:SetText(Me:getSoundTimes())
        else
            if Me:getFreeSoundTimes() > 0 then
                local freeSoundTimes = Me:getFreeSoundTimes()
                self.txtMicCnt:SetText(freeSoundTimes)
            else
                self.txtMicCnt:SetText("")
            end
        end
    end
end

function M:onClose()
    self.isShow = false
    if UI:isOpen("chatEmoji") then
        UI:getWnd("chatEmoji"):onShow(false)
    end
    -- 关闭渐隐定时器
    -- self:stopHideTimer()
    self:stopOnlineTimer()
end
function M:initEvent()
    self:lightSubscribe("error!!!!! script_client win_chat m_inputBtnSend event : EventButtonClick", self.m_inputBtnSend, UIEvent.EventButtonClick, function()
        if not self:checkCanSend() then return end
        self:sendChatMessage()
    end)

    self:lightSubscribe("error!!!!! script_client win_chat m_inputBox event : EventEditTextInput", self.m_inputBox, UIEvent.EventEditTextInput, function(window, trigger)

        local inputStr = self.m_inputBox:GetPropertyString("Text", "") or ""
        self.sendMsgText = tostring(inputStr)

        local msgList = UIChatManage:splitStringToMultiLine(self.lytPut:GetPixelSize().x - 20, self.sendMsgText)
        if msgList[1] then
            self.m_inputBox:SetProperty("Text", msgList[1] .. (msgList[2] and ".." or ""))
        end

        if trigger == 1 then
        elseif trigger == 0 then
            if self:checkCanSend() then
                self:sendChatMessage()
            end
        end

    end)

    self:lightSubscribe("error!!!!! script_client win_chat m_inputBox event : EventWindowTouchDown", self.m_inputBox, UIEvent.EventWindowTouchDown, function()
        --UIChatManage:showChatViewByType(Define.chatWinSizeType.mainChat)
        self.inputBoxText:SetVisible(false)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat m_inputBox event : EventWindowTouchUp", self.m_inputBox, UIEvent.EventWindowTouchUp, function()
        self.m_inputBox:SetProperty("Text", self.sendMsgText)
        self.inputBoxText:SetVisible(false)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnSoundSend event : EventWindowTouchDown", self.btnSoundSend, UIEvent.EventWindowTouchDown, function()
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            return
        end
        self:startRecordMsg()
        self.txtSoundTip:SetText(Lang:toText("ui.chat.send.voice"))
        self:updateVoiceIconShow(2)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundSend event : EventWindowTouchUp", self.btnSoundSend, UIEvent.EventWindowTouchUp, function()
        self.txtSoundTip:SetText("")
        self:updateVoiceIconShow(1)
        self:stopRecordMsg()
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundSend event : EventWindowTouchMove", self.btnSoundSend, UIEvent.EventWindowTouchMove, function()
        --self.btnSoundSend:SetScale({ x = 1.2, y = 1.2, z = 1.2 })
        if not self.isRecording then return end
        self.txtSoundTip:SetText(Lang:toText("ui.chat.send.voice"))
        self:updateVoiceIconShow(2)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundCancel event : EventWindowTouchMove", self.btnSoundCancel, UIEvent.EventWindowTouchMove, function()
        if not self.isRecording then return end
        self.txtSoundTip:SetText(Lang:toText("ui.chat.cancel.send.voice"))
        self:updateVoiceIconShow(3)
        self.btnSoundCancel:SetScale({ x = 1.2, y = 1.2, z = 1.2 })
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundCancel event : EventMotionRelease", self.btnSoundCancel, UIEvent.EventMotionRelease, function()
        self.btnSoundCancel:SetScale({ x = 1, y = 1, z = 1 })
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundCancel event : EventWindowTouchUp", self.btnSoundCancel, UIEvent.EventWindowTouchUp, function()
        self:cancelRecordMsg()
        self.txtSoundTip:SetText("")
        self:updateVoiceIconShow(1)
        self.btnSoundCancel:SetScale({ x = 1, y = 1, z = 1 })
    end)
    self:lightSubscribe("error!!!!! script_client win_chat lytVoiceCancelBg event : EventWindowTouchUp", self.lytVoiceCancelBg, UIEvent.EventWindowTouchMove, function()
        if not self.isRecording then return end
        self.txtSoundTip:SetText(Lang:toText("ui.chat.cancel.send.voice"))
        self:updateVoiceIconShow(3)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat lytVoiceCancelBg event : EventWindowTouchUp", self.lytVoiceCancelBg, UIEvent.EventWindowTouchUp, function()
        self:cancelRecordMsg()
        self.txtSoundTip:SetText("")
        self:updateVoiceIconShow(1)
    end)

    --点击到最底部
    self:lightSubscribe("error!!!!! script_client win_chat btnGotoNewMsg event : EventButtonClick", self.btnGotoNewMsg, UIEvent.EventButtonClick, function()
        self:gotoBottom()
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnGotoBottom event : EventButtonClick", self.btnGotoBottom, UIEvent.EventButtonClick, function()
        self:gotoBottom()
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnEmoji event : EventButtonClick", self.btnEmoji, UIEvent.EventButtonClick, function()
        UI:getWnd("chatEmoji"):onShow(true)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnMic event : EventButtonClick", self.btnMic, UIEvent.EventButtonClick, function()
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            return
        end
        self:showOrHideWindowByType(WINDOW.SOUND, true)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnKeyBoard event : EventButtonClick", self.btnKeyBoard, UIEvent.EventButtonClick, function()
        self:showOrHideWindowByType(WINDOW.SOUND, false)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lytWindowClose event : EventWindowTouchDown", self.lytWindowClose, UIEvent.EventWindowTouchDown, function()
        UIChatManage:showChatViewByType(Define.chatWinSizeType.smallMiniChat)
        self:showOrHideWindowByType(WINDOW.PLAYER, false)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnWindowClose event : EventWindowTouchDown", self.btnWindowClose, UIEvent.EventButtonClick, function()
        UIChatManage:showChatViewByType(Define.chatWinSizeType.smallMiniChat)
        self:showOrHideWindowByType(WINDOW.PLAYER, false)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat chkAutoPlay event : EventCheckStateChanged", self.chkAutoPlay, UIEvent.EventCheckStateChanged, function()
        local check = self.chkAutoPlay:GetChecked()
        self:setAutoVoiceState(check)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat chkLock event : EventCheckStateChanged", self.chkLock, UIEvent.EventCheckStateChanged, function()
        local check = self.chkLock:GetChecked()
        self:setLock(check)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat guiInstanceRoot event : EventWindowTouchDown", GUISystem.instance:GetRootWindow(), UIEvent.EventWindowTouchDown, function()
        if UI:isOpen('chat') then
            -- 判断锁屏
            if self.lockScreenList[self.curTab] then
                return
            end
        end
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnTeamHallBtn event : EventButtonClick", self.btnTeamHallBtn, UIEvent.EventButtonClick, function()
        Me:clickChatTeamHallBtn()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_SCENE_TOUCH_BEGIN", Event.EVENT_SCENE_TOUCH_BEGIN, function(x, y)
        if UI:isOpen('chat') then
            -- 判断锁屏
            if self.lockScreenList[self.curTab] then
                return
            end
            UIChatManage:showChatViewByType(Define.chatWinSizeType.smallMiniChat)
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_CHAT_SEND_VOICE", Event.EVENT_CHAT_SEND_VOICE, function(time, url)
        if not self:checkCanSend() then
            self:cancelRecordMsg()
            return
        end
        self:sendVoiceMsg(time, url)
    end)
    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_CHAT_VOICE_FILE_ERROR", Event.EVENT_CHAT_VOICE_FILE_ERROR, function(errorType)
        Client.ShowTip(1, Lang:toText("ui.chat.voicefail"), 40)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_SOUND_TIME_CHANGE", Event.EVENT_SOUND_TIME_CHANGE, function(value)
        self:updateSoundTimes()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_FREE_SOUND_TIME_CHANGE", Event.EVENT_FREE_SOUND_TIME_CHANGE, function(value)
        self:updateSoundTimes()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_SOUND_MOON_CHANGE", Event.EVENT_SOUND_MOON_CHANGE, function(value)
        self.btnMic:SetNormalImage(Me:getSoundMoonCardEnable() and "set:chat.json image:btn_0_voice_forever" or "set:chat.json image:btn_0_voice_normal")
        self.btnMic:SetPushedImage(Me:getSoundMoonCardEnable() and "set:chat.json image:btn_0_voice_forever" or "set:chat.json image:btn_0_voice_normal")
        --self.txtMicCnt:SetVisible(not Me:getSoundMoonCardEnable())
        self:updateSoundTimes()
    end)

    for _, pageType in pairs(chatSetting.chatTabList) do
        self:subscribe(self.lstTabContentEx[pageType], UIEvent.EventScrollMoveChange, function()
            if self.curTab ~= pageType  or not self.isShow  then return end
            self:updateGotoBottomBtnShow(self.curTab)
        end)
    end

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat event : EVENT_CHECK_IGNORE", Event.EVENT_CHECK_IGNORE, function(id, objId, name, btn)
        if UIChatManage:checkIsIgnore(id) then
            if btn then
                btn:SetText(Lang:toText("ui.chat.disignore"))
            end
        else
            if btn then
                btn:SetText(Lang:toText("ui.chat.ignore"))
            end
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat event : EVENT_CHECK_IGNORE", Event.EVENT_UPDATE_FRIEND_LIST_SHOW, function(type)
        if not self.isShow then
            return
        end
        self.firstGetFriendData = true
        if type == Define.chatFriendType.game then
            self.lytChatFriend:invoke("initGameFriendList", Me.allFriendData[type])
        elseif type == Define.chatFriendType.platform then
            self.lytChatFriend:invoke("initPlatformFriendList", Me.allFriendData[type])
        end
        UIChatManage:addOneNeedOnlineItem(Me.allFriendData[type].dataList)
    end)

    Lib.subscribeEvent(Event.EVENT_FINISH_PARSE_REQUESTS_DATA, function()
        self:refreshRequestsList()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat event : EventTeamInfoChange", Event.EventTeamInfoChange, function()
        self:updateBtnEmojiShowWithTab()
        self:updateLytPutShowWithTab()
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_FRIEND_PRIVATE_SHOW, function()
        local curPrivateUserId = UIChatManage:getCurPrivateFriend()
        if curPrivateUserId then
            self:openPrivateChat(curPrivateUserId)
        else
            self:onClickTab(Define.Page.PRIVATE)
        end
    end)

    Lib.lightSubscribeEvent("error!!!!!  : EVENT_UPDATE_PRIVATE_HISTORY", Event.EVENT_UPDATE_PRIVATE_HISTORY, function()
        self.lytChatPrivate:invoke("updatePrivateHistoryList")
    end)
end

function M:setLock(islock)
    if islock then
        for _, tab in pairs(self.lockScreenList) do
            tab = false
        end
    end
    self.lockScreenList[self.curTab] = islock
end
function M:sendTimeCount()
    self.canSend[self.curTab] = false
    self.lastSendTime[self.curTab] = os.time()
    LuaTimer:schedule(function(tab)
        self.canSend[tab] = true
    end, self.duration * 1000, nil, self.curTab)
end
function M:setAutoVoiceState(isOpen)
    self.autoVoiceStateList[self.curTab] = isOpen
end
--开始录音
function M:startRecordMsg()
    self.isRecording = true
    VoiceManager:startRecord(self.curTab == Define.Page.PRIVATE and self.lastPrivateUserId or false)
    self.lytWindowClose:SetVisible(false)
    self.voiceTimer = World.Timer(((chatSetting.voiceMaxTime or 60) - (chatSetting.voiceLastTime or 10)) * 20, function()
        self.txtSoundTime:SetVisible(true)
        self.txtSoundTime:SetText(self.lastVoiceTime .. "s")
        self.voiceTimer = World.Timer(20, function()
            if self.lastVoiceTime < 1 then
                self.txtSoundTime:SetVisible(false)
                self.lastVoiceTime = chatSetting.voiceLastTime or 10
                self.voiceTimer = nil
                self.btnSoundSend:SetScale({ x = 1, y = 1, z = 1 })
                self.btnSoundCancel:SetScale({ x = 1, y = 1, z = 1 })
                VoiceManager:stopRecord(self.curTab == Define.Page.PRIVATE and self.lastPrivateUserId or false)
                --self:showOrHideWindowByType(WINDOW.SOUND, false)
                self:updateVoiceIconShow(1)
                self.lytWindowClose:SetVisible(true)
                self.isRecording = false
                UI:getWnd("chatBar"):voicedSuccess()
                return false
            end
            self.lastVoiceTime = self.lastVoiceTime - 1
            self.txtSoundTime:SetText(self.lastVoiceTime .. "s")
            return true
        end)
    end)
end
function M:stopRecordMsg()
    if not Me:getCanSendSound() then
        UI:openWnd("chatShop")
        return
    end
    if not self.isRecording then return end
    self.isRecording = false
    self.lytWindowClose:SetVisible(true)
    VoiceManager:stopRecord(self.curTab == Define.Page.PRIVATE and self.lastPrivateUserId or false)
    if self.voiceTimer then
        self.voiceTimer()
        self.txtSoundTime:SetVisible(false)

        self.lastVoiceTime = chatSetting.voiceLastTime or 10
        self.voiceTimer = nil
    end
    --self:showOrHideWindowByType(WINDOW.SOUND, false)
end
function M:cancelRecordMsg()
    if not Me:getCanSendSound() then
        UI:openWnd("chatShop")
        return
    end
    if self.isRecording then
        Client.ShowTip(1, Lang:toText("ui.chat.voicefail"), 40)
    end
    self.isRecording = false
    self.lytWindowClose:SetVisible(true)
    VoiceManager:cancelRecord(self.curTab == Define.Page.PRIVATE and self.lastPrivateUserId or false)
    if self.voiceTimer then
        self.voiceTimer()
        self.txtSoundTime:SetVisible(false)
        self.lastVoiceTime = chatSetting.voiceLastTime or 10
        self.voiceTimer = nil
    end
    --self:showOrHideWindowByType(WINDOW.SOUND, false)
end

function M:openPrivateChat(id)
    if self.lastPrivateUserId and self.lastPrivateUserId ~= id then
        self:exchangePrivateList(id)
    end
    self.lastPrivateUserId = id
    self:onClickTab(Define.Page.PRIVATE)
end

function M:showOrHideWindowByType(idx, isShow, playerInfo)
    if idx == WINDOW.SETTING then
        self.lytSettingWindow:SetVisible(isShow)
    elseif idx == WINDOW.SOUND then
        self.lytSoundGround:SetVisible(isShow)
        self.btnEmoji:SetVisible(not isShow)
        self.lytPut:SetVisible(not isShow)
        if UI:isOpen("chatEmoji") then
            UI:getWnd("chatEmoji"):onShow(false)
        end
    end
end

function M:setAutoHide()
    if self.lockScreenList[self.curTab] then
        return
    end
    if self.cdTimer then
        return
    end
    self.cdTimer = World.Timer((chatSetting.hideWaitTime or 5) * 20, function()
        UIChatManage:showChatViewByType(Define.chatWinSizeType.smallMiniChat)
        self.cdTimer = nil
    end)
end

-- 创建定时器
function M:startHideTimer()
    Lib.logDebug('startHideTimer')
    -- 判断锁屏
    if self.lockScreenList[self.curTab] then
        return
    end

    self.hideTimer = LuaTimer:schedule(function()
        self:fadeOut()
        LuaTimer:cancel(self.hideTimer)
        self.hideTimer = nil
    end, (chatSetting.hideWaitTime or 5) * 1000)
end

-- 停止定时器
function M:stopHideTimer()
    if self.hideTimer then
        LuaTimer:cancel(self.hideTimer)
        self.hideTimer = nil
    end
end

function M:fadeOut()
    self:showOrHideWindowByType(WINDOW.SETTING, false)

    UIAnimationManager:play(self.lytPut, "fadeOutChat", function()
        self.lytPut:SetVisible(false)
        self.lytPut:SetAlpha(1)
    end)

    UIAnimationManager:play(self.btnEmoji, "fadeOutChat", function()
        self.btnEmoji:SetVisible(false)
        self.btnEmoji:SetAlpha(1)
    end)

    UIAnimationManager:play(self.ltTabList, "fadeOutChat", function()
        self.ltTabList:SetVisible(false)
        self.ltTabList:SetAlpha(1)
    end)
end

-- 根据选择的tab是否显示输入框
function M:updateLytPutShowWithTab()
    self.lytNoInputPanel:SetVisible(false)
    if self.curTab == Define.Page.PRIVATE then
        if UIChatManage:getCurPrivateFriend() then
            self.lytPut:SetVisible(true)
        else
            self.lytPut:SetVisible(false)
        end
    elseif self.curTab == Define.Page.TEAM then
        if Me:isJoinTeam() then
            self.lytPut:SetVisible(true)
        else
            self.lytPut:SetVisible(false)
            self.lytNoInputPanel:SetVisible(true)
            self.txtNoInputTips:SetVisible(false)
            self.btnTeamHallBtn:SetVisible(chatSetting.isShowTeamHallBtn)
            self.btnTeamHallBtn:SetText(Lang:toText("ui.chat.team.hall"))
        end
    elseif self.curTab == Define.Page.SYSTEM then
        self.lytPut:SetVisible(false)
        self.lytNoInputPanel:SetVisible(true)
        self.txtNoInputTips:SetVisible(true)
        self.txtNoInputTips:SetText(Lang:toText("ui.chat.system.input"))
        self.btnTeamHallBtn:SetVisible(false)
    else
        self.lytPut:SetVisible(true)
    end
end

-- 根据选择的tab是否显示表情按钮
function M:updateBtnEmojiShowWithTab()
    if self.curTab == Define.Page.PRIVATE then
        if UIChatManage:getCurPrivateFriend() then
            self.btnEmoji:SetVisible(true)
        else
            self.btnEmoji:SetVisible(false)
        end
    elseif self.curTab == Define.Page.TEAM then
        if Me:isJoinTeam() then
            self.btnEmoji:SetVisible(true)
        else
            self.btnEmoji:SetVisible(false)
        end
    elseif self.curTab == Define.Page.SYSTEM then
        self.btnEmoji:SetVisible(false)
    else
        self.btnEmoji:SetVisible(true)
    end
end

function M:initTabList()
    for _, pageType in pairs(chatSetting.chatTabList) do
        if Me:checkChatMainTabIsOpen(pageType) then
            if not self.tabList[pageType] then
                local chatTab = UIMgr:new_widget("chatTabItem")
                chatTab:invoke("initTabByType", pageType)
                self:lightSubscribe("error!!!!! script_client win_chat chatTab event : EventWindowClick", chatTab, UIEvent.EventWindowClick, function()
                    self:onClickTab(pageType)
                end)
                self.ltTabList:AddItem(chatTab, true)
                self.tabList[pageType] = chatTab
            end
        end
    end

    if #chatSetting.chatTabList <= 1 then
        self.hideTabList = true
        self.ltTabList:SetVisible(false)
    end
end

function M:onClickTab(type)
    if type == Define.Page.FAMILY and Me:getValue(chatSetting.familyVal) == 0 then
        Client.ShowTip(1, Lang:toText("ui.chat.addFamilyPlease"), 40)
        return 
    end

    if type ~= self.curTab then
        VoiceManager:cleanAutoVoiceList()
    end

    if type == Define.Page.FRIEND then
        self.lytChatPanel:SetVisible(false)
        self.lytFriendPanel:SetVisible(true)
        self.lytPrivatePanel:SetVisible(false)
        self.lytNearPanel:SetVisible(false)
        Me:updateClientFriendDataList(Define.chatFriendType.game)
        Me:updateClientFriendDataList(Define.chatFriendType.platform)
    elseif type == Define.Page.PRIVATE then
        self.lytChatPanel:SetVisible(true)
        self.lytFriendPanel:SetVisible(false)
        self.lytPrivatePanel:SetVisible(true)
        self.lytNearPanel:SetVisible(false)
        self.lytChatPrivate:invoke("updatePrivatePanelShow")
        self.lytChatPrivate:invoke("updatePrivateHistoryList")
    elseif type == Define.Page.NEAR then
        self.lytNearPanel:SetVisible(true)
        self.lytChatPanel:SetVisible(false)
        self.lytFriendPanel:SetVisible(false)
        self.lytPrivatePanel:SetVisible(false)
        self.lytChatNear:invoke("refreshNearData")
    else
        self.lytChatPanel:SetVisible(true)
        self.lytFriendPanel:SetVisible(false)
        self.lytPrivatePanel:SetVisible(false)
        self.lytNearPanel:SetVisible(false)
    end
    self:changeTabStatus(type)
    self:changeTabContent(type)
end

function M:changeTabContent(tab)
    if self.curTab ~= tab then
        UIChatManage:stopAllVoiceView(self.curTab)
    end
    self:showOrHideWindowByType(WINDOW.SOUND, false)

    self.curTab = tab
    self.chkLock:SetChecked(self.lockScreenList[tab])
    self.chkAutoPlay:SetChecked(self.autoVoiceStateList[tab])

    self:updateLytPutShowWithTab()
    self:updateBtnEmojiShowWithTab()
    self:setAllExVisible(false)

    if tab == Define.Page.PRIVATE then
        local curPrivateUserId = UIChatManage:getCurPrivateFriend()
        if curPrivateUserId then
            self.lytContent:SetVisible(true)
            if not UIChatManage.chatTabDataList[tab][curPrivateUserId] then
                UIChatManage.chatTabDataList[tab][curPrivateUserId] = {}
            end
            if self.newMsgList[tab] and self.newMsgList[tab] > 0 then
                self.btnGotoNewMsg:SetVisible(true)
                self.btnGotoBottom:SetVisible(true)
                self.btnNewMsgText:SetText(Lang:toText({ "ui.chat.newMsg", self.newMsgList[tab] }))
            else
                self.btnGotoNewMsg:SetVisible(false)
                self:updateGotoBottomBtnShow(self.curTab)
            end
            self:loadExMsgCache(self.curTab)
            self.lstTabContentEx[self.curTab]:SetVisible(true)
        else
            self.lytContent:SetVisible(false)
            self.btnGotoNewMsg:SetVisible(false)
            self.btnGotoBottom:SetVisible(false)
        end
        self.lytSettingWindow:SetVisible(false)
    elseif tab == Define.Page.FRIEND then
        self.lytContent:SetVisible(false)
        self.btnGotoNewMsg:SetVisible(false)
        self.btnGotoBottom:SetVisible(false)
        self.lytSettingWindow:SetVisible(false)
    else
        self.lytSettingWindow:SetVisible(true)
        self.lytContent:SetVisible(true)
        if self.newMsgList[tab] and self.newMsgList[tab] > 0 then
            self.btnGotoNewMsg:SetVisible(true)
            self.btnNewMsgText:SetText(Lang:toText({ "ui.chat.newMsg", self.newMsgList[tab] }))
            self.btnGotoBottom:SetVisible(true)
        else
            self.btnGotoNewMsg:SetVisible(false)
            self:updateGotoBottomBtnShow(self.curTab)
        end
        self:loadExMsgCache(self.curTab)
        self.lstTabContentEx[self.curTab]:SetVisible(true)
    end
end

function M:updateGotoBottomBtnShow(pageType)
    local offset = self.lstTabContentEx[pageType]:GetScrollOffset()
    local minOffset = self.lstTabContentEx[pageType]:GetMinScrollOffset()
    self.btnGotoBottom:SetVisible(false)
    if offset <= minOffset then
        self.btnGotoNewMsg:SetVisible(false)
        self.btnGotoBottom:SetVisible(false)
        if self.newMsgList[self.curTab] then
            self.newMsgList[self.curTab] = 0
        end
    elseif offset > minOffset + 10 then
        self.btnGotoBottom:SetVisible(true)
    end
end

function M:changeTabStatus(tab)
    for _, chatTab in pairs(self.tabList) do
        chatTab:invoke("onCheckClick", tab)
    end

    if tab == Define.Page.PRIVATE then
        self.tabList[Define.Page.PRIVATE]:invoke("updatePlayerName", UIChatManage.curPrivateUserId)
    end
end

function M:sendVoiceMsg(time, url)
    if not self:checkCanSend() then
        return
    end
    self:sendChatMsgToServer(url, time)
end

function M:sendChatMessage()
    local msg = self.sendMsgText
    if not msg or #msg < 1 then
        return
    end
    if not self:checkCanSend() then
        return
    end
    self:sendChatMsgToServer(msg)

    self.m_inputBox:SetProperty("Text", "")
    self.sendMsgText = ""
    self.inputBoxText:SetVisible(true)
end

function M:sendEmoji(emoji)
    if not self:checkCanSend(emoji.type) or not self:checkSpecialSend(emoji.type) then
        return
    end
    -- 发送快捷短语
    if emoji.type == Define.chatEmojiTab.SHORT then
        self:sendChatMsgToServer(emoji.emojiData)
    else
        self:sendChatMsgToServer("", false, emoji)
    end
end

function M:exchangePrivateList(userId)
    --上一个私聊对象全部重置为未处理
    if UIChatManage.curPrivateUserId then
        local list = self.exInfoCache[Define.Page.PRIVATE][self.lastPrivateUserId] or {}
        if list and #list > 0 then
            local cnt =#list
            for i = 1,cnt do
                list[i].isNewMsg = true
            end
        end
    end

    local privateListItemCnt = self.lstTabContentEx[Define.Page.PRIVATE]:GetItemCount()
    for i = 1,privateListItemCnt do
        local item = self.lstTabContentEx[Define.Page.PRIVATE]:GetItem(0)
        self.lstTabContentEx[Define.Page.PRIVATE]:RemoveItem(item, true)
    end

    --local privateChatInfoCnt = self.exInfoCache[Define.Page.PRIVATE][userId] and #self.exInfoCache[Define.Page.PRIVATE][userId] or 0
    --local needAdd = privateChatInfoCnt-privateListItemCnt
    --if needAdd>=0 then
    --    for i = 1,needAdd do
    --        self:addMsgInExList(self.exInfoCache[Define.Page.PRIVATE][userId][privateChatInfoCnt-needAdd+i],Define.Page.PRIVATE,true)
    --    end
    --    for i = 1,privateChatInfoCnt-needAdd do
    --        local info = self.exInfoCache[Define.Page.PRIVATE][userId][i]
    --        self.lstTabContentEx[Define.Page.PRIVATE]:GetItem(i-1):invoke("initViewByData",info)
    --    end
    --else
    --    needAdd = -needAdd
    --    for i = 1,needAdd do
    --        local item = self.lstTabContentEx[Define.Page.PRIVATE]:GetItem(0)
    --        self.lstTabContentEx[Define.Page.PRIVATE]:RemoveItem(item, true)
    --    end
    --
    --    for i = 1,privateChatInfoCnt do
    --        local info = self.exInfoCache[Define.Page.PRIVATE][userId][i]
    --        self.lstTabContentEx[Define.Page.PRIVATE]:GetItem(i-1):invoke("initViewByData",info)
    --    end
    --end
    --for i = 1,privateChatInfoCnt do
    --    local info = self.exInfoCache[Define.Page.PRIVATE][userId][i]
    --    info.isNewMsg = false
    --end
    --self.lstTabContentEx[Define.Page.PRIVATE]:GoLastScroll()
end

function M:loadExMsgCache(type)
    if type == Define.Page.PRIVATE then
        if self.exInfoCache[type][UIChatManage.curPrivateUserId] then
            local cnt = #self.exInfoCache[type][UIChatManage.curPrivateUserId]
            local doCnt = cnt - math.max(cnt-Define.MainChatMaxCnt,0)
            for i = 1,doCnt do
                local data = self.exInfoCache[type][UIChatManage.curPrivateUserId][cnt-doCnt+i]
                if data.isNewMsg then
                    self:addMsgInExList(data,type)
                end
            end
            self.lstTabContentEx[Define.Page.PRIVATE]:GoLastScroll()
        end
    else
        local cnt = #self.exInfoCache[type]
        local doCnt = cnt - math.max(cnt-Define.MainChatMaxCnt,0)
        for i = 1,doCnt do
            self:addMsgInExList(self.exInfoCache[type][cnt-doCnt+i],type)
        end
        --处理完成，清空缓存
        self.exInfoCache[type] = {}
    end
end

local function cleanDoubleMaxInfoTable(tb)
    local tbCnt = #tb
    if tbCnt> Define.MainChatMaxCnt then
        table.remove(tb,1)
    end
end

function M:cleanPrivateContent(userId)
    self.exInfoCache[Define.Page.PRIVATE][userId] = nil
end

function M:addMsgInExList(data,type,force,privateArgs)
    Lib.logInfo("addMsgInExList",Lib.v2s(privateArgs,2))
    --非大窗，未打开聊天或者非当前分页情况下只做数据记录，不做界面更新
    local keyId = privateArgs and privateArgs.keyId and privateArgs.keyId or data.platId
    if not self.isShow or (self.curTab ~= type and not force) then
        if type == Define.Page.PRIVATE then
            if not self.exInfoCache[type][keyId] then
                self.exInfoCache[type][keyId] = {}
            end
            data.isNewMsg = true
            table.insert(self.exInfoCache[type][keyId],(privateArgs and privateArgs.isHistory)  and 1 or #(self.exInfoCache[type][keyId])+1, data)
            cleanDoubleMaxInfoTable(self.exInfoCache[type][keyId])
        else
            table.insert(self.exInfoCache[type],data)
            cleanDoubleMaxInfoTable(self.exInfoCache[type])
        end
        return
    end
    --私聊无论是否处理UI都要缓存
    if  type == Define.Page.PRIVATE and self.curTab == Define.Page.PRIVATE  then
        if not self.exInfoCache[type][keyId] then
            self.exInfoCache[type][keyId] = {}
        end
        data.isNewMsg = true
        table.insert(self.exInfoCache[type][keyId],(privateArgs and privateArgs.isHistory) and 1 or #(self.exInfoCache[type][keyId])+1,data)
        cleanDoubleMaxInfoTable(self.exInfoCache[type][keyId])
        --当前私聊页面不为本次消息所属玩家时不再继续处理ui
        if UIChatManage.curPrivateUserId ~=keyId and keyId ~=Me.platformUserId and not force then
            return
        end
    end

    local contentType = self:getContentItemType(data)
    local pageCnt = self.lstTabContentEx[type]:GetItemCount()
    if pageCnt >=Define.MainChatMaxCnt then
        local cell = self.lstTabContentEx[type]:GetItem(0)
        if cell:invoke("getItemContentType") == contentType then
            self.lstTabContentEx[type]:RemoveItem(cell, false)
        else
            self.lstTabContentEx[type]:RemoveItem(cell, true)
            cell = self:createContentItemWithType(contentType)
            cell:invoke("setItemContentType",contentType)
        end
        cell:invoke("initViewByData",data)
        self.lstTabContentEx[type]:AddItem1(cell,(privateArgs and privateArgs.isHistory) and 0 or -1)
    else
        local cell = self:createContentItemWithType(contentType)
        cell:invoke("setItemContentType",contentType)
        cell:invoke("initViewByData",data)
        self.lstTabContentEx[type]:AddItem1(cell,(privateArgs and privateArgs.isHistory) and 0 or -1)
    end
    data.isNewMsg = false
end

-- 根据cell UI类型，创建不同cell Node
function M:createContentItemWithType(contentType)
    local cell
    if contentType == Define.chatMainContentType.systemEx then
        cell = UIMgr:new_widget("chatSystemItem")
    elseif contentType == Define.chatMainContentType.teamEx then
        cell = UIMgr:new_widget("chatTeamJoinItem")
    elseif contentType == Define.chatMainContentType.petEx then
        cell = UIMgr:new_widget("chatLinkItemEx")
    elseif contentType == Define.chatMainContentType.goodEx then
        cell = UIMgr:new_widget("chatLinkItemEx")
    else
        cell = UIMgr:new_widget("chatContentItemEx")
    end
    return cell
end

-- 获取消息cell UI类型
function M:getContentItemType(data)
    if data.type == Define.Page.SYSTEM then
        return Define.chatMainContentType.systemEx
    elseif data.type == Define.Page.TEAM and data.teamInviteData then
        return Define.chatMainContentType.teamEx
    else
        if data.emoji and data.emoji.type == Define.chatEmojiTab.PET then
            return Define.chatMainContentType.petEx
        end
        if data.emoji and data.emoji.type == Define.chatEmojiTab.GOODS then
            return Define.chatMainContentType.goodEx
        end
    end
    return Define.chatMainContentType.normalEx
end

--到最底部
function M:gotoBottom()
    self.btnGotoNewMsg:SetVisible(false)
    self.btnGotoBottom:SetVisible(false)
    self.newMsgList[self.curTab] = 0
    if self.curTab ~= Define.Page.FRIEND then
        World.LightTimer("lstScroll",2,function()
            self.lstTabContentEx[self.curTab]:GoLastScroll()
        end)
    end
end

-- 收到新消息，仅仅做提示
function M:receiveChatMessage(type, msg, fromname, privateArgs, voiceTime)
    local calcOffset = self.lstTabContentEx[self.curTab]:GetScrollOffset()
    local upTooFar =  (calcOffset -  self.lstTabContentEx[self.curTab]:GetMinScrollOffset()) > 40

    if upTooFar and fromname ~= Me.name and not privateArgs then
        self:addNewMsgTips(type)
    elseif type == self.curTab then
        self:gotoBottom()
    end

    --自动语音播放
    if voiceTime and self.autoVoiceStateList[self.curTab] and self.curTab == type then
        if fromname ~= Me.name and not privateArgs then
            World.Timer(1, function()
                VoiceManager:autoPlayVoice(msg)
            end)
        end
    end
end

--添加未读消息提示
function M:addNewMsgTips(type)
    if not self.newMsgList[type] then
        self.newMsgList[type] = 0
    end

    self.newMsgList[type] = self.newMsgList[type] + 1
    if type == self.curTab then
        self.btnGotoNewMsg:SetVisible(true)
        self.btnGotoBottom:SetVisible(true)
        self.btnNewMsgText:SetText(Lang:toText({ "ui.chat.newMsg", self.newMsgList[self.curTab] }))
    end

end
function M:isSelfMsg()
end

function M:setAllExVisible(value)
    for pageType, _ in pairs(self.lstTabContentEx) do
        self.lstTabContentEx[pageType]:SetVisible(value)
    end
end

function M:initAllExConfig()
    for pageType, _ in pairs(self.lstTabContentEx) do
        self.lstTabContentEx[pageType]:InitConfig(0, 1, 1)
    end
end

function M:getCurTab()
    return self.curTab
end

function M:checkCanSend(type)
    if not self.canSend[self.curTab] then
        if type then
            local cd = self.specialSend[type].cd
            local time = self.specialSendLimit.cdTime - math.ceil(os.time() - cd)
            local text = Lang:toText("ui.chat.cannotsend")
            if time > 0 then
                text = string.format(Lang:toText("ui.chat.can.not.send.emoji"), time)
            end
            Client.ShowTip(1, text, 40)
        else
            local time = self.duration - math.ceil(os.time() - self.lastSendTime[self.curTab])
            local text = Lang:toText("ui.chat.send.wait")
            if time > 0 then
                text = string.format(Lang:toText("ui.chat.can.not.send"), time)
            end
            Client.ShowTip(1, text, 40)
        end
        return false
    end
    return true
end

function M:checkSpecialSend(type)
    ---cd中
    if not type or not self.specialSend[type] then return true end
    local cd = self.specialSend[type].cd
    local record = self.specialSend[type].record
    if cd > 0 then
        ---cd时间还没到
        if os.time() - cd < self.specialSendLimit.cdTime then
            local time = self.specialSendLimit.cdTime - math.ceil(os.time() - cd)
            local text = Lang:toText("ui.chat.cannotsend")
            if time > 0 then
                text = string.format(Lang:toText("ui.chat.can.not.send.emoji"), time)
            end
            Client.ShowTip(1, text, 40)
            return false
        else
            ---cd时间到了
            self.specialSend[type].cd = 0
            self.specialSend[type].record = {}
            return true
        end
    else
        ---没有cd
        ---没有记录
        if #record == 0 then
            table.insert(self.specialSend[type].record, {time = os.time(), valid = true})
            return true
        else
            local max = self.specialSendLimit.limitTimes
            local setCd = false
            local times = 0
            for i, v in pairs(self.specialSend[type].record) do
                if os.time() - v.time > self.specialSendLimit.limitTime then
                    v.valid = false
                else
                    times = times + 1
                    if times >= max then
                        setCd = true
                        break
                    end
                end
            end
            if setCd then
                self.specialSend[type].cd = os.time()
            else
                for i = #self.specialSend[type].record, 1, -1 do
                    if not self.specialSend[type].record[i].valid then
                        table.remove(self.specialSend[type].record, i)
                    end
                end
                table.insert(self.specialSend[type].record, {time = os.time(), valid = true})
            end
            return true
        end
    end
end

function M:sendChatMsgToServer(msg, time, emoji)
    UIChatManage:requestServerSendChatMsg(self.curTab, msg, time, emoji)
    self:sendTimeCount()
end

function M:stopOnlineTimer()
    if self.onLineTimer then
        LuaTimer:cancel(self.onLineTimer)
        self.onLineTimer = nil
    end
end

function M:startOnlineTimer()
    self:stopOnlineTimer()
    UIChatManage:requestPlayerOnlineState()
    self.onLineTimer = LuaTimer:scheduleTimer(function()
        UIChatManage:requestPlayerOnlineState()
    end, chatSetting.onlineUpdateTime*1000)
end
return M