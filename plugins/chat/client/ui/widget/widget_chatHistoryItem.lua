local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)
function M:init()
    widget_base.init(self, "ChatHistoryItem.json")
    self:initWnd()
    self:initData()
    self:initEvent()
end

function M:initWnd()
    self.txtName = self:child("ChatHistoryItem-Name")
    self.imgBg = self:child("ChatHistoryItem-Bg")
    self.txtRelation = self:child("ChatHistoryItem-Relation")
    self.txtCnt = self:child("ChatHistoryItem-Msg-Cnt")
    self.btnDel = self:child("ChatHistoryItem-Del")
end
function M:initData()
    self:closePoint()
end
function M:initEvent()
    self:lightSubscribe("error!!!!! script_client widget_chatHistoryItem imgBg event : EventWindowClick",self.imgBg, UIEvent.EventWindowClick, function()
        Lib.emitEvent("EVENT_JUMP_PRIVATE_CHAT", self.data)
    end)
    self:lightSubscribe("error!!!!! script_client widget_chatHistoryItem btnDel event : EventButtonClick",self.btnDel, UIEvent.EventButtonClick, function()
        Lib.emitEvent("EVENT_DEL_PRIVATE_CHAT", self.data.platId)
    end)
    
end
function M:closePoint()
    self.txtCnt:SetVisible(false)
    self.txtCnt:SetText("0")
end
function M:onDataChanged(data)
    -- print("-------onDataChanged--------",Lib.v2s(data))
    self.data = data
    
    self.nameColorStr = "FF000000"
    self.txtName:SetText("▢"..self.nameColorStr.." "..data.fromname)
    if not data.relation then
        if data.platId then
            if Me:isFriendShip(data.platId) then
                data.relation = 3
            else
                data.relation = 1
            end
        end
        
    end
    
    if data.relation == 1 then
        self.txtRelation:SetText("▢FFF00925"..Lang:toText("ui.chat.strangr"))
    elseif data.relation == 3 then
        self.txtRelation:SetText("▢FF2EB9E6"..Lang:toText("ui.chat.friend"))
    else
        self.txtRelation:SetText("▢FFF00925"..Lang:toText("ui.chat.strangr"))
    end
    
    self.txtCnt:SetText(data.cnt)
    self.txtCnt:SetVisible(tonumber(data.cnt)>0)
end

function M:onInvoke(key, ...)
    local fn = M[key]
    assert(type(fn) == "function", key)
    return fn(self, ...)
end

return M
