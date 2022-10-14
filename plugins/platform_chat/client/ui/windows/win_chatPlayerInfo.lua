local chatSetting = World.cfg.chatSetting or {}
local infoSetting = chatSetting.infoSetting or {}

--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")
--- @type PlayerSpInfoManager
local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")

local ButtonCfg = {
    {
        name = "ui.chat.ignore",
        image = "set:chat.json image:btn_9_adddot",
        checkEvent = {
            isClient = true,
            name = "EVENT_CHECK_IGNORE"
        },
        clickEvent = {
            isClient = true,
            name = "EVENT_SET_IGNORE"
        }
    },
    {
        name = "ui.chat.private",
        image = "set:chat.json image:btn_9_adddot",
        clickEvent = {
            isClient = true,
            name = "EVENT_OPEN_PRIVATE_CHAT"
        }
    },
    {
        name = "ui.chat.invite",
        image = "set:chat.json image:btn_9_adddot",
        clickEvent = {
            isClient = true,
            name = "EVENT_INVITE_GAME"
        }
    },
}

function M:init()
    WinBase.init(self, "ChatPlayerInfo.json",false)
    self:initWnd()
    self:initEvent()
end

function M:initWnd()
    self.buttonsCfg = chatSetting.infoButtons or ButtonCfg

    self.lytInfo = self:child("ChatPlayerInfo-Bg")
    self.lytClose = self:child("ChatPlayerInfo-Close")

    self.imgHead = self:child("ChatPlayerInfo-Head")
    self.imgHeadFrame = self:child("ChatPlayerInfo-Head-Frame")
    self.txtLv = self:child("ChatPlayerInfo-Lv")
    self.imgSex = self:child("ChatPlayerInfo-Sex")
    self.txtLv:SetVisible(false)

    self.imgTopBg = self:child("ChatPlayerInfo-Info-Bg")

    self.imgTags = self:child("ChatPlayerInfo-Tags")
    self.imgTags:SetVisible(false)
    self.lytTagPanel= self:child("ChatPlayerInfo-TagPanel")
    self.tagGridView = UIMgr:new_widget("grid_view", self.lytTagPanel)
    self.tagGridView:SetAutoColumnCount(false)
    self.tagGridView:InitConfig(10, 5, 3)
    self.tagAdapter = UIMgr:new_adapter("common",100,33, "chatTagItem", "ChatTagItem.json")
    self.tagGridView:invoke("setAdapter", self.tagAdapter)

    --额外信息栏
    self.imgEmblem = self:child("ChatPlayerInfo-Emblem")
    --1号栏位
    self.imgTopInfo1Bg = self:child("ChatPlayerInfo-Title-Bg")
    --1号栏位标题
    self.txtTopInfo1Title = self:child("ChatPlayerInfo-Title")
    --1号栏位图标
    self.imgTopInfo1Icon = self:child("ChatPlayerInfo-heartIcon")
    --1号栏位值
    self.txtTopInfo1Val = self:child("ChatPlayerInfo-intimacyValue")

    --2号栏位
    self.imgTopInfo2Bg = self:child("ChatPlayerInfo-relation-Bg")
    --2号栏位标题
    self.txtTopInfo2Title = self:child("ChatPlayerInfo-Title-relation")
    --2号栏位图标
    --self.imgTopInfo1Icon = self:child("ChatPlayerInfo-heartIcon")
    --2号栏位值
    self.txtTopInfo2Val = self:child("ChatPlayerInfo-relationVal")

    self.txtName = self:child("ChatPlayerInfo-Name")
    self.txtId = self:child("ChatPlayerInfo-Id")

    self.lytParam1 = self:child("ChatPlayerInfo-param1")
    self.imgParam1 = self:child("ChatPlayerInfo-param1Icon")
    self.txtParam1 = self:child("ChatPlayerInfo-param1Txt")

    self.lytParam2 = self:child("ChatPlayerInfo-param2")
    self.imgParam2 = self:child("ChatPlayerInfo-param2Icon")
    self.txtParam2 = self:child("ChatPlayerInfo-param2Txt")

    --self.btnAddFriend = self:child("ChatPlayerInfo-addFriend")
    --self.btnDeleteFriend = self:child("ChatPlayerInfo-deleteFriend")

    self.lytButton = self:child("ChatPlayerInfo-Buttons")

    self:child("ChatPlayerInfo-playerTitle"):SetText(Lang:toText("ui.chat.playerInfo"))

    self.imgEmblem:SetVisible(false)
    self.lytParam1:SetVisible(false)
    self.lytParam2:SetVisible(false)
    self.txtId:SetVisible(true)

    self.buttons = {}
    self.addedFriendList = {}
    self.lineHeight = 155
    self.buttonsStartY = 10
    self.buttonsHeight = 0
    self.tagsStartY = 10
    self:initButtons()

    if World.cfg.chatSetting and World.cfg.chatSetting.chatLevel then
        self:root():SetLevel(World.cfg.chatSetting.chatLevel)
    end
end

function M:initButtons()
    if self.buttonsCfg then
        local btnsCont = (#self.buttonsCfg)+1
        self.buttonsHeight = btnsCont > 2 and math.ceil(btnsCont / 2)*59 or 59
        self.lytButton:SetArea({0,0},{0,self.buttonsStartY},{1,0},{0,self.buttonsHeight})
        self.lineHeight = self.lineHeight+self.buttonsHeight
        self.lytInfo:SetArea({0,0},{0,0},{0,371},{0,self.lineHeight})
        local row = btnsCont > 2 and 2 or 1
        local rowInterval = row > 1 and 50 or 0
        local line = btnsCont > 4 and math.ceil(btnsCont / 2) or 2
        local height = (self.lytButton:GetPixelSize().y - 16) / line
        local width = (self.lytButton:GetPixelSize().x - rowInterval) / row
        for i = 1, btnsCont do
            local cfg = self.buttonsCfg[i]
            local btn
            if i==btnsCont then
                btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "btnFriend")
            else
                btn = GUIWindowManager.instance:CreateGUIWindow1("Button", cfg.name)
            end
            self.lytButton:AddChildWindow(btn)
            local _l = btnsCont > 2 and math.ceil(i / 2) or i
            local _r = btnsCont > 2 and 2 - i % 2 or 1
            btn:SetArea({ 0, 20+(_r - 1) * (width + 8)}, { 0, (_l - 1) * (height + 0)}, { 0, width }, { 0, height })
            btn:SetNormalImage(cfg and cfg.image or "set:chat.json image:btn_9_green")
            btn:SetPushedImage(cfg and cfg.image or "set:chat.json image:btn_9_green")
            btn:SetProperty("StretchType", "NineGrid")
            btn:SetProperty("StretchOffset", "25 25 10 10")
            self:updateBtnShowName(btn, cfg and cfg.name or "")
            btn:SetProperty("Font", cfg and cfg.fontSize or "HT16")
            btn:SetProperty("TextBorder", "false")
            --btn:SetProperty("TextBorderColor", cfg.borderColor or {71/255, 105/255, 17/255, 1})
            if i==btnsCont then
                self.btnFriend = btn

            else
                self.buttons[i] = btn
            end

        end
    end
end

function M:initEvent()
    ---- 测试删除好友
    --self:subscribe(self.btnDeleteFriend, UIEvent.EventButtonClick, function()
    --    AsyncProcess.FriendOperation(FriendManager.operationType.DELETE, self.curSelPlayerUserId)
    --    UI:closeWnd(self)
    --end)

    self:lightSubscribe("error!!!!! script_client win_chatPlayerInfo lytClose event : EventButtonClick", self.lytClose, UIEvent.EventWindowClick, function()
        UI:closeWnd(self)
    end)

    if self.buttonsCfg then
        for i = 1, #self.buttonsCfg do
            local cfg = self.buttonsCfg[i]
            if cfg.clickEvent then
                self:lightSubscribe("error!!!!! script_client win_chatPlayerInfo buttons event : EventButtonClick", self.buttons[i], UIEvent.EventButtonClick, function()
                    Lib.logInfo("chat player info button:",cfg.clickEvent.name)
                    if cfg.clickEvent.isClient then
                        Lib.emitEvent(Event[cfg.clickEvent.name], self.curSelPlayerUserId)
                    else
                        Me:sendPacket({
                            pid = cfg.clickEvent.name,
                            object = self.curSelPlayerUserId
                        })
                    end
                    UI:closeWnd(self)
                end)
            end
        end
    end

    self:subscribe(self.btnFriend, UIEvent.EventButtonClick, function()
        if not self.curSelPlayerUserId then
            return
        end
        if self.curPlayerIsFriend == nil then
            return
        end
        if self.curPlayerIsFriend then
            UIChatManage:doDeleteFriendOperate(self.curSelPlayerUserId, self.curSelPlayerName)
        else
            AsyncProcess.FriendOperation(FriendManager.operationType.ADD_FRIEND, self.curSelPlayerUserId)
        end
        UI:closeWnd(self)
    end)
end

--注册event事件监听，注意这里的事件是show的时候注册，close的时候注销的，常驻事件可在initEvent里面注册
function M:subscribeEvent()
    self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_CHECK_ONE_IS_GAME_PLAYER, function()
        if not self.curSelPlayerUserId then
            return
        end
        self.curPlayerIsTheGamePlayer = Me:checkOneIsTheGamePlayer(self.curSelPlayerUserId)
        self:updateGameSpecialBtnTouch()
    end)
end

function M:updateBtnEvent()
    if self.buttonsCfg then
        for i = 1, #self.buttonsCfg do
            local cfg = self.buttonsCfg[i]
            if cfg.checkEvent then
                if cfg.checkEvent.isClient then
                    Lib.emitEvent(Event[cfg.checkEvent.name], self.curSelPlayerUserId, self.curSelPlayerId, self.curSelPlayerName, self.buttons[i])
                else
                    Me:sendPacket({
                        pid = cfg.checkEvent.name,
                        object = self.curSelPlayerUserId
                    })
                end
            end
        end
    end
end
local reTagsSize = false
function M:initTags(tagData)
    self.imgTags:SetVisible(true)
    if not reTagsSize then
        reTagsSize = true
        self.lineHeight = self.lineHeight+163
        self.buttonsStartY = self.buttonsStartY+163
        self.lytButton:SetArea({0,0},{0,self.buttonsStartY},{1,0},{0,self.buttonsHeight})
        self.imgTags:SetYPosition({0,self.tagsStartY})
        self.lytInfo:SetArea({0,0},{0,0},{0,371},{0,self.lineHeight})
    end

    self.tagAdapter:clearItems()
    self.tagGridView:ResetPos()
    for _, data in pairs(tagData) do
        self.tagAdapter:addItem(tonumber(data))
    end
end
local reTopSize = false
---@param data TopData
function M:initPlayerTopInfo(data)
    self.imgEmblem:SetVisible(true)
    self.imgTopInfo1Bg:SetVisible(false)
    self.imgTopInfo2Bg:SetVisible(false)
    if not reTopSize then
        reTopSize = true
        self.lineHeight = self.lineHeight+80
        self.buttonsStartY = self.buttonsStartY+80
        self.tagsStartY = self.tagsStartY+80
        self.lytButton:SetArea({0,0},{0,self.buttonsStartY},{1,0},{0,self.buttonsHeight})
        self.imgTags:SetYPosition({0,self.tagsStartY})
        self.lytInfo:SetArea({0,0},{0,0},{0,371},{0,self.lineHeight})
    end

    if data.title1 then
        self.imgTopInfo1Bg:SetVisible(true)
        self.txtTopInfo1Title:SetText(Lang:toText(data.title1))
        self.imgTopInfo1Icon:SetImage(data.icon1)
        self.txtTopInfo1Val:SetText(Lang:toText(data.txt1))
    end
    if data.title2 then
        self.imgTopInfo1Bg:SetArea({0,11},{0,7},{0,171},{0,61})
        self.imgTopInfo2Bg:SetVisible(true)
        self.txtTopInfo2Title:SetText(Lang:toText(data.title2))
        --self.imgTopInfo2Icon:SetImage(icon2)
        self.txtTopInfo2Val:SetText(Lang:toText(data.txt2))
    else
        self.imgTopInfo1Bg:SetArea({0,11},{0,7},{0,608},{0,61})
    end
end
---@param data SpData
function M:initPlayerSpInfo(data)
    self.lytParam1:SetVisible(false)
    self.lytParam2:SetVisible(false)
    self.txtId:SetVisible(true)
    if data.txt1 then
        self.txtId:SetVisible(false)
        self.lytParam1:SetVisible(true)
        self.txtParam1:SetText(Lang:toText(data.txt1))
        if data.icon1 then
            self.imgParam1:SetVisible(true)
            self.imgParam1:SetImage(data.icon1)
            self.txtParam1:SetArea({0,30},{0,0},{1,-30},{1,0})
        else
            self.imgParam1:SetVisible(false)
            self.txtParam1:SetArea({0,0},{0,0},{1,0},{1,0})
        end
    end
    if data.txt2 then
        self.txtId:SetVisible(false)
        self.lytParam2:SetVisible(true)
        self.txtParam2:SetText(Lang:toText(data.txt2))
        if data.icon2 then
            self.imgParam2:SetVisible(true)
            self.imgParam2:SetImage(data.icon2)
            self.txtParam2:SetArea({0,30},{0,0},{1,-30},{1,0})
        else
            self.imgParam2:SetVisible(false)
            self.txtParam2:SetArea({0,0},{0,0},{1,0},{1,0})
        end
    end

    self.txtLv:SetVisible(false)
    if data.txt3 and data.txt3 > 0 then
        self.txtLv:SetVisible(true)
        self.txtLv:SetText("Lv." .. data.txt3)
        self.curSelPlayerLevel = tonumber(data.txt3)
    end
    self:updateGameSpecialBtnTouch()
end

-- 获得某个配置按钮
function M:getButtonByName(name)
    for i = 1, #self.buttonsCfg do
        local cfg = self.buttonsCfg[i]
        if cfg.name == name then
            return self.buttons[i]
        end
    end
    return nil
end

-- 更新按钮点击状态
function M:updateBtnTouchState(btnNode, btnName, state, targetLevel)
    if not btnNode then
        return
    end
    if state then -- 设置为可点击的，判断一下功能是否开启了
        btnNode:SetEnabled(Me:checkChatPlayerBtnIsOpen(btnName, targetLevel))
    else
        btnNode:SetEnabled(false)
    end
end

-- 更新按钮名
function M:updateBtnShowName(btnNode, btnName, userId)
    btnNode:SetText(Me:getPlayerInfoBtnTxtName(btnName, userId))
end

function M:isGameSpecialBtn(btn_name)
    local btnList = Me:getPlayerInfoGameBtn()
    for _, btnName in pairs(btnList) do
        if btnName == btn_name then
            return true
        end
    end
    return false
end

-- 更新特殊按钮点击状态
function M:updateGameSpecialBtnTouch()
    local btnList = Me:getPlayerInfoGameBtn()
    for _, btnName in pairs(btnList) do
        local gameBtn = self:getButtonByName(btnName)
        if gameBtn then
            if self.curPlayerIsTheGamePlayer then
                self:updateBtnTouchState(gameBtn, btnName, true,  self.curSelPlayerLevel)
            else
                self:updateBtnTouchState(gameBtn, btnName, false)
            end
        end
    end
end

-- 更新所有按钮点击状态
function M:updateAllCfgBtnTouch()
    if self.buttonsCfg then
        for i = 1, #self.buttonsCfg do
            if self:isGameSpecialBtn(self.buttonsCfg[i].name) then
                self:updateBtnTouchState(self.buttons[i],self.buttonsCfg[i].name, false,  self.curSelPlayerLevel)
            else
                self:updateBtnTouchState(self.buttons[i],self.buttonsCfg[i].name, true, 9999)
            end
            self:updateBtnShowName(self.buttons[i], self.buttonsCfg[i].name, self.data.userId)
        end
    end
end

function M:initPlayerHeadData(data)
    self.data = data

    self.txtLv:SetVisible(false)
    self.curPlayerIsFriend = nil
    if self.btnFriend then
        self.curPlayerIsFriend = Plugins.CallTargetPluginFunc("platform_chat", "checkPlayerIsMyChatFriend", self.data.userId)
        if self.curPlayerIsFriend then
            self.btnFriend:SetNormalImage( "set:chat.json image:btn_9_cancel")
            self.btnFriend:SetPushedImage( "set:chat.json image:btn_9_cancel")
            self.btnFriend:SetText(Lang:toText("ui.chat.player_delFriend"))
            self.btnFriend:SetVisible(World.cfg.chatSetting.isShowPlayerDelBtn)
        else
            self.btnFriend:SetNormalImage( "set:chat.json image:btn_9_adddot")
            self.btnFriend:SetPushedImage( "set:chat.json image:btn_9_adddot")
            self.btnFriend:SetText(Lang:toText("ui.chat.player_addFriend"))
            self.btnFriend:SetVisible(World.cfg.chatSetting.isShowPlayerAddBtn )
        end
        self:updateBtnTouchState(self.btnFriend, "btnFriend", true,  9999)
    end
    self:updateAllCfgBtnTouch()

    if self.curSelPlayerUserId and self.curSelPlayerUserId == data.userId then
        return
    end

    self.curSelPlayerId = data.objId or 0
    self.curSelPlayerUserId = data.userId
    self.curSelPlayerName = data.nickName
    self.txtName:SetText(Lang:toText({"ui.chat.playerInfo.name", data.nickName}))
    self.txtId:SetText(Lang:toText({"ui.chat.playerInfo.id", self.curSelPlayerUserId}))

    if data and data.picUrl and #data.picUrl > 0  then
        self.imgHead:SetImageUrl(data.picUrl)
    else
        self.imgHead:SetImage("set:default_icon.json image:header_icon")
    end
    if data.sex == 2 then
        self.imgSex:SetImage("set:chat.json image:img_0_female" )
        self.imgTopBg:SetImage("set:chat.json image:img_9_quality_purple")
        self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_captain")
    else
        self.imgSex:SetImage( "set:chat.json image:img_0_male" )
        self.imgTopBg:SetImage("set:chat.json image:img_9_quality_blue")
        self.imgHeadFrame:SetImage("set:chat.json image:img_9_headframe_players")
    end

    self:updateBtnEvent()
end

function M:onClose()
    if self._allEvent then
        for k, fun in pairs(self._allEvent) do
            fun()
        end
    end
end

function M:onOpen(userId)
    self._allEvent = {}
    self:subscribeEvent()
    self:initView(userId)
end

function M:onHide()
    UI:closeWnd("chatPlayerInfo")
end

function M:onShow(isShow, userId)
    if isShow then
        if not UI:isOpen(self) then
            UI:openWnd("chatPlayerInfo", userId)
        else
            self:onHide()
        end
    else
        self:onHide()
    end
end

--界面数据初始化
function M:initView(userId)
    if userId == Me.platformUserId or not userId then
        self:onHide()
        return
    end
    self.curSelPlayerLevel = 0
    self.curPlayerIsTheGamePlayer = false
    AsyncProcess.GetUserDetail(userId, function (data)
        if not userId or not data then
            return
        end
        self:initPlayerHeadData(data)
        local curUserId = data.userId
        self.curPlayerIsTheGamePlayer = Me:checkOneIsTheGamePlayer(curUserId)
        PlayerSpInfoManager:getPlayerSpDataById(curUserId ,function(info)
            local spData = UIChatManage:getSpDataByUserSpInfo(info, curUserId)
            local topData = UIChatManage:getTopDataByUserSpInfo(info, curUserId)
            if spData then
                self:initPlayerSpInfo(spData)
            end
            if topData then
                self:initPlayerTopInfo(topData)
            end
        end)

        if chatSetting.isOpenTagFunction then
            AsyncProcess.GetPlayerListTagData({ curUserId },function(data)
                if data then
                    for _, val in pairs(data) do
                        if tonumber(val.userId) == curUserId then
                            self:initTags(val.labels)
                            return
                        end
                    end
                    self:initTags({})
                end
            end)
        end
    end)
end