function M:init()
    WinBase.init(self, "shopSettingEdit_edit.json")

    self.edit = self:child("setting-edit-layout-Edit")
    self.title = self:child("setting-edit-bg-text")
    self.sureBtn = self:child("setting-edit-bg-edit-sure")
    self.cancelBtn = self:child("setting-edit-bg-edit-cancel")
    self.sureBtnText = self:child("setting-edit-bg-edit-sureText")
    self.cancelBtnText = self:child("setting-edit-bg-edit-cancelText")

    self.edit:SetTextColor({0.094117, 0.674509, 0.474509, 1})
    self.title:SetText(Lang:toText("win.map.global.setting.shop.add.title"))
    self.sureBtnText:SetText(Lang:toText("win.map.edit.entity.setting.yes"))
    self.cancelBtnText:SetText(Lang:toText("composition.replenish.no.btn"))

    self:subscribe(self.cancelBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

    self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
        local text = self.edit:GetPropertyString("Text","")
        if text ~= "" then
            Lib.emitEvent(Event.EVENT_SHOP_SETTING_EDIT, text)
        end
        UI:closeWnd(self)
    end)
end

function M:onOpen()
    self.edit:SetText("")
end

function M:onReload(reloadArg)

end

return M