
local widget_base = require "ui.widget.widget_base"
---@class WidgetChatTagSelectItem : widget_base
local WidgetChatTagSelectItem = Lib.derive(widget_base)
---@type TagsConfig
local TagsConfig = T(Config, "TagsConfig")
local chatSetting = World.cfg.chatSetting

function WidgetChatTagSelectItem:init()
    widget_base.init(self, "ChatTagSelectItem.json")
    self:initUI()
    self:initEvent()
end

function WidgetChatTagSelectItem:initUI()
    self.lytItemPanel = self:child("ChatTagSelectItem-itemPanel")
    self.imgItemBg = self:child("ChatTagSelectItem-itemBg")
    self.txtItemTitle = self:child("ChatTagSelectItem-itemTitle")
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatTagSelectItem:initEvent()
    self:subscribe(self.lytItemPanel, UIEvent.EventWindowClick, function()
        UI:getWnd("chatTagSelect"):updateOneTagSelectState(self.tagCfg)
    end)
end

local function getTextColor(str)
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
    return { colorlist[1] / 255, colorlist[2] / 255, colorlist[3] / 255 }
end

function WidgetChatTagSelectItem:onDataChanged(tagCfg)
    self.tagCfg = tagCfg
    self.txtItemTitle:SetText(Lang:toText(tagCfg.name))
    if tagCfg.isSelect then
        self.imgItemBg:SetImage(chatSetting.chatTagSetting[tostring(tagCfg.tagType)].tagTypeRes)
        self.txtItemTitle:SetTextColor( getTextColor("FEFEFE"))
    else
        self.imgItemBg:SetImage("set:friendTag.json image:img_9_playtag")
        self.txtItemTitle:SetTextColor( getTextColor(chatSetting.chatTagSetting[tostring(tagCfg.tagType)].tagTypeColor))
    end
end
return WidgetChatTagSelectItem