local setting = require "common.setting"

function M:init()
	WinBase.init(self, "PlayerKillTip.json", true)
	Lib.subscribeEvent(Event.EVENT_UPDATE_PLAYER_KILL_COUNT, function(count)
		if count <= 0 then
			UI:closeWnd(self)
			return
		end
		self:updateKillCount(count)
	end)
end

function M:onOpen(count)
	WinBase.onOpen(self)
	self:updateKillCount(count or 1)
	local koWnd = self:child("PlayerKillTip-KO")
	local killWnd = self:child("PlayerKillTip-Kill")
	killWnd:SetVisible(false)
	UILib.zoomTween(koWnd, 3, 1, 1.2, 1)
	self.tweenTimer = World.Timer(7, function()
		UILib.zoomTween(killWnd, 3, 1, 1.2, 1)
		killWnd:SetVisible(true)
	end)
end

function M:onClose()
	self:closeTweenTimer()
	self:child("PlayerKillTip-Count"):CleanupChildren()
	WinBase.onClose(self)
end

function M:closeTweenTimer()
	local timer = self.tweenTimer
	if timer then
		timer()
		self.tweenTimer = nil
	end
end

function M:updateKillCount(count)
	local parent = self:child("PlayerKillTip-Count")
	parent:CleanupChildren()
	local grid = UILib.makeNumbersGrid("PlayerKillTip-Count-Grid", count, "red_numbers")
	grid:SetHorizontalAlignment(1)	-- middle
	grid:SetVerticalAlignment(2)	-- bottom
	local width = tostring(count):len() * 50
	grid:SetArea({0, 0}, {0, 0}, {0, width}, {1, 0})
	parent:AddChildWindow(grid)
end
