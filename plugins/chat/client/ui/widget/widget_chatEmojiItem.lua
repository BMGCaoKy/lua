local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

function M:init()
    widget_base.init(self, "ChatEmojiItem.json")
    
    self:initWnd()
end

function M:initWnd()
    self:lightSubscribe("error!!!!! script_client widget_chatEmojiItem img event : EventWindowClick",self._root, UIEvent.EventWindowClick, function()
        ---发表情
        UI:getWnd("chatMain"):sendEmoji(self.icon)
    end)
end

function M:onDataChanged(data)
    self._root:SetImage(data.icon)
    self.icon = data.icon
end

function M:onInvoke(key, ...)
    local fn = M[key]
    assert(type(fn) == "function", key)
    return fn(self, ...)
end

return M
