local chatSetting = World.cfg.chatSetting or {}
local VoiceShopConfig = T(Config, "VoiceShopConfig")
function M:init()
    WinBase.init(self, "ChatShop.json",false)
    self:initWnd()
    self:initEvent()
end
function M:initWnd()
    self.btnItem1 = self:child("ChatShop-Item-Buy-1")
    self.txtItemCost1 = self:child("ChatShop-Item-Cost-1")
    self.txtItemCnt1 = self:child("ChatShop-Item-Info-1")
    self.btnItem2 = self:child("ChatShop-Item-Buy-2")
    self.txtItemCost2 = self:child("ChatShop-Item-Cost-2")
    self.txtItemCnt2 = self:child("ChatShop-Item-Info-2")
    self.btnItem3 = self:child("ChatShop-Item-Buy-3")
    self.txtItemCost3 = self:child("ChatShop-Item-Cost-3")
    self.txtItemCnt3 = self:child("ChatShop-Item-Info-3")
    self.btnMoon = self:child("ChatShop-Moon")
    self.txtMoonInfo = self:child("ChatShop-Moon-Text")
    self.txtMoonCost = self:child("ChatShop-Moon-Cost")

    self.txtTitle = self:child("ChatShop-Title-Text")
    self.txtTitle:SetText(Lang:toText("ui.chat.shopTitle"))
    self.imgMoonHasTimeBg = self:child("ChatShop-Moon-Time-Bg")
    self.txtMoonHasTime = self:child("ChatShop-Moon-LastTime")
    self.txtVoiceTime = self:child("ChatShop-Moon-VoiceCnt")
    self.btnClose = self:child("ChatShop-Close")

    self:root():SetLevel((chatSetting.chatLevel or 48) - 2)
    self:initData()
end

function M:initEvent()
    self:subscribe(self.btnClose, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
    self:subscribe(self.btnItem1, UIEvent.EventButtonClick, function()
        self:buyById(1)
    end)    
    self:subscribe(self.btnItem2, UIEvent.EventButtonClick, function()
        self:buyById(2)
    end)
    self:subscribe(self.btnItem3, UIEvent.EventButtonClick, function()
        self:buyById(3)
    end)
    self:subscribe(self.btnMoon, UIEvent.EventButtonClick, function()
        self:buyById(4)
    end)
    Lib.subscribeEvent(Event.EVENT_CHAT_CARD_TIME, function(time)
        if time >-1 then
            self.imgMoonHasTimeBg:SetVisible(true)
            local day = math.floor(time/(3600*24)) 
            if day>0 then
                self.txtMoonHasTime:SetText(Lang:toText({"ui.chat.moonTime",day})) 
            else
                self.txtMoonHasTime:SetText(Lang:toText("ui.chat.moonLess")) 
            end
        else
            self.imgMoonHasTimeBg:SetVisible(false)
            self.txtMoonHasTime:SetText("")
        end
        
        
    end)
    Lib.subscribeEvent(Event.EVENT_SOUND_TIME_CHANGE, function(value)
        self.txtVoiceTime:SetText(Lang:toText({"ui.chat.hasVoice",Me:getSoundTimes()})) 
    end)
    Lib.subscribeEvent(Event.EVENT_SOUND_MOON_CHANGE, function(value)
        Me:getVoiceCardTime()
    end)
end
function M:buyById(idx)
    local wallet = Me:data("wallet")
    local cost = VoiceShopConfig:getItemById(idx).cost
    if not cost then
        print("CANT FIND VOICE ITEM PRICE")
        return
    end
    if wallet and wallet["gDiamonds"] and wallet["gDiamonds"].count >=cost then
        local uiParams = {
            titleText = "gui_lang_tip_title",
            msgText = {"ui.chat.sureBuy", VoiceShopConfig:getItemById(idx).cost},
        }
        Me:sendPacket({
            pid = "BuyVoice",
            idx = idx
        })
        --Me:showChatShopDialog(uiParams, function(isSelect)
        --    Lib.logDebug('isSelect = ', isSelect)
        --    if isSelect then
        --        Me:sendPacket({
        --            pid = "BuyVoice",
        --            idx = idx
        --        })
        --    end
        --end)
    else
        Interface.onRecharge(1)
    end
    
    
end

function M:initData()
    self.txtItemCost1:SetText(VoiceShopConfig:getItemById(1).cost)
    self.txtItemCost2:SetText(VoiceShopConfig:getItemById(2).cost)
    self.txtItemCost3:SetText(VoiceShopConfig:getItemById(3).cost)
    self.txtMoonCost:SetText(VoiceShopConfig:getItemById(4).cost) 
    self.txtVoiceTime:SetText(Lang:toText({"ui.chat.hasVoice",Me:getSoundTimes()})) 
    self.txtMoonInfo:SetText(Lang:toText("ui.chat.moonCard"))
    self.txtItemCnt1:SetText(Lang:toText({"ui.chat.buyNum",VoiceShopConfig:getItemById(1).num}) )
    self.txtItemCnt2:SetText(Lang:toText({"ui.chat.buyNum",VoiceShopConfig:getItemById(2).num}) )
    self.txtItemCnt3:SetText(Lang:toText({"ui.chat.buyNum",VoiceShopConfig:getItemById(3).num}) )
end
function M:onClose()
end
function M:onOpen()
    self:initData()
    Me:getVoiceCardTime()
end