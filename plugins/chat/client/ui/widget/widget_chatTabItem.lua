local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

local chatSetting = World.cfg.chatSetting
local SelectStatus = {
    NotSelect = 1,
    Select = 2,
}
local TabType = T(Define, "TabType")

function M:init()
    widget_base.init(self, "ChatTabItem.json")
    
    self:initWnd()
    self:initData()
end

function M:initWnd()
    self.imgIcon = self:child("ChatTabItem-Icon")
    self.imgBg = self:child("ChatTabItem-Bg")
    self.imgPoint = self:child("ChatTabItem-Point")
    self.txtCnt = self:child("ChatTabItem-Cnt")
    self.imgEffect = self:child("ChatTabItem-Effect")
    self.imgEffect:SetVisible(false)
end
function M:initData()
    self.curObjID = false
    self:closePoint()
end

function M:initTabByType(TabType)
    self.type = TabType

    if self.type  == Define.Page.FAMILY then
        Lib.subscribeEvent(Event.EVENT_FAMILY_ICON_CHANGE, function(value)
            self:changeTeamIcon()
        end)
    end
    self:setTabConfig()
    self.selectStatus = SelectStatus.NotSelect
    self:changeSelectStatus()
end
function M:setChatIsOpen(isOpen)
    self.isChatOpen = isOpen
end

function M:setTabConfig()
    if chatSetting.tabIcon and #chatSetting.tabIcon>0 then
        self.notSelectIcon =  chatSetting.tabIcon[self.type].normal
        self.selectIcon = chatSetting.tabIcon[self.type].select
        self.imgPoint:SetImage(chatSetting.tabIcon[self.type].point)
    else
        self.notSelectIcon =  "set:chat_main.json image:icon_common_chat_n"
        self.selectIcon = "set:chat_main.json image:icon_common_chat_s"
        self.imgPoint:SetImage("set:chat_main.json image:icon_chat_point")
    end

    if self.type == Define.Page.COMMON then
        Lib.lightSubscribeEvent("error!!!!! script_client widget_chatTabItem Lib event : EVENT_CHAT_MESSAGE",Event.EVENT_CHAT_MESSAGE, function(msg, fromname, voiceTime, emoji, args)
            Lib.logDebug('chatTabItem EVENT_CHAT_MESSAGE = ', Lib.v2s(args))
            if not args then
                return
            end
            local uId = args[4]
            if uId and UI:getWnd("chatMain"):checkIsIgnore(uId) then
                return
            end
            if (self.selectStatus == SelectStatus.Select and self.isChatOpen)
             or args[3] ~= Define.Page.COMMON then
                return
            end
            Lib.logDebug('addPointCnt')
            self:addPointCnt()
        end)
        -- self.txtIcon:SetVisible(false)
    elseif self.type == Define.Page.FAMILY then
        Lib.subscribeEvent(Event.EVENT_CHAT_MESSAGE, function(msg, fromname, voiceTime, emoji, args)
            if not args then
                return
            end
            local uId = args[4]
            if uId and UI:getWnd("chatMain"):checkIsIgnore(uId) then
                return
            end
            if self.selectStatus == SelectStatus.Select or args[3] ~= Define.Page.FAMILY then
                return
            end
            self:addPointCnt()
        end)
        -- self.txtIcon:SetVisible(false)
    elseif self.type == Define.Page.HISTORY then
        Lib.lightSubscribeEvent("error!!!!! script_client widget_chatTabItem Lib event : EVENT_CHAT_HISTORY_CHANGE","EVENT_CHAT_HISTORY_CHANGE", function()
            if self.selectStatus == SelectStatus.Select  then
                return
            end
            self:addPointCnt()
        end)
    elseif self.type == Define.Page.PRIVATE then
        Lib.lightSubscribeEvent("error!!!!! script_client widget_chatTabItem Lib event : EVENT_CHAT_MESSAGE",Event.EVENT_CHAT_MESSAGE, function(msg,fromname,voiceTime,emoji,args)
            if not args then
                return
            end
            local uId = args[4]
            if uId and UI:getWnd("chatMain"):checkIsIgnore(uId) then
                return
            end
            if self.selectStatus == SelectStatus.Select or args[3] ~= Define.Page.PRIVATE or args[1] == Me.objID or (self.curObjID and self.curObjID ~= args[4]) then
                return
            end
            self:addPointCnt()
        end)
        -- self.txtIcon:SetVisible(false)
    end
end

function M:addPointCnt()
    Lib.logDebug('addPointCnt')
    self.infoCnt = self.infoCnt + 1
    self.txtCnt:SetText( self.infoCnt>99 and "99+" or self.infoCnt.."")
    self.imgPoint:SetVisible(true)
    Lib.emitEvent(Event.EVENT_CHAT_POINT_CHANGE,self.infoCnt,self.type)
    
end

function M:updatePlayerName(name)
    -- if #name>=6 then
    --     local front = string.sub(name,1,5) 
    --     local back = string.sub(name,6) 
    --     name = string.format(front ..'\n' ..back) 
    -- end
    self.imgEffect:SetVisible(true)
    World.Timer(20, function()
        self.imgEffect:SetVisible(false)
    end)
    -- self.txtIcon:SetText(name)
end
function M:onCheckClick(type)
    if self.type == type then
        self.selectStatus = SelectStatus.Select
    else
        self.selectStatus = SelectStatus.NotSelect
    end
    self:changeSelectStatus()
end
function M:setCurPlayerId(curObjID)
    self.curObjID = curObjID
end

function M:closePoint()
    self.imgPoint:SetVisible(false)
    self.infoCnt = 0
    self.txtCnt:SetText("0")
    Lib.emitEvent(Event.EVENT_CHAT_POINT_CHANGE,self.infoCnt,self.type)
end

function M:changeSelectStatus()
    if self.selectStatus == SelectStatus.Select then
        self:closePoint()
        self.imgIcon:SetImage(self.selectIcon)
        self.imgBg:SetImage(chatSetting.tabBgImg and chatSetting.tabBgImg.select or "set:chat_main.json image:bg_page_n")
    else
        self.imgBg:SetImage(chatSetting.tabBgImg and chatSetting.tabBgImg.normal or "set:chat_main.json image:bg_page_normal_s")
        if self.type == Define.Page.PRIVATE then
            -- self.txtIcon:SetTextColor({255/255, 255/255, 255/255})
            self.imgIcon:SetImage(self.notSelectIcon)
        else
            self.imgIcon:SetImage(self.notSelectIcon)
        end 
    end
end


function M:changeTeamIcon()
    if not chatSetting.familyIcon then
        return
    end
    local imgs = chatSetting.familyIcon[tostring(Me:getValue(chatSetting.familyVal))]
    if imgs then
        self.notSelectIcon = imgs.normal
        self.selectIcon = imgs.select
    end
    self:changeSelectStatus()
end

function M:onInvoke(key, ...)
    local fn = M[key]
    assert(type(fn) == "function", key)
    return fn(self, ...)
end

return M
