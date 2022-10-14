local isMyParty = false

function M:init()
    WinBase.init(self, "PartyInnerSetting.json", true)
    self.likeNumber = self:child("PartyInnerSetting-LikeNumber")
    local likeBtn = self:child("PartyInnerSetting-Like")
    likeBtn:SetText(Lang:toText("gui.party.like"))
    self.likeBtn = likeBtn
    local exitBtn = self:child("PartyInnerSetting-Exit") 
    exitBtn:SetText(Lang:toText("gui.party.exit"))
    self.exitBtn = exitBtn
    self:subscribe(self.exitBtn, UIEvent.EventButtonClick, function()
        Me:sendPacket({ pid = "LeaveParty", inPartyOwnerId = self.inPartyOwnerId })
    end)
    local settingBtn = self:child("PartyInnerSetting-Setting") 
    settingBtn:SetText(Lang:toText("gui.party.setting"))
    self:subscribe(settingBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_SHOW_PARTY_SETTING, true)
    end)
    self.settingBtn = settingBtn
    Lib.subscribeEvent(Event.EVENT_PARTY_INFO_CHANGED, function(info)
        self:updatePartySettingInfo(info)
    end)
    UI:getWnd("party_setting")
end

function M:updatePartySettingInfo(info)
    self.likeNumber:SetText(info and info.likeNum or 0)
end

function M:onOpen(packet)
    WinBase.onOpen(self)
    local inPartyOwnerId = packet.inPartyOwnerId
    self.inPartyOwnerId = inPartyOwnerId
    isMyParty = inPartyOwnerId == Me.platformUserId
    Me:data("main").inSelfParty = isMyParty
    self.exitBtn:SetVisible(not isMyParty)
    self.likeNumber:SetVisible(isMyParty)
    self.settingBtn:SetVisible(isMyParty)
    local likeBtn = self.likeBtn
    likeBtn:SetVisible(true)
    self:unsubscribe(likeBtn, UIEvent.EventButtonClick)
    self:subscribe(likeBtn, UIEvent.EventButtonClick, function()
        Me:sendPacket({pid = "LikeParty", inPartyOwnerId = inPartyOwnerId})
        likeBtn:SetVisible(false)
        self.likeNumber:SetVisible(true)
    end)
    self:updatePartySettingInfo(packet.partyData)
end

function M:onClose()
    WinBase.onClose(self)
end