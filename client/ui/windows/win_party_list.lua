local debugPort = require "common.debugport"
local engineVersion = debugPort.engineVersion

function M:init()
	WinBase.init(self, "PartyList.json", true)
	self.lastUpdateTime = 0
	self.partyList = self:child("PartyList-List")

	local titleText = self:child("PartyList-Title")
	titleText:SetText(Lang:getMessage(titleText:GetText()))
	local refreshBtn = self:child("PartyList-Refresh")
	refreshBtn:SetText(Lang:getMessage(refreshBtn:GetText()))
	self:subscribe(refreshBtn, UIEvent.EventButtonClick, function()
		self:requestPartyList()
	end)
	local newPartyBtn = self:child("PartyList-NewParty")
	newPartyBtn:SetText(Lang:getMessage(newPartyBtn:GetText()))
	self:subscribe(newPartyBtn, UIEvent.EventButtonClick, function()
        local partyName = Lang:toText({"gui.party.default.name", Me.name})
		Me:sendPacket({pid = "QueryCreatePartyViewInfo", partyName = partyName}, function (info)
            if info.canCreate then
                self:showCreatePartyViewInfo(info)
            end
		end)
	end)
	self:subscribe(self:child("PartyList-Close"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)
	Lib.subscribeEvent(Event.EVENT_PARTY_LIST_CHANGED, function(data)
		self:refreshPartyList(data)
	end)
end

function M:onOpen(regId)
	WinBase.onOpen(self)
    self:requestPartyList()
    self.regId = regId
end

function M:onClose()
    WinBase.onClose(self)
    if self.regId then
        Me:doCallBack("ShowPartyList", "close", self.regId)
        self.regId = nil
    end
end

local function showPartyNameEdit(self, item)
    item:SetTextColor({106 / 255, 241 / 255, 233 / 255, 1})
    self:subscribe(item, UIEvent.EventWindowTextChanged, function ()
        local text = item:GetPropertyString("Text", "")
        if #text == 0 then
            text = self.partyName
        end
        self.partyName = text --backup
        item:SetProperty("Text", text)
    end)
end

function M:showCreatePartyViewInfo(info)
    local item = GUIWindowManager.instance:LoadWindowFromJSON("PartyCreateViewInfo.json")
    local editItem = item:child("PartyCreateViewInfo-NameEdit")
    local partyName = Lang:toText({info.partyName, World.getEntityOriginalName(info.from)})
    self.partyName = partyName
    self.partyTime = 0
    self.partyPrice = 0

    editItem:SetText(partyName)
    showPartyNameEdit(self, editItem)
    item:child("PartyCreateViewInfo-MemberMax"):SetText(Lang:toText({"party.memberLimit", info.maxPlayerNum}))
    item:child("PartyCreateViewInfo-Title"):SetText(Lang:toText("party.create"))
    item:child("PartyCreateViewInfo-Image"):SetImage(info.partyImage)
    
    local cancelBtn = item:child("PartyCreateViewInfo-Cancel")
    cancelBtn:SetText(Lang:toText("cancel"))
    self:subscribe(cancelBtn, UIEvent.EventButtonClick, function()
        self._root:RemoveChildWindow1(item)
    end)
    local createBtn = item:child("PartyCreateViewInfo-Create")
    local priceView = item:child("PartyCreateViewInfo-Money")

    local minTime = 0
    for _, k in pairs(World.cfg.party.prices) do
        if minTime == 0 then
            minTime = k.time
        end
        minTime = math.min(k.time, minTime)
    end

    local lvTab = item:child("PartyCreateViewInfo-TimeList")
    for i, v in pairs(World.cfg.party.prices) do
        local rb = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", "PartyCreateViewInfo-TimeList-Tab-" .. v.time)
        rb:SetText(Lang:toText({"party_time", v.time } ))
        self:subscribe(rb, UIEvent.EventRadioStateChanged, function(view)
            if view:IsSelected() then
                if v.time == minTime and info.remainCount > 0 then
                    createBtn:SetText(Lang:toText({"create_party_free_count", info.remainCount}))
                    priceView:SetVisible(false)
                    self.partyTime = v.time
                    self.partyPrice = 0
                else
                    priceView:SetText(Lang:toText(v.price))
                    priceView:SetVisible(true)
                    self.partyPrice = v.price
                    self.partyTime = v.time
                    createBtn:SetText("")
                end
            end
        end)

        rb:SetArea({0, (i - 1) * 110}, {0, 0}, {0, 100}, {0, 50})
        rb:SetNormalImage("set:Generic_Btn.json image:Generic_Btn_Blue_Small.png")
        rb:SetPushedImage("set:Generic_Btn.json image:Generic_Btn_Yellow_Small.png")
        rb:SetProperty("StretchType", "NineGrid")
        rb:SetProperty("StretchOffset", "20 20 0 0")

        lvTab:AddChildWindow(rb)
        if i == 1 then
            rb:SetSelected(false)
            rb:SetSelected(true)
        end
    end

    priceView:SetNormalImage(Coin:iconByCoinId(World.cfg.party.coinId))
    priceView:SetPushedImage(Coin:iconByCoinId(World.cfg.party.coinId))


    lvTab:SetArea({0, 236}, {0, 123}, {0, 100 * #World.cfg.party.prices - 10}, {0, 50})

    self:subscribe(createBtn, UIEvent.EventButtonClick, function()

        if info.remainCount > 0 and self.partyPrice == 0 then
            Me:sendPacket({
                pid = "CreateParty",
                time = self.partyTime,
                partyName = self.partyName,
            })
        else
            local msg = { "create_party_msg", self.partyTime }
            local showArgs = {  msgText = msg, leftText = "ui_cancel", leftCoinId = -1, rightCoinId = World.cfg.party.coinId, rightText = self.partyPrice}
            UILib.openPayDialog(showArgs, function(selectedLeft)
                if UI:isOpen(self) and not selectedLeft then
                    Me:sendPacket({
                        pid = "CreateParty",
                        time = self.partyTime,
                        partyName = self.partyName,
                    })
                end
            end)
        end
    end)
    self._root:AddChildWindow(item, "PartyCreateViewInfo")
end

function M:refreshPartyList(list)
    self.lastUpdateTime = os.time()
    local partyList = self.partyList
    partyList:ClearAllItem()
    local windowMgr = GUIWindowManager.instance
    for i, data in pairs(list) do
        if data.userId == Me.platformUserId then
            goto continue
        end
        if data.engineVersion ~= engineVersion then
            goto continue
        end
        local item = windowMgr:LoadWindowFromJSON("PartyListItem.json")
        item:child("PartyListItem-HouseIcon"):SetImage(data.partyImage or "")
        item:child("PartyListItem-HeadIcon"):SetImageUrl(data.picUrl  or "")
        item:child("PartyListItem-PartyName"):SetText(data.partyName or "")
        item:child("PartyListItem-PraiseCount"):SetText(tostring(data.likeNum or 0))
        item:child("PartyListItem-MembersCount"):SetText(string.format("%d / %d", data.curPlayerNum, data.maxPlayerNum))
        item:child("PartyListItem-Language"):SetText(Lang:toText(data.language or "en"))
        local joinBtn = item:child("PartyListItem-Join")
        joinBtn:SetText(Lang:getMessage(joinBtn:GetText()))
        if data.curPlayerNum >= data.maxPlayerNum then
            joinBtn:SetEnabled(false)
        end
        self:subscribe(joinBtn, UIEvent.EventButtonClick, function()
            joinBtn:SetEnabled(false)
            Me:sendPacket({
                pid = "RequestJoinParty",
                targetUserId = data.userId,
                partyId = data.partyId,
            })
        end)
        partyList:AddItem(item)
        ::continue::
    end
end

function M:requestPartyList()
	if os.time() - self.lastUpdateTime < 2 then
		return
	end
	Me:sendPacket({pid = "QueryPartyList"})
end
