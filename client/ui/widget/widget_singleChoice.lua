local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

function M:init()
    widget_base.init(self, "singleChoice_edit.json")
    self:initUIName()
    self:uiEventReg()
end

function M:initUIName()
    self.content = self:child("SingleChoice-Content")
    self.checkImage = self:child("SingleChoice-Check")
    self.text = self:child("SingleChoice-Text")
end

function M:updateUI(selected)
    self:callBackFunc(selected)
    self.checkImage:SetImage(selected and "set:setting_base.json image:radio_click.png" or "set:setting_base.json image:radio_empty.png")
    self.text:SetTextColor(selected and {99/255, 100/255, 106/255, 1} or {174/255, 184/255, 183/255, 1})
end

function M:fillData(params)
    local cfg = Clientsetting.getUIDescCsvData(params.index)
    if not cfg then
        return
    end
    local titleText = cfg.title and Lang:toText(cfg.title) or ""
    self.text:SetText(titleText)
    self.text:SetWidth({0, self.text:GetFont():GetTextExtent(titleText,1)})
    self._root:SetSelected(params.value)
    self:updateUI(params.value)
end

function M:cmp(item1, item2)
    if item1.index and item1.index == item2.index then
        return true
    end
    return false
end

function M:callBackFunc(value)
    if self.backFunc then
        self.backFunc(value)
    end
end

function M:setBackFunc(func)
	self.backFunc = func
end

function M:uiEventReg()
    self._root:subscribe(UIEvent.EventRadioStateChanged, function(wnd)
        self:updateUI(wnd:IsSelected())
    end)
end

return M
