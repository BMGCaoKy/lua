
function M:init()
    WinBase.init(self, "headCountDown.json")
	self.countdown = self:child("headCountDown-text")
end

function M:onOpen(time, textColor, backColor)
	if not time or time < 0 then
		return
	end
	if not self:isvisible() then
        self:show()
    end
	local closeTimer = self.closeTimer
   if closeTimer then
		closeTimer()
		self.closeTimer = nil
   end
   local hours, min, second = Lib.timeFormatting(time)
   self.countdown:SetText(string.format("%02d:%02d", min, second))
   local function tick()
		time = time - 1
		if UI:getWnd("headCountDown") and time >0 then
			local hours, min, second = Lib.timeFormatting(time)
			self.countdown:SetText(string.format("%02d:%02d", min, second))
		end
		if UI:getWnd("headCountDown") and time <= 0 then
			self:hide()
			return false
		end
		return time > 0
   end
    self.closeTimer = World.Timer(20, tick)
end

return M