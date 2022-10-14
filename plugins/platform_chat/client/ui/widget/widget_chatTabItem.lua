local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

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
    self.txtTabName = self:child("ChatTabItem-tabName")
    self.imgPoint = self:child("ChatTabItem-Point")
    self.txtCnt = self:child("ChatTabItem-Cnt")
end
function M:initData()
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
    if chatSetting.tabIcon and #chatSetting.tabIcon>0 and chatSetting.tabIcon[self.type] then
        self.notSelectIcon =  chatSetting.tabIcon[self.type].normal
        self.selectIcon = chatSetting.tabIcon[self.type].select
        self.imgPoint:SetImage(chatSetting.tabIcon[self.type].point)
        self.txtTabName:SetText(Lang:toText(chatSetting.tabIcon[self.type].tabName))
    else
        self.notSelectIcon =  "set:chat.json image:chb_9_select"
        self.selectIcon = "set:chat.json image:chb_9_select"
        self.imgPoint:SetImage("set:chat.json image:img_9_reddot")
        self.txtTabName:SetText("")
    end

    Lib.lightSubscribeEvent("error!!!!! script_client widget_chatTabItem Lib event : EVENT_CHAT_MESSAGE",Event.EVENT_CHAT_MESSAGE, function(msg, fromname, voiceTime, emoji, args)
        --Lib.logDebug('chatTabItem EVENT_CHAT_MESSAGE = ', Lib.v2s(args))
        if not args then
            return
        end
        local uId = args[4]
        if uId and UIChatManage:checkIsIgnore(uId) then
            return
        end
        if args[3] ~= self.type then
            return
        end
        if (self.selectStatus == SelectStatus.Select and UI:isOpen("chatMain")) then
            return
        end
        if self.type == Define.Page.PRIVATE then
            return
        end
        self:addPointCnt()
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client widget_chatTabItem Lib event : EVENT_UPDATE_PRIVATE_RED_NUM",Event.EVENT_UPDATE_PRIVATE_RED_NUM, function(redNum)
        if self.type == Define.Page.PRIVATE then
            self.infoCnt = redNum
            self:updatePointCntShow()
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client widget_chatTabItem Lib event : EVENT_UPDATE_FRIEND_RED_NUM",Event.EVENT_UPDATE_FRIEND_RED_NUM, function(redNum)
        if self.type == Define.Page.FRIEND then
            self.infoCnt = redNum
            self:updatePointCntShow()
        end
    end)
end

function M:addPointCnt()
    self.infoCnt = self.infoCnt + 1
    self:updatePointCntShow()
end

function M:updatePointCntShow()
    self.txtCnt:SetText( self.infoCnt>99 and "99+" or self.infoCnt.."")
    if self.infoCnt > 0 then
        self.imgPoint:SetVisible(true)
    else
        self.imgPoint:SetVisible(false)
    end
    Lib.emitEvent(Event.EVENT_CHAT_POINT_CHANGE,self.infoCnt,self.type)
end

function M:updatePlayerName(name)
    -- if #name>=6 then
    --     local front = string.sub(name,1,5) 
    --     local back = string.sub(name,6) 
    --     name = string.format(front ..'\n' ..back) 
    -- end
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

function M:closePoint()
    self.imgPoint:SetVisible(false)
    self.infoCnt = 0
    self.txtCnt:SetText("0")
    Lib.emitEvent(Event.EVENT_CHAT_POINT_CHANGE,self.infoCnt,self.type)
end

local function getTextColor(str)
    local curColorStr = str or "000000"
    -- 去掉#字符
    local newstr = string.gsub(curColorStr, '#', '')

    -- 每次截取两个字符 转换成十进制
    local colorlist = {}
    local index = 1
    while index < string.len(newstr) do
        local tempstr = string.sub(newstr, index, index + 1)
        table.insert(colorlist, tonumber(tempstr, 16))
        index = index + 2
    end
    return { colorlist[1] / 255, colorlist[2] / 255, colorlist[3] / 255 }
end

function M:changeSelectStatus()
    if self.selectStatus == SelectStatus.Select then
        if self.type ~= Define.Page.FRIEND then
            self:closePoint()
        end
        self.imgIcon:SetImage(self.selectIcon)
        self.txtTabName:SetTextColor(getTextColor(chatSetting.tabIcon[self.type].nameSColor))
    else
        self.imgIcon:SetImage(self.notSelectIcon)
        self.txtTabName:SetTextColor(getTextColor(chatSetting.tabIcon[self.type].nameNColor))
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
