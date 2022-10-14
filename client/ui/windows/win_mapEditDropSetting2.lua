
function M:init()
    WinBase.init(self, "dropSettingItem2_edit.json")
    self.layout = self:child("DropSetting-Layout")
    self:child("DropSetting-Sure"):SetText(Lang:toText("global.sure"))
    self:child("DropSetting-Cancel"):SetText(Lang:toText("global.cancel"))
    self:subscribe(self:child("DropSetting-Cancel"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
    self:subscribe(self:child("DropSetting-Sure"), UIEvent.EventButtonClick, function()
        if self.backFunc then
            self.backFunc(self.dropSetting:getDropData())
        end
        UI:closeWnd(self)
    end)
end

function M:onOpen(params, backFunc)
    self:root():SetLevel(10)
    if not self.dropSetting then
        self.dropSetting = UI:openMultiInstanceWnd("mapEditDropSetting", params)
        self.layout:AddChildWindow(self.dropSetting:root())
    else
        self.dropSetting:onOpen(params)
    end
    self.backFunc = backFunc
    self.dropSetting:setContentXPosition({0, 100})
end