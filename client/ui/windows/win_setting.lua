local settingComponentLoadDelayTime = World.cfg. settingComponentLoadDelayTime or 200
local settingComponentLoadDelayInterval = World.cfg. settingComponentLoadDelayInterval or 40

local CGame_instance = CGame.instance

function M:init()
    WinBase.init(self, "ClientSetting.json", true)
    self.isDebuging = CGame_instance:isShowPlayerControlUi()
    local isPcPlatform = CGame_instance:getPlatformId() == 1
    self.isPcPlatform = isPcPlatform
    self.settingPannels = {}

    self:initResumeAndExitGameBtns(isPcPlatform)

    local tabList = self:child("ClientSetting-TabList")
    local contentPanel = self:child("ClientSetting-ContentPanel")
    if isPcPlatform then
        tabList:SetHeight({1, -92})
        contentPanel:SetHeight({1, -132})
    end
    self:child("ClientSetting-Bottom"):SetVisible(isPcPlatform)

    local tabContainer = UIMgr:new_widget("tab", "Left", 0)
    tabContainer:invoke("BTN_SIZE", { 1, 0 }, { 0, 86 })
    tabContainer:invoke("BTN_STRETCH", "16 16 16 20")
    tabContainer:invoke("BTN_IMAGE", "set:new_gui_material.json image:menu_radio_nor", "set:new_gui_material.json image:menu_radio_pre")

    tabList:AddChildWindow(tabContainer)
    self.tabContainer = tabContainer
    self.contentPanel = contentPanel

    if not World.cfg.hideSettingPlayerList then
        self:initPlayerList()
    end
    self.initGameSettingTimer = World.LightTimer("error!!! win_setting delay init gameSettings!!!!!", 20, function() 
        self:initGameSettings() 
        self.initGameSettingTimer = nil
    end)
    if isPcPlatform then
        self:initPCKeySettings()
    end
end

function M:initResumeAndExitGameBtns(isPcPlatform)
    local resumBtn = self:child("ClientSetting-ResumeGame")
    local exitBtn = self:child("ClientSetting-ExitGame")

    if isPcPlatform then
        resumBtn:SetVisible(false)
        exitBtn:SetVisible(false)

        resumBtn = self:child("ClientSetting-ResumeBtn")
        exitBtn = self:child("ClientSetting-ExitBtn")

        local resetBtn = self:child("ClientSetting-ResetBtn")
        resetBtn:SetText(Lang:toText("gui_menu_reset_key"))
        resetBtn:SetVisible(false)
        self:lightSubscribe("error!!!!! : win_setting resumBtn event : EventButtonClick", resetBtn, UIEvent.EventButtonClick, function()
            self:resetAllKeySetting()
        end)
    end

    resumBtn:SetText(Lang:toText("gui_menu_resumegame"))
    self:lightSubscribe("error!!!!! : win_setting resumBtn event : EventButtonClick", resumBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_CHECKED_MENU, false)
    end)

    exitBtn:SetText(Lang:toText("gui_menu_exitgame"))
    self:lightSubscribe("error!!!!! : win_setting exitBtn event : EventButtonClick", exitBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_MENU_EXIT)
    end)
end

--------------------------------------------------------------------------------
-- PlayerList
function M:initPlayerList()
    local tabContainer = self.tabContainer
    local index = tabContainer:invoke("GET_CHILD_COUNT")
    tabContainer:invoke("ADD_BUTTON", "gui_menu_playerlist", function(button)
        if button:IsSelected() then
            self:showSettingPanel(index + 1)
            self:updatePlayerList(self.playerDataMap)
        end
    end, { 1.0, 1.0, 1.0 }, nil, "HT20")

    local playersPanel = GUIWindowManager.instance:LoadWindowFromJSON("MenuPlayer.json")
    playersPanel:SetVisible(false)
    self.contentPanel:AddChildWindow(playersPanel)
    self.settingPannels[index + 1] = playersPanel

    self.playersPanelList = playersPanel:child("MenuPlayer-PlayerList")
    self.playersPanelTipWidget = playersPanel:child("MenuPlayer-Tip-Message")
    self.playersPanelTipWidget:SetText("")

    self.playerItemMap = {}
    self.playerDataMap = {}
    self.playersPanelTipShowTime = 0
    self.playersPanelTipMessage = ""

    Me:sendPacket({
        pid = "QueryPlayerlist",
    }, function(data)
        local playerDataMap = self.playerDataMap
        for _, player in ipairs(data) do
            playerDataMap[player.userId] = player
            player.isFriend = (player.userId == Me.platformUserId)
            player.isFriendRequest = false
            if player.userId ~= Me.platformUserId then
                CGame_instance:getShellInterface():userChange(player.name, "", player.userId, 0, true)
            end
        end
        self:showSettingPanel(index + 1) -- TODO
        self:updatePlayerList(playerDataMap)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_setting lib event : EVENT_PLAYER_STATUS", Event.EVENT_PLAYER_STATUS, function(status, uId, uName)
        print("EVENT_PLAYER_STATUS", status, uId, uName)
        if status == 1 then -- delete
            self.playerDataMap[uId] = nil
            CGame_instance:getShellInterface():userChange("", "", uId, 0, false)
            self:updatePlayerList(self.playerDataMap)     --reset playerlist
        else   -- add
            self.playerDataMap[uId] = {name = uName, userId = uId, isFriend = (uId == Me.platformUserId), isFriendRequest = false}
            self:createPlayerListItem(uName, uId)
            CGame_instance:getShellInterface():userChange(uName, "", uId, 0, true)
        end
        self:updatePlayerItem()
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_setting lib event : EVENT_PLAYER_RECONNECT", Event.EVENT_PLAYER_RECONNECT, function()
        self:updatePlayerItem()
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_setting lib event : EVENT_FRIEND_OPERATION", Event.EVENT_FRIEND_OPERATION, function(operationType, playerPlatformId)
        self:onFriendOperationForAppHttpResult(operationType, playerPlatformId)
        self:updatePlayerItem()
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_setting lib event : EVENT_FRIEND_OPERATION_FOR_SERVER", Event.EVENT_FRIEND_OPERATION_FOR_SERVER, function(operationType, playerPlatformId)
        self:friendOpreationForServer(operationType, playerPlatformId)
        self:updatePlayerItem()
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_setting lib event : EVENT_FRIEND_OPERATION_NOTICE", Event.EVENT_FRIEND_OPERATION_NOTICE, function(operationType, playerPlatformId)
        --for the gear
        local opType = FriendManager.operationType
        if operationType == opType.AGREE then
            operationType = 3
        elseif operationType == opType.ADD_FRIEND then
            operationType = 4
        end
        if type(operationType) == "number" then
            Lib.emitEvent(Event.EVENT_FRIEND_OPERATION_FOR_SERVER, operationType, playerPlatformId)
        end
    end)
end

function M:updatePlayerList(playerlist)
    if (next(playerlist) == nil) or (not UI:isOpen(self)) then
        return
    end
    self.playersPanelList:ClearAllItem()
    self.playerItemMap = {}
    self:createPlayerListItem(Me.name, Me.platformUserId)
    for _, player in pairs(playerlist) do
        if player.userId ~= Me.platformUserId and (not self.playerItemMap[player.userId]) then
            self:createPlayerListItem(player.name, player.userId)
        end
    end
    self:updatePlayerItem()
end

function M:createPlayerListItem(name, userId)
    if not name or not userId then
        return
    end
    local playerInfos = Game.GetPlayerByUserId(userId)
    if playerInfos and playerInfos.isFollowMode then
        --跟随者不加入玩家列表
        return
    end
    if userId == Me.platformUserId then
        name = name.."(me)"
    end
    local playerItem = GUIWindowManager.instance:LoadWindowFromJSON("MenuPlayerItem.json")
    playerItem:child("MenuPlayerItem-Friend-Icon"):SetVisible(false)
    playerItem:child("MenuPlayerItem-Name"):SetText(name)
    
    local btnAddFriend = playerItem:child("MenuPlayerItem-Btn-Add-Friend")
    btnAddFriend:SetVisible(false)
    btnAddFriend:SetText(Lang:toText("gui_player_list_item_add_friend"))
    self:lightSubscribe("error!!!!! : win_setting btnAddFriend event : EventButtonClick", btnAddFriend, UIEvent.EventButtonClick, function()
        self:friendOpreation(userId, 2, btnAddFriend)
    end)
    
    local btnIgnore = playerItem:child("MenuPlayerItem-Btn-Neglect")
    btnIgnore:SetVisible(false)
    btnIgnore:SetText(Lang:toText("gui_player_list_item_add_friend_btn_ignore"))
    local messageVies = playerItem:child("MenuPlayerItem-Message")
    messageVies:SetVisible(false)
    messageVies:SetText(Lang:toText("gui_player_list_item_add_friend_msg"))
    self:lightSubscribe("error!!!!! : win_setting btnIgnore event : EventButtonClick", btnIgnore, UIEvent.EventButtonClick, function()
        self:friendOpreation(userId, 0, btnAddFriend, messageVies)
    end)
    
    local btnAgree = playerItem:child("MenuPlayerItem-Btn-Agree")
    btnAgree:SetVisible(false)
    btnAgree:SetText(Lang:toText("gui_player_list_item_add_friend_btn_agree"))
    self:lightSubscribe("error!!!!! : win_setting btnAgree event : EventButtonClick", btnAgree, UIEvent.EventButtonClick, function()
        self:friendOpreation(userId, 1, btnAddFriend)
    end)
    
    self.playersPanelList:AddItem(playerItem)
    self.playerItemMap[userId] = playerItem
end

function M:updatePlayerItem()
    if not UI:isOpen(self) then
        return
    end
    for uId, playerItem in pairs(self.playerItemMap) do
        local playerData = self.playerDataMap[uId]
        if not playerData then
            goto continue
        end
        local playerName = playerItem:child("MenuPlayerItem-Name")
        if playerData.isFriend then
            playerItem:child("MenuPlayerItem-Friend-Icon"):SetVisible(uId ~= Me.platformUserId)
            playerName:SetTextColor({0.647059, 0.913726, 0.364706})
        else
            playerName:SetTextColor(playerData.isFriendRequest and {1.0, 0.235294, 0.196078} or {0.92549, 0.870588, 0.788235})
        end
        playerItem:child("MenuPlayerItem-Message"):SetVisible((playerData.isFriendRequest) and (uId ~= Me.platformUserId))
        playerItem:child("MenuPlayerItem-Btn-Neglect"):SetVisible((playerData.isFriendRequest) and (uId ~= Me.platformUserId))
        playerItem:child("MenuPlayerItem-Btn-Agree"):SetVisible((playerData.isFriendRequest) and (uId ~= Me.platformUserId))
        local btnAddFriend = playerItem:child("MenuPlayerItem-Btn-Add-Friend")
        btnAddFriend:SetVisible((not (playerData.isFriend)) and (not (playerData.isFriendRequest)) and (uId ~= Me.platformUserId) and (not FunctionSetting:disableFriend()))
        btnAddFriend:SetEnabled(not playerData.enabled)
        btnAddFriend:SetText(Lang:toText(playerData.enabled and "gui_player_list_item_add_friend_msg_sent" or "gui_player_list_item_add_friend"))
        ::continue::
    end
    local timerCloser = self.playersPanelTipTimerCloser
    if timerCloser then
        timerCloser()
    end
    self.playersPanelTipTimerCloser = World.Timer(1, function()
        local showTime = self.playersPanelTipShowTime
        if showTime == 0 or showTime > 2000 then
            self.playersPanelTipWidget:SetText("")
        else
            self.playersPanelTipShowTime = showTime + 50
            self.playersPanelTipWidget:SetText(self.playersPanelTipMessage)
        end
    end)
end

----------------------------------------
-- Friend
function M:friendOpreation(userId, viewId, btn, message)
    local playerData = self.playerDataMap[userId]
    if playerData then
        if viewId == 0 then -- BTN_NEGLECT
            playerData.isFriendRequest = false
            btn:SetText(Lang:toText("gui_player_list_item_add_friend"))
            playerData.enabled = false
        elseif viewId == 1 then--BTN_AGREE
            CGame_instance:getShellInterface():onFriendOperation(1, userId)
        elseif viewId == 2 then
            CGame_instance:getShellInterface():onFriendOperation(2, userId)
            btn:SetText(Lang:toText("gui_player_list_item_add_friend_msg_sent"))
            playerData.enabled = true
        end
        self:updatePlayerItem()
    end
end

function M:friendOpreationForServer(operationType, userId)
    local playerData = self.playerDataMap[userId]
    if playerData then
        if operationType == 3 then -- AGREE_ADD_FRIEND
            playerData.isFriend = true
            playerData.isFriendRequest = false
        elseif operationType == 4 then--REQUEST_ADD_FRIEND
            playerData.isFriendRequest = true
            Lib.emitEvent(Event.EVENT_SHOW_RED_POINT)
        end
    end
end

function M:onFriendOperationForAppHttpResult(operationType, userId)
    local playerData = self.playerDataMap[userId]
    if not playerData then
        return
    end
    if operationType == 1 then  --NO_FRIEND
        playerData.isFriend = false
    elseif operationType == 2 then     --IS_FRIEND
        playerData.isFriend = true
        playerData.isFriendRequest = false
    elseif operationType == 3 then    --AGREE_ADD_FRIEND
        Me:sendPacket({
            pid = "SendFriendOperation",
            operationType = operationType,
            userId = userId
        }, function() end)
        playerData.isFriend = true
        playerData.isFriendRequest = false
    elseif operationType == 4 then    --REQUEST_ADD_FRIEND
        Me:sendPacket({
            pid = "SendFriendOperation",
            operationType = operationType,
            userId = userId
        }, function() end)
    elseif operationType == 10000 then --REQUEST_ADD_FRIEND_FAILURE
        self.playersPanelTipShowTime = 1
        self.playersPanelTipMessage = Lang:toText("gui_player_list_item_add_friend_msg_send_failure")
        local playerItem = self.playerItemMap[userId]
        if playerItem then
            playerItem:child("MenuPlayerItem-Btn-Add-Friend"):SetText(Lang:toText("gui_player_list_item_add_friend"))
            playerData.enabled = false
        end
    elseif operationType == 10001 then --AGREE_ADD_FRIEND_FAILURE
        self.playersPanelTipShowTime = 1
        self.playersPanelTipMessage = Lang:toText("gui_player_list_item_add_friend_msg_agree_failure")
    end
end

--------------------------------------------------------------------------------
-- GameSetting
function M:initGameSettings()
    local tabContainer = self.tabContainer
    local index = tabContainer:invoke("GET_CHILD_COUNT")
    tabContainer:invoke("ADD_BUTTON", "gui_menu_setting", function(button)
        if button:IsSelected() then
            self:showSettingPanel(index + 1)
        end
    end, { 1.0, 1.0, 1.0 }, nil, "HT20")

    local gameSettingPanel = GUIWindowManager.instance:LoadWindowFromJSON("GameSetting.json")
    gameSettingPanel:SetVisible(false)
    self.contentPanel:AddChildWindow(gameSettingPanel)
    self.settingPannels[index + 1] = gameSettingPanel

    self.gameSettingGrid = gameSettingPanel:child("GameSetting-grid")
    self.gameSettingGrid:InitConfig(2, 0, World.cfg.gameSettingUIRowSize or 2)
    self.gameSettingGridItemTimerArray = {}

    local defaultSettings = Clientsetting.getSetting()

    local pSett = World.cfg.personalSettingUI or {}
--    if pSett.luminance then
--        gameSettingPanel:child("GameSetting-Content-Function-Luminance-Name"):SetText(Lang:toText("gui.setting.luminance"))
--        self:createGameSettingSilderItem("gui.setting.luminance", defaultSettings.luminance, Clientsetting.refreshLuminance)
--    end

    if pSett.volume == nil or pSett.volume then
        gameSettingPanel:child("GameSetting-Content-Function-Volume-Name"):SetText(Lang:toText("gui.setting.volume"))
        self:createGameSettingSilderItem("gui.setting.volume", defaultSettings.volume, Clientsetting.refreshVolume)
    end

    if pSett.horizon == nil or pSett.horizon then
        gameSettingPanel:child("GameSetting-Content-Function-Horizon-Name"):SetText(Lang:toText("gui.setting.horizon"))
        -- self:createGameSettingSilderItem("gui.setting.horizon", defaultSettings.horizon, Clientsetting.refreshHorizon)
    end
    
    if pSett.sensitive == nil or pSett.sensitive then
        local minSize, maxSize =  0.2, 1.2
        local progress = (defaultSettings.camera_sensitive - minSize) / (maxSize - minSize)
        gameSettingPanel:child("GameSetting-Content-Function-Camera-Sensitive-Name"):SetText(Lang:toText("gui.setting.camera.sensitive"))
        self:createGameSettingSilderItem("gui.setting.camera.sensitive", progress, Clientsetting.refreshCameraSensitive)
    end
    
    if pSett.guiSize == nil or pSett.guiSize then
        gameSettingPanel:child("GameSetting-Content-Function-Gui-Size-Name"):SetText(Lang:toText("gui.setting.gui.size"))
        local guiMinSize, guiMaxSize = 0.5, 1
        local fGuiSize = math.min(guiMaxSize, math.max(guiMinSize, defaultSettings.gui_size))
        local progressGui = (fGuiSize - guiMinSize) / (guiMaxSize - guiMinSize)
        self:createGameSettingSilderItem("gui.setting.gui.size", progressGui, function(value)
            Lib.emitEvent(Event.EVENT_SET_GUI_SIZE)
            Clientsetting.refreshGuiSize(value)
        end)
    end
    
    if pSett.controlMode == nil or pSett.controlMode then
        gameSettingPanel:child("GameSetting-Content-Function-Toggle-Pole-Name"):SetText(Lang:toText("gui.setting.pole.toggle"))
        self:createGameSettingCheckBoxItem("gui.setting.pole.toggle", defaultSettings.usePole > 0, function(isChecked)
            Clientsetting.refreshPoleControlState(isChecked and 1.0 or 0)
            Lib.emitEvent(Event.EVENT_SWITCH_MOVE_CONTROL, isChecked and 1.0 or 0)
        end)
    end

    if pSett.jumpSneakState == nil or pSett.jumpSneakState then
        gameSettingPanel:child("GameSetting-Content-Function-Toggle-Jump-Sneak-Pos-Name"):SetText(Lang:toText("gui.setting.jump.sneak.toggle"))
        self:createGameSettingCheckBoxItem("gui.setting.jump.sneak.toggle", defaultSettings.isJumpDefault > 0, function(isChecked)
            Clientsetting.refreshJumpSneakState(isChecked and 1.0 or 0)
            Lib.emitEvent(Event.EVENT_CHECKBOX_CHANGE, isChecked)
        end)
    end

    if pSett.imageQuality == nil or pSett.imageQuality then
        self:createGameQualitySettingItem("gui.setting.gui.quality", defaultSettings.saveQualityLeve or 1)
    end

    gameSettingPanel:child("GameSetting-Content-Function-Real-Time-Name"):SetText(Lang:toText("gui.setting.gui.real.time"))
    gameSettingPanel:child("GameSetting-Content-Function-Screen-Softness-Name"):SetText(Lang:toText("gui.setting.gui.screen.soft"))
    gameSettingPanel:child("GameSetting-Content-Function-Square-Normal-Name"):SetText(Lang:toText("gui.setting.gui.squre.normal"))
    gameSettingPanel:child("GameSetting-Content-Function-Role-Highlight-Name"):SetText(Lang:toText("gui.setting.gui.character.highlight"))
    gameSettingPanel:child("GameSetting-Content-Function-Diffusion-Strength-Name"):SetText(Lang:toText("gui.setting.gui.diffusion.strength"))
    gameSettingPanel:child("GameSetting-Content-Function-Samp-Step-Name"):SetText(Lang:toText("gui.setting.gui.samp.step"))
end

local function createGameSettingItem(nameKey, isSlider)
    local settingItem = GUIWindowManager.instance:LoadWindowFromJSON("GameSettingItem.json")
    settingItem:child("GameSettingItem-Name"):SetText(Lang:toText(nameKey))
    settingItem:child("GameSettingItem-Slider"):SetVisible(isSlider)
    settingItem:child("GameSettingItem-CheckBox"):SetVisible(not isSlider)
    return settingItem
end

function M:fetchGameSettingSilderItem(nameKey, defaltVal, handler)
    local settingItem = createGameSettingItem(nameKey, true)
    local slider = settingItem:child("GameSettingItem-Slider")
    slider:SetProgress(defaltVal)
    handler(slider:GetProgress())

    local function update()
        local progress = slider:GetProgress()
        if progress > 0.9 then
            progress = 1.0
        elseif progress < 0.1 then
            progress = 0
        end
        handler(progress)
    end
    self:lightSubscribe("error!!!!! : win_setting nameKey: ".. nameKey .. " slider event : EventWindowTouchDown", slider, UIEvent.EventWindowTouchDown, update)
    self:lightSubscribe("error!!!!! : win_setting nameKey: ".. nameKey .. " slider event : EventWindowTouchMove", slider, UIEvent.EventWindowTouchMove, update)
    self:lightSubscribe("error!!!!! : win_setting nameKey: ".. nameKey .. " slider event : EventWindowTouchUp", slider, UIEvent.EventWindowTouchUp, update)
    self:lightSubscribe("error!!!!! : win_setting nameKey: ".. nameKey .. " slider event : EventMotionRelease", slider, UIEvent.EventMotionRelease, update)

    self.gameSettingGrid:AddItem(settingItem)
end

function M:createGameSettingSilderItem(nameKey, defaltVal, handler)
    local gameSettingGridItemTimerArray = self.gameSettingGridItemTimerArray
    local index = #gameSettingGridItemTimerArray + 1
    local func = function()
        gameSettingGridItemTimerArray[index] = {}
        self:fetchGameSettingSilderItem(nameKey, defaltVal, handler)
    end
    gameSettingGridItemTimerArray[index] = {
        timer = World.LightTimer("createGameSettingSilderItem delay create component : ".. nameKey, settingComponentLoadDelayTime + #gameSettingGridItemTimerArray * settingComponentLoadDelayInterval, func),
        func = func
    }
end

function M:fetchGameSettingCheckBoxItem(nameKey, defaltVal, handler)
    local settingItem = createGameSettingItem(nameKey, false)
    local checkBox = settingItem:child("GameSettingItem-CheckBox")
    checkBox:SetChecked(defaltVal)
    self:lightSubscribe("error!!!!! : win_setting checkBox event : EventCheckStateChanged", checkBox, UIEvent.EventCheckStateChanged, function()
        handler(checkBox:GetChecked())
    end)

    self.gameSettingGrid:AddItem(settingItem)
end

function M:createGameSettingCheckBoxItem(nameKey, defaltVal, handler)
    local gameSettingGridItemTimerArray = self.gameSettingGridItemTimerArray
    local index = #gameSettingGridItemTimerArray + 1
    local func = function()
        gameSettingGridItemTimerArray[index] = {}
        self:fetchGameSettingCheckBoxItem(nameKey, defaltVal, handler)
    end
    gameSettingGridItemTimerArray[index] = {
        timer = World.LightTimer("createGameSettingCheckBoxItem delay create component : ".. nameKey, settingComponentLoadDelayTime + #gameSettingGridItemTimerArray * settingComponentLoadDelayInterval, func),
        func = func
    }
end

function M:fetchGameQualitySettingItem(nameKey, defaltVal)
    local settingItem = createGameSettingItem(nameKey, true)


    settingItem:child("GameSettingItem-Low"):SetText(Lang:toText("gui.setting.gui.quality.low"))
    --settingItem:child("GameSettingItem-Centre"):SetText(Lang:toText("gui.setting.gui.quality.centre"))
    settingItem:child("GameSettingItem-High"):SetText(Lang:toText("gui.setting.gui.quality.high"))
    settingItem:child("GameSettingItem-Low"):SetVisible(true)
    --settingItem:child("GameSettingItem-Centre"):SetVisible(true)
    settingItem:child("GameSettingItem-High"):SetVisible(true)

    local quality = settingItem:child("GameSettingItem-Slider")

    local function handleQualityLevel(level)
        if 1 <= level and level <= 3 then
            quality:SetProgress(0.5 * (level - 1))
            self:gameSettingSetQualityLevel(level)
        end
    end
    handleQualityLevel(defaltVal)

    local function handleQualityProgress()
        local value = quality:GetProgress()
        if 0 <= value and value <= 1 then
            value = math.max(1, math.ceil(value * 3))
            handleQualityLevel(value)
            Lib.emitEvent(Event.EVENT_SETTING_TO_TOOLBAR_QUALITY, value)
        end
    end
    self:lightSubscribe("error!!!!! : win_setting quality event : EventWindowTouchMove", quality, UIEvent.EventWindowTouchMove, handleQualityProgress)
    self:lightSubscribe("error!!!!! : win_setting quality event : EventWindowTouchUp", quality, UIEvent.EventWindowTouchUp, handleQualityProgress)
    self:lightSubscribe("error!!!!! : win_setting quality event : EventMotionRelease", quality, UIEvent.EventMotionRelease, handleQualityProgress)

    Lib.lightSubscribeEvent("error!!!!! : win_setting lib event : EVENT_TOOLBAR_TO_SETTING_QUALITY", Event.EVENT_TOOLBAR_TO_SETTING_QUALITY, handleQualityLevel)

    self.gameSettingGrid:AddItem(settingItem)
end

function M:createGameQualitySettingItem(nameKey, defaltVal)
    local gameSettingGridItemTimerArray = self.gameSettingGridItemTimerArray
    local index = #gameSettingGridItemTimerArray + 1
    local func = function()
        gameSettingGridItemTimerArray[index] = {}
        self:fetchGameQualitySettingItem(nameKey, defaltVal)
    end
    gameSettingGridItemTimerArray[index] = {
        timer = World.LightTimer("createGameQualitySettingItem delay create component : ".. nameKey, settingComponentLoadDelayTime + #gameSettingGridItemTimerArray * settingComponentLoadDelayInterval, func),
        func = func
    }
end

function M:gameSettingSetQualityLevel(level)
    -----1  2 
    local values = {
        {0, 0},
        {1, 1},
        {2, 2},
    }
    local tab = values[level]       
	Blockman.instance.gameSettings:setCurQualityLevel(tab[1])
    Clientsetting.refreshSaveQualityLeve(level)
end

--------------------------------------------------------------------------------
-- PCKeySetting
function M:initPCKeySettings()
    if not self.isPcPlatform then
        return
    end
    local tabContainer = self.tabContainer
    local index = tabContainer:invoke("GET_CHILD_COUNT")
    tabContainer:invoke("ADD_BUTTON", "gui_menu_key_setting", function(button)
        if button:IsSelected() then
            self:showSettingPanel(index + 1)
            local resetKeySettingBtn = self:child("ClientSetting-ResetBtn")
            if resetKeySettingBtn then
                resetKeySettingBtn:SetVisible(true)
            end
        end
    end, { 1.0, 1.0, 1.0 }, nil, "HT20")

    local keySettingPanel = GUIWindowManager.instance:LoadWindowFromJSON("MenuKeySetting.json")
    keySettingPanel:SetVisible(false)
    self.contentPanel:AddChildWindow(keySettingPanel)
    self.settingPannels[index + 1] = keySettingPanel

    self.keySettingItemList = keySettingPanel:child("MenuKeySetting-List")
    self.keySettingTipWidget = keySettingPanel:child("MenuKeySetting-Tip-Message")
    self.keySettingTipWidget:SetVisible(true)
    self.keySettingTipWidget:SetText("")
    self.keySettingTipMessage = ""
    self.keySettingTipShowTime = 0.0
    self.needShowKeySettingTip = false
    self.keySettingTipColor = ""
    self.keySettingMap = {}

    for _, itemData in pairs(Clientsetting.getKeySettingDefault()) do
        local isTitle = itemData.IsTitle > 0
        local item = GUIWindowManager.instance:LoadWindowFromJSON("MenuKeySettingItem.json")
        item:child("MenuKeySettingItem-Bg"):SetVisible(not isTitle)
        item:child("MenuKeySettingItem-Title"):SetVisible(isTitle)
        
        local opText = item:child("MenuKeySettingItem-OpText")
        opText:SetVisible(not isTitle)
        
        local titleText = item:child("MenuKeySettingItem-TitleText")
        titleText:SetVisible(isTitle)
        
        local editor = item:child("MenuKeySettingItem-Edit")
        editor:SetVisible(not isTitle)
        --editor:SetTextColor({1, 1, 1})
        --editor:SetTextBorder(true)
        if isTitle then
            titleText:SetText(Lang:toText(itemData.Language))
            editor:setData("DefaultKey", 0)
        else
            opText:SetText(Lang:toText(itemData.Language))
            editor:SetTextVertAlign(1)
            editor:SetTextHorzAlign(1)
            editor:SetText(Clientsetting.vkcode2String(Clientsetting.getCustomKeySettingKeyCode(itemData.KeyCode)))
            editor:setData("DefaultKey", itemData.KeyCode)
        end
        
        local resetButton = item:child("MenuKeySettingItem-Reset")
        resetButton:SetText(Lang:toText("gui_setting_item_reset_text"))
        resetButton:SetVisible(not isTitle)
        self:lightSubscribe("error!!!!! : win_setting MenuKeySettingItem-Reset event : EventButtonClick", resetButton, UIEvent.EventButtonClick, function()
            self:resetKeySettingItem(editor)
            Clientsetting.saveCustomKeySetting()
        end)
        self:lightSubscribe("error!!!!! : win_setting MenuKeySettingItem-Edit event : EventWindowTouchDown", editor, UIEvent.EventWindowTouchDown, function()
            editor:SetTextWithNoTextChange(Lang:toText("gui_setting_start_set_text"))
        end)
        self:lightSubscribe("error!!!!! : win_setting MenuKeySettingItem-Edit event : EventWindowTextChanged", editor, UIEvent.EventWindowTextChanged, function()
            self:onKeySettingItemChanged(editor, itemData.KeyCode)
        end)
        self.keySettingItemList:AddItem(item)
        if itemData.KeyCode then
            self.keySettingMap[itemData.KeyCode] = item
        end
    end
end

function M:resetAllKeySetting()
    for _, itemData in pairs(self.keySettingMap) do
        local editor = itemData:child("MenuKeySettingItem-Edit")
        editor:SetText(Clientsetting.vkcode2String(editor:data("DefaultKey")))
    end
    Clientsetting.saveCustomKeySettingToGame()
    Clientsetting.saveCustomKeySetting()
    local tipColor = "0 1 0 1"
    self:setKeySettingTipMessage(Lang:toText("gui_setting_key_reset_all_suc"), tipColor)
    World.Timer(1, self.showKeySettingPanel, self, 50, self.keySettingTipMessage, 1500)
end

function M:resetKeySettingItem(editor)
    local defaultKeyCode = editor:data("DefaultKey")
    Clientsetting.setCustomKeySettingKeyCode(defaultKeyCode, defaultKeyCode)
    editor:SetText(Clientsetting.vkcode2String(defaultKeyCode))
    if Clientsetting.getCustomKeySettingKeyCode(defaultKeyCode) then
        Blockman.instance.gameSettings:setKeySettingMapByKeyCode(defaultKeyCode, defaultKeyCode) --confilt
        local tipColor = "0 1 0 1"
        self:setKeySettingTipMessage(Lang:toText("gui_setting_key_reset_suc"), tipColor)
        World.Timer(1, self.showKeySettingPanel, self, 50, self.keySettingTipMessage, 1500)
        for key, custormKeyItem in pairs(Clientsetting:getCustomKeySetting()) do
            if custormKeyItem == defaultKeyCode and key ~= defaultKeyCode then
                self:resetKeySettingItem(self.keySettingMap[key]:child("MenuKeySettingItem-Edit"))
            end
        end
    end
end

function M:onKeySettingItemChanged(editor, defalutKeyCode)
    local curText = string.upper(editor:GetText())
    if curText == "`" then
        curText = "~"
    end
    local msg = ""
    local tipColor = "1 0 0 1"
    local customKeyCode = Clientsetting.getCustomKeySettingKeyCode(defalutKeyCode)
    if Clientsetting.isInvaildString(curText) then
        local keyCode = Clientsetting.string2vkcode(curText)
        if keyCode == customKeyCode then
            editor:SetText(Clientsetting.vkcode2String(keyCode))
            return
        elseif customKeyCode then
            local isRepeat = false
            for k, v in pairs(Clientsetting:getCustomKeySetting()) do
                if v == keyCode then
                    isRepeat = true
                    break
                end
            end
            if not isRepeat then
                Clientsetting.setCustomKeySettingKeyCode(defalutKeyCode, keyCode)
                editor:SetText(Clientsetting.vkcode2String(keyCode))
                Clientsetting.saveCustomKeySetting()
                msg = Lang:toText("gui_setting_key_change_suc")
                tipColor = "0 1 0 1"
                Blockman.instance.gameSettings:setKeySettingMapByKeyCode(defalutKeyCode, keyCode)
            else
                msg = Lang:toText("gui_setting_key_repeat")
                editor:SetText(Clientsetting.vkcode2String(customKeyCode))
            end
        end
    else
        editor:SetText(Clientsetting.vkcode2String(customKeyCode))
        if curText ~= Lang:toText("gui_setting_key_invalid") then
            msg = Lang:toText("gui_setting_key_repeat")
        end
    end
    self:setKeySettingTipMessage(msg, tipColor)
    World.Timer(1, self.showKeySettingPanel, self, 50, self.keySettingTipMessage, 1500)
end

function M:setKeySettingTipMessage(message, color)
    self.keySettingTipMessage = message
    self.needShowKeySettingTip = true
    self.keySettingItemList:SetTouchable(false)
    self.keySettingTipColor = color
end

function M:showKeySettingPanel(nTimeElapse, msg, tipShwoTime)
    if self.needShowKeySettingTip and self.keySettingTipShowTime < tipShwoTime then
        self.keySettingTipShowTime = self.keySettingTipShowTime + nTimeElapse
    else
        self.needShowKeySettingTip = false
        self.keySettingTipShowTime = 0.0
        self.keySettingTipWidget:SetText("")
        self.keySettingItemList:SetTouchable(true)
        return false
    end
    if self.needShowKeySettingTip then
        self.keySettingTipWidget:SetProperty("TextColor", self.keySettingTipColor)
        self.keySettingTipWidget:SetText(msg)
    end
    return true
end

--------------------------------------------------------------------------------

function M:showSettingPanel(index)
    if not UI:isOpen(self) then
        return
    end
    local tabContainer = self.tabContainer
    if 0 < index and index <= tabContainer:invoke("GET_CHILD_COUNT") then
        tabContainer:invoke("SELECTED", index - 1)
    end
    for i, panel in pairs(self.settingPannels) do
        panel:SetVisible(i == index)
    end
    local resetKeySettingBtn = self:child("ClientSetting-ResetBtn")
    if resetKeySettingBtn then
        resetKeySettingBtn:SetVisible(false)
    end
end

function M:onClose()
    local closer = self.playersPanelTipTimerCloser
    if closer then
        closer()
        self.playersPanelTipTimerCloser = nil
    end
end

function M:onOpen()
    if self.initGameSettingTimer then
        self.initGameSettingTimer()
        self.initGameSettingTimer = nil
        self:initGameSettings()
    end
    for _, funcMap in ipairs(self.gameSettingGridItemTimerArray) do
        if funcMap.func then
            funcMap.func()
        end
        if funcMap.timer then
            funcMap.timer()
        end
    end
    self:showSettingPanel(1)
    if self.playerDataMap then
        self:updatePlayerList(self.playerDataMap)
    end
end

return M