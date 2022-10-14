function M:init()
    WinBase.init(self, "loadingTip_edit.json")
    self:root():SetLevel(10)
    self:child("Loading-Tips-Frame-Title"):SetText(Lang:toText("composition.replenish.title"))
    self:child("Loading-Tips-Frame-Context"):SetText(Lang:toText("win.map.loading.tips.context"))
    self:child("Loading-Tips-Frame-Sure-Text"):SetText(Lang:toText("win.map.loading.tips.sure.btn"))
    
    self:subscribe(self:child("Loading-Tips-Frame-Sure"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
        Lib.emitEvent(Event.EVENT_UP_DOWNLOAD_STATUS, 5)
    end)
end



function M:onClose()
end

return M