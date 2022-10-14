local tipTime

function M:init()
    WinBase.init(self, "teleporterEditTip_edit.json")
    self.numIcon = self:child("Edit-Tip-num")
    self.info = self:child("Edit-Tip-Info")
    tipTime = Entity.GetCfg("myplugin/transfer_point1").tipTime or 100
    Lib.subscribeEvent(Event.EVENT_EMPTY_STATE, function()
        Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, false)
    end)
    Lib.subscribeEvent(Event.EVENT_BEFORE_SAVE_MAP_SETTING, function()
        Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, false)
    end)
    Lib.subscribeEvent(Event.EVENT_SWITCH_PALETTE, function()
        Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, false)
	end)
end

function M:updateShowInfo(count, pairID, deleFunc, num)
    self.count = count
    self.deleFunc = deleFunc
    local function closeWin()
        Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, false)
    end
    if self.timer then
        self.timer()
    end

    if self.count == 0 and not deleFunc and not pairID then
        if num == 0 then
            UI:closeWnd(self)
        end
        return
    end

    local tip = Lang:toText("teleporter_finish")
    self.numIcon:SetImage("set:map_edit_teleporterTips.json image:tips_" .. pairID)
    if count == 2 then
        self.info:SetText(tip .. "2/2")
        self.timer = World.Timer(tipTime, closeWin)
    elseif count == 1 then
        self.info:SetText(tip .. "1/2")
    elseif count == 0 then
        self.info:SetText(tip .. "0/2")
    end
end

function M:onClose()
    local deleFunc = self.deleFunc
    if self.count == 1 and deleFunc then
        deleFunc()
        self.count = 0
        self.deleFunc = nil
    end
end

return M