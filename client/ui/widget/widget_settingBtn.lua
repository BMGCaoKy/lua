local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

local F = {}

function F:setDropItem()
    UI:openWnd("mapEditDropSetting2", self.params, function(dropData)
        self:callBackFunc(dropData)
    end)
end

function M:init()
    widget_base.init(self, "settingBtn_edit.json")
    self:initUIName()
    self:uiEventReg()
end

function M:initUIName()
    self.title = self:child("SettingBtn-Title")
    self.title:SetText(Lang:toText("block.die.drop.title"))
    self.btn = self:child("SettingBtn-Btn")
    self.btn:SetText(Lang:toText("block.die.drop.setting"))
end

function M:fillData(params)
    self.params = params
    local cfg = Clientsetting.getUIDescCsvData(params.index)
    if not cfg then
        return
    end
    self.title:setTextAutolinefeed(Lang:toText(cfg.title or ""))
    self.btn:SetText(Lang:toText(cfg.btnTitle or ""))
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
    self.btn:subscribe(UIEvent.EventButtonClick, function()
        local propItem = self.params.propItem
        local event = propItem and propItem.event
        if event and F[event] then
            F[event](self)
        else
            self:callBackFunc()
        end
    end)
end

return M
