local TRAY_ID = 1
M.chatChannel = World.cfg.chatChannel or {"current"}
function M:init()

    WinBase.init(self, "Chat.json", true)

    -- print(self._root)
    self.m_chatContent = self:child("Chat-Content")
    self.m_closeBtnBack = self:child("Chat-BtnBack")
    self.m_input = self:child("Chat-Input")
	self.m_inputBox = self:child("Chat-Input-Box")
	self.m_inputBtnSend = self:child("Chat-Input-BtnSend")
	self.m_inputType = self:child("Chat-Input-Type")
	self.m_inputType:SetItemAlignment(0)
	self.m_inputType:SetMoveAble(false)
	self.m_inputType:SetAutoColumnCount(false)
	self.m_inputType:InitConfig(0,0,#self.chatChannel)

	self.showChannel = {}
	self.hideChannel = {}

	self._close_chat = nil
	self.count = 0
	self._root:SetVisible(false)
	self.selectChannel = self.chatChannel[1] or "current"
	self.chatChannelContent= {[self.chatChannel[1]] = self.m_chatContent}
	self.channelMessageItem = {[self.chatChannel[1]] = 0}

	self:lightSubscribe("error!!!!! : win_chat m_closeBtnBack event : EventButtonClick", self.m_closeBtnBack, UIEvent.EventButtonClick, function()
        self:chatbtnClose()
    end)

	self:lightSubscribe("error!!!!! : win_chat m_inputBtnSend event : EventButtonClick", self.m_inputBtnSend, UIEvent.EventButtonClick, function()
        self:sendChatMessage()
    end)
	Lib.lightSubscribeEvent("error!!!!! : win_chat lib event : EVENT_CHAT_MESSAGE", Event.EVENT_CHAT_MESSAGE, function(msg,fromname,type)
		self:showChatMessage(msg,fromname,type)
	end)

	Lib.lightSubscribeEvent("error!!!!! : win_chat lib event : EVENT_CHAT_CHANNEL", Event.EVENT_CHAT_CHANNEL, function(show, channelName)
		if show == nil or show then
			self:showChatChannel(channelName)
		else
			self:hideChatChannel(channelName)
		end
		self.m_inputType:SetVisible(#self.showChannel>1)
	end)

	self:initChatChannel()
end

function M:chatbtnClose()
    Lib.emitEvent(Event.EVENT_OPEN_CHATBTN, false)
end

--input and get Message for outside
function M:sendChatMessage()
	local msg = self.m_inputBox:GetPropertyString("Text","")
	local packet ={
		pid = "ChatMessage",
        fromname = Me.name,
        msg = msg,
		type = self.selectChannel
	}
    self.m_inputBox:SetProperty("Text","")
    if World.gameCfg.gm and msg == '/showgm' then
		UI:openWnd("gm_board")
        return
    end
	Me:sendPacket(packet)
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
			local wnd = GUIWindowManager.instance:CloneWindow("CloneWindow-" .. type, self.m_chatContent)
			wnd:SetVisible(false)
			self.chatChannelContent[type] = wnd
			self.channelMessageItem[type] = 0
			self:root():AddChildWindow(wnd)
			for _ = 0, 3 do
				wnd:MoveBack()
			end
		end
        self:lightSubscribe("error!!!!! : win_chat chatChannel-cell-i="..i.." event : EventRadioStateChanged", radioBtn, UIEvent.EventRadioStateChanged, function(statu)
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


function M:showChatMessage( msg, fromname, type)
	type = type or "current"
	local h, msgLen = 20, string.len(msg)
	if msg == "nil" or msgLen == 0  then
		return
	end
    local strTextName = string.format("Main-Chat-Message-List-item-%d", self.count)
    self.count = self.count + 1
    local pStaticText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", strTextName)
	if fromname then
		msg = "▢FFFF0000["..fromname.."]▢FF00FF00"..msg
		pStaticText:SetText(msg)
	else
		pStaticText:SetText(msg)
	end
    pStaticText:SetTouchable(false)
    pStaticText:SetHorizontalAlignment(1)
    pStaticText:SetVerticalAlignment(0)
    pStaticText:SetTextScale(1)
    pStaticText:SetWordWrap(true)

	for _, info in ipairs({{30,150},{60,300},{90,450}}) do
		if msgLen < info[2] then
			h = info[1]
			break
		end
	end

    pStaticText:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, h })
	pStaticText:SetSelfAdaptionArea(true)

	if self.chatChannelContent[type] then
		self.chatChannelContent[type]:AddItem(pStaticText, false)
		self.channelMessageItem[type] = self.chatChannelContent[type]:getContainerWindow():GetChildCount()
	end

    if self.channelMessageItem[type] and self.channelMessageItem[type] > 50 then
		self.channelMessageItem[type] = self.channelMessageItem[type] - 1
        self:removeChat(self.chatChannelContent[type])
        return false
    end

end

function M:removeChat(m_chat)
    if m_chat and m_chat:getContainerWindow() then
        if m_chat:getContainerWindow():GetChildCount() > 0 then
            m_chat:DeleteItem(0)
        end
    end
end

return M
