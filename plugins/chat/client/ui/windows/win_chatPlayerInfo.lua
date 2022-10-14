local chatSetting = World.cfg.chatSetting or {}
local infoSetting = chatSetting.infoSetting or {}
local playerImgPool = {}
local ButtonCfg = {
    {
        name = "ui.chat.ignore",
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
        clickEvent = {
            isClient = true,
            name = "EVENT_OPEN_PRIVATE_CHAT"
        }
    },
}
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
    WinBase.init(self, "ChatPlayerInfo.json",false)
    self:initWnd()
    self:initEvent()
end

function M:initWnd()
    self.buttonsCfg = chatSetting.infoButtons or ButtonCfg

    self.lytInfo = self:child("ChatPlayerInfo-Bg")
    self.lytClose = self:child("ChatPlayerInfo-Close")

    self.imgHead = self:child("ChatPlayerInfo-Head")
    self.txtLv = self:child("ChatPlayerInfo-Lv")

    self.imgEmblem = self:child("ChatPlayerInfo-Emblem")
    self.imgTitle = self:child("ChatPlayerInfo-Title-Bg")
    self.txtTitle = self:child("ChatPlayerInfo-Title")

    self.txtName = self:child("ChatPlayerInfo-Name")
    self.txtId = self:child("ChatPlayerInfo-Id")

    self.lytButton = self:child("ChatPlayerInfo-Buttons")
    self.buttons = {}
    self.addedFriendList = {}
    self:initButtons()

    if chatSetting.chatSystemColor then
        self.txtId:SetTextColor(getColorOfRGB(chatSetting.chatSystemColor))
    end

    self:root():SetLevel((chatSetting.chatLevel or 48) - 1)
end

function M:initButtons()
    if self.buttonsCfg then
        local row = #self.buttonsCfg > 2 and 2 or 1
        local rowInterval = row > 1 and 8 or 0
        local line = #self.buttonsCfg > 4 and math.ceil(#self.buttonsCfg / 2) or 2
        local height = (self.lytButton:GetPixelSize().y - 8) / line
        local width = (self.lytButton:GetPixelSize().x - rowInterval) / row
        for i = 1, #self.buttonsCfg do
            local btn = GUIWindowManager.instance:CreateGUIWindow1("Button")
            self.lytButton:AddChildWindow(btn)
            local cfg = self.buttonsCfg[i]
            local _l = #self.buttonsCfg > 2 and math.ceil(i / 2) or i
            local _r = #self.buttonsCfg > 2 and 2 - i % 2 or 1
            btn:SetArea({ 0, (_r - 1) * (width + 8)}, { 0, (_l - 1) * (height + 8)}, { 0, width }, { 0, height })
            btn:SetNormalImage(cfg.image or "set:chat_main.json image:btn_9_green")
            btn:SetPushedImage(cfg.image or "set:chat_main.json image:btn_9_green")
            btn:SetProperty("StretchType", "NineGrid")
            btn:SetProperty("StretchOffset", "10 10 10 10")
            btn:SetText(Lang:toText(cfg.name or ""))
            btn:SetProperty("Font", cfg.fontSize or "HT16")
            btn:SetProperty("TextBorder", "true")
            btn:SetProperty("TextBorderColor", cfg.borderColor or {71/255, 105/255, 17/255, 1})
            self.buttons[i] = btn
        end
    end
end

function M:initEvent()
    self:lightSubscribe("error!!!!! script_client win_chatPlayerInfo lytClose event : EventButtonClick", self.lytClose, UIEvent.EventWindowClick, function()
        UI:closeWnd(self)
    end)

    if self.buttonsCfg then
        for i = 1, #self.buttonsCfg do
            local cfg = self.buttonsCfg[i]
            if cfg.clickEvent then
                self:lightSubscribe("error!!!!! script_client win_chatPlayerInfo buttons event : EventButtonClick", self.buttons[i], UIEvent.EventButtonClick, function()
                    if cfg.clickEvent.isClient then
                        Lib.emitEvent(Event[cfg.clickEvent.name], self.curSelPlatId, self.curSelPlayerId, self.curSelPlayerName, self.buttons[i])
                    else
                        Me:sendPacket({
                            pid = cfg.clickEvent.name,
                            object = self.curSelPlatId
                        })
                    end
                    UI:closeWnd(self)
                end)
            end
        end
    end
end

function M:updateBtnEvent()
    if self.buttonsCfg then
        for i = 1, #self.buttonsCfg do
            local cfg = self.buttonsCfg[i]
            if cfg.checkEvent then
                if cfg.checkEvent.isClient then
                    Lib.emitEvent(Event[cfg.checkEvent.name], self.curSelPlatId, self.curSelPlayerId, self.curSelPlayerName, self.buttons[i])
                else
                    Me:sendPacket({
                        pid = cfg.checkEvent.name,
                        object = self.curSelPlatId
                    })
                end
            end
        end
    end
end

function M:initPlayer(data)
    if data.uId == Me.platformUserId or not data.uId then
        UI:closeWnd(self)
        return
    end

    if self.curSelPlatId and self.curSelPlatId == data.uId then
        return
    end

    self.curSelPlayerId = data.objId
    self.curSelPlatId = data.uId
    self.curSelPlayerName = data.name
    self.txtName:SetText("▢" .. data.nameColor .. data.name)
    self.txtId:SetText("ID: " .. self.curSelPlatId)
    local player = World.CurWorld:getEntity(data.objId)

    if not playerImgPool[data.uId] then
        AsyncProcess.GetUserDetail(data.uId, function (_data)
            if _data and _data.picUrl and #_data.picUrl > 0  then
                playerImgPool[data.uId] = _data.picUrl
                self.imgHead:SetImageUrl(_data.picUrl)
            else
                self.imgHead:SetImage("set:default_icon.json image:header_icon")
            end
        end)
    else
        self.imgHead:SetImageUrl(playerImgPool[data.uId])
    end

    self.txtLv:SetVisible(false)
    self.imgEmblem:SetVisible(false)
    self.imgTitle:SetVisible(false)

    if player and infoSetting.lvKey then
        self.txtLv:SetVisible(true)
        self.txtLv:SetText("Lv." .. player:getValue(infoSetting.lvKey))
    end

    if player and infoSetting.emblem then
        self.imgEmblem:SetVisible(true)
        self.imgEmblem:SetImage(player:getEmblemIcon())
    end

    if player and infoSetting.title then
        self.imgTitle:SetVisible(true)
        self.txtTitle:SetText(player:getTitleName())
    end

    self:updateBtnEvent()
end

function M:onClose()
end

function M:onOpen(data)
    if not data then
        UI:closeWnd(self)
        return
    end
    self:initPlayer(data)
end