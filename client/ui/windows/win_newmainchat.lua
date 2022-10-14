--新界面聊天框
M.chatChannel = World.cfg.chatChannel or {"current"}
function M:init()
	self.objID = Me.objID
	WinBase.init(self, "NewMainChatPanel.json",false)
	self.base = self:child("NewMainChatPanel-Base")
    self.base:SetVisible(true)

    self.bool_message_bg = false
    self._messageItem = 0
    self.count = 0
	self:initWnd()
end

function M:initWnd()
    self.chat_message = self:child("NewMainChatPanel-Msg_List")
    self.chat_message:SetTouchable(false)

    self.chat_message_bg = self:child("NewMainChatPanel-Base_Img")
    self.chat_message_bg:SetVisible(false)

    self.m_inputType = self:child("NewMainChatPanel-Base-Type")
    self.m_inputType:SetItemAlignment(0)
    self.m_inputType:SetMoveAble(false)
    self.m_inputType:SetAutoColumnCount(false)
    self.m_inputType:InitConfig(0,0,#self.chatChannel)

    self.showChannel = {}
    self.hideChannel = {}
    self.selectChannel = self.chatChannel[1] or "current"
    self.chatChannelContent= {[self.chatChannel[1]] = self.chat_message}
    self.channelMessageItem = {[self.chatChannel[1]] = 0}
    self:initChatChannel()

    local hideBtn = self:child("NewMainChatPanel-Hide_Btn")
    self.hideBtn = hideBtn
    hideBtn:SetVisible(false)
    self:lightSubscribe("error!!!!! script_client win_newmainchat hideBtn event : EventButtonClick",hideBtn, UIEvent.EventButtonClick, function()
        self.chat_message_bg:SetVisible(false)
        self.hideBtn:SetVisible(false)
        self.openBtn:SetVisible(true)
    end)

    local openBtn = self:child("NewMainChatPanel-Open_Btn")
    self.openBtn = openBtn
    openBtn:SetVisible(true)
    self:lightSubscribe("error!!!!! script_client win_newmainchat openBtn event : EventButtonClick",openBtn, UIEvent.EventButtonClick, function()
        self.chat_message_bg:SetVisible(true)
        self.hideBtn:SetVisible(true)
        self.openBtn:SetVisible(false)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_newmainchat Lib event : EVENT_CHAT_MESSAGE",Event.EVENT_CHAT_MESSAGE, function(msg,fromname,type)
        self:showChatMessage(msg,fromname,type)
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_newmainchat Lib event : EVENT_CHAT_CHANNEL",Event.EVENT_CHAT_CHANNEL, function(show, channelName)
        if show == nil or show then
            self:showChatChannel(channelName)
        else
            self:hideChatChannel(channelName)
        end
        self.m_inputType:SetVisible(#self.showChannel>1)
    end)
end

function M:initChatChannel()
    if #self.chatChannel <= 1 then
        if self.chatChannelContent[self.selectChannel] then
            self.chatChannelContent[self.selectChannel]:SetVisible(false)
        end
        self.selectChannel = self.chatChannel[1]
        if self.chatChannelContent[self.selectChannel] then
            self.chatChannelContent[self.selectChannel]:SetVisible(true)
        end
        return
    end
    for i, type in ipairs(self.chatChannel) do
        local radioBtn = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", "Chat-Channel-" .. type)
        local radioName = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Chat-Channel-Name-" .. type)
        radioBtn:SetArea({ 0, 0 }, { 0, 0 }, { 0, 70 }, { 1, 0 })
        radioBtn:SetNormalImage("set:newbie_guide.json image:select-team-nubl")
        radioBtn:SetPushedImage("set:new_gui_material.json image:chat_input_bg")
        radioBtn:SetProperty("StretchType", "NineGrid")
        radioBtn:SetProperty("StretchOffset", "5 5 2 5")
        radioName:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
        radioName:SetTextHorzAlign(1)
        radioName:SetTextVertAlign(1)
        radioName:SetText(Lang:toText("chat.channel." .. type))
        radioBtn:AddChildWindow(radioName)
        if not self.chatChannelContent[type] then
            local wnd = GUIWindowManager.instance:CloneWindow("CloneWindow-" .. type, self.chat_message)
            wnd:SetVisible(false)
            self.chatChannelContent[type] = wnd
            self.channelMessageItem[type] = 0
            self.chat_message_bg:AddChildWindow(wnd)
        end
        self:lightSubscribe("error!!!!! script_client win_newmainchat radioBtn-i="..i.."-type="..type.." event : EventRadioStateChanged",radioBtn, UIEvent.EventRadioStateChanged, function(statu)
            if statu:IsSelected() then
                if self.chatChannelContent[self.selectChannel] then
                    self.chatChannelContent[self.selectChannel]:SetVisible(false)
                end
                self.selectChannel = type
                if self.chatChannelContent[type] then
                    self.chatChannelContent[type]:SetVisible(true)
                end
            end
        end)
        table.insert(self.showChannel, type)
        self.showChannel[type] = radioBtn
        self.m_inputType:AddItem(radioBtn)
        if i == 1 then
            radioBtn:SetSelected(true)
        end
    end
end

function M:hideChatChannel(channelName)
    if self.hideChannel[channelName] then
        return
    end
    for i, type in ipairs(self.showChannel) do
        if type == channelName then
            local radio = self.showChannel[channelName]
            self.m_inputType:RemoveItem(radio)
            self.hideChannel[channelName] = radio
            self.showChannel[channelName] = nil
            table.remove(self.showChannel, i)
        end
    end
    if self.selectChannel == channelName then
        for _, type in ipairs(self.chatChannel) do
            local radio = self.showChannel[type]
            if type ~= channelName and radio then
                radio:SetSelected(true)
                break
            end
        end
    end
end

function M:showChatChannel(channelName)
    local radio = self.hideChannel[channelName]
    if not radio then
        return
    end
    for i, type in ipairs(self.chatChannel) do
        if type == channelName then
            table.insert(self.showChannel, type)
            self.showChannel[type] = radio
            self.hideChannel[type] = nil
            self.m_inputType:AddItem(radio, i)

        end
    end
end

function M:showChatMessage(msg,fromname,type)
    type = type or "current"
    local msgLen = string.len(msg)
	if msg == "nil" or msgLen == 0  then
		return
    end 
    if self.chatChannelContent[type] == nil or self.channelMessageItem[type] == nil then
        return
    end
    local strTextName = string.format("PromptNotice-Chat-Message-List-item-%d", self.count)
    self.count = self.count + 1

    local strTextBase = GUIWindowManager.instance:LoadWindowFromJSON("NewMainChatCell.json"):child("NewMainChatCell-Base")
    local textBase = strTextBase:child("NewMainChatCell-Msg")

	if fromname then
		msg = "▢FFFF0000["..fromname.."]▢FF00FF00"..msg
		textBase:SetText(msg)
	else
		textBase:SetText(msg)
	end
	local h = (textBase:GetFont():GetTextExtent(msg,1.0) / textBase:GetPixelSize().x + 1) * 25
    local area = strTextBase:GetPixelSize()
    strTextBase:SetArea({ 0, 0 }, { 0, 0 }, { 0, area.x }, { 0, h})

    local channelContent = self.chatChannelContent[type]
    if channelContent then
        channelContent:AddItem(strTextBase, false)
        self.channelMessageItem[type] = self.chatChannelContent[type]:getContainerWindow():GetChildCount()
    end
    local mItem = self.channelMessageItem[type]
	strTextBase:SetWidth({ 1, 0 })
	if not self.bool_message_bg and type == self.selectChannel then
		self:messageBgEvent(true, channelContent)
	end
	local time = 20
    local function tick()
        time = time - 1
        if time == 0 or mItem > 6 then
            self.channelMessageItem[type] = mItem - 1
			if self.channelMessageItem[type] < 1 and type == self.selectChannel then
				self:messageBgEvent(false, channelContent)
			end
            self:removeChat(channelContent)
            return false
        end
        return true
    end

    self._close_chat = World.Timer(20, tick)

end

function M:removeChat(m_chat)
    if m_chat and m_chat:getContainerWindow() then
        if m_chat:getContainerWindow():GetChildCount() > 0 then
            m_chat:DeleteItem(0)
        end
    end
end

function M:messageBgEvent(bol, m_chat)
    if not World.cfg.hideNewMainChat then
    	self.bool_message_bg = bol
        self.chat_message_bg:SetVisible(bol)
        self.hideBtn:SetVisible(bol)
        self.openBtn:SetVisible(not bol)
        m_chat:SetTouchable(bol)
    end
end

function M:onOpen()
    if World.cfg.hideNewMainChat then
        self.chat_message_bg:SetVisible(false)
        self.base:SetVisible(false)
        self.hideBtn:SetVisible(false)
        self.openBtn:SetVisible(false)
        return
    end
    local roomInfoWnd = UI:getWnd("main"):child("Main-Online-Room-Info")
    if World.CurWorld.isEditorEnvironment then
        self._root:SetYPosition({0, 180})
    elseif roomInfoWnd then
        self._root:SetYPosition({0, 210})
    else
        self._root:SetYPosition({0, 125})
    end
end

function M:onClose()

end