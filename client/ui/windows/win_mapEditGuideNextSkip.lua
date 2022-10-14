local network_mgr = require "network_mgr"
local function unifyProc(self, btn, proc)
    self:subscribe(btn, UIEvent.EventWindowTouchUp, function()
        self:unsubscribe(btn)
        World.Timer(3, function()
            if not btn then
                return
            end
            unifyProc(self, btn, proc)
        end)
        if proc then
            proc()
        end
        btn:SetImage("set:map_edit_myMap.json image:but_green_pop_nor")
    end)
    self:subscribe(btn, UIEvent.EventWindowTouchDown, function()
        btn:SetImage("set:map_edit_myMap.json image:but_green_pop_act")
        self:emit(1)
    end)

    self:subscribe(btn, UIEvent.EventMotionRelease, function()
        btn:SetImage("set:map_edit_myMap.json image:but_green_pop_nor")
    end)

end

function M:init()
	WinBase.init(self, "guide_btn.json")
    self:child("Img-Next-Txt"):SetText(Lang:toText("gui.guide.next.step"))
    self:child("Btn-Skip-Txt"):SetText(Lang:toText("gui.guide.skip"))
    self.nextBtn = self:child("Img-Next")
    self.skipBtn = self:child("Btn-Skip")
    self:root():setBelongWhitelist(true)
    unifyProc(self, self.nextBtn, function()
        self:emit(2)
    end)

    self:subscribe(self.skipBtn, UIEvent.EventButtonClick, function()
        Clientsetting.setGuideInfo("isNewAcc", false, true)
		Clientsetting.setGuideInfo("isGuideStage", false, true)
		Clientsetting.setGuideInfo("isGuideTools", false, true)
		Clientsetting.setGuideInfo("isRemind", false, true)
		Clientsetting.setGuideInfo("isPathRemind", false, true)
		Clientsetting.setGuideInfo("isAreaRemind", false, true)
		Clientsetting.setGuideInfo("isOpenGuide", false)
        Lib.emitEvent(Event.EVENT_NOVICE_GUIDE, 4, true)
        local key = {"isNewAcc", "isGuideStage", "isGuideTools", "isRemind", "isPathRemind", "isAreaRemind", "isOpenGuide"}
        local value = {"1", "1", "1", "1", "1", "1", "1",}
        World.Timer(5, function()
            network_mgr:set_client_cache(key, value)
            return false
        end)
        
    end)

end

function M:emit(type) --type: 1=touchDown, 2=touchUp
    if not self.targetWnd then
        return
    end
    if type == 1 then
        self.targetWnd:TouchDown({x = 1, y = 2})
    elseif type == 2 then
        self.targetWnd:TouchUp({x = 1, y = 2})
    end
end

function M:onOpen(wnd)
    self.targetWnd = wnd
end

function M:onReload(reloadArg)

end

return M
