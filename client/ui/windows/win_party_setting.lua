local PARTY_INVITE_SHOW_TIME = World.cfg.inviteShowTime or 100
local broadcastIndex = assert(World.cfg.broadcastPartyInviteItemIndex)

function M:init()
	WinBase.init(self, "PartySetting.json", true)
	
	local titleText = self:child("PartySetting-Title")
	titleText:SetText(Lang:getMessage(titleText:GetText()))
	self.lastBroadcastTime = 0
	local broadcastBtn = self:child("PartySetting-Broadcast")
	broadcastBtn:SetText(Lang:getMessage(broadcastBtn:GetText()))
    self:subscribe(broadcastBtn, UIEvent.EventButtonClick, function()
        self:onClickBroadcastBtn()
    end)
	local bgmListBtn = self:child("PartySetting-MusicList")
	bgmListBtn:SetText(Lang:getMessage(bgmListBtn:GetText()))
	self:subscribe(bgmListBtn, UIEvent.EventButtonClick, function()
		UI:openWnd("bgm_list")
	end)

	local closePartyBtn = self:child("PartySetting-CloseParty")
	closePartyBtn:SetText(Lang:getMessage(closePartyBtn:GetText()))
	self:subscribe(closePartyBtn, UIEvent.EventButtonClick, function()
		Me:sendPacket({ pid = "CloseParty" })
	end)
	self:subscribe(self:child("PartySetting-Close"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)
	self.membersCountText = self:child("PartySetting-MembersCount")
    local broadcastItem = Shop:getShop(broadcastIndex)
    self.broadcastItem = broadcastItem
    self:child("PartySetting-BroadcastCost"):SetText(broadcastItem.price)
    self:child("PartySetting-Currency"):SetImage(Coin:iconByCoinId(broadcastItem.coinId))

    Lib.subscribeEvent(Event.EVENT_PARTY_INFO_CHANGED, function(info)
        self:updatePartySettingInfo(info)
    end)

    Lib.subscribeEvent(Event.EVENT_SEND_BUY_SHOP_RESULT, function(index, _, msg, _, succeed)
        if index ~= broadcastIndex then
            return
        end
        if succeed then
            Client.ShowTip(3, Lang:toText("tip.party.broadcast.invite.pay.money.success"), 40)
            self:broadcastPartyInvite()
            self.lastBroadcastTime = os.time()
        elseif msg == "game_shop_ack_of_money" then
            Lib.emitEvent(Event.EVENT_SHOW_GOLD_SHOP, true)
        else
            Client.ShowTip(3, Lang:toText(msg), 40)
        end
    end)
end

function M:onOpen()
	WinBase.onOpen(self)
	Me:sendPacket({pid = "QueryPartyInfo"})
end

function M:onClose()
	WinBase.onClose(self)
end

function M:onClickBroadcastBtn()
    if os.time() - self.lastBroadcastTime <= 3 then
        Client.ShowTip(3, Lang:toText("tip.operate.frequently"), 40)
        return
    end
    if self.isFull then
        Client.ShowTip(3, Lang:toText("tip.user.party.reach.capacity"), 40)
        return
    end
    local price = self.broadcastItem.price
    local tipContent = {
        msgText = {"tip.party.broadcast.invite.need.money", price},
        leftText = "ui_cancel",
        rightCoinId = self.broadcastItem.coinId,
        rightText = price,
    }
    UILib.openPayDialog(tipContent, function(isCancel)
        if not isCancel then
            Shop:requestBuyStop(broadcastIndex, 1)
        end
    end)
end

function M:updatePartySettingInfo(info, broadcastCfg)
    local curPlayerNum, maxPlayerNum = info.curPlayerNum, info.maxPlayerNum
    self.membersCountText:SetText(string.format("%d / %d", curPlayerNum, maxPlayerNum))
    self.isFull = curPlayerNum == maxPlayerNum
end

function M:broadcastPartyInvite()
	local selfInfo = UserInfoCache.GetCache(Me.platformUserId)
    local content = {
        userId = Me.platformUserId,
        picUrl = selfInfo.picUrl,
        nickName = selfInfo.nickName,
        fromParty = true,
        partyInfo = selfInfo.partyInfo,
        showTime = PARTY_INVITE_SHOW_TIME,
	}
	Me:sendPlayerInvite(nil, content, true)
end