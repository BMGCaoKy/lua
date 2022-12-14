---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wangpq.
--- DateTime: 2020/5/28 15:43
---
local handles = T(Player, "PackageHandlers")---@type PlayerPackageHandlers

function M:init()
    WinBase.init(self, "TakePhotos.json")
    self:initWnd()
end

function M:initWnd()
    self.action = self:child("TakePhotos-action")
    self.close = self:child("TakePhotos-close")

    self:subscribe(self.action, UIEvent.EventButtonClick, function()
        handles.TakePhotos(Me, nil)
    end)

    self:subscribe(self.close, UIEvent.EventButtonClick, function()
        UI:closeWnd("takePhotos")
    end)
end

function M:onClose()
    Me:cameraModeClose()
end