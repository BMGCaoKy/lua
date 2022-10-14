




local UIAnimationManager = T(UILib, "UIAnimationManager") --@type UIAnimationManager
local LuaTimer = T(Lib, "LuaTimer")
local chatSetting = World.cfg.chatSetting or {}
local EmojiConfig = T(Config, "EmojiConfig")
local ShortConfig = T(Config, "ShortConfig")

local misc = require "misc"
local now_nanoseconds = misc.now_nanoseconds
local function getTime()
    return now_nanoseconds() / 1000000
end

local BCWinSizeType = {
    Big = 1,
    Small = 2
}

local WINDOW = {
    SETTING = 1,
    PLAYER = 2,
    SOUND = 3,
    EMOJI = 4
}

local SpecialSendType = {
    Emoji = 1,
    Short = 2
}

local SpecialSendTip = {
    [SpecialSendType.Emoji] = "ui.chat.can.not.send.emoji",
    [SpecialSendType.Short] = "ui.chat.can.not.send.short"
}

local contentItemPool = {}

local function getChatNameColor(num)
    local count = #chatSetting.chatHeadColor
    local index = num % count
    if index == 0 then index = count end
    return chatSetting.chatHeadColor[index]
end

function M:init()
    local begin = getTime()
    local begin1
    begin1 = getTime()
    WinBase.init(self, "ChatMain.json", true)
    begin1 = getTime()

    self.maxSendLen = chatSetting.maxMsgSize or 150

    -- 聊天间隔时间
    self.duration = chatSetting.duration or 2
    self.lastSendTime = {
        [Define.Page.COMMON] = 0,
        [Define.Page.PRIVATE] = 0,
        [Define.Page.FAMILY] = 0
    }
    -- 可以发送消息（文字与语音）的标识
    self.canSend = {
        [Define.Page.COMMON] = true,
        [Define.Page.PRIVATE] = true,
        [Define.Page.FAMILY] = true
    }

    --世界聊天数据表
    self.chatDataList = {}
    --私聊数据表列表
    self.privateChatList = {}
    --当前私聊对象名称
    --self.curPrivateObjId = false
    self.curSelPlayerId = false
   --家族聊天数据表
   self.familyChatDataList = {}
    --聊天历史选项数据表
    self.chatHistoryDataList = {}
    --已申请过好友的列表
    self.addedFriendList = {}
    --已屏蔽消息的列表
    self.ignoreList = {}
    --锁屏状态列表
    self.lockScreenList = {}
    --自动播放状态表
    self.autoVoiceStateList = {false, false, false, false }
    --自动播放内容列表
    self.autoVoiceList = {}
    --右侧栏item实例表
    self.tabList = {}
    --各消息列表位置
    self.listPisList = {}
    --新消息数量列表
    self.newMsgList = {}
    --名字颜色
    self.headNameColor = {}
    --说话人次
    self.chatNum = 0

    self.alignmentType = chatSetting.alignment and chatSetting.alignment.type or "CB"

    --拦截交互事件
    self:root():SetParentTouch(false)


    --聊天内容通用虚拟列表及其适配器初始化
    self.lytContent = self:child("ChatMain-Content-Pos")
    self.imgContentBg = self:child("ChatMain-Content-Bg")

    self.lstContentEx = {}
    self.lstContentEx[Define.Page.COMMON] = UIMgr:new_widget("grid_view")
    self.lstContentEx[Define.Page.COMMON]:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lstContentEx[Define.Page.COMMON]:InitConfig(0, 1, 1)
    self.lytContent:AddChildWindow(self.lstContentEx[Define.Page.COMMON])
    self.lstContentEx[Define.Page.COMMON]:SetVisible(false)

    self.lstContentEx[Define.Page.FAMILY] = UIMgr:new_widget("grid_view")
    self.lstContentEx[Define.Page.FAMILY]:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lstContentEx[Define.Page.FAMILY]:InitConfig(0, 1, 1)
    self.lytContent:AddChildWindow(self.lstContentEx[Define.Page.FAMILY])
    self.lstContentEx[Define.Page.FAMILY]:SetVisible(false)

    self.lstContentEx[Define.Page.PRIVATE] = UIMgr:new_widget("grid_view")
    self.lstContentEx[Define.Page.PRIVATE]:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lstContentEx[Define.Page.PRIVATE]:InitConfig(0, 1, 1)
    self.lytContent:AddChildWindow(self.lstContentEx[Define.Page.PRIVATE])
    self.lstContentEx[Define.Page.PRIVATE]:SetVisible(false)

    self.exInfoCache = {}
    self.exInfoCache[Define.Page.COMMON] = {}
    self.exInfoCache[Define.Page.FAMILY]= {}
    self.exInfoCache[Define.Page.PRIVATE]= {}
    --self.exInfoCachePrivateIdx = {}

    self.lstContent = UIMgr:new_widget("grid_view")
    self.lstContent:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lstContent:InitConfig(0, 1, 1)
    self.lytContent:AddChildWindow(self.lstContent)
    --self:preloadMsgExItem()

    self.chatAdapter = UIMgr:new_adapter("chatContentAdapter", self.lstContent:GetPixelSize().x, chatSetting.chtBarHeight or 28)
    self.lstContent:invoke("setAdapter", self.chatAdapter)

    self.chatAdapter:setData(self.chatDataList)
    self.chatAdapter:setBottomCall(function()
        self.btnGotoBottom:SetVisible(false)
        self.btnGoBottomNoNew:SetVisible(false)
        if self.newMsgList[self.curTab] then
            self.newMsgList[self.curTab] = 0
        end
    end)
    --self.imgWindowBg = self:child("ChatMain-Window-Bg")
    self.btnGotoBottom = self:child("ChatMain-Go-Bottom")
    self.btnGotoBottom:SetVisible(false)
    self.sendMsgText = ""

    --历史选项虚拟列表机器适配器初始化
    self.lytHistory = self:child("ChatMain-History-List")
    self.lstHistory = UIMgr:new_widget("grid_view")
    self.lstHistory:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lstHistory:InitConfig(0, 0, 1)
    self.lytHistory:AddChildWindow(self.lstHistory)
    self.historyAdapter = UIMgr:new_adapter("chatHistoryAdapter", 435, 48)
    self.lstHistory:invoke("setAdapter", self.historyAdapter)
    self.historyAdapter:setData(self.chatHistoryDataList)
    self.lytHistory:SetVisible(false)

    --其他交互项目初始化
    self.imgBg = self:child("ChatMain-Bg")
    self.lytPut = self:child("ChatMain-Input")
    self.btnMic = self:child("ChatMain-Mic")
    self.txtMicCnt = self:child("ChatMain-MicCount")
    self.imgMicIcon = self:child("ChatMain-Window-Mic")
    -- self.txtMicCnt:SetText(Me:getSoundTimes())
    self.m_inputBox = self:child("ChatMain-Input-Box")
    self.m_inputBox:SetMaxLength(self.maxSendLen)
    --self.m_inputBox:SetXPosition({0, 20})
    self.imgInputBg = self:child("ChatMain-Input-Bg")

    self.m_inputBtnSend = self:child("ChatMain-Input-BtnSend")
    self.btnEmoji = self:child("ChatMain-Emoji")
    self.lytWindow = self:child("ChatMain-Window")
    self.lytWindowClose = self:child("ChatMain-Window-Close")
    self.btnWindowClose = self:child("ChatMain-Close-Btn")

    self.imgTip = self:child("ChatMain-Tip-Bg")
    self.imgTip:SetVisible(false)
    self.txtTip = self:child("ChatMain-Tip-Txt")

    self.inputBoxText = self:child("ChatMain-Input-Box-Text")
    -- self.inputBoxText:SetText(Lang:toText("gui_lang_input_box_text"))

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
    self.imgSoundMicIcon = self:child("ChatMain-Mic-Icon")
    self.imgSoundCancelIcon = self:child("ChatMain-Mic-Cancel-Icon")
    self.imgSoundMicIcon:SetVisible(false)
    self.imgSoundCancelIcon:SetVisible(false)

    --设置交互操作面板
    self.lytSettingWindow = self:child("ChatMain-Setting-Window")
    --self.lytSettingCancel = self:child("ChatMain-Setting-Cancel")
    self.chkAutoPlay = self:child("ChatMain-Setting-Autoplay-Check")
    self.chkLock = self:child("ChatMain-Setting-Lock-Check")
    self.txtAutoPlay = self:child("ChatMain-Setting-AutoPlay")
    self.txtLock = self:child("ChatMain-Setting-Lock")
    self.txtAutoPlay:SetText(Lang:toText("ui.chat.autoplay"))
    self.txtLock:SetText(Lang:toText("ui.chat.lock"))
    --历史页面底部提示栏
    self.lytHistoryBottom = self:child("ChatMain-History-Bottom")
    self.txtHistory1 = self:child("ChatMain-History-Info")
    self.txtHistory1:SetText(Lang:toText("ui.chat.history1"))
    self.txtHistory2 = self:child("ChatMain-History-Info2")
    self.txtHistory2:SetText(Lang:toText("ui.chat.history2"))
    self.lytHistoryBottom:SetVisible(false)
    self.lytMiniClose = self:child("ChatMain-Mini-Close")
    self.lytSizeControl = self:child("ChatMain-Size-Control")
    self.lytSizeControl:SetVisible(false)
    self.lytMiniClose:SetVisible(false)
    --右侧切换栏
    self.ltTabList = self:child("ChatMain-Sel-List")
    self.ltTabList:SetProperty("BetweenDistance", "0")
    --当前页面索引
    self.curTab = Define.Page.COMMON
    --语音录音最后剩余时间
    self.lastVoiceTime = chatSetting.voiceLastTime or 10
    --初始小窗状态
    self.winSizeType = BCWinSizeType.Small
    --表情
    self.lytEmojiBg = self:child("ChatMain-Emoji-Window-Bg")
    self.lytEmoji = self:child("ChatMain-Emoji-Window")
    self.btnEmojiClose = self:child("ChatMain-Emoji-Close")
    --快捷短语
    self.lytShortBg = self:child("ChatMain-Short-Window-Bg")
    self.lytShort = self:child("ChatMain-Short-Window")

    self.btnGoBottomNoNew = self:child("ChatMain-Go-Bottom-Btn")
    self.btnGoBottomNoNew:SetVisible(false)

    --设置系统文字颜色
    if chatSetting.chatSystemColor then
        self.txtAutoPlay:SetTextColor(getColorOfRGB(chatSetting.chatSystemColor))
        self.txtSoundSend:SetTextColor(getColorOfRGB(chatSetting.chatSystemColor))
        self.txtSoundTip:SetTextColor(getColorOfRGB(chatSetting.chatSystemColor))
        self.txtSoundSend:SetTextColor(getColorOfRGB(chatSetting.chatSystemColor))
    end

    self.specialSendLimit = chatSetting.emojiSendLimit or {
        limitTime = 15,
        limitTimes = 3,
        cdTime = 30
    }
    self.specialSend = {
        [SpecialSendType.Emoji] = {
            cd = 0,
            record = {}
        },
        [SpecialSendType.Short] = {
            cd = 0,
            record = {}
        }
    }

    self:initEmojiList()
    self:initShortList()
    self:initCalcText()
    self:initEvent()
    self:initTabList()
    --获取最新好友信息
    FriendManager.LoadFriendData()

    --默认下布局
    self:setMainPos()
    self:root():SetLevel(chatSetting.chatLevel or 48)
end

function M:setAlignmentType(type, offset)
    if not type then return end
    self.alignmentType = type
    self.alignmentOffset = offset
    if not self.isMainView then
        self:resetMiniPos()
    else
        self:setShowMode(false)
    end
end

function M:resetMiniPos()
    if self.alignmentType == "CB" then
        self:setBottomPos()
    elseif self.alignmentType == "LT" then
        self:setLeftTopPos()
    else
        self:setBottomPos()
    end
    self.lstContent:SetWidth({1, -5})
    local offset =chatSetting.alignment and chatSetting.alignment.offset or {0,0,0,0}
    local _off = self.alignmentOffset or offset
    local size = chatSetting.alignment and chatSetting.alignment.miniSize or {449, 203, 336}
    if offset then
        self._root:SetArea({0+_off[1],0+_off[2]},{0+_off[3],-20+_off[4]},{0,size[1]},{0,size[2]})
    else
        self._root:SetArea({0,-34},{0,-20},{0,size[1]},{0,size[2]})
    end

    self.winSizeType = BCWinSizeType.Small
    self.lytSizeControl:SetBackImage("set:chat_main.json image:btn_0_unfold")
    self._root:SetBackImage("")
    self.imgContentBg:SetImage("set:chat_main.json image:img_9_talkboard")
    self.isMainView = false
    UI:getWnd("chatBar"):ShowBar(true)
    if UI:isOpen("chatMain") then
        Lib.emitEvent(Event.EVENT_CHAT_VIEW_STATUS, Define.ChatViewStatus.Mini)
    end
end

function getColorOfRGB(str)
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

function M:initCalcText()
    self.pStaticText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "CalcText")
    self.pStaticText:SetTouchable(false)
    self.pStaticText:SetHorizontalAlignment(1)
    self.pStaticText:SetVerticalAlignment(0)
    self.pStaticText:SetTextScale(1)
    self.pStaticText:SetFontSize(chatSetting.chatFont or "HT16")
    self.pStaticText:SetWordWrap(true)
    if chatSetting.chatFontColor then
        local c = getColorOfRGB(chatSetting.chatFontColor)
        self.pStaticText:SetTextColor(getColorOfRGB(chatSetting.chatFontColor))
    else
        self.pStaticText:SetTextColor( {0,0,0})
    end
    
end
function M:splitStringToMultiLine(width, msg)
    local outList = {}
    outList = self.pStaticText:GetFont():SplitStringToMultiLine(width - 15, self.pStaticText:GetTextColor(), msg, outList, {})
    return outList
end

function M:onOpen(mini)
    self.isShow = true
    self.tabList[Define.Page.COMMON]:invoke("setChatIsOpen", self.isShow)
    self:onClickTab(self.curTab)
    local showMain = self.isMainView
    if mini then showMain = false end
    self:setShowMode(showMain)
    self:updateSoundTimes()
    UI:getWnd("chatBar"):setChatShow(true)
    -- self:startHideTimer()
end

function M:updateSoundTimes()
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
    Lib.logDebug('onClose')
    self.isShow = false
    self.tabList[Define.Page.COMMON]:invoke("setChatIsOpen", self.isShow)
    UI:getWnd("chatBar"):setChatShow(false)
    Lib.emitEvent(Event.EVENT_CHAT_VIEW_STATUS, Define.ChatViewStatus.Hide)
    -- 关闭渐隐定时器
    -- self:stopHideTimer()
end
function M:initEvent()
    self:lightSubscribe("error!!!!! script_client win_chat m_inputBtnSend event : EventButtonClick", self.m_inputBtnSend, UIEvent.EventButtonClick, function()
        if not self:checkCanSend() then return end
        self:setShowMode(true)
        self:sendChatMessage()
    end)

    self:lightSubscribe("error!!!!! script_client win_chat m_inputBox event : EventEditTextInput", self.m_inputBox, UIEvent.EventEditTextInput, function(window, trigger)
        Lib.logDebug('window = ', window)
        Lib.logDebug('trigger = ', trigger)

        self.sendMsgText = string.format(self.m_inputBox:GetPropertyString("Text", ""))
        local msgList = self:splitStringToMultiLine(self.lytPut:GetPixelSize().x - 20, self.sendMsgText)
        if msgList[1] then
            self.m_inputBox:SetProperty("Text", msgList[1] .. (msgList[2] and ".." or ""))
        end

        if trigger == 1 then
        elseif trigger == 0 then
            if self:checkCanSend() then
                --self:setShowMode(true)
                self:sendChatMessage()
                -- self:startHideTimer()
            end
        end

    end)


    Lib.lightSubscribeEvent("error!!!!! script_client win_chat event : EVENT_SET_IGNORE", Event.EVENT_SET_IGNORE, function(id, objId, name, btn)
        if not self.ignoreList[id] then
            self.ignoreList[id] = true
            if btn then
                btn:SetText(Lang:toText("ui.chat.disignore"))
            end
        else
            self.ignoreList[id] = false
            if btn then
                btn:SetText(Lang:toText("ui.chat.ignore"))
            end
        end
        Client.ShowTip(1, Lang:toText(self.ignoreList[id] and "ui.chat.ignore.tip" or "ui.chat.disignore.tip"), 40)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat m_inputBox event : EventWindowTouchDown", self.m_inputBox, UIEvent.EventWindowTouchDown, function()
        self:setShowMode(true)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat m_inputBox event : EventWindowTouchUp", self.m_inputBox, UIEvent.EventWindowTouchUp, function()
        self.m_inputBox:SetProperty("Text", self.sendMsgText)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnSoundSend event : EventWindowTouchDown", self.btnSoundSend, UIEvent.EventWindowTouchDown, function()
        --self:setShowMode(true)
        self:startRecordMsg()
        self.txtSoundTip:SetText(Lang:toText("ui.chat.send.voice"))
        self.imgSoundMicIcon:SetVisible(true)
        self.imgSoundCancelIcon:SetVisible(false)
        self.imgMicIcon:SetVisible(true)
        self.btnSoundCancel:SetVisible(true)
        self.lytVoiceCancelBg:SetVisible(true)
        --self.btnSoundSend:SetScale({ x = 1.2, y = 1.2, z = 1.2 })

    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundSend event : EventWindowTouchUp", self.btnSoundSend, UIEvent.EventWindowTouchUp, function()
        --self:setShowMode(true)
        self.txtSoundTip:SetText("")
        self:stopRecordMsg()
        self.imgMicIcon:SetVisible(false)
        self.btnSoundCancel:SetVisible(false)
        self.lytVoiceCancelBg:SetVisible(false)
        --self.btnSoundSend:SetScale({ x = 1, y = 1, z = 1 })
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundSend event : EventWindowTouchMove", self.btnSoundSend, UIEvent.EventWindowTouchMove, function()
        --self.btnSoundSend:SetScale({ x = 1.2, y = 1.2, z = 1.2 })
        if not self.isRecording then return end
        self.imgSoundMicIcon:SetVisible(true)
        self.imgSoundCancelIcon:SetVisible(false)
        self.txtSoundTip:SetText(Lang:toText("ui.chat.send.voice"))
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundSend event : EventMotionRelease", self.btnSoundSend, UIEvent.EventMotionRelease, function()
        --self.btnSoundSend:SetScale({ x = 1, y = 1, z = 1 })
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundCancel event : EventWindowTouchMove", self.btnSoundCancel, UIEvent.EventWindowTouchMove, function()
        if not self.isRecording then return end
        self.txtSoundTip:SetText(Lang:toText("ui.chat.cancel.send.voice"))
        self.imgSoundMicIcon:SetVisible(false)
        self.imgSoundCancelIcon:SetVisible(true)
        self.btnSoundCancel:SetScale({ x = 1.2, y = 1.2, z = 1.2 })
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundCancel event : EventMotionRelease", self.btnSoundCancel, UIEvent.EventMotionRelease, function()
        self.btnSoundCancel:SetScale({ x = 1, y = 1, z = 1 })
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnSoundCancel event : EventWindowTouchUp", self.btnSoundCancel, UIEvent.EventWindowTouchUp, function()
        self:cancelRecordMsg()
        self.txtSoundTip:SetText("")
        self.btnSoundCancel:SetScale({ x = 1, y = 1, z = 1 })
        self.imgMicIcon:SetVisible(false)
        self.btnSoundCancel:SetVisible(false)
        self.lytVoiceCancelBg:SetVisible(false)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat lytVoiceCancelBg event : EventWindowTouchUp", self.lytVoiceCancelBg, UIEvent.EventWindowTouchMove, function()
        if not self.isRecording then return end
        self.imgSoundMicIcon:SetVisible(false)
        self.imgSoundCancelIcon:SetVisible(true)
        self.txtSoundTip:SetText(Lang:toText("ui.chat.cancel.send.voice"))
    end)
    self:lightSubscribe("error!!!!! script_client win_chat lytVoiceCancelBg event : EventWindowTouchUp", self.lytVoiceCancelBg, UIEvent.EventWindowTouchUp, function()
        self:cancelRecordMsg()
        self.txtSoundTip:SetText("")
        self.imgMicIcon:SetVisible(false)
        self.btnSoundCancel:SetVisible(false)
        self.lytVoiceCancelBg:SetVisible(false)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_OPEN_PRIVATE_CHAT", Event.EVENT_OPEN_PRIVATE_CHAT, function(userId,objId, name)
        if not chatSetting.privateChannel then return end
        local player = Game.GetPlayerByUserId(userId)
        if (not name or type(name) ~= "string") and not player then
            perror("face to face,but can't find the player,objId is :", userId)
            return
        end
        if not self.isShow then
            UI:openWnd("chatMain")
        end
        self:setShowMode(true)
        --self.curPrivateObjId =objId

        self.curSelPlayerName = (not name or type(name) ~= "string") and player.name or name
        self.curTab = Define.Page.PRIVATE
        self:openPrivateChat(userId)
    end)
    --点击到最底部
    self:lightSubscribe("error!!!!! script_client win_chat btnGotoBottom event : EventButtonClick", self.btnGotoBottom, UIEvent.EventButtonClick, function()
        --self:setShowMode(true)
        self:gotoBottom()
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnGoBottomNoNew event : EventButtonClick", self.btnGoBottomNoNew, UIEvent.EventButtonClick, function()
        --self:setShowMode(true)
        self:gotoBottom()
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnEmoji event : EventButtonClick", self.btnEmoji, UIEvent.EventButtonClick, function()
        --self:setShowMode(true)
        self:showOrHideWindowByType(WINDOW.EMOJI, not self.lytEmojiBg:IsVisible())
    end)
    self:lightSubscribe("error!!!!! script_client win_chat btnMic event : EventButtonClick", self.btnMic, UIEvent.EventButtonClick, function()
        self:setShowMode(true)
        if not Me:getCanSendSound() then
            UI:openWnd("chatShop")
            return
        end
        self:showOrHideWindowByType(WINDOW.SOUND, true)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnKeyBoard event : EventButtonClick", self.btnKeyBoard, UIEvent.EventButtonClick, function()
        self:setShowMode(true)
        self:showOrHideWindowByType(WINDOW.SOUND, false)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lytWindowClose event : EventWindowTouchDown", self.lytWindowClose, UIEvent.EventWindowTouchDown, function()
        self:setShowMode(false)
        --local window = UI:getWnd("toolbar", true)
        --UI:closeWnd("chatMain")
        --if window then
        --    window:setChatOpened(false)
        --end
        self:showOrHideWindowByType(WINDOW.PLAYER, false)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnWindowClose event : EventWindowTouchDown", self.btnWindowClose, UIEvent.EventButtonClick, function()
        self:setShowMode(false)
        self:showOrHideWindowByType(WINDOW.PLAYER, false)
    end)
    --self:lightSubscribe("error!!!!! script_client win_chat lytSettingCancel event : EventWindowTouchDown", self.lytSettingCancel, UIEvent.EventWindowTouchDown, function()
    --    self:setShowMode(true)
    --    self:showOrHideWindowByType(WINDOW.SETTING, false)
    --end)

    self:lightSubscribe("error!!!!! script_client win_chat chkAutoPlay event : EventCheckStateChanged", self.chkAutoPlay, UIEvent.EventCheckStateChanged, function()
        --self:setShowMode(true)
        local check = self.chkAutoPlay:GetChecked()
        self:setAutoVoiceState(check)
    end)
    self:lightSubscribe("error!!!!! script_client win_chat chkLock event : EventCheckStateChanged", self.chkLock, UIEvent.EventCheckStateChanged, function()
        --self:setShowMode(true)
        local check = self.chkLock:GetChecked()
        self:setLock(check)
    end)
    --self:lightSubscribe("error!!!!! script_client win_chat self event : EventWindowTouchDown", self:root(), UIEvent.EventWindowTouchDown, function()
    --    self:setShowMode(true)
    --end)
    self:lightSubscribe("error!!!!! script_client win_chat lstHistory event : EventWindowTouchDown", self.lstHistory, UIEvent.EventWindowTouchDown, function()
        self:setShowMode(true)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lstContent event : EventWindowTouchDown", self.lstContent, UIEvent.EventWindowTouchDown, function()
        self.lstTouchDown = true
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lstContent event : EventWindowTouchDown", self.lstContent, UIEvent.EventWindowTouchMove, function()
        self.lstMove = true
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lstContent event : EventWindowTouchDown", self.lstContent, UIEvent.EventWindowTouchUp, function()
        if not self.isMainView and self.lstTouchDown and not self.lstMove then
            self:setShowMode(true)
        end
        self.lstTouchDown = false
        self.lstMove = false
    end)

    self:lightSubscribe("error!!!!! script_client win_chat guiInstanceRoot event : EventWindowTouchDown", GUISystem.instance:GetRootWindow(), UIEvent.EventWindowTouchDown, function()
        if UI:isOpen('chatMain') then
            -- 判断锁屏
            if self.lockScreenList[self.curTab] then
                return
            end
            --self:setShowMode(false)
            -- self:stopHideTimer()
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_SCENE_TOUCH_BEGIN", Event.EVENT_SCENE_TOUCH_BEGIN, function(x, y)
        if UI:isOpen('chatMain') then
            -- 判断锁屏
            if self.lockScreenList[self.curTab] then
                return
            end
            --self:setShowMode(false)
            -- self:stopHideTimer()
        end
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lytMiniClose event : EventWindowTouchDown", self.lytMiniClose, UIEvent.EventWindowClick, function()
         --self:stopHideTimer()
         --self:startHideTimer()
        UI:closeWnd("chatMain")
        local window = UI:getWnd("toolbar", true)
        if window and window.setChatOpened then
            window:setChatOpened(false)
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_CHAT_MESSAGE", Event.EVENT_CHAT_MESSAGE, function(msg, fromname, voiceTime, emoji, args, privateArgs, msgPack, isWorldMsg)
        if not args then
            return
        end
        self:showChatMessage(msg, fromname, voiceTime, emoji, args[1],args[2],args[3],args[4], privateArgs, msgPack, isWorldMsg)
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

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_CHAT_VOICE_START", Event.EVENT_CHAT_VOICE_START, function(path)
        local voiceName = string.sub(path, -19)
        local list = {}
        if self.curTab == Define.Page.COMMON then
            list = self.chatDataList
        elseif self.curTab == Define.Page.FAMILY then
            list = self.familyChatDataList
        elseif self.curTab == Define.Page.PRIVATE then
            list = self.privateChatList[self.curSelPlayerName]
        end
        for idx, item in pairs(list) do
            local voiceName2 = string.sub(list[idx].msg, -19)
            if list[idx].voiceTime and voiceName2 == voiceName then
                list[idx].isRead = true
                list[idx].playing = true
                break
            end
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_CHAT_VOICE_END", Event.EVENT_CHAT_VOICE_END, function(path)
        local voiceName = string.sub(path, -19)
        local list = {}
        if self.curTab == Define.Page.COMMON then
            list = self.chatDataList
        elseif self.curTab == Define.Page.FAMILY then
            list = self.familyChatDataList
        elseif self.curTab == Define.Page.PRIVATE then
            list = self.privateChatList[self.curSelPlayerName]
        end
        for idx, item in pairs(list) do
            local voiceName2 = string.sub(list[idx].msg, -19)
            if list[idx].voiceTime and voiceName2 == voiceName then
                list[idx].isRead = true
                list[idx].playing = false
                break
            end
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_SOUND_MOON_CHANGE", Event.EVENT_SOUND_MOON_CHANGE, function(value)
        self.btnMic:SetNormalImage(Me:getSoundMoonCardEnable() and "set:chat_main.json image:btn_0_voice_s_forever" or "set:chat_main.json image:btn_0_voice_s_normal")
        self.btnMic:SetPushedImage(Me:getSoundMoonCardEnable() and "set:chat_main.json image:btn_0_voice_s_forever" or "set:chat_main.json image:btn_0_voice_s_normal")
        --self.txtMicCnt:SetVisible(not Me:getSoundMoonCardEnable())
        self:updateSoundTimes()
    end)
    --Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_OPEN_CHAT_PLAYER", "EVENT_OPEN_CHAT_PLAYER", function(parma)
    --    self:showOrHideWindowByType(WINDOW.PLAYER, true, parma)
    --end)
    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_JUMP_PRIVATE_CHAT", "EVENT_JUMP_PRIVATE_CHAT", function(data)
        --self.curSelPlayerId = data.platId
        self.curSelPlayerName = data.fromname
        data.cnt = 0
        self.historyAdapter:notifyItemDataChange(data)
        self:openPrivateChat(data.platId)
    end)
    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_DEL_PRIVATE_CHAT", "EVENT_DEL_PRIVATE_CHAT", function(platId)
        for idx, data in pairs(self.chatHistoryDataList) do
            if data.platId == platId then
                table.remove(self.chatHistoryDataList, idx)
            end
        end
        self.historyAdapter:setData(self.chatHistoryDataList)
    end)

    self:lightSubscribe("error!!!!! script_client win_chat lytSizeControl event : EventWindowTouchDown", self.lytSizeControl, UIEvent.EventWindowTouchDown, function()
        self:changeBCSize()
    end)

    self:lightSubscribe("error!!!!! script_client win_chat btnEmojiClose event : EventButtonClick", self.btnEmojiClose, UIEvent.EventButtonClick, function()
        self:showOrHideWindowByType(WINDOW.EMOJI, false)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_SET_CHAT_ALIGNMENT", Event.EVENT_SET_CHAT_ALIGNMENT, function(type, offset)
        self:setAlignmentType(type, offset or false)
    end)

    self:subscribe(self.lstContentEx[Define.Page.COMMON], UIEvent.EventScrollMoveChange, function()
        if self.curTab ~= Define.Page.COMMON or not self.isMainView or not self.isShow then return end

        local offset = self.lstContentEx[Define.Page.COMMON]:GetScrollOffset()
        local minOffset = self.lstContentEx[Define.Page.COMMON]:GetMinScrollOffset()
        if offset <= minOffset then
            self.btnGotoBottom:SetVisible(false)
            self.btnGoBottomNoNew:SetVisible(false)
            if self.newMsgList[self.curTab] then
                self.newMsgList[self.curTab] = 0
            end
        elseif offset - minOffset > 20 then
            if not self.btnGoBottomNoNew:IsVisible() and
                    (not self.newMsgList[Define.Page.COMMON] or self.newMsgList[Define.Page.COMMON] == 0) then
                self.btnGoBottomNoNew:SetVisible(true)
            end
        end
    end)

    self:subscribe(self.lstContentEx[Define.Page.PRIVATE], UIEvent.EventScrollMoveChange, function()
        if self.curTab ~= Define.Page.PRIVATE or not self.isMainView or not self.isShow then return end

        local offset = self.lstContentEx[Define.Page.PRIVATE]:GetScrollOffset()
        local minOffset = self.lstContentEx[Define.Page.PRIVATE]:GetMinScrollOffset()
        if offset <= minOffset then
            self.btnGotoBottom:SetVisible(false)
            self.btnGoBottomNoNew:SetVisible(false)
            if self.newMsgList[self.curTab] then
                self.newMsgList[self.curTab] = 0
            end
        elseif offset - minOffset > 20 then
            if not self.btnGoBottomNoNew:IsVisible() and
                    (not self.newMsgList[Define.Page.PRIVATE] or self.newMsgList[Define.Page.PRIVATE] == 0) then
                self.btnGoBottomNoNew:SetVisible(true)
            end
        end
    end)

    self:subscribe(self.lstContentEx[Define.Page.FAMILY], UIEvent.EventScrollMoveChange, function()
        if self.curTab ~= Define.Page.FAMILY or not self.isMainView or not self.isShow then return end

        local offset = self.lstContentEx[Define.Page.FAMILY]:GetScrollOffset()
        local minOffset = self.lstContentEx[Define.Page.FAMILY]:GetMinScrollOffset()
        if offset <= minOffset then
            self.btnGotoBottom:SetVisible(false)
            self.btnGoBottomNoNew:SetVisible(false)
            if self.newMsgList[self.curTab] then
                self.newMsgList[self.curTab] = 0
            end
        elseif offset - minOffset > 20 then
            if not self.btnGoBottomNoNew:IsVisible() and
                    (not self.newMsgList[Define.Page.FAMILY] or self.newMsgList[Define.Page.FAMILY] == 0) then
                self.btnGoBottomNoNew:SetVisible(true)
            end
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_chat event : EVENT_CHECK_IGNORE", Event.EVENT_CHECK_IGNORE, function(id, objId, name, btn)
        if self.ignoreList[id] then
            if btn then
                btn:SetText(Lang:toText("ui.chat.disignore"))
            end
        else
            if btn then
                btn:SetText(Lang:toText("ui.chat.ignore"))
            end
        end
    end)

    Lib.subscribeEvent(Event.EVENT_PLAYER_STATUS, function(status, uId, uName)
        if status == 1 and self.headNameColor[uId] then
            self.headNameColor[uId] = nil
        end
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
    Client.ShowTip(1, Lang:toText(isOpen and "ui.chat.openAutoVoice" or "ui.chat.closeAutoVoice"), 40)
end
--开始录音
function M:startRecordMsg()
    if not Me:getCanSendSound() then
        UI:openWnd("chatShop")
        return
    end
    self.isRecording = true
    VoiceManager:startRecord()
    self.lytWindowClose:SetVisible(false)
    --self.imgMicIcon:SetImage("set:chat_main.json image:icon_mic_ing")
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
                VoiceManager:stopRecord()
                --self.imgMicIcon:SetImage("set:chat_main.json image:icon_mic_b")
                --self:showOrHideWindowByType(WINDOW.SOUND, false)
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
    self.isRecording = false
    self.lytWindowClose:SetVisible(true)
    --self.imgMicIcon:SetImage("set:chat_main.json image:icon_mic_b")
    VoiceManager:stopRecord()
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
    --self.imgMicIcon:SetImage("set:chat_main.json image:icon_mic_b")
    VoiceManager:cancelRecord()
    if self.voiceTimer then
        self.voiceTimer()
        self.txtSoundTime:SetVisible(false)
        self.lastVoiceTime = chatSetting.voiceLastTime or 10
        self.voiceTimer = nil
    end
    --self:showOrHideWindowByType(WINDOW.SOUND, false)
end
function M:openPrivateChat(id)

    --self.curPrivateObjId = id
    if self.curSelPlayerId ~= id then
        self:exchangePrivateList(id)
    end
    self.curSelPlayerId = id

    self.tabList[Define.Page.PRIVATE]:invoke("setCurPlayerId", id)
    self:onClickTab(Define.Page.PRIVATE)
end
function M:showOrHideWindowByType(idx, isShow, playerInfo)
    if idx == WINDOW.SETTING then
        self.lytSettingWindow:SetVisible(isShow)
    elseif idx == WINDOW.SOUND then

        --self.imgWindowBg:SetArea({ 0, 0 }, { 0, 32 }, { 0, 300 }, { 0, 293 })--big
        --self.lytWindow:SetVisible(isShow)
        --self.lytPlayerGround:SetVisible(false)
        self.lytSoundGround:SetVisible(isShow)
        self.btnEmoji:SetVisible(not isShow)
        self.lytPut:SetVisible(not isShow)
        self.lytEmojiBg:SetVisible(false)
        if isShow then
            self.imgMicIcon:SetVisible(false)
            self.btnSoundCancel:SetVisible(false)
            self.lytVoiceCancelBg:SetVisible(false)
        end
    elseif idx == WINDOW.EMOJI then
        self.lytEmojiBg:SetVisible(isShow)
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
        self:setShowMode(false)
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
    Lib.logDebug('call fadeOut')
    self:showOrHideWindowByType(WINDOW.SETTING, false)
    self.lytMiniClose:SetVisible(true)
    self.lytSizeControl:SetVisible(true)

    UIAnimationManager:play(self.lytPut, "fadeOutChat", function()
        self.lytPut:SetVisible(false)
        self.lytPut:SetAlpha(1)
    end)

    UIAnimationManager:play(self.imgInputBg, "fadeOutChat", function()
        self.imgInputBg:SetVisible(false)
        self.imgInputBg:SetAlpha(1)
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

function M:setShowMode(isShow)
    self:showOrHideWindowByType(WINDOW.SOUND, false)
    if isShow then
        -- if self.cdTimer then
        --     self.cdTimer()
        --     self.cdTimer = nil
        -- end
        -- self.imgBg:SetVisible(true)

        self:setMainPos()

        self.lytPut:SetVisible(self.curTab ~= Define.Page.HISTORY)
        self.btnEmoji:SetVisible(self.curTab ~= Define.Page.HISTORY)
        if self.lstContentEx[self.curTab] then
            self.lstContentEx[self.curTab]:SetVisible(self.curTab ~= Define.Page.HISTORY)
        end
    else
        if self.curTab == Define.Page.HISTORY then
            self:onClickTab(Define.Page.COMMON)
        end
        self.lstContentEx[Define.Page.COMMON]:SetVisible(false)
        self.lstContentEx[Define.Page.FAMILY]:SetVisible(false)
        self.lstContentEx[Define.Page.PRIVATE]:SetVisible(false)
        self:resetMiniPos()

        self:showOrHideWindowByType(WINDOW.PLAYER, false)
        --self:showOrHideWindowByType(WINDOW.SETTING, false)
        -- self.imgBg:SetVisible(false)
        --self.imgTip:SetVisible(false)
        self.lytPut:SetVisible(false)
        self.btnEmoji:SetVisible(false)
        self:showOrHideWindowByType(WINDOW.EMOJI, false)
    end
    self.lstContent:SetVisible(not isShow)
    self.lytSettingWindow:SetVisible(isShow)
    self.imgInputBg:SetVisible(isShow)
    self.ltTabList:SetVisible(isShow and not self.hideTabList)
    self.lytMiniClose:SetVisible(not isShow)
    self.lytSizeControl:SetVisible(not isShow)
    self.lytWindowClose:SetVisible(isShow)
    self.btnWindowClose:SetVisible(isShow)
    self.lytShortBg:SetVisible(self.hasShort and isShow)
    self:refreshWin()
end

function M:initTabList()
    for i = Define.Page.COMMON, Define.Page.PRIVATE do
        repeat
            if i == Define.Page.FAMILY and not chatSetting.familyVal then--lua 风格的continue写法,
                break
            end
            if (i == Define.Page.PRIVATE or i == Define.Page.HISTORY) and not chatSetting.privateChannel then--lua 风格的continue写法,
                break
            end
            local chatTab = UIMgr:new_widget("chatTabItem")
            chatTab:invoke("initTabByType", i)
            self:lightSubscribe("error!!!!! script_client win_chat chatTab event : EventWindowClick", chatTab, UIEvent.EventWindowClick, function()
                self:onClickTab(i)
            end)
            self.ltTabList:AddItem(chatTab, true)
            self.tabList[i] = chatTab
        until true
    end
    if not chatSetting.familyVal and not chatSetting.privateChannel then
        self.hideTabList = true
        self.ltTabList:SetVisible(false)
    end
    self:onClickTab(self.curTab)
end

function M:initEmojiList()
    self.lstEmoji = UIMgr:new_widget("grid_view")
    self.lstEmoji:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lstEmoji:InitConfig(0, 0, 6)
    self.lytEmoji:AddChildWindow(self.lstEmoji)
    self.emojiAdapter = UIMgr:new_adapter("chatEmojiAdapter", 108.5, 108.5)
    self.lstEmoji:invoke("setAdapter", self.emojiAdapter)

    local cfg = EmojiConfig:getItems()
    self.emojiAdapter:setData(cfg)
end

function M:initShortList()
    local cfg = ShortConfig:getItems()
    if not next(cfg) then
        self.hasShort = false
        return
    end
    self.hasShort = true
    self.lstShort = UIMgr:new_widget("grid_view")
    self.lstShort:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
    self.lstShort:InitConfig(30, 9, 3)
    self.lytShort:AddChildWindow(self.lstShort)
    local itemWidth = (self.lstShort:GetPixelSize().x - 60) / 3
    local itemHeight = (itemWidth / 197) * 60
    self.shortAdapter = UIMgr:new_adapter("chatShortAdapter", itemWidth, itemHeight)
    self.lstShort:invoke("setAdapter", self.shortAdapter)

    self.shortAdapter:setData(cfg)
end

function M:onClickTab(type)
    if type == Define.Page.PRIVATE and not self.curSelPlayerId then
        Client.ShowTip(1, Lang:toText("ui.chat.pickPlayerPlease"), 40)
        return
    end
    if type == Define.Page.FAMILY and Me:getValue(chatSetting.familyVal) == 0 then
        Client.ShowTip(1, Lang:toText("ui.chat.addFamilyPlease"), 40)
        return 
    end

    if type ~= self.curTab then
        VoiceManager:cleanAutoVoiceList()
    end
    self:changeTabStatus(type)
    self:changeTabContent(type)

end
function M:stopAllVoiceView()
    local list = {}
    if self.curTab == Define.Page.COMMON then
        list = self.chatDataList
    elseif self.curTab == Define.Page.FAMILY then
        list = self.familyChatDataList
    elseif self.curTab == Define.Page.PRIVATE then
        list = self.privateChatList[self.curSelPlayerName]
    end
    for idx, item in pairs(list) do
        if list[idx].voiceTime and list[idx].playing then
            list[idx].isRead = true
            list[idx].playing = false
        end
    end
end
function M:changeTabContent(tab)
    self.listPisList[self.curTab] = self.lstContent:GetScrollOffset()
    self.chatAdapter:clearItems()
    self.lstContent:InitConfig(0, 1, 1)

    if self.curTab ~= tab then
        self:stopAllVoiceView()
    end
    self:showOrHideWindowByType(WINDOW.SOUND, false)
    if tab == Define.Page.COMMON then
        self.lytHistory:SetVisible(false)
        self.lytContent:SetVisible(true)
        self.lytPut:SetVisible(true)
        --self.imgTip:SetVisible(true)
        -- self.imgTip:SetImage("set:chat_main.json image:bg_tip_private")
        self.txtTip:SetText(Lang:toText("ui.chat.commoning"))
        self.btnEmoji:SetVisible(true)
        self.lytHistoryBottom:SetVisible(false)

        self.chatAdapter:setData(self.chatDataList)
    elseif tab == Define.Page.FAMILY then
        self.lytHistory:SetVisible(false)
        self.lytContent:SetVisible(true)
        self.lytPut:SetVisible(true)
        --self.imgTip:SetVisible(true)
        -- self.imgTip:SetImage("set:chat_main.json image:bg_tip_private")
        self.txtTip:SetText(Lang:toText("ui.chat.familing"))
        self.btnEmoji:SetVisible(true)
        self.lytHistoryBottom:SetVisible(false)
        self.chatAdapter:setData(self.familyChatDataList)
    elseif tab == Define.Page.HISTORY then
        self.lytHistory:SetVisible(true)
        self.historyAdapter:setData(self.chatHistoryDataList)
        self.lytContent:SetVisible(false)
        --self.imgTip:SetVisible(false)
        self.btnGotoBottom:SetVisible(false)
        self.btnGoBottomNoNew:SetVisible(false)
        self.lytPut:SetVisible(false)
        self.btnEmoji:SetVisible(false)
        self.lytHistoryBottom:SetVisible(true)
    elseif tab == Define.Page.PRIVATE then
        self.lytHistory:SetVisible(false)
        self.lytContent:SetVisible(true)
        self.lytPut:SetVisible(true)
        --self.imgTip:SetVisible(true)
        self.txtTip:SetText(Lang:toText({ "ui.chat.privating", self.curSelPlayerName }))
        self.btnEmoji:SetVisible(true)
        self.lytHistoryBottom:SetVisible(false)
        if not self.privateChatList[self.curSelPlayerName] then
            self.privateChatList[self.curSelPlayerName] = {}
        end
        self.chatAdapter:setData(self.privateChatList[self.curSelPlayerName])
    end

    if tab ~= Define.Page.HISTORY then
        self.lstContent:SetScrollOffset(self.listPisList[tab] or 0)
        if not self.listPisList[tab] or self.listPisList[tab] == 0 then
            self.chatAdapter:notifyDataChange()
        end

        if self.newMsgList[tab] and self.newMsgList[tab] > 0 then
            self.btnGotoBottom:SetVisible(true)
            self.btnGoBottomNoNew:SetVisible(false)
            self.btnGotoBottom:SetText(Lang:toText({ "ui.chat.newMsg", self.newMsgList[tab] }))
        else
            self.btnGotoBottom:SetVisible(false)
        end
    end

    self.curTab = tab
    self.chkLock:SetChecked(self.lockScreenList[tab])
    self.chkAutoPlay:SetChecked(self.autoVoiceStateList[tab])

    if self.isMainView then
        self.lstContentEx[Define.Page.COMMON]:SetVisible(false)
        self.lstContentEx[Define.Page.FAMILY]:SetVisible(false)
        self.lstContentEx[Define.Page.PRIVATE]:SetVisible(false)
        if self.curTab ~= Define.Page.HISTORY then
            --if self.curTab ~= Define.Page.PRIVATE then
            --
            --end
            self:loadExMsgCache(self.curTab)
            self.lstContentEx[self.curTab]:SetVisible(true)
            local offset = self.lstContentEx[tab]:GetScrollOffset()
            local minOffset = self.lstContentEx[tab]:GetMinScrollOffset()
            if offset - minOffset > 20 then
                self.btnGoBottomNoNew:SetVisible(true)
            end
        end
    end
end
function M:changeTabStatus(tab)
    for _, chatTab in pairs(self.tabList) do
        chatTab:invoke("onCheckClick", tab)
    end

    if tab == Define.Page.PRIVATE then
        self.tabList[Define.Page.PRIVATE]:invoke("updatePlayerName", self.curSelPlayerName)
    end
end
function M:sendVoiceMsg(time, url)
    if self.curTab == Define.Page.COMMON then
        self:commonChat(url, time)
    elseif self.curTab == Define.Page.FAMILY then
        self:familyChat(url,time)
    elseif self.curTab == Define.Page.PRIVATE then
        self:privateChat(url, time)
    end
    Client.ShowTip(1, Lang:toText("ui.chat.send.voice.succ"), 40)
    self:sendTimeCount()
end
--input and get Message for outside
function M:sendChatMessage()
    local msg = self.sendMsgText
    if not msg or #msg < 1 then
        return
    end
    if self.curTab == Define.Page.COMMON then
        self:commonChat(msg)
    elseif self.curTab == Define.Page.FAMILY then
        self:familyChat(msg)
    elseif self.curTab == Define.Page.PRIVATE then
        self:privateChat(msg)
    end
    self.m_inputBox:SetProperty("Text", "")
    self.sendMsgText = ""
    self:sendTimeCount()
end

function M:sendEmoji(emoji)
    if not self:checkCanSend(SpecialSendType.Emoji) or not self:checkSpecialSend(SpecialSendType.Emoji) then
        return
    end
    if self.curTab == Define.Page.COMMON then
        self:commonChat("", false, emoji)
    elseif self.curTab == Define.Page.FAMILY then
        self:familyChat("", false, emoji)
    elseif self.curTab == Define.Page.PRIVATE then
        self:privateChat("", false, emoji)
    end
    self:sendTimeCount()
end

function M:sendShort(short)
    if not self:checkCanSend(SpecialSendType.Short) or not self:checkSpecialSend(SpecialSendType.Short) then
        return
    end
    if self.curTab == Define.Page.COMMON then
        self:commonChat(short)
    elseif self.curTab == Define.Page.FAMILY then
        self:familyChat(short)
    elseif self.curTab == Define.Page.PRIVATE then
        self:privateChat(short)
    end
    self:sendTimeCount()
end

function M:commonChat(msg, time, emoji)
    local packet = {
        pid = "ChatMessage",
        fromname = Me.name,
        msg = msg,
        voiceTime = time or false,
        emoji = emoji or false
    }

    -- if msg == "/blockmango_gm" then
    --     local mainUI = UI:getWnd("main")
    --     mainUI:child("Main-GM"):SetVisible(true)
    --     return
    -- end
    Me:sendPacket(packet)
end
function M:familyChat(msg, time, emoji)
    local packet ={
		pid = "ChatMessageToFamily",
        fromname = Me.name,
        msg = msg,
        voiceTime = time or false,
        emoji = emoji or false
    }
	Me:sendPacket(packet)
end
function M:privateChat(msg, time, emoji)
    local packet = {
        pid = "ChatMessageToPrivate",
        fromname = Me.name,
        msg = msg,
        voiceTime = time or false,
        targetId = self.curSelPlayerId,
        targetName = self.curSelPlayerName,
        emoji = emoji or false
    }
    Me:sendPacket(packet)
end

function M:addMsg(type, info, privateArgs)
    local infoList = self:unpackMsg(info)
    self:addMsgInExList(info,type,false,privateArgs)
    if type == Define.Page.FAMILY then
        if #self.familyChatDataList >=200-(#infoList) then
            for i = 1,(#infoList) do
                table.remove(self.familyChatDataList,1)
            end
        end 
        for _,item_info in pairs(infoList) do
            table.insert(self.familyChatDataList,item_info)

        end

    elseif type == Define.Page.PRIVATE then
        local objID = privateArgs and privateArgs.targetId or info.objID
        local name = privateArgs and privateArgs.targetName or info.fromname
        if not self.privateChatList[name] then
            self.privateChatList[name] = {}
        end
        if #self.privateChatList[name] >= 200 - (#infoList) then
            for i = 1, (#infoList) do
                table.remove(self.privateChatList[name], 1)
            end
        end
        for _, item_info in pairs(infoList) do
            table.insert(self.privateChatList[name], item_info)
        end
        -- table.insert(self.privateChatList[name],info) 
        self:updateHistory(info, type, privateArgs)
    else
        if #self.chatDataList >= 200 - (#infoList) then
            -- table.remove(self.chatDataList,1)
            for i = 1, (#infoList) do
                table.remove(self.chatDataList, 1)
            end
        end
        for _, item_info in pairs(infoList) do
            table.insert(self.chatDataList, item_info)
        end
    end
end
---将长消息拆分为多项
function M:unpackMsg(info)
    local infoList = {}
    local nameLen = (#info.fromname)
    local nameHead = "[" .. info.fromname .. "]:"
    if info.voiceTime then
        table.insert(infoList, info)
    elseif info.emoji then
        table.insert(infoList, info)
        --for i = 1, 4 do
        --    table.insert(infoList, { msg = "        ", fromname = "", objID = info.objID,dign = info.dign, platId = info.platId, isWorldMsg = info.isWorldMsg })
        --end
    else
        if info.dign == Define.ChatPlayerType.server then
            local listStr = Lib.splitString(info.msg, ",")
            if #listStr == 1 then 
                info.msg = Lang:toText(info.msg)
            elseif #listStr == 2 then
                info.msg = Lang:toText(listStr)
            else--用户名字带“,”的情况
                local nameStr = ""
                for i = 2,(#listStr-1) do
                    nameStr = nameStr .. listStr[i] .. (i==(#listStr-1) and '' or ',')
                end
                info.msg = Lang:toText({listStr[1],nameStr,listStr[#listStr]})
            end
            nameLen = #Lang:toText(info.fromname)
            nameHead = "["..Lang:toText(info.fromname).."]:"
        end
        local size = chatSetting.alignment and chatSetting.alignment.miniSize or {617, 203, 336}
        local outList = self:splitStringToMultiLine(size[1] - 20, nameHead .. info.msg)
        outList[1] = string.sub(outList[1], nameLen + 4)
        for i, item in pairs(outList) do
            local _info = { msg = item, fromname = i == 1 and info.fromname or "", objID = info.objID,dign = info.dign, platId = info.platId, isWorldMsg = info.isWorldMsg }
            if info.nameColor then
                _info.nameColor = info.nameColor
            end
            table.insert(infoList, _info)
            end
    end
    return infoList
end
--更新历史页面 
function M:updateHistory(info, type, privateArgs)
    local objID, fromname,dign, platId = info.objID, info.fromname,info.dign, info.platId
    --当前正在私聊时产生的消息不更新右侧红点,不更新历史页面

    if privateArgs then
        objID = privateArgs.targetId
        platId = privateArgs.targetUserId
        fromname = privateArgs.targetName
    end
    --自己发消息永远不更新红点
    if objID == Me.platformUserId then
        return
    end

    if  dign == Define.ChatPlayerType.server then
        return
    end

    local has = false
    for _, history in pairs(self.chatHistoryDataList) do
        print("history.objID:",history.objID)
        print("objID:",objID)
        if history.objID == objID then
            has = true
            if info.objID ~= Me.platformUserId then
                history.cnt = history.cnt + 1
            end

            self.historyAdapter:notifyItemDataChange(history)
            if self.curTab ~= Define.Page.PRIVATE or self.curSelPlayerId ~= objID or not self.isMainView or not UI:isOpen("chatMain") then
                if not self:checkIsIgnore(objID) then
                    Lib.emitEvent("EVENT_CHAT_HISTORY_CHANGE")
                end
            end
            break
        end
    end
    if not has then
        table.insert(self.chatHistoryDataList, 1, { objID = objID, fromname = fromname, cnt = objID ~= Me.platformUserId and 1 or 0,dign = dign, platId = platId, type = type })
        self.historyAdapter:setData(self.chatHistoryDataList)
        if self.curTab ~= Define.Page.PRIVATE or self.curSelPlayerId ~= objID then
            if not self:checkIsIgnore(objID) then
                Lib.emitEvent("EVENT_CHAT_HISTORY_CHANGE")
            end
        end
    end
end

--消息显示
function M:showChatMessage(msg, fromname, voiceTime, emoji, objID, dign, type, platId, privateArgs, msgPack, isWorldMsg)
    local h, msgLen = 20, string.len(msg)
    if (msg == "nil" or msgLen == 0) and not emoji then
        return
    end
    if self.ignoreList[platId] then
        return
    end

    local nameColor = nil
    if type ~= Define.Page.PRIVATE then
        nameColor = self:checkNameColor(platId)
    end
    local calcOffset = (type == self.curTab) and self.lstContent:GetScrollOffset() or (self.listPisList[type] or 0)
    local upTooFar = (calcOffset - self:getBottomOffset(type)) > 40--self.lstContent:GetScrollOffset()
    if self.isMainView and self.lstContentEx[self.curTab] then
        calcOffset = (type == self.curTab) and self.lstContentEx[self.curTab]:GetScrollOffset() or (self.listPisList[type] or 0)
        upTooFar = (calcOffset -  self.lstContentEx[self.curTab]:GetMinScrollOffset()) > 40
    end

    local info = { msg = msg,
                   fromname = fromname,
                   voiceTime = voiceTime,
                   emoji = emoji,
                   objID = objID,
                   dign = dign,
                   platId = platId,
                   msgPack = msgPack,
                   isWorldMsg = isWorldMsg
    }
    if nameColor then info.nameColor = nameColor end

    self:addMsg(type, info, privateArgs)

    if self.curTab == Define.Page.COMMON then
        self.chatAdapter:setData(self.chatDataList)
    elseif self.curTab == Define.Page.FAMILY then
        self.chatAdapter:setData(self.familyChatDataList)
    elseif self.curTab == Define.Page.PRIVATE then
        self.chatAdapter:setData(self.privateChatList[self.curSelPlayerName])
    end

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

local function copyData(self,type,fromIdx,toIdx)
    local fromItem = self.lstContentEx[type]:GetItem(fromIdx)
    local toItem = self.lstContentEx[type]:GetItem(toIdx)
    toItem:invoke("initViewByData",fromItem:invoke("getData"))
end

function M:exchangePrivateList(userId)
    --上一个私聊对象全部重置为未处理
    if self.curSelPlayerId then
        local list =self.exInfoCache[Define.Page.PRIVATE][self.curSelPlayerId]
        if list and #list > 0 then
            local cnt =#list
            for i = 1,cnt do
                list[i].isNewMsg = true
            end
        end
    end

    local privateListItemCnt = self.lstContentEx[Define.Page.PRIVATE]:GetItemCount()
    local privateChatInfoCnt = self.exInfoCache[Define.Page.PRIVATE][userId] and #self.exInfoCache[Define.Page.PRIVATE][userId] or 0
    local needAdd = privateChatInfoCnt-privateListItemCnt
    if needAdd>=0 then
        for i = 1,needAdd do
            self:addMsgInExList(self.exInfoCache[Define.Page.PRIVATE][userId][privateChatInfoCnt-needAdd+i],Define.Page.PRIVATE,true)
        end
        for i = 1,privateChatInfoCnt-needAdd do
            local info = self.exInfoCache[Define.Page.PRIVATE][userId][i]
            info.isNewMsg = false
            self.lstContentEx[Define.Page.PRIVATE]:GetItem(i-1):invoke("initViewByData",info)
        end
    else
        needAdd = -needAdd
        for i = 1,needAdd do
            local item = self.lstContentEx[Define.Page.PRIVATE]:GetItem(0)
            self.lstContentEx[Define.Page.PRIVATE]:RemoveItem(item,false)
            table.insert(contentItemPool,item)
        end

        for i = 1,privateChatInfoCnt do
            local info = self.exInfoCache[Define.Page.PRIVATE][userId][i]
            info.isNewMsg = false
            self.lstContentEx[Define.Page.PRIVATE]:GetItem(i-1):invoke("initViewByData",info)
        end

    end
    self.lstContentEx[Define.Page.PRIVATE]:GoLastScroll()

end

function M:loadExMsgCache(type)
    if type == Define.Page.PRIVATE then
        if self.exInfoCache[type][self.curSelPlayerId] then
            local cnt = #self.exInfoCache[type][self.curSelPlayerId]
            local doCnt = cnt - math.max(cnt-Define.MainChatMaxCnt,0)
            for i = 1,doCnt do
                local data = self.exInfoCache[type][self.curSelPlayerId][cnt-doCnt+i]
                if data.isNewMsg then
                    self:addMsgInExList(data,type)
                end
            end
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
        --local retTb = {}
        --local start = tbCnt-Define.MainChatMaxCnt
        --for i = 1,Define.MainChatMaxCnt do
        --    table.insert(retTb,tb[start+i])
        --end
        --tb = retTb
    end
end

function M:addMsgInExList(data,type,force,privateArgs)
    --非大窗，未打开聊天或者非当前分页情况下只做数据记录，不做界面更新
    local targetId = privateArgs and privateArgs.targetUserId and privateArgs.targetUserId or data.platId

    if not self.isMainView or not self.isShow or (self.curTab ~= type and not force) then
        if type == Define.Page.PRIVATE then
            if not self.exInfoCache[type][targetId] then
                self.exInfoCache[type][targetId] = {}
            end
            data.isNewMsg = true
            table.insert(self.exInfoCache[type][targetId],data)
            cleanDoubleMaxInfoTable(self.exInfoCache[type][targetId])
        else
            table.insert(self.exInfoCache[type],data)
            cleanDoubleMaxInfoTable(self.exInfoCache[type])
        end

        return
    end
    --私聊无论是否处理UI都要缓存
    if   type == Define.Page.PRIVATE and self.curTab == Define.Page.PRIVATE  then
        if not self.exInfoCache[type][targetId] then
            self.exInfoCache[type][targetId] = {}
        end
        data.isNewMsg = true
        table.insert(self.exInfoCache[type][targetId],data)
        cleanDoubleMaxInfoTable(self.exInfoCache[type][targetId])
        --当前私聊页面不为本次消息所属玩家时不再继续处理ui
        if self.curSelPlayerId ~=targetId and targetId ~=Me.platformUserId and not force then
            return
        end

    end

    local pageCnt = self.lstContentEx[type]:GetItemCount()

    if pageCnt >=Define.MainChatMaxCnt then

        local item = self.lstContentEx[type]:GetItem(0)
        self.lstContentEx[type]:RemoveItem(item,false)
        item:invoke("initViewByData",data)
        self.lstContentEx[type]:AddItem(item)


    else

        local cell
        if #contentItemPool>0 then
            cell = table.remove(contentItemPool)
        else
            cell = UIMgr:new_widget("chatContentItemEx")
        end

        cell:invoke("initViewByData",data)
        self.lstContentEx[type]:AddItem(cell)
    end
    data.isNewMsg = false

    --local i = 0
    --local isDone = false
    --while(self.lstContentEx:GetItem(i)) do
    --    local item = self.lstContentEx:GetItem(i)
    --    if not item:IsVisible() then
    --        item:SetVisible(true)
    --        item:invoke("initViewByData",data)
    --        isDone = true
    --        break
    --    end
    --end
    --if not isDone then
    --    local cell = UIMgr:new_widget("chatContentItemEx")
    --    cell:invoke("initViewByData",data)
    --    self.lstContentEx:AddItem(cell)
    --end
end
function M:getBottomOffset(tab)
    local calcTab = tab or self.curTab
    local gotoBottom = 0
    local msgLen = 0
    if calcTab == Define.Page.COMMON then
        msgLen = #self.chatDataList
    elseif calcTab == Define.Page.FAMILY then
        msgLen = #self.familyChatDataList
    elseif calcTab == Define.Page.PRIVATE then
        msgLen = self.privateChatList[self.curSelPlayerName] and #self.privateChatList[self.curSelPlayerName] or 0
    end
    local allItemH = msgLen * ((chatSetting.chtBarHeight or 28) + 1) - 1
    gotoBottom = math.min(0, self.lstContent:GetPixelSize().y - allItemH)
    return gotoBottom
end
--到最底部
function M:gotoBottom()
    self.btnGotoBottom:SetVisible(false)
    self.btnGoBottomNoNew:SetVisible(false)
    self.newMsgList[self.curTab] = 0
    if self.curTab ~= Define.Page.HISTORY then
        World.LightTimer("lstScroll",1,function()
            self.lstContentEx[self.curTab]:GoLastScroll()
        end)
    end
    if not self.isMainView then
        self.chatAdapter:setScrollOffset(self:getBottomOffset())
        World.LightTimer("gotoBottom",2,function()
            self.chatAdapter:setScrollOffset(self:getBottomOffset())
        end)
    end
end
--添加未读消息提示
function M:addNewMsgTips(type)
    if not self.newMsgList[type] then
        self.newMsgList[type] = 0
    end

    self.newMsgList[type] = self.newMsgList[type] + 1
    if type == self.curTab then
        self.btnGotoBottom:SetVisible(true)
        self.btnGoBottomNoNew:SetVisible(false)
        self.btnGotoBottom:SetText(Lang:toText({ "ui.chat.newMsg", self.newMsgList[self.curTab] }))
    end
end
function M:isSelfMsg()
end

function M:setMainPos()
    self.lstContent:SetWidth({1, 0})
    self._root:SetHorizontalAlignment(0)
    self._root:SetVerticalAlignment(0)
    self._root:SetArea({0,0},{0,0},{0,617},{1,0})
    self._root:SetBackImage("set:chat_main.json image:img_9_talkboard_big")
    self.imgContentBg:SetImage("")
    self.isMainView = true
    if UI:isOpen(self) then
        UI:getWnd("chatBar"):ShowBar(false)
    end
    if self.curTab ~= Define.Page.HISTORY then
        self:loadExMsgCache(self.curTab)
    end
    if UI:isOpen("chatMain") then
        Lib.emitEvent(Event.EVENT_CHAT_VIEW_STATUS, Define.ChatViewStatus.Main)
    end
end

function M:setLeftTopPos()
    self._root:SetHorizontalAlignment(0)
    self._root:SetVerticalAlignment(0)
    -- self:root():SetAlwaysOnTop(true)
    -- self:root():SetLevel(1)
end
function M:setBottomPos()
    self._root:SetHorizontalAlignment(1)
    self._root:SetVerticalAlignment(2)
    -- self:root():SetAlwaysOnTop(false)
    -- self:root():SetLevel(50)
end

function M:changeBCSize()
    local size = chatSetting.alignment and chatSetting.alignment.miniSize or {617, 203, 336}
    if self.winSizeType == BCWinSizeType.Big then
        self._root:SetHeight({ 0, size[2] })
        self.winSizeType = BCWinSizeType.Small
        self.lytSizeControl:SetBackImage("set:chat_main.json image:btn_0_unfold")
    elseif self.winSizeType == BCWinSizeType.Small then
        self._root:SetHeight({ 0, size[3] })
        self.winSizeType = BCWinSizeType.Big
        self.lytSizeControl:SetBackImage("set:chat_main.json image:btn_0_shrink")
    end
    self:refreshWin()
end

function M:refreshWin()
    self.lstContent:InitConfig(0, 1, 1)
    self.lstHistory:InitConfig(0, 0, 1)
    self.lstContentEx[Define.Page.COMMON]:InitConfig(0, 1, 1)
    self.lstContentEx[Define.Page.FAMILY]:InitConfig(0, 1, 1)
    self.lstContentEx[Define.Page.PRIVATE]:InitConfig(0, 1, 1)
    self.chatAdapter:notifyDataChange()
    self:gotoBottom()
end

function M:checkIsIgnore(id)
    return self.ignoreList[id]
end

function M:checkCanSend(type)
    if not self.canSend[self.curTab] then
        if type then
            local cd = self.specialSend[type].cd
            local time = self.specialSendLimit.cdTime - math.ceil(os.time() - cd)
            local text = Lang:toText("ui.chat.cannotsend")
            if time > 0 then
                text = string.format(Lang:toText(SpecialSendTip[type]), time)
            end
            Client.ShowTip(1, text, 40)
        else
            local time = self.duration - math.ceil(os.time() - self.lastSendTime[self.curTab])
            local text = Lang:toText("ui.chat.cannotsend")
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
                text = string.format(Lang:toText(SpecialSendTip[type]), time)
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

function M:checkNameColor(userId)
    local default = chatSetting.chatNiceNameColor or "FF0000"
    if not chatSetting.chatHeadColor then
        return nil
    end

    if self.headNameColor[userId] then
        return self.headNameColor[userId]
    end
    self.chatNum = self.chatNum + 1
    local color = getChatNameColor(self.chatNum)
    self.headNameColor[userId] = color
    return color or default
end

return M