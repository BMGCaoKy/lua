local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

function M:init()
    widget_base.init(self, "ChatShortItem.json")
    self.btn = self:child("ChatShortItem-Btn")
    self.btnText = self:child("ChatShortItem-Text")

    self:initWnd()
end

function M:initWnd()
    self:lightSubscribe("error!!!!! script_client widget_chatShortItem img event : EventWindowClick",self.btn, UIEvent.EventButtonClick, function()
        ---发快捷短语
        UI:getWnd("chatMain"):sendShort(self.text)
    end)
end

function M:onDataChanged(data)
    self.btnText:SetText(Lang:toText(data.name))
    self.btn:SetNormalImage("set:chat_main.json image:img_0_phrase_01")
    self.btn:SetPushedImage("set:chat_main.json image:img_0_phrase_01")
    self.text = data.text
    if data.event and data.event ~= "" then
        self.btn:SetNormalImage("set:chat_main.json image:img_0_phrase_02")
        self.btn:SetPushedImage("set:chat_main.json image:img_0_phrase_02")
    end
end

function M:onInvoke(key, ...)
    local fn = M[key]
    assert(type(fn) == "function", key)
    return fn(self, ...)
end

return M
