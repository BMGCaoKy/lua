function M:init()
    WinBase.init(self, "UpglideTip.json", true)
    self.tip = self:child("UpglideTip-Tip")
    self.tip:SetText("")
end

function M:showTip(msg,time)
    if self.timer then
        self.timer()
        self.timer = nil
    end
    if self.tween then
        self.tween()
        self.tween = nil
    end
    self:root():SetYPosition({0, 0})
    self.tip:SetText(msg)
    self.timer = World.Timer(time or 30 , function()
        self.tween = UILib.uiTween(self:root(), {Y = {0,-170}}, 6, function()
            UI:closeWnd(self)
            self:root():SetYPosition({0, 0})
            self.tip:SetText("")
        end)
    end)
end

return M