local countdownTime

function M:init()
    WinBase.init(self, "Countdown.json")
    self.m_countdown_respawn = self:child("Countdown-Respawn")
    self.m_countdown_respawn:SetText(Lang:toText("gui.wait.rebirth"))
    self.countDownText = self:child("Countdown-Last-Time")
    local deadCountDownUIProp = World.cfg.deadCountDownUIProp
    if deadCountDownUIProp then
        if deadCountDownUIProp.fontSize then
            self.countDownText:SetFontSize(deadCountDownUIProp.fontSize)
            self.countDownText:SetProperty("TextScale", 10)
        end
        if deadCountDownUIProp.textScale then
            self.countDownText:SetProperty("TextScale", deadCountDownUIProp.textScale)
        end
        if deadCountDownUIProp.textUIArea then
            self.countDownText:SetArea(table.unpack(deadCountDownUIProp.textUIArea))
        end
    end
    Lib.subscribeEvent(Event.EVENT_STOP_DEAD_COUNTDOWN, function()
        countdownTime = 0
    end)
end

function M:_countdown(time, callback, canTouchMain)
    countdownTime = time or 100
    if not self:isvisible() then
        self:show()
    end
    if countdownTime <= 0 then
        self:hide()
    end
	if self.closeTimer then
		self.closeTimer()
		self.closeTimer = nil
    end
    local countDownText = self.countDownText
    local reloadArg = self.reloadArg
    local closeTimer = self.closeTimer
    countDownText:SetText(tostring(countdownTime))
    local function tick()
        countdownTime = countdownTime - 1
		self.reloadArg = table.pack(countdownTime, callback, closeTimer)
        countDownText:SetText(tostring(math.ceil(countdownTime / 20)))
        if countdownTime <= 0 then
            UI:closeWnd(self)
            callback()
            return false
        end
        return true
    end
    self.closeTimer = World.Timer(1, tick)
    if canTouchMain then 
        self:root():SetTouchable(false)
    end
end

function M:forceCallBack()
	if self.closeTimer then
		self.closeTimer()
		self.closeTimer = nil
	end
    local _, callback, _ = table.unpack(self.reloadArg or {}, 1, self.reloadArg and self.reloadArg.n)
    if callback then
        callback()
    end
    self.reloadArg = nil
end

function M:onReload(reloadArg)
	local time, callback, closeTimer = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	if closeTimer then
		closeTimer()
		closeTimer = nil
	end
	self:_countdown(time, callback)
end

return M